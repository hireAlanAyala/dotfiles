local M = {}

-- Configuration
M.config = {
  session_prefix = "nvim",
  auto_name_from_cwd = true,
  state_file = vim.fn.stdpath('data') .. '/terminal-persist-state.json',
  project_state_file = '.nvim/terminal-sessions.json',  -- Per-project state
  auto_restore = true,
}

-- Get project identifier (used for grouping sessions)
local function get_project_id()
  local cwd = vim.fn.getcwd()
  -- Use full path hash for uniqueness but keep directory name for readability
  local path_hash = vim.fn.sha256(cwd):sub(1, 6)
  local dir_name = vim.fn.fnamemodify(cwd, ':t'):gsub('[^%w%-_]', '_')
  return string.format("%s_%s", dir_name, path_hash)
end

-- Generate session name from current directory
local function generate_session_name(custom_suffix)
  local project_id = get_project_id()
  
  if custom_suffix then
    -- User provided a name, use it as suffix
    return string.format("%s_%s", project_id, custom_suffix)
  else
    -- Auto-generate with timestamp
    local timestamp = os.date("%H%M%S")
    return string.format("%s_%s", project_id, timestamp)
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
  if not file then return {} end
  
  local content = file:read('*all')
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
  if not file then return end
  
  file:write(vim.json.encode(state))
  file:close()
end

-- Check if tmux session exists
local function session_exists(session_name)
  local result = vim.fn.system(string.format("tmux has-session -t %s 2>/dev/null", session_name))
  return vim.v.shell_error == 0
end

-- Create a new persistent terminal
function M.new_terminal(cmd, session_name)
  -- Generate session name using custom name as suffix if provided
  local final_session_name = generate_session_name(session_name)
  
  -- If session doesn't exist, create it detached first
  if not session_exists(final_session_name) then
    local create_cmd = string.format(
      "tmux new-session -d -s %s -c '%s' \\; set-option -t %s history-limit 50000",
      final_session_name,
      vim.fn.getcwd(),
      final_session_name
    )
    vim.fn.system(create_cmd)
  end
  
  -- Open terminal and attach to the session
  vim.cmd('enew')  -- Create new buffer in current window
  vim.cmd(string.format('terminal ~/.config/scripts/tmux-attach-with-history.sh %s', final_session_name))
  
  -- Store session info in buffer variable
  local buf_nr = vim.api.nvim_get_current_buf()
  vim.b[buf_nr].tmux_session = final_session_name
  vim.b[buf_nr].tmux_persistent = true
  vim.b[buf_nr].terminal_persist_managed = true  -- Unique marker
  
  -- Set buffer name - always use the custom name
  vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_name))
  
  -- If command provided, send it to the session
  if cmd then
    vim.defer_fn(function()
      M.send_to_session(final_session_name, cmd)
    end, 500)
  end
  
  -- Auto enter insert mode
  vim.cmd('startinsert')
  
  return buf_nr, final_session_name
end


-- Attach to existing session in new terminal
function M.attach_session(session_name, restore_buffer_name)
  if not session_name then
    -- List sessions and let user choose
    local sessions = vim.fn.systemlist("tmux ls -F '#{session_name}'")
    if #sessions == 0 then
      vim.notify("No tmux sessions found")
      return
    end
    
    -- Get project state to show custom names
    local project_state = read_project_state()
    local session_choices = {}
    for _, sess in ipairs(sessions) do
      local info = project_state[sess]
      if info and info.custom_name then
        table.insert(session_choices, {
          display = string.format("%s (%s)", info.custom_name, sess),
          value = sess,
          buffer_name = info.buffer_name
        })
      else
        table.insert(session_choices, {
          display = sess,
          value = sess
        })
      end
    end
    
    vim.ui.select(session_choices, {
      prompt = "Select tmux session:",
      format_item = function(item) return item.display end,
    }, function(choice)
      if choice then
        vim.cmd('enew')
        vim.cmd(string.format("terminal tmux attach-session -t %s", choice.value))
        
        -- Store session info
        local buf_nr = vim.api.nvim_get_current_buf()
        vim.b[buf_nr].tmux_session = choice.value
        vim.b[buf_nr].tmux_persistent = true
        vim.b[buf_nr].terminal_persist_managed = true  -- Unique marker
        
        -- Restore buffer name using custom name
        local state = read_project_state()
        local session_info = state[choice.value]
        if session_info and session_info.custom_name then
          vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_info.custom_name))
        end
        
        vim.cmd('startinsert')
      end
    end)
  else
    vim.cmd('enew')
    vim.cmd(string.format("terminal tmux attach-session -t %s", session_name))
    
    -- Store session info
    local buf_nr = vim.api.nvim_get_current_buf()
    vim.b[buf_nr].tmux_session = session_name
    vim.b[buf_nr].tmux_persistent = true
    vim.b[buf_nr].terminal_persist_managed = true  -- Unique marker
    
    -- Restore buffer name using custom name from state (with delay to ensure terminal is ready)
    vim.defer_fn(function()
      local project_state = read_project_state()
      local session_info = project_state[session_name]
      if session_info and session_info.custom_name then
        vim.api.nvim_buf_set_name(buf_nr, string.format('term://%s', session_info.custom_name))
      end
    end, 100)
    
    vim.cmd('startinsert')
  end
end



-- Send command to existing session
function M.send_to_session(session_name, cmd)
  local tmux_cmd = string.format(
    "tmux send-keys -t %s '%s' Enter",
    session_name,
    cmd:gsub("'", "'\"'\"'")
  )
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
  
  -- Only count sessions belonging to this project
  for session_name, info in pairs(state) do
    -- Check if session belongs to current project (has same prefix)
    if session_name:sub(1, #project_id) == project_id then
      if session_exists(session_name) then
        restored = restored + 1
      else
        -- Session doesn't exist anymore, clean up
        failed = failed + 1
      end
    end
  end
  
  if restored > 0 or failed > 0 then
    local msg = string.format('Project sessions: %d available', restored)
    if failed > 0 then
      msg = msg .. string.format(' (%d cleaned up)', failed)
      -- Clean up dead sessions
      local new_state = {}
      for session_name, info in pairs(state) do
        if session_exists(session_name) then
          new_state[session_name] = info
        end
      end
      write_project_state(new_state)
    end
    
    vim.notify(msg)
    
    -- Auto-attach to first session if only one exists
    if restored == 1 and M.config.auto_restore then
      for session_name, info in pairs(state) do
        if session_exists(session_name) then
          vim.defer_fn(function()
            M.attach_session(session_name)
          end, 500)
          break
        end
      end
    end
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
        custom_name = session_name,  -- Store the user-provided name
      })
    end
    return buf_nr, final_session_name
  end
  
  -- Kill tmux session when terminal-persist buffer is closed
  vim.api.nvim_create_autocmd({'BufDelete', 'BufWipeout'}, {
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
            vim.notify('Terminal session closed')
          end
          
          -- Remove from project state regardless
          local state = read_project_state()
          state[session] = nil
          write_project_state(state)
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