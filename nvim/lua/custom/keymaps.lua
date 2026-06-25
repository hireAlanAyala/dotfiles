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

-- Window navigation (move focus)
vim.keymap.set('n', '<C-h>', '<C-w>h', { desc = 'Navigate left' })
vim.keymap.set('n', '<C-l>', '<C-w>l', { desc = 'Navigate right' })
vim.keymap.set('n', '<C-j>', '<C-w>j', { desc = 'Navigate down' })
vim.keymap.set('n', '<C-k>', '<C-w>k', { desc = 'Navigate up' })

-- Window moving: swap the current pane with its neighbor in the given direction,
-- preserving the existing layout and sizes (unlike <C-w>HJKL, which flattens to the edge).
-- Focus follows the pane so it stays under your cursor. <C-w>HJKL is still there built-in
-- when you actually want the "throw to wall / flip orientation" behavior.
-- Alt+Shift (not Ctrl+Shift): Alt passes through tmux as an Esc-prefix, whereas Ctrl+Shift
-- needs the CSI-u "extended-keys" protocol that this tmux has turned off.
local function swap_window(dir)
  local cur = vim.api.nvim_get_current_win()
  local cur_cursor = vim.api.nvim_win_get_cursor(cur)
  vim.cmd('wincmd ' .. dir)
  local target = vim.api.nvim_get_current_win()
  if target == cur then return end -- no neighbor that way; wincmd was a no-op

  local target_cursor = vim.api.nvim_win_get_cursor(target)
  local cur_buf = vim.api.nvim_win_get_buf(cur)
  local target_buf = vim.api.nvim_win_get_buf(target)

  vim.api.nvim_win_set_buf(cur, target_buf)
  vim.api.nvim_win_set_buf(target, cur_buf)
  pcall(vim.api.nvim_win_set_cursor, cur, target_cursor)
  pcall(vim.api.nvim_win_set_cursor, target, cur_cursor)

  vim.api.nvim_set_current_win(target) -- follow the moved buffer to its new spot
end

vim.keymap.set('n', '<M-S-h>', function() swap_window('h') end, { desc = 'Swap pane left' })
vim.keymap.set('n', '<M-S-l>', function() swap_window('l') end, { desc = 'Swap pane right' })
vim.keymap.set('n', '<M-S-j>', function() swap_window('j') end, { desc = 'Swap pane down' })
vim.keymap.set('n', '<M-S-k>', function() swap_window('k') end, { desc = 'Swap pane up' })

-- Terminal persist keymaps
local terminal_persist = require 'terminal-persist'
vim.keymap.set('n', '<leader>tn', function()
  vim.ui.input({ prompt = 'Terminal name: ' }, function(input)
    if not input then return end
    if input == '' then
      vim.notify('Terminal name is required', vim.log.levels.WARN)
      return
    end
    local name, cmd = input:match '^(.-)  (.+)$'
    terminal_persist.new(name or input, true, cmd)
  end)
end, { desc = 'new persistent terminal' })

-- Task runner keymaps
vim.keymap.set('n', '<leader>tc', function()
  require('custom.task-runner').create_task()
end, { desc = 'Create task' })


-- Quickfix (using fzf-lua)
vim.keymap.set('n', 'sq', function() require('fzf-lua').quickfix() end, { desc = 'Search [Q]uickfix' })

-- Open file or URL under cursor
local common_tlds = { 'com', 'org', 'io', 'net', 'dev', 'co', 'app', 'sh', 'me', 'info', 'xyz' }

local function is_url(str)
  if str:match '^https?://' or str:match '^www%.' or str:match '^localhost:%d+' then
    return true
  end
  for _, tld in ipairs(common_tlds) do
    if str:match('^[%w%-]+%.' .. tld) or str:match('^[%w%-]+%.[%w%-]+%.' .. tld) then
      return true
    end
  end
  return false
end

local function search_and_open(target)
  -- Check if exists directly
  if vim.fn.filereadable(target) == 1 or vim.fn.isdirectory(target) == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(target))
    return
  end

  -- Search from home directory
  local root = vim.env.HOME

  local basename = target:match '[^/]+$' or target
  local escaped = basename:gsub('([%[%]%(%)%{%}%+%?%^%$%.|\\])', '\\%1')
  local results = vim.fn.systemlist('fd "^' .. escaped .. '$" ' .. vim.fn.shellescape(root))

  if #results == 0 then
    -- Fallback: if looks like URI scheme, try xdg-open
    if target:match '^%w+:' then
      local cmd = vim.fn.has 'wsl' == 1 and 'wslview' or 'xdg-open'
      vim.fn.system(cmd .. ' ' .. vim.fn.shellescape(target))
    else
      vim.notify('Not found: ' .. target, vim.log.levels.WARN)
    end
  elseif #results == 1 then
    vim.cmd('edit ' .. vim.fn.fnameescape(results[1]))
  else
    -- Multiple matches - use files picker with query from home
    require('fzf-lua').files({ query = basename, cwd = vim.env.HOME })
  end
end

vim.keymap.set('n', 'gx', function()
  -- Try markdown link first from CWORD, then fall back to cfile for clean extraction
  local raw = vim.fn.expand '<cWORD>'
  local target = raw:match '%[.-%]%((.-)%)'
  if not target then
    target = vim.fn.expand '<cfile>'
  end
  target = target:gsub('[.,;:!?>]+$', ''):gsub('^~', vim.env.HOME)
  if is_url(target) then
    local url = target:match('^https?://') and target or ('https://' .. target)
    local cmd = vim.fn.has 'wsl' == 1 and 'wslview' or 'xdg-open'
    vim.fn.system(cmd .. ' ' .. vim.fn.shellescape(url))
  else
    search_and_open(target)
  end
end, { desc = 'Open file or URL under cursor' })

-- CSV Viewer - automatically opens CSV files in special viewer format
