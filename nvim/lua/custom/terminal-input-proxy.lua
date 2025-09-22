-- terminal_input_proxy.lua
local M = {}

-- ---------- utils ----------
local function sys(cmd, args)
  -- Neovim 0.10+: vim.system; fallback to vim.fn.systemlist
  if vim.system then
    local res = vim.system(vim.list_extend({ cmd }, args or {}), { text = true }):wait()
    if res.code ~= 0 then
      return nil, res.stderr
    end
    return res.stdout, nil
  else
    local out = vim.fn.systemlist(vim.list_extend({ cmd }, args or {}))
    if vim.v.shell_error ~= 0 then
      return nil, table.concat(out, '\n')
    end
    return table.concat(out, '\n'), nil
  end
end

local function trim(s)
  return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

local function get_job_tty(job_id)
  -- Use `ps -o tty=` on the job's PID. Linux/mac both support this.
  local pid = vim.fn.jobpid(job_id)
  if not pid or pid <= 0 then
    return nil
  end
  local out = sys('ps', { '-o', 'tty=', '-p', tostring(pid) })
  if not out then
    return nil
  end
  local tty = trim(out)
  if tty == '' or tty == '?' then
    return nil
  end
  -- Normalize to /dev/pts/N (Linux) or /dev/ttysNN (macOS)
  if not tty:match '^/dev/' then
    tty = '/dev/' .. tty
  end
  return tty
end

local function find_tmux_pane_by_tty(tty)
  -- Search all panes and match pane_tty to the job's tty
  local out = sys('tmux', { 'list-panes', '-a', '-F', '#{pane_id} #{pane_tty}' })
  if not out then
    return nil
  end
  for line in out:gmatch '[^\r\n]+' do
    local pane, ptty = line:match '(%S+)%s+(%S+)'
    if pane and ptty and trim(ptty) == tty then
      return pane
    end
  end
  return nil
end

local function tmux_send_keys(pane, keys)
  -- keys can be a list like {"End", "C-u"} or a single string
  if type(keys) == 'string' then
    -- Use -l -- to send literal characters (handles spaces/shell metachars)
    sys('tmux', { 'send-keys', '-t', pane, '-l', '--', keys })
  elseif type(keys) == 'table' then
    -- For named keys / chords, call without -l
    -- e.g., {"End"} or {"C-u"} or {"Enter"}
    for _, k in ipairs(keys) do
      sys('tmux', { 'send-keys', '-t', pane, k })
    end
  end
end

-- Position cursor using arrow keys (reliable across all terminals)
local function tmux_position_cursor(pane, target_col, text_length)
  if target_col >= text_length then
    return -- Cursor is already at or past the end
  end
  
  -- Calculate how many positions to move left from the end
  local moves_left = text_length - target_col
  if moves_left > 0 then
    -- Send multiple Left keys efficiently in one command
    local left_keys = {}
    for i = 1, moves_left do
      table.insert(left_keys, 'Left')
    end
    tmux_send_keys(pane, left_keys)
  end
end

-- Small debounce so we don't hammer tmux on every char
local function make_debouncer(ms)
  local timer = nil
  return function(fn)
    if timer then
      timer:stop()
      timer:close()
    end
    timer = vim.loop.new_timer()
    timer:start(ms, 0, function()
      -- Schedule the callback to run in the main thread
      vim.schedule(function()
        pcall(fn)
      end)
      timer:stop()
      timer:close()
      timer = nil
    end)
  end
end

-- ---------- state ----------
M.state = {
  buf = nil,
  win = nil,
  active = false,
  term_job_id = nil,
  pane_id = nil,
  augroup = nil,
  mode = nil, -- 'direct' or 'session'
  session_name = nil,
}

-- ---------- public ----------
-- Set up editing mode on terminal buffer
function M._setup_terminal_mappings(term_buf, proxy_buf)
  -- Simple approach: map Ctrl+E to toggle editing mode
  local opts = { buffer = term_buf, noremap = true, silent = true }
  
  vim.keymap.set('t', '<C-e>', function()
    M._enter_edit_mode(proxy_buf)
  end, opts)
  
  vim.keymap.set('t', '<Esc>', function() 
    M.close_input_buffer() 
  end, opts)
end

