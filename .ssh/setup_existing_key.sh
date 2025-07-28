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
process_key() {
    local key_name="$1"
    
    # Set the paths
    local private_key_path="$HOME/.ssh/$key_name"
    local public_key_path="$HOME/.ssh/$key_name.pub"
    local sops_key_name="ssh_private_key_$key_name"

    # Check if key already exists locally
    if [[ -f "$private_key_path" ]]; then
        echo -e "${YELLOW}Warning: SSH key $key_name already exists at $private_key_path${RESET}"
        if [[ "$2" != "batch" ]]; then
            read -p "Do you want to overwrite it? (y/N): " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}Skipping $key_name${RESET}"
                return 0
            fi
        else
            echo -e "${BLUE}Skipping existing key: $key_name${RESET}"
            return 0
        fi
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

    # Display public key for server installation (only for single key mode)
    if [[ "$2" != "batch" ]]; then
        echo -e "\n${YELLOW}=== PUBLIC KEY FOR SERVER ===${RESET}"
        echo -e "${YELLOW}To install on server, run:${RESET}"
        echo -e "${YELLOW}ssh-copy-id -i ~/.ssh/$key_name $key_name${RESET}"
        echo -e "${YELLOW}Or manually add this public key to server's ~/.ssh/authorized_keys:${RESET}"
        cat "$public_key_path"
    fi

    echo -e "${GREEN}✓ SSH key setup complete for $key_name!${RESET}"
}

# Prompt for the key name or all keys
echo -e "${BLUE}Setting up existing SSH key from SOPS...${RESET}"
list_sops_keys
echo ""
read -p "Enter the key name (without ssh_private_key_ prefix) or 'all' for all keys: " key_name

# Validate input
if [[ -z "$key_name" ]]; then
    echo -e "${RED}Error: Key name is required${RESET}"
    exit 1
fi

# If user wants all keys, get the list and process each one
if [[ "$key_name" == "all" ]]; then
    echo -e "${BLUE}Processing all SSH keys...${RESET}"
    keys=($(sops -d ~/.config/secrets.yaml | grep "ssh_private_key_" | sed 's/ssh_private_key_//' | sed 's/:.*//' | tr '\n' ' '))
    
    for key in "${keys[@]}"; do
        echo -e "\n${YELLOW}=== Processing key: $key ===${RESET}"
        process_key "$key" "batch"
    done
    echo -e "\n${GREEN}✓ All SSH keys processed!${RESET}"
    exit 0
fi

process_key() {
    local key_name="$1"
    
    # Set the paths
    local private_key_path="$HOME/.ssh/$key_name"
    local public_key_path="$HOME/.ssh/$key_name.pub"
    local sops_key_name="ssh_private_key_$key_name"

    # Check if key already exists locally
    if [[ -f "$private_key_path" ]]; then
        echo -e "${YELLOW}Warning: SSH key $key_name already exists at $private_key_path${RESET}"
        if [[ "$2" != "batch" ]]; then
            read -p "Do you want to overwrite it? (y/N): " overwrite
            if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
                echo -e "${BLUE}Skipping $key_name${RESET}"
                return 0
            fi
        else
            echo -e "${BLUE}Skipping existing key: $key_name${RESET}"
            return 0
        fi
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

    # Display public key for server installation (only for single key mode)
    if [[ "$2" != "batch" ]]; then
        echo -e "\n${YELLOW}=== PUBLIC KEY FOR SERVER ===${RESET}"
        echo -e "${YELLOW}To install on server, run:${RESET}"
        echo -e "${YELLOW}ssh-copy-id -i ~/.ssh/$key_name $key_name${RESET}"
        echo -e "${YELLOW}Or manually add this public key to server's ~/.ssh/authorized_keys:${RESET}"
        cat "$public_key_path"
    fi

    echo -e "${GREEN}✓ SSH key setup complete for $key_name!${RESET}"
}

# Process single key if not "all"
process_key "$key_name"