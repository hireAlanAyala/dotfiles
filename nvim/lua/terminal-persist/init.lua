-- Terminal persistence plugin
-- Terminals are backed by a configurable strategy (default: tmux)

local M = {}
local strategies = require 'terminal-persist.strategies'

M.config = {
  state_file = '.nvim/terminal-sessions.json',
  auto_restore = true,
  scrollback = 100000,
  -- Strategy patterns: map name patterns to strategies
  -- First matching pattern wins. Unmatched names use default_strategy.
  -- Example: strategy_patterns = { ['^special_'] = 'custom_strategy' }
  strategy_patterns = {},
  default_strategy = 'tmux',
}

-- ============================================================================
-- State Management
-- ============================================================================

local function get_state_file()
  return vim.fn.getcwd() .. '/' .. M.config.state_file
end

local function read_state()
  local file = io.open(get_state_file(), 'r')
  if not file then return {} end
  local content = file:read '*all'
  file:close()
  local ok, state = pcall(vim.json.decode, content)
  return ok and state or {}
end

local function write_state(state)
  local state_file = get_state_file()
  vim.fn.mkdir(vim.fn.fnamemodify(state_file, ':h'), 'p')
  local file = io.open(state_file, 'w')
  if not file then return false end
  file:write(vim.json.encode(state))
  file:close()
  return true
end

-- ============================================================================
-- Helpers
-- ============================================================================

local function get_project_id()
  local cwd = vim.fn.getcwd()
  local path_hash = vim.fn.sha256(cwd):sub(1, 6)
  local dir_name = vim.fn.fnamemodify(cwd, ':t'):gsub('[^%w%-_]', '_')
  return string.format('%s_%s', dir_name, path_hash)
end

local function generate_session_name(name)
  local project_id = get_project_id()
  return string.format('%s_%s', project_id, name or os.date '%H%M%S')
end

local function get_strategy_for_name(name)
  if not name then return M.config.default_strategy end
  for pattern, strategy in pairs(M.config.strategy_patterns) do
    if name:match(pattern) then return strategy end
  end
  return M.config.default_strategy
end

local function get_strategy(strategy_name)
  return strategies.strategies[strategy_name or M.config.default_strategy]
end

-- Find existing buffer for a session
local function find_buffer_for_session(session_name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].persist_session == session_name then
      return buf
    end
  end
  return nil
end

-- ============================================================================
-- Terminal Creation
-- ============================================================================

local function create_terminal(session_name, name, switch, strategy_name)
  strategy_name = strategy_name or get_strategy_for_name(name)
  local strategy = get_strategy(strategy_name)
  local buf_nr = vim.api.nvim_create_buf(true, false)

  vim.api.nvim_buf_call(buf_nr, function()
    local cmd = strategy:create_or_attach(session_name)
    vim.fn.termopen(cmd)
    vim.bo[buf_nr].scrollback = M.config.scrollback
  end)

  -- Setup buffer
  vim.b[buf_nr].terminal_persist_managed = true
  vim.b[buf_nr].persist_session = session_name
  vim.b[buf_nr].persist_name = name
  vim.b[buf_nr].persist_strategy = strategy_name

  -- Use vim.schedule (not defer) to run after termopen() finishes in the same event loop,
  -- without an arbitrary delay. termopen() overwrites buffer name with the shell command.
  -- We also set term_title because fzf-lua's buffer picker uses vim.b.term_title
  -- for terminal buffers instead of the buffer name (see fzf-lua/providers/buffers.lua)
  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(buf_nr) then
      pcall(vim.api.nvim_buf_set_name, buf_nr, string.format('term://%s', name))
      vim.b[buf_nr].term_title = name
    end
  end)

  if switch then
    vim.cmd('buffer ' .. buf_nr)
    vim.defer_fn(function() vim.cmd 'startinsert' end, 100)
  end

  return buf_nr
end

-- ============================================================================
-- Public API
-- ============================================================================