-- Enter edit mode with a visible buffer for editing
function M._enter_edit_mode(proxy_buf)
  -- Get current line from terminal
  local current_line = M._get_current_terminal_line()
  
  -- Set proxy buffer content
  vim.api.nvim_buf_set_lines(proxy_buf, 0, -1, false, { current_line or '' })
  
  -- Create a temporary window for editing
  local width = math.min(80, math.max(40, math.floor(vim.o.columns * 0.8)))
  local win = vim.api.nvim_open_win(proxy_buf, true, {
    relative = 'editor',
    width = width,
    height = 1,
    row = vim.o.lines - 4,
    col = math.floor((vim.o.columns - width) / 2),
    style = 'minimal',
    border = { '╭', '─', '╮', '│', '╯', '─', '╰', '│' },
    title = ' Edit Terminal Line ',
    title_pos = 'center',
  })
  
  M.state.win = win
  vim.cmd('startinsert')
end

-- Try to get current line from terminal (simplified)
function M._get_current_terminal_line()
  -- This is a placeholder - getting the current line from terminal is complex
  return ""
end

function M.close_input_buffer()
  -- Before closing, preserve the current cursor position from the proxy buffer
  if M.state.active and M.state.pane_id and M.state.buf and vim.api.nvim_buf_is_valid(M.state.buf) then
    local cursor_pos = vim.api.nvim_win_get_cursor(M.state.win or 0)
    local cursor_col = cursor_pos[2] -- 0-based column
    local text = vim.api.nvim_get_current_line()
    
    -- Apply the final state with cursor position
    local function apply_final_line()
      tmux_send_keys(M.state.pane_id, { 'End' })
      tmux_send_keys(M.state.pane_id, { 'C-u' })
      if text and #text > 0 then
        tmux_send_keys(M.state.pane_id, text)
        -- Position cursor where it was in the proxy buffer
        if cursor_col < #text then
          tmux_position_cursor(M.state.pane_id, cursor_col, #text)
        end
      end
    end
    
    apply_final_line()
  end
  
  if M.state.win and vim.api.nvim_win_is_valid(M.state.win) then
    vim.api.nvim_win_close(M.state.win, true)
  end
  if M.state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, M.state.augroup)
  end
  
  -- After closing proxy, make sure we're in insert mode in the terminal
  vim.defer_fn(function()
    vim.cmd('startinsert')
  end, 50)
  
  M.state = {
    buf = nil,
    win = nil,
    active = false,
    term_job_id = nil,
    pane_id = nil,
    augroup = nil,
    mode = nil,
    session_name = nil,
    last_text = '',
    last_cursor = 0,
  }
end

-- Helper to find tmux pane by session name
local function find_tmux_pane_by_session(session_name)
  -- Get the active pane for the session
  local out = sys('tmux', { 'list-panes', '-t', session_name, '-F', '#{pane_active} #{pane_id}' })
  if not out then
    return nil
  end
  for line in out:gmatch '[^\r\n]+' do
    local active, pane = line:match '(%S+)%s+(%S+)'
    if active == '1' and pane then
      return pane
    end
  end
  -- If no active pane, get the first one
  local first_pane = sys('tmux', { 'list-panes', '-t', session_name, '-F', '#{pane_id}' })
  if first_pane then
    return trim(first_pane):match '^[^\r\n]+'
  end
  return nil
end

function M.open_input_buffer_for_session(session_name)
  -- Find tmux pane from session name
  local pane = find_tmux_pane_by_session(session_name)
  if not pane then
    vim.notify('TermProxy: could not find tmux pane for session ' .. session_name, vim.log.levels.ERROR)
    return
  end

  -- Create and configure the input buffer (shared code)
  M._create_input_buffer(pane, 'session', nil, session_name)
end

function M.open_input_buffer(term_job_id)
  -- Resolve tmux pane from the terminal job
  local tty = get_job_tty(term_job_id)
  if not tty then
    vim.notify('TermProxy: could not resolve TTY for job ' .. tostring(term_job_id), vim.log.levels.ERROR)
    return
  end
  local pane = find_tmux_pane_by_tty(tty)
  if not pane then
    vim.notify('TermProxy: could not find tmux pane for TTY ' .. tty, vim.log.levels.ERROR)
    return
  end

  -- Create and configure the input buffer (shared code)
  M._create_input_buffer(pane, 'direct', term_job_id, nil)
end

