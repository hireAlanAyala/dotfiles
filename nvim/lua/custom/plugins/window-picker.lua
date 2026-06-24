-- Jump focus to a specific window by pressing the letter shown on it.
-- <leader>w paints a big letter on each pane; press it to jump there.
return {
  's1n7ax/nvim-window-picker',
  name = 'window-picker',
  version = '2.*',
  config = function()
    require('window-picker').setup {
      -- Big centered letter on each window -- easiest to spot at a glance.
      hint = 'floating-big-letter',
      selection_chars = 'FJDKSLAHGNUVRBYTMCEIWOQPZX',
      filter_rules = {
        -- Don't offer the window you're already in.
        include_current_win = false,
        -- If there's only one other window, just go there without prompting.
        autoselect_one = true,
        -- Include everything (the defaults exclude terminals/quickfix, but we want
        -- to be able to jump to terminal panes too).
        bo = {
          filetype = {},
          buftype = {},
        },
      },
    }
  end,
  keys = {
    {
      '<leader>w',
      function()
        local picked = require('window-picker').pick_window()
        if picked then
          vim.api.nvim_set_current_win(picked)
        end
      end,
      desc = 'Pick window',
    },
  },
}
