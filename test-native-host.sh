#!/bin/bash

# This script simulates what Windows Chrome would execute via wsl.exe

echo "=== Testing Native Messaging Host Connection ==="
echo "Date: $(date)"
echo "User: $(whoami)"
echo "Working Directory: $(pwd)"
echo ""

# Test 1: Check if we can access the script
echo "Test 1: Checking script accessibility"
SCRIPT_PATH="$HOME/.npm-global/lib/node_modules/mcp-chrome-bridge/dist/run_host.sh"
if [ -f "$SCRIPT_PATH" ]; then
    echo "✓ Script exists at: $SCRIPT_PATH"
    if [ -x "$SCRIPT_PATH" ]; then
        echo "✓ Script is executable"
    else
        echo "✗ Script is NOT executable"
    fi
else
    echo "✗ Script NOT found at: $SCRIPT_PATH"
fi
echo ""

# Test 2: Check Node.js availability
echo "Test 2: Checking Node.js"
NODE_PATH="/nix/store/lz7iav1hd92jbv44zf2rdd7b2mj23536-nodejs-20.19.3/bin/node"
if [ -x "$NODE_PATH" ]; then
    echo "✓ Node.js found at: $NODE_PATH"
    echo "  Version: $($NODE_PATH -v)"
else
    echo "✗ Node.js NOT found at expected path"
    # Try to find it
    if command -v node &>/dev/null; then
        echo "  Alternative found at: $(command -v node)"
        echo "  Version: $(node -v)"
    fi
fi
echo ""

# Test 3: Simulate the exact command Chrome would use
echo "Test 3: Simulating Chrome's command"
echo "Command: bash -c \"cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && ./run_host.sh\""
echo ""

# Test 4: Check for any permission issues with WSL
echo "Test 4: WSL Environment Check"
echo "HOME: $HOME"
echo "PATH: $PATH"
echo "WSL_DISTRO_NAME: $WSL_DISTRO_NAME"
echo "WSL_INTEROP: $WSL_INTEROP"
echo ""

# Test 5: Try to execute the script with a test message
echo "Test 5: Testing script execution (will timeout after 2 seconds)"
echo "Sending test message..."
# Native messaging uses length-prefixed JSON messages
# Format: 4-byte length (little-endian) + JSON message
TEST_MESSAGE='{"type":"test","data":"Hello from test script"}'
MESSAGE_LENGTH=${#TEST_MESSAGE}

# Create a test input with proper native messaging format
(
    # Send length as 4 bytes (little-endian)
    printf '\x%02x\x00\x00\x00' $MESSAGE_LENGTH
    # Send the JSON message
    printf '%s' "$TEST_MESSAGE"
) | timeout 2s bash -c "cd ~/.npm-global/lib/node_modules/mcp-chrome-bridge/dist && ./run_host.sh" 2>&1 || true

echo ""
echo "=== Test Complete ==="