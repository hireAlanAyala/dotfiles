-- terminal_input_proxy.lua
local M = {}

-- Configuration
M.config = {
  update_strategy = 'readline',
  debounce_ms = 10,
}

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

-- Small debounce so we don't hammer tmux on every char
local function make_debouncer(ms)
  local timer = nil
  return function(fn)
    if timer then
      timer:stop()
      timer:close()
    end
    -- Use vim.uv (modern) or fallback to vim.loop (legacy)
    local uv = vim.uv or vim.loop
    timer = uv.new_timer()
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

-- ---------- Terminal Update Strategies (Dependency Injection) ----------

-- Strategy interface: each strategy handles the entire update process
local strategies = {}

-- Strategy 1: Readline Commands (current working method)
strategies.readline = {
  name = "Readline Commands",
  description = "Uses End + Ctrl+U + arrow keys (most reliable)",
  
  update = function(pane_id, new_text, cursor_col, old_text, old_cursor)
    -- Move to end, clear line, write text, position cursor
    tmux_send_keys(pane_id, { 'End' })
    tmux_send_keys(pane_id, { 'C-u' })
    
    if new_text and #new_text > 0 then
      tmux_send_keys(pane_id, new_text)
      
      if cursor_col ~= nil and cursor_col < #new_text then
        local moves_left = #new_text - cursor_col
        if moves_left > 0 then
          local left_keys = {}
          for i = 1, moves_left do
            table.insert(left_keys, 'Left')
          end
          tmux_send_keys(pane_id, left_keys)
        end
      end
    end
  end
}

-- Strategy 2: Escape Sequences (atomic single command)
strategies.escape_sequences = {
  name = "Escape Sequences",
  description = "Single atomic escape sequence command",
  
  update = function(pane_id, new_text, cursor_col, old_text, old_cursor)
    local cmd = '\r' -- Carriage return to beginning
    
    if new_text and #new_text > 0 then
      cmd = cmd .. new_text
    end
    
    cmd = cmd .. '\033[K' -- Clear to end
    
    if cursor_col ~= nil and cursor_col < #new_text then
      cmd = cmd .. string.format('\033[%dG', cursor_col + 1)
    end
    
    sys('tmux', { 'send-keys', '-t', pane_id, cmd })
  end
}

-- Strategy 3: Control Characters (Ctrl+A + Ctrl+K)
strategies.control_chars = {
  name = "Control Characters",
  description = "Uses Ctrl+A and Ctrl+K control sequences",
  
  update = function(pane_id, new_text, cursor_col, old_text, old_cursor)
    sys('tmux', { 'send-keys', '-t', pane_id, 'C-a' })
    sys('tmux', { 'send-keys', '-t', pane_id, 'C-k' })
    
    if new_text and #new_text > 0 then
      sys('tmux', { 'send-keys', '-t', pane_id, '-l', new_text })
      
      if cursor_col ~= nil and cursor_col < #new_text then
        local moves_left = #new_text - cursor_col
        if moves_left > 0 then
          local left_keys = {}
          for i = 1, moves_left do
            table.insert(left_keys, 'Left')
          end
          tmux_send_keys(pane_id, left_keys)
        end
      end
    end
  end
}

