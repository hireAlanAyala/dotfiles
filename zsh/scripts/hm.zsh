#!/usr/bin/env zsh

cd ~/.config || exit 1
git add .
home-manager switch --flake "./home-manager#alan"
if [[ $? -eq 0 ]]; then
    source ~/.zshrc
    echo -e "${YELLOW_ORANGE}✅ Home Manager updated successfully!${RESET}"
else
    echo -e "${RED}❌ Home Manager switch failed${RESET}"
    exit 1
fi
cd -
echo -e "${YELLOW_ORANGE}Remember to ensure all relevant files are whitelisted in ~/.config/ .gitignore!${RESET}"
