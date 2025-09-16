-- Keymaps configuration
-- Organized by category with consistent prefixes
-- <leader>g - Git (git status, blame, diff, commits)
-- <leader>l - LSP/Language (code actions, diagnostics, formatting)
-- <leader>s - Search (grep, find and replace, symbols)
-- <leader>b - Buffers (buffer navigation, close, list)
-- <leader>t - Terminal (terminal operations)
-- <leader>d - Debug/Diagnostics (DAP, error navigation)
-- <leader>c - Code (commenting, refactoring, snippets)
-- <leader>n - Navigation (file tree, jumps, marks)
-- <leader>r - Run/REPL (run tests, execute code)
-- <leader>h - Help/Hunk (help docs, git hunks)

local M = {}

-- Buffer history tracking for MRU navigation
local buffer_history = {}
local history_index = 0
local navigating = false

-- Track buffer visits with cursor position
local function track_buffer_visit()
  -- Skip tracking during navigation
  if navigating then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local cursor = vim.api.nvim_win_get_cursor(0)

  -- Only track normal buffers (not special buffers)
  if vim.bo[bufnr].buftype == '' then
    -- If we're in the middle of history, truncate forward history
    if history_index < #buffer_history then
      for i = #buffer_history, history_index + 1, -1 do
        table.remove(buffer_history, i)
      end
    end

    -- Don't add duplicate of current position
    if history_index > 0 and buffer_history[history_index] and buffer_history[history_index].bufnr == bufnr then
      -- Just update cursor position
      buffer_history[history_index].cursor = cursor
    else
      -- Add new entry
      table.insert(buffer_history, {
        bufnr = bufnr,
        cursor = cursor,
      })
      history_index = #buffer_history
    end

    -- Limit history size
    if #buffer_history > 50 then
      table.remove(buffer_history, 1)
      history_index = history_index - 1
    end
  end
end

-- Navigate buffer history
local function navigate_buffer_history(direction)
  if #buffer_history == 0 then
    vim.notify('No buffer history', vim.log.levels.INFO)
    return
  end

  -- Update current position's cursor before navigating
  if buffer_history[history_index] then
    buffer_history[history_index].cursor = vim.api.nvim_win_get_cursor(0)
  end

  -- Calculate new index
  local new_index = history_index + direction

  -- Check bounds
  if new_index < 1 or new_index > #buffer_history then
    vim.notify('No more buffer history in that direction', vim.log.levels.INFO)
    return
  end

  history_index = new_index
  local entry = buffer_history[history_index]

  if entry and vim.api.nvim_buf_is_valid(entry.bufnr) then
    -- Set flag to skip tracking
    navigating = true

    -- Switch to buffer
    vim.api.nvim_set_current_buf(entry.bufnr)
    -- Restore cursor position
    vim.api.nvim_win_set_cursor(0, entry.cursor)

    -- Reset flag after a short delay
    vim.defer_fn(function()
      navigating = false
    end, 50)
  else
    -- Remove invalid entry and adjust index
    table.remove(buffer_history, history_index)
    if history_index > #buffer_history then
      history_index = #buffer_history
    end
    if #buffer_history > 0 then
      navigate_buffer_history(0) -- Retry at same position
    end
  end
end

-- Set up autocmd to track buffer visits
vim.api.nvim_create_autocmd({ 'BufEnter', 'BufWinEnter' }, {
  callback = track_buffer_visit,
})

