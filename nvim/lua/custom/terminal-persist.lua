-- Terminal persistence plugin
-- Vanilla terminals for claude (session restored via `c` wrapper)
-- tmux-backed terminals for everything else

local M = {}

M.config = {
  state_file = '.nvim/terminal-sessions.json',
  auto_restore = true,
  scrollback = 100000,
  history_limit = 50000,
  vanilla_patterns = { '^claude' },
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

local function is_vanilla(name)
  if not name then return false end
  for _, pattern in ipairs(M.config.vanilla_patterns) do
    if name:match(pattern) then return true end
  end
  return false
end

local function terminal_has_tmux(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  local pid = vim.b[buf].terminal_job_pid
  if not pid then return false end
  local result = vim.fn.system(string.format('pstree -p %d 2>/dev/null', pid))
  return result:match 'tmux' ~= nil
end

local function tmux_session_exists(session_name)
  vim.fn.system(string.format('tmux has-session -t %s 2>/dev/null', session_name))
  return vim.v.shell_error == 0
end

local function tmux_create_session(session_name)
  vim.fn.system(string.format(
    "tmux new-session -d -s %s -c '%s' \\; set-option -t %s history-limit %d",
    session_name, vim.fn.getcwd(), session_name, M.config.history_limit
  ))
end

local function tmux_kill_session(session_name)
  if tmux_session_exists(session_name) then
    vim.fn.system(string.format('tmux kill-session -t "%s" 2>&1', session_name))
  end
end

-- ============================================================================
-- Terminal Creation
-- ============================================================================

local function create_terminal(session_name, name, use_vanilla, switch)
  local buf_nr = vim.api.nvim_create_buf(true, false)

  vim.api.nvim_buf_call(buf_nr, function()
    if use_vanilla then
      vim.fn.termopen(vim.o.shell, { env = { NVIM_TERMINAL_SESSION = session_name } })
    else
      if not tmux_session_exists(session_name) then
        tmux_create_session(session_name)
      end
      vim.fn.termopen(string.format('~/.config/scripts/tmux-attach-with-history.sh %s', session_name))
    end
    vim.bo[buf_nr].scrollback = M.config.scrollback
  end)

  -- Setup buffer
  vim.b[buf_nr].terminal_persist_managed = true
  vim.b[buf_nr].persist_session = session_name
  vim.b[buf_nr].persist_name = name
  vim.b[buf_nr].is_vanilla = use_vanilla
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
  local use_vanilla = is_vanilla(name)

  local buf_nr = create_terminal(session_name, name, use_vanilla, switch)

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
    is_vanilla = use_vanilla,
    created = os.time(),
  }
  write_state(state)

  return buf_nr, session_name
end

function M.restore()
  local state = read_state()
  local project_id = get_project_id()
  local restored = 0

  local current_win = vim.api.nvim_get_current_win()
  local current_buf = vim.api.nvim_get_current_buf()

  for session_name, info in pairs(state) do
    if type(info) == 'table' and info.name and session_name:sub(1, #project_id) == project_id then
      local should_restore = info.claude_session_id -- has claude session to resume
        or (not info.is_vanilla and tmux_session_exists(session_name)) -- tmux session alive

      if should_restore then
        local buf_nr = create_terminal(session_name, info.name, info.is_vanilla or info.claude_session_id, false)

        -- Auto-run `c --restore` for claude sessions
        if info.claude_session_id then
          vim.defer_fn(function()
            local chan = vim.b[buf_nr].terminal_job_id
            if chan then vim.api.nvim_chan_send(chan, 'c --restore\n') end
          end, 150)
        end

        restored = restored + 1
      end
    end
  end

  vim.api.nvim_set_current_win(current_win)
  vim.api.nvim_set_current_buf(current_buf)

  if restored > 0 then
    vim.notify(string.format('Restored %d terminal(s)', restored))
  end

  return restored
end

function M.has_tmux(buf)
  return terminal_has_tmux(buf)
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

  vim.api.nvim_create_user_command('HasTmux', function()
    local has = terminal_has_tmux()
    vim.notify(has and 'tmux: yes' or 'tmux: no', vim.log.levels.INFO)
  end, { desc = 'Check if current terminal has tmux running inside' })

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
      local vanilla = vim.b[buf].is_vanilla
      if not session then return end

      vim.defer_fn(function()
        if not vanilla then tmux_kill_session(session) end
        local state = read_state()
        state[session] = nil
        write_state(state)
      end, 100)
    end,
  })
end

return M
