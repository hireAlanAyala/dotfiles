#!/bin/bash
# Dumps tmux scrollback into nvim's terminal buffer before attaching.
# nvim needs an in-memory copy for search, text-objects, and scrolling motions to work.

session="$1"

# Function to remove only trailing blank lines from input
# Preserves blank lines within content
trim_trailing_blanks() {
    awk '/^[[:space:]]*$/{b=b RS $0;next} {printf "%s%s%s", b, NR==1?"":RS, $0;b=""} END{print ""}'
}

# Pass NVIM socket to tmux session so child processes know they're inside nvim
if [[ -n "$NVIM" ]]; then
    tmux set-environment -t "$session" NVIM "$NVIM"
fi

# Capture scrollback and display with trailing blank lines removed
tmux capture-pane -e -J -p -S -10000 -t "$session" | trim_trailing_blanks

# Then attach to the session
exec tmux attach-session -t "$session"