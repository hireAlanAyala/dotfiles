#!/bin/bash

# Dotfiles Nix + Home Manager Installation Script
# Based on manual installation notes

set -euo pipefail

echo "🚀 Starting Nix + Home Manager installation..."
echo "This script will install Nix and set up your development environment."
echo ""

# Check if we're on the right system
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ This script is designed for Linux systems"
    exit 1
fi

# Backup existing shell configs
echo "=== Backing up existing shell configs ==="
[ -f ~/.profile ] && mv ~/.profile ~/.profile.backup && echo "✅ Backed up ~/.profile"
[ -f ~/.bashrc ] && mv ~/.bashrc ~/.bashrc.backup && echo "✅ Backed up ~/.bashrc"

# Install Nix (multi-user)
echo ""
echo "=== Installing Nix (multi-user) ==="
echo "This will require sudo access..."

if ! command -v nix &> /dev/null; then
    curl -L https://nixos.org/nix/install | sh -s -- --daemon --yes
    echo "✅ Nix installed successfully"
else
    echo "✅ Nix already installed"
fi

# Source Nix environment
echo ""
echo "=== Setting up Nix environment ==="
if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then
    . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
    echo "✅ Nix environment sourced"
else
    echo "⚠️  Nix daemon profile not found, you may need to restart your shell"
fi

# Add Nix channels
echo ""
echo "=== Setting up Nix channels ==="
nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
nix-channel --add https://github.com/nix-community/home-manager/archive/master.tar.gz home-manager
nix-channel --update
echo "✅ Nix channels configured"

# Enable flakes and nix-command
echo ""
echo "=== Enabling Nix flakes ==="
mkdir -p ~/.config/nix
echo "experimental-features = nix-command flakes" > ~/.config/nix/nix.conf
echo "✅ Nix flakes enabled"

# Install Home Manager
echo ""
echo "=== Installing Home Manager ==="

# Move any existing home-manager directory out of the way
if [ -d ~/home-manager ]; then
    mv ~/home-manager ~/home-manager.backup.$(date +%s)
    echo "✅ Backed up existing home-manager directory"
fi

# Setup GPG keys before Home Manager (if available)
echo "=== Setting up GPG keys ==="
cd ~/.config
if [ -f ./provision/setup-gpg-ssh.sh ]; then
    # Call without SSH setup (GPG only)
    ./provision/setup-gpg-ssh.sh || echo "GPG setup completed with some warnings"
else
    echo "⚠️  GPG setup script not found, continuing without GPG setup"
fi

# Install Home Manager using dedicated script
echo "=== Installing Home Manager ==="
./setup-home-manager.sh

# Source home-manager environment
if [ -f ~/.nix-profile/etc/profile.d/hm-session-vars.sh ]; then
    . ~/.nix-profile/etc/profile.d/hm-session-vars.sh
    echo "✅ Home Manager environment sourced"
fi

# Setup SSH keys after Home Manager (if script exists)
echo ""
echo "=== Setting up SSH keys ==="
if [ -f ~/.ssh/setup_all_ssh_keys.sh ]; then
    ~/.ssh/setup_all_ssh_keys.sh --all || echo "SSH key setup completed with some warnings"
else
    echo "⚠️  SSH setup script not found, skipping SSH key setup"
fi

# Show what's installed
echo ""
echo "=== Installation Summary ==="
echo "Development tools installed:"

command -v git >/dev/null && echo "  ✅ git: $(git --version)"
command -v go >/dev/null && echo "  ✅ go: $(go version)"  
command -v node >/dev/null && echo "  ✅ node: $(node --version)"
command -v python3 >/dev/null && echo "  ✅ python3: $(python3 --version)"
command -v docker >/dev/null && echo "  ✅ docker: $(docker --version)"
command -v nvim >/dev/null && echo "  ✅ neovim: $(nvim --version | head -1)"

echo ""
echo "🎉 Installation complete!"
echo ""
echo "📝 Next steps:"
echo "1. Restart your shell or run: source ~/.bashrc"
echo "2. Optional: Set up GPG keys for encrypted configs"
echo "3. Optional: Run SSH key setup: ~/.ssh/setup_all_ssh_keys.sh --all"
echo ""
echo "To update your configuration in the future:"
echo "  cd ~/.config && git pull && home-manager switch --flake .#developer"
echo ""