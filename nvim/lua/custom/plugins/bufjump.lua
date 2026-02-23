return {
  "kwkarlwang/bufjump.nvim",
  lazy = false,
  config = function()
    require("bufjump").setup()
    vim.keymap.set("n", "<M-o>", require("bufjump").backward, { desc = "Jump to previous buffer" })
    vim.keymap.set("n", "<M-i>", require("bufjump").forward, { desc = "Jump to next buffer" })
  end,
}
