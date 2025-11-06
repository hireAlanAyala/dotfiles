local M = {}

-- TODO: reformat this to a more general session manager

-- Configuration
M.config = {
  state_file = '.nvim/terminal-sessions.json',
}

-- Get project state file path
local function get_state_file()
  return vim.fn.getcwd() .. '/' .. M.config.state_file
end

-- Read project state
function M.read_state()
  local state_file = get_state_file()
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
function M.write_state(state)
  local state_file = get_state_file()

  -- Create directory if it doesn't exist
  local dir = vim.fn.fnamemodify(state_file, ':h')
  vim.fn.mkdir(dir, 'p')

  local file = io.open(state_file, 'w')
  if not file then
    return false
  end

  file:write(vim.json.encode(state))
  file:close()
  return true
end

-- Track/update a session
function M.track(session_name, info)
  local state = M.read_state()

  -- Add or update session info
  state[session_name] = vim.tbl_extend('force', info or {}, {
    last_accessed = os.time(),
    project_dir = vim.fn.getcwd(),
  })

  M.write_state(state)
end

-- Untrack a session
function M.untrack(session_name)
  local state = M.read_state()
  state[session_name] = nil
  M.write_state(state)
end

-- Get all sessions
function M.get_all()
  return M.read_state()
end

-- Check if tmux session exists
local function session_exists(session_name)
  local result = vim.fn.system(string.format('tmux has-session -t %s 2>/dev/null', session_name))
  return vim.v.shell_error == 0
end

-- Clean up stale sessions (sessions that no longer exist in tmux)
function M.cleanup_stale()
  local state = M.read_state()
  local new_state = {}
  local cleaned = 0

  for session_name, info in pairs(state) do
    -- Skip non-session keys (like nvim_socket)
    if session_name ~= 'nvim_socket' then
      if session_exists(session_name) then
        new_state[session_name] = info
      else
        cleaned = cleaned + 1
      end
    else
      -- Keep special keys
      new_state[session_name] = info
    end
  end

  if cleaned > 0 then
    M.write_state(new_state)
  end

  return cleaned
end

return M
