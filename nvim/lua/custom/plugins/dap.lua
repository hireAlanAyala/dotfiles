return {
  'rcarriga/nvim-dap-ui',
  dependencies = {
    'mfussenegger/nvim-dap',
    'nvim-neotest/nvim-nio',
    'theHamsta/nvim-dap-virtual-text',
  },
  config = function()
    local dap = require 'dap'
    local dapui = require 'dapui'

    dapui.setup {
      layouts = {
        {
          elements = {
            { id = 'scopes', size = 0.25 },
            { id = 'breakpoints', size = 0.25 },
            { id = 'stacks', size = 0.25 },
            { id = 'watches', size = 0.25 },
          },
          position = 'left',
          size = 40,
        },
        {
          elements = {
            { id = 'repl', size = 0.5 },
            { id = 'console', size = 0.5 },
          },
          position = 'bottom',
          size = 10,
        },
      },
    }

    -- Setup virtual text
    require('nvim-dap-virtual-text').setup()

    -- Setup debug keymaps
    require('config.keymaps').setup_dap_keymaps()

    -- Event hooks
    dap.listeners.before.attach.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.launch.dapui_config = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated.dapui_config = function()
      dapui.close()
    end
    dap.listeners.before.event_exited.dapui_config = function()
      dapui.close()
    end

    -- Language configs
    dap.adapters.coreclr = {
      type = 'executable',
      command = os.getenv 'HOME' .. '/.nix-profile/bin/netcoredbg',
      args = { '--interpreter=vscode' },
    }

    local dotnet_config = {
      {
        type = 'coreclr',
        name = 'Launch - netcoredbg',
        request = 'launch',
        program = function()
          local cwd = vim.fn.getcwd()
          local dlls = vim.fn.glob(cwd .. '/bin/Debug/**/*.dll', false, true)

          if #dlls == 0 then
            return vim.fn.input('No DLLs found. Enter path manually: ', cwd .. '/bin/Debug/', 'file')
          elseif #dlls == 1 then
            return dlls[1]
          else
            -- Use Neovim's UI selector (can be telescope, dressing.nvim, etc.)
            local co = coroutine.running()
            vim.ui.select(dlls, { prompt = 'Select DLL to debug' }, function(choice)
              coroutine.resume(co, choice)
            end)
            return coroutine.yield()
          end
        end,
      },
    }

    dap.configurations.cs = dotnet_config
    dap.configurations.fsharp = dotnet_config

    -- JavaScript/TypeScript debugging with js-debug-adapter
    dap.adapters['pwa-node'] = {
      type = 'server',
      host = 'localhost',
      port = '${port}',
      executable = {
        command = 'js-debug-adapter',
        args = { '${port}' },
      },
    }

    -- Chrome/Browser debugging
    dap.adapters['pwa-chrome'] = {
      type = 'server',
      host = 'localhost',
      port = '${port}',
      executable = {
        command = 'js-debug-adapter',
        args = { '${port}' },
      },
    }

    local js_config = {
      {
        name = 'Launch Node.js Program',
        type = 'pwa-node',
        request = 'launch',
        program = function()
          return vim.fn.input('Path to executable: ', vim.fn.getcwd() .. '/', 'file')
        end,
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
        console = 'integratedTerminal',
      },
      {
        name = 'Launch via npm',
        type = 'pwa-node',
        request = 'launch',
        cwd = '${workspaceFolder}',
        runtimeExecutable = 'npm',
        runtimeArgs = { 'run-script', 'debug' },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
        console = 'integratedTerminal',
      },
      {
        name = 'Attach to Process',
        type = 'pwa-node',
        request = 'attach',
        processId = function()
          return require('dap.utils').pick_process()
        end,
        cwd = '${workspaceFolder}',
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
      },
      {
        name = 'Debug Jest Tests',
        type = 'pwa-node',
        request = 'launch',
        cwd = '${workspaceFolder}',
        runtimeExecutable = 'node',
        runtimeArgs = { '--inspect-brk', 'node_modules/.bin/jest', '--runInBand' },
        console = 'integratedTerminal',
        internalConsoleOptions = 'neverOpen',
        resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
      },
      {
        name = 'Debug Current File',
        type = 'pwa-node',
        request = 'launch',
        program = '${file}',
        cwd = '${workspaceFolder}',
        sourceMaps = true,
        resolveSourceMapLocations = { '${workspaceFolder}/**', '!**/node_modules/**' },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
        console = 'integratedTerminal',
      },
    }

    -- TypeScript-specific configuration
    local ts_config = {
      {
        type = 'pwa-node',
        request = 'launch',
        name = 'Debug TypeScript',
        program = '${workspaceFolder}/src/server.ts',
        cwd = '${workspaceFolder}',
        runtimeArgs = { '-r', 'ts-node/register' },
        sourceMaps = true,
        outFiles = {
          '${workspaceFolder}/dist/**/*.js',
          '${workspaceFolder}/build/**/*.js',
          '${workspaceFolder}/out/**/*.js',
          '${workspaceFolder}/**/*.js',
        },
        resolveSourceMapLocations = {
          '${workspaceFolder}/**',
          '!**/node_modules/**',
        },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
        console = 'integratedTerminal',
      },
      {
        name = 'Debug Current TypeScript File',
        type = 'pwa-node',
        request = 'launch',
        program = '${file}',
        cwd = '${workspaceFolder}',
        runtimeArgs = { '-r', 'ts-node/register' },
        sourceMaps = true,
        outFiles = {
          '${workspaceFolder}/dist/**/*.js',
          '${workspaceFolder}/build/**/*.js',
          '${workspaceFolder}/out/**/*.js',
          '${workspaceFolder}/**/*.js',
        },
        resolveSourceMapLocations = {
          '${workspaceFolder}/**',
          '!**/node_modules/**',
        },
        skipFiles = { '<node_internals>/**', 'node_modules/**' },
        console = 'integratedTerminal',
      },
    }

    dap.configurations.javascript = js_config
    dap.configurations.typescript = ts_config
  end,
}