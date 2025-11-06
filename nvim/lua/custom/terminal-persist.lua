local M = {}

-- Configuration
M.config = {
  session_prefix = 'nvim',
  auto_name_from_cwd = true,
  state_file = vim.fn.stdpath 'data' .. '/terminal-persist-state.json',
  project_state_file = '.nvim/terminal-sessions.json', -- Per-project state
  auto_restore = true,

  -- ATTACHMENT METHOD - Only using with-history for scrollback support
  attach_method = 'with-history',
}

-- Define attachment method using termopen for better control
M.attach_method = function(session_name, buf_nr)
  local socket = require('custom.socket')
  local nvim_addr = socket.get()
  local cmd = string.format('NVIM=%s ~/.config/scripts/tmux-attach-with-history.sh %s', nvim_addr, session_name)

  -- Use termopen for terminal attachment
  -- WARNING: Do NOT use stdout_buffered/stderr_buffered options - they are deprecated in Neovim 0.10+
  local job_id = vim.fn.termopen(cmd)

  -- Set scrollback to maximum AFTER terminal is created
  -- WARNING: do not move into autocmd, it must be set once & early to prevent resetting the location
  if buf_nr then
    vim.bo[buf_nr].scrollback = 100000
  else
    vim.bo.scrollback = 100000
  end

  -- Update $NVIM in tmux session environment for this specific session
  if nvim_addr and nvim_addr ~= '' then
    -- Update environment for this specific tmux session
    -- vim.fn.system(string.format('tmux set-environment -t %s NVIM "%s"', session_name, nvim_addr))
  end

  return job_id
end

-- Get project identifier (used for grouping sessions)
local function get_project_id()
  local cwd = vim.fn.getcwd()
  -- Use full path hash for uniqueness but keep directory name for readability
  local path_hash = vim.fn.sha256(cwd):sub(1, 6)
  local dir_name = vim.fn.fnamemodify(cwd, ':t'):gsub('[^%w%-_]', '_')
  return string.format('%s_%s', dir_name, path_hash)
end

-- Generate session name from current directory
local function generate_session_name(custom_suffix)
  local project_id = get_project_id()

  if custom_suffix then
    -- User provided a name, use it as suffix
    return string.format('%s_%s', project_id, custom_suffix)
  else
    -- Auto-generate with timestamp
    local timestamp = os.date '%H%M%S'
    return string.format('%s_%s', project_id, timestamp)
  end
end


-- Check if tmux session exists
local function session_exists(session_name)
  local result = vim.fn.system(string.format('tmux has-session -t %s 2>/dev/null', session_name))
  return vim.v.shell_error == 0
end

-- Create a new persistent terminal
function M.new_terminal(cmd, session_name, switch_to_buffer)
  -- Generate session name using custom name as suffix if provided
  local final_session_name = generate_session_name(session_name)

  -- If session doesn't exist, create it detached first
  if not session_exists(final_session_name) then
    local create_cmd =
      string.format("tmux new-session -d -s %s -c '%s' \\; set-option -t %s history-limit 50000", final_session_name, vim.fn.getcwd(), final_session_name)
    vim.fn.system(create_cmd)
  end

  -- Always create buffer in background first
  local buf_nr = vim.api.nvim_create_buf(true, false)

  -- Set up the terminal in the background buffer using termopen
  vim.api.nvim_buf_call(buf_nr, function()
    M.attach_method(final_session_name, buf_nr)
  end)

  -- Switch to buffer if requested
  if switch_to_buffer then
    -- Set buffer in current window
    vim.cmd('buffer ' .. buf_nr)

    vim.defer_fn(function()
      vim.cmd 'startinsert'
    end, 100)
  end

  -- Store session info in buffer variable
  local buf_vars = vim.b[buf_nr]
  buf_vars.tmux_session = final_session_name
  buf_vars.tmux_persistent = true
  buf_vars.terminal_persist_managed = true -- Unique marker

  -- Set buffer name - always use the custom name
  vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_name))

  -- If command provided, send it to the session
  if cmd then
    vim.defer_fn(function()
      M.send_to_session(final_session_name, cmd)
    end, 500)
  end

  return buf_nr, final_session_name
end

