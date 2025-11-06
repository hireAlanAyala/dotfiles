local M = {}

function M.run_command_async(cmd, callback)
  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)
  local handle
  
  local result = ""
  local error_output = ""
  
  handle = vim.loop.spawn("sh", {
    args = {"-c", cmd},
    stdio = {nil, stdout, stderr}
  }, function(code, signal)
    stdout:read_stop()
    stderr:read_stop()
    stdout:close()
    stderr:close()
    handle:close()
    
    vim.schedule(function()
      if code == 0 then
        callback(nil, result)
      else
        callback("Command failed with exit code: " .. code .. ". Error: " .. error_output, nil)
      end
    end)
  end)
  
  if not handle then
    callback("Failed to spawn command", nil)
    return
  end
  
  stdout:read_start(function(err, data)
    if data then
      result = result .. data
    end
  end)
  
  stderr:read_start(function(err, data)
    if data then
      error_output = error_output .. data
    end
  end)
end

function M.process_note_async(initial_content, base_dir, on_complete)
  local ai_analyzer = require("custom.smart-notes.ai-analyzer")
  local fallback_analyzer = require("custom.smart-notes.analyzer")
  
  -- Show loading indicator
  vim.api.nvim_echo({{"⣷ Analyzing note with AI...", "WarningMsg"}}, false, {})
  
  -- Check for TODO/task content first
  local lower_content = string.lower(initial_content)
  if string.find(lower_content, "todo") or string.find(lower_content, "feat") or string.find(lower_content, "bug") then
    vim.schedule(function()
      on_complete("todo", nil)
    end)
    return
  end
  
  -- Prepare AI analysis  
  local existing_files = ai_analyzer.get_notes_structure(base_dir)
  local nouns = ai_analyzer.extract_key_nouns(initial_content)
  
  if #existing_files == 0 then
    vim.schedule(function()
      on_complete(nil, {{path = "", confidence = 50, reason = "No existing structure found"}})
    end)
    return
  end
  
  local prompt = ai_analyzer.create_claude_prompt(initial_content, nouns, existing_files)
  local escaped_prompt = string.gsub(prompt, "'", "'\"'\"'")
  local cmd = string.format("echo '%s' | claude --output-format json --add-dir '%s'", escaped_prompt, base_dir)
  
  M.run_command_async(cmd, function(err, result)
    if err then
      print("\nAI analysis failed: " .. err)
      local detected_path, confidence = fallback_analyzer.analyze_content(initial_content)
      on_complete(nil, {{path = detected_path or "", confidence = confidence or 50, reason = "fallback analysis"}})
      return
    end
    
    -- Log output
    local log_file = base_dir .. "/.smart-notes-debug.log"
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    local log_entry = string.format("\n=== %s ===\nCommand: %s\nOutput:\n%s\n", timestamp, cmd, result or "nil")
    
    local file = io.open(log_file, "a")
    if file then
      file:write(log_entry)
      file:close()
    end
    
    -- Parse response
    local destinations, parse_err = ai_analyzer.parse_claude_response(result)
    if parse_err then
      print("\nFailed to parse AI response: " .. parse_err)
      local detected_path, confidence = fallback_analyzer.analyze_content(initial_content)
      on_complete(nil, {{path = detected_path or "", confidence = confidence or 50, reason = "fallback analysis"}})
      return
    end
    
    on_complete(nil, destinations)
  end)
end

return M