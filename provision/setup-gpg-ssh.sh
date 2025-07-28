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
    
    # Trust the key automatically using fingerprint
    FINGERPRINT=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep fpr | cut -d: -f10 | head -1)
    if [ -n "$FINGERPRINT" ]; then
        echo "Trusting GPG key with fingerprint: $FINGERPRINT"
        echo "${FINGERPRINT}:6:" | gpg --batch --yes --import-ownertrust
        echo "✅ GPG key imported and trusted"
    else
        # Fallback: try with ultimate trust without fingerprint verification
        echo "Could not get fingerprint, setting ultimate trust for all imported keys..."
        gpg --list-secret-keys --with-colons 2>/dev/null | grep sec | cut -d: -f5 | while read keyid; do
            echo "$keyid:6:" | gpg --batch --yes --import-ownertrust 2>/dev/null || true
        done
        echo "✅ GPG key imported with fallback trust method"
    fi
else
    echo "No GPG key file provided or file not found, skipping GPG setup"
fi

echo "✅ GPG setup complete"