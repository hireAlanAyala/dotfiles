#!/bin/bash

# Set the login shell to the system zsh.
ZSH_PATH="$(command -v zsh || echo /usr/bin/zsh)"

if [ ! -x "$ZSH_PATH" ]; then
    echo "Error: zsh not found (install it first)"
    exit 1
fi

# Ensure zsh is listed in /etc/shells
if ! grep -qx "$ZSH_PATH" /etc/shells 2>/dev/null; then
    echo "Adding $ZSH_PATH to /etc/shells..."
    echo "$ZSH_PATH" | sudo tee -a /etc/shells
else
    echo "$ZSH_PATH is already in /etc/shells."
fi

# Change the login shell to zsh
if [ "$SHELL" != "$ZSH_PATH" ]; then
    echo "Changing login shell to $ZSH_PATH..."
    chsh -s "$ZSH_PATH"
else
    echo "Login shell is already $ZSH_PATH."
fi

echo "Setup complete. Log out and back in for changes to take effect."
