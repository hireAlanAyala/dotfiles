local M = {}

function M.get_notes_structure(notes_dir)
  local cmd = string.format("find '%s' -type f -name '*.md' | head -50", notes_dir)
  local handle = io.popen(cmd)
  local result = handle:read("*a")
  handle:close()
  
  local files = {}
  for line in result:gmatch("[^\r\n]+") do
    local relative_path = string.gsub(line, notes_dir .. "/", "")
    table.insert(files, relative_path)
  end
  
  return files
end

function M.extract_key_nouns(content)
  local lines = vim.split(content, "\n")
  local first_lines = table.concat(vim.list_slice(lines, 1, math.min(3, #lines)), " ")
  
  local nouns = {}
  for word in first_lines:gmatch("%w+") do
    if #word > 3 and not vim.tbl_contains({"this", "that", "with", "from", "they", "have", "will", "been", "were"}, string.lower(word)) then
      table.insert(nouns, word)
    end
  end
  
  return nouns
end

function M.create_claude_prompt(content, nouns, existing_files)
  local nouns_str = table.concat(nouns, ", ")
  local files_str = table.concat(existing_files, "\n")
  
  return string.format([[
You are helping organize notes into a file system. Given this note content and existing file structure, suggest the best 3 locations (in order of confidence) where this note should be placed.

NOTE CONTENT:
%s

KEY NOUNS EXTRACTED: %s

EXISTING FILE STRUCTURE:
%s

Requirements:
1. Suggest 3 EXISTING FILES to append this note to (best match first)
2. Each suggestion MUST be an existing file path from the file structure above
3. Match based on semantic similarity between note content and file topics
4. Format as JSON: {"destinations": [{"path": "coding/terminal/neovim.md", "confidence": 95, "reason": "Note about nvim commands belongs with existing neovim documentation"}, ...]}
5. IMPORTANT: Only suggest files that actually exist in the structure above
6. Consider file names and their likely content (e.g., neovim.md for nvim topics, claude.md for AI assistant topics)
7. If no existing file is a good match, suggest the most general relevant file and explain why

Examples:
- "nvim :checkhealth" → coding/terminal/neovim.md
- "tmux pane navigation" → coding/terminal/tmux.md  
- "Claude API usage" → coding/ai/claude.md
- "Python type hints" → coding/languages/type_systems.md

CRITICAL: You must ALWAYS append to existing files. Never suggest creating new files.
]], content, nouns_str, files_str)
end

function M.call_claude_headless(prompt, notes_dir)
  local cmd = string.format("echo '%s' | claude --output-format json --add-dir '%s'", 
    string.gsub(prompt, "'", "'\"'\"'"), -- Escape single quotes
    notes_dir)
  local cmd_with_stderr = cmd .. " 2>&1"
  local handle = io.popen(cmd_with_stderr)
  if not handle then
    return nil, "Failed to execute claude command"
  end
  
  local result = handle:read("*a")
  local exit_code = handle:close()
  
  -- Log the raw output for debugging and save to file
  local log_output = result or "nil"
  print("Claude CLI output: " .. log_output)
  
  -- Save detailed log to file
  local log_file = notes_dir .. "/.smart-notes-debug.log"
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  local log_entry = string.format("\n=== %s ===\nCommand: %s\nOutput:\n%s\n", timestamp, cmd, log_output)
  
  local file = io.open(log_file, "a")
  if file then
    file:write(log_entry)
    file:close()
  end
  
  if not exit_code then
    return nil, "Claude command failed with non-zero exit code. Output: " .. (result or "no output")
  end
  
  if not result or result == "" then
    return nil, "Claude returned empty result"
  end
  
  -- Check if this is actually an error response (not just containing the word "error" in content)
  local ok_test, response_test = pcall(vim.json.decode, result)
  if ok_test and response_test.type == "result" and response_test.subtype == "success" then
    -- This is a successful response, continue processing
  elseif string.find(string.lower(result), "authentication") or string.find(string.lower(result), "unauthorized") then
    return nil, "Claude authentication error: " .. result
  end
  
  return result, nil
end

function M.parse_claude_response(response)
  -- First decode the outer Claude CLI response
  local ok, outer_response = pcall(vim.json.decode, response)
  if not ok then
    return nil, "Failed to parse Claude CLI response JSON"
  end
  
  -- Extract the actual result content
  local result_content = outer_response.result
  if not result_content then
    return nil, "No result field in Claude response"
  end
  
  -- Look for JSON within markdown code blocks or plain JSON
  local json_str = string.match(result_content, "```json\n(.-)```") or 
                   string.match(result_content, "```\n(%{.-%})\n```") or
                   string.match(result_content, "(%{.-%})")
  
  if not json_str then
    return nil, "No JSON found in result content"
  end
  
  local ok2, destinations_data = pcall(vim.json.decode, json_str)
  if not ok2 or not destinations_data.destinations then
    return nil, "Invalid destinations JSON format"
  end
  
  return destinations_data.destinations, nil
end

function M.analyze_content_with_ai(content, notes_dir)
  local existing_files = M.get_notes_structure(notes_dir)
  local nouns = M.extract_key_nouns(content)
  
  if #existing_files == 0 then
    return {{path = "", confidence = 50, reason = "No existing structure found"}}, nil
  end
  
  local prompt = M.create_claude_prompt(content, nouns, existing_files)
  local response, err = M.call_claude_headless(prompt, notes_dir)
  
  if err then
    return {{path = "", confidence = 30, reason = "AI analysis failed: " .. err}}, err
  end
  
  local destinations, parse_err = M.parse_claude_response(response)
  if parse_err then
    return {{path = "", confidence = 30, reason = "Failed to parse AI response: " .. parse_err}}, parse_err
  end
  
  return destinations, nil
end

return M