M.setup = function()
  local map = vim.keymap.set

  -- Set up basic which-key groups for keymaps defined in this function
  -- Plugin-specific groups are defined in their respective setup functions
  -- INFO: ideas: (x) diagnostics/quickfix, (u) UI,
  -- Example whichkeys: https://catalins.tech/content/images/size/w1000/2024/10/lazyvim-which-key-plugin.webp
  local wk_groups = {
    { '<leader>a', group = 'ai' },
    { '<leader>b', group = 'buffers' },
    { '<leader>t', group = 'terminal' },
    { '<leader>d', group = 'debug/diagnostics' },
    { '<leader>c', group = 'code', mode = { 'n', 'x' } },
    { '<leader>n', group = 'navigation' },
    { '<leader>r', group = 'run/repl' },
    { '<leader>g', group = 'git' }, -- Git group for basic git commands
  }

  -- Basic vim keymaps
  map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlight' })
  map('n', 'k', "v:count == 0 ? 'gk' : 'k'", { desc = 'Move up', expr = true, silent = true })
  map('n', 'j', "v:count == 0 ? 'gj' : 'j'", { desc = 'Move down', expr = true, silent = true })
  map('t', '<Esc><Esc>', '<C-\\><C-n>', { desc = 'Exit terminal mode' })
  map('v', 'J', ":m '>+1<CR>gv=gv", { desc = 'Move selection down' })
  map('v', 'K', ":m '<-2<CR>gv=gv", { desc = 'Move selection up' })

  -- Git - <leader>g
  map('n', '<leader>gg', '<cmd>Neogit<CR>', { desc = 'git neogit' })
  map('n', '<leader>gs', '<cmd>Git<CR>', { desc = 'git status' })
  map('n', '<leader>gd', '<cmd>Gvdiffsplit<CR>', { desc = 'git diff' })
  map('n', '<leader>gl', '<cmd>Git log --oneline<CR>', { desc = 'git log' })
  map('n', '<leader>gp', '<cmd>Git push<CR>', { desc = 'git push' })
  map('n', '<leader>gP', '<cmd>Git pull<CR>', { desc = 'git pull' })

  -- Git Hunks are configured in gitsigns plugin setup

  -- LSP/Language - <leader>l
  -- LSP keymaps are configured in the LSP on_attach function

  -- Search - <leader>s
  -- Search keymaps are configured in telescope plugin setup

  -- Buffers - <leader>b
  map('n', '<leader>bd', '<cmd>bdelete<CR>', { desc = 'buffer delete' })
  map('n', '<leader>bD', '<cmd>%bd|e#<CR>', { desc = 'buffer delete others' })

  -- Buffer history navigation (like <C-o>/<C-i> but for whole buffers)
  map('n', '<leader>bo', function()
    navigate_buffer_history(-1)
  end, { desc = 'buffer history back' })
  map('n', '<leader>bi', function()
    navigate_buffer_history(1)
  end, { desc = 'buffer history forward' })

  -- Window navigation
  map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window' })
  map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window' })
  map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window' })
  map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window' })

  -- Terminal - <leader>t
  map('n', '<leader>tt', '<cmd>terminal<CR>', { desc = 'terminal toggle' })
  map('n', '<leader>tp', function()
    local dir

    -- Check if we're in an Oil buffer
    if vim.bo.filetype == 'oil' then
      local ok, oil = pcall(require, 'oil')
      if ok then
        dir = oil.get_current_dir()
      end
    end

    -- If not Oil or Oil failed, use regular file path logic
    if not dir then
      local filepath = vim.fn.expand '%:p'
      dir = filepath ~= '' and vim.fn.fnamemodify(filepath, ':h') or vim.fn.getcwd()
    end

    vim.cmd 'terminal'
    vim.defer_fn(function()
      local term_buf = vim.api.nvim_get_current_buf()
      local term_chan = vim.api.nvim_buf_get_option(term_buf, 'channel')
      if term_chan then
        vim.api.nvim_chan_send(term_chan, 'cd "' .. dir .. '"\n')
      end
    end, 100)
    vim.cmd 'startinsert'
  end, { desc = 'terminal at buffer path' })

  map('n', '<leader>tt', function()
    local task_folder = '.vrun'

    local cwd = vim.fn.getcwd()
    local task_dir = cwd .. '/' .. task_folder
    
    -- Check if the task folder exists
    if vim.fn.isdirectory(task_dir) == 0 then
      vim.notify('No ' .. task_folder .. ' directory found in ' .. cwd, vim.log.levels.WARN)
      return
    end
    
    -- Get all files in the task folder
    local files = vim.fn.glob(task_dir .. '/*', false, true)
    
    -- Filter out directories, keep only files
    local task_files = {}
    for _, file in ipairs(files) do
      if vim.fn.isdirectory(file) == 0 then
        table.insert(task_files, file)
      end
    end
    
    if #task_files == 0 then
      vim.notify('No task files found in ' .. task_folder, vim.log.levels.WARN)
      return
    end
    
    vim.ui.select(task_files, {
      prompt = 'Select task to run:',
      format_item = function(item)
        -- Show just the filename without path
        return vim.fn.fnamemodify(item, ':t')
      end,
    }, function(choice)
      if not choice then
        return
      end

      local lines = vim.fn.readfile(choice)
      
      if #lines == 0 then
        vim.notify(choice .. ' is empty', vim.log.levels.WARN)
        return
      end

      local buffer_name = vim.fn.fnamemodify(choice, ':t')

      vim.cmd 'enew'
      local buf = vim.api.nvim_get_current_buf()
      local term_id = vim.fn.termopen(vim.o.shell)

      vim.api.nvim_buf_set_name(buf, 'term://' .. buffer_name)

      vim.defer_fn(function()
        local term_chan = vim.b.terminal_job_id

        if term_chan then
          for _, line in ipairs(lines) do
            if line ~= '' and not line:match '^%s*#' then
              vim.api.nvim_chan_send(term_chan, line .. '\n')
            end
          end
        end
      end, 100)

      vim.cmd 'startinsert'
    end)
  end, { desc = 'terminal task' })

  -- Debug/Diagnostics - <leader>d
  -- Debug keymaps are configured in the DAP plugin setup

  -- Diagnostic navigation
  map('n', '<leader>dn', vim.diagnostic.goto_next, { desc = 'diagnostic next' })
  map('n', '<leader>dp', vim.diagnostic.goto_prev, { desc = 'diagnostic previous' })
  map('n', '<leader>de', vim.diagnostic.open_float, { desc = 'diagnostic error' })
  map('n', '<leader>dq', vim.diagnostic.setloclist, { desc = 'diagnostic quickfix' })

  -- AI - <leader>a
  map({ 'n', 'v' }, '<leader>a?', function()
    local text_to_send = ''

    -- Check if we're in visual mode
    local mode = vim.fn.mode()
    if mode == 'v' or mode == 'V' or mode == '\22' then -- \22 is visual block mode
      -- Get selected text
      local start_pos = vim.fn.getpos "'<"
      local end_pos = vim.fn.getpos "'>"
      local lines = vim.fn.getline(start_pos[2], end_pos[2])

      -- Handle single line selection
      if #lines == 1 then
        if lines[1] then
          lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
        end
      elseif #lines > 1 then
        -- Handle multi-line selection
        if lines[1] then
          lines[1] = string.sub(lines[1], start_pos[3])
        end
        if lines[#lines] then
          lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
        end
      end

      text_to_send = table.concat(lines, '\n')
    else
      -- Normal mode - get current line
      text_to_send = vim.fn.getline '.'
    end

    if text_to_send == '' then
      vim.notify('No text to explain', vim.log.levels.WARN)
      return
    end

    -- Prompt for additional instructions
    local additional_prompt = vim.fn.input 'Additional instructions (optional): '

    -- Build the prompt
    local prompt = 'Explain the following code'
    if additional_prompt ~= '' then
      prompt = prompt .. ' with these instructions: ' .. additional_prompt
    end
    prompt = prompt .. ':\\n\\n'

    -- Escape the text properly for shell
    local escaped_text = text_to_send:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('`', '\\`'):gsub('%$', '\\$')

    -- Run claude command with text
    local cmd = string.format('claude -p "%s%s"', prompt, escaped_text)
    local output = vim.fn.system(cmd)

    if vim.v.shell_error ~= 0 then
      vim.notify('Claude command failed: ' .. output, vim.log.levels.ERROR)
    else
      -- Open output in a new buffer
      vim.cmd 'new'
      vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.split(output, '\n'))
      vim.bo.buftype = 'nofile'
      vim.bo.bufhidden = 'wipe'
      vim.bo.filetype = 'markdown'
      vim.cmd 'normal! gg'
      vim.notify 'Claude explanation opened in new buffer'
    end
  end, { desc = 'explain code' })

  -- Code - <leader>c
  map('n', '<leader>cf', function()
    local ok = pcall(vim.lsp.buf.format, { async = true })
    if not ok then
      vim.notify('No formatter available', vim.log.levels.WARN)
    end
  end, { desc = 'code format' })

  -- Navigation - <leader>n
  -- Keeping this group empty for future navigation keybinds

  -- Run/REPL - <leader>r
  map('n', '<leader>rt', '<cmd>TestNearest<CR>', { desc = 'test nearest' })
  map('n', '<leader>rf', '<cmd>TestFile<CR>', { desc = 'test file' })
  map('n', '<leader>rs', '<cmd>TestSuite<CR>', { desc = 'test suite' })
  map('n', '<leader>rl', '<cmd>TestLast<CR>', { desc = 'test last' })
  map('n', '<leader>rv', '<cmd>TestVisit<CR>', { desc = 'test visit' })

  -- Help/Documentation - <leader>h
  -- Help keymaps are configured in telescope plugin setup

  -- Special double leader mapping for buffers
  -- This is configured in telescope plugin setup

  -- LuaSnip reload
  map('n', '<leader><leader>s', '<cmd>source ~/.config/nvim/after/plugin/luasnip.lua<CR>', { desc = 'Reload LuaSnip' })

  -- Diagnostic navigation (bracket style)
  map('n', '[d', vim.diagnostic.goto_prev, { desc = 'Go to previous diagnostic message' })
  map('n', ']d', vim.diagnostic.goto_next, { desc = 'Go to next diagnostic message' })

  -- Quickfix navigation
  map('n', '[q', '<cmd>cprevious<CR>', { desc = 'Previous quickfix' })
  map('n', ']q', '<cmd>cnext<CR>', { desc = 'Next quickfix' })

  -- Add which-key groups for the keymaps defined in this function
  -- We need to defer this slightly since which-key might not be loaded yet
  vim.defer_fn(function()
    local ok, wk = pcall(require, 'which-key')
    if ok then
      wk.add(wk_groups)
    end
  end, 100)
