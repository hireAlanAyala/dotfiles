return {
  'folke/tokyonight.nvim',
  priority = 1000, -- Make sure to load this before all the other start plugins.
  init = function()
    -- Load the colorscheme here.
    -- Like many other themes, this one has different styles, and you could load
    -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
    vim.cmd.colorscheme 'tokyonight-night'
    vim.o.termguicolors = true

    -- You can configure highlights by doing something like:
    vim.cmd.hi 'Normal guibg=NONE ctermbg=NONE'
    vim.cmd.hi 'NonText guibg=NONE ctermbg=NONE'
    vim.cmd.hi 'Comment gui=none'
  end,
}