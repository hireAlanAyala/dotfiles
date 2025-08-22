local M = {}

-- Auto session management for tmux resurrect
function M.auto_session()
  local session_dir = vim.fn.expand '~/.config/nvim/sessions/'
  if vim.fn.isdirectory(session_dir) == 0 then
    vim.fn.mkdir(session_dir, 'p')
  end

  -- Get current tmux session name for session file
  local tmux_session = vim.fn.system('tmux display-message -p "#S"'):gsub('\n', '')
  if tmux_session == '' then
    tmux_session = 'default'
  end

  local session_file = session_dir .. tmux_session .. '.vim'

  -- Auto save session on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      if vim.fn.argc() == 0 then -- Only save if no arguments passed
        vim.cmd('mksession! ' .. session_file)
      end
    end,
  })

  -- Auto restore session if no files opened
  if vim.fn.argc() == 0 and vim.fn.filereadable(session_file) == 1 then
    vim.defer_fn(function()
      vim.cmd('source ' .. session_file)
    end, 100)
  end
end

-- Manual session save command
function M.setup_commands()
  vim.api.nvim_create_user_command('SaveSession', function()
    local session_dir = vim.fn.expand '~/.config/nvim/sessions/'
    if vim.fn.isdirectory(session_dir) == 0 then
      vim.fn.mkdir(session_dir, 'p')
    end

    local tmux_session = vim.fn.system('tmux display-message -p "#S"'):gsub('\n', '')
    if tmux_session == '' then
      tmux_session = 'default'
    end

    local session_file = session_dir .. tmux_session .. '.vim'
    vim.cmd('mksession! ' .. session_file)
    print('Session saved: ' .. session_file)
  end, {})
end

function M.setup()
  -- Only enable auto session in tmux
  if vim.env.TMUX then
    M.auto_session()
  end
  
  M.setup_commands()
end

return M