end

-- Note: which-key groups are now defined within each plugin-specific setup function
-- to ensure they're available when the keymaps are actually registered

-- Functions for plugin-specific keymaps that require plugins to be loaded
M.setup_telescope_keymaps = function()
  local builtin = require 'telescope.builtin'
  local map = vim.keymap.set
  local wk = require 'which-key'

  -- Ensure groups are defined
  wk.add {
    { '<leader>f', group = 'file' },
    { '<leader>s', group = 'search' },
    { '<leader>h', group = 'help' },
  }

  -- File operations
  map('n', '<leader>fp', function()
    local path = vim.fn.expand '%:p'
    vim.fn.setreg('+', path)
    vim.notify('Copied path: ' .. path)
  end, { desc = 'copy file path' })

  -- Git operations
  map('n', '<leader>gc', builtin.git_commits, { desc = 'git commits' })
  map('n', '<leader>gb', builtin.git_branches, { desc = 'git branches' })

  -- Search operations
  map('n', '<leader>sh', builtin.help_tags, { desc = 'search help' })
  map('n', '<leader>sk', builtin.keymaps, { desc = 'search keymaps' })
  map('n', '<leader>sf', builtin.find_files, { desc = 'search files' })
  map('n', '<leader>ss', builtin.lsp_document_symbols, { desc = 'search symbols' })
  map('n', '<leader>sS', builtin.lsp_dynamic_workspace_symbols, { desc = 'search symbols (project)' })
  map('n', '<leader>sT', builtin.builtin, { desc = 'search telescope' })
  map('n', '<leader>sw', builtin.grep_string, { desc = 'search word' })
  map('n', '<leader>sg', require('telescope').extensions.live_grep_args.live_grep_args, { desc = 'search grep' })
  map('n', '<leader>sd', builtin.diagnostics, { desc = 'search diagnostics' })
  map('n', '<leader>sr', builtin.resume, { desc = 'search resume' })
  map('n', '<leader>s.', builtin.oldfiles, { desc = 'search recent files' })
  map('n', '<leader>st', '<cmd>TodoTelescope<CR>', { desc = 'search todos' })
  map('n', '<leader>sm', '<cmd>Telescope media_files<CR>', { desc = 'search media files' })
  
  -- Terminal operations
  map('n', '<leader>ts', function()
    require('custom.telescope').tmux_sessions()
  end, { desc = 'tmux sessions' })

  -- Help/Documentation
  map('n', '<leader>hh', builtin.help_tags, { desc = 'help tags' })
  map('n', '<leader>hk', builtin.keymaps, { desc = 'keymaps' })
  map('n', '<leader>hm', builtin.man_pages, { desc = 'man pages' })
  map('n', '<leader>hi', '<cmd>Inspect<CR>', { desc = 'inspect' })
  map('n', '<leader>hn', '<cmd>h news<CR>', { desc = 'news' })

  -- Special double leader mapping for buffers
  map('n', '<leader><leader>', builtin.buffers, { desc = 'find buffers' })

  -- Search in current buffer (fuzzy matching, unlike / which is exact match only)
  map('n', '<leader>sb', function()
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown {
      winblend = 10,
      previewer = false,
    })
  end, { desc = 'search buffer' })

  -- Search in open files
  map('n', '<leader>s/', function()
    builtin.live_grep {
      grep_open_files = true,
      prompt_title = 'Live Grep in Open Files',
    }
  end, { desc = 'search in open files' })

  -- Search Neovim config
  map('n', '<leader>sn', function()
    builtin.find_files { cwd = vim.fn.stdpath 'config' }
  end, { desc = 'search neovim files' })

  -- Search folders and open in Oil
  map('n', '<leader>sF', function()
    builtin.find_files {
      find_command = { 'find', '.', '-type', 'd', '-not', '-path', '*/.*' },
      prompt_title = 'Search Folders',
      previewer = false,
      layout_config = { height = 0.6 },
      attach_mappings = function(_, map_key)
        map_key('i', '<CR>', function(prompt_bufnr)
          local selection = require('telescope.actions.state').get_selected_entry()
          require('telescope.actions').close(prompt_bufnr)
          if selection then
            vim.cmd('Oil ' .. vim.fn.fnameescape(selection.value))
          end
        end)
        map_key('n', '<CR>', function(prompt_bufnr)
          local selection = require('telescope.actions.state').get_selected_entry()
          require('telescope.actions').close(prompt_bufnr)
          if selection then
            vim.cmd('Oil ' .. vim.fn.fnameescape(selection.value))
          end
        end)
        return true
      end,
    }
  end, { desc = 'search folders' })
