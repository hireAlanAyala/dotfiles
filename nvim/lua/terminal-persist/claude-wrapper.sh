#!/bin/bash
# Claude wrapper for nvim terminal-persist integration
#
# Features:
#   - Persists claude session ID in terminal-persist state file
#   - Detaches tmux to run claude directly in nvim terminal, reattaches after
#   - Session ID tied to tmux session name, survives claude restarts
#
# Usage:
#   claude              New managed session
#   claude fix bug      New managed session with prompt
#   claude -t           Resume stored session for this terminal
#   claude -c           Continue last conversation (tmux dance, no state tracking)
#
# Vanilla pass-through flags (no session management, no tmux dance):
#   -h  Help output (no session needed)
#   -p  Print mode, non-interactive (no TUI, used for pipes)
#   -r  Resume by user-specified session ID
#   -v  Version output (no session needed)
#
# Lifecycle (managed session):
#   1. Wrapper runs inside tmux session (terminal-persist managed)
#   2. Generate/lookup session ID, write to state file
#   3. tmux detach-client -E "..." detaches nvim from tmux
#      - tmux session stays alive in background
#      - -E command runs in nvim's terminal (outside tmux)
#   4. Claude TUI runs directly in nvim terminal (clean, no tmux layer)
#   5. On graceful exit (code 0): cleanup session ID from state
#      On forced kill: session ID preserved for auto-resume via terminal-persist
#   6. Reattach to tmux session (back to shell)

STATE_FILE="${PWD}/.nvim/terminal-sessions.json"
DEBUG_SCRIPT="$HOME/.config/nvim/lua/terminal-persist/claude-wrapper-debug.sh"

debug() {
  [[ "${CLAUDE_WRAPPER_DEBUG:-0}" == "1" && -x "$DEBUG_SCRIPT" ]] || return 0
  "$DEBUG_SCRIPT" "$@"
}

# Cleanup helper (called after claude exits)
[[ "$1" == "--cleanup" ]] && {
  [[ -f "$STATE_FILE" ]] && {
    tmp=$(mktemp)
    jq --arg s "$2" 'if .[$s] then .[$s] |= del(.claude_session_id) else . end' \
      "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
  }
  debug "cleanup session=$2 state_file=$STATE_FILE"
  exit 0
}

# Determine if this should be treated as an interactive TUI run
# TUI runs get the tmux "dance"; non-interactive (pipes, -p, -h/--help, -v/--version) do not.
is_tui=1
for arg in "$@"; do
  case "$arg" in
    -h|--help|-p|-v|--version) is_tui=0 ;;
  esac
done
[[ -t 0 && -t 1 ]] || is_tui=0

# Get tmux session name if in tmux
[[ -n "$TMUX" ]] && SESSION=$(tmux display-message -p '#S')

# Only manage sessions if inside a terminal-persist tmux session
manage_session=0
if [[ -n "$SESSION" && $is_tui -eq 1 ]]; then
  if jq -e --arg s "$SESSION" '.[$s]' "$STATE_FILE" &>/dev/null; then
    manage_session=1
  fi
fi

if [[ $manage_session -eq 1 ]]; then
  case "$1" in
    -t)
      # Resume stored session for this terminal
      shift
      id=$(jq -r --arg s "$SESSION" '.[$s].claude_session_id // empty' "$STATE_FILE")
      [[ -n "$id" ]] && args=(--resume "$id" "$@") || args=(--continue "$@")
      ;;
    -c)
      # Continue last conversation (tmux dance, but no state tracking)
      shift
      args=(--continue "$@")
      ;;
    -r)
      # Resume by user-specified session ID (tmux dance, no state tracking)
      shift
      args=(-r "$@")
      ;;
    -h|-p|-v)
      # Vanilla pass-through (see header for rationale)
      exec claude "$@"
      ;;
    *)
      # New managed session (bare, prompts, --long-flags, -d, etc.)
      id=$(uuidgen)
      tmp=$(mktemp)
      jq --arg s "$SESSION" --arg id "$id" '.[$s].claude_session_id = $id' \
        "$STATE_FILE" > "$tmp" && mv "$tmp" "$STATE_FILE"
      args=(--session-id "$id" "$@")
      ;;
  esac
else
  args=("$@")
fi

debug "session=$SESSION tmux=${TMUX:-0} is_tui=$is_tui manage_session=$manage_session args=${args[*]}"

if [[ -n "$SESSION" && $is_tui -eq 1 ]]; then
  # Detach tmux, run claude directly, cleanup on graceful exit, reattach
  # Post-detach command runs in nvim's terminal (outside tmux):
  post=""
  # 1. Run claude TUI
  post+="claude ${args[*]}; "
  # 3. Graceful exit (code 0): cleanup session ID from state
  post+="[ \$? -eq 0 ] && ~/.config/nvim/lua/terminal-persist/claude-wrapper.sh --cleanup '$SESSION'; "
  # 4. Reattach to tmux session
  post+="tmux attach -t '$SESSION'"
  exec tmux detach-client -E "$post"
fi

# Outside managed session: vanilla pass-through
exec claude "$@"
