#!/bin/bash

# Get the path to the Nix-managed zsh dynamically
NIX_ZSH="$HOME/.nix-profile/bin/zsh"

# Check if the Nix-managed zsh exists
if [ ! -f "$NIX_ZSH" ]; then
    echo "Error: Nix-managed zsh not found at $NIX_ZSH"
    exit 1
fi

# Check if the Nix-managed zsh is already in /etc/shells
if ! grep -q "$NIX_ZSH" /etc/shells; then
    echo "Adding Nix-managed zsh to /etc/shells..."
    echo "$NIX_ZSH" | sudo tee -a /etc/shells
else
    echo "Nix-managed zsh is already in /etc/shells."
fi

# Change the login shell to the Nix-managed zsh
if [ "$SHELL" != "$NIX_ZSH" ]; then
    echo "Changing login shell to Nix-managed zsh..."
    chsh -s "$NIX_ZSH"
else
    echo "Login shell is already set to Nix-managed zsh."
fi

echo "Setup complete. Please log out and log back in for changes to take effect."
