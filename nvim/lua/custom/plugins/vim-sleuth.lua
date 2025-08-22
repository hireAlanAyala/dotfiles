return {
  'tpope/vim-sleuth', -- Detect tabstop and shiftwidth automatically
  config = function()
    -- Override Sleuth for F# files (force spaces)
    vim.api.nvim_create_autocmd('FileType', {
      pattern = 'fsharp',
      callback = function()
        vim.bo.expandtab = true
        vim.bo.tabstop = 4
        vim.bo.shiftwidth = 4
        vim.bo.softtabstop = 4
      end,
    })
  end,
}