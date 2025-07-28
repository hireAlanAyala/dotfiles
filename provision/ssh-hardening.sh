#!/bin/bash
set -euo pipefail

# SSH Hardening Script for Linode VPS
# This script hardens SSH configuration by changing port and disabling insecure options

# Configuration
SSH_PORT="${SSH_PORT:-2222}"
USERNAME="${USERNAME:-developer}"

echo "=== Starting SSH hardening ==="

# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Test current SSH config
sshd -t || echo "Initial SSH config has issues"

# Change SSH port
if grep -q "^#Port 22" /etc/ssh/sshd_config; then
    sed -i "s/^#Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
elif grep -q "^Port 22" /etc/ssh/sshd_config; then
    sed -i "s/^Port 22/Port $SSH_PORT/" /etc/ssh/sshd_config
else
    echo "Port $SSH_PORT" >> /etc/ssh/sshd_config
fi

# Disable password authentication
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config

# Disable root login
sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config

# Test the new configuration
echo "Testing SSH configuration..."
if ! sshd -t; then
    echo "SSH configuration test failed! Restoring backup..."
    cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
    exit 1
fi

# Configure firewall BEFORE restarting SSH
echo "=== Configuring firewall ==="
ufw --force enable
ufw default deny incoming
ufw default allow outgoing  
ufw allow 22/tcp comment 'SSH on default port (temporary)'
ufw allow $SSH_PORT/tcp comment 'SSH on custom port'

# Restart SSH service
echo "=== Restarting SSH service ==="
# Try both service names (Arch might use either)
if systemctl is-active sshd &>/dev/null; then
    systemctl restart sshd || {
        echo "SSH restart failed! Checking status..."
        systemctl status sshd
        journalctl -xeu sshd.service | tail -20
        exit 1
    }
else
    systemctl restart ssh || {
        echo "SSH restart failed! Checking status..."
        systemctl status ssh
        journalctl -xeu ssh.service | tail -20
        exit 1
    }
fi

# Remove temporary port 22 access now that SSH is on custom port
echo "=== Removing temporary port 22 access ==="
ufw delete allow 22/tcp
ufw status verbose

echo "✅ SSH hardening completed successfully"
echo "SSH is now running on port $SSH_PORT with password authentication disabled"