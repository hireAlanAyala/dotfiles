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
-- require('custom.dtach-terminal').setup()  -- Disabled in favor of tmux-persist
require('custom.tmux-persist').setup()

-- Setup plugins
require 'custom.lazy'
