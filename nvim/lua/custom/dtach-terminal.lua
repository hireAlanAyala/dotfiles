local M = {}

-- Configuration
M.config = {
  socket_dir = vim.fn.stdpath('data') .. '/dtach-sockets',
  state_file = vim.fn.stdpath('data') .. '/dtach-terminals.json',
  default_shell = vim.o.shell or '/bin/bash',
}

-- Ensure socket directory exists
vim.fn.mkdir(M.config.socket_dir, 'p')

-- Generate unique socket name
local function generate_socket_name()
  local timestamp = os.time()
  local random = math.random(1000, 9999)
  return string.format('%s/nvim-term-%d-%d.sock', M.config.socket_dir, timestamp, random)
end

-- Read saved state
local function read_state()
  local file = io.open(M.config.state_file, 'r')
  if not file then return {} end
  
  local content = file:read('*all')
  file:close()
  
  local ok, state = pcall(vim.json.decode, content)
  return ok and state or {}
end

-- Write state
local function write_state(state)
  local file = io.open(M.config.state_file, 'w')
  if not file then return end
  
  file:write(vim.json.encode(state))
  file:close()
end

-- Check if socket has active process
local function socket_is_active(socket_path)
  -- Check if socket file exists
  if vim.fn.filereadable(socket_path) == 0 then
    return false
  end
  
  -- Try to probe the socket with dtach
  local result = vim.fn.system(string.format('dtach -n %s echo "probe" 2>&1', socket_path))
  -- If dtach says socket is in use, it's active
  return string.find(result, 'in use') ~= nil
end

-- Create new dtach terminal
function M.new_terminal(cmd)
  -- Generate socket path
  local socket_path = generate_socket_name()
  
  -- Default to shell if no command provided
  cmd = cmd or M.config.default_shell
  
  -- Save current window info
  local win_id = vim.api.nvim_get_current_win()
  local buf_pos = vim.api.nvim_win_get_cursor(win_id)
  
  -- Create terminal with dtach
  local term_cmd = string.format('dtach -c %s %s', socket_path, cmd)
  vim.cmd('terminal ' .. term_cmd)
  
  -- Get buffer number
  local buf_nr = vim.api.nvim_get_current_buf()
  
  -- Store socket path in buffer variable
  vim.b[buf_nr].dtach_socket = socket_path
  vim.b[buf_nr].dtach_cmd = cmd
  
  -- Save to state
  local state = read_state()
  state[tostring(buf_nr)] = {
    socket = socket_path,
    cmd = cmd,
    created = os.time(),
    cwd = vim.fn.getcwd(),
  }
  write_state(state)
  
  -- Set buffer name to something meaningful
  vim.api.nvim_buf_set_name(buf_nr, 'term://' .. cmd .. ' [dtach]')
  
  -- Enter insert mode
  vim.cmd('startinsert')
  
  return buf_nr
end

-- Restore saved terminals
function M.restore_terminals()
  local state = read_state()
  local restored = 0
  local failed = 0
  
  -- Clean up state
  local new_state = {}
  
  for _, session in pairs(state) do
    if socket_is_active(session.socket) then
      -- Change to saved working directory if it exists
      local saved_cwd = vim.fn.getcwd()
      if session.cwd and vim.fn.isdirectory(session.cwd) == 1 then
        vim.cmd('cd ' .. session.cwd)
      end
      
      -- Attach to existing dtach session
      local term_cmd = string.format('dtach -a %s', session.socket)
      vim.cmd('terminal ' .. term_cmd)
      
      -- Get new buffer number
      local buf_nr = vim.api.nvim_get_current_buf()
      
      -- Store socket info in new buffer
      vim.b[buf_nr].dtach_socket = session.socket
      vim.b[buf_nr].dtach_cmd = session.cmd
      
      -- Update state with new buffer number
      new_state[tostring(buf_nr)] = session
      
      -- Restore working directory
      vim.cmd('cd ' .. saved_cwd)
      
      -- Set buffer name
      vim.api.nvim_buf_set_name(buf_nr, 'term://' .. session.cmd .. ' [dtach-restored]')
      
      restored = restored + 1
    else
      -- Socket is dead, remove from state
      failed = failed + 1
    end
  end
  
  -- Write updated state
  write_state(new_state)
  
  -- Notify user
  local msg = string.format('Restored %d terminals', restored)
  if failed > 0 then
    msg = msg .. string.format(' (%d dead sessions cleaned up)', failed)
  end
  vim.notify(msg)
  
  return restored
end

-- List active sessions
function M.list_sessions()
  local state = read_state()
  local sessions = {}
  
  for buf_nr, session in pairs(state) do
    if socket_is_active(session.socket) then
      table.insert(sessions, {
        buffer = buf_nr,
        socket = session.socket,
        cmd = session.cmd,
        created = os.date('%Y-%m-%d %H:%M:%S', session.created),
        cwd = session.cwd,
      })
    end
  end
  
  return sessions
end

-- Clean up dead sockets
function M.cleanup()
  local state = read_state()
  local new_state = {}
  local cleaned = 0
  
  for buf_nr, session in pairs(state) do
    if socket_is_active(session.socket) then
      new_state[buf_nr] = session
    else
      -- Remove dead socket file
      vim.fn.delete(session.socket)
      cleaned = cleaned + 1
    end
  end
  
  write_state(new_state)
  vim.notify(string.format('Cleaned up %d dead sessions', cleaned))
end

-- Detach from current terminal (just close buffer, process keeps running)
function M.detach_current()
  local buf_nr = vim.api.nvim_get_current_buf()
  
  if vim.b[buf_nr].dtach_socket then
    -- Just close the buffer, dtach keeps process running
    vim.cmd('close')
    vim.notify('Terminal detached (process still running)')
  else
    vim.notify('Not a dtach terminal buffer', vim.log.levels.WARN)
  end
end

-- Setup function to create keymaps
function M.setup(opts)
  -- Merge config
  if opts and opts.config then
    M.config = vim.tbl_deep_extend('force', M.config, opts.config)
  end
  
  -- Auto-cleanup on startup
  M.cleanup()
  
  -- Update state when terminal buffer is deleted
  vim.api.nvim_create_autocmd('TermClose', {
    callback = function()
      local buf_nr = vim.api.nvim_get_current_buf()
      if vim.b[buf_nr].dtach_socket then
        -- Keep session in state even after buffer closes
        -- This allows restoration later
        vim.notify('Terminal detached - use <leader>tr to restore')
      end
    end,
  })
end

return M