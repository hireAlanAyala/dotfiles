local M = {}

-- Strategy interface:
--   session_exists(self, session_name) -> boolean  [BLOCKING - avoid in hot paths]
--   attach(self, session_name) -> string           [NON-BLOCKING - use for restore]
--   create_or_attach(self, session_name) -> string [BLOCKING - use for new terminals]
--   kill(self, session_name)

M.strategies = {}

-- tmux: session persistence with scrollback history
-- Note: tmux requires explicit -c cwd because new-session runs on the tmux server,
-- which uses its own directory, not the caller's cwd.
M.strategies.tmux = {
  session_exists = function(self, session_name)
    vim.fn.system(string.format('tmux has-session -t %s 2>/dev/null', session_name))
    return vim.v.shell_error == 0
  end,

  -- Attach to existing session (skip existence check - caller must verify)
  attach = function(self, session_name)
    return string.format('~/.config/nvim/lua/terminal-persist/tmux-attach-with-history.sh %s', session_name)
  end,

  create_or_attach = function(self, session_name)
    if not self:session_exists(session_name) then
      vim.fn.system(string.format(
        "tmux new-session -d -s %s -c '%s' \\; set-option -t %s history-limit 50000",
        session_name, vim.fn.getcwd(), session_name
      ))
    end
    return self:attach(session_name)
  end,

  kill = function(self, session_name)
    if self:session_exists(session_name) then
      vim.fn.system(string.format('tmux kill-session -t "%s" 2>&1', session_name))
    end
  end,
}

return M
