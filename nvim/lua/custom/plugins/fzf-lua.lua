-- fzf-lua configuration
-- Primary fuzzy finder replacing telescope

-- Custom action: Smart buffer delete
-- Switches to alt buffer before deleting if the buffer is currently visible
local function smart_buf_del(selected, opts)
  local path = require("fzf-lua.path")
  local actions = require("fzf-lua.actions")

  for _, sel in ipairs(selected) do
    local entry = path.entry_to_file(sel, opts)
    if entry.bufnr then
      local bufnr_to_delete = entry.bufnr

      -- Check if the buffer to delete is currently visible in any window
      local target_win = nil
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(win) == bufnr_to_delete then
          target_win = win
          break
        end
      end

      -- If visible, switch to an alternate buffer first
      if target_win then
        local alt_buf = nil
        for _, buf in ipairs(vim.api.nvim_list_bufs()) do
          if buf ~= bufnr_to_delete
              and vim.api.nvim_buf_is_valid(buf)
              and vim.api.nvim_buf_is_loaded(buf)
              and vim.bo[buf].buftype == '' then
            alt_buf = buf
            break
          end
        end

        if alt_buf then
          vim.api.nvim_win_set_buf(target_win, alt_buf)
        else
          local new_buf = vim.api.nvim_create_buf(true, false)
          vim.api.nvim_win_set_buf(target_win, new_buf)
        end
      end

      -- Now delete the buffer
      if vim.api.nvim_buf_is_valid(bufnr_to_delete) then
        vim.api.nvim_buf_delete(bufnr_to_delete, { force = true })
      end
    end
  end
end

-- Custom picker: Search folders and open in Oil
local function folders_oil(opts)
  opts = opts or {}
  local cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.fn.getcwd()
  local home = vim.fn.expand("~")
  local is_home = cwd == home
  local fzf = require("fzf-lua")
  -- fd outputs relative paths when run from cwd
  fzf.fzf_exec("fd --type d --hidden --exclude .git --exclude node_modules", {
    cwd = cwd,
    prompt = is_home and "~> " or "> ",
    fn_transform = function(entry)
      return is_home and "~/" .. entry or entry
    end,
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local path = selected[1]
          if is_home then
            path = path:gsub("^~/", home .. "/")
          else
            path = cwd .. "/" .. path
          end
          vim.cmd("Oil " .. vim.fn.fnameescape(path))
        end
      end,
      ["-"] = function()
        folders_oil({ cwd = "~" })
      end,
    },
    previewer = false,
    winopts = {
      height = 0.6,
      width = 0.5,
    },
  })
end

-- Custom picker: Files with dynamic fd flags via "  " delimiter
-- Usage: type "pattern  -u" to include ignored files
local function files_with_flags(opts)
  opts = opts or {}
  local fzf = require("fzf-lua")
  local base_fd = "fd --color=never --type f --hidden --full-path --exclude .git"

  local cwd = opts.cwd and vim.fn.expand(opts.cwd) or vim.fn.getcwd()
  local home = vim.fn.expand("~")
  local display_cwd = cwd:gsub("^" .. vim.pesc(home), "~")

  fzf.fzf_live(function(query)
    -- query can be string or table depending on fzf-lua version
    local query_str = ""
    if type(query) == "string" then
      query_str = query
    elseif type(query) == "table" then
      query_str = query[1] or query.query or ""
    end
    local search, flags = query_str:match("^(.-)  (.+)$")
    if flags then
      -- Has delimiter: use search term + flags, let fd filter
      local pattern = search ~= "" and vim.fn.shellescape(search) or ""
      return base_fd .. " " .. flags .. " " .. pattern .. " " .. vim.fn.shellescape(cwd)
    else
      -- No delimiter: let fzf handle all fuzzy matching
      return base_fd .. " . " .. vim.fn.shellescape(cwd)
    end
  end, {
    prompt = "> " .. display_cwd .. "/",
    cwd = cwd,
    exec_empty_query = true,
    file_icons = true,
    color_icons = true,
    actions = fzf.defaults.actions.files,
    previewer = fzf.config.globals.previewers,
    winopts = fzf.config.globals.winopts,
    fzf_opts = fzf.config.globals.fzf_opts,
  })
end

