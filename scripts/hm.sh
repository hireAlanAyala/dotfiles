#!/bin/bash
# Home Manager update script - Bash version

echo "Current login shell: $(getent passwd $(whoami) | cut -d: -f7)"
cd ~/.config || exit 1
git add .
home-manager switch --flake "./home-manager#walker"

if [ $? -eq 0 ]; then
    # Only source .zshrc if we're actually in zsh
    if [[ "$SHELL" == *"zsh"* ]] && [[ -n "$ZSH_VERSION" ]]; then
        source ~/.zshrc
    fi
    echo -e "✅ Home Manager updated successfully!"
    
else
    echo -e "❌ Home Manager switch failed"
    exit 1
fi

cd - > /dev/null
echo -e "Remember to ensure all relevant files are whitelisted in ~/.config/ .gitignore!"
