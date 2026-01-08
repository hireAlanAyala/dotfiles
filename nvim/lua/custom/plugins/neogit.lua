return {
  'NeogitOrg/neogit',
  cmd = 'Neogit',
  dependencies = {
    'nvim-lua/plenary.nvim', -- required
    'sindrets/diffview.nvim', -- optional - Diff integration
    'ibhagwan/fzf-lua', -- optional
  },
  config = function()
    -- Clear any existing OptionSet autocmds for foldminlines before Neogit loads
    vim.api.nvim_clear_autocmds({ event = 'OptionSet', pattern = 'foldminlines' })
    
    -- Wrap nvim_buf_call to prevent errors with invalid buffers
    local original_nvim_buf_call = vim.api.nvim_buf_call
    vim.api.nvim_buf_call = function(buffer, fn)
      if not vim.api.nvim_buf_is_valid(buffer) then
        return
      end
      return original_nvim_buf_call(buffer, fn)
    end
    
    require('neogit').setup {
      integrations = {
        telescope = false,
        diffview = true,
        fzf_lua = true,
      },
      -- Disable features that might trigger treesitter
      disable_hint = true,
      disable_context_highlighting = true,
      disable_signs = false,
      disable_commit_confirmation = true,
      disable_insert_on_commit = true,
      -- Auto-refresh when the git repository state changes
      auto_refresh = true,
      -- Disable auto-close to prevent buffer issues
      auto_close = false,
      -- Configure signs
      signs = {
        -- { CLOSED, OPENED }
        section = { '>', 'v' },
        item = { '>', 'v' },
        hunk = { '', '' },
      },
      -- Disable folding entirely for Neogit
      disable_line_numbers = false,
      -- Kind of ui to use
      kind = "tab",
      -- Disable all default keymaps to prevent fold issues
      disable_builtin_notifications = true,
      mappings = {
        -- Disable fold-related mappings
        status = {
          ['za'] = false,
          ['zc'] = false,
          ['zo'] = false,
          ['zC'] = false,
          ['zO'] = false,
          ['zM'] = false,
          ['zR'] = false,
        },
      },
    }

    -- Force disable folding for all Neogit buffers
    vim.api.nvim_create_autocmd({'FileType', 'BufEnter', 'BufWinEnter'}, {
      pattern = {'NeogitStatus', 'NeogitCommitView', 'NeogitPopup', 'NeogitLogView'},
      callback = function()
        -- Disable all folding methods
        vim.opt_local.foldmethod = 'manual'
        vim.opt_local.foldenable = false
        vim.opt_local.foldlevel = 99
        -- Disable treesitter folding specifically
        pcall(function()
          vim.treesitter.stop()
        end)
      end,
    })
    
    -- Also on the User event
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