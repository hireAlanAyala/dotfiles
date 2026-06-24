-- Bootstrap essential settings
vim.g.mapleader = ' '
vim.g.maplocalleader = ' '
vim.g.have_nerd_font = true

-- Harden the shell: if $SHELL (nvim's 'shell') no longer exists -- e.g. after
-- migrating off a Nix-provided zsh -- fall back to a system shell so :terminal,
-- terminal-persist, and fzf-lua can still spawn. Warn so a stale $SHELL gets
-- noticed (a re-login into the session usually refreshes it).
do
  if vim.fn.executable(vim.o.shell) == 0 then
    local stale = vim.o.shell
    local fallback = (vim.fn.executable('/usr/bin/zsh') == 1 and '/usr/bin/zsh')
      or (vim.fn.executable('zsh') == 1 and 'zsh' or '/bin/sh')
    vim.o.shell = fallback
    vim.schedule(function()
      vim.notify(
        ('$SHELL %q not found — using %q. Re-login to refresh the session env.'):format(stale, fallback),
        vim.log.levels.WARN
      )
    end)
  end
end

-- Initialize persistent socket (must be done before other modules)
require('custom.socket').init()

-- plugins I want /targets.vim
-- firenvim
-- nvim-dbee (does not support sqlite)
-- explore db tuis: lazysql, rainfrog, vim-dadbod-ui, harlequin, sqlua
-- overseer (task runner, people are using it to automate tasks they'd usually have in a separate window/pane)
-- nvim-better-n
-- nvim-various-textobjs (text object ideas)
-- term-edit.nvim or editable-term.nvim

-- Load all modules
require 'config.options'
require 'custom.options'
require('config.keymaps').setup()
require 'custom.keymaps'
require 'custom.autocmds'

require('custom.transparency').setup()
require 'custom.commands'
require 'custom.terminal-paste-fix'
require('terminal-persist').setup()
require('custom.session-jump').setup()
require('custom.task-runner').setup()
require('custom.smart-notes').setup()
require 'custom.csv'
require('custom.browser').setup()
require('custom.vault').setup()

require 'custom.lazy'
