-- Image preview using Kitty graphics protocol
-- Requires: kitty terminal (or tmux with passthrough enabled)
-- Optional dependencies: magick (luarocks), imagemagick

return {
  '3rd/image.nvim',
  event = 'VeryLazy',
  build = false, -- disable luarocks build, we handle it separately
  opts = {
    backend = 'kitty',
    processor = 'magick_cli', -- use imagemagick CLI instead of luarocks magick
    integrations = {
      markdown = {
        enabled = true,
        clear_in_insert_mode = false,
        download_remote_images = true,
        only_render_image_at_cursor = false,
        floating_windows = false,
        filetypes = { 'markdown', 'vimwiki' },
      },
      neorg = {
        enabled = true,
        filetypes = { 'norg' },
      },
      html = {
        enabled = false,
      },
      css = {
        enabled = false,
      },
    },
    max_width = nil, -- auto
    max_height = nil, -- auto
    max_width_window_percentage = nil,
    max_height_window_percentage = 50,
    window_overlap_clear_enabled = true, -- clear images when windows overlap
    window_overlap_clear_ft_ignore = { 'cmp_menu', 'cmp_docs', '' },
    editor_only_render_when_focused = false,
    tmux_show_only_in_active_window = true,
    hijack_file_patterns = { '*.png', '*.jpg', '*.jpeg', '*.gif', '*.webp', '*.avif' },
  },
}
