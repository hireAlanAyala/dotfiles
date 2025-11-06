-- Bootstrap essential settings
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- Initialize persistent socket (must be done before other modules)
require('custom.socket').init()

-- plugins I want /targets.vim
-- firenvim
-- nvim-dbee (does not support sqlite)
-- explore db tuis: lazysql, rainfrog, vim-dadbod-ui, harlequin, sqlua
-- overseer (task runner, people are using it to automate tasks they'd usually have in a separate window/pane)
-- nvim-better-n
-- nvim-various-textobjs (text object ideas)

-- Load all modules
require 'config.options'
require 'custom.options'
require('config.keymaps').setup()
require 'custom.keymaps'
require 'custom.autocmds'

require('custom.transparency').setup()
require 'custom.commands'
require 'custom.terminal-paste-fix'
require('custom.terminal-persist').setup()
require 'custom.terminal-input-proxy'
require('custom.task-runner').setup()
require('custom.smart-notes').setup()
require 'custom.csv'

require 'custom.lazy'
