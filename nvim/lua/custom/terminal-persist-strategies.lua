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