#!/bin/bash
# Home Manager update script - Bash version

echo "Current login shell: $(getent passwd $(whoami) | cut -d: -f7)"
cd ~/.config || exit 1
git add .
home-manager switch --flake "./home-manager#alan"

if [ $? -eq 0 ]; then
    # Only source .zshrc if we're actually in zsh
    if [[ "$SHELL" == *"zsh"* ]] && [[ -n "$ZSH_VERSION" ]]; then
        source ~/.zshrc
    fi
    echo -e "✅ Home Manager updated successfully!"
    
    # Sync Windows configurations
    echo "Syncing Windows configurations..."
    if bash ~/.config/scripts/sync-windows-configs.sh --all; then
        echo "✅ Windows configurations synced successfully!"
    else
        echo "⚠️  Some Windows configurations failed to sync"
    fi
    
    # Install fonts to Windows
    echo "Installing fonts to Windows..."
    if bash ~/.config/scripts/install-fonts-to-windows.sh; then
        echo "✅ Fonts installed to Windows successfully!"
    else
        echo "⚠️  Font installation failed or required manual intervention"
    fi
    
    # Start mouse-jiggle script
    echo "Starting mouse-jiggle script..."
    if bash ~/.config/scripts/mouse-jiggle.sh > /dev/null 2>&1 &; then
        echo "✅ Mouse-jiggle script started in background!"
    else
        echo "⚠️  Failed to start mouse-jiggle script"
    fi
else
    echo -e "❌ Home Manager switch failed"
    exit 1
fi

cd - > /dev/null
echo -e "Remember to ensure all relevant files are whitelisted in ~/.config/ .gitignore!"