-- Attach to existing session in new terminal
function M.attach_session(session_name, restore_buffer_name)
  if not session_name then
    -- List sessions and let user choose
    local sessions = vim.fn.systemlist "tmux ls -F '#{session_name}'"
    if #sessions == 0 then
      vim.notify 'No tmux sessions found'
      return
    end

    -- Get project state to show custom names
    local project_state = require('custom.session').read_state()
    local session_choices = {}
    for _, sess in ipairs(sessions) do
      local info = project_state[sess]
      if info and info.custom_name then
        table.insert(session_choices, {
          display = string.format('%s (%s)', info.custom_name, sess),
          value = sess,
          buffer_name = info.buffer_name,
        })
      else
        table.insert(session_choices, {
          display = sess,
          value = sess,
        })
      end
    end

    vim.ui.select(session_choices, {
      prompt = 'Select tmux session:',
      format_item = function(item)
        return item.display
      end,
    }, function(choice)
      if choice then
        vim.cmd 'enew'
        local buf_nr = vim.api.nvim_get_current_buf()

        -- Use termopen attachment method
        M.attach_method(choice.value, buf_nr)

        -- Store session info
        vim.b[buf_nr].tmux_session = choice.value
        vim.b[buf_nr].tmux_persistent = true
        vim.b[buf_nr].terminal_persist_managed = true -- Unique marker

        -- Restore buffer name using custom name
        local state = require('custom.session').read_state()
        local session_info = state[choice.value]
        if session_info and session_info.custom_name then
          vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_info.custom_name))
        end

        vim.cmd 'startinsert'
      end
    end)
  else
    vim.cmd 'enew'
    local buf_nr = vim.api.nvim_get_current_buf()

    -- Use termopen attachment method
    M.attach_method(session_name, buf_nr)

    -- Store session info
    vim.b[buf_nr].tmux_session = session_name
    vim.b[buf_nr].tmux_persistent = true
    vim.b[buf_nr].terminal_persist_managed = true -- Unique marker

    -- Restore buffer name using custom name from state (with delay to ensure terminal is ready)
    vim.defer_fn(function()
      local project_state = require('custom.session').read_state()
      local session_info = project_state[session_name]
      if session_info and session_info.custom_name then
        vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_info.custom_name))
      end
    end, 100)

    vim.cmd 'startinsert'
  end
end

-- Send command to existing session
function M.send_to_session(session_name, cmd)
  local tmux_cmd = string.format("tmux send-keys -t %s '%s' Enter", session_name, cmd:gsub("'", "'\"'\"'"))
  vim.fn.system(tmux_cmd)
end


