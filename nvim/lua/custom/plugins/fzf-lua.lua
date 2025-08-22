return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    winopts = {
      height = 0.85,
      width = 0.80,
      preview = {
        border = "rounded",
        wrap = "nowrap",
        hidden = "nohidden",
        vertical = "down:45%",
        horizontal = "right:50%",
        layout = "flex",
        flip_columns = 120,
      }
    },
    previewer = {
      builtin = {
        extensions = {
          -- neovim terminal only supports viu block output
          ["png"] = { "viu", "-b" },
          ["jpg"] = { "viu", "-b" },
          ["jpeg"] = { "viu", "-b" },
          ["gif"] = { "viu", "-b" },
          ["webp"] = { "viu", "-b" },
          ["bmp"] = { "viu", "-b" },
        }
      }
    }
  }
}