-- Custom picker: Grep in open buffers only
local function grep_open_buffers()
  local fzf = require("fzf-lua")
  -- Get list of open buffer file paths
  local buffers = vim.api.nvim_list_bufs()
  local files = {}
  for _, buf in ipairs(buffers) do
    if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].buftype == '' then
      local name = vim.api.nvim_buf_get_name(buf)
      if name and name ~= '' then
        table.insert(files, name)
      end
    end
  end

  if #files == 0 then
    vim.notify("No open buffers with files", vim.log.levels.INFO)
    return
  end

  fzf.live_grep({
    cmd = "rg --color=always --line-number --column --smart-case",
    search_paths = files,
    prompt = "Grep Open Files> ",
  })
end

-- Helper to run tmux commands on parent server (non-nested)
local function parent_tmux(cmd)
  return 'TMUX="" tmux ' .. cmd
end

-- Custom picker: Tmux sessions
local function tmux_sessions()
  local fzf = require("fzf-lua")

  -- Get current session and list in one call
  local cmd = parent_tmux('display-message -p "CURRENT:#{session_name}"') .. ' && ' ..
              parent_tmux('list-sessions -F "#{session_name}#{?session_attached, (attached),}"') .. ' 2>/dev/null || echo ""'
  local output = vim.fn.system(cmd)

  local current_session = output:match('CURRENT:([^\n]+)')
  local result = output:gsub('CURRENT:[^\n]+\n?', '')

  -- Parse all sessions and separate parent sessions from sub-sessions
  local all_sessions = {}
  local sub_sessions = {}

  for line in result:gmatch('[^\n]+') do
    local name, is_attached = line:match('^([^%(]+)(.*)$')
    if name then
      name = name:gsub('%s+$', '') -- trim whitespace
      local is_active = is_attached:match('%(attached%)')

      -- Check if this is a sub-session
      if name:match('_[%w]+_') then
        -- Extract parent session name (everything before the first _[hash]_)
        local parent = name:match('^(.-)_[%w]+_')
        if parent then
          if not sub_sessions[parent] then
            sub_sessions[parent] = 0
          end
          sub_sessions[parent] = sub_sessions[parent] + 1
        end
      else
        -- This is a parent session
        table.insert(all_sessions, {
          name = name,
          is_active = is_active ~= nil,
        })
      end
    end
  end

  -- Build the final sessions list with sub-session counts
  local sessions = {}

  for _, session in ipairs(all_sessions) do
    local display = session.name

    -- Add sub-session count if any
    local sub_count = sub_sessions[session.name] or 0
    if sub_count > 0 then
      display = display .. ' +' .. sub_count
    end

    -- Add active indicator
    if session.is_active then
      display = display .. ' *'
    end

    table.insert(sessions, display)
  end

  -- If no sessions, show a message
  if #sessions == 0 then
    vim.notify('No tmux sessions found', vim.log.levels.INFO)
    return
  end

  fzf.fzf_exec(sessions, {
    prompt = "> ",
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          -- Extract session name (remove +N and * indicators)
          local session_name = selected[1]:match('^([^%s]+)')
          vim.fn.system(parent_tmux('switch-client -t ' .. vim.fn.shellescape(session_name)))
        end
      end,
      ["ctrl-x"] = function(selected)
        if selected and selected[1] then
          local session_name = selected[1]:match('^([^%s]+)')
          local confirm = vim.fn.confirm("Delete tmux session '" .. session_name .. "'?", '&Yes\n&No', 2)
          if confirm == 1 then
            vim.fn.system(parent_tmux('kill-session -t ' .. vim.fn.shellescape(session_name)))
            -- Reopen picker
            vim.schedule(tmux_sessions)
          end
        end
      end,
    },
    previewer = false,
    winopts = {
      height = 0.4,
      width = 0.3,
      title = " Tmux Sessions ",
    },
  })
end

