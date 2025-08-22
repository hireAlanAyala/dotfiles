return {
  'folke/which-key.nvim',
  event = 'VimEnter', -- Sets the loading event to 'VimEnter'
  opts = {
    icons = {
      -- set icon mappings to false to disable icons
      mappings = false,
      -- If you are using a Nerd Font: set icons.keys to an empty table which will use the
      -- default whick-key.nvim defined Nerd Font icons, otherwise define a string table
      keys = vim.g.have_nerd_font and {} or {
        Up = '<Up> ',
        Down = '<Down> ',
        Left = '<Left> ',
        Right = '<Right> ',
        C = '<C-…> ',
        M = '<M-…> ',
        D = '<D-…> ',
        S = '<S-…> ',
        CR = '<CR> ',
        Esc = '<Esc> ',
        ScrollWheelDown = '<ScrollWheelDown> ',
        ScrollWheelUp = '<ScrollWheelUp> ',
        NL = '<NL> ',
        BS = '<BS> ',
        Space = '<Space> ',
        Tab = '<Tab> ',
        F1 = '<F1>',
        F2 = '<F2>',
        F3 = '<F3>',
        F4 = '<F4>',
        F5 = '<F5>',
        F6 = '<F6>',
        F7 = '<F7>',
        F8 = '<F8>',
        F9 = '<F9>',
        F10 = '<F10>',
        F11 = '<F11>',
        F12 = '<F12>',
      },
    },

    -- Document existing key chains
    -- Groups are now defined in config/keymaps.lua

    config = function(_, opts)
      -- Set up which-key with the provided opts
      local wk = require 'which-key'
      wk.setup(opts)

      -- Function to yank diagnostic messages
      local function yank_diagnostic()
        print 'yank_diagnostic'
        local diagnostics = vim.diagnostic.get(0, { lnum = vim.api.nvim_win_get_cursor(0)[1] - 1 })
        if #diagnostics == 0 then
          vim.notify('No diagnostics found at cursor position', vim.log.levels.WARN)
          return
        end

        -- Concatenate all diagnostic messages with newlines
        local messages = {}
        for _, diagnostic in ipairs(diagnostics) do
          table.insert(messages, diagnostic.message)
        end
        local message_text = table.concat(messages, '\n')

        -- Yank to system clipboard and default register
        vim.fn.setreg('+', message_text)
        vim.fn.setreg('"', message_text)

        vim.notify('Diagnostic message yanked to clipboard', vim.log.levels.INFO)
      end

      -- Register our yank diagnostic mapping
      wk.add {
        { 'yd', yank_diagnostic, desc = 'Yank diagnostic message', mode = 'n' },
      }

      -- Note: which-key groups are now set up within each plugin-specific keymap function
    end,
  },
}