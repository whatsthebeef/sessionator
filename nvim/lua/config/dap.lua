local dap = require("dap")
local dapui = require("dapui")
require("dapui").setup()

-- Set up vscode-js-debug
require("dap-vscode-js").setup({
  -- Path to the vscode-js-debug installation
  debugger_path = vim.fn.stdpath("data") .. "/vscode-js-debug",
  adapter_path = "src/vsDebugServer.js",
  -- Command to use to run the adapter. By default, it will use node
  -- You can customize it if needed
  adapters = { 'pwa-node', 'pwa-chrome', 'pwa-msedge', 'node-terminal', 'pwa-extensionHost' },
})

require("dap").adapters["pwa-node"] = {
  type = "server",
  host = "localhost",
  port = "${port}",
  executable = {
    command = "node",
    -- 💀 Make sure to update this path to point to your installation
    args = {"/Users/john/.local/share/nvim/js-debug/src/dapDebugServer.js", "${port}"},
  }
}

-- Jasmine test configuration
dap.configurations.javascript = dap.configurations.javascript or {}
table.insert(dap.configurations.javascript, {
  type = "pwa-node",
  request = "launch",
  name = "Launch Jasmine Tests",
  -- Use one of these based on your project setup:
  program = "${workspaceFolder}/node_modules/jasmine/bin/jasmine.js",
  -- Or for projects using jasmine-node:
  -- program = "${workspaceFolder}/node_modules/jasmine-node/bin/jasmine-node",
  args = {
    "${file}"  -- Run current file
    -- Or to run all tests:
    -- "${workspaceFolder}/spec"
  },
  cwd = "${workspaceFolder}",
  console = "integratedTerminal",
  internalConsoleOptions = "neverOpen",
  sourceMaps = true,
  skipFiles = { "<node_internals>/**" },
  -- Or for plain JS:
  -- runtimeExecutable = "node",
  resolveSourceMapLocations = {
    "${workspaceFolder}/**",
    "!**/node_modules/**"
  },
})

-- Also add TypeScript configuration
--  dap.configurations.typescript = dap.configurations.typescript or {}
--  table.insert(dap.configurations.typescript, {
--    type = "pwa-node",
--    request = "launch",
--    name = "Launch Jasmine TypeScript Tests",
--    runtimeExecutable = "node",
--    runtimeArgs = {
--      "yarn", "cbt",
--    },
--    cwd = "${workspaceFolder}",
--    console = "integratedTerminal",
--    internalConsoleOptions = "neverOpen",
--    skipFiles = { "<node_internals>/**" },
--    sourceMaps = true,
--    outFiles = { "${workspaceFolder}/dist/**/*.js" },
--    resolveSourceMapLocations = {
--      "${workspaceFolder}/**",
--      "!**/node_modules/**"
--    },
--  })



-- Also add TypeScript configuration
dap.configurations.typescript = dap.configurations.typescript or {}
table.insert(dap.configurations.typescript, {
  type = "pwa-node",
  request = "launch",
  name = "Debug Jasmine TS Test",
  runtimeExecutable = "node",
  runtimeArgs = {
    "--loader", "ts-node/esm",
    "${workspaceFolder}/../../scripts/esm-jasmine-runner.mjs",
    "${file}"
  },
  cwd = "${workspaceFolder}",
  sourceMaps = true,
  console = "integratedTerminal",
  internalConsoleOptions = "neverOpen",
  skipFiles = { "<node_internals>/**", "**/node_modules/**" },
})

-- Configure JavaScript/TypeScript debugging
-- for _, language in ipairs({ "typescript", "javascript"}) do
--   dap.configurations[language] = {
--     -- Node.js
--     {
--       type = "pwa-node",
--       program = "${workspaceFolder}/node_modules/jasmine/bin/jasmine.js",
--       args = {"${file}"},
--       request = "launch",
--       name = "Jasmine",
--       cwd = "${workspaceFolder}",
--       sourceMaps = true,
--       outFiles = { "${workspaceFolder}/dist/**/*.js" },
--     },
--   }
-- end

-- Python configuration
dap.adapters.python = {
  type = 'executable',
  command = '.venv/bin/python', -- or 'python3', or full path
  args = { '-m', 'debugpy.adapter' },
}

dap.configurations.python = {
  {
    type = 'python',
    request = 'launch',
    name = "Launch file",
    program = "${file}", -- current buffer
    pythonPath = function()
      -- Use virtualenv if available
      local venv = os.getenv("VIRTUAL_ENV")
      if venv then
        return venv .. "/bin/python"
      else
        return "python"
      end
    end,
  },
}

-- Set up key mappings for debugging
vim.keymap.set('n', ',db', dap.toggle_breakpoint, { desc = "Toggle Breakpoint" })
vim.keymap.set('n', ',dc', dap.continue, { desc = "Continue" })
vim.keymap.set('n', ',do', dap.step_over, { desc = "Step Over" })
vim.keymap.set('n', ',di', dap.step_into, { desc = "Step Into" })
vim.keymap.set('n', ',du', dapui.toggle, { desc = "Toggle UI" })
vim.keymap.set('n', ',dd', dap.clear_breakpoints, { desc = "Delete all Breakpoints" })
vim.keymap.set('n', ',dt', dap.terminate, { desc = "Stop run" })
vim.keymap.set('n', ',dl', dap.run_last, { desc = "Run last" })
