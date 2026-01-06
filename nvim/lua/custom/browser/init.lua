-- Browser development tools
-- Keybindings under <leader>bd (browser dev)

local M = {}

local scripts_dir = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':h') .. '/scripts'
local node_path = vim.fn.expand '$HOME/.npm-global/lib/node_modules'
local log_path = '/tmp/network-metadata.json'

-- Track the background capture process
local capture_job_id = nil

local function get_node_env()
  return 'NODE_PATH=' .. node_path
end

local function check_deps()
  local check = vim.fn.system(get_node_env() .. ' node -e "require(\'chrome-remote-interface\')" 2>&1')
  if vim.v.shell_error ~= 0 then
    vim.notify('Missing chrome-remote-interface. Run: npm install -g chrome-remote-interface', vim.log.levels.ERROR)
    return false
  end
  return true
end

local function stop_capture()
  if capture_job_id then
    vim.fn.jobstop(capture_job_id)
    capture_job_id = nil
  end
end

local function start_capture(target_id)
  stop_capture()

  local script = scripts_dir .. '/network-capture.js'
  local cmd = string.format('%s node %s %s', get_node_env(), script, target_id)

  capture_job_id = vim.fn.jobstart(cmd, {
    on_exit = function(_, code)
      if code ~= 0 then
        vim.notify('Network capture exited with code ' .. code, vim.log.levels.WARN)
      end
      capture_job_id = nil
    end,
  })

  return capture_job_id ~= nil and capture_job_id > 0
end

local function open_network_terminal()
  local terminal_persist = require 'custom.terminal-persist'

  -- Check if "network" terminal already exists
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.b[buf].persist_name == 'network' then
      vim.api.nvim_set_current_buf(buf)
      vim.cmd 'startinsert'
      return
    end
  end

  -- Create new persistent terminal with tail command
  terminal_persist.new('network', true, 'tail -f ' .. log_path)
end

local function pick_tab_and_capture()
  if not check_deps() then
    return
  end

  local list_script = scripts_dir .. '/list-tabs.js'
  local cmd = string.format('%s node %s', get_node_env(), list_script)
  local output = vim.fn.system(cmd)

  if vim.v.shell_error ~= 0 then
    vim.notify('Failed to list tabs. Is Chrome running with --remote-debugging-port=9222?', vim.log.levels.ERROR)
    return
  end

  local ok, tabs = pcall(vim.json.decode, output)
  if not ok or tabs.error then
    vim.notify('Failed to parse tabs: ' .. (tabs.error or 'unknown error'), vim.log.levels.ERROR)
    return
  end

  if #tabs == 0 then
    vim.notify('No tabs found', vim.log.levels.WARN)
    return
  end

  local fzf = require 'fzf-lua'

  local entries = {}
  local tab_map = {}

  for i, tab in ipairs(tabs) do
    local display = string.format('%s | %s', tab.title or '(no title)', tab.url or '')
    entries[i] = display
    tab_map[display] = tab.targetId
  end

  fzf.fzf_exec(entries, {
    prompt = 'Select tab> ',
    actions = {
      ['default'] = function(selected)
        if not selected or #selected == 0 then
          return
        end

        local target_id = tab_map[selected[1]]
        if not target_id then
          vim.notify('Could not find target ID', vim.log.levels.ERROR)
          return
        end

        -- Start capture in background
        if start_capture(target_id) then
          vim.notify('Network capture started', vim.log.levels.INFO)
          -- Open persistent terminal with tail
          vim.defer_fn(open_network_terminal, 200)
        else
          vim.notify('Failed to start capture', vim.log.levels.ERROR)
        end
      end,
    },
  })
end

M.setup = function()
  local map = vim.keymap.set

  -- Register which-key group
  vim.defer_fn(function()
    local ok, wk = pcall(require, 'which-key')
    if ok then
      wk.add {
        { '<leader>b', group = 'browser' },
        { '<leader>bd', group = 'browser dev' },
      }
    end
  end, 100)

  -- Network capture - fzf picker, opens tail in persistent terminal
  map('n', '<leader>bdn', pick_tab_and_capture, { desc = 'network capture' })

  -- Stop network capture
  map('n', '<leader>bds', function()
    stop_capture()
    vim.notify('Network capture stopped', vim.log.levels.INFO)
  end, { desc = 'stop network capture' })

  -- Diagnose captured network data
  map('n', '<leader>bdd', function()
    local script = scripts_dir .. '/network-diagnose.js'
    vim.cmd('terminal node ' .. vim.fn.fnameescape(script))
  end, { desc = 'diagnose network' })

  -- Cleanup on exit
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = stop_capture,
  })
end

return M
