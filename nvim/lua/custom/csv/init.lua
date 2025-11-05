-- INFO: usage recipes
-- move between columns: f| then ; for next and , for prev
-- edit cell: shift + k, change data in the window

-- CSV Viewer with truncation and full-text expansion
local M = {}

M.ns = vim.api.nvim_create_namespace 'csv_viewer'
M.cells = {} -- Metadata: {["row:col"] = {full="...", truncated="...", is_truncated=...}}
M.max_width = 20 -- Default max column width
M.json_data = {} -- JSON array from miller: {[bufnr] = [{col1="val",...}, ...]}
M.csv_file_path = {} -- Path to CSV file: {[bufnr] = "path"}
M.layouts = {} -- Store layouts by buffer number: {[bufnr] = {data_win, prev_bufnr, col_widths, full_header}}
M.columns = {} -- Column names in order: {[bufnr] = {"col1", "col2", ...}}
M.num_rows = {} -- Number of rows: {[bufnr] = count}
M.suppress_autoopen = {} -- Temporarily suppress auto-opening: {[bufnr] = true}

-- Convert cell_id string "row:col" to extmark ID (integer)
local function cell_id_to_extmark_id(cell_id)
  local row, col = cell_id:match '(%d+):(%d+)'
  return tonumber(row) * 1000 + tonumber(col)
end

-- Convert extmark ID back to cell_id string
local function extmark_id_to_cell_id(extmark_id)
  local row = math.floor(extmark_id / 1000)
  local col = extmark_id % 1000
  return string.format('%d:%d', row, col)
end

-- Find cell at cursor position
local function find_cell_at_cursor(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  -- Get all extmarks on current line
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, M.ns, { row, 0 }, { row, -1 }, { details = true })

  -- Find which cell contains the cursor
  for _, mark in ipairs(marks) do
    local extmark_id = mark[1]
    local mark_row = mark[2]
    local mark_col = mark[3]
    local mark_end_col = mark[4].end_col

    if col >= mark_col and col < mark_end_col then
      local cell_id = extmark_id_to_cell_id(extmark_id)
      local cell = M.cells[cell_id]

      if cell then
        return cell_id, cell, mark_row, mark_col, mark_end_col
      end
    end
  end

  return nil
end

