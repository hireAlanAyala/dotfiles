-- Telescope is a fuzzy finder that comes with a lot of different things that
-- it can fuzzy find! It's more than just a "file finder", it can search
-- many different aspects of Neovim, your workspace, LSP, and more!
--
-- The easiest way to use Telescope, is to start by doing something like:
--  :Telescope help_tags
--
-- After running this command, a window will open up and you're able to
-- type in the prompt window. You'll see a list of `help_tags` options and
-- a corresponding preview of the help.
--
-- Two important keymaps to use while in Telescope are:
--  - Insert mode: <c-/>
--  - Normal mode: ?
--
-- This opens a window that shows you all of the keymaps for the current
-- Telescope picker. This is really useful to discover what Telescope can
-- do as well as how to actually do it!

local builtin = require 'telescope.builtin'
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'

local function remove_qf_item(prompt_bufnr)
  local selected_entry = action_state.get_selected_entry()

  if not selected_entry then
    print 'No entry selected!'
    return
  end

  -- Get the current quickfix list
  local qflist = vim.fn.getqflist()

  -- Remove the selected entry
  local new_qflist = {}
  for _, item in ipairs(qflist) do
    if item.lnum ~= selected_entry.lnum or item.bufnr ~= selected_entry.bufnr then
      table.insert(new_qflist, item)
    end
  end

  -- Update the quickfix list
  vim.fn.setqflist(new_qflist, 'r')

  -- Close the current Telescope prompt
  actions.close(prompt_bufnr)

  -- Reopen the Quickfix picker
  vim.defer_fn(function()
    require('telescope.builtin').quickfix()
  end, 50) -- Small delay to avoid flicker
end

local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values

-- our picker function: colors
local colors = function(opts)
  opts = opts or {}
  pickers
    .new(opts, {
      prompt_title = 'colors',
      finder = finders.new_table {
        results = {
          { 'red', '#ff0000' },
          { 'green', '#00ff00' },
          { 'blue', '#0000ff' },
        },
        entry_maker = function(entry)
          return {
            value = entry, -- best practice reference to the original entry, for later use
            display = entry[1],
            ordinal = entry[1],
          }
        end,
      },
      sorter = conf.generic_sorter(opts),
      -- prompt_bufnr represents the picker as it is a buffer in nvim
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          print(prompt_bufnr)
          -- returns a table hash
          -- this differs from the string passed in because internally it's packed into a table with multiple key:value pairs
          -- it's possible to get selection after closing the buffer
          local selection = action_state.get_selected_entry()
          print('selection', selection)
          -- inspect takes tables, functions, etc and turns them to strings for printing
          print('inspected selection', vim.inspect(selection))
          vim.api.nvim_put({ selection[1] }, '', false, true)
        end)

        return true
      end,
    })
    :find()
end

local function git_log_source_picker(opts)
  opts = opts or {}

  pickers
    .new(opts, {
      prompt_title = 'Git File Content Search (-S)',
      finder = finders.new_job(
        function(prompt)
          if not prompt or prompt == '' then
            return nil
          end
          return { 'git', 'log', '-S', prompt, '--source', '--all', '--pretty=format:%h %ad %s', '--date=short' }
        end,
        nil, -- This should be `nil` because entry_maker will handle formatting
        {
          entry_maker = function(entry)
            -- Split the log entry into commit hash, date, and message
            local parts = vim.split(entry, ' ', { trimempty = true })

            -- Ensure we have at least <commit_hash> <date> <message>
            if #parts < 3 then
              return nil
            end

            local commit_hash = parts[1]
            local date = parts[2]
            local message = table.concat(parts, ' ', 3) -- Preserve full commit message
            local display = string.format('%-10s %-12s %s', commit_hash, date, message)

            -- Debugging Output
            print('display', display)

            local result = {
              value = commit_hash, -- The actual commit hash
              display = display, -- How it looks in Telescope UI
              ordinal = commit_hash .. ' ' .. date .. ' ' .. message, -- Used for searching
              commit = commit_hash, -- Store the commit hash for selection
            }

            -- Debugging Output
            print('result', vim.inspect(result))

            return result
          end,
        }
      ),
      sorter = conf.generic_sorter(opts),
      attach_mappings = function(_, map)
        map('i', '<CR>', function(prompt_bufnr)
          local selection = action_state.get_selected_entry()

          if not selection or not selection.commit then
            print '⚠️ No valid commit selected!'
            return
          end

          actions.close(prompt_bufnr)
          vim.cmd('Git show ' .. selection.commit) -- Open commit details
        end)
        return true
      end,
    })
    :find()
end

local previewers = require 'telescope.previewers'
local utils = require 'telescope.utils'

