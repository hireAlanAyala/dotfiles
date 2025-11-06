local M = {}

M.keyword_rules = {
  project = {
    ["hpg"] = "hpg/",
    ["best_feedback"] = "hpg/",
    ["storyboard"] = "hpg/",
  },
  
  technical = {
    ["nvim"] = "coding/terminal/",
    ["tmux"] = "coding/terminal/",
    ["terminal"] = "coding/terminal/",
    ["config"] = "coding/terminal/",
    ["datastar"] = "coding/frontend/",
    ["frontend"] = "coding/frontend/",
    ["javascript"] = "coding/frontend/",
    ["claude"] = "coding/ai/",
    ["ai"] = "coding/ai/",
    ["anthropic"] = "coding/ai/",
    ["mcp"] = "coding/ai/",
  },
  
  domain = {
    ["budget"] = "finance/",
    ["finance"] = "finance/",
    ["medical"] = "medical/",
    ["hardware"] = "hardware/",
    ["soldering"] = "hardware/",
  },
  
  content_type = {
    ["todo"] = "",
    ["feat"] = "",
    ["bug"] = "",
  }
}

function M.analyze_content(content)
  local lines = vim.split(content, "\n")
  local first_few_lines = table.concat(vim.list_slice(lines, 1, math.min(5, #lines)), " ")
  local lower_content = string.lower(first_few_lines)
  
  local detected_path = nil
  local confidence = 0
  
  for category, rules in pairs(M.keyword_rules) do
    for keyword, path in pairs(rules) do
      if string.find(lower_content, keyword) then
        if category == "project" then
          detected_path = path
          confidence = 90
          break
        elseif category == "technical" and confidence < 80 then
          detected_path = path
          confidence = 80
        elseif category == "domain" and confidence < 70 then
          detected_path = path
          confidence = 70
        elseif category == "content_type" and confidence < 60 then
          detected_path = "todo.md"
          confidence = 60
        end
      end
    end
    if confidence >= 90 then break end
  end
  
  return detected_path, confidence
end

function M.extract_title(content)
  local lines = vim.split(content, "\n")
  
  for _, line in ipairs(lines) do
    line = vim.trim(line)
    if line ~= "" then
      if string.match(line, "^#%s+(.+)") then
        return string.match(line, "^#%s+(.+)")
      elseif not string.match(line, "^[#%-*]") then
        return line:sub(1, 50)
      end
    end
  end
  
  return "untitled_note"
end

function M.sanitize_filename(title)
  local sanitized = string.gsub(title, "[^%w%s%-_]", "")
  sanitized = string.gsub(sanitized, "%s+", "_")
  sanitized = string.lower(sanitized)
  return sanitized
end

return M