-- Show and edit cell content in floating window
function M.show_full_cell()
  local bufnr = vim.api.nvim_get_current_buf()
  local cell_id, cell = find_cell_at_cursor()

  if not cell then
    local cursor = vim.api.nvim_win_get_cursor(0)
    vim.notify('No cell found at cursor (row=' .. (cursor[1] - 1) .. ', col=' .. cursor[2] .. ')', vim.log.levels.WARN)
    return
  end

  -- Create editable buffer for cell content
  local edit_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { cell.full })
  vim.bo[edit_buf].bufhidden = 'wipe'
  vim.bo[edit_buf].filetype = 'text'

  -- Calculate window size
  local width = math.max(#cell.full + 4, 40)
  width = math.min(width, vim.o.columns - 10)

  local opts = {
    relative = 'cursor',
    row = 1,
    col = 0,
    width = width,
    height = 1,
    style = 'minimal',
    border = 'rounded',
    title = ' Edit Cell (Enter/Esc to save) ',
    title_pos = 'center',
  }

  local win = vim.api.nvim_open_win(edit_buf, true, opts)

  -- Save and close function
  local function save_and_close()
    if not vim.api.nvim_win_is_valid(win) then return end

    local new_lines = vim.api.nvim_buf_get_lines(edit_buf, 0, -1, false)
    local new_text = new_lines[1] or ''

    -- Update cell metadata
    cell.full = new_text
    M.cells[cell_id] = cell

    -- Update display
    M.update_cell_display(bufnr, cell_id, new_text)

    -- Close window
    vim.api.nvim_win_close(win, true)
  end

  -- Keymaps for saving
  vim.keymap.set('n', '<CR>', save_and_close, { buffer = edit_buf, nowait = true })
  vim.keymap.set('n', '<Esc>', save_and_close, { buffer = edit_buf, nowait = true })
  vim.keymap.set('i', '<CR>', function()
    vim.cmd('stopinsert')
    save_and_close()
  end, { buffer = edit_buf, nowait = true })
  vim.keymap.set('i', '<Esc>', function()
    vim.cmd('stopinsert')
    save_and_close()
  end, { buffer = edit_buf, nowait = true })

  -- Start in insert mode
  vim.cmd('startinsert')
end

-- Slice string by display width (UTF-8 aware)
local function slice_by_display_width(str, start_width, width)
  if not str or str == '' then
    return ''
  end

  local result = ''
  local current_width = 0
  local char_idx = 0
  local total_chars = vim.fn.strchars(str)

  -- Skip characters until we reach start_width
  while char_idx < total_chars do
    local char = vim.fn.strcharpart(str, char_idx, 1)
    local char_width = vim.fn.strdisplaywidth(char)

    if current_width + char_width > start_width then
      break
    end

    current_width = current_width + char_width
    char_idx = char_idx + 1
  end

  -- Collect characters until we reach the desired width
  local result_width = 0
  while char_idx < total_chars and result_width < width do
    local char = vim.fn.strcharpart(str, char_idx, 1)
    local char_width = vim.fn.strdisplaywidth(char)

    if result_width + char_width > width then
      break
    end

    result = result .. char
    result_width = result_width + char_width
    char_idx = char_idx + 1
  end

  return result
end

-- Build winbar header string for current scroll position
local function build_winbar_header(full_header, leftcol, win_width)
  if not full_header then
    return ''
  end
  return slice_by_display_width(full_header, leftcol, win_width)
end

-- Update winbar based on current scroll position
local function update_winbar_for_scroll(win, orig_bufnr)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end

  local layout = M.layouts[orig_bufnr]
  if not layout or not layout.full_header then
    return
  end

  local leftcol = vim.api.nvim_win_call(win, function()
    return vim.fn.winsaveview().leftcol
  end)

  local win_width = vim.api.nvim_win_get_width(win)
  local winbar_text = build_winbar_header(layout.full_header, leftcol, win_width)
  vim.wo[win].winbar = winbar_text
end

-- Rebuild table from M.cells (called after cell edits)
local function rebuild_table_from_cells(bufnr)
  local data_win = M.layouts[bufnr] and M.layouts[bufnr].data_win
  local cursor, view
  if data_win and vim.api.nvim_win_is_valid(data_win) then
    cursor = vim.api.nvim_win_get_cursor(data_win)
    view = vim.api.nvim_win_call(data_win, vim.fn.winsaveview)
  end

  local columns = M.columns[bufnr]
  local num_rows = M.num_rows[bufnr]

  if not columns or not num_rows then
    return
  end

  -- Recalculate column widths
  local col_widths = {}
  for _, col_name in ipairs(columns) do
    col_widths[col_name] = vim.fn.strdisplaywidth(col_name)
  end

  for row_idx = 2, num_rows + 1 do
    for col_idx, col_name in ipairs(columns) do
      local cell_id = string.format('%d:%d', row_idx, col_idx)
      local cell = M.cells[cell_id]
      if cell then
        local value = cell.full
        local display_width = vim.fn.strdisplaywidth(value)
        local is_truncated = display_width > M.max_width
        local truncated = value

        if is_truncated then
          local char_count = 0
          local byte_pos = 0
          for i = 1, vim.fn.strchars(value) do
            local char = vim.fn.strcharpart(value, i - 1, 1)
            local char_width = vim.fn.strdisplaywidth(char)
            if char_count + char_width > M.max_width - 3 then
              break
            end
            char_count = char_count + char_width
            byte_pos = byte_pos + #char
          end
          truncated = value:sub(1, byte_pos) .. '...'
        end

        cell.truncated = truncated
        cell.is_truncated = is_truncated

        local trunc_width = vim.fn.strdisplaywidth(truncated)
        if trunc_width > col_widths[col_name] then
          col_widths[col_name] = trunc_width
        end
      end
    end
  end

  -- Build data lines (no separators)
  local data_lines = {}
  for row_idx = 2, num_rows + 1 do
    local data_row = {}
    table.insert(data_row, '|')
    for col_idx, col_name in ipairs(columns) do
      local cell_id = string.format('%d:%d', row_idx, col_idx)
      local cell = M.cells[cell_id]
      local value = cell and cell.truncated or ''
      local value_display_width = vim.fn.strdisplaywidth(value)
      local padding = col_widths[col_name] - value_display_width
      table.insert(data_row, ' ' .. value .. string.rep(' ', padding) .. ' |')
    end
    table.insert(data_lines, table.concat(data_row))
  end

  -- Update buffer (in-place)
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, data_lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false  -- Prevent auto-save from triggering

  -- Rebuild cached full header string
  if M.layouts[bufnr] then
    local header_parts = {}
    table.insert(header_parts, '|')
    for _, col_name in ipairs(columns) do
      local col_display_width = vim.fn.strdisplaywidth(col_name)
      table.insert(header_parts, ' ' .. col_name .. string.rep(' ', col_widths[col_name] - col_display_width) .. ' |')
    end
    M.layouts[bufnr].full_header = table.concat(header_parts)
    M.layouts[bufnr].col_widths = col_widths

    if data_win and vim.api.nvim_win_is_valid(data_win) then
      update_winbar_for_scroll(data_win, bufnr)
    end
  end

  -- Re-place extmarks
  local function place_extmarks_internal(buf)
    vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)

    for line_idx, line in ipairs(lines) do
      local data_row = line_idx + 1

      local col_num = 0
      local search_pos = 1

      while true do
        local pipe_start = line:find('|', search_pos)
        if not pipe_start then
          break
        end
        local pipe_end = line:find('|', pipe_start + 1)
        if not pipe_end then
          break
        end

        col_num = col_num + 1

        local cell_content = line:sub(pipe_start + 1, pipe_end - 1)
        local trimmed = cell_content:match '^%s*(.-)%s*$'

        local cell_id = string.format('%d:%d', data_row, col_num)
        local cell = M.cells[cell_id]

        if cell and trimmed and trimmed ~= '' then
          local cell_col = pipe_start + 2
          local extmark_id = cell_id_to_extmark_id(cell_id)

          vim.api.nvim_buf_set_extmark(buf, M.ns, line_idx - 1, cell_col - 1, {
            id = extmark_id,
            end_col = cell_col - 1 + vim.fn.strdisplaywidth(trimmed),
          })
        end

        search_pos = pipe_end
      end
    end
  end

  place_extmarks_internal(bufnr)

  -- Restore cursor
  if data_win and vim.api.nvim_win_is_valid(data_win) and cursor and view then
    pcall(vim.api.nvim_win_set_cursor, data_win, cursor)
    pcall(vim.api.nvim_win_call, data_win, function()
      vim.fn.winrestview(view)
    end)
  end