-- local function git_history_search(opts)
--   opts = opts or {}
--
--   -- Prompt for the search term if not provided
--   local search_term = opts.search_term or vim.fn.input 'Search git history for: '
--   if search_term == '' then
--     return
--   end
--
--   -- Create the git command
--   local git_cmd = {
--     'git',
--     'log',
--     '-S',
--     search_term,
--     '--source',
--     '--all',
--     '--pretty=format:%h %ad %s',
--     '--date=short',
--   }
--
--   -- Create custom previewer that properly handles multiple preview requests
--   local previewer = previewers.new_buffer_previewer {
--     title = 'Git Commit Preview',
--     get_buffer_by_name = function(_, entry)
--       return entry.value
--     end,
--     define_preview = function(self, entry)
--       local commit_hash = entry.value:match '^(%w+)'
--
--       -- Clear the buffer content
--       vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, {})
--
--       -- Run git show and handle the output
--       local stdout, ret, stderr = utils.get_os_command_output {
--         'git',
--         'show',
--         commit_hash,
--       }
--
--       if ret == 0 then
--         vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, stdout)
--         -- Optional: Set filetype for syntax highlighting
--         vim.api.nvim_buf_set_option(self.state.bufnr, 'filetype', 'git')
--       else
--         vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, stderr)
--       end
--     end,
--   }
--
--   pickers
--     .new(opts, {
--       prompt_title = 'Git History Search: ' .. search_term,
--       finder = finders.new_oneshot_job(git_cmd, opts),
--       sorter = conf.generic_sorter(opts),
--       previewer = previewer,
--       attach_mappings = function(buffer_number)
--         -- Add custom key mappings here
--         actions.select_default:replace(function()
--           local selection = action_state.get_selected_entry()
--           local commit_hash = selection.value:match '^(%w+)'
--
--           -- Close telescope
--           actions.close(buffer_number)
--
--           -- Open commit in a new split
--           vim.cmd 'vsplit'
--           vim.cmd('terminal git show ' .. commit_hash)
--           vim.cmd 'startinsert'
--         end)
--
--         return true
--       end,
--     })
--     :find()
-- end

-- [[ Configure Telescope ]]
-- See `:help telescope` and `:help telescope.setup()`
require('telescope').setup {
  -- You can put your default mappings / updates / etc. in here
  --  All the info you're looking for is in `:help telescope.setup()`
  --
  defaults = {
    mappings = {
      n = {
        ['n'] = 'move_selection_next',
        ['N'] = 'move_selection_previous',
      },
    },
    file_ignore_patterns = { 'node_modules' },
    vimgrep_arguments = {
      'rg',
      '--color=never',
      '--no-heading',
      '--with-filename',
      '--line-number',
      '--column',
      '--smart-case',
      '--hidden',
      '--glob=!node_modules',
    },
  },
  pickers = {
    find_files = {
      hidden = true,
      find_command = { 'rg', '--files', '--hidden', '--no-ignore', '--glob', '!node_modules' },
    },
    live_grep = {
      vimgrep_arguments = {
        'rg',
        '--color=never',
        '--no-heading',
        '--with-filename',
        '--line-number',
        '--column',
        '--smart-case',
        '--hidden',
        '--no-ignore',
        '--glob=!node_modules',
      },
    },
    buffers = {
      mappings = {
        n = {
          ['dd'] = 'delete_buffer',
        },
      },
    },
    quickfix = {
      mappings = {
        n = { ['d'] = remove_qf_item },
      },
    },
  },
  extensions = {
    ['ui-select'] = {
      require('telescope.themes').get_dropdown(),
    },
    media_files = {
      -- filetypes whitelist
      filetypes = { 'png', 'jpg', 'jpeg', 'gif', 'webp', 'pdf', 'mp4', 'webm' },
      -- find command
      find_cmd = 'find',
    },
    live_grep_args = {
      auto_quoting = true, -- enable/disable auto-quoting
      -- Override the default vimgrep_arguments to ensure compatibility
      vimgrep_arguments = {
        'rg',
        '--color=never',
        '--no-heading',
        '--with-filename',
        '--line-number',
        '--column',
        '--smart-case',
        '--hidden',
        '--glob=!node_modules',
      },
      -- define mappings, e.g.
      mappings = { -- extend mappings
        i = {
          ['<C-k>'] = function(prompt_bufnr)
            require('telescope-live-grep-args.actions').quote_prompt()(prompt_bufnr)
          end,
          ['<C-i>'] = function(prompt_bufnr)
            require('telescope-live-grep-args.actions').quote_prompt { postfix = ' --iglob ' }(prompt_bufnr)
          end,
          ['<C-t>'] = function(prompt_bufnr)
            require('telescope-live-grep-args.actions').quote_prompt { postfix = ' -t ' }(prompt_bufnr)
          end,
        },
      },
    },
  },
}

-- Enable Telescope extensions if they are installed
pcall(require('telescope').load_extension, 'fzf')
pcall(require('telescope').load_extension, 'ui-select')
pcall(require('telescope').load_extension, 'live_grep_args')
pcall(require('telescope').load_extension, 'media_files')

-- Setup telescope keymaps
require('config.keymaps').setup_telescope_keymaps()

-- Export custom pickers for use in keymaps or commands
return {
  colors = colors,
  git_log_source_picker = git_log_source_picker,
}