-- Helper: reload nvim for worktree switch
local function reload_nvim_for_worktree(worktree_path)
  -- Close terminal buffers
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      if vim.bo[buf].buftype == 'terminal' then
        pcall(vim.api.nvim_buf_delete, buf, { force = true })
      end
    end
  end

  -- Close regular buffers (fail if unsaved changes)
  local unclosed_bufs = {}
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
      if vim.bo[buf].buftype ~= 'terminal' then
        if not vim.bo[buf].modified then
          pcall(vim.api.nvim_buf_delete, buf, {})
        else
          table.insert(unclosed_bufs, buf)
        end
      end
    end
  end

  if #unclosed_bufs > 0 then
    vim.notify(string.format('Cannot switch: %d buffer(s) with unsaved changes', #unclosed_bufs), vim.log.levels.WARN)
    return false
  end

  local ok, err = pcall(vim.cmd, 'cd ' .. vim.fn.fnameescape(worktree_path))
  if not ok then
    vim.notify('Failed to change directory: ' .. err, vim.log.levels.ERROR)
    return false
  end

  vim.defer_fn(function() pcall(vim.cmd, 'LspRestart') end, 100)
  vim.defer_fn(function() pcall(vim.cmd, 'Oil .') end, 200)
  return true
end

-- Custom picker: Git worktrees
local function git_worktrees()
  local fzf = require("fzf-lua")

  -- Get current path and worktree list in one call
  local output = vim.fn.system('git rev-parse --show-toplevel && git worktree list 2>/dev/null')
  if vim.v.shell_error ~= 0 or output == '' then
    vim.notify('No git worktrees found', vim.log.levels.INFO)
    return
  end

  -- First line is current path, rest is worktree list
  local current_path = output:match('^([^\n]+)')
  local result = output:gsub('^[^\n]+\n', '')

  -- Parse worktrees into display strings and store data
  local entries = {}
  local worktree_data = {}

  for line in result:gmatch('[^\n]+') do
    local path, commit, branch = line:match('^(.-)%s+(%w+)%s+%[(.-)%]$')
    if path then
      local display_name = vim.fn.fnamemodify(path, ':t')
      local is_current = path == current_path
      local display = display_name .. ' [' .. branch .. ']'
      if is_current then
        display = display .. ' *'
      end
      table.insert(entries, display)
      worktree_data[display] = {
        path = path,
        branch = branch,
        commit = commit,
        name = display_name,
      }
    end
  end

  if #entries == 0 then
    vim.notify('Failed to parse git worktrees', vim.log.levels.ERROR)
    return
  end

  fzf.fzf_exec(entries, {
    prompt = "> ",
    actions = {
      ["default"] = function(selected)
        if selected and selected[1] then
          local wt = worktree_data[selected[1]]
          if wt then
            reload_nvim_for_worktree(wt.path)
          end
        end
      end,
      ["ctrl-x"] = function(selected)
        if selected and selected[1] then
          local wt = worktree_data[selected[1]]
          if wt then
            local confirm = vim.fn.confirm("Delete worktree '" .. wt.name .. "' [" .. wt.branch .. ']?', '&Yes\n&No', 2)
            if confirm == 1 then
              vim.fn.system('git worktree remove ' .. vim.fn.shellescape(wt.path))
              if vim.v.shell_error == 0 then
                vim.fn.system('git branch -D ' .. vim.fn.shellescape(wt.branch))
                vim.schedule(git_worktrees)
              else
                vim.notify('Failed to delete worktree', vim.log.levels.ERROR)
              end
            end
          end
        end
      end,
      ["alt-o"] = function(_)
        vim.ui.input({ prompt = 'New branch name: ' }, function(branch_name)
          if not branch_name or branch_name == '' then return end

          -- Find default branch
          local default_branch = 'main'
          local master_check = vim.fn.system('git show-ref --verify --quiet refs/heads/master')
          if vim.v.shell_error == 0 then
            default_branch = 'master'
          end

          vim.ui.input({ prompt = 'Base branch (default: ' .. default_branch .. '): ' }, function(base_branch)
            base_branch = (base_branch and base_branch ~= '') and base_branch or default_branch
            local cwd = vim.fn.getcwd()
            local parent_dir = vim.fn.fnamemodify(cwd, ':h')
            local path = parent_dir .. '/' .. branch_name
            local cmd = string.format('git worktree add -b %s %s %s',
              vim.fn.shellescape(branch_name),
              vim.fn.shellescape(path),
              vim.fn.shellescape(base_branch))

            local output = vim.fn.system(cmd)
            if vim.v.shell_error == 0 then
              reload_nvim_for_worktree(path)
            else
              vim.notify('Failed to create worktree: ' .. output, vim.log.levels.ERROR)
            end
          end)
        end)
      end,
    },
    preview = {
      type = "cmd",
      fn = function(items)
        local wt = worktree_data[items[1]]
        if wt then
          return 'cd "' .. wt.path .. '" && git log --oneline -20 --pretty=format:"%h %s"'
        end
        return "echo 'No preview'"
      end,
    },
    winopts = {
      height = 0.5,
      width = 0.8,
      title = " Git Worktrees ",
    },
  })
end

-- Custom picker: Task runner
local function task_picker()
  local fzf = require("fzf-lua")
  local task_runner = require("custom.task-runner")

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

  -- Get all running tmux sessions with one call (instead of N has-session calls)
  local running_sessions = {}
  local sessions_output = vim.fn.system('tmux list-sessions -F "#{session_name}" 2>/dev/null')
  for session in sessions_output:gmatch('[^\n]+') do
    running_sessions[session] = true
  end

  -- Build entries with running status
  local entries = {}
  local task_data = {}
  local project_id = vim.fn.fnamemodify(vim.fn.getcwd(), ':t'):gsub('[^%w%-_]', '_') .. '_' .. vim.fn.sha256(vim.fn.getcwd()):sub(1, 6)

  for _, task in ipairs(tasks) do
    local session_name = project_id .. '_' .. task.name
    local is_running = running_sessions[session_name] ~= nil

    local display = task.name
    if is_running then
      display = display .. ' ✅'
    end

    table.insert(entries, display)
    task_data[display] = task
  end

  fzf.fzf_exec(entries, {
    prompt = "> ",
    actions = {
      ["default"] = function(selected)
        if selected then
          if #selected > 1 then
            -- Multi-select: run all in background
            for _, sel in ipairs(selected) do
              local task = task_data[sel]
              if task then
                task_runner.run_task(task, false)
              end
            end
          elseif #selected == 1 then
            -- Single select: run and switch to terminal
            local task = task_data[selected[1]]
            if task then
              task_runner.run_task(task, true)
            end
          end
        end
      end,
    },
    fzf_opts = {
      ["--multi"] = true,
    },
    previewer = false,
    winopts = {
      height = 0.5,
      width = 0.33,
      title = " Tasks ",
    },
  })
end

-- Custom picker: Git log -S search (find commits that changed content)
local function git_pickaxe()
  local fzf = require("fzf-lua")

  -- Prompt for search term
  vim.ui.input({ prompt = "Search git history for: " }, function(search_term)
    if not search_term or search_term == "" then
      return
    end

    local cmd = string.format(
      "git log -S %s --source --all --pretty=format:'%%h %%ad %%s' --date=short 2>/dev/null",
      vim.fn.shellescape(search_term)
    )

    fzf.fzf_exec(cmd, {
      prompt = "Git -S: " .. search_term .. "> ",
      actions = {
        ["default"] = function(selected)
          if selected and selected[1] then
            local commit_hash = selected[1]:match('^(%w+)')
            if commit_hash then
              vim.cmd('Git show ' .. commit_hash)
            end
          end
        end,
        ["ctrl-y"] = function(selected)
          if selected and selected[1] then
            local commit_hash = selected[1]:match('^(%w+)')
            if commit_hash then
              vim.fn.setreg('+', commit_hash)
              vim.notify('Copied: ' .. commit_hash)
            end
          end
        end,
      },
      previewer = "git_diff",
      preview = {
        type = "cmd",
        fn = function(items)
          local commit = items[1]:match('^(%w+)')
          return "git show --color=always " .. commit
        end,
      },
      winopts = {
        height = 0.85,
        width = 0.80,
      },
    })
  end)
end

return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = {
    winopts = {
      height = 0.85,
      width = 0.80,
    },

    fzf_opts = {
      ["--multi"] = true,
      ["--pointer"] = " ",
      ["--marker"] = "+",
      ["--color"] = table.concat({
        "fg:#FFB000",
        "bg:#0A0A08",
        "hl:#FFCC00",
        "fg+:#FFCC00",
        "bg+:#2A1F00",
        "hl+:#FFCC00",
        "info:#996600",
        "prompt:#FFBB00",
        "query:#FFBB00",
        "pointer:#FFBB00",
        "marker:#FF8800",
        "spinner:#FFBB00",
        "header:#996600",
        "border:#996600",
        "gutter:#0A0A08",
      }, ","),
    },

    files = {
      fd_opts = "--color=never --type f --hidden --exclude .git",
      fzf_opts = {},
      file_icons = true,
      color_icons = true,
      actions = {},
    },

    grep = {
      rg_opts = "--color=always --line-number --column --smart-case --hidden --no-ignore --glob '!node_modules' --glob '!.git'",
    },

    buffers = {
      no_header = true,
      no_header_i = true,
      ignore_current_buffer = false,
      -- header-lines=0 ensures current buffer is selectable (not treated as a header)
      -- this allows hovering and deleting the current buffer with dd
      fzf_opts = { ["--header-lines"] = 0 },
      -- Filter out oil buffers
      filter = function(bufnr)
        return vim.bo[bufnr].filetype ~= "oil"
      end,
      -- Use buffer name instead of terminal title (programs like Claude Code can change
      -- the terminal title dynamically, making items unreliable to fuzzy search)
      formatter = "path",
      actions = { ["ctrl-x"] = { fn = smart_buf_del, reload = true } },
    },

    previewers = {
      builtin = {
        ueberzug_scaler = "cover",
        extensions = {
          ["png"] = { "ueberzugpp" },
          ["jpg"] = { "ueberzugpp" },
          ["jpeg"] = { "ueberzugpp" },
          ["gif"] = { "ueberzugpp" },
          ["webp"] = { "ueberzugpp" },
          ["bmp"] = { "ueberzugpp" },
          ["svg"] = { "ueberzugpp" },
        },
      },
    },
  },

  config = function(_, opts)
    local fzf = require('fzf-lua')
    local actions = require('fzf-lua.actions')

    -- Universal yank: grab the raw entry text (strip tab-separated display formatting)
    local function yank_entry(selected)
      if not selected or not selected[1] then return end
      -- Files picker uses "raw<TAB>formatted" with --with-nth=2, so strip after tab
      -- Other pickers (grep, buffers, etc.) don't use tabs, so this is a no-op
      local to_copy = selected[1]:match("^([^\t]+)") or selected[1]
      vim.fn.setreg("+", to_copy)
      vim.notify("Copied: " .. to_copy)
    end

    fzf.setup({
      winopts = opts.winopts,
      fzf_opts = opts.fzf_opts,
      -- Global defaults apply to ALL pickers
      defaults = {
        actions = {
          ["ctrl-y"] = { fn = yank_entry, exec_silent = true },
        },
      },
      -- File-specific actions (inherits defaults + adds more)
      actions = {
        files = {
          true,
          ["alt-q"] = actions.file_sel_to_qf,
        },
      },
      files = opts.files,
      grep = opts.grep,
      buffers = opts.buffers,
      previewers = opts.previewers,
    })

    -- Make matches stand out with background highlight
    vim.api.nvim_set_hl(0, 'FzfLuaSearch', { fg = '#0A0A08', bg = '#FFBB00', bold = true })

    -- Terminal keybindings for fzf buffers
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "fzf",
      callback = function()
        local buf = vim.api.nvim_get_current_buf()
        -- Normal mode mappings
        vim.keymap.set('n', '<CR>', 'i<CR>', { buffer = buf, noremap = true, silent = true })
        vim.keymap.set('n', '<Esc>', 'i<C-c>', { buffer = buf, noremap = true, silent = true })
        vim.keymap.set('n', 'j', 'i<Down><C-\\><C-n>', { buffer = buf, noremap = true, silent = true })
        vim.keymap.set('n', 'k', 'i<Up><C-\\><C-n>', { buffer = buf, noremap = true, silent = true })
        vim.keymap.set('n', 'dd', 'i<C-x><C-\\><C-n>', { buffer = buf, noremap = true, silent = true })
        vim.keymap.set('n', 'o', 'i<A-o>', { buffer = buf, noremap = true, silent = true })
        -- Tab for toggle selection in normal mode
        vim.keymap.set('n', '<Tab>', 'i<Tab><C-\\><C-n>', { buffer = buf, noremap = true, silent = true })
        vim.keymap.set('n', '<S-Tab>', 'i<S-Tab><C-\\><C-n>', { buffer = buf, noremap = true, silent = true })
        -- yy to copy the file path
        vim.keymap.set('n', 'yy', 'i<C-y><C-\\><C-n>', { buffer = buf, noremap = true, silent = true })
        -- - to switch to home directory (normal mode only)
        vim.keymap.set('n', '-', function()
          -- Close current fzf window and open files at home
          vim.cmd('close')
          vim.schedule(function()
            files_with_flags({ cwd = "~" })
            vim.cmd('startinsert')
          end)
        end, { buffer = buf, noremap = true, silent = true })
        -- Alt-q to send selected to quickfix in normal mode
        vim.keymap.set('n', '<A-q>', 'i<A-q>', { buffer = buf, noremap = true, silent = true })
      end,
    })

    local map = vim.keymap.set

    -- Register which-key group
    vim.defer_fn(function()
      local ok, wk = pcall(require, 'which-key')
      if ok then
        wk.add {
          { '<leader>f', group = 'file' },
          { '<leader>s', group = 'search' },
        }
      end
    end, 100)

    -- === Core Search Keymaps ===

    -- Buffers (most used, double leader)
    map('n', '<leader><leader>', function() fzf.buffers() end, { desc = 'buffers' })

    -- Find files
    map('n', '<leader>sf', function() fzf.files() end, { desc = 'search files' })
    map('n', '<leader>s<C-f>', files_with_flags, { desc = 'search files (live flags)' })

    -- Live grep (with glob support via "-- *.lua" syntax)
    map('n', '<leader>sg', function() fzf.live_grep() end, { desc = 'search grep' })

    -- Grep word under cursor
    map('n', '<leader>sw', function() fzf.grep_cword() end, { desc = 'search word' })

    -- Resume last search
    map('n', '<leader>sr', function() fzf.resume() end, { desc = 'search resume' })

    -- Recent files
    map('n', '<leader>s.', function() fzf.oldfiles() end, { desc = 'search recent files' })

    -- Current buffer fuzzy find
    map('n', '<leader>sb', function() fzf.blines() end, { desc = 'search buffer lines' })

    -- Search in open files only
    map('n', '<leader>s/', grep_open_buffers, { desc = 'search in open files' })


    -- Search folders and open in Oil
    map('n', '<leader>sF', folders_oil, { desc = 'search folders' })

    -- LSP symbols
    map('n', '<leader>ss', function() fzf.lsp_document_symbols() end, { desc = 'search symbols' })
    map('n', '<leader>sS', function() fzf.lsp_live_workspace_symbols() end, { desc = 'search symbols (workspace)' })

    -- Diagnostics
    map('n', '<leader>sd', function() fzf.diagnostics_workspace() end, { desc = 'search diagnostics' })

    -- Quickfix
    map('n', '<leader>sq', function() fzf.quickfix() end, { desc = 'search quickfix' })


    -- === Git ===
    map('n', '<leader>gc', function() fzf.git_commits() end, { desc = 'git commits' })
    map('n', '<leader>gb', function() fzf.git_branches() end, { desc = 'git branches' })
    map('n', '<leader>gf', function() fzf.git_files() end, { desc = 'git files' })
    map('n', '<leader>gS', function() fzf.git_status() end, { desc = 'git status (fzf)' })
    map('n', '<leader>g/', git_pickaxe, { desc = 'git pickaxe (-S search)' })
    map('n', '<leader>gw', git_worktrees, { desc = 'git worktrees' })

    -- === Tmux ===
    map('n', '<leader>ts', tmux_sessions, { desc = 'tmux sessions' })

    -- === Tasks ===
    map('n', '<leader>tt', task_picker, { desc = 'tasks' })

    -- === File operations ===
    map('n', '<leader>fp', function()
      local path = vim.fn.expand '%:p'
      vim.fn.setreg('+', path)
      vim.notify('Copied path: ' .. path)
    end, { desc = 'copy file path' })

    -- === Misc ===
    map('n', '<leader>sC', function() fzf.command_history() end, { desc = 'search command history' })
    map('n', '<leader>sm', function() fzf.marks() end, { desc = 'search marks' })
    map('n', '<leader>sj', function() fzf.jumps() end, { desc = 'search jumps' })
  end,
}
