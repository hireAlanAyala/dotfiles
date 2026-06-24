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
  -- Where per-session output logs are streamed for live inspection. Logs live
  -- exactly as long as their tmux session (see arm_logging). Out-of-repo so
  -- they can't be committed; agent terminals (name ~ '^a_') are never logged.
  log_dir = vim.fn.stdpath('state') .. '/term-logs',
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
-- Output logging
-- ============================================================================

-- Path of the log file for a session (always derivable, even if logging is off).
local function log_path(session_name)
  return M.config.log_dir .. '/' .. session_name .. '.log'
end

-- Stream a session's pane output to a log file for live inspection.
-- The piped `cat` reads the pane's output; when the tmux session/pane dies it
-- gets EOF and exits, and the EXIT trap removes the log -- so the file lives
-- exactly as long as the session does (it survives nvim quit because the
-- session does). Only newly-created, non-agent sessions are armed; restored
-- sessions are already piping from the nvim that created them.
local function arm_logging(session_name, name)
  if not name or name:match('^a_') then return end
  local log = log_path(session_name)
  vim.fn.mkdir(M.config.log_dir, 'p')
  -- No `exec`: the shell must stay alive as cat's parent so the trap survives.
  -- When the pane dies cat gets EOF (or tmux signals the command); the trap then
  -- removes the log. Trap signals too, in case tmux terminates rather than EOFs.
  local pipe_cmd = string.format("trap 'rm -f %s' EXIT HUP INT TERM; cat > %s", log, log)
  vim.system({ 'tmux', 'pipe-pane', '-t', session_name, pipe_cmd })
end

-- ============================================================================
-- Terminal Creation
-- ============================================================================

