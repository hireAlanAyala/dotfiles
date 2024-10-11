#!/usr/bin/env bash

# Define some color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
RESET="\033[0m"

# Prompt for the key name and email
read -p "Enter the name for the SSH key (no spaces, example: linode_image_processor): " key_name
read -p "Enter your email for the SSH key: " key_email

# Set the paths for temporary storage
private_key_path="/tmp/ssh_private_key_$key_name"
public_key_path="$private_key_path.pub"  # Corrected reference to the public key path

# Generate the SSH key pair
ssh-keygen -t rsa -b 4096 -C "$key_email" -f "$private_key_path" -N "" || { echo -e "${RED}Error generating SSH key${RESET}"; exit 1; }
echo "\n"

# Copy the private key to the clipboard
if command -v pbcopy &> /dev/null; then
    # macOS
    cat "$private_key_path" | pbcopy
    echo -e "${GREEN}Private key copied to clipboard (macOS).${RESET}"
elif command -v xclip &> /dev/null; then
    # Linux (xclip)
    cat "$private_key_path" | xclip -selection clipboard
    echo -e "${GREEN}Private key copied to clipboard (Linux with xclip).${RESET}"
elif command -v wl-copy &> /dev/null; then
    # Linux (Wayland wl-copy)
    cat "$private_key_path" | wl-copy
    echo -e "${GREEN}Private key copied to clipboard (Linux with wl-copy).${RESET}"
else
    echo -e "${RED}Error: No clipboard utility found. Please install pbcopy (macOS), xclip (Linux X11), or wl-copy (Wayland).${RESET}"
    rm "$private_key_path" "$public_key_path"
    exit 1
fi

# Echo the steps to manually add the key to your SOPS secrets.yaml
echo "\n"
echo -e "${YELLOW}Add the private key to your SOPS secrets.yaml:${RESET}"
echo "--------------------------------------------------"
echo -e "${YELLOW}1. Run: sops ~/.config/secrets.yaml${RESET}"
echo -e "${YELLOW}2. Add the following entry (replace '{private key from clipboard}' with the actual private key):${RESET}"
echo -e "${YELLOW}ssh_private_key_name_${key_name}: |${RESET}"
echo -e "${YELLOW}{private key from clipboard}${RESET}"
echo "\n"

# Echo the public key to add to ~/.config/.ssh
echo -e "${YELLOW}The public key has been saved at: $public_key_path${RESET}"
echo ""
echo -e "${YELLOW}Add the public key to ~/.config/.ssh/config:${RESET}"
echo "------------------------------------------------"
echo -e "${YELLOW}Host $key_name${RESET}"
echo -e "${YELLOW}  HostName example.com${RESET}"      # Adjust this as needed
echo -e "${YELLOW}  User example_user${RESET}"
echo -e "${YELLOW}  IdentityFile ~/.config/.ssh/$key_name${RESET}"
echo -e "${YELLOW}  IdentityOnly yes #must always include this${RESET}"
echo "\n"

#TODO:
# add the private key to ~/.ssh with a chmod of 600. DO NOT ADD KEY TO .config/.ssh

# Clean up: Keep the public key in /tmp but remove the private key after use
rm "$private_key_path"
mv "$public_key_path" "$HOME/.config/.ssh/$key_name.pub" || { echo -e "${RED}Error moving the public key to ~/.config/.ssh/$key_name.pub${RESET}"; exit 1; }
echo -e "${GREEN}Public key moved to $HOME/.config/.ssh/$key_name.pub${RESET}"

