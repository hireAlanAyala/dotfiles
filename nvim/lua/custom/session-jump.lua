-- session-jump: a bufjump-style forward/back jumplist for tmux *parent* sessions.
--
-- bufjump (custom/plugins/bufjump.lua) walks a per-window jumplist of buffers with
-- <M-o>/<M-i>. This does the same thing across whole tmux projects: <leader>so jumps
-- back and <leader>si jumps forward through the parent (project) sessions you've
-- visited, switching the tmux client each time.
--
-- Why a file instead of in-memory state: switching the tmux client moves the terminal
-- to a *different* nvim instance (each project has its own nvim). So the jumplist can't
-- live in one nvim's memory -- it's persisted to a shared JSON file that every nvim
-- instance reads and writes. The file is the single source of truth; nothing is cached.
--
-- "Parent" sessions are the project-level ones. terminal-persist spawns helper
-- sub-sessions named <parent>_<6hex>_<label> (e.g. _config_70a7bd_a_agent); those are
-- excluded. A session is a sub-session iff its name matches `_%x%x%x%x%x%x_`, matching
-- the convention already used in custom/plugins/fzf-lua.lua and terminal-persist.

local M = {}

local STATE_FILE = vim.fn.stdpath('state') .. '/tmux-session-jumplist.json'
local MAX_ENTRIES = 50 -- cap so back-and-forth flapping can't grow the stack forever

