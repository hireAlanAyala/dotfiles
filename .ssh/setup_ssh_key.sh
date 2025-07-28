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

# Function to list available SSH keys in SOPS
list_sops_keys() {
    echo -e "${BLUE}Available SSH keys in SOPS:${RESET}"
    sops -d ~/.config/secrets.yaml | grep "ssh_private_key_" | sed 's/ssh_private_key_//' | sed 's/:.*//' | while read key; do
        echo "  - $key"
    done
}

# Function to process a single SSH key
setup_ssh_key() {
    local key_name="$1"
    
    # Set the paths
    local private_key_path="$HOME/.ssh/$key_name"
    local public_key_path="$HOME/.ssh/$key_name.pub"
    local sops_key_name="ssh_private_key_$key_name"

    # Check if key already exists locally
    if [[ -f "$private_key_path" ]]; then
        echo -e "${YELLOW}Warning: SSH key $key_name already exists at $private_key_path${RESET}"
        read -p "Do you want to overwrite it? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            echo -e "${BLUE}Operation cancelled${RESET}"
            exit 0
        fi
    fi

    # Extract private key from SOPS
    echo -e "${BLUE}Extracting private key from SOPS...${RESET}"
    if ! sops -d ~/.config/secrets.yaml | yq -r ".$sops_key_name" > "$private_key_path"; then
        echo -e "${RED}Error: Could not extract key '$sops_key_name' from SOPS${RESET}"
        exit 1
    fi

    # Set correct permissions on private key
    chmod 600 "$private_key_path" || { echo -e "${RED}Error setting private key permissions${RESET}"; exit 1; }
    echo -e "${GREEN}Private key extracted and secured at $private_key_path${RESET}"

    # Generate public key from private key
    echo -e "${BLUE}Generating public key...${RESET}"
    if ! ssh-keygen -y -f "$private_key_path" > "$public_key_path"; then
        echo -e "${RED}Error generating public key${RESET}"
        rm -f "$private_key_path"
        exit 1
    fi
    echo -e "${GREEN}Public key generated at $public_key_path${RESET}"

    # Add key to ssh-agent
    if ssh-add "$private_key_path" 2>/dev/null; then
        echo -e "${GREEN}SSH key added to ssh-agent${RESET}"
    else
        echo -e "${YELLOW}Warning: Could not add key to ssh-agent (agent may not be running)${RESET}"
    fi

    # Display public key for server installation
    echo -e "\n${YELLOW}=== PUBLIC KEY FOR SERVER ===${RESET}"
    echo -e "${YELLOW}To install on server, run:${RESET}"
    echo -e "${YELLOW}ssh-copy-id -i ~/.ssh/$key_name $key_name${RESET}"
    echo -e "${YELLOW}Or manually add this public key to server's ~/.ssh/authorized_keys:${RESET}"
    cat "$public_key_path"

    echo -e "\n${GREEN}✓ SSH key setup complete!${RESET}"
    echo -e "${GREEN}✓ Private key: $private_key_path${RESET}"
    echo -e "${GREEN}✓ Public key: $public_key_path${RESET}"
    echo -e "${GREEN}✓ Key added to ssh-agent${RESET}"
}

# Main script logic
echo -e "${BLUE}Setting up existing SSH key from SOPS...${RESET}"
list_sops_keys
echo ""

# Check if key name was provided as argument
if [[ -n "$1" ]]; then
    key_name="$1"
else
    read -p "Enter the key name (without ssh_private_key_ prefix): " key_name
fi

# Validate input
if [[ -z "$key_name" ]]; then
    echo -e "${RED}Error: Key name is required${RESET}"
    exit 1
fi

# Process the key
setup_ssh_key "$key_name"