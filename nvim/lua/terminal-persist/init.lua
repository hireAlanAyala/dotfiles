-- Terminal persistence plugin
-- Terminals are backed by a configurable strategy (default: tmux)
--
-- PERFORMANCE CRITICAL:
-- - restore() must not call blocking vim.fn.system() for tmux sessions
-- - Use pre-fetched tmux_sessions table from async jobstart, not strategy:session_exists()
-- - Use strategy:attach() during restore (skips existence check), not create_or_attach()

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

local function create_terminal(session_name, name, switch, strategy_name, attach_only)
  strategy_name = strategy_name or get_strategy_for_name(name)
  local strategy = get_strategy(strategy_name)
  local buf_nr = vim.api.nvim_create_buf(true, false)

  vim.api.nvim_buf_call(buf_nr, function()
    local cmd = attach_only and strategy:attach(session_name) or strategy:create_or_attach(session_name)
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

-- Performance threshold for restore (warn if exceeded)
local RESTORE_WARN_MS = 500

function M.restore()
  local t_start = vim.loop.hrtime()
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

      -- Filter to sessions that exist (use pre-fetched tmux_sessions for tmux strategy)
      local valid = {}
      for _, item in ipairs(to_restore) do
        local strategy_name = item.info.strategy or M.config.default_strategy
        local strategy = get_strategy(strategy_name)
        if strategy then
          local exists
          if strategy_name == 'tmux' then
            exists = tmux_sessions[item.session_name]
          else
            exists = strategy:session_exists(item.session_name)
          end
          if exists then
            item.strategy_name = strategy_name
            table.insert(valid, item)
          end
        end
      end

      if #valid == 0 then return end

      -- Restore one terminal per event loop tick to avoid blocking
      local i = 0
      local function restore_next()
        i = i + 1
        if i > #valid then
          -- Done - restore focus and notify
          if vim.api.nvim_win_is_valid(current_win) then
            vim.api.nvim_set_current_win(current_win)
          end
          if vim.api.nvim_buf_is_valid(current_buf) then
            vim.api.nvim_set_current_buf(current_buf)
          end
          local elapsed_ms = (vim.loop.hrtime() - t_start) / 1e6
          if elapsed_ms > RESTORE_WARN_MS then
            vim.notify(string.format('terminal-persist: restore took %.0fms (threshold: %dms) - possible regression!', elapsed_ms, RESTORE_WARN_MS), vim.log.levels.WARN)
          end
          vim.notify(string.format('Restored %d terminal(s)', #valid))
          return
        end

        local item = valid[i]
        pcall(create_terminal, item.session_name, item.info.name, false, item.strategy_name, true)

        if item.info.claude_session_id and item.strategy_name == 'tmux' then
          -- Wait for client to attach before sending keys (detach-client -E requires a client)
          local attempts = 0
          local max_attempts = 20 -- 2 seconds max
          local function wait_for_client()
            attempts = attempts + 1
            vim.fn.jobstart(string.format("tmux list-clients -t '%s' 2>/dev/null", item.session_name), {
              stdout_buffered = true,
              on_stdout = function(_, data)
                local has_client = data and data[1] and data[1] ~= ''
                if has_client then
                  vim.fn.jobstart(string.format("tmux send-keys -t '%s' 'c -t' Enter", item.session_name))
                elseif attempts < max_attempts then
                  vim.defer_fn(wait_for_client, 100)
                end
              end,
            })
          end
          vim.defer_fn(wait_for_client, 100)
        end

        vim.schedule(restore_next)
      end

      vim.schedule(restore_next)
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
