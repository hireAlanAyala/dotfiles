#!/bin/bash

# Setup GPG and SSH keys on the VPS
# Usage: ./setup-gpg-ssh.sh [GPG_KEY_FILE]

set -euo pipefail

GPG_KEY_FILE="${1:-}"

echo "=== Setting up GPG and SSH keys ==="

# Import GPG key if provided
if [ -n "$GPG_KEY_FILE" ] && [ -f "$GPG_KEY_FILE" ]; then
    echo "=== Setting up GPG ==="
    
    # Set up GPG environment for non-interactive use
    export GPG_TTY=$(tty) 2>/dev/null || export GPG_TTY=""
    export GNUPGHOME="$HOME/.gnupg"
    
    # Create GPG directory with proper permissions
    mkdir -p "$GNUPGHOME"
    chmod 700 "$GNUPGHOME"
    
    # Import GPG key with batch mode and no TTY
    echo "Importing GPG key..."
    gpg --batch --yes --import "$GPG_KEY_FILE" 2>/dev/null || {
        echo "Standard import failed, trying with pinentry-mode loopback..."
        gpg --batch --yes --pinentry-mode loopback --import "$GPG_KEY_FILE"
    }
    
    rm -f "$GPG_KEY_FILE"
    
    # Trust the key automatically
    KEY_ID=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep sec | awk '{print $2}' | cut -d'/' -f2 | head -1)
    if [ -n "$KEY_ID" ]; then
        echo "Trusting GPG key: $KEY_ID"
        echo "${KEY_ID}:6:" | gpg --batch --yes --import-ownertrust
        echo "✅ GPG key imported and trusted"
    else
        echo "⚠️ GPG key imported but could not auto-trust"
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