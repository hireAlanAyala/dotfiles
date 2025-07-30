#!/bin/bash
set -euo pipefail

# SSH Finalization Script for Linode VPS
# This script completes SSH hardening by disabling root login after user access is verified

# Configuration
USERNAME="${USERNAME:-developer}"
SSH_PORT="${SSH_PORT:-2222}"

echo "=== Finalizing SSH security configuration ==="

# Verify user has SSH access
if [ ! -f "/home/$USERNAME/.ssh/authorized_keys" ]; then
    echo "Error: No authorized_keys found for $USERNAME"
    exit 1
fi

# Check if authorized_keys has content
if [ ! -s "/home/$USERNAME/.ssh/authorized_keys" ]; then
    echo "Error: authorized_keys is empty for $USERNAME"
    exit 1
fi

# Count the number of keys
KEY_COUNT=$(grep -c "^ssh-" "/home/$USERNAME/.ssh/authorized_keys" || true)
echo "Found $KEY_COUNT SSH keys for user $USERNAME"

if [ "$KEY_COUNT" -eq 0 ]; then
    echo "Error: No valid SSH keys found in authorized_keys"
    exit 1
fi

# Backup current config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.finalize-backup

# Now disable root login completely
echo "Disabling root login..."
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Test configuration
echo "Testing SSH configuration..."
if ! sshd -t; then
    echo "SSH configuration test failed! Restoring backup..."
    cp /etc/ssh/sshd_config.finalize-backup /etc/ssh/sshd_config
    exit 1
fi

# Restart SSH service
echo "Restarting SSH service..."
if systemctl is-active sshd &>/dev/null; then
    systemctl restart sshd || {
        echo "SSH restart failed! Restoring backup..."
        cp /etc/ssh/sshd_config.finalize-backup /etc/ssh/sshd_config
        systemctl restart sshd
        exit 1
    }
else
    systemctl restart ssh || {
        echo "SSH restart failed! Restoring backup..."
        cp /etc/ssh/sshd_config.finalize-backup /etc/ssh/sshd_config
        systemctl restart ssh
        exit 1
    }
fi

echo "✅ SSH security finalization completed"
echo "Root login is now completely disabled"
echo "Access is only available via user $USERNAME on port $SSH_PORT"