end

-- Update cell display in the table buffer after editing
function M.update_cell_display(bufnr, cell_id, new_text)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  local cell = M.cells[cell_id]
  if not cell then
    vim.notify('Cell not found: ' .. cell_id, vim.log.levels.WARN)
    return
  end

  -- Update the full value in M.cells
  cell.full = new_text

  -- Update JSON data
  local row, col = cell_id:match('(%d+):(%d+)')
  if row and col then
    row = tonumber(row)
    col = tonumber(col)

    local json_row_idx = row - 1  -- cell row 2 = JSON row 1
    local columns = M.columns[bufnr]

    if M.json_data[bufnr] and M.json_data[bufnr][json_row_idx] and columns and columns[col] then
      local col_name = columns[col]
      M.json_data[bufnr][json_row_idx][col_name] = new_text
    end
  end

  -- In the in-place approach, bufnr is the layout key
  if not M.layouts[bufnr] then
    vim.notify('Could not find layout for buffer', vim.log.levels.WARN)
    return
  end

  -- Rebuild entire table from M.cells
  rebuild_table_from_cells(bufnr)

  -- Note: rebuild_table_from_cells() sets modified=false to prevent auto-save.
  -- Changes are stored in JSON data and will be written to file on :w via BufWriteCmd.
end

-- Place extmarks on cells for tracking
local function place_extmarks(bufnr)
  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for line_idx, line in ipairs(lines) do
    -- Calculate actual row number (no separators: Line 1 = row 2, Line 2 = row 3, etc.)
    local data_row = line_idx + 1

    -- Split by pipes and process each cell
    local col_num = 0
    local search_pos = 1

    while true do
      -- Find the next pipe-delimited cell
      local pipe_start = line:find('|', search_pos)
      if not pipe_start then
        break
      end

      local pipe_end = line:find('|', pipe_start + 1)
      if not pipe_end then
        break
      end

      col_num = col_num + 1

      -- Extract cell content between pipes
      local cell_content = line:sub(pipe_start + 1, pipe_end - 1)
      local trimmed = cell_content:match '^%s*(.-)%s*$'

      local cell_id = string.format('%d:%d', data_row, col_num)
      local cell = M.cells[cell_id]

      if cell and trimmed and trimmed ~= '' then
        -- The position is just after the first pipe, accounting for the space
        -- Format is: "| text " so text starts at pipe_start + 2
        local cell_col = pipe_start + 2
        local extmark_id = cell_id_to_extmark_id(cell_id)

        vim.api.nvim_buf_set_extmark(bufnr, M.ns, line_idx - 1, cell_col - 1, {
          id = extmark_id,
          end_col = cell_col - 1 + vim.fn.strdisplaywidth(trimmed),
        })
      end

      search_pos = pipe_end
    end
  end
