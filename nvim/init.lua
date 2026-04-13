
---------------------- Variables ----------------------
---vim.g.tempDir = "~/dev/.swptmp/"
vim.g.tempDir = "~/dev/.swptmp/"

-------- Plugins

require("config.lazy")
require("config.coc")
require("config.fzf")
require("config.dap")
require("config.supermaven")

---------- General

vim.g.mapleader = ','
vim.cmd('syntax enable');

------------------- Configuration --------------------

vim.opt.syntax = "on"  -- Enable syntax highlighting

-- Syntastic and UI settings
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.scrolloff = 3
vim.opt.showcmd = true
vim.opt.ruler = true
vim.opt.visualbell = false
vim.opt.backup = false
vim.opt.number = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.title = true
vim.opt.ttyfast = true
vim.opt.modeline = true
vim.opt.modelines = 3
vim.opt.shortmess = "atI"
vim.opt.startofline = false
vim.opt.whichwrap = "b,s,h,l,<,>,[,]"
vim.opt.backspace = "indent,eol,start"
vim.opt.foldmethod = "indent"
vim.opt.foldlevelstart = 4

-- Search settings
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.wildignorecase = true

-- Wildmenu settings
vim.opt.wildmenu = true
vim.opt.wildmode = { "list:full" }
vim.opt.wildignore = {
  "*.swp", "*.bak", "*.pyc", "*.class", "*.sln",
  "*.Master", "*.csproj", "*.csproj.user",
  "*.cache", "*.dll", "*.pdb", "*.min.*",
  "*/.git/**/*", "tags", "*.tar.*",
  "*/node_modules/*", "tmp", "10m_cultural", "*/.yarn/*",
  "*/dist/*",
}

-- Backup and swap directory settings
vim.opt.backupdir = { vim.fn.expand(vim.g.tempDir) }
vim.opt.directory = { vim.fn.expand(vim.g.tempDir) }

-- Indentation settings
vim.opt.autoindent = true
vim.opt.expandtab = true  -- Tabs are converted to spaces
vim.opt.showmatch = true  -- Show matching braces
vim.opt.tags = { "./tags", "tags" }
vim.opt.tagstack = true

----------------------- Highlighting
vim.cmd [[
  hi x018_DarkBlue ctermfg=18 guifg=#000087
  hi x017_NavyBlue ctermfg=17 guifg=#00005f
  hi x142_Gold3 ctermfg=142 guifg=#afaf00
  hi x148_Yellow3 ctermfg=148 guifg=#afd700
  hi x108_DarkSeaGreen ctermfg=108 guifg=#87af87
  hi x022_DarkGreen ctermfg=22 guifg=#005f00
  hi x088_DarkRed ctermfg=88 guifg=#870000
  hi x124_Red3 ctermfg=124 guifg=#af0000
  hi x128_Brown ctermfg=130
  hi x138_RosyBrown ctermfg=138
  hi x143_DarkKhaki ctermfg=143
  hi x208_DarkOrange ctermfg=208
  colorscheme grb256
  hi StatusLineNC ctermbg=242
  hi Cursor ctermfg=124
  hi jsVariable ctermfg=18
  hi jsThis ctermfg=18 cterm=bold
  hi jsNull ctermfg=124
  hi jsFunction ctermfg=22 cterm=bold
  hi Function ctermfg=22 cterm=bold
  hi Type ctermfg=142
  hi Special ctermfg=22
  hi Number ctermfg=124
  hi Variables ctermfg=18
  hi String ctermfg=18
  hi Constant ctermfg=208
  hi Identifier ctermfg=208
  hi Todo ctermfg=16 ctermbg=160
]]

----- Autocommand

