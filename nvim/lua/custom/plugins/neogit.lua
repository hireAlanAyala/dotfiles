return {
  'NeogitOrg/neogit',
  dependencies = {
    'nvim-lua/plenary.nvim', -- required
    'sindrets/diffview.nvim', -- optional - Diff integration

    -- Only one of these is needed.
    'nvim-telescope/telescope.nvim', -- optional
    'ibhagwan/fzf-lua', -- optional
    'echasnovski/mini.pick', -- optional
  },
  config = function()
    require('neogit').setup {
      -- Disable problematic options that might conflict with folding
      disable_hint = false,
      disable_context_highlighting = false,
      disable_signs = false,
      -- Auto-refresh when the git repository state changes
      auto_refresh = true,
      -- Disable auto-close to prevent buffer issues
      auto_close = false,
      -- Use telescope for branch selection instead of native selectors
      use_telescope = true,
      -- Configure signs
      signs = {
        -- { CLOSED, OPENED }
        section = { '', '' },
        item = { '', '' },
        hunk = { '', '' },
      },
      -- Disable folding entirely for Neogit
      disable_line_numbers = false,
      mappings = {
        -- Disable fold-related mappings
        status = {
          ['za'] = false,
          ['zc'] = false,
          ['zo'] = false,
        },
      },
    }

    -- Force disable folding for all Neogit buffers immediately after setup
    vim.api.nvim_create_autocmd('User', {
      pattern = 'NeogitStatusRefresh',
      callback = function()
        pcall(function()
          vim.wo.foldmethod = 'manual'
          vim.wo.foldenable = false
        end)
      end,
    })
  end,
}