#!/usr/bin/env bash

# Define some color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Check if SOPS is available
if ! command -v sops &> /dev/null; then
    echo -e "${RED}Error: SOPS is not installed or not in PATH${RESET}"
    exit 1
fi

# Function to process a single SSH key in batch mode
setup_ssh_key_batch() {
    local key_name="$1"
    
    # Set the paths
    local private_key_path="$HOME/.ssh/$key_name"
    local public_key_path="$HOME/.ssh/$key_name.pub"
    local sops_key_name="ssh_private_key_$key_name"

    # Skip if key already exists (batch mode - no prompts)
    if [[ -f "$private_key_path" ]]; then
        echo -e "${BLUE}Skipping existing key: $key_name${RESET}"
        return 0
    fi

    # Extract private key from SOPS
    echo -e "${BLUE}Extracting private key from SOPS...${RESET}"
    if ! sops -d ~/.config/secrets.yaml | yq -r ".$sops_key_name" > "$private_key_path"; then
        echo -e "${RED}Error: Could not extract key '$sops_key_name' from SOPS${RESET}"
        return 1
    fi

    # Set correct permissions on private key
    chmod 600 "$private_key_path" || { echo -e "${RED}Error setting private key permissions${RESET}"; return 1; }
    echo -e "${GREEN}Private key extracted and secured at $private_key_path${RESET}"

    # Generate public key from private key
    echo -e "${BLUE}Generating public key...${RESET}"
    if ! ssh-keygen -y -f "$private_key_path" > "$public_key_path"; then
        echo -e "${RED}Error generating public key${RESET}"
        rm -f "$private_key_path"
        return 1
    fi
    echo -e "${GREEN}Public key generated at $public_key_path${RESET}"

    # Add key to ssh-agent
    if ssh-add "$private_key_path" 2>/dev/null; then
        echo -e "${GREEN}SSH key added to ssh-agent${RESET}"
    else
        echo -e "${YELLOW}Warning: Could not add key to ssh-agent (agent may not be running)${RESET}"
    fi

    echo -e "${GREEN}✓ SSH key setup complete for $key_name!${RESET}"
    return 0
}

# Main script logic
echo -e "${BLUE}Setting up all SSH keys from SOPS...${RESET}"

# Get list of all SSH keys from SOPS
keys=($(sops -d ~/.config/secrets.yaml | grep "ssh_private_key_" | sed 's/ssh_private_key_//' | sed 's/:.*//' | tr '\n' ' '))

if [[ ${#keys[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No SSH keys found in SOPS${RESET}"
    exit 0
fi

echo -e "${BLUE}Found ${#keys[@]} SSH key(s):${RESET}"
for key in "${keys[@]}"; do
    echo "  - $key"
done
echo ""

# Process each key
success_count=0
error_count=0

for key in "${keys[@]}"; do
    echo -e "${YELLOW}=== Processing key: $key ===${RESET}"
    if setup_ssh_key_batch "$key"; then
        ((success_count++))
    else
        ((error_count++))
    fi
    echo ""
done

# Summary
echo -e "${GREEN}=== SUMMARY ===${RESET}"
echo -e "${GREEN}✓ Successfully processed: $success_count keys${RESET}"
if [[ $error_count -gt 0 ]]; then
    echo -e "${RED}✗ Failed to process: $error_count keys${RESET}"
fi

# List all SSH keys that are now available
echo -e "\n${BLUE}SSH keys now available:${RESET}"
ls -1 ~/.ssh/*.pub 2>/dev/null | sed 's|.*/||; s|\.pub$||' | while read key; do
    echo "  - $key"
done

echo -e "\n${GREEN}✓ All SSH keys processing complete!${RESET}"