-- Restore project sessions
function M.restore_project_sessions()
  local session = require('custom.session')
  local state = session.read_state()
  local project_id = get_project_id()
  local restored = 0
  local sessions_to_restore = {}

  -- Collect sessions belonging to this project
  for session_name, info in pairs(state) do
    -- Skip non-session keys (like nvim_socket)
    if session_name ~= 'nvim_socket' and type(info) == 'table' then
      -- Check if session belongs to current project (has same prefix)
      if session_name:sub(1, #project_id) == project_id then
        if session_exists(session_name) then
          restored = restored + 1
          table.insert(sessions_to_restore, { name = session_name, info = info })
        end
      end
    end
  end

  -- Clean up stale sessions
  local cleaned = session.cleanup_stale()
  if cleaned > 0 then
    vim.notify(string.format('Cleaned up %d stale session(s)', cleaned), vim.log.levels.INFO)
  end

  -- Restore all matching sessions as terminal buffers
  if restored > 0 and M.config.auto_restore then
    vim.defer_fn(function()
      -- Save current window/buffer to return to after restoration
      local current_win = vim.api.nvim_get_current_win()
      local current_buf = vim.api.nvim_get_current_buf()

      -- IMPORTANT: We reuse new_terminal() for restoration instead of duplicating logic.
      -- This relies on generate_session_name() producing consistent names based on project ID.
      -- If the naming scheme changes, restored sessions won't match existing tmux sessions.
      -- The project ID is stable (based on CWD hash), so this should be safe.
      for _, session_data in ipairs(sessions_to_restore) do
        local session_info = session_data.info
        if session_info and session_info.custom_name then
          -- Create terminal without switching to it (3rd param = false)
          M.new_terminal(nil, session_info.custom_name, false)
        end
      end

      -- Return to original buffer/window
      vim.api.nvim_set_current_win(current_win)
      vim.api.nvim_set_current_buf(current_buf)

      vim.notify(string.format('Restored %d terminals in background', restored))
    end, 500)
  elseif restored > 0 then
    vim.notify(string.format('Project sessions: %d available', restored))
  end

  return restored
end

-- Save the current socket to project state
local function save_socket_to_state()
  local socket = require('custom.socket').get()
  if not socket or socket == '' then
    return
  end

  local session = require('custom.session')
  local state = session.read_state()
  state.nvim_socket = socket
  session.write_state(state)
end

-- Setup autocmds and keymaps
function M.setup(opts)
  -- Merge config
  if opts and opts.config then
    M.config = vim.tbl_deep_extend('force', M.config, opts.config)
  end

  -- Save the Neovim socket to project state on startup
  vim.defer_fn(function()
    save_socket_to_state()
  end, 100)

  -- Auto-restore on startup
  if M.config.auto_restore then
    vim.defer_fn(function()
      M.restore_project_sessions()
    end, 100)
  end

  -- No automatic history refresh - use 'with-history' method or tmux copy mode for full history

  -- Terminal configuration autocmd - consolidated settings for terminal-persist managed buffers only
  -- prevents overriding settings for neogit & other plugin buffers/terminals
  vim.api.nvim_create_autocmd('BufEnter', {
    callback = function(args)
      local buf_nr = args.buf
      -- Only apply to terminal-persist managed buffers
      if vim.b[buf_nr].terminal_persist_managed then
        -- Disable line numbers and sign column for clean terminal appearance
        vim.wo.number = false
        vim.wo.relativenumber = false
        vim.wo.signcolumn = 'no'

        -- Make normal mode behave more like terminal mode
        -- This preserves the terminal's view of the scrollback
        vim.wo.scrolloff = 0
        vim.wo.sidescrolloff = 0
      end
    end,
  })

  -- Track sessions when created
  local original_new_terminal = M.new_terminal
  M.new_terminal = function(cmd, session_name, switch_to_buffer)
    local buf_nr, final_session_name = original_new_terminal(cmd, session_name, switch_to_buffer)
    if final_session_name then
      -- Get the buffer name that was set
      local buffer_name = vim.api.nvim_buf_get_name(buf_nr)
      require('custom.session').track(final_session_name, {
        cmd = cmd,
        created = os.time(),
        buffer_name = buffer_name,
        custom_name = session_name, -- Store the user-provided name
      })
    end
    return buf_nr, final_session_name
  end

  -- Kill tmux session when terminal-persist buffer is closed
  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    callback = function(args)
      local buf_nr = args.buf

      -- Check if buffer is still valid before accessing properties
      if not vim.api.nvim_buf_is_valid(buf_nr) then
        return
      end

      -- Safely check for buffer variables
      local ok, buf_vars = pcall(function()
        return vim.b[buf_nr]
      end)
      if not ok or not buf_vars or not buf_vars.terminal_persist_managed then
        return
      end

      local session = buf_vars.tmux_session
      if session then
        -- Defer the cleanup to avoid interfering with the deletion process
        vim.defer_fn(function()
          -- Debug: check if session exists first
          local check_result = vim.fn.system(string.format('tmux has-session -t "%s" 2>&1', session))
          local check_exit = vim.v.shell_error

          if check_exit == 0 then
            -- Session exists, try to kill it
            local result = vim.fn.system(string.format('tmux kill-session -t "%s" 2>&1', session))
            local exit_code = vim.v.shell_error

            -- Only notify on error, not success (to avoid screen disruption)
            if exit_code ~= 0 then
              vim.notify(string.format('Failed to kill tmux session %s: %s', session, result))
            end
          end

          -- Remove from project state regardless
          local state = require('custom.session').read_state()
          state[session] = nil
          require('custom.session').write_state(state)
        end, 100) -- Small delay to let buffer cleanup finish
      end
    end,
  })

  -- Handle buffer rename for terminal buffers
  vim.api.nvim_create_autocmd('BufFilePost', {
    callback = function(args)
      local buf_nr = args.buf
      -- Check if this is a managed terminal buffer
      if vim.b[buf_nr] and vim.b[buf_nr].terminal_persist_managed then
        local session = vim.b[buf_nr].tmux_session
        if session then
          local new_name = args.file
          -- Extract the custom name from the new buffer name
          local custom_name = new_name:match '^term://(.+)$' or new_name:match '([^/]+)$'

          if custom_name then
            -- Update the state with new custom name
            local state = require('custom.session').read_state()
            if state[session] then
              state[session].custom_name = custom_name
              state[session].buffer_name = new_name
              require('custom.session').write_state(state)
            end
          end
        end
      end
    end,
  })

  -- Save state on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      -- Update last accessed time for all tracked sessions
      local state = require('custom.session').read_state()
      for session_name, info in pairs(state) do
        if session_exists(session_name) then
          info.last_accessed = os.time()
        end
      end
      require('custom.session').write_state(state)
    end,
  })