-- Shared function to create the input buffer
function M._create_input_buffer(pane_id, mode, term_job_id, session_name)

  local buf = vim.api.nvim_create_buf(false, true)
  -- Make buffer name unique to avoid conflicts
  local buf_name = string.format('[Terminal Input Proxy %d]', vim.fn.getpid() .. os.time())
  vim.api.nvim_buf_set_name(buf, buf_name)
  vim.bo[buf].filetype = 'TermProxy'

  -- Create a very small, unobtrusive window at the bottom
  local width = math.min(60, math.floor(vim.o.columns * 0.8))
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = width,
    height = 1,
    row = vim.o.lines - 2,
    col = 0,
    style = 'minimal',
    border = 'none',
  })
  
  -- Make it blend in
  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:StatusLine')

  -- Save state
  M.state = {
    buf = buf,
    win = win,
    active = true,
    term_job_id = term_job_id,
    pane_id = pane_id,
    augroup = vim.api.nvim_create_augroup('TermInputProxyAU', { clear = true }),
    mode = mode,
    session_name = session_name,
    last_text = '', -- Track previous text for incremental updates
    last_cursor = 0, -- Track previous cursor position
  }

  -- Enter insert mode
  vim.cmd('startinsert')

  -- Core "live update" function: move to end, clear line, write new text
  local function apply_line(new_text, cursor_col)
    if not (M.state.active and M.state.pane_id) then
      return
    end
    
    -- Move cursor to end, clear line back to bol, then type literal text
    tmux_send_keys(M.state.pane_id, { 'End' })
    tmux_send_keys(M.state.pane_id, { 'C-u' })
    
    if new_text and #new_text > 0 then
      tmux_send_keys(M.state.pane_id, new_text)
      
      -- Position cursor using arrow keys if not at the end
      if cursor_col ~= nil and cursor_col < #new_text then
        tmux_position_cursor(M.state.pane_id, cursor_col, #new_text)
      end
    end
    
    -- Update state
    M.state.last_text = new_text
    M.state.last_cursor = cursor_col
  end

  -- Debounced updater on TextChangedI
  local debounce = make_debouncer(10) -- Reduced from 25ms to 10ms for more responsive typing
  vim.api.nvim_create_autocmd({ 'TextChangedI' }, {
    group = M.state.augroup,
    buffer = buf,
    callback = function()
      local new_text = vim.api.nvim_get_current_line()
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      local cursor_col = cursor_pos[2] -- 0-based column
      debounce(function()
        apply_line(new_text, cursor_col)
      end)
    end,
  })

  -- Also update when cursor moves in insert mode
  vim.api.nvim_create_autocmd({ 'CursorMovedI' }, {
    group = M.state.augroup,
    buffer = buf,
    callback = function()
      local new_text = vim.api.nvim_get_current_line()
      local cursor_pos = vim.api.nvim_win_get_cursor(0)
      local cursor_col = cursor_pos[2] -- 0-based column
      debounce(function()
        apply_line(new_text, cursor_col)
      end)
    end,
  })

  -- Submit on Enter
  vim.keymap.set('i', '<CR>', function()
    local input = vim.api.nvim_get_current_line()
    -- Ensure the line in tmux matches our buffer right before submit (cursor at end)
    apply_line(input, #input)
    -- Send Enter
    tmux_send_keys(M.state.pane_id, { 'Enter' })
    M.close_input_buffer()
  end, { buffer = buf, noremap = true, silent = true })

  -- Cancel on Esc (no input sent)
  vim.keymap.set('i', '<Esc>', function()
    M.close_input_buffer()
  end, { buffer = buf, noremap = true, silent = true })

  -- Close if user leaves the window or buffer is wiped
  vim.api.nvim_create_autocmd({ 'BufLeave', 'BufWipeout' }, {
    group = M.state.augroup,
    buffer = buf,
    callback = function()
      M.close_input_buffer()
    end,
  })
end

function M.toggle_input_proxy()
  -- Always close existing proxy buffer first if it exists
  if M.state.active then
    M.close_input_buffer()
  end

  local bufnr = vim.api.nvim_get_current_buf()
  
  -- Check if it's a persistent terminal with tmux session
  local tmux_session = vim.b[bufnr] and vim.b[bufnr].tmux_session
  if tmux_session then
    vim.cmd 'stopinsert'
    M.open_input_buffer_for_session(tmux_session)
    return
  end
  
  -- Otherwise, try regular terminal job
  local term_job_id = vim.b[bufnr] and vim.b[bufnr].terminal_job_id
  if not term_job_id then
    print 'Not in a terminal buffer.'
    return
  end

  vim.cmd 'stopinsert'
  M.open_input_buffer(term_job_id)
end

vim.api.nvim_create_user_command('ToggleTerminalInput', function()
  M.toggle_input_proxy()
end, {})

return M