function M.new(name, switch, cmd)
  if switch == nil then switch = true end

  local session_name = generate_session_name(name)
  local strategy_name = get_strategy_for_name(name)

  -- Check if buffer already exists for this session
  local existing_buf = find_buffer_for_session(session_name)
  if existing_buf then
    if switch then
      vim.cmd('buffer ' .. existing_buf)
      vim.defer_fn(function() vim.cmd 'startinsert' end, 100)
    end
    return existing_buf, session_name
  end

  local buf_nr = create_terminal(session_name, name, switch, strategy_name)

  -- Send initial command if provided
  if cmd then
    vim.defer_fn(function()
      local chan = vim.b[buf_nr].terminal_job_id
      if chan then
        vim.api.nvim_chan_send(chan, cmd .. '\n')
      end
    end, 150)
  end

  -- Track in state
  local state = read_state()
  state[session_name] = {
    name = name,
    strategy = strategy_name,
    created = os.time(),
  }
  write_state(state)

  return buf_nr, session_name
end

function M.restore()
  -- State file read is sync but fast (local file, small JSON)
  local state = read_state()
  local project_id = get_project_id()

  -- Collect sessions to restore
  local to_restore = {}
  for session_name, info in pairs(state) do
    if type(info) == 'table' and info.name and session_name:sub(1, #project_id) == project_id then
      if not find_buffer_for_session(session_name) then
        table.insert(to_restore, { session_name = session_name, info = info })
      end
    end
  end

  if #to_restore == 0 then return end

  local restored = 0
  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()

  -- Fetch tmux sessions async, then restore all
  vim.fn.jobstart('tmux list-sessions -F "#{session_name}" 2>/dev/null', {
    stdout_buffered = true,
    on_stdout = function(_, data)
      local tmux_sessions = {}
      for _, session in ipairs(data) do
        if session ~= '' then tmux_sessions[session] = true end
      end

      for _, item in ipairs(to_restore) do
        local ok, err = pcall(function()
          local strategy_name = item.info.strategy or M.config.default_strategy
          local strategy = get_strategy(strategy_name)
          if not strategy then return end

          -- Use pre-fetched tmux_sessions for tmux, strategy:session_exists for others
          local exists = strategy_name == 'tmux'
            and tmux_sessions[item.session_name]
            or strategy:session_exists(item.session_name)

          if exists then
            create_terminal(item.session_name, item.info.name, false, strategy_name)
            restored = restored + 1

            -- Auto-resume claude session if interrupted (claude_session_id exists in state).
            -- We auto-resume rather than restore scrollback because claude's inline editing
            -- causes nvim and tmux scrollback to desync.
            if item.info.claude_session_id and strategy_name == 'tmux' then
              vim.defer_fn(function()
                vim.fn.system(string.format("tmux send-keys -t '%s' 'c -t' Enter", item.session_name))
              end, 200)
            end
          end
        end)
      end

      if vim.api.nvim_win_is_valid(current_win) then
        vim.api.nvim_set_current_win(current_win)
      end
      if vim.api.nvim_buf_is_valid(current_buf) then
        vim.api.nvim_set_current_buf(current_buf)
      end
      if restored > 0 then
        vim.notify(string.format('Restored %d terminal(s)', restored))
      end
    end,
  })
end

-- ============================================================================
-- Setup
-- ============================================================================

function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end

  if M.config.auto_restore then
    vim.defer_fn(M.restore, 100)
  end

  -- Terminal buffer options
  vim.api.nvim_create_autocmd('BufEnter', {
    callback = function(args)
      if vim.b[args.buf].terminal_persist_managed then
        vim.wo.number = false
        vim.wo.relativenumber = false
        vim.wo.signcolumn = 'no'
      end
    end,
  })

  -- Cleanup on buffer close
  vim.api.nvim_create_autocmd({ 'BufDelete', 'BufWipeout' }, {
    callback = function(args)
      local buf = args.buf
      if not vim.api.nvim_buf_is_valid(buf) then return end

      local session = vim.b[buf].persist_session
      local strategy_name = vim.b[buf].persist_strategy or M.config.default_strategy
      if not session then return end

      vim.defer_fn(function()
        local strategy = get_strategy(strategy_name)
        strategy:kill(session)
        local state = read_state()
        state[session] = nil
        write_state(state)
      end, 100)
    end,
  })
end

return M
