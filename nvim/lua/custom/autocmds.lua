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

-- Prevent treesitter from attaching to Neogit buffers entirely
-- This addresses the root cause by stopping treesitter before it can fail
vim.api.nvim_create_autocmd('BufNew', {
  callback = function(event)
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(event.buf) then
        local ft = vim.bo[event.buf].filetype
        if ft:match('^Neogit') then
          -- Disable treesitter completely for this buffer
          vim.bo[event.buf].syntax = 'on'  -- Use traditional syntax instead
          pcall(vim.treesitter.stop, event.buf)
        end
      end
    end)
  end,
})

-- Early intervention for Neogit filetypes
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'Neogit*',
  callback = function(event)
    -- Stop treesitter before it can attach
    pcall(vim.treesitter.stop, event.buf)
    -- Use manual folding
    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.foldenable = false
    vim.opt_local.foldexpr = ''
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