vim.api.nvim_create_autocmd('BufWritePost', {
  pattern = vim.fn.stdpath('config') .. '/**/*.lua', -- Watches all Lua files in the config
  callback = function()
    vim.cmd('luafile ' .. vim.fn.expand('<afile>'))
    print('🔄 Reloaded: ' .. vim.fn.expand('<afile>'))
  end,
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = { "*.css", "*.scss" },
  command = "normal! mC"
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = { "*.html", "*.erb", "*.js", "*.ts", "*.php", "*.rb" },
  command = "normal! mH"
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = { "*.js" },
  command = "normal! mJ"
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = { "*.ts"},
  command = "normal! mT"
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = { "*.php"},
  command = "normal! mP"
})

vim.api.nvim_create_autocmd("BufLeave", {
  pattern = { "*.rb"},
  command = "normal! mR"
})

vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "*",
  callback = function()
    if vim.fn.line("'\"") > 1 and vim.fn.line("'\"") <= vim.fn.line("$") then
      vim.cmd('normal! g`"')
    end
  end
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "helpfile",
  command = "set nonumber"
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "typescript",
  command = "set tabstop=2"
})

vim.api.nvim_create_autocmd("Syntax", {
  pattern = "html",
  command = "setlocal foldmethod=indent foldlevel=2"
})

-- Open the quickfix window automatically after grep command
vim.api.nvim_create_autocmd("QuickFixCmdPost", {
  pattern = "*grep*",
  command = "cwindow"
})

-- Set the filetype to 'typescript' for new and existing .ts files
vim.api.nvim_create_autocmd({ "BufNewFile", "BufRead" }, {
  pattern = "*.ts",
  command = "setlocal filetype=typescript"
})

--------- Key mappings

-- Ex Commands
-- vim.keymap.set('n', '/', ':<C-F>/', { noremap = true, silent = true })
vim.keymap.set('n', '/', function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(':<C-F>i/', true, false, true), 'n', true)
end, { noremap = true, silent = true })
vim.keymap.set('n', ':', function()
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(':<C-F>i', true, false, true), 'n', true)
end, { noremap = true, silent = true })

-- Jumping between buffers
vim.keymap.set('n', '<Leader>n', ':silent b#<CR>', { noremap = true, silent = true })

-- Grep commands
vim.keymap.set('n', '<Leader>g', ':execute "Ggrep " . expand("<cword>")<CR>', { noremap = true, silent = true })

-- Delete without copying to register
vim.keymap.set('n', '<Leader>d', '"_d', { noremap = true, silent = true })

vim.keymap.set('n', 'q', '<Nop>', { noremap = true, silent = true })

vim.keymap.set('n', '<C-w><Down>', '<C-w>-', { noremap = true, silent = true })
vim.keymap.set('n', '<C-w><Up>', '<C-w><Up>', { noremap = true, silent = true })

vim.keymap.set('n', '<Leader>p', ':!yarn format:all<CR>', { noremap = true, silent = true })

vim.api.nvim_create_user_command("RemoveWindowLineEndings", ":%s/\r$//g", {})
vim.api.nvim_create_user_command("ChangeFileType", "set ff=unix", {})

function FunDeleteSwapFile()
  local swpFile = vim.g.tempDir .. vim.fn.expand('%:t') .. ".swp"
  print(swpFile)
  vim.fn.execute("!rm " .. swpFile)
end

vim.keymap.set('n', '<Leader>ds', ':lua FunDeleteSwapFile()<CR>', { noremap = true, silent = true })