end

M.setup_lsp_keymaps = function(event)
  local map = function(keys, func, desc, mode)
    mode = mode or 'n'
    vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = desc })
  end

  local wk = require 'which-key'
  -- Ensure LSP group is defined
  wk.add {
    { '<leader>l', group = 'lsp' },
  }

  -- LSP/Language operations
  map('<leader>la', vim.lsp.buf.code_action, 'code action', { 'n', 'x' })
  map('<leader>lr', vim.lsp.buf.rename, 'rename')
  map('<leader>le', vim.diagnostic.open_float, 'show error')
  map('<leader>lq', vim.diagnostic.setloclist, 'diagnostic quickfix')
end

M.setup_gitsigns_keymaps = function(bufnr)
  local gitsigns = require 'gitsigns'
  local map = function(mode, l, r, opts)
    opts = opts or {}
    opts.buffer = bufnr
    vim.keymap.set(mode, l, r, opts)
  end

  local wk = require 'which-key'
  -- Ensure Git Hunks group is defined (main Git group is in setup())
  wk.add {
    { '<leader>gh', group = 'git hunks' },
  }

  -- Git Hunks (moved from <leader>h to <leader>gh)
  map('n', '<leader>ghs', gitsigns.stage_hunk, { desc = 'stage hunk' })
  map('n', '<leader>ghr', gitsigns.reset_hunk, { desc = 'reset hunk' })
  map('v', '<leader>ghs', function()
    gitsigns.stage_hunk { vim.fn.line '.', vim.fn.line 'v' }
  end, { desc = 'stage hunk' })
  map('v', '<leader>ghr', function()
    gitsigns.reset_hunk { vim.fn.line '.', vim.fn.line 'v' }
  end, { desc = 'reset hunk' })
  map('n', '<leader>ghS', gitsigns.stage_buffer, { desc = 'stage buffer' })
  map('n', '<leader>ghu', gitsigns.undo_stage_hunk, { desc = 'undo stage hunk' })
  map('n', '<leader>ghR', gitsigns.reset_buffer, { desc = 'reset buffer' })
  map('n', '<leader>ghp', gitsigns.preview_hunk, { desc = 'preview hunk' })
  map('n', '<leader>ghi', gitsigns.preview_hunk_inline, { desc = 'preview hunk inline' })
  map('n', '<leader>ghb', function()
    gitsigns.blame_line { full = true }
  end, { desc = 'blame line' })
  map('n', '<leader>ghd', gitsigns.diffthis, { desc = 'diff this' })
  map('n', '<leader>ghD', function()
    gitsigns.diffthis '~'
  end, { desc = 'diff this ~' })
  map('n', '<leader>ghq', gitsigns.setqflist, { desc = 'quickfix list' })
  map('n', '<leader>ghQ', function()
    gitsigns.setqflist 'all'
  end, { desc = 'quickfix list (all)' })

  -- Toggle options
  map('n', '<leader>tb', gitsigns.toggle_current_line_blame, { desc = 'toggle blame line' })
  map('n', '<leader>tw', gitsigns.toggle_word_diff, { desc = 'toggle word diff' })
  map('n', '<leader>td', gitsigns.toggle_deleted, { desc = 'toggle show deleted' })

  -- Gitsigns navigation
  map('n', ']h', function()
    if vim.wo.diff then
      vim.cmd.normal { ']c', bang = true }
    else
      gitsigns.nav_hunk 'next'
    end
  end, { desc = 'Jump to next git hunk' })

  map('n', '[h', function()
    if vim.wo.diff then
      vim.cmd.normal { '[c', bang = true }
    else
      gitsigns.nav_hunk 'prev'
    end
  end, { desc = 'Jump to previous git hunk' })
