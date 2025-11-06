-- Additional keymaps that aren't in config/keymaps.lua

-- Clear highlights on search when pressing <Esc> in normal mode
vim.keymap.set('n', '<Esc>', '<cmd>nohlsearch<CR>')

-- Window resizing keymaps
vim.keymap.set('n', '<C-Up>', ':resize +2<CR>', { desc = 'Increase window height' })
vim.keymap.set('n', '<C-Down>', ':resize -2<CR>', { desc = 'Decrease window height' })
vim.keymap.set('n', '<C-Left>', ':vertical resize -2<CR>', { desc = 'Decrease window width' })
vim.keymap.set('n', '<C-Right>', ':vertical resize +2<CR>', { desc = 'Increase window width' })

-- Move lines up/down
vim.keymap.set('n', '<A-j>', ':m .+1<CR>==', { desc = 'Move line down' })
vim.keymap.set('n', '<A-k>', ':m .-2<CR>==', { desc = 'Move line up' })
vim.keymap.set('v', '<A-j>', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
vim.keymap.set('v', '<A-k>', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

-- Better indenting in visual mode
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left and reselect' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right and reselect' })

-- Better J behavior
vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })

-- vim-tmux-navigator keymaps for seamless navigation between nvim and tmux panes
-- These work with the tmux vim-tmux-navigator plugin for unified navigation
vim.keymap.set('n', '<C-h>', '<cmd>TmuxNavigateLeft<cr>', { desc = 'Navigate left (nvim/tmux)' })
vim.keymap.set('n', '<C-l>', '<cmd>TmuxNavigateRight<cr>', { desc = 'Navigate right (nvim/tmux)' })
vim.keymap.set('n', '<C-j>', '<cmd>TmuxNavigateDown<cr>', { desc = 'Navigate down (nvim/tmux)' })
vim.keymap.set('n', '<C-k>', '<cmd>TmuxNavigateUp<cr>', { desc = 'Navigate up (nvim/tmux)' })

-- Terminal persist keymaps
local terminal_persist = require 'custom.terminal-persist'
vim.keymap.set('n', '<leader>tn', function()
  vim.ui.input({ prompt = 'Terminal name: ' }, function(name)
    if name and name ~= '' then
      terminal_persist.new_terminal(nil, name, true)
    elseif name == '' then
      vim.notify('Terminal name is required', vim.log.levels.WARN)
    end
  end)
end, { desc = 'new persistent terminal' })

vim.keymap.set('n', '<leader>ac', function()
  terminal_persist.new_terminal('claude /commit', 'commits', true)
end, { desc = 'commit' })

-- Task runner keymaps (lazy loaded to avoid telescope dependency issues)
vim.keymap.set('n', '<leader>tt', function()
  require('custom.telescope-tasks').task_picker()
end, { desc = 'List tasks' })

vim.keymap.set('n', '<leader>tc', function()
  require('custom.task-runner').create_task()
end, { desc = 'Create task' })

-- Alt+I/O test notifications
vim.keymap.set('n', '<A-o>', function()
  vim.notify('Alt+O pressed - Jump back', vim.log.levels.INFO, { timeout = 1000 })
end, { desc = 'Test Alt+O notification' })

vim.keymap.set('n', '<A-i>', function()
  vim.notify('Alt+I pressed - Jump forward', vim.log.levels.INFO, { timeout = 1000 })
end, { desc = 'Test Alt+I notification' })

-- Telescope quickfix
vim.keymap.set('n', 'sq', '<cmd>Telescope quickfix<cr>', { desc = 'Search [Q]uickfix' })

-- Open file or URL under cursor
vim.keymap.set('n', 'gx', function()
  local path = vim.fn.expand '<cfile>'
  if vim.fn.filereadable(path) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
  else
    -- Handle URLs or external paths
    if vim.fn.has 'wsl' == 1 then
      vim.fn.system('wslview ' .. vim.fn.shellescape(path))
    else
      vim.fn.system('xdg-open ' .. vim.fn.shellescape(path))
    end
  end
end, { desc = 'Open file or URL under cursor' })

-- CSV Viewer - automatically opens CSV files in special viewer format

-- TEST COMMANDS for scrollback options
vim.api.nvim_create_user_command('TestOriginal', function()
  terminal_persist.test_original_attach('_config_c858e7_claude_scrollback')
end, { desc = 'Test Original: Current approach with scrollback=10000' })

vim.api.nvim_create_user_command('TestOption2', function()
  terminal_persist.test_option2_attach('_config_c858e7_claude_scrollback')
end, { desc = 'Test Option 2: Unbuffered PTY output' })

vim.api.nvim_create_user_command('TestOption4', function()
  terminal_persist.test_option4_attach('_config_c858e7_claude_scrollback')
end, { desc = 'Test Option 4: Tmux c0-change throttling' })

vim.api.nvim_create_user_command('TestOption7', function()
  terminal_persist.test_option7_attach('_config_c858e7_claude_scrollback')
end, { desc = 'Test Option 7: Explicit output handlers' })