-- Strategy 4: Incremental Updates (smart diffing)
strategies.incremental = {
  name = "Incremental Updates",
  description = "Only sends changes, not full line rewrites",
  
  update = function(pane_id, new_text, cursor_col, old_text, old_cursor)
    old_text = old_text or ''
    
    -- Simple case: just appending at the end
    if old_cursor == #old_text and cursor_col == #new_text and 
       new_text:sub(1, #old_text) == old_text then
      local to_append = new_text:sub(#old_text + 1)
      if #to_append > 0 then
        tmux_send_keys(pane_id, to_append)
      end
      return
    end
    
    -- Simple case: backspace at end
    if old_cursor == #old_text and cursor_col == #new_text and 
       #new_text == #old_text - 1 and old_text:sub(1, #new_text) == new_text then
      tmux_send_keys(pane_id, { 'BackSpace' })
      return
    end
    
    -- Complex case: fall back to readline strategy
    strategies.readline.update(pane_id, new_text, cursor_col, old_text, old_cursor)
  end
}


-- Get current strategy
local function get_strategy()
  return strategies[M.config.update_strategy] or strategies.readline
end

-- Public functions to manage strategies
function M.set_strategy(strategy_name)
  if strategies[strategy_name] then
    M.config.update_strategy = strategy_name
    vim.notify(string.format('Terminal input strategy set to: %s', strategies[strategy_name].name))
    return true
  else
    vim.notify('Unknown strategy: ' .. strategy_name, vim.log.levels.ERROR)
    return false
  end
end

function M.list_strategies()
  local available = {}
  for name, strategy in pairs(strategies) do
    table.insert(available, {
      name = name,
      title = strategy.name,
      description = strategy.description,
      current = (name == M.config.update_strategy)
    })
  end
  return available
end

function M.get_current_strategy()
  return M.config.update_strategy
end

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
    -- Use vim.uv (modern) or fallback to vim.loop (legacy)
    local uv = vim.uv or vim.loop
    timer = uv.new_timer()
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
  
  -- After closing proxy, stay in normal mode in the terminal
  -- (Remove the startinsert call to stay in normal mode)
  
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

  -- Get the terminal window dimensions and position
  local term_win = vim.api.nvim_get_current_win()
  local win_config = vim.api.nvim_win_get_config(term_win)
  local win_pos = vim.api.nvim_win_get_position(term_win)
  local win_height = vim.api.nvim_win_get_height(term_win)
  local win_width = vim.api.nvim_win_get_width(term_win)
  
  -- Note: We should already be in terminal insert mode from toggle_input_proxy
  
  -- For terminal buffers, we need a different approach
  -- The terminal maintains its own viewport that's separate from the buffer lines
  local term_buf = vim.api.nvim_win_get_buf(term_win)
  
  -- Get the mode to understand terminal state
  local mode = vim.api.nvim_get_mode().mode
  vim.notify(string.format('Current mode: %s', mode))
  
  -- In terminal mode, the cursor is managed by the terminal itself
  -- We'll use a simpler approach: position relative to window
  
  -- Option 1: Use termwinscroll to understand where we are
  local scrolloff = vim.b[term_buf].terminal_scrollback_buffer_size or 0
  local term_info = vim.api.nvim_buf_get_var(term_buf, 'term_title') or ''
  
  -- Option 2: Use marker injection to find exact position
  local offset_from_bottom = 0
  local found_line = nil
  local original_text = ""
  
  -- Step 1: Save current line by sending End + copy to clipboard  
  tmux_send_keys(pane_id, { 'C-e' })  -- Move to end
  tmux_send_keys(pane_id, { 'C-a' })  -- Select to beginning
  
  -- Create unique marker
  local marker = string.format("__NVIM_PROXY_%d__", os.time())
  
  -- Step 2: Replace current line with marker
  tmux_send_keys(pane_id, { 'C-u' })  -- Clear line
  tmux_send_keys(pane_id, marker)
  
  -- Step 3: Give tmux a moment to update the display
  vim.wait(50)
  
  -- Step 4: Find the marker in terminal buffer
  local win_lines = vim.api.nvim_buf_get_lines(term_buf, -win_height, -1, false)
  
  for i = #win_lines, 1, -1 do
    local line = win_lines[i] or ''
    if line:find(marker, 1, true) then
      offset_from_bottom = #win_lines - i
      found_line = line
      -- Extract original text (everything before marker on the line)
      local marker_pos = line:find(marker, 1, true)
      if marker_pos > 1 then
        original_text = line:sub(1, marker_pos - 1)
        -- Remove prompt characters
        local prompt_patterns = { '$ ', '> ', '%% ', '# ', ': ' }
        for _, pattern in ipairs(prompt_patterns) do
          local pos = original_text:find(pattern, 1, true)
          if pos then
            original_text = original_text:sub(pos + #pattern)
            break
          end
        end
      end
      vim.notify(string.format('Found marker at offset %d from bottom, original text: "%s"', offset_from_bottom, original_text))
      break
    end
  end
  
  -- Step 5: Restore original content
  tmux_send_keys(pane_id, { 'C-u' })  -- Clear marker
  if #original_text > 0 then
    tmux_send_keys(pane_id, original_text)
  end
  
  -- If marker wasn't found, fall back to finding last non-empty line
  if not found_line then
    vim.notify('Marker not found, falling back to last line detection')
    for i = #win_lines, math.max(1, #win_lines - 5), -1 do
      local line = win_lines[i] or ''
      if line:match('%S') then
        offset_from_bottom = #win_lines - i
        found_line = line
        original_text = line
        -- Extract command from prompt
        local prompt_patterns = { '$ ', '> ', '%% ', '# ', ': ' }
        for _, pattern in ipairs(prompt_patterns) do
          local pos = original_text:find(pattern, 1, true)
          if pos then
            original_text = original_text:sub(pos + #pattern)
            break
          end
        end
        break
      end
    end
  end
  
  -- Debug output
  vim.notify(string.format('Terminal window: pos=(%d,%d), size=%dx%d', 
    win_pos[1], win_pos[2], win_width, win_height))
  vim.notify(string.format('Mode: %s, Offset from bottom: %d', mode, offset_from_bottom))
  
  -- Calculate floating window position
  local float_row = win_pos[1] + win_height - 1 - offset_from_bottom
  local float_col = win_pos[2]
  
  vim.notify(string.format('Overlay position: row=%d', float_row))
  
  -- Create floating window positioned at cursor line
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    width = win_width,
    height = 1,
    row = float_row,
    col = float_col,
    style = 'minimal',
    border = 'none',
    zindex = 50,  -- Float above other windows
  })
  
  -- Style to match terminal
  vim.api.nvim_win_set_option(win, 'winblend', 0)
  vim.api.nvim_win_set_option(win, 'winhighlight', 'Normal:Normal')
  
  -- Use the original text we captured during marker detection
  local initial_text = original_text or ""
  
  -- Fallback to state if nothing found
  if #initial_text == 0 and M.state and M.state.last_text then
    initial_text = M.state.last_text
  end
  
  vim.notify(string.format('Initial text for proxy buffer: "%s"', initial_text))
  
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { initial_text })
  
  -- Position cursor at end of text
  if #initial_text > 0 then
    vim.api.nvim_win_set_cursor(win, { 1, #initial_text })
  end

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

  -- Core "live update" function: uses dependency injection pattern
  local function apply_line(new_text, cursor_col)
    if not (M.state.active and M.state.pane_id) then
      return
    end
    
    -- Get current strategy and delegate the entire update process
    local strategy = get_strategy()
    strategy.update(
      M.state.pane_id, 
      new_text, 
      cursor_col, 
      M.state.last_text, 
      M.state.last_cursor
    )
    
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

  -- Close when leaving insert mode (entering normal mode)
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = M.state.augroup,
    buffer = buf,
    callback = function()
      M.close_input_buffer()
    end,
  })
  
  -- Keep Esc mapping as backup in case autocmd doesn't fire
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
    -- First ensure we're in terminal insert mode to get accurate position
    vim.cmd 'startinsert'
    vim.defer_fn(function()
      M.open_input_buffer_for_session(tmux_session)
    end, 50)
    return
  end
  
  -- Otherwise, try regular terminal job
  local term_job_id = vim.b[bufnr] and vim.b[bufnr].terminal_job_id
  if not term_job_id then
    print 'Not in a terminal buffer.'
    return
  end

  -- First ensure we're in terminal insert mode to get accurate position
  vim.cmd 'startinsert'
  vim.defer_fn(function()
    M.open_input_buffer(term_job_id)
  end, 50)
end

vim.api.nvim_create_user_command('ToggleTerminalInput', function()
  M.toggle_input_proxy()
end, {})

vim.api.nvim_create_user_command('TerminalInputStrategy', function(opts)
  if #opts.args == 0 then
    -- List available strategies
    local strategy_list = M.list_strategies()
    for _, strategy in ipairs(strategy_list) do
      local marker = strategy.current and " (*)" or ""
      vim.notify(string.format('%s: %s - %s%s', strategy.name, strategy.title, strategy.description, marker))
    end
  else
    -- Set strategy
    M.set_strategy(opts.args)
  end
end, {
  nargs = '?',
  complete = function()
    return { 'readline', 'escape_sequences', 'control_chars', 'incremental' }
  end,
})

return M
