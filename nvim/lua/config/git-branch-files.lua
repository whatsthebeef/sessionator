local gbranch_list_buf = nil

vim.api.nvim_create_user_command("GBranchFiles", function(opts)
  local base = opts.args ~= "" and opts.args or "master"

  local lines = vim.fn.systemlist({
    "git",
    "diff",
    "--name-status",
    base .. "...HEAD",
  })

  vim.cmd("enew")
  vim.bo.buftype = "nofile"
  vim.bo.bufhidden = "wipe"
  vim.bo.swapfile = false
  vim.bo.filetype = "gitbranchfiles"

  gbranch_list_buf = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.b.gbranch_base = base

  -- Enter on a file: open the diff in a new tab
  vim.keymap.set("n", "<CR>", function()
    local line = vim.fn.getline(".")
    if line == "" then
      return
    end

    local branch_base = vim.b.gbranch_base or "master"

    local parts = vim.split(line, "\t")
    local status = parts[1]
    local file = parts[#parts]

    if not file or file == "" then
      return
    end

    if status:sub(1, 1) == "D" then
      vim.cmd("tabedit")
      vim.cmd("Gedit " .. branch_base .. ":" .. vim.fn.fnameescape(file))
    else
      vim.cmd("tabedit " .. vim.fn.fnameescape(file))
      vim.cmd("Gdiffsplit " .. branch_base)
    end

    -- q in the diff tab closes it and returns to the list
    vim.keymap.set("n", "q", function()
      vim.cmd("tabclose")
    end, { buffer = false, nowait = true })
  end, { buffer = true })

  -- q in the list closes it
  vim.keymap.set("n", "q", function()
    vim.cmd("bwipeout")
    gbranch_list_buf = nil
  end, { buffer = true, nowait = true })
end, {
  nargs = "?",
})

-- Keybindings
local map = vim.keymap.set
map('n', ',dm', ':GBranchFiles master<CR>', { desc = 'Branch files: diff vs master' })
map('n', ',dh', ':0Gclog<CR>', { desc = 'Git: current file history' })
map('n', ',da', ':Gclog<CR>', { desc = 'Git: all commits' })
