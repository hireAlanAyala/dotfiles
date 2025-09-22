#!/bin/bash
# Kill all child sessions that belong to the same working directory
# Child sessions are identified by the 6-character hash in their name

SESSION="$1"

if [ -z "$SESSION" ]; then
    exit 0
fi

# Get the working directory of the closing session
SESSION_CWD=$(tmux display-message -p -t "$SESSION" '#{pane_current_path}' 2>/dev/null)

if [ -z "$SESSION_CWD" ]; then
    # Session already closed, can't get its working directory
    exit 0
fi

# Generate the hash (first 6 chars of sha256)
HASH=$(echo -n "$SESSION_CWD" | sha256sum | cut -c1-6)

# Find all sessions that contain this hash in their name
# Pattern: anything_HASH_anything
CHILD_SESSIONS=$(tmux list-sessions -F '#{session_name}' 2>/dev/null | grep "_${HASH}_")

if [ -n "$CHILD_SESSIONS" ]; then
    echo "Cleaning up sessions with working dir hash $HASH from $SESSION_CWD:" >&2
    for child in $CHILD_SESSIONS; do
        if tmux has-session -t "$child" 2>/dev/null; then
            echo "  Killing: $child" >&2
            tmux kill-session -t "$child" 2>/dev/null
        fi
    done
fi