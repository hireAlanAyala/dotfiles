-- INFO: this is the file that TJ uses

-- Center screen when jumping
-- WARNING: I tried to setup centering the cursor line when navigating but it messed with builtin nvim functionality

-- Better window navigation
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Navigate left' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Navigate right' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Navigate down' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Navigate up' })

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

-- Move lines to top/bottom of buffer (mirrors gg / G)
vim.keymap.set('n', '<A-g><A-g>', ':m 0<CR>==', { desc = 'Move line to top' })
vim.keymap.set('n', '<A-G>', ':m $<CR>==', { desc = 'Move line to bottom' })
vim.keymap.set('v', '<A-g><A-g>', ":m 0<CR>gv=gv", { desc = 'Move selection to top' })
vim.keymap.set('v', '<A-G>', ":m '>$<CR>gv=gv", { desc = 'Move selection to bottom' })

-- Better indenting in visual mode
vim.keymap.set('v', '<', '<gv', { desc = 'Indent left and reselect' })
vim.keymap.set('v', '>', '>gv', { desc = 'Indent right and reselect' })

-- Better J behavior
vim.keymap.set('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })
