local M = {}

-- background transparent - apply after colorscheme loads
function M.set_transparency()
  vim.cmd [[
    highlight Normal guibg=NONE ctermbg=NONE
    highlight NonText guibg=NONE ctermbg=NONE
    highlight SignColumn guibg=NONE ctermbg=NONE
    highlight NormalFloat guibg=NONE ctermbg=NONE
    highlight LineNr guibg=NONE ctermbg=NONE
    highlight CursorLineNr guibg=NONE ctermbg=NONE
    highlight FoldColumn guibg=NONE ctermbg=NONE
    highlight VertSplit guibg=NONE ctermbg=NONE
    highlight StatusLine guibg=NONE ctermbg=NONE
    highlight StatusLineNC guibg=NONE ctermbg=NONE
    highlight TabLine guibg=NONE ctermbg=NONE
    highlight TabLineFill guibg=NONE ctermbg=NONE
    highlight TabLineSel guibg=NONE ctermbg=NONE
    highlight Pmenu guibg=NONE ctermbg=NONE
    highlight PmenuSel guibg=NONE ctermbg=NONE
    highlight GitSignsAdd guibg=NONE ctermbg=NONE
    highlight GitSignsChange guibg=NONE ctermbg=NONE
    highlight GitSignsDelete guibg=NONE ctermbg=NONE
  ]]
end

function M.setup()
  -- Apply transparency now and after colorscheme changes
  M.set_transparency()
  vim.api.nvim_create_autocmd('ColorScheme', {
    callback = M.set_transparency,
  })
end

return M