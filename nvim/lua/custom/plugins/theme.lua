-- return {
--   'folke/tokyonight.nvim',
--   priority = 1000, -- Make sure to load this before all the other start plugins.
--   init = function()
--     -- Load the colorscheme here.
--     -- Like many other themes, this one has different styles, and you could load
--     -- any other, such as 'tokyonight-storm', 'tokyonight-moon', or 'tokyonight-day'.
--     vim.cmd.colorscheme 'tokyonight-night'
--     vim.o.termguicolors = true
--
--     -- You can configure highlights by doing something like:
--     vim.cmd.hi 'Normal guibg=NONE ctermbg=NONE'
--     vim.cmd.hi 'NonText guibg=NONE ctermbg=NONE'
--     vim.cmd.hi 'Comment gui=none'
--   end,
-- }

return {
  'EdenEast/nightfox.nvim',
  lazy = false,
  priority = 1000,
  dependencies = {
    'folke/snacks.nvim',
    'nvim-tree/nvim-web-devicons',
    'nvim-lualine/lualine.nvim',
  },

  config = function()
    local nightfox = require 'nightfox'
    local Shade = require 'nightfox.lib.shade'
    local c = require 'nightfox.lib.color'

    -- ==========================================================================
    -- Monochromatic Amber/Yellow Theme Strategy (base: #FFCC00)
    -- ==========================================================================
    -- All semantic colors map to shades of yellow/amber. Hierarchy uses brightness.
    --
    -- Color Hierarchy (hottest → coolest):
    --   #FF8800 → #FF9900 → #FFBB00 → #FFCC00 → #FFB000 → #CC9900 → #996600 → #805500
    --   keywords  accents    orange    yellow    white     green      dim       comments
    --
    -- Shade System: Shade.new(base, bright, dim)
    --   - base:   default color for the role
    --   - bright: used for .bright variant (highlights)
    --   - dim:    used for .dim variant (e.g., strings as orange.dim)
    --
    -- Semantic Mappings:
    --   red     → keywords (if, function, local) - hottest, grabs attention
    --   orange  → functions, strings, numbers - prominent
    --   yellow  → operators (+, =, etc) - primary
    --   white   → variables, constants, types - common text
    --   green   → muted accents
    --   cyan    → secondary elements
    --   magenta → hints, special elements
    --   pink    → tertiary elements
    --
    -- Foreground Hierarchy:
    --   fg0 (#FFCC00) → fg1 (#FFB000) → fg2 (#CC9900) → fg3 (#996600)
    -- ==========================================================================
    local retropc_palette = {
      -- Base "RetroPC" Palette Overrides
      bg0 = '#0A0A08',
      bg1 = '#0A0A08',
      bg2 = '#1A1612',
      bg3 = '#2A1F00',
      bg4 = '#2A1F00',
      fg0 = '#FFCC00',  -- brightest
      fg1 = '#FFB000',  -- primary
      fg2 = '#CC9900',  -- muted
      fg3 = '#996600',  -- dim
      sel0 = '#2A1F00',
      sel1 = c.from_hex('#2A1F00'):blend(c.from_hex '#FFCC00', 0.2):to_css(),
      comment = '#805500',  -- dimmest
      red = Shade.new('#FF8800', c.from_hex('#FF8800'):lighten(8):to_css(), '#FF6600'),  -- hottest (keywords)
      orange = Shade.new('#FFBB00', '#FFCC00', c.from_hex('#FFBB00'):lighten(-8):to_css()),  -- primary (functions)
      yellow = Shade.new('#FFCC00', c.from_hex('#FFCC00'):lighten(10):to_css(), '#FFB000'),  -- operators
      white = Shade.new('#FFB000', '#FFCC00', '#CC9900'),  -- variables
      black = Shade.new('#2A1F00', '#805500', '#1A1612'),
      green = Shade.new('#CC9900', '#D4AA00', '#996600'),  -- muted
      cyan = Shade.new('#FFAA00', '#FFBB00', '#CC8800'),   -- secondary
      blue = Shade.new('#CC9900', '#D4AA00', '#996600'),   -- muted (alias)
      magenta = Shade.new('#FF9900', '#FFAA00', '#CC7700'),  -- hints
      pink = Shade.new('#FFAA00', '#FFBB00', '#CC8800'),   -- tertiary

      -- Lualine Palette Extensions
      lualine_normal_bg = '#FFBB00',
      lualine_insert_bg = '#FF8800',
      lualine_visual_bg = '#FF9900',
      lualine_command_bg = '#FFBB00',
      lualine_inactive_bg = c.from_hex('#0A0A08'):lighten(5):to_css(),

      -- Treesitter Palette Extensions
      ts_parameter = '#FFAA00',  -- accents
      ts_property = '#FFB000',   -- fg0
    }

    local final_palettes = {
      carbonfox = require('nightfox.lib.collect').deep_extend(require('nightfox.palette').load 'carbonfox', retropc_palette),
    }

    local specs = {
      carbonfox = {
        syntax = {
          keyword = 'red', -- "local", "function", "if"
          conditional = 'red',
          statement = 'red',
          func = 'orange',
          string = 'orange.dim',
          number = 'orange',
          operator = 'yellow',
          variable = 'white',
          ident = 'white.dim',
          const = 'white',
          type = 'white',
          field = 'white.dim',
          comment = 'comment',
        },
        diag = {
          error = 'red',
          warn = 'red',
          info = 'cyan',
          hint = 'magenta',
        },
      },
    }

    local groups = {
      all = {
        -- Base Groups
        Whitespace = { fg = 'palette.black.bright' },
        NonText = { fg = 'palette.black.bright' },
        IncSearch = { bg = 'palette.sel1' },
        CursorLine = { bg = c.from_hex('#0A0A08'):blend(c.from_hex '#FFCC00', 0.08):to_css() },
        Normal = { fg = 'palette.fg1' },

        -- Noice Cmdline Overrides
        NoiceCmdlinePopupBorder = { fg = 'palette.fg3' },
        NoiceCmdlinePopupTitle = { fg = 'palette.fg3', style = 'bold' },
        NoiceCmdlinePopupBorderSearch = { fg = 'palette.fg3' },
        NoiceCmdlinePopupTitleSearch = { fg = 'palette.fg3', style = 'bold' },
        NoiceCmdLineIcon = { fg = 'palette.red' },

        -- Neo-tree overrides
        NeoTreeNormal = { bg = 'palette.bg0' },
        NeoTreeNormalNC = { link = 'NeoTreeNormal' },
        NeoTreeDirectoryName = { fg = 'palette.fg3' },
        NeoTreeDirectoryIcon = { fg = 'palette.fg3' },
        NeoTreeRootName = { fg = 'palette.orange', style = 'bold' },
        NeoTreeGitAdded = { fg = 'palette.green' },
        NeoTreeGitModified = { fg = 'palette.yellow' },
        NeoTreeGitDeleted = { fg = 'palette.red' },
        NeoTreeGitIgnored = { fg = 'palette.comment' },
        NeoTreeC = { fg = 'palette.orange', bg = 'palette.sel0' },

        -- Dashboard overrides
        SnacksDashboardHeader = { fg = 'palette.fg3' },
        SnacksDashboardIcon = { fg = 'palette.fg1' },
        SnacksDashboardDir = { fg = 'palette.orange' },
        SnacksDashboardFile = { fg = 'palette.fg3' },
        SnacksDashboardFooter = { fg = 'palette.fg3' },
        SnacksDashboardKey = { fg = 'palette.orange' },
        SnacksDashboardDesc = { fg = 'palette.fg1' },
        SnacksDashboardSpecial = { fg = 'palette.fg1' },

        -- Treesitter overrides
        ['@comment'] = { fg = 'palette.comment', style = 'italic' },
        ['@keyword'] = { fg = 'palette.red', style = 'bold' },
        ['@keyword.function'] = { fg = 'palette.red', style = 'bold' },
        ['@keyword.operator'] = { fg = 'palette.red', style = 'bold' },
        ['@function'] = { fg = 'palette.orange', style = 'bold' },
        ['@function.builtin'] = { fg = 'palette.orange', style = 'bold' },
        ['@function.call'] = { fg = 'palette.orange' },
        ['@string'] = { fg = 'palette.orange' },
        ['@number'] = { fg = 'palette.orange' },
        ['@operator'] = { fg = 'palette.yellow' },
        ['@variable'] = { fg = 'palette.white' },
        ['@constant'] = { fg = 'palette.white' },
        ['@type'] = { fg = 'palette.white.dim' },
        ['@variable.parameter'] = { fg = 'palette.ts_parameter', style = 'italic' },
        ['@property'] = { fg = 'palette.ts_property' },
        ['@field'] = { fg = 'palette.ts_property' },
      },
    }

    nightfox.setup {
      options = {
        style = 'carbonfox',
        terminal_colors = true,
        dim_inactive = true,
        styles = { comments = 'italic', functions = 'bold', keywords = 'bold' },
        modules = {
          neotree = true,
          treesitter = true,
        },
      },
      palettes = final_palettes,
      specs = specs,
      groups = groups,
    }

    vim.cmd 'colorscheme carbonfox'

    -- Clear NormalNC background so inactive windows stay transparent
    vim.api.nvim_set_hl(0, 'NormalNC', { fg = '#FFB000' })

    -- Lualine overrides
    local lualine_theme = {
      normal = {
        a = { fg = retropc_palette.bg0, bg = retropc_palette.lualine_normal_bg, gui = 'bold' },
        b = { fg = retropc_palette.fg1, bg = retropc_palette.lualine_inactive_bg },
        c = { fg = retropc_palette.fg2, bg = retropc_palette.lualine_inactive_bg },
      },
      insert = {
        a = { fg = retropc_palette.bg0, bg = retropc_palette.lualine_insert_bg, gui = 'bold' },
        b = { fg = retropc_palette.fg1, bg = retropc_palette.lualine_inactive_bg },
        c = { fg = retropc_palette.fg2, bg = retropc_palette.lualine_inactive_bg },
      },
      visual = {
        a = { fg = retropc_palette.bg0, bg = retropc_palette.lualine_visual_bg, gui = 'bold' },
        b = { fg = retropc_palette.fg1, bg = retropc_palette.lualine_inactive_bg },
        c = { fg = retropc_palette.fg2, bg = retropc_palette.lualine_inactive_bg },
      },
      command = {
        a = { fg = retropc_palette.bg0, bg = retropc_palette.lualine_command_bg, gui = 'bold' },
        b = { fg = retropc_palette.fg1, bg = retropc_palette.lualine_inactive_bg },
        c = { fg = retropc_palette.fg2, bg = retropc_palette.lualine_inactive_bg },
      },
      inactive = {
        a = { fg = retropc_palette.fg3, bg = retropc_palette.lualine_inactive_bg },
        b = { fg = retropc_palette.fg3, bg = retropc_palette.lualine_inactive_bg },
        c = { fg = retropc_palette.comment, bg = retropc_palette.lualine_inactive_bg },
      },
    }


    require('lualine').setup {
      options = {
        theme = lualine_theme,
      },
      sections = {
        lualine_a = { 'mode' },
        lualine_b = { 'diagnostics' },
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'searchcount', 'selectioncount' },
        lualine_y = {},
        lualine_z = { 'location' },
      },
      inactive_sections = {
        lualine_a = {},
        lualine_b = {},
        lualine_c = { { 'filename', path = 1 } },
        lualine_x = { 'location' },
        lualine_y = {},
        lualine_z = {},
      },
    }
  end,
}

