#!/bin/bash

# Change directory for entire tmux session, all windows, and all panes
# Usage: tmux-change-session-dir.sh <directory_input>

dir_input="$1"

if [ -z "$dir_input" ]; then
    tmux display-message "Error: Directory input is required"
    exit 1
fi

path=""

# First, try to evaluate as bash expression (for things like $HOME, $(pwd), etc.)
if [[ "$dir_input" =~ \$|\`|\$\( ]]; then
    # Contains bash variables or command substitution
    path=$(eval echo "$dir_input" 2>/dev/null)
    if [ -z "$path" ]; then
        tmux display-message "Error: Failed to evaluate bash expression: $dir_input"
        exit 1
    fi
elif [ -d "$dir_input" ]; then
    # Direct path exists
    path="$dir_input"
else
    # Use zoxide to find the directory
    path=$(zoxide query "$dir_input" 2>/dev/null)
    if [ -z "$path" ]; then
        tmux display-message "Error: Directory not found for query: $dir_input"
        exit 1
    fi
fi

# Expand to absolute path
path=$(realpath "$path" 2>/dev/null)

if [ -z "$path" ] || [ ! -d "$path" ]; then
    tmux display-message "Error: Resolved path does not exist or is not a directory: $path"
    exit 1
fi

# Get current session name
session_name=$(tmux display-message -p '#S')

# Set default path for the session (affects new windows/panes)
tmux set-option default-path "$path"

# Get all windows in the current session
windows=$(tmux list-windows -t "$session_name" -F '#I')

# Change directory for all panes in all windows
for window_id in $windows; do
    # Get all panes in this window
    panes=$(tmux list-panes -t "$session_name:$window_id" -F '#P')

    for pane_id in $panes; do
        # Send cd command to each pane
        tmux send-keys -t "$session_name:$window_id.$pane_id" "cd '$path'" Enter
    done
done

# tmux display-message "Changed session '$session_name' directory to: $path"