local function create_terminal(session_name, name, switch, strategy_name, attach_only)
  strategy_name = strategy_name or get_strategy_for_name(name)
  local strategy = get_strategy(strategy_name)
  local buf_nr = vim.api.nvim_create_buf(true, false)

  -- Detect whether create_or_attach is about to create a brand-new session, so
  -- we only arm logging once (not on restore/attach, which would replace a live
  -- pipe and trip its cleanup trap). Skipped on the restore hot path (attach_only).
  local newly_created = false
  if not attach_only and strategy.session_exists then
    newly_created = not strategy:session_exists(session_name)
  end

  vim.api.nvim_buf_call(buf_nr, function()
    local cmd = attach_only and strategy:attach(session_name) or strategy:create_or_attach(session_name)
    vim.fn.termopen(cmd)
    vim.bo[buf_nr].scrollback = M.config.scrollback
  end)

  if newly_created then
    arm_logging(session_name, name)
  end

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
    -- Output log for live inspection (nil for agent terminals, which aren't logged).
    log = (name and not name:match('^a_')) and log_path(session_name) or nil,
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
          -- On the initial startup restore only, wipe jumplist entries added
          -- by buffer switches during restore so <C-o> from the user's first
          -- navigation doesn't land in a terminal buffer they never visited.
          -- Subsequent manual restores leave the jumplist alone.
          if M._initial_restore then
            M._initial_restore = false
            vim.cmd('clearjumps')
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

        local is_agent_session = item.session_name:match('_%x%x%x%x%x%x_a_') ~= nil
        if item.strategy_name == 'tmux' and (item.info.claude_session_id or is_agent_session) then
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
-- De-wrap yanks (pull joined text from tmux instead of nvim's wrapped grid)
-- ============================================================================
--
-- nvim's terminal buffer stores the screen as a grid: a command wider than the
-- pane wraps onto multiple physical rows, each becoming a separate buffer line.
-- Yanking across a wrap therefore captures a hard newline that was never in the
-- command -- pasting it into a shell runs the first line early. On a *multi-line*
-- yank in a managed terminal we rejoin the command via one of two strategies:
--
--   1. tmux: for content that lives in the tmux pane (plain terminals), tmux
--      tracks which rows are soft-wrap continuations, so `capture-pane -J`
--      rejoins them. We look the selection up in that joined capture.
--   2. grid width: claude terminals run *outside* tmux (the wrapper's detach
--      dance), so their output lives in nvim's own grid -- tmux's pane is empty.
--      There we reconstruct from the grid: a row filling the full terminal width
--      is a soft-wrap continuation; a shorter row ends a real line.
--
-- Single-line yanks (already correct), and either strategy finding nothing, fall
-- through untouched -- so this is never worse than a native yank, and the grid
-- path fails *safe* (an unrecognised break stays split, never a silent merge).

-- How far back to search tmux history for the yanked command (lines).
M.config.dewrap_depth = M.config.dewrap_depth or 10000

-- Charwise-replace the just-yanked text, so it pastes as one shell-ready line.
-- Mirrors to '0' (the yank register) when the yank was to the unnamed register.
local function set_dewrapped(event, joined)
  local reg = (event.regname ~= '' and event.regname) or '"'
  vim.fn.setreg(reg, joined, 'v')
  if event.regname == '' then vim.fn.setreg('0', joined, 'v') end
end

-- Strategy 1: rejoin via tmux's wrap flags. Returns true if it replaced the reg.
local function dewrap_via_tmux(event, session)
  -- Anchor on the first and last selected rows. Matching against trimmed text
  -- sidesteps the grid's trailing-pad spaces; capturing without `-e` keeps the
  -- text plain so it compares byte-for-byte with what nvim displayed.
  local lines = event.regcontents
  local first = vim.trim(lines[1])
  local last = vim.trim(lines[#lines])
  if first == '' then return false end

  local res = vim.system(
    { 'tmux', 'capture-pane', '-p', '-J', '-t', session, '-S', '-' .. M.config.dewrap_depth },
    { text = true }
  ):wait()
  if res.code ~= 0 or not res.stdout then return false end

  -- Search most-recent-first: find a logical line containing the first row, then
  -- require the last row to appear after it on that same line. Two anchors make a
  -- wrong-line match very unlikely; the slice between them is the rejoined command.
  local captured = vim.split((res.stdout:gsub('\n$', '')), '\n', { plain = true })
  for i = #captured, 1, -1 do
    local line = captured[i]
    local s = line:find(first, 1, true)
    if s then
      local e = line:find(last, s, true)
      if e then
        set_dewrapped(event, line:sub(s, e + #last - 1))
        return true
      end
    end
  end
  return false
end

-- Strategy 2: reconstruct from nvim's own grid using terminal width (claude
-- terminals, whose output never reaches tmux). Returns true if it merged rows.
local function dewrap_via_grid(event)
  local win = vim.api.nvim_get_current_win()
  local width = vim.api.nvim_win_get_width(win) - (vim.fn.getwininfo(win)[1].textoff or 0)
  if width < 1 then return false end

  -- Use the full buffer lines of the yanked region (marked '[ .. ']), not the
  -- possibly column-trimmed selection -- width detection needs whole rows.
  local sp, ep = vim.fn.getpos("'["), vim.fn.getpos("']")
  if sp[2] == 0 or ep[2] == 0 or ep[2] < sp[2] then return false end
  local full = vim.api.nvim_buf_get_lines(0, sp[2] - 1, ep[2], false)
  if #full < 2 then return false end

  -- A row that fills the full width is a soft-wrap continuation -> concatenate
  -- the next row with no separator; a shorter row is a real line break.
  local out, cur = {}, full[1]
  for i = 2, #full do
    if vim.fn.strdisplaywidth(full[i - 1]) >= width then
      cur = cur .. full[i]
    else
      table.insert(out, cur)
      cur = full[i]
    end
  end
  table.insert(out, cur)

  if #out >= #full then return false end -- nothing merged: leave native yank
  set_dewrapped(event, table.concat(out, '\n'))
  return true
end

local function dewrap_yank(event)
  -- Only post-process genuine yanks of multi-line text in a managed terminal.
  if event.operator ~= 'y' then return end
  if vim.bo.buftype ~= 'terminal' then return end
  local session = vim.b.persist_session
  if not session then return end

  local lines = event.regcontents
  if type(lines) ~= 'table' or #lines < 2 then return end -- single line: native

  -- tmux first (authoritative wrap flags); grid fallback for content that lives
  -- in nvim rather than the tmux pane. Either miss leaves the native yank.
  if dewrap_via_tmux(event, session) then return end
  dewrap_via_grid(event)
end

-- ============================================================================
-- Setup
-- ============================================================================

function M.setup(opts)
  if opts then
    M.config = vim.tbl_deep_extend('force', M.config, opts)
  end

  if M.config.auto_restore then
    M._initial_restore = true
    vim.defer_fn(M.restore, 100)
  end

  -- De-wrap multi-line yanks in managed terminals by rejoining via tmux.
  vim.api.nvim_create_autocmd('TextYankPost', {
    group = vim.api.nvim_create_augroup('terminal-persist-dewrap', { clear = true }),
    desc = 'Rejoin wrapped commands yanked from a managed terminal (tmux capture-pane -J)',
    callback = function() dewrap_yank(vim.v.event) end,
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
