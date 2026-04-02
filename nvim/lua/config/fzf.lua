-- In your Neovim config file (init.lua or a separate keymaps.lua file)
local map = vim.keymap.set

-- Core file navigation
map('n', ',ff', "<cmd>lua require('fzf-lua').files()<CR>", { desc = "Find files" })
map('n', ',fs', "<cmd>lua require('fzf-lua').files({ actions = { ['default'] = require('fzf-lua').actions.file_split } })<CR>", { desc = "Find files with split" })
map('n', ',fi', "<cmd>lua require('fzf-lua').files({ no_ignore = true, actions = { ['default'] = require('fzf-lua').actions.file_split } })<CR>", { desc = "Find files with split" })
-- map('n', ',fg', "<cmd>lua require('fzf-lua').git_files()<CR>", { desc = "Find git files" })
-- map('n', ',fb', "<cmd>lua require('fzf-lua').buffers()<CR>", { desc = "Find buffers" })
-- map('n', ',fh', "<cmd>lua require('fzf-lua').oldfiles()<CR>", { desc = "Find history" })

-- Search content
map('n', ',sg', "<cmd>lua require('fzf-lua').grep()<CR>", { desc = "Search with grep" })
map('n', ',sw', "<cmd>lua require('fzf-lua').grep_cword()<CR>", { desc = "Search current word" })
map('n', ',sv', "<cmd>lua require('fzf-lua').grep_visual()<CR>", { desc = "Search visual selection" })
map('n', ',sl', "<cmd>lua require('fzf-lua').live_grep()<CR>", { desc = "Live grep" })

-- Project navigation
map('n', ',/', "<cmd>lua require('fzf-lua').blines()<CR>", { desc = "Search in buffer" })
map('n', ',gf', "<cmd>lua require('fzf-lua').git_status()<CR>", { desc = "Git status" })
map('n', ',gc', "<cmd>lua require('fzf-lua').git_commits()<CR>", { desc = "Git commits" })