end

-- Convert CSV buffer to formatted table view
function M.view_csv(bufnr, max_width)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.max_width = max_width or M.max_width

  -- Store CSV file path
  M.csv_file_path[bufnr] = vim.api.nvim_buf_get_name(bufnr)

  -- Get CSV content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local csv_content = table.concat(lines, '\n')

  -- Write CSV to temp file
  local temp_file = vim.fn.tempname()
  local f = io.open(temp_file, 'w')
  if not f then
    vim.notify('Failed to create temp file', vim.log.levels.ERROR)
    return
  end
  f:write(csv_content)
  f:close()

  -- Use miller to parse CSV to JSON (with ragged CSV support for inconsistent column counts)
  local cmd = string.format('mlr --csv --allow-ragged-csv-input --ojson cat %s', vim.fn.shellescape(temp_file))
  local json_output = vim.fn.system(cmd)

  -- Clean up temp file
  vim.fn.delete(temp_file)

  if vim.v.shell_error ~= 0 then
    vim.notify('Error running miller: ' .. json_output, vim.log.levels.ERROR)
    return
  end

  -- Parse JSON
  local ok, rows = pcall(vim.json.decode, json_output)
  if not ok or not rows then
    vim.notify('Failed to parse miller JSON output', vim.log.levels.ERROR)
    return
  end

  if #rows == 0 then
    vim.notify('No data in CSV', vim.log.levels.WARN)
    return
  end

  -- Store JSON data for this buffer
  M.json_data[bufnr] = rows

  -- Build table from parsed data
  M.cells = {}

  -- Get column names from first row
  local columns = {}
  for col_name, _ in pairs(rows[1]) do
    table.insert(columns, col_name)
  end
  table.sort(columns) -- Keep consistent order

  -- Store column info for rebuilds
  local orig_bufnr = bufnr
  M.columns[orig_bufnr] = columns
  M.num_rows[orig_bufnr] = #rows

  -- Calculate column widths
  local col_widths = {}
  for _, col_name in ipairs(columns) do
    col_widths[col_name] = vim.fn.strdisplaywidth(col_name)
  end

  -- Process all rows to determine widths and build cell metadata
  local row_data = {}
  for row_idx, row in ipairs(rows) do
    row_data[row_idx] = {}
    for col_idx, col_name in ipairs(columns) do
      local value = tostring(row[col_name] or '')
      local cell_id = string.format('%d:%d', row_idx + 1, col_idx)

      local display_width = vim.fn.strdisplaywidth(value)
      local is_truncated = display_width > M.max_width
      local truncated = value

      if is_truncated then
        local char_count = 0
        local byte_pos = 0
        for i = 1, vim.fn.strchars(value) do
          local char = vim.fn.strcharpart(value, i - 1, 1)
          local char_width = vim.fn.strdisplaywidth(char)
          if char_count + char_width > M.max_width - 3 then
            break
          end
          char_count = char_count + char_width
          byte_pos = byte_pos + #char
        end
        truncated = value:sub(1, byte_pos) .. '...'
      end

      M.cells[cell_id] = {
        full = value,
        truncated = truncated,
        is_truncated = is_truncated,
      }

      row_data[row_idx][col_idx] = truncated

      local trunc_width = vim.fn.strdisplaywidth(truncated)
      if trunc_width > col_widths[col_name] then
        col_widths[col_name] = trunc_width
      end
    end
  end

  -- Store header row metadata
  for col_idx, col_name in ipairs(columns) do
    local cell_id = '1:' .. col_idx
    M.cells[cell_id] = {
      full = col_name,
      truncated = col_name,
      is_truncated = false,
    }
  end

  -- Build data rows (no separators between rows)
  local output_lines = {}
  for row_idx = 1, #rows do
    local data_row = {}
    table.insert(data_row, '|')
    for col_idx, col_name in ipairs(columns) do
      local value = row_data[row_idx][col_idx]
      local value_display_width = vim.fn.strdisplaywidth(value)
      local padding = col_widths[col_name] - value_display_width
      table.insert(data_row, ' ' .. value .. string.rep(' ', padding) .. ' |')
    end
    table.insert(output_lines, table.concat(data_row))
  end

  -- Get the previous buffer from jumplist
  local jumplist = vim.fn.getjumplist()[1]
  local prev_bufnr = nil
  for i = #jumplist, 1, -1 do
    local jump_bufnr = jumplist[i].bufnr
    if jump_bufnr ~= orig_bufnr and vim.api.nvim_buf_is_valid(jump_bufnr) then
      prev_bufnr = jump_bufnr
      break
    end
  end

  -- Store original window
  local orig_win = vim.api.nvim_get_current_win()

  -- Replace buffer content in-place with formatted table
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output_lines)
  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].modified = false

  -- Configure window options
  vim.wo[orig_win].wrap = false
  vim.wo[orig_win].number = false
  vim.wo[orig_win].relativenumber = false
  vim.wo[orig_win].signcolumn = 'no'
  vim.wo[orig_win].foldcolumn = '0'

  -- Build and cache full header string for winbar updates
  local header_parts = {}
  table.insert(header_parts, '|')
  for _, col_name in ipairs(columns) do
    local col_display_width = vim.fn.strdisplaywidth(col_name)
    table.insert(header_parts, ' ' .. col_name .. string.rep(' ', col_widths[col_name] - col_display_width) .. ' |')
  end
  local full_header_string = table.concat(header_parts)

  -- Store layout info (no data_buf since we modify in-place)
  M.layouts[orig_bufnr] = {
    data_win = orig_win,
    prev_bufnr = prev_bufnr,
    col_widths = col_widths,
    full_header = full_header_string,
  }

  -- Set initial winbar
  update_winbar_for_scroll(orig_win, orig_bufnr)

  -- Update winbar on scroll
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'WinScrolled' }, {
    buffer = bufnr,
    callback = function()
      update_winbar_for_scroll(orig_win, orig_bufnr)
    end,
  })

  -- Clean up on buffer close
  vim.api.nvim_create_autocmd('BufWipeout', {
    buffer = bufnr,
    once = true,
    callback = function()
      vim.schedule(function()
        if M.layouts[orig_bufnr] then
          M.layouts[orig_bufnr] = nil
        end
      end)
    end,
  })

  -- Handle window resize
  vim.api.nvim_create_autocmd('VimResized', {
    callback = function()
      if M.layouts[orig_bufnr] and vim.api.nvim_win_is_valid(orig_win) then
        update_winbar_for_scroll(orig_win, orig_bufnr)
      end
    end,
  })

  -- Place extmarks on buffer
  place_extmarks(bufnr)

  -- Set up buffer-local keymap for K
  vim.keymap.set('n', 'K', M.show_full_cell, {
    buffer = bufnr,
    desc = 'Show and edit CSV cell content',
    nowait = true,
  })

  -- Set up save handler
  vim.api.nvim_create_autocmd('BufWriteCmd', {
    buffer = bufnr,
    callback = function()
      M.save_csv(bufnr)
    end,
  })
