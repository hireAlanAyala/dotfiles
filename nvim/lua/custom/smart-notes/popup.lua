local M = {}
local async = require("custom.smart-notes.async")

M.state = {
  popup_buf = nil,
  popup_win = nil,
  preview_buf = nil,
  preview_win = nil,
  timer = nil,
  current_target = nil,
  base_dir = nil,
  note_content = "",  -- Track the actual note content
  is_analyzing = false  -- Prevent concurrent analyses
}

function M.create_popup()
  -- Create popup buffer
  M.state.popup_buf = vim.api.nvim_create_buf(false, true)
  
  -- Set buffer options
  vim.api.nvim_buf_set_option(M.state.popup_buf, 'buftype', 'nofile')
  vim.api.nvim_buf_set_option(M.state.popup_buf, 'filetype', 'markdown')
  
  -- Calculate window dimensions
  local width = math.floor(vim.o.columns * 0.8)
  local height = math.floor(vim.o.lines * 0.3)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create popup window
  M.state.popup_win = vim.api.nvim_open_win(M.state.popup_buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' Smart Note ',
    title_pos = 'center',
  })
  
  -- Set window options
  vim.api.nvim_win_set_option(M.state.popup_win, 'wrap', true)
  vim.api.nvim_win_set_option(M.state.popup_win, 'linebreak', true)
  
  -- Set initial content
  vim.api.nvim_buf_set_lines(M.state.popup_buf, 0, -1, false, {})
  
  -- Create autocmds for live analysis
  local group = vim.api.nvim_create_augroup('SmartNotesPopup', { clear = true })
  
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = group,
    buffer = M.state.popup_buf,
    callback = function()
      -- Update note content on each change
      local lines = vim.api.nvim_buf_get_lines(M.state.popup_buf, 2, -1, false)
      M.state.note_content = vim.trim(table.concat(lines, "\n"))
      M.debounced_analyze()
    end
  })
  
  -- Trigger analysis when leaving insert mode
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    buffer = M.state.popup_buf,
    callback = function()
      -- Update content first
      local lines = vim.api.nvim_buf_get_lines(M.state.popup_buf, 2, -1, false)
      M.state.note_content = vim.trim(table.concat(lines, "\n"))
      -- Immediate analysis on insert leave
      vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(M.state.popup_win) then
          M.analyze_current_content()
        end
      end, 100)
    end
  })
  
  -- Set keymaps
  local opts = { noremap = true, silent = true, buffer = M.state.popup_buf }
  vim.keymap.set('n', '<CR>', function() M.save_note() end, opts)
  vim.keymap.set('i', '<C-s>', function() M.save_note() end, opts)
  vim.keymap.set('n', 'q', function() M.close() end, opts)
  vim.keymap.set('n', '<Esc>', function() M.close() end, opts)
  
  -- Add help text
  vim.api.nvim_buf_set_option(M.state.popup_buf, 'modifiable', true)
  vim.api.nvim_buf_set_lines(M.state.popup_buf, 0, -1, false, {
    "-- Type your note here. AI will analyze and show target file --",
    "-- Press <Enter> or <C-s> to save, <Esc> or q to cancel --",
    "",
  })
  
  -- Position cursor on line 3
  vim.api.nvim_win_set_cursor(M.state.popup_win, {3, 0})
end

function M.debounced_analyze()
  -- Cancel existing timer
  if M.state.timer then
    vim.loop.timer_stop(M.state.timer)
    M.state.timer = nil
  end
  
  -- Create new timer with 1500ms delay
  M.state.timer = vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(M.state.popup_win) then
      M.analyze_current_content()
    end
  end, 1500)
end

