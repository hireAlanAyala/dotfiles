#!/bin/bash
session="$1"
# Print the scrollback history first
tmux capture-pane -t "$session" -S - -p
# Then attach to the session
exec tmux attach-session -t "$session"