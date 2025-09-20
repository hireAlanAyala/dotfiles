local M = {}

-- look into tmux -CC
-- WARNING: CLAUDE DO NOT DELETE!
-- core issue:
-- when I open a terminal tmux is attaching to a session within an already attached session
-- so I have an outer layer tmux -> inner layer tmux -> nvim terminal buffer
-- the outer layer tmux only sees the view port -> inner layer tmux sees all terminal history
-- to test this, dettach from the nvim session and attach directly to the terminal session
-- you will be able to scroll up and see all history
--
-- INFO: FACTS:
-- outer tmux -> nvim terminal -> inner tmux
-- only the inner tmux has the correct scrollback
-- nvim + outer tmux do not
--
-- INFO: WAYS TO SCROLLBACK:
-- tmux leader, tmux leader [
-- tmux leader + s (attach to sub session)

-- Configuration
M.config = {
  session_prefix = 'nvim',
  auto_name_from_cwd = true,
  state_file = vim.fn.stdpath 'data' .. '/terminal-persist-state.json',
  project_state_file = '.nvim/terminal-sessions.json', -- Per-project state
  auto_restore = true,

  -- ATTACHMENT METHOD - Change this variable to test different methods:
  -- 'with-history' = Dump scrollback then attach (default)
  -- 'direct' = Direct tmux attach (no scrollback)
  -- 'capture-loop' = Continuous capture (read-only)
  -- 'pipe-pane' = Use tmux pipe-pane (read-only)
  -- 'hybrid-pipe' = Pipe output + send-keys input (experimental)
  -- 'smart-attach' = Detects tmux nesting and warns
  -- 'isolated-socket' = Uses separate tmux server socket
  attach_method = 'with-history',
}

-- Define attachment methods
M.attach_methods = {
  ['with-history'] = function(session_name)
    return string.format('terminal ~/.config/scripts/tmux-attach-with-history.sh %s', session_name)
  end,

  ['direct'] = function(session_name)
    return string.format('terminal tmux attach-session -t %s', session_name)
  end,

  ['smart-attach'] = function(session_name)
    -- Detect if we're already in tmux and handle accordingly
    local in_tmux = vim.env.TMUX ~= nil
    if in_tmux then
      -- If in tmux, use send-keys to switch or warn user
      vim.notify('Already in tmux! Consider using tmux switch-client -t ' .. session_name, vim.log.levels.WARN)
      -- Still attach but with TMUX= to bypass nesting protection
      return string.format('terminal env TMUX= tmux attach-session -t %s', session_name)
    else
      return string.format('terminal tmux attach-session -t %s', session_name)
    end
  end,

  ['isolated-socket'] = function(session_name)
    -- Use separate tmux server socket to avoid nesting
    local socket = 'nvim-' .. vim.fn.getpid()
    return string.format('terminal tmux -L %s attach-session -t %s', socket, session_name)
  end,

  ['capture-loop'] = function(session_name)
    local cmd = string.format(
      [[
terminal bash -c 'while true; do 
  clear
  tmux capture-pane -t %s -p -S -
  sleep 0.1
done']],
      session_name
    )
    return cmd
  end,

  ['pipe-pane'] = function(session_name)
    local pipe = string.format('/tmp/nvim-tmux-%s-%s', session_name, vim.fn.getpid())
    vim.fn.system(string.format('mkfifo %s 2>/dev/null', pipe))
    vim.fn.system(string.format('tmux pipe-pane -t %s -o "cat > %s"', session_name, pipe))
    return string.format('terminal cat %s', pipe)
  end,

  ['hybrid-pipe'] = function(session_name)
    -- EXPERIMENTAL: Hybrid approach using pipe-pane for output and send-keys for input
    --
    -- LIMITATIONS:
    -- 1. No real TTY - TUI apps (vim, htop) won't work, no terminal resizing
    -- 2. Input issues - Only text+Enter, no raw keys (Ctrl/Alt), no password prompts
    -- 3. Output issues - ANSI escapes may break, no terminal queries, colors might fail
    -- 4. Performance - Extra latency from pipes/processes, potential buffering delays
    -- 5. Reliability - Complex cleanup, possible orphaned processes, race conditions
    --
    -- Only use for simple command execution and output monitoring, not interactive use!

    -- Create a custom script that handles both input and output
    local script_content = string.format(
      [[#!/bin/bash
session="%s"
pipe="/tmp/nvim-tmux-${session}-$$"

# Create named pipe for output
mkfifo "$pipe" 2>/dev/null

# Start capturing tmux output to pipe
tmux pipe-pane -t "$session" -o "cat > $pipe"

# Function to handle input
handle_input() {
  while IFS= read -r line; do
    tmux send-keys -t "$session" "$line" Enter
  done
}

# Capture existing scrollback first
tmux capture-pane -t "$session" -S - -p

# Then start the bidirectional flow
# Output: cat the pipe in background
cat "$pipe" &
CAT_PID=$!

# Input: read from stdin and send to tmux
handle_input

# Cleanup on exit
trap "kill $CAT_PID 2>/dev/null; tmux pipe-pane -t '$session'; rm -f '$pipe'" EXIT
]],
      session_name
    )

    local script_path = string.format('/tmp/nvim-hybrid-%s-%s.sh', session_name, vim.fn.getpid())
    local file = io.open(script_path, 'w')
    file:write(script_content)
    file:close()
    vim.fn.system(string.format('chmod +x %s', script_path))

    return string.format('terminal %s', script_path)
  end,
}

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

-- Get project state file path
local function get_project_state_file()
  local cwd = vim.fn.getcwd()
  return cwd .. '/' .. M.config.project_state_file
end

-- Read project state
local function read_project_state()
  local state_file = get_project_state_file()
  local file = io.open(state_file, 'r')
  if not file then
    return {}
  end

  local content = file:read '*all'
  file:close()

  local ok, state = pcall(vim.json.decode, content)
  return ok and state or {}
end

-- Write project state
local function write_project_state(state)
  local state_file = get_project_state_file()

  -- Create directory if it doesn't exist
  local dir = vim.fn.fnamemodify(state_file, ':h')
  vim.fn.mkdir(dir, 'p')

  local file = io.open(state_file, 'w')
  if not file then
    return
  end

  file:write(vim.json.encode(state))
  file:close()
end

-- Check if tmux session exists
local function session_exists(session_name)
  local result = vim.fn.system(string.format('tmux has-session -t %s 2>/dev/null', session_name))
  return vim.v.shell_error == 0
end

-- Create a new persistent terminal
function M.new_terminal(cmd, session_name)
  -- Generate session name using custom name as suffix if provided
  local final_session_name = generate_session_name(session_name)

  -- If session doesn't exist, create it detached first
  if not session_exists(final_session_name) then
    local create_cmd =
      string.format("tmux new-session -d -s %s -c '%s' \\; set-option -t %s history-limit 50000", final_session_name, vim.fn.getcwd(), final_session_name)
    vim.fn.system(create_cmd)
  end

  -- Open terminal and attach to the session
  vim.cmd 'enew' -- Create new buffer in current window

  -- Get the attachment method
  local attach_fn = M.attach_methods[M.config.attach_method]
  if not attach_fn then
    vim.notify(string.format('Unknown attach method: %s', M.config.attach_method), vim.log.levels.ERROR)
    attach_fn = M.attach_methods['with-history'] -- Fallback to default
  end

  local attach_cmd = attach_fn(final_session_name)
  vim.cmd(attach_cmd)

  -- Store session info in buffer variable
  local buf_nr = vim.api.nvim_get_current_buf()
  vim.b[buf_nr].tmux_session = final_session_name
  vim.b[buf_nr].tmux_persistent = true
  vim.b[buf_nr].terminal_persist_managed = true -- Unique marker

  -- Set buffer name - always use the custom name
  vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_name))

  -- If command provided, send it to the session
  if cmd then
    vim.defer_fn(function()
      M.send_to_session(final_session_name, cmd)
    end, 500)
  end

  -- Auto enter insert mode
  vim.cmd 'startinsert'

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
    local project_state = read_project_state()
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

        -- Use configured attachment method
        local attach_fn = M.attach_methods[M.config.attach_method] or M.attach_methods['with-history']
        vim.cmd(attach_fn(choice.value))

        -- Store session info
        local buf_nr = vim.api.nvim_get_current_buf()
        vim.b[buf_nr].tmux_session = choice.value
        vim.b[buf_nr].tmux_persistent = true
        vim.b[buf_nr].terminal_persist_managed = true -- Unique marker

        -- Restore buffer name using custom name
        local state = read_project_state()
        local session_info = state[choice.value]
        if session_info and session_info.custom_name then
          vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_info.custom_name))
        end

        vim.cmd 'startinsert'
      end
    end)
  else
    vim.cmd 'enew'

    -- Use configured attachment method
    local attach_fn = M.attach_methods[M.config.attach_method] or M.attach_methods['with-history']
    vim.cmd(attach_fn(session_name))

    -- Store session info
    local buf_nr = vim.api.nvim_get_current_buf()
    vim.b[buf_nr].tmux_session = session_name
    vim.b[buf_nr].tmux_persistent = true
    vim.b[buf_nr].terminal_persist_managed = true -- Unique marker

    -- Restore buffer name using custom name from state (with delay to ensure terminal is ready)
    vim.defer_fn(function()
      local project_state = read_project_state()
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

-- Track session for current project
local function track_session(session_name, info)
  local state = read_project_state()

  -- Add or update session info
  state[session_name] = vim.tbl_extend('force', info or {}, {
    last_accessed = os.time(),
    project_dir = vim.fn.getcwd(),
  })

  write_project_state(state)
end

-- Untrack session
local function untrack_session(session_name)
  local state = read_project_state()
  state[session_name] = nil
  write_project_state(state)
end

-- Restore project sessions
function M.restore_project_sessions()
  local state = read_project_state()
  local project_id = get_project_id()
  local restored = 0
  local failed = 0
  local sessions_to_restore = {}

  -- Collect sessions belonging to this project
  for session_name, info in pairs(state) do
    -- Check if session belongs to current project (has same prefix)
    if session_name:sub(1, #project_id) == project_id then
      if session_exists(session_name) then
        restored = restored + 1
        table.insert(sessions_to_restore, {name = session_name, info = info})
      else
        -- Session doesn't exist anymore, clean up
        failed = failed + 1
      end
    end
  end

  if failed > 0 then
    -- Clean up dead sessions
    local new_state = {}
    for session_name, info in pairs(state) do
      if session_exists(session_name) then
        new_state[session_name] = info
      end
    end
    write_project_state(new_state)
  end

  -- Restore all matching sessions as terminal buffers
  if restored > 0 and M.config.auto_restore then
    vim.defer_fn(function()
      -- Save current window
      local current_win = vim.api.nvim_get_current_win()
      local current_buf = vim.api.nvim_get_current_buf()
      
      for _, session_data in ipairs(sessions_to_restore) do
        -- Create buffer for session without switching to it
        local buf_nr = vim.api.nvim_create_buf(true, false)
        
        -- Set up the terminal in the background buffer
        vim.api.nvim_buf_call(buf_nr, function()
          -- Get the attachment method
          local attach_fn = M.attach_methods[M.config.attach_method] or M.attach_methods['with-history']
          local attach_cmd = attach_fn(session_data.name)
          
          -- Execute the terminal command in this buffer
          vim.cmd(attach_cmd)
        end)
        
        -- Store session info in buffer
        vim.b[buf_nr].tmux_session = session_data.name
        vim.b[buf_nr].tmux_persistent = true
        vim.b[buf_nr].terminal_persist_managed = true
        
        -- Restore buffer name from saved state
        -- We defer this to ensure the terminal buffer is fully initialized
        -- and re-read state to get the most recent custom name (in case it was renamed)
        vim.defer_fn(function()
          local current_state = read_project_state()
          local session_info = current_state[session_data.name]
          if session_info and session_info.custom_name then
            vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_info.custom_name))
          end
        end, 100)
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

-- Setup autocmds and keymaps
function M.setup(opts)
  -- Merge config
  if opts and opts.config then
    M.config = vim.tbl_deep_extend('force', M.config, opts.config)
  end

  -- Auto-restore on startup
  if M.config.auto_restore then
    vim.defer_fn(function()
      M.restore_project_sessions()
    end, 100)
  end
  
  -- No automatic history refresh - use 'with-history' method or tmux copy mode for full history

  -- Track sessions when created
  local original_new_terminal = M.new_terminal
  M.new_terminal = function(cmd, session_name)
    local buf_nr, final_session_name = original_new_terminal(cmd, session_name)
    if final_session_name then
      -- Get the buffer name that was set
      local buffer_name = vim.api.nvim_buf_get_name(buf_nr)
      track_session(final_session_name, {
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
      -- Only handle buffers created by terminal-persist (not other terminal plugins)
      if vim.b[buf_nr].terminal_persist_managed then
        local session = vim.b[buf_nr].tmux_session
        if session then
          -- Debug: check if session exists first
          local check_result = vim.fn.system(string.format('tmux has-session -t "%s" 2>&1', session))
          local check_exit = vim.v.shell_error

          if check_exit == 0 then
            -- Session exists, try to kill it
            local result = vim.fn.system(string.format('tmux kill-session -t "%s" 2>&1', session))
            local exit_code = vim.v.shell_error

            if exit_code == 0 then
              vim.notify(string.format('Killed tmux session: %s', session))
            else
              vim.notify(string.format('Failed to kill tmux session %s: %s', session, result))
            end
          else
            -- Session already dead (normal when terminal exits) - just clean up silently
            vim.notify 'Terminal session closed'
          end

          -- Remove from project state regardless
          local state = read_project_state()
          state[session] = nil
          write_project_state(state)
        end
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
          local custom_name = new_name:match('^term://(.+)$') or new_name:match('([^/]+)$')
          
          if custom_name then
            -- Update the state with new custom name
            local state = read_project_state()
            if state[session] then
              state[session].custom_name = custom_name
              state[session].buffer_name = new_name
              write_project_state(state)
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
      local state = read_project_state()
      for session_name, info in pairs(state) do
        if session_exists(session_name) then
          info.last_accessed = os.time()
        end
      end
      write_project_state(state)
    end,
  })
end

return M
