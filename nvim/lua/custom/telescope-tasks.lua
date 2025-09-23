local M = {}

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local task_runner = require('custom.task-runner')
local telescope_utils = require('custom.telescope-utils')

-- Task picker
function M.task_picker()
  local tasks = task_runner.load_tasks()
  local task_file = vim.fn.getcwd() .. '/.nvim/tasks.yaml'
  
  if #tasks == 0 then
    if vim.fn.filereadable(task_file) == 1 then
      vim.notify('Tasks file exists but no tasks loaded. Check ' .. task_file .. ' for syntax errors', vim.log.levels.WARN)
    else
      vim.notify('No tasks found. Create tasks in .nvim/tasks.yaml', vim.log.levels.INFO)
    end
    return
  end
  
  pickers.new({}, {
    prompt_title = 'Tasks',
    layout_strategy = 'vertical',
    layout_config = {
      width = 0.33,
      height = 0.5,
    },
    finder = finders.new_table({
      results = tasks,
      entry_maker = function(task)
        local display = task.name
        if task.autostart then
          display = display .. ' [autostart]'
        end
        return {
          value = task,
          display = display,
          ordinal = task.name,
        }
      end,
    }),
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        local picker = action_state.get_current_picker(prompt_bufnr)
        local multi_selections = picker:get_multi_selection()
        
        actions.close(prompt_bufnr)
        
        if #multi_selections > 0 then
          -- Run all multi-selected tasks
          for _, selection in ipairs(multi_selections) do
            task_runner.run_task(selection.value)
          end
        else
          -- Run single selected task
          local selection = action_state.get_selected_entry()
          if selection then
            task_runner.run_task(selection.value)
          end
        end
      end)
      
      return true
    end,
    previewer = false,
  }):find()
end

return M