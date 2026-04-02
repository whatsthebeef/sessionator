vim.g.coc_global_extensions = {
  "coc-lua",
  "coc-tsserver",
  "coc-json",
  "coc-html",
  "coc-css",
  "coc-eslint",
  "coc-prettier",
  "coc-pyright",
}

vim.o.completeopt = "menuone,noselect"

-- Key Mappings for coc.nvim
local keymap = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Navigate completion menu
keymap("i", "<Tab>", "coc#pum#visible() ? coc#pum#next(1) : '<Tab>'", { expr = true, noremap = true })
keymap("i", "<S-Tab>", "coc#pum#visible() ? coc#pum#prev(1) : '<S-Tab>'", { expr = true, noremap = true })
keymap("i", "<CR>", "coc#pum#visible() ? coc#pum#confirm() : '<CR>'", { expr = true, noremap = true })

-- Go to definition & references
keymap("n", "gd", "<Plug>(coc-definition)", opts)
keymap("n", "gr", "<Plug>(coc-references)", opts)

-- Show documentation
keymap("n", "K", ":call CocActionAsync('doHover')<CR>", opts)

-- Format file
keymap("n", ",fo", ":CocCommand prettier.formatFile<CR>", opts)

-- Code actions & rename
keymap("n", ",rn", "<Plug>(coc-rename)", opts)
keymap("n", ",ca", "<Plug>(coc-codeaction-selected)", opts)

-- Navigate diagnostics
keymap("n", "[g", "<Plug>(coc-diagnostic-prev)", opts)
keymap("n", "]g", "<Plug>(coc-diagnostic-next)", opts)

-- Restart Coc
keymap("n", ",rc", ":CocRestart<CR>", opts)

-- Highlight symbol under cursor
vim.api.nvim_create_autocmd("CursorHold", {
  pattern = "*",
  command = "silent call CocActionAsync('highlight')",
})