end

M.setup_dap_keymaps = function()
  local dap = require 'dap'
  local dapui = require 'dapui'
  local map = vim.keymap.set
  local wk = require 'which-key'

  -- Ensure Debug group is defined
  wk.add {
    { '<leader>d', group = 'debug' },
  }

  -- Debug controls
  map('n', '<leader>dc', dap.continue, { desc = 'continue' })
  map('n', '<leader>dr', dap.restart, { desc = 'restart' })
  map('n', '<leader>dq', dap.terminate, { desc = 'quit' })
  map('n', '<leader>db', dap.toggle_breakpoint, { desc = 'breakpoint' })
  map('n', '<leader>dB', function()
    dap.set_breakpoint(vim.fn.input 'Breakpoint condition: ')
  end, { desc = 'breakpoint conditional' })

  -- Debug stepping
  map('n', '<leader>dl', dap.step_over, { desc = 'step over' })
  map('n', '<leader>dj', dap.step_into, { desc = 'step into' })
  map('n', '<leader>dk', dap.step_out, { desc = 'step out' })
  map('n', '<leader>dh', dap.step_back, { desc = 'step back' })

  -- Debug UI
  map('n', '<leader>dt', dapui.toggle, { desc = 'toggle ui' })
  map({ 'n', 'v' }, '<leader>de', function()
    dapui.eval(nil, { enter = true })
  end, { desc = 'evaluate' })
end

return M
