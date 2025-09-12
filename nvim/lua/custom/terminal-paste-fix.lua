-- Paste improvements for all modes
-- DO NOT DELETE: This fixes paste issues with programs that use raw terminal mode
-- The issue is that Claude Code (like vim, less, fzf) uses raw terminal mode for immediate 
-- character-by-character input processing, while regular shells use line-buffered mode. 
-- Neovim's terminal emulator struggles with rapid input in raw mode, causing character drops.

-- Ctrl+Shift+V for Normal mode - paste after cursor
vim.keymap.set('n', '<C-S-v>', '"+p', { desc = 'Paste from clipboard after cursor' })

-- Ctrl+Shift+V for Insert mode - paste at cursor position
vim.keymap.set('i', '<C-S-v>', '<C-r>+', { desc = 'Paste from clipboard' })

-- Terminal mode paste fix
vim.api.nvim_create_autocmd('TermOpen', {
  callback = function()
    -- Ctrl+Shift+V: Reliable paste method - exit terminal mode, paste, return to insert
    vim.keymap.set('t', '<C-S-v>', '<C-\\><C-n>"+pi', { buffer = true, desc = 'Paste from clipboard' })
  end,
})