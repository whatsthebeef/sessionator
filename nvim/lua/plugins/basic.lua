return {
  -- CoC.nvim (Conqueror of Completion)
  { 'neoclide/coc.nvim' },

  -- vim-fugitive (Git integration)
  { 'tpope/vim-fugitive' },

  -- vim-surround (Surround text manipulation)
  { 'tpope/vim-surround' },
  -- {
  --  'github/copilot.vim',  -- GitHub Copilot plugin
  -- },
  {
    "ibhagwan/fzf-lua",
    -- optional for icon support
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- or if using mini.icons/mini.nvim
    -- dependencies = { "echasnovski/mini.icons" },
    opts = {}
  },
  { 'mfussenegger/nvim-dap' },
  {
	  "rcarriga/nvim-dap-ui",
	  dependencies = {
		  "mfussenegger/nvim-dap",
		  "nvim-neotest/nvim-nio"
	  },
	  config = function()
		  require("dapui").setup()
	  end
  },
  { 'mxsdev/nvim-dap-vscode-js' },
  {
    "supermaven-inc/supermaven-nvim",
  },
}
