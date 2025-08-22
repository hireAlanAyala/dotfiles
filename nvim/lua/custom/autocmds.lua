local augroup = vim.api.nvim_create_augroup('UserConfig', {})

-- Return to last edit position when opening files
vim.api.nvim_create_autocmd('BufReadPost', {
  group = augroup,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Create directories when saving files
vim.api.nvim_create_autocmd('BufWritePre', {
  group = augroup,
  callback = function()
    local dir = vim.fn.expand '<afile>:p:h'
    if vim.fn.isdirectory(dir) == 0 then
      vim.fn.mkdir(dir, 'p')
    end
  end,
})

-- Terminal configuration
vim.api.nvim_create_autocmd('TermOpen', {
  pattern = '*',
  callback = function()
    -- Disable line numbers in terminal
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.opt_local.signcolumn = 'no'

    -- Start in insert mode
    vim.cmd 'startinsert'

    -- Set terminal buffer options
    vim.opt_local.scrollback = 10000

    -- Make normal mode behave more like terminal mode
    -- This preserves the terminal's view of the scrollback
    vim.opt_local.scrolloff = 0
    vim.opt_local.sidescrolloff = 0

    -- Don't set modifiable = false as it can interfere with DAP debugging
  end,
})

-- Disable treesitter folding for Neogit to prevent errors
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'NeogitStatus', 'NeogitCommit', 'NeogitPopup' },
  callback = function()
    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.foldenable = false
  end,
})

-- Fix treesitter folding issues with Neogit - comprehensive coverage
vim.api.nvim_create_autocmd({ 'FileType', 'BufWinEnter' }, {
  pattern = { 'NeogitStatus', 'NeogitCommitMessage', 'NeogitPopup', 'NeogitLogView', 'NeogitCommit', 'Neogit*' },
  callback = function(event)
    pcall(function()
      vim.wo[0].foldmethod = 'manual'
      vim.wo[0].foldenable = false
      if event.buf and vim.api.nvim_buf_is_valid(event.buf) then
        vim.bo[event.buf].foldmethod = 'manual'
      end
    end)
  end,
})

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.highlight.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function()
    vim.highlight.on_yank()
  end,
})

