-- Bootstrap essential settings
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- Load all modules
require 'config.options'
require 'custom.options'
require('config.keymaps').setup()
require 'custom.keymaps'
require 'custom.autocmds'
require('custom.transparency').setup()
require 'custom.commands'
require('custom.sessions').setup()

-- Setup plugins
require 'custom.lazy'