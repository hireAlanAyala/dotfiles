#!/bin/bash

# Tmux Session Initializer - Now using YAML-based session management
# This script serves as a compatibility layer for the new session manager

SESSION_MANAGER="$HOME/.config/tmux/session-manager.sh"

# Check if the new session manager exists
if [[ ! -f "$SESSION_MANAGER" ]]; then
    echo "Error: Session manager not found at $SESSION_MANAGER"
    echo "Please ensure the session manager script is installed."
    exit 1
fi

# Run the session manager with auto mode (creates auto-startup sessions and attaches to default)
exec "$SESSION_MANAGER" auto
