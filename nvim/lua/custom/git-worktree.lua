-- Git Worktree Telescope Picker
-- Provides functionality to list, switch, create, and delete git worktrees

local builtin = require 'telescope.builtin'
local actions = require 'telescope.actions'
local action_state = require 'telescope.actions.state'
local pickers = require 'telescope.pickers'
local finders = require 'telescope.finders'
local conf = require('telescope.config').values
local previewers = require 'telescope.previewers'
local telescope_utils = require 'custom.telescope-utils'

local M = {}

local function close_terminal_buffers()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local ok_buftype, buftype = pcall(vim.api.nvim_buf_get_option, buf, 'buftype')
      if ok_buftype and buftype == 'terminal' then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end
end

local function close_regular_buffers()
  local unclosed_bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      local ok_buftype, buftype = pcall(vim.api.nvim_buf_get_option, buf, 'buftype')
      local ok_check, is_modified = pcall(vim.api.nvim_buf_get_option, buf, 'modified')

      if ok_buftype and buftype ~= 'terminal' then
        if ok_check and not is_modified then
          pcall(vim.api.nvim_buf_delete, buf, {})
        elseif ok_check and is_modified then
          table.insert(unclosed_bufs, buf)
        end
      end
    end
  end
  return unclosed_bufs
end

local function reload_nvim_for_worktree(worktree_path)
  close_terminal_buffers()

  local unclosed_bufs = close_regular_buffers()

  if #unclosed_bufs > 0 then
    vim.notify(string.format('Cannot switch: %d buffer(s) with unsaved changes remain open', #unclosed_bufs), vim.log.levels.WARN)
    return false
  end

  local ok, err = pcall(vim.cmd, 'cd ' .. vim.fn.fnameescape(worktree_path))
  if not ok then
    vim.notify('Failed to change directory: ' .. err, vim.log.levels.ERROR)
    return false
  end

  vim.defer_fn(function()
    pcall(vim.cmd, 'LspRestart')
  end, 100)

  vim.defer_fn(function()
    pcall(vim.cmd, 'Oil .')
  end, 200)

  return true
end

-- Main git worktree picker function
M.git_worktrees = function(opts)
  opts = opts or {}

  -- Get list of worktrees
  local handle = io.popen 'git worktree list 2>/dev/null || echo ""'
  local result = handle:read '*a'
  handle:close()

  if result == '' then
    vim.notify('No git worktrees found', vim.log.levels.INFO)
    return
  end

  -- Get current worktree path
  local current_handle = io.popen 'git rev-parse --show-toplevel 2>/dev/null || echo ""'
  local current_path = current_handle:read('*a'):gsub('%s+$', '')
  current_handle:close()

  -- Parse worktrees
  local worktrees = {}
  local current_index = 1
  local index = 0

  for line in result:gmatch '[^\n]+' do
    index = index + 1
    local path, commit, branch = line:match '^(.-)%s+(%w+)%s+%[(.-)%]$'
    if path then
      local display_name = vim.fn.fnamemodify(path, ':t')
      local is_current = path == current_path

      -- Format the display
      local display = display_name .. ' [' .. branch .. ']'
      if is_current then
        display = display .. ' *'
        current_index = index
      end

      table.insert(worktrees, {
        path = path,
        branch = branch,
        commit = commit,
        display = display,
        name = display_name,
      })
    end
  end

  if #worktrees == 0 then
    vim.notify('Failed to parse git worktrees', vim.log.levels.ERROR)
    return
  end

  pickers
    .new({
      default_selection_index = current_index,
      layout_strategy = 'horizontal',
      layout_config = {
        height = 0.5,
        width = 0.8,
        prompt_position = 'bottom',
        preview_width = 0.4,
      },
      sorting_strategy = 'ascending',
    }, {
      prompt_title = 'Search',
      finder = finders.new_table {
        results = worktrees,
        entry_maker = function(entry)
          return {
            value = entry,
            display = entry.display,
            ordinal = entry.name .. ' ' .. entry.branch,
            path = entry.path,
          }
        end,
      },
      sorter = conf.generic_sorter(opts),
      previewer = previewers.new_buffer_previewer {
        title = 'Commit Messages',
        define_preview = function(self, entry)
          local worktree = entry.value

          -- Get recent commit messages for this worktree
          local git_handle = io.popen('cd "' .. worktree.path .. '" && git log --oneline -20 --pretty=format:"%h %s"')
          local git_log = git_handle:read '*a'
          git_handle:close()

          local lines = {}
          for line in git_log:gmatch '[^\n]+' do
            table.insert(lines, line)
          end

          if #lines == 0 then
            lines = { 'No commit history found' }
          end

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
        end,
      },
      attach_mappings = function(prompt_bufnr, map)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local selection = action_state.get_selected_entry()
          if selection then
            local worktree = selection.value
            reload_nvim_for_worktree(worktree.path)
          end
        end)

        -- Add 'dd' mapping to delete worktree
        local delete_handler = telescope_utils.create_double_key_handler('d', function()
          local selection = action_state.get_selected_entry()
          if selection then
            local worktree = selection.value
            local confirm = vim.fn.confirm("Delete worktree '" .. worktree.name .. "' [" .. worktree.branch .. ']?', '&Yes\n&No', 2)
            if confirm == 1 then
              -- Remove the worktree
              vim.fn.system('git worktree remove ' .. vim.fn.shellescape(worktree.path))
              if vim.v.shell_error == 0 then
                -- Also delete the branch
                vim.fn.system('git branch -D ' .. vim.fn.shellescape(worktree.branch))
                -- Refresh the picker without notification
                actions.close(prompt_bufnr)
                M.git_worktrees(opts)
              else
                vim.notify('Failed to delete worktree', vim.log.levels.ERROR)
              end
            end
          end
        end, {
          timeout = 500,
          message = "Press 'd' again to delete worktree",
        })

        map('n', 'd', delete_handler)

        -- Add 'a' mapping to add new worktree
        map('n', 'a', function()
          actions.close(prompt_bufnr)
          vim.ui.input({ prompt = 'New branch name: ' }, function(branch_name)
            if branch_name and branch_name ~= '' then
              -- Find the main branch by checking which one actually exists
              local default_branch = 'master' -- fallback

              -- Check if master exists
              local master_check = io.popen 'git show-ref --verify --quiet refs/heads/master'
              master_check:close()
              local master_exists = (vim.v.shell_error == 0)

              -- Check if main exists
              local main_check = io.popen 'git show-ref --verify --quiet refs/heads/main'
              main_check:close()
              local main_exists = (vim.v.shell_error == 0)

              -- Prefer master if it exists, otherwise main
              if master_exists then
                default_branch = 'master'
              elseif main_exists then
                default_branch = 'main'
              end

              vim.ui.input({ prompt = 'Base branch (default: ' .. default_branch .. '): ' }, function(base_branch)
                base_branch = base_branch and base_branch ~= '' and base_branch or default_branch
                local cwd = vim.fn.getcwd()
                local parent_dir = vim.fn.fnamemodify(cwd, ':h')
                local path = parent_dir .. '/' .. branch_name
                local cmd =
                  string.format('git worktree add -b %s %s %s', vim.fn.shellescape(branch_name), vim.fn.shellescape(path), vim.fn.shellescape(base_branch))

                local output = vim.fn.system(cmd)
                if vim.v.shell_error == 0 then
                  reload_nvim_for_worktree(path)
                else
                  vim.notify('Failed to create worktree. Exit code: ' .. vim.v.shell_error, vim.log.levels.ERROR)
                  vim.notify('Command output: ' .. output, vim.log.levels.ERROR)
                end
              end)
            end
          end)
        end)

        return true
      end,
    })
    :find()
end

return M
