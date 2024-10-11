#!/usr/bin/env bash

# Check if ~/.ssh already exists and back it up if it does
if [ -e "$HOME/.ssh" ]; then
    mv "$HOME/.ssh" "$HOME/.ssh.nix-backup"
    echo "Backed up existing .ssh to .ssh.nix-backup"
fi

# Create symlink from ~/.config/.ssh to ~/.ssh
ln -s "$HOME/.config/.ssh" "$HOME/.ssh"
echo "Symlink created: $HOME/.ssh -> $HOME/.config/.ssh"

