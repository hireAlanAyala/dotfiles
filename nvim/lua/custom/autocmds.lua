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

-- Big-file guard. Opening a very large file used to spin treesitter / LSP / regex
-- syntax into a tight Lua loop, balloon memory to many GB, and wedge nvim with no way
-- to recover the session. Above a size threshold we flag the buffer (vim.b.bigfile,
-- read by treesitter's disable function) and strip the expensive machinery so the file
-- opens instantly. Adjust BIGFILE_BYTES to taste.
local BIGFILE_BYTES = 1.5 * 1024 * 1024

vim.api.nvim_create_autocmd('BufReadPre', {
  group = augroup,
  callback = function(ev)
    local stat = vim.loop.fs_stat(ev.match)
    if stat and stat.size > BIGFILE_BYTES then
      vim.b[ev.buf].bigfile = true
    end
  end,
})

vim.api.nvim_create_autocmd('FileType', {
  group = augroup,
  callback = function(ev)
    if not vim.b[ev.buf].bigfile then return end
    pcall(vim.treesitter.stop, ev.buf)
    vim.bo[ev.buf].syntax = 'off'
    vim.bo[ev.buf].swapfile = false
    vim.bo[ev.buf].undofile = false
    vim.opt_local.foldmethod = 'manual'
    vim.opt_local.foldexpr = ''
    vim.opt_local.spell = false
    -- Detach any LSP clients that managed to attach before we got here
    vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(ev.buf) then return end
      for _, client in pairs(vim.lsp.get_clients({ bufnr = ev.buf })) do
        pcall(vim.lsp.buf_detach_client, ev.buf, client.id)
      end
    end)
    vim.notify(
      ('Big file (%.1f MB): treesitter, syntax & LSP disabled'):format(
        (vim.loop.fs_stat(vim.api.nvim_buf_get_name(ev.buf)) or { size = 0 }).size / 1024 / 1024),
      vim.log.levels.WARN
    )
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

