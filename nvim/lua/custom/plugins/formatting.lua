return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>f',
      function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      mode = '',
      desc = '[F]ormat buffer',
    },
  },
  opts = {
    notify_on_error = false,
    format_on_save = {
      timeout_ms = 500,
      lsp_format = 'fallback',
    },
    formatters_by_ft = {
      lua = { 'stylua' },
      go = { 'gofmt' }, -- Uses system gofmt
      -- Conform can also run multiple formatters sequentially
      -- python = { "isort", "black" },
      --
      -- You can use 'stop_after_first' to run the first available formatter from the list
      javascript = { 'prettierd', 'prettier', stop_after_first = true },
      typescript = { 'prettierd', 'prettier', stop_after_first = true },
      javascriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      typescriptreact = { 'prettierd', 'prettier', stop_after_first = true },
      jsx = { 'prettierd', 'prettier', stop_after_first = true },
      tsx = { 'prettierd', 'prettier', stop_after_first = true },
      ts = { 'prettierd', 'prettier', stop_after_first = true },
      js = { 'prettierd', 'prettier', stop_after_first = true },
      fsharp = { 'fantomas' },
      fs = { 'fantomas' },
      fsx = { 'fantomas' },
      fsproj = { 'fantomas' },
    },
    formatters = {
      prettier = {
        append_args = { '--config', vim.fn.expand '~/.config/nvim/formatters/prettierrc' },
        env = {
          tab_widh = 1,
        },
        tabWidth = 2,
      },
      prettierd = {
        append_args = { '--config', vim.fn.expand '~/.config/nvim/formatters/.prettierrc.json' },
        env = {
          string.format('PRETTIERD_DEFAULT_CONFIG=%s', vim.fn.expand '~/.config/nvim/formatters/.prettierrc.json'),
        },
        tabWidth = 2,
      },
      fantomas = {
        command = vim.fn.stdpath 'data' .. '/mason/bin/fantomas', -- Use Mason's installed fantomas binary
        args = { '--indent-size', '4', '--no-newline-at-end' }, -- Example args, adjust as needed
        stdin = true, -- Pipe input directly from the buffer
      },
    },
  },
}