-- Run a tmux command against the server. TMUX='' detaches from the nested client so we
-- always talk to the most-recently-active client/session (mirrors fzf-lua.lua's usage).
local function tmux(args)
  return vim.system(vim.list_extend({ 'tmux' }, args), { env = { TMUX = '' } }):wait()
end

local function is_sub_session(name)
  return name:match('_%x%x%x%x%x%x_') ~= nil
end

-- Reduce a session name to its parent: a sub-session <parent>_<hash>_<label> maps to
-- <parent>; a parent maps to itself.
local function to_parent(name)
  return name:match('^(.-)_%x%x%x%x%x%x_') or name
end

local function session_exists(name)
  return tmux({ 'has-session', '-t', name }).code == 0
end

-- The parent session the active tmux client is currently in, or nil if not in tmux.
--
-- Normally nvim runs in the parent client, so display-message returns the parent name
-- directly and no reduction is needed. We only reduce when the client reports a
-- sub-session AND the reduced parent actually exists -- because the reduction assumes
-- the parent's name equals the sub-session prefix, which isn't always true (e.g. the
-- config project's parent is named `-config` but its sub-sessions are `_config_<hash>_…`).
local function current_parent()
  if vim.env.TMUX == nil or vim.env.TMUX == '' then return nil end
  local res = tmux({ 'display-message', '-p', '#{session_name}' })
  if res.code ~= 0 then return nil end
  local name = vim.trim(res.stdout or '')
  if name == '' then return nil end
  if not is_sub_session(name) then return name end

  local parent = to_parent(name)
  if parent ~= name and session_exists(parent) then return parent end
  return nil -- a sub-session whose parent we can't resolve; don't record a bogus entry
end

-- Set of session names that currently exist (one tmux call instead of one per entry).
local function live_sessions()
  local set = {}
  local res = tmux({ 'list-sessions', '-F', '#{session_name}' })
  if res.code ~= 0 then return set end
  for line in (res.stdout or ''):gmatch('[^\n]+') do
    set[vim.trim(line)] = true
  end
  return set
end

local function read_state()
  local f = io.open(STATE_FILE, 'r')
  if not f then return { stack = {}, cursor = 0 } end
  local content = f:read('*a')
  f:close()
  local ok, decoded = pcall(vim.json.decode, content)
  if not ok or type(decoded) ~= 'table' or type(decoded.stack) ~= 'table' then
    return { stack = {}, cursor = 0 }
  end
  decoded.cursor = decoded.cursor or 0
  return decoded
end

-- Atomic write (temp + rename) so concurrent nvim instances never read a half-written file.
local function write_state(state)
  local tmp = STATE_FILE .. '.tmp'
  local f = io.open(tmp, 'w')
  if not f then return end
  f:write(vim.json.encode(state))
  f:close()
  os.rename(tmp, STATE_FILE)
end

-- Drop dead sessions from the stack, keeping the cursor pointed at the same logical entry
-- (or the nearest surviving one before it).
local function prune(state, live)
  local alive, new_cursor = {}, 0
  for i, name in ipairs(state.stack) do
    if live[name] then
      table.insert(alive, name)
      if i <= state.cursor then new_cursor = #alive end
    end
  end
  if new_cursor == 0 and #alive > 0 then new_cursor = 1 end
  state.stack, state.cursor = alive, new_cursor
end

-- Record an arrival at `parent`. A no-op if we're already there (this is what makes
-- forward history survive our own back/forward jumps: after a jump the cursor already
-- points at the destination, so the landing nvim's FocusGained records nothing). A
-- genuinely new destination truncates any forward history and pushes the new entry.
function M.record(parent)
  parent = parent or current_parent()
  if not parent or is_sub_session(parent) then return end

  local state = read_state()
  if state.stack[state.cursor] == parent then return end

  for i = #state.stack, state.cursor + 1, -1 do
    state.stack[i] = nil
  end
  table.insert(state.stack, parent)

  while #state.stack > MAX_ENTRIES do
    table.remove(state.stack, 1)
  end
  state.cursor = #state.stack
  write_state(state)
end

-- dir: -1 = back (<leader>so), +1 = forward (<leader>si)
local function jump(dir)
  local parent = current_parent()
  if not parent then
    vim.notify('session-jump: not inside a tmux session', vim.log.levels.WARN)
    return
  end
  M.record(parent) -- make sure where we are is on the stack before moving

  local state = read_state()
  prune(state, live_sessions())

  local target = state.cursor + dir
  if target < 1 or target > #state.stack then
    vim.notify(
      dir < 0 and 'session-jump: no earlier session' or 'session-jump: no later session',
      vim.log.levels.INFO
    )
    return
  end

  state.cursor = target
  write_state(state) -- write before switching so the destination nvim sees the new cursor
  -- async so nvim doesn't block while the client switches away
  vim.fn.jobstart({ 'tmux', 'switch-client', '-t', state.stack[target] }, { env = { TMUX = '' } })
end

function M.backward() jump(-1) end
function M.forward() jump(1) end

-- Cached name of the parent session this nvim instance lives in, for the statusline.
-- A given nvim's parent is effectively constant (switching clients moves to a *different*
-- nvim), so we only recompute on focus/enter -- the statusline reads the cache and never
-- makes a blocking tmux call on redraw.
M._parent = nil

function M.refresh()
  M._parent = current_parent()
  return M._parent
end

-- Returns the parent session name, or nil if this nvim isn't in a tmux parent session.
function M.parent_session()
  return M._parent
end

function M.setup()
  -- Alt+Shift+o/i mirrors bufjump's Alt+o/i (buffers); Shift marks the "bigger" jump.
  vim.keymap.set('n', '<M-S-o>', M.backward, { desc = 'Jump to previous tmux session' })
  vim.keymap.set('n', '<M-S-i>', M.forward, { desc = 'Jump to next tmux session' })

  -- Record the current project on startup and whenever this nvim's client becomes
  -- active again -- this captures session switches made outside these keymaps (the
  -- <leader>ss picker, tmux `prefix s`, terminal-persist) so the jumplist stays honest.
  local group = vim.api.nvim_create_augroup('SessionJump', { clear = true })
  vim.api.nvim_create_autocmd({ 'VimEnter', 'FocusGained' }, {
    group = group,
    callback = function() M.record(M.refresh()) end,
  })

  M.refresh() -- populate the cache before lualine first draws
end

return M
