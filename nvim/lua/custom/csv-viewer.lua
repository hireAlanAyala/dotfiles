-- CSV Viewer with truncation and full-text expansion
local M = {}

M.ns = vim.api.nvim_create_namespace('csv_viewer')
M.cells = {}
M.max_width = 20  -- Default max column width

-- Convert cell_id string "row:col" to extmark ID (integer)
local function cell_id_to_extmark_id(cell_id)
  local row, col = cell_id:match('(%d+):(%d+)')
  return tonumber(row) * 1000 + tonumber(col)
end

-- Convert extmark ID back to cell_id string
local function extmark_id_to_cell_id(extmark_id)
  local row = math.floor(extmark_id / 1000)
  local col = extmark_id % 1000
  return string.format('%d:%d', row, col)
end

-- Show floating window with full cell content
function M.show_full_cell()
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1] - 1, cursor[2]

  -- Get all extmarks on current line
  local marks = vim.api.nvim_buf_get_extmarks(
    0,
    M.ns,
    { row, 0 },
    { row, -1 },
    { details = true }
  )

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
        M.show_float(cell.full, cell.is_truncated, cell_id)
        return
      end
    end
  end

  vim.notify('No cell found at cursor (row=' .. row .. ', col=' .. col .. ')', vim.log.levels.WARN)
end

-- Display floating window with text (using LSP's floating preview for auto-close behavior)
function M.show_float(text, is_truncated, cell_id)
  local lines = vim.split(text, '\n')

  -- Use LSP's built-in floating preview which handles auto-close on cursor move
  vim.lsp.util.open_floating_preview(lines, 'markdown', {
    border = 'none',
    focusable = true,
    focus = false,
    close_events = { 'CursorMoved', 'CursorMovedI', 'InsertEnter', 'BufLeave' },
  })
end

-- Parse JSON metadata from AWK script
local function parse_metadata(json_str)
  local ok, result = pcall(vim.json.decode, json_str)
  if not ok then
    vim.notify('Failed to parse cell metadata: ' .. tostring(result), vim.log.levels.ERROR)
    return {}
  end
  return result
end

-- Place extmarks on cells for tracking
local function place_extmarks(bufnr)
  -- Clear existing extmarks
  vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)

  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for line_idx, line in ipairs(lines) do
    -- Skip separator lines
    if not line:match('^|[-+]+|$') then
      -- Calculate actual row number (accounting for header and separators)
      -- Line 1 = header (row 1), Line 2 = separator, Line 3 = data row 2, Line 4 = separator, etc.
      local data_row
      if line_idx == 1 then
        data_row = 1  -- Header
      elseif line_idx > 2 then
        data_row = math.floor((line_idx + 1) / 2)
      else
        goto continue_line
      end

      -- Split by pipes and process each cell
      local col_num = 0
      local search_pos = 1

      while true do
        -- Find the next pipe-delimited cell
        local pipe_start = line:find('|', search_pos)
        if not pipe_start then break end

        local pipe_end = line:find('|', pipe_start + 1)
        if not pipe_end then break end

        col_num = col_num + 1

        -- Extract cell content between pipes
        local cell_content = line:sub(pipe_start + 1, pipe_end - 1)
        local trimmed = cell_content:match('^%s*(.-)%s*$')

        local cell_id = string.format('%d:%d', data_row, col_num)
        local cell = M.cells[cell_id]

        if cell and trimmed and trimmed ~= '' then
          -- The position is just after the first pipe, accounting for the space
          -- Format is: "| text " so text starts at pipe_start + 2
          local cell_col = pipe_start + 2
          local extmark_id = cell_id_to_extmark_id(cell_id)

          vim.api.nvim_buf_set_extmark(bufnr, M.ns, line_idx - 1, cell_col - 1, {
            id = extmark_id,
            end_col = cell_col - 1 + #trimmed,
            hl_group = cell.is_truncated and 'Comment' or nil,
          })
        end

        search_pos = pipe_end
      end

      ::continue_line::
    end
  end
end

-- Convert CSV buffer to formatted table view
function M.view_csv(bufnr, max_width)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  M.max_width = max_width or M.max_width

  -- Get CSV content
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local csv_content = table.concat(lines, '\n')

  -- Write CSV to temp file (safer than echo with special chars)
  local temp_file = vim.fn.tempname()
  local f = io.open(temp_file, 'w')
  if not f then
    vim.notify('Failed to create temp file', vim.log.levels.ERROR)
    return
  end
  f:write(csv_content)
  f:close()

  -- Run AWK script
  local script_path = vim.fn.stdpath('config') .. '/scripts/csv-to-table.awk'
  local cmd = string.format(
    'gawk -v MAX_WIDTH=%d -f %s %s',
    M.max_width,
    vim.fn.shellescape(script_path),
    vim.fn.shellescape(temp_file)
  )

  local output = vim.fn.system(cmd)

  -- Clean up temp file
  vim.fn.delete(temp_file)

  if vim.v.shell_error ~= 0 then
    vim.notify('Error running csv-to-table.awk: ' .. output, vim.log.levels.ERROR)
    return
  end

  -- Split output and find metadata marker
  local output_lines = vim.split(output, '\n', { trimempty = true })
  local metadata_json = nil
  local table_lines = {}

  for _, line in ipairs(output_lines) do
    if line:match('^___CSV_METADATA___') then
      metadata_json = line:gsub('^___CSV_METADATA___', '')
    else
      table.insert(table_lines, line)
    end
  end

  if not metadata_json then
    vim.notify('No metadata found in AWK output', vim.log.levels.ERROR)
    return
  end

  output_lines = table_lines

  -- Parse metadata
  M.cells = parse_metadata(metadata_json)

  -- Replace buffer content with formatted table
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', true)
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output_lines)
  vim.api.nvim_buf_set_option(bufnr, 'modifiable', false)
  vim.api.nvim_buf_set_option(bufnr, 'modified', false)

  -- Place extmarks
  place_extmarks(bufnr)

  -- Set up buffer-local keymap for K
  vim.keymap.set('n', 'K', M.show_full_cell, {
    buffer = bufnr,
    desc = 'Show full CSV cell content',
    nowait = true,
  })

  vim.notify('CSV table view enabled. Press K on a cell to see full content.', vim.log.levels.INFO)
end

return M
