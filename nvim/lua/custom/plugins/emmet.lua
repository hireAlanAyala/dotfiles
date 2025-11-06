return {
  -- do not use nvim-emmet it had instrusive completion menu options that could not be disabled
  'mattn/emmet-vim',
  ft = { 'html', 'css', 'javascript', 'javascriptreact', 'typescript', 'typescriptreact', 'vue', 'markdown' },
  config = function()
    -- c-y , triggers expansion
    vim.g.emmet_mode = 'inv' -- 'i' for insert, 'n' for normal, 'v' for visual
  end,
}
