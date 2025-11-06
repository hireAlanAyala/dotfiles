local ai_analyzer = require("custom.smart-notes.ai-analyzer")
local fallback_analyzer = require("custom.smart-notes.analyzer")
local async = require("custom.smart-notes.async")

local M = {}

function M.get_notes_base_dir()
  return require("custom.smart-notes").config.notes_dir
end

function M.ensure_directory_exists(dir_path)
  local stat = vim.loop.fs_stat(dir_path)
  if not stat then
    vim.fn.mkdir(dir_path, "p")
  end
end

function M.get_unique_filename(base_path, filename)
  local extension = require("custom.smart-notes").config.default_extension
  local full_path = base_path .. "/" .. filename .. extension
  
  if vim.loop.fs_stat(full_path) then
    local counter = 1
    repeat
      full_path = base_path .. "/" .. filename .. "_" .. counter .. extension
      counter = counter + 1
    until not vim.loop.fs_stat(full_path)
  end
  
  return full_path
end

function M.handle_todo_append(content)
  local todo_path = M.get_notes_base_dir() .. "/todo.md"
  
  if vim.loop.fs_stat(todo_path) then
    local existing_content = vim.fn.readfile(todo_path)
    table.insert(existing_content, "")
    table.insert(existing_content, "## " .. os.date("%Y-%m-%d %H:%M"))
    for _, line in ipairs(vim.split(content, "\n")) do
      table.insert(existing_content, line)
    end
    vim.fn.writefile(existing_content, todo_path)
    return todo_path
  else
    local new_content = {
      "# TODO",
      "",
      "## " .. os.date("%Y-%m-%d %H:%M"),
    }
    for _, line in ipairs(vim.split(content, "\n")) do
      table.insert(new_content, line)
    end
    vim.fn.writefile(new_content, todo_path)
    return todo_path
  end
end

function M.create_note(initial_content)
  initial_content = initial_content or ""
  
  if initial_content == "" then
    initial_content = "# New Note\n\n"
  end
  
  local base_dir = M.get_notes_base_dir()
  
  -- Process note asynchronously
  async.process_note_async(initial_content, base_dir, function(todo_flag, destinations)
    if todo_flag == "todo" then
      local final_path = M.handle_todo_append(initial_content)
      vim.cmd("edit " .. final_path)
      print("Note appended to todo.md")
      return
    end
    
    -- Use the highest confidence destination
    local best_dest = destinations[1]
    
    -- Check if AI found a good existing file (confidence >= 50)
    if best_dest.confidence < 50 then
      print("No good existing file found for this note. Consider creating a more general note file first.")
      return
    end
    
    -- AI should now return file paths, not directory paths
    local target_file = base_dir .. "/" .. best_dest.path
    
    -- Check if file exists
    if not vim.loop.fs_stat(target_file) then
      print("Error: Suggested file doesn't exist: " .. best_dest.path)
      return
    end
    
    -- Append to existing file
    local existing_content = vim.fn.readfile(target_file)
    table.insert(existing_content, "")
    for _, line in ipairs(vim.split(initial_content, "\n")) do
      table.insert(existing_content, line)
    end
    
    vim.fn.writefile(existing_content, target_file)
    vim.cmd("edit " .. target_file)
    
    -- Show AI reasoning
    print(string.format("Note appended to: %s (AI confidence: %d%% - %s)", 
          string.gsub(target_file, base_dir, "~notes"), best_dest.confidence, best_dest.reason or "AI suggested"))
    
    -- Show alternative suggestions
    if #destinations > 1 then
      print("Alternative suggestions:")
      for i = 2, math.min(3, #destinations) do
        local alt = destinations[i]
        print(string.format("  %d. %s (%d%% - %s)", i, alt.path or "root", alt.confidence, alt.reason or ""))
      end
    end
  end)
end

return M