end

-- TEST ORIGINAL: Current approach (for comparison)
function M.test_original_attach(session_name)
  vim.cmd 'enew'
  local buf = vim.api.nvim_get_current_buf()

  -- Use default scrollback (10000) like original
  -- vim.bo[buf].scrollback = 10000  -- This is the default, so we don't need to set it

  -- Use the current attach method
  vim.cmd(M.attach_method(session_name))

  vim.b[buf].tmux_session = session_name
  vim.b[buf].tmux_persistent = true
  vim.b[buf].terminal_persist_managed = true
  vim.cmd 'startinsert'
  vim.notify 'Testing Original: Current approach with default scrollback=10000'
end

-- TEST OPTION 2: PTY Buffer - Unbuffered output
function M.test_option2_attach(session_name)
  vim.cmd 'enew'
  local buf = vim.api.nvim_get_current_buf()

  -- Set scrollback limit higher
  vim.bo[buf].scrollback = 100000

  -- Use termopen to attach to tmux session
  -- WARNING: Do NOT use stdout_buffered/stderr_buffered options - they are deprecated in Neovim 0.10+
  local socket = require('custom.socket')
  vim.fn.termopen(string.format('NVIM=%s ~/.config/scripts/tmux-attach-with-history.sh %s', socket.get(), session_name))

  vim.b[buf].tmux_session = session_name
  vim.b[buf].tmux_persistent = true
  vim.b[buf].terminal_persist_managed = true
  vim.cmd 'startinsert'
  vim.notify 'Testing Option 2: Unbuffered PTY output'
end

-- TEST OPTION 4: Rate limiting with c0-change settings
function M.test_option4_attach(session_name)
  -- First set tmux c0-change options
  vim.fn.system(string.format('tmux set-option -t %s c0-change-interval 50', session_name))
  vim.fn.system(string.format('tmux set-option -t %s c0-change-trigger 250', session_name))

  vim.cmd 'enew'
  local buf = vim.api.nvim_get_current_buf()

  -- Set scrollback limit higher
  vim.bo[buf].scrollback = 100000

  local socket = require('custom.socket')
  vim.fn.termopen(string.format('NVIM=%s ~/.config/scripts/tmux-attach-with-history.sh %s', socket.get(), session_name))

  vim.b[buf].tmux_session = session_name
  vim.b[buf].tmux_persistent = true
  vim.b[buf].terminal_persist_managed = true
  vim.cmd 'startinsert'
  vim.notify 'Testing Option 4: Tmux c0-change throttling'
end

-- TEST OPTION 7: Explicit output handlers
function M.test_option7_attach(session_name)
  vim.cmd 'enew'
  local buf = vim.api.nvim_get_current_buf()

  -- Set scrollback limit higher
  vim.bo[buf].scrollback = 100000

  -- Use termopen with explicit handlers to ensure all output is captured
  local socket = require('custom.socket')
  vim.fn.termopen(string.format('NVIM=%s ~/.config/scripts/tmux-attach-with-history.sh %s', socket.get(), session_name), {
    -- Explicitly handle all output
    on_stdout = function(_, data, _)
      -- Default handler, but explicitly set
      -- This ensures we're not accidentally filtering
      return false -- Let default handler process
    end,
    on_stderr = function(_, data, _)
      return false -- Let default handler process
    end,
  })

  vim.b[buf].tmux_session = session_name
  vim.b[buf].tmux_persistent = true
  vim.b[buf].terminal_persist_managed = true
  vim.cmd 'startinsert'
  vim.notify 'Testing Option 7: Explicit output handlers'
end

return M
