local M = {}

-- Get task file path for current project
local function get_task_file()
  return vim.fn.getcwd() .. '/.nvim/tasks.yaml'
end

-- Simple YAML parser for our specific format
local function parse_yaml(content)
  local tasks = {}
  local current_task = nil
  local current_key = nil
  local collecting_lines = {}
  
  for i, line in ipairs(content) do
    -- New task starts with "- name:"
    if line:match('^%- name:') then
      -- Save previous task
      if current_task then
        table.insert(tasks, current_task)
      end
      -- Start new task
      current_task = {}
      current_task.name = line:match('^%- name:%s*(.+)$')
      current_key = nil
    elseif current_task and line:match('^  %w+:') then
      -- Save any collected multiline content
      if current_key and #collecting_lines > 0 then
        current_task[current_key] = table.concat(collecting_lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
        collecting_lines = {}
      end
      
      -- Parse property line
      local key, value = line:match('^  (%w+):%s*(.*)$')
      if key and value then
        if value == '|' then
          -- Start collecting multiline
          current_key = key
        elseif value == 'true' then
          current_task[key] = true
          current_key = nil
        elseif value == 'false' then
          current_task[key] = false
          current_key = nil
        elseif value ~= '' then
          current_task[key] = value
          current_key = nil
        end
      end
    elseif current_key and line:match('^    ') then
      -- Collect multiline content (indented with 4 spaces)
      table.insert(collecting_lines, line:sub(5)) -- Remove first 4 spaces
    end
  end
  
  -- Save last task
  if current_task then
    if current_key and #collecting_lines > 0 then
      current_task[current_key] = table.concat(collecting_lines, '\n'):gsub('^%s+', ''):gsub('%s+$', '')
    end
    table.insert(tasks, current_task)
  end
  
  return tasks
end

-- Format task for YAML
local function format_task_yaml(task)
  local lines = {'- name: ' .. task.name}
  table.insert(lines, '  command: ' .. (task.command or ''))
  if task.autostart ~= nil then
    table.insert(lines, '  autostart: ' .. tostring(task.autostart))
  end
  return table.concat(lines, '\n')
end

-- Load all tasks from YAML file
function M.load_tasks()
  local file_path = get_task_file()
  local tasks = {}
  
  -- Check if file exists
  if vim.fn.filereadable(file_path) == 0 then
    return tasks
  end
  
  local ok, content = pcall(vim.fn.readfile, file_path)
  if ok and content then
    tasks = parse_yaml(content)
    -- Add IDs based on name
    for i, task in ipairs(tasks) do
      task.id = task.name:lower():gsub('%s+', '_'):gsub('[^%w_]', '')
    end
  end
  
  return tasks
end

-- Save all tasks to YAML file
function M.save_tasks(tasks)
  local file_path = get_task_file()
  
  -- Ensure directory exists
  local dir = vim.fn.fnamemodify(file_path, ':h')
  vim.fn.mkdir(dir, 'p')
  
  local lines = {}
  for _, task in ipairs(tasks) do
    table.insert(lines, format_task_yaml(task))
  end
  
  local content = table.concat(lines, '\n')
  local file = io.open(file_path, 'w')
  if file then
    file:write(content)
    file:close()
    return true
  end
  return false
end

-- Add or update a task
function M.save_task(task_id, task_data)
  local tasks = M.load_tasks()
  
  -- Check if task exists (update) or new
  local found = false
  for i, task in ipairs(tasks) do
    if task.id == task_id then
      tasks[i] = vim.tbl_extend('force', task, task_data, {id = task_id})
      found = true
      break
    end
  end
  
  if not found then
    task_data.id = task_id
    table.insert(tasks, task_data)
  end
  
  return M.save_tasks(tasks)
end

-- Delete a task
function M.delete_task(task_id)
  local tasks = M.load_tasks()
  local new_tasks = {}
  
  for _, task in ipairs(tasks) do
    if task.id ~= task_id then
      table.insert(new_tasks, task)
    end
  end
  
  return M.save_tasks(new_tasks)
end

-- Run a task using terminal-persist
function M.run_task(task, switch_to_buffer)
  -- Check if task is already running
  local project_id = vim.fn.fnamemodify(vim.fn.getcwd(), ':t'):gsub('[^%w%-_]', '_') .. '_' .. vim.fn.sha256(vim.fn.getcwd()):sub(1, 6)
  local session_name = project_id .. '_' .. task.name
  vim.fn.system('tmux has-session -t ' .. vim.fn.shellescape(session_name) .. ' 2>/dev/null')
  local is_running = vim.v.shell_error == 0

  if is_running then
    vim.notify('Task "' .. task.name .. '" is already running', vim.log.levels.WARN)
    return
  end
  
  local terminal_persist = require('custom.terminal-persist')
  terminal_persist.new_terminal(task.command, task.name, switch_to_buffer)
end


-- Create a new task with user input
function M.create_task()
  local task_data = {}
  
  -- Get task name
  vim.ui.input({ prompt = 'Task name: ' }, function(name)
    if not name or name == '' then return end
    task_data.name = name
    
    -- Get command
    vim.ui.input({ prompt = 'Command: ' }, function(command)
      if not command or command == '' then return end
      task_data.command = command
      
      -- Get autostart (optional)
      vim.ui.select({'true', 'false'}, {
        prompt = 'Autostart: ',
      }, function(choice)
        task_data.autostart = choice == 'true'
        
        -- Generate task ID from name
        local task_id = task_data.name:lower():gsub('%s+', '_'):gsub('[^%w_]', '')
        
        -- Save task
        if M.save_task(task_id, task_data) then
          vim.notify('Task created: ' .. task_data.name)
        else
          vim.notify('Failed to create task', vim.log.levels.ERROR)
        end
      end)
    end)
  end)
end

-- Check if terminal buffer exists for task name
local function has_terminal_buffer(task_name)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) then
      local buf_name = vim.api.nvim_buf_get_name(buf)
      if buf_name:match('terminal://.*' .. vim.pesc(task_name) .. '$') then
        return true
      end
    end
  end
  return false
end

-- Auto-launch tasks when pwd changes
local function auto_launch_on_pwd_change()
  local tasks = M.load_tasks()
  for _, task in ipairs(tasks) do
    if task.autostart and not has_terminal_buffer(task.name) then
      vim.defer_fn(function()
        M.run_task(task, false)
      end, 500)
    end
  end
end

-- Setup autostart tasks
function M.setup_autostart()
  local tasks = M.load_tasks()
  for _, task in ipairs(tasks) do
    if task.autostart then
      vim.defer_fn(function()
        M.run_task(task, false)
      end, 1000) -- Delay to ensure nvim is fully loaded
    end
  end
end

-- Setup both initial autostart and pwd change detection
function M.setup()
  -- Initial autostart on nvim launch
  M.setup_autostart()
  
  -- Setup autocmd for pwd change detection
  vim.api.nvim_create_autocmd("DirChanged", {
    pattern = "*",
    callback = function()
      vim.defer_fn(auto_launch_on_pwd_change, 100)
    end,
    group = vim.api.nvim_create_augroup("TaskRunnerPwdChange", { clear = true })
  })
end

-- Setup autocmd for pwd change detection (kept for backward compatibility)
function M.setup_pwd_autolaunch()
  vim.api.nvim_create_autocmd("DirChanged", {
    pattern = "*",
    callback = function()
      vim.defer_fn(auto_launch_on_pwd_change, 100)
    end,
    group = vim.api.nvim_create_augroup("TaskRunnerPwdChange", { clear = true })
  })
end

return M