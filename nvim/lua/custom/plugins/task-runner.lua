return {
  {
    'nvim-telescope/telescope.nvim',
    dependencies = { 'nvim-lua/plenary.nvim' },
    config = function()
      -- Setup task runner
      local task_runner = require('custom.task-runner')
      
      -- Create user commands
      vim.api.nvim_create_user_command('TaskCreate', function()
        task_runner.create_task()
      end, { desc = 'Create a new task' })
      
      vim.api.nvim_create_user_command('TaskList', function()
        require('custom.telescope-tasks').task_picker()
      end, { desc = 'List all tasks' })
      
      -- Setup autostart tasks when entering a project
      vim.api.nvim_create_autocmd('VimEnter', {
        callback = function()
          vim.defer_fn(function()
            task_runner.setup_autostart()
          end, 500)
        end,
      })
    end,
  },
}