#!/bin/bash
session="$1"

# Function to remove only trailing blank lines from input
# Preserves blank lines within content
trim_trailing_blanks() {
    awk '/^[[:space:]]*$/{b=b RS $0;next} {printf "%s%s%s", b, NR==1?"":RS, $0;b=""} END{print ""}'
}

# Capture scrollback and display with trailing blank lines removed
tmux capture-pane -e -J -p -S -10000 -t "$session" | trim_trailing_blanks

# Then attach to the session
exec tmux attach-session -t "$session"