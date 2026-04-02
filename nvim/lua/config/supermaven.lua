require("supermaven-nvim").setup({
  keymaps = {
    accept_suggestion = "<C-j>",  -- accept the full suggestion
    accept_word = nil,            -- disable partial accept (it hijacks <C-j> by default)
    clear_suggestion = "<C-k>",   -- optional
  },
  ignore_filetypes = { cpp = true }, -- or { "cpp", }
  color = {
    suggestion_color = "#ffffff",
    cterm = 244,
  },
  log_level = "info", -- set to "off" to disable logging completely
  disable_inline_completion = false, -- disables inline completion for use with cmp
  disable_keymaps = false, -- disables built in keymaps for more manual control
  condition = function()
    return false
  end -- condition to check for stopping supermaven, `true` means to stop supermaven when the condition is true.
})

-- In case the old C-j was already set by lazy-load order, force-remove it:
pcall(vim.keymap.del, "i", "<C-j>")
-- And re-apply (belt-and-suspenders):
vim.keymap.set("i", "<C-j>",
  function() require("supermaven-nvim.completion_preview").on_accept_suggestion() end,
  { desc = "Supermaven: accept suggestion" }
)
