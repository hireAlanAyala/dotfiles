-- gocryptfs vault integration for oil.
--
-- One vault: encrypted at rest in ~/.vault-encrypted, mounted as a plaintext
-- view at ~/vault. Stepping into ~/vault (in oil or any buffer) auto-prompts for
-- the password and mounts it. Leaving the vault tree re-locks it after a short
-- idle, so the plaintext only exists while you are actually in there.
--
-- The actual mount/unmount logic lives in the `vault` bin script (arch/bin/vault);
-- this module only decides WHEN to unlock/lock based on which buffers are open.

local M = {}

local CIPHER = vim.fn.expand('~/.vault-encrypted')
local MOUNT = vim.fn.expand('~/vault')
local IDLE_MS = 10000
local VAULT_BIN = 'vault' -- on PATH via ~/.local/bin

local lock_timer = nil
local unlocking = false -- guards against stacking password prompts

-- Path of a buffer, resolving oil:// buffers to the dir they show.
local function buf_path(buf)
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' then return nil end
  local oil_path = name:match('^oil://(.*)$')
  return oil_path or name
end

-- Is `path` the mountpoint itself or somewhere inside it?
local function in_vault(path)
  if not path or path == '' then return false end
  path = vim.fn.fnamemodify(path, ':p'):gsub('/+$', '')
  return path == MOUNT or path:sub(1, #MOUNT + 1) == MOUNT .. '/'
end

-- Read /proc/mounts directly (no subprocess) to see if the vault is mounted.
local function is_mounted()
  local f = io.open('/proc/mounts', 'r')
  if not f then return false end
  for line in f:lines() do
    local mp = line:match('^%S+%s+(%S+)%s')
    if mp == MOUNT then
      f:close()
      return true
    end
  end
  f:close()
  return false
end

-- Is a vault buffer (oil or file) currently VISIBLE in some window? We check
-- windows, not the loaded-buffer list, on purpose: oil keeps a background buffer
-- alive for every directory you visit, so a loaded-buffer check would stay true
-- forever after one browse and the lock-on-leave would never fire. "Visible
-- somewhere" is the real signal that you haven't left the vault yet.
local function any_buffer_in_vault()
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    local p = buf_path(buf)
    -- win_findbuf finds windows across ALL tabpages, so a vault buffer shown in
    -- another tab still counts; a backgrounded (hidden) oil buffer does not.
    if p and in_vault(p) and #vim.fn.win_findbuf(buf) > 0 then
      return true
    end
  end
  return false
end

local function cancel_lock_timer()
  if lock_timer then
    lock_timer:stop()
    if not lock_timer:is_closing() then lock_timer:close() end
    lock_timer = nil
  end
end

-- Lock now, but only if nothing is still using the vault.
local function do_lock()
  if not is_mounted() then return end
  if any_buffer_in_vault() then return end
  vim.system({ VAULT_BIN, 'lock' }, {}, function(res)
    vim.schedule(function()
      if res.code == 0 then
        vim.notify('Vault locked')
      elseif res.code == 75 then
        -- Lazy-detached but gocryptfs is still serving a held process: the vault
        -- LOOKS locked but its plaintext is still readable by that process.
        vim.notify(
          'Vault NOT fully sealed: a process still holds it open (lazily detached). '
            .. 'It seals once that process exits -- check for a shell/terminal inside ' .. MOUNT .. '.',
          vim.log.levels.WARN)
      else
        vim.notify('Vault lock failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
      end
    end)
  end)
end

local function schedule_lock()
  cancel_lock_timer()
  lock_timer = vim.loop.new_timer()
  lock_timer:start(IDLE_MS, 0, function()
    cancel_lock_timer()
    vim.schedule(do_lock)
  end)
end

-- Prompt for the password and mount. No-op if already mounted or already prompting.
local function unlock()
  if unlocking or is_mounted() then return end
  if vim.fn.isdirectory(CIPHER) == 0 then
    vim.notify('Vault: cipher dir missing: ' .. CIPHER, vim.log.levels.ERROR)
    return
  end
  unlocking = true
  local pw = vim.fn.inputsecret('Vault password: ')
  if pw == nil or pw == '' then
    unlocking = false
    vim.notify('Vault: unlock cancelled', vim.log.levels.WARN)
    return
  end
  vim.system({ VAULT_BIN, 'unlock' }, { stdin = pw .. '\n' }, function(res)
    vim.schedule(function()
      unlocking = false
      if res.code == 0 then
        vim.notify('Vault unlocked')
        -- Refresh the oil listing so the now-decrypted files appear.
        if vim.bo.filetype == 'oil' then
          pcall(function() require('oil').open(MOUNT) end)
        end
      elseif res.code == 76 then
        -- A prior instance is still draining; mounting now would double-mount the
        -- cipher dir. Not a failure -- just retry once it has finished sealing.
        vim.notify('Vault still sealing from a prior lock -- wait a moment and try again.',
          vim.log.levels.WARN)
      else
        vim.notify('Vault unlock failed: ' .. (res.stderr or ''), vim.log.levels.ERROR)
      end
    end)
  end)
end

function M.setup()
  -- Fail loud if MOUNT is degenerate: in_vault()'s prefix match would otherwise
  -- silently mis-scope (match everything or nothing), so refuse to wire up the
  -- integration rather than guard the vault against the wrong path.
  if MOUNT:sub(1, 1) ~= '/' or MOUNT == '/' then
    vim.notify('vault.lua: MOUNT misconfigured (' .. tostring(MOUNT) .. ') -- integration disabled',
      vim.log.levels.ERROR)
    return
  end

  -- Never write nvim's plaintext derivatives (persistent undo, swap) for files
  -- under the vault -- those land OUTSIDE it and would survive locking, leaking
  -- full contents. Per-buffer overrides win over the global options.
  vim.api.nvim_create_autocmd({ 'BufReadPre', 'BufNewFile' }, {
    pattern = MOUNT .. '/*',
    callback = function(args)
      vim.bo[args.buf].undofile = false
      vim.bo[args.buf].swapfile = false
    end,
  })

  -- Drive unlock/lock off buffer focus. oil opens one buffer per directory, so
  -- BufEnter fires for both oil navigation and opening files.
  vim.api.nvim_create_autocmd('BufEnter', {
    callback = function(args)
      local p = buf_path(args.buf)
      if p and in_vault(p) then
        cancel_lock_timer()
        if not is_mounted() then
          vim.schedule(unlock)
        end
      elseif not any_buffer_in_vault() then
        schedule_lock()
      end
    end,
  })

  -- Lock when nvim exits, so the vault never stays decrypted after you close the
  -- editor. Synchronous; the bin script's lazy fallback keeps it from hanging.
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function()
      if is_mounted() then vim.fn.system({ VAULT_BIN, 'lock' }) end
    end,
  })

  vim.api.nvim_create_user_command('VaultLock', do_lock, { desc = 'Lock the vault now' })
  vim.api.nvim_create_user_command('VaultUnlock', unlock, { desc = 'Unlock the vault' })
  vim.api.nvim_create_user_command('VaultStatus', function()
    vim.notify('Vault: ' .. (is_mounted() and 'unlocked' or 'locked'))
  end, { desc = 'Show vault status' })
end

return M