function M.analyze_current_content()
  -- Prevent concurrent analyses
  if M.state.is_analyzing then
    print("⣷ Analysis already in progress...")
    return
  end
  
  -- Just use our tracked content - no need to read from buffers
  local content = M.state.note_content
  
  -- Skip if too short or empty
  if not content or content == "" or #vim.trim(content) < 15 then
    print("⣷ Content too short for analysis (" .. #(content or "") .. " chars): '" .. (content or "nil") .. "'")
    return
  end
  
  print("⣷ Analyzing: " .. string.sub(content, 1, 30) .. "...")
  M.state.is_analyzing = true
  
  -- Run async analysis
  async.process_note_async(content, M.state.base_dir, function(todo_flag, destinations)
    M.state.is_analyzing = false
    
    if not vim.api.nvim_win_is_valid(M.state.popup_win) then
      print("⚠ Window closed during analysis")
      return
    end
    
    local target_file = nil
    
    if todo_flag == "todo" then
      target_file = M.state.base_dir .. "/todo.md"
      print("📝 TODO detected")
    elseif destinations and #destinations > 0 and destinations[1].confidence >= 50 then
      target_file = M.state.base_dir .. "/" .. destinations[1].path
      print("🎯 Target: " .. destinations[1].path .. " (" .. destinations[1].confidence .. "%)")
    else
      print("❓ No good target found")
    end
    
    if target_file and target_file ~= M.state.current_target then
      print("🔄 Switching to: " .. vim.fn.fnamemodify(target_file, ":t"))
      M.state.current_target = target_file
      M.show_preview(target_file)
    elseif target_file == M.state.current_target then
      print("✅ Staying in current file")
    end
  end)
end

function M.show_preview(file_path)
  -- Check if file exists
  if not vim.loop.fs_stat(file_path) then
    return
  end
  
  -- Use the tracked note content
  local content = M.state.note_content
  
  -- Save cursor position
  local cursor = vim.api.nvim_win_get_cursor(M.state.popup_win)
  local mode = vim.api.nvim_get_mode().mode
  
  -- Calculate cursor position within note content more precisely
  local relative_cursor_line, cursor_col
  if M.state.file_path then
    -- Already transformed - cursor is relative to note start
    relative_cursor_line = cursor[1] - M.state.note_start_line + 1
    cursor_col = cursor[2]
  else
    -- In popup - cursor is relative to line 3 (after help text)
    relative_cursor_line = math.max(1, cursor[1] - 2)
    cursor_col = cursor[2]
  end
  
  -- Ensure we don't go beyond content bounds
  local content_lines = vim.split(content, "\n")
  relative_cursor_line = math.min(relative_cursor_line, #content_lines)
  
  -- If switching files, we need to remove content from old file first
  if M.state.file_path and M.state.file_path ~= file_path then
    -- Restore original file without our note
    local current_buf = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(current_buf, M.state.original_file_lines, -1, false, {})
    -- Only write if it's a normal file, not a popup buffer
    local buftype = vim.api.nvim_buf_get_option(current_buf, 'buftype')
    if buftype == '' then
      pcall(vim.cmd, 'write')
    end
  end
  
  -- Load target file in the popup window
  vim.api.nvim_win_set_buf(M.state.popup_win, vim.fn.bufnr(file_path, true))
  vim.cmd('edit ' .. file_path)
  
  -- Get the file content
  local file_lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  
  -- Store original file length
  M.state.original_file_lines = #file_lines
  
  -- Add separator and note content at the end
  table.insert(file_lines, "")
  local note_start_line = #file_lines + 1
  
  -- Add note lines
  for line in content:gmatch("[^\n]*") do
    table.insert(file_lines, line)
  end
  
  -- Set the combined content
  vim.api.nvim_buf_set_lines(0, 0, -1, false, file_lines)
  
  -- Calculate new cursor position with better bounds checking
  local new_cursor_line = note_start_line + relative_cursor_line - 1
  local total_lines = vim.api.nvim_buf_line_count(0)
  
  -- Ensure cursor position is valid
  new_cursor_line = math.max(note_start_line, math.min(new_cursor_line, total_lines))
  
  -- Ensure column is valid for the line
  local line_content = vim.api.nvim_buf_get_lines(0, new_cursor_line - 1, new_cursor_line, false)[1] or ""
  cursor_col = math.min(cursor_col, #line_content)
  
  -- Use vim.schedule to ensure buffer is fully loaded before setting cursor
  vim.schedule(function()
    if vim.api.nvim_win_is_valid(M.state.popup_win) then
      pcall(vim.api.nvim_win_set_cursor, M.state.popup_win, {new_cursor_line, cursor_col})
    end
  end)
  
  -- Update window title to show file
  vim.api.nvim_win_set_config(M.state.popup_win, {
    title = ' ' .. vim.fn.fnamemodify(file_path, ":t") .. ' - Smart Note ',
  })
  
  -- Store the note boundaries
  M.state.note_start_line = note_start_line
  M.state.file_path = file_path
  
  -- Re-attach autocmd to new buffer for continued tracking
  local group = vim.api.nvim_create_augroup('SmartNotesTransformed', { clear = true })
  vim.api.nvim_create_autocmd({'TextChanged', 'TextChangedI'}, {
    group = group,
    buffer = 0,
    callback = function()
      -- Update note content from the transformed buffer
      local note_lines = vim.api.nvim_buf_get_lines(0, M.state.note_start_line - 1, -1, false)
      M.state.note_content = vim.trim(table.concat(note_lines, "\n"))
      M.debounced_analyze()
    end
  })
  
  -- Also add InsertLeave for transformed buffer
  vim.api.nvim_create_autocmd('InsertLeave', {
    group = group,
    buffer = 0,
    callback = function()
      -- Update content first
      local note_lines = vim.api.nvim_buf_get_lines(0, M.state.note_start_line - 1, -1, false)
      M.state.note_content = vim.trim(table.concat(note_lines, "\n"))
      -- Immediate analysis on insert leave
      vim.defer_fn(function()
        if vim.api.nvim_win_is_valid(M.state.popup_win) then
          M.analyze_current_content()
        end
      end, 100)
    end
  })
  
  -- Restore mode
  if mode == 'i' then
    vim.cmd('startinsert')
  end
end

function M.save_note()
  -- If we have transformed into target file
  if M.state.file_path then
    -- Save the current buffer (which is the target file)
    vim.cmd('write')
    vim.api.nvim_echo({{"Note saved to: " .. vim.fn.fnamemodify(M.state.file_path, ":~"), "Title"}}, false, {})
    M.close(true)
    return
  end
  
  -- Old behavior for when no target determined
  if not M.state.current_target then
    vim.api.nvim_echo({{"No target file determined yet. Keep typing...", "WarningMsg"}}, false, {})
    return
  end
  
  -- This shouldn't happen anymore but keep as fallback
  local lines = vim.api.nvim_buf_get_lines(M.state.popup_buf, 2, -1, false)
  local content = table.concat(lines, "\n")
  content = vim.trim(content)
  
  if content == "" then
    vim.api.nvim_echo({{"Empty note, canceling...", "WarningMsg"}}, false, {})
    M.close()
    return
  end
  
  local existing_content = vim.fn.readfile(M.state.current_target)
  table.insert(existing_content, "")
  for _, line in ipairs(vim.split(content, "\n")) do
    table.insert(existing_content, line)
  end
  
  vim.fn.writefile(existing_content, M.state.current_target)
  vim.api.nvim_echo({{"Note saved to: " .. vim.fn.fnamemodify(M.state.current_target, ":~"), "Title"}}, false, {})
  M.close(true)
end

function M.close(keep_preview)
  -- Stop timer
  if M.state.timer then
    vim.loop.timer_stop(M.state.timer)
    M.state.timer = nil
  end
  
  -- Close popup
  if M.state.popup_win and vim.api.nvim_win_is_valid(M.state.popup_win) then
    vim.api.nvim_win_close(M.state.popup_win, true)
  end
  
  -- Close preview unless keeping it
  if not keep_preview and M.state.preview_win and vim.api.nvim_win_is_valid(M.state.preview_win) then
    vim.api.nvim_win_close(M.state.preview_win, true)
  end
  
  -- Clear state
  M.state.popup_buf = nil
  M.state.popup_win = nil
  M.state.preview_buf = nil
  M.state.preview_win = nil
  M.state.current_target = nil
  M.state.file_path = nil
  M.state.note_start_line = nil
  M.state.original_file_lines = nil
  M.state.note_content = ""
  M.state.is_analyzing = false
  
  -- Clear autocommands
  vim.api.nvim_clear_autocmds({ group = 'SmartNotesPopup' })
end

function M.open(base_dir)
  M.state.base_dir = base_dir
  M.create_popup()
end

return M