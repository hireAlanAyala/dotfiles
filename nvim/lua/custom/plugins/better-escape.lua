return {
  'max397574/better-escape.nvim',
  config = function()
    require('better_escape').setup({
      default_mappings = false,
      mappings = {
        i = { j = { k = "<Esc>", j = "<Esc>" } },
        c = { j = { k = "<Esc>", j = "<Esc>" } },
        v = { j = { k = "<Esc>" } },
        s = { j = { k = "<Esc>" } },
        t = { j = { k = "<C-\\><C-n>" } },
      },
    })
  end,
}