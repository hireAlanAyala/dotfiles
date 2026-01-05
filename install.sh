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

# Setup 1Password daemon early (before Nix) for secret access
echo ""
echo "=== Setting up 1Password CLI daemon ==="
echo "This provides secure access to secrets during installation..."
if [ -f ./provision/setup-onepass-daemon.sh ]; then
    sudo ./provision/setup-onepass-daemon.sh
    echo "✅ 1Password daemon setup complete"
    
    # Source helper functions for use during install
    source /opt/onepass/client.sh
    source ./provision/onepass-helpers.sh
    
    echo ""
    echo "🔐 1Password daemon is ready for use during installation"
    echo "   You can now use: op_interactive_signin, op_safe_get_password, etc."
    echo "   Example: API_KEY=\$(op_safe_get_password 'My API Key')"
    echo ""
else
    echo "⚠️  1Password daemon setup script not found, continuing without 1Password"
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

# Setup SSH keys after Home Manager
echo ""
echo "=== Setting up SSH keys ==="
~/.ssh/setup_all_ssh_keys.sh --all || echo "SSH key setup completed with some warnings"

# Setup zsh as default shell
echo ""
echo "=== Setting up zsh as default shell ==="
if command -v zsh >/dev/null; then
    ZSH_PATH=$(which zsh)
    
    # Add zsh to /etc/shells if not already there
    if ! grep -q "$ZSH_PATH" /etc/shells 2>/dev/null; then
        echo "Adding $ZSH_PATH to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells
    fi
    
    # Change default shell to zsh
    if [ "$SHELL" != "$ZSH_PATH" ]; then
        echo "Changing default shell to zsh..."
        chsh -s "$ZSH_PATH"
        echo "✅ Default shell changed to zsh"
    else
        echo "✅ Default shell is already zsh"
    fi
else
    echo "⚠️  zsh not found, skipping shell setup"
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
echo "1. IMPORTANT: Log out and log back in (or restart your terminal) for:"
echo "   - zsh to become default shell"
echo "   - 'onepass' group membership to take effect"
echo "2. Or manually switch now:"
echo "   source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && newgrp onepass && zsh"
echo "3. Optional: Set up GPG keys for encrypted configs"
echo "4. Optional: Run SSH key setup: ~/.ssh/setup_all_ssh_keys.sh --all"
echo ""
echo "🔐 1Password daemon is installed and running:"
echo "  - Access via: source /opt/onepass/client.sh && source ~/.config/provision/onepass-helpers.sh" 
echo "  - Sign in: op_interactive_signin"
echo "  - Health check: op_health_check"
echo "  - Help: op_help"
echo ""
echo "To update your configuration in the future:"
echo "  cd ~/.config && git pull && home-manager switch --flake .#walker"
echo ""