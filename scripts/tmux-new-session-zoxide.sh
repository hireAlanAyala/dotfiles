#!/bin/bash

# Tmux new session with zoxide directory lookup or path evaluation
# Usage: tmux-new-session-zoxide.sh <directory_query_or_path> [session_name]
# If session_name not provided, uses directory name

dir_input="$1"
session_name="$2"

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
    tmux display-message "Zoxide query '$dir_input' returned: '$path'"
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

# If no session name provided, use directory name
if [ -z "$session_name" ]; then
    # Get the last component of the path as session name
    session_name=$(basename "$path")
    # Replace dots with underscores (tmux doesn't like dots in session names)
    session_name=${session_name//./_}
fi

# Create new session and switch to it
tmux new-session -d -s "$session_name" -c "$path"
tmux switch-client -t "$session_name"
tmux display-message "Created session '$session_name' in: $path"