vim.opt.wildcharm = 26 -- vim.api.nvim_replace_termcodes('<C-z>', true, true, true)
vim.keymap.set('n', '<Leader>m', ':<C-f>isilent buffer<Space>', { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>b', ':<C-f>isbuffer<Space>', { noremap = true, silent = true })

vim.opt.path = ".,**"
-- vim.keymap.set('n', '<Leader>f', ':<C-f>isilent find *', { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>s', ':<C-f>isfind *', { noremap = true, silent = true })
-- Currently used by the tfm plugin
-- vim.keymap.set('n', '<Leader>v', ':<C-f>ivert sfind *', { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>h', ':<C-f>ibo sfind *', { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>t', ':<C-f>itabfind *', { noremap = true, silent = true })

function AngularSwitch(ext)
  local path = vim.fn.expand('%')
  if path:match(ext .. "$") then
    if path:match("(%.spec%.*)") then
      if ext:match("(%.spec%.*)") then
        return
      end
    else
      return
    end
  end
  if ext == '.js' or ext == '.spec.js' then
    path = path:gsub("src/", "dist/")
  else
    path = path:gsub("dist/", "src/")
  end
  local newPath = path:gsub("(%.spec%.ts)$", ext)
                      :gsub("(%.spec%.js)$", ext)
                      :gsub("(%.ts)$", ext)
                      :gsub("(%.js)$", ext)
                      :gsub("(%.html)$", ext)
                      :gsub("(%.scss)$", ext)
  if vim.fn.bufexists(newPath) > 0 then
    vim.cmd('silent buff ' .. newPath)
  else
    vim.cmd('silent e ' .. newPath)
  end
end


vim.keymap.set('n', '<Leader>nt', function() AngularSwitch('.spec.ts') end, { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>nz', function() AngularSwitch('.spec.js') end, { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>nc', function() AngularSwitch('.ts') end, { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>nj', function() AngularSwitch('.js') end, { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>nh', function() AngularSwitch('.html') end, { noremap = true, silent = true })
vim.keymap.set('n', '<Leader>ns', function() AngularSwitch('.scss') end, { noremap = true, silent = true })

function NewFileInDirOfCurrentBuffer()
  vim.fn.inputsave()
  local name = vim.fn.input("Enter file name: ")
  vim.fn.inputrestore()
  vim.cmd("e " .. vim.fn.expand("%:p:h") .. "/" .. name)
end

vim.keymap.set('n', ',nf', ':lua NewFileInDirOfCurrentBuffer()<CR>', { noremap = true, silent = true })

------------ Commands
vim.api.nvim_create_user_command("Evrc", "tabedit $MYVIMRC", {})
vim.api.nvim_create_user_command("Rvrc", "source $MYVIMRC", {})

vim.api.nvim_create_user_command("RemoveWindowLineEndings", ":%s/\r$//g", {})
vim.api.nvim_create_user_command("ChangeFileType", ":set ff=unix", {})

vim.api.nvim_create_user_command("CLOutputToWindow", function(opts)
  local res = vim.fn.system(opts.args)
  vim.cmd("new")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(res, "\n"))
end, { nargs = 1 })

function NewFileInDirOfCurrentBuffer()
  vim.fn.inputsave()
  local name = vim.fn.input("Enter file name: ")
  vim.fn.inputrestore()
  vim.cmd("e " .. vim.fn.expand("%:p:h") .. "/" .. name)
end

vim.keymap.set('n', ',nf', ':lua NewFileInDirOfCurrentBuffer()<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<C-N>', ':silent noh<CR>', { noremap = true, silent = true })

vim.keymap.set('n', '<Leader>g', function()
  vim.cmd("execute 'Ggrep ' .. vim.fn.expand('<cword>')")
end, { noremap = true, silent = true })

vim.api.nvim_create_user_command("GgrepRev", function(opts)
  vim.cmd("Git! grep " .. opts.args .. " $(git rev-list --all)")
end, { nargs = 1 })

vim.api.nvim_create_user_command("Gpush", function(opts)
  vim.cmd("Git add %")
  vim.cmd("Git commit -m " .. opts.args)
  vim.cmd("Git push")
end, { nargs = 1 })

vim.api.nvim_create_user_command("GpushDummy", function()
  vim.cmd("Git add %")
  vim.cmd("Git commit -m 'Squash'")
  vim.cmd("Git push")
end, {})

vim.keymap.set("n", "<leader>gw", function()
  require("worktrees").worktrees()
end, { desc = "Git worktrees" })
