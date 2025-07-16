#!/bin/bash

# Mouse jiggle script for WSL
# Moves mouse up and down by 1 pixel every X seconds to prevent screen lock

# Default interval (seconds)
INTERVAL=${1:-30}

# PID file for process locking
PIDFILE="/tmp/mouse-jiggle.pid"

# Check if already running
if [ -f "$PIDFILE" ]; then
    PID=$(cat "$PIDFILE")
    if kill -0 "$PID" 2>/dev/null; then
        echo "Error: mouse-jiggle is already running (PID: $PID)"
        exit 1
    else
        # Stale PID file, remove it
        rm -f "$PIDFILE"
    fi
fi

# Create PID file
echo $$ > "$PIDFILE"

# Cleanup function
cleanup() {
    rm -f "$PIDFILE"
    exit 0
}

# Set up signal handlers
trap cleanup EXIT INT TERM

# PowerShell path
POWERSHELL="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

# Check if PowerShell is available
if [ ! -f "$POWERSHELL" ]; then
    echo "Error: PowerShell not found at $POWERSHELL"
    exit 1
fi

echo "Starting mouse jiggle (interval: ${INTERVAL}s, press Ctrl+C to stop)"

# Main loop - use single PowerShell command to reduce overhead
while true; do
    $POWERSHELL -WindowStyle Hidden -ExecutionPolicy Bypass -Command "
        Add-Type -AssemblyName System.Windows.Forms
        \$pos = [System.Windows.Forms.Cursor]::Position
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(\$pos.X, (\$pos.Y + 1))
        Start-Sleep -Milliseconds 100
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point(\$pos.X, \$pos.Y)
    " > /dev/null 2>&1
    
    # Wait for the specified interval
    sleep "$INTERVAL"
done
