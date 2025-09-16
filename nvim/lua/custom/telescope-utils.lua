-- Telescope utilities for reusable functionality

local M = {}

-- Create a double-key handler for telescope pickers
-- Usage: local dd_handler = create_double_key_handler('d', function() ... end, { timeout = 500, message = "Press 'd' again" })
M.create_double_key_handler = function(key, action, opts)
  opts = opts or {}
  local timeout = opts.timeout or 500 -- milliseconds
  local message = opts.message or ("Press '" .. key .. "' again")
  local silent = opts.silent or false
  
  local last_press = 0
  
  return function()
    local current_time = vim.fn.reltime()
    
    if last_press == 0 then
      last_press = current_time
      if not silent then
        vim.notify(message, vim.log.levels.INFO)
      end
      return
    end
    
    local time_since_last = vim.fn.reltimestr(vim.fn.reltime(last_press, current_time))
    
    if tonumber(time_since_last) < (timeout / 1000) then
      -- Reset the handler
      last_press = 0
      -- Execute the action
      action()
    else
      -- Too slow, restart the sequence
      last_press = current_time
      if not silent then
        vim.notify(message, vim.log.levels.INFO)
      end
    end
  end
end

-- Create a confirmation dialog wrapper
M.confirm_action = function(message, action, opts)
  opts = opts or {}
  local choices = opts.choices or "&Yes\n&No"
  local default = opts.default or 2
  
  return function()
    local confirm = vim.fn.confirm(message, choices, default)
    if confirm == 1 then
      action()
    end
  end
end

-- Combine double-key and confirmation for dangerous actions
M.create_double_key_confirm = function(key, message, action, opts)
  opts = opts or {}
  local confirm_opts = {
    choices = opts.choices,
    default = opts.default,
  }
  
  local double_key_opts = {
    timeout = opts.timeout,
    message = opts.message or ("Press '" .. key .. "' again to " .. (opts.action_name or "confirm")),
    silent = opts.silent,
  }
  
  local confirmed_action = M.confirm_action(message, action, confirm_opts)
  return M.create_double_key_handler(key, confirmed_action, double_key_opts)
end

return M