-- Bootstrap essential settings
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- plugins I want /targets.vim

-- Load all modules
require 'config.options'
require 'custom.options'
require('config.keymaps').setup()
require 'custom.keymaps'
require 'custom.autocmds'
require('custom.transparency').setup()
require 'custom.commands'
require 'custom.terminal-paste-fix'
require('custom.sessions').setup()
-- require('custom.dtach-terminal').setup()  -- Disabled in favor of terminal-persist
require('custom.terminal-persist').setup()
require 'custom.terminal-input-proxy'
require('custom.task-runner').setup()

-- Setup plugins
require 'custom.lazy'

vim.api.nvim_create_user_command('Hydrate', function()
  local ts = vim.fn.expand '~/.config/demo.typescript'
  local tf = vim.fn.expand '~/.config/demo.time'
  local cmd = string.format('hydrate-typescript %s %s', vim.fn.shellescape(ts), vim.fn.shellescape(tf))
  if vim.bo.buftype == 'terminal' and vim.b.terminal_job_id then
    vim.api.nvim_chan_send(vim.b.terminal_job_id, cmd .. '\r')
  else
    vim.cmd('terminal ' .. cmd)
  end
end, {})
