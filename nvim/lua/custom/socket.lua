local M = {}

-- Get the current socket address
function M.get()
  return vim.v.servername or ''
end

-- Get or create persistent project socket path
function M.get_project_socket()
  local cwd = vim.fn.getcwd()
  local socket_dir = vim.fn.stdpath('run') or '/tmp'

  -- Create deterministic socket name from current directory
  local project_hash = vim.fn.sha256(cwd):sub(1, 8)
  local socket_path = string.format('%s/nvim-project-%s.sock', socket_dir, project_hash)

  -- Check if socket exists and is stale (Neovim not running)
  if vim.fn.filereadable(socket_path) == 1 then
    -- Try to connect - if it fails, socket is stale
    local ok = pcall(function()
      vim.fn.sockconnect('pipe', socket_path, { rpc = true })
    end)
    if not ok then
      -- Socket is stale, remove it
      vim.fn.delete(socket_path)
    end
  end

  return socket_path
end

-- Initialize persistent socket for this session
function M.init()
  -- Start server if not already running
  if vim.v.servername == '' or vim.v.servername == vim.env.NVIM then
    local socket = M.get_project_socket()
    vim.fn.serverstart(socket)
  end

  -- Set NVIM_LISTEN_ADDRESS for compatibility
  vim.env.NVIM_LISTEN_ADDRESS = vim.v.servername
end

return M
