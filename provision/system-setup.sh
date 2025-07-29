#!/bin/bash
set -euo pipefail

# System Setup Script for Linode VPS
# This script performs initial system configuration including packages, user creation, and swap

# Configuration
USERNAME="${USERNAME:-developer}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
ESSENTIAL_PACKAGES="${ESSENTIAL_PACKAGES:-sudo ufw git curl xz age sops gnupg}"
SWAP_SIZE="${SWAP_SIZE:-4G}"

echo "=== Starting system configuration at $(date) ==="

# Enable parallel downloads for faster package installation
sed -i 's/^#ParallelDownloads.*/ParallelDownloads = 5/' /etc/pacman.conf

# Skip full system update, just sync package database
echo "Syncing package database..."
time pacman -Sy --noconfirm

# Install essential packages first
echo "Installing essential packages..."
time pacman -S --noconfirm $ESSENTIAL_PACKAGES

# Create non-root user
if ! id "$USERNAME" &>/dev/null; then
    useradd -m -s /bin/bash -G wheel "$USERNAME"
    if [ -n "$ROOT_PASSWORD" ]; then
        echo "$USERNAME:$ROOT_PASSWORD" | chpasswd
    fi
fi

# Swap configuration removed for simplicity

# Configure sudo
echo "%wheel ALL=(ALL) ALL" > /etc/sudoers.d/wheel
chmod 440 /etc/sudoers.d/wheel

# Copy SSH keys to new user
if [ -f /root/.ssh/authorized_keys ]; then
    mkdir -p "/home/$USERNAME/.ssh"
    cp /root/.ssh/authorized_keys "/home/$USERNAME/.ssh/"
    chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
    chmod 700 "/home/$USERNAME/.ssh"
    chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
fi

echo "✅ System setup completed successfully"