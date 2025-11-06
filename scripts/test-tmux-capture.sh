#!/bin/bash

# Test script to debug tmux capture-pane behavior in nested sessions

session="${1:-test-session}"

echo "=== Testing tmux capture-pane for session: $session ==="
echo

# Check if we're in a tmux session
if [ -n "$TMUX" ]; then
    echo "Currently in tmux session: $(tmux display-message -p '#S')"
    echo "TMUX env variable: $TMUX"
else
    echo "Not currently in a tmux session"
fi
echo

# Check if target session exists
if tmux has-session -t "$session" 2>/dev/null; then
    echo "Session '$session' exists"
    
    # Get session info
    echo "Session info:"
    tmux list-panes -t "$session" -F "  Pane: #P, Size: #{pane_width}x#{pane_height}, Current: #{pane_current_command}"
    echo
    
    # Try to capture with different parameters
    echo "Testing capture-pane with different parameters:"
    echo
    
    echo "1. Basic capture (last 50 lines):"
    tmux capture-pane -p -t "$session" | wc -l
    echo
    
    echo "2. With -S -10000 (up to 10000 lines of scrollback):"
    tmux capture-pane -p -S -10000 -t "$session" | wc -l
    echo
    
    echo "3. With -S - (entire scrollback):"
    tmux capture-pane -p -S - -t "$session" | wc -l
    echo
    
    echo "4. With -J (join wrapped lines):"
    tmux capture-pane -p -J -S -10000 -t "$session" | wc -l
    echo
    
    echo "5. With -e (escape sequences):"
    tmux capture-pane -p -e -S -10000 -t "$session" | wc -l
    echo
    
    echo "6. Full parameters as used in script (-e -J -p -S -10000):"
    tmux capture-pane -e -J -p -S -10000 -t "$session" | wc -l
    echo
    
    # Check the actual history limit of the pane
    echo "Pane history limit:"
    tmux show-options -t "$session" | grep history-limit
    echo
    
    # Try to see if there's any content
    echo "First 5 lines of captured content:"
    tmux capture-pane -e -J -p -S -10000 -t "$session" | head -5
    echo
    
    echo "Last 5 lines of captured content:"
    tmux capture-pane -e -J -p -S -10000 -t "$session" | tail -5
    
else
    echo "Session '$session' does not exist"
fi