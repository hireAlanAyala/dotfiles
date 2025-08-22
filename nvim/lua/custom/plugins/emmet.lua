return {
  'olrtg/nvim-emmet',
  config = function()
    -- Simple single-key expansion
    vim.keymap.set({ 'i', 'n' }, '<C-e>', function()
      require('nvim-emmet').expand_abbr()
    end, { desc = 'Emmet expand abbreviation' })
  end,
}