end

-- Save changes back to CSV file using miller
function M.save_csv(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()

  if not M.csv_file_path[bufnr] or not M.json_data[bufnr] then
    vim.notify('No CSV file loaded', vim.log.levels.ERROR)
    return
  end

  -- Write JSON to temp file
  local json_temp = vim.fn.tempname()
  local json_str = vim.json.encode(M.json_data[bufnr])
  local f = io.open(json_temp, 'w')
  if not f then
    vim.notify('Failed to create temp JSON file', vim.log.levels.ERROR)
    return
  end
  f:write(json_str)
  f:close()

  -- Convert JSON to CSV using miller
  local csv_temp = vim.fn.tempname()
  local cmd = string.format('mlr --json --ocsv cat %s > %s',
    vim.fn.shellescape(json_temp),
    vim.fn.shellescape(csv_temp))
  local result = vim.fn.system(cmd)

  -- Clean up JSON temp file
  vim.fn.delete(json_temp)

  if vim.v.shell_error ~= 0 then
    vim.notify('Error converting JSON to CSV: ' .. result, vim.log.levels.ERROR)
    vim.fn.delete(csv_temp)
    return
  end

  -- Read CSV output from miller
  local csv_file = io.open(csv_temp, 'r')
  if not csv_file then
    vim.notify('Failed to read CSV temp file', vim.log.levels.ERROR)
    vim.fn.delete(csv_temp)
    return
  end
  local csv_content = csv_file:read('*all')
  csv_file:close()
  vim.fn.delete(csv_temp)

  -- Write to actual CSV file
  local out_file = io.open(M.csv_file_path[bufnr], 'w')
  if not out_file then
    vim.notify('Failed to open file for writing: ' .. M.csv_file_path[bufnr], vim.log.levels.ERROR)
    return
  end
  out_file:write(csv_content)
  out_file:close()

  -- Mark buffer as not modified
  vim.bo[bufnr].modified = false
  vim.notify('CSV file saved: ' .. M.csv_file_path[bufnr], vim.log.levels.INFO)
end

-- Automatically open CSV files in the viewer whenever buffer is entered
vim.api.nvim_create_autocmd('BufEnter', {
  pattern = '*.csv',
  callback = function(args)
    local bufnr = args.buf

    -- Check if auto-opening is suppressed for this buffer
    if M.suppress_autoopen[bufnr] then
      -- Clear the suppression flag after a short delay
      vim.defer_fn(function()
        M.suppress_autoopen[bufnr] = nil
      end, 100)
      return
    end

    -- Check if the viewer layout is already showing for this buffer
    local layout = M.layouts[bufnr]
    if layout then
      -- Layout exists, check if windows are still valid
      if layout.data_win and vim.api.nvim_win_is_valid(layout.data_win) then
        -- Viewer already showing, nothing to do
        return
      else
        -- Windows were closed, clean up the layout
        M.layouts[bufnr] = nil
      end
    end

    -- Check if buffer is already formatted (contains pipe-delimited table)
    -- vs raw CSV (contains commas but no pipes in structured way)
    local first_line = vim.api.nvim_buf_get_lines(bufnr, 0, 1, false)[1] or ''
    local is_formatted = first_line:match '^|.*|$' ~= nil

    if is_formatted then
      -- Buffer is already formatted, don't reformat
      return
    end

    -- Apply the CSV viewer with default max width
    vim.schedule(function()
      if vim.api.nvim_buf_is_valid(bufnr) then
        M.view_csv(bufnr, M.max_width)
      end
    end)
  end,
})

return M
