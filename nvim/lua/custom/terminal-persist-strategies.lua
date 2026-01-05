local M = {}

-- Strategy interface: Each strategy should implement:
-- - name: string identifier
-- - attach(session_name, opts): function to attach to session
-- - supports_scrollback: boolean indicating if strategy preserves scrollback

M.strategies = {}

-- Strategy 1: Direct attachment (original behavior)
M.strategies.direct = {
  name = "direct",
  supports_scrollback = false,
  attach = function(session_name, opts)
    return string.format('terminal tmux attach-session -t %s', session_name)
  end
}

-- Strategy 2: With history (current behavior)
M.strategies.with_history = {
  name = "with_history",
  supports_scrollback = true,
  attach = function(session_name, opts)
    return string.format('terminal ~/.config/scripts/tmux-attach-with-history.sh %s', session_name)
  end
}

-- Strategy 3: Headless pipe (continuous streaming)
M.strategies.headless_pipe = {
  name = "headless_pipe",
  supports_scrollback = true,
  attach = function(session_name, opts)
    -- Create a unique pipe for this session
    local pipe_path = string.format('/tmp/nvim-tmux-pipe-%s-%s', session_name, vim.fn.getpid())
    
    -- Start piping the tmux pane output
    vim.fn.system(string.format('mkfifo %s 2>/dev/null', pipe_path))
    vim.fn.system(string.format('tmux pipe-pane -t %s -o "cat > %s"', session_name, pipe_path))
    
    -- Return terminal command that reads from the pipe
    return string.format('terminal cat %s', pipe_path)
  end,
  cleanup = function(session_name)
    -- Stop piping when done
    vim.fn.system(string.format('tmux pipe-pane -t %s', session_name))
  end
}

-- Strategy 4: Capture with polling (for read-only viewing)
M.strategies.capture_poll = {
  name = "capture_poll",
  supports_scrollback = true,
  attach = function(session_name, opts)
    local poll_interval = opts.poll_interval or 100  -- ms
    local script = string.format([[
terminal bash -c 'while true; do
  tmux capture-pane -t %s -p -S -
  printf "\033[2J\033[H"  # Clear screen and move cursor home
  sleep %f
done']], session_name, poll_interval / 1000.0)
    return script
  end
}

-- Strategy 5: Control mode (experimental)
M.strategies.control_mode = {
  name = "control_mode",
  supports_scrollback = true,
  experimental = true,
  attach = function(session_name, opts)
    return string.format('terminal tmux -CC attach-session -t %s', session_name)
  end
}

-- Strategy 6: dtach - minimal session persistence without terminal emulation
-- dtach passes escape sequences through raw, letting nvim's terminal handle scrollback directly
-- Pros: nvim's scrollback stays in sync, no double terminal emulation
-- Cons: no tmux features (panes, windows, status bar)
M.strategies.dtach = {
  name = "dtach",
  supports_scrollback = true,
  description = "Raw PTY passthrough - nvim handles all scrollback",
  socket_dir = "/tmp/nvim-dtach",

  -- Get socket path for a session
  get_socket_path = function(self, session_name)
    return string.format('%s/%s.socket', self.socket_dir, session_name)
  end,

  -- Check if dtach is available
  is_available = function()
    return vim.fn.executable('dtach') == 1
  end,

  -- Check if session exists
  session_exists = function(self, session_name)
    local socket_path = self:get_socket_path(session_name)
    return vim.fn.filereadable(socket_path) == 1
  end,

  -- Create new session (returns command for termopen)
  create = function(self, session_name, opts)
    local socket_path = self:get_socket_path(session_name)
    local cwd = opts and opts.cwd or vim.fn.getcwd()
    local shell = opts and opts.shell or vim.o.shell

    -- Ensure socket directory exists
    vim.fn.mkdir(self.socket_dir, 'p')

    -- dtach -c creates a new session
    -- -z disables suspend (Ctrl-Z)
    return string.format('dtach -c %s -z %s', socket_path, shell)
  end,

  -- Attach to existing session (returns command for termopen)
  attach = function(self, session_name, opts)
    local socket_path
    if type(self) == "string" then
      -- Called as attach(session_name, opts) without self
      socket_path = string.format('/tmp/nvim-dtach/%s.socket', self)
    else
      socket_path = self:get_socket_path(session_name)
    end

    -- dtach -a attaches to existing session
    return string.format('dtach -a %s', socket_path)
  end,

  -- Create or attach (returns command for termopen)
  create_or_attach = function(self, session_name, opts)
    local socket_path = self:get_socket_path(session_name)
    local cwd = opts and opts.cwd or vim.fn.getcwd()
    local shell = opts and opts.shell or vim.o.shell

    -- Ensure socket directory exists
    vim.fn.mkdir(self.socket_dir, 'p')

    -- dtach -A creates if doesn't exist, attaches if it does
    -- -z disables suspend
    return string.format('dtach -A %s -z %s', socket_path, shell)
  end,

  -- Kill session
  kill = function(self, session_name)
    local socket_path = self:get_socket_path(session_name)
    -- dtach sessions die when socket is removed and no clients attached
    -- Sending SIGHUP to the dtach master process is cleaner
    -- For now, just remove the socket
    vim.fn.delete(socket_path)
  end,

  -- List sessions
  list = function(self)
    local sessions = {}
    local socket_dir = self.socket_dir
    if vim.fn.isdirectory(socket_dir) == 1 then
      local files = vim.fn.glob(socket_dir .. '/*.socket', false, true)
      for _, file in ipairs(files) do
        local name = vim.fn.fnamemodify(file, ':t:r')
        table.insert(sessions, name)
      end
    end
    return sessions
  end,
}

-- Get a strategy by name
function M.get_strategy(name)
  return M.strategies[name] or M.strategies.with_history
end

-- List available strategies
function M.list_strategies()
  local list = {}
  for name, strategy in pairs(M.strategies) do
    table.insert(list, {
      name = name,
      supports_scrollback = strategy.supports_scrollback,
      experimental = strategy.experimental or false
    })
  end
  return list
end

-- Register a custom strategy
function M.register_strategy(name, strategy)
  if not strategy.name or not strategy.attach then
    error("Strategy must have 'name' and 'attach' fields")
  end
  M.strategies[name] = strategy
end

return M