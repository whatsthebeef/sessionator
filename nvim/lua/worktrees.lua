local M = {}

local function trim(s)
  return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function get_current_branch()
  local out = vim.fn.system({ "git", "branch", "--show-current" })
  if vim.v.shell_error ~= 0 then
    return nil
  end
  out = trim(out)
  if out == "" then
    return nil
  end
  return out
end

local function get_worktrees()
  local lines = vim.fn.systemlist({ "git", "worktree", "list", "--porcelain" })
  if vim.v.shell_error ~= 0 then
    vim.notify("Could not read git worktree list", vim.log.levels.ERROR)
    return {}
  end

  local items = {}
  local current = nil

  for _, line in ipairs(lines) do
    local wt = line:match("^worktree%s+(.+)$")
    local branch = line:match("^branch%s+refs/heads/(.+)$")
    local detached = line == "detached"

    if wt then
      current = {
        path = wt,
        branch = nil,
        detached = false,
      }
      table.insert(items, current)
    elseif branch and current then
      current.branch = branch
    elseif detached and current then
      current.detached = true
    end
  end

  return items
end

local function display_line(item)
  local path = vim.fn.fnamemodify(item.path, ":~")
  local branch = item.detached and "(detached)" or (item.branch or "(unknown)")
  return string.format("%s\t[%s]", path, branch)
end

local function parse_path(line)
  return line:match("^(.-)\t%[")
end

local function find_item_by_display(items, line)
  local display_path = parse_path(line)
  if not display_path then
    return nil
  end

  for _, item in ipairs(items) do
    if vim.fn.fnamemodify(item.path, ":~") == display_path then
      return item
    end
  end

  return nil
end

local function open_worktree(item)
  vim.cmd("cd " .. vim.fn.fnameescape(item.path))
  vim.cmd("enew")
  vim.cmd("edit .")
end

local function delete_worktree(item)
  local cwd_abs = vim.fn.fnamemodify(vim.fn.getcwd(), ":p")
  local item_abs = vim.fn.fnamemodify(item.path, ":p")

  if cwd_abs == item_abs then
    vim.notify("Cannot delete the worktree you are currently in", vim.log.levels.ERROR)
    return
  end

  local choice = vim.fn.confirm(
    "Delete worktree?\n" .. item.path,
    "&Yes\n&No",
    2
  )

  if choice ~= 1 then
    return
  end

  local out = vim.fn.system({ "git", "worktree", "remove", item.path })
  if vim.v.shell_error ~= 0 then
    vim.notify(trim(out), vim.log.levels.ERROR)
    return
  end

  vim.fn.system({ "git", "worktree", "prune" })
  vim.notify("Deleted worktree: " .. item.path)

  vim.schedule(function()
    M.worktrees()
  end)
end

local function squash_merge_worktree(item)
  if item.detached or not item.branch or item.branch == "" then
    vim.notify("Cannot squash-merge a detached worktree", vim.log.levels.ERROR)
    return
  end

  local current_branch = get_current_branch()
  if not current_branch then
    vim.notify("Could not determine current branch", vim.log.levels.ERROR)
    return
  end

  if current_branch == item.branch then
    vim.notify(
      string.format("Cannot squash-merge branch '%s' into itself", current_branch),
      vim.log.levels.ERROR
    )
    return
  end

  local choice = vim.fn.confirm(
    string.format(
      "Squash-merge '%s' into current branch '%s'?",
      item.branch,
      current_branch
    ),
    "&Yes\n&No",
    2
  )

  if choice ~= 1 then
    return
  end

  local out = vim.fn.system({ "git", "merge", "--squash", item.branch })
  if vim.v.shell_error ~= 0 then
    vim.notify(trim(out), vim.log.levels.ERROR)
    return
  end

  vim.notify(
    string.format(
      "Squash merge applied from '%s' into '%s'. Review and commit manually.",
      item.branch,
      current_branch
    ),
    vim.log.levels.INFO
  )
end

function M.worktrees()
  local ok, fzf = pcall(require, "fzf-lua")
  if not ok then
    vim.notify("fzf-lua is not available", vim.log.levels.ERROR)
    return
  end

  local items = get_worktrees()
  if vim.tbl_isempty(items) then
    vim.notify("No worktrees found", vim.log.levels.WARN)
    return
  end

  local lines = vim.tbl_map(display_line, items)

  fzf.fzf_exec(lines, {
    prompt = "Worktrees> ",
    fzf_opts = {
      ["--delimiter"] = "\t",
      ["--with-nth"] = "1,2",
      ["--header"] = "Enter: open  |  Ctrl-d: delete  |  Ctrl-s: squash merge into current branch",
    },
    actions = {
      ["default"] = function(selected)
        local item = selected and find_item_by_display(items, selected[1])
        if item then
          open_worktree(item)
        end
      end,
      ["ctrl-d"] = function(selected)
        local item = selected and find_item_by_display(items, selected[1])
        if item then
          delete_worktree(item)
        end
      end,
      ["ctrl-s"] = function(selected)
        local item = selected and find_item_by_display(items, selected[1])
        if item then
          squash_merge_worktree(item)
        end
      end,
    },
  })
end

vim.api.nvim_create_user_command("Worktrees", function()
  require("worktrees").worktrees()
end, {})

return M
