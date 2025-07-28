#!/bin/bash

# Setup GPG and SSH keys on the VPS
# Usage: ./setup-gpg-ssh.sh [GPG_KEY_FILE]

set -euo pipefail

GPG_KEY_FILE="${1:-}"

echo "=== Setting up GPG and SSH keys ==="

# Import GPG key if provided
if [ -n "$GPG_KEY_FILE" ] && [ -f "$GPG_KEY_FILE" ]; then
    echo "=== Setting up GPG ==="
    # Import GPG key
    gpg --import "$GPG_KEY_FILE"
    rm -f "$GPG_KEY_FILE"
    
    # Trust the key
    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG | grep sec | awk '{print $2}' | cut -d'/' -f2 | head -1)
    if [ -n "$KEY_ID" ]; then
        echo "${KEY_ID}:6:" | gpg --import-ownertrust
        echo "✅ GPG key imported and trusted"
    fi
else
    echo "No GPG key file provided or file not found, skipping GPG setup"
fi

# Run SSH key setup if the script exists
if [ -f ~/.ssh/setup_all_ssh_keys.sh ]; then
    echo "=== Setting up SSH keys ==="
    export GPG_TTY=$(tty)
    ~/.ssh/setup_all_ssh_keys.sh --all || echo "SSH key setup completed with some errors"
else
    echo "No SSH setup script found, skipping"
fi

echo "✅ GPG and SSH setup complete"