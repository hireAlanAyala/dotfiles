#!/bin/bash

# Home Manager setup script (assumes Nix is already installed)

set -euo pipefail

echo "🏠 Setting up Home Manager configuration..."

# Source Nix environment if needed
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    echo "✅ Nix environment sourced"
fi

# Enable flakes if not already enabled
echo "=== Enabling Nix flakes ==="
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
echo "✅ Nix flakes enabled"

# Go to the home-manager directory
cd ~/.config/home-manager

# Update flake inputs
echo "=== Updating flake inputs ==="
nix flake update
echo "✅ Flake inputs updated"

# Apply Home Manager configuration using flakes
echo "=== Applying Home Manager configuration ==="
nix run home-manager/master -- switch --flake .#developer -b backup
echo "✅ Home Manager configuration applied"

# Source home-manager environment
if [ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
    . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    echo "✅ Home Manager environment sourced"
fi

echo ""
echo "🎉 Home Manager setup complete!"
echo ""
echo "📝 To update your configuration in the future:"
echo "  cd ~/.config && git pull && home-manager switch --flake .#developer"
echo ""