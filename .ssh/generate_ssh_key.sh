#!/usr/bin/env bash

# Define some color codes
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[0;34m"
RESET="\033[0m"

# Prompt for the key name and email
read -p "Enter the name for the SSH key (no spaces, example: linode_image_processor): " key_name
read -p "Enter your email for the SSH key: " key_email

# Prompt for encryption type
echo -e "\n${BLUE}Select encryption type:${RESET}"
echo "1. Ed25519 (recommended - modern, fast, secure)"
echo "2. RSA (widely compatible, traditional)"
echo "3. ECDSA (elliptic curve, good balance)"
read -p "Select encryption type (1-3, default: 1): " encryption_choice
encryption_choice=${encryption_choice:-1}

# Set encryption parameters based on choice
key_type_flag=""
key_size_flag=""

case "$encryption_choice" in
    1)
        key_type_flag="ed25519"
        echo -e "${GREEN}Using Ed25519 (256-bit security, no size options)${RESET}"
        ;;
    2)
        key_type_flag="rsa"
        echo -e "\n${BLUE}Select RSA key size:${RESET}"
        echo "1. 2048 bits (minimum, faster)"
        echo "2. 3072 bits (good balance)"
        echo "3. 4096 bits (maximum security, recommended)"
        read -p "Select key size (1-3, default: 3): " rsa_size_choice
        rsa_size_choice=${rsa_size_choice:-3}

        case "$rsa_size_choice" in
            1) key_size_flag="2048" ;;
            2) key_size_flag="3072" ;;
            3) key_size_flag="4096" ;;
            *) key_size_flag="4096" ;;
        esac
        echo -e "${GREEN}Using RSA with ${key_size_flag} bits${RESET}"
        ;;
    3)
        key_type_flag="ecdsa"
        echo -e "\n${BLUE}Select ECDSA curve size:${RESET}"
        echo "1. 256 bits (fast, good security)"
        echo "2. 384 bits (better security)"
        echo "3. 521 bits (maximum security)"
        read -p "Select curve size (1-3, default: 1): " ecdsa_size_choice
        ecdsa_size_choice=${ecdsa_size_choice:-1}

        case "$ecdsa_size_choice" in
            1) key_size_flag="256" ;;
            2) key_size_flag="384" ;;
            3) key_size_flag="521" ;;
            *) key_size_flag="256" ;;
        esac
        echo -e "${GREEN}Using ECDSA with ${key_size_flag}-bit curve${RESET}"
        ;;
    *)
        key_type_flag="ed25519"
        echo -e "${GREEN}Using Ed25519 (default)${RESET}"
        ;;
esac

# Save original key name for SSH Host alias, then append encryption type to key_name
host_alias="$key_name"
key_name="${key_name}_${key_type_flag}"

# Determine key type
echo -e "\n${BLUE}Key type:${RESET}"
echo "1. Server/VPS (Linode, DigitalOcean, etc.)"
echo "2. Git service (GitHub, GitLab, Azure DevOps, etc.)"
echo "3. Other service"
read -p "Select key type (1-3): " key_type

hostname=""
username="root"

if [[ "$key_type" == "1" ]]; then
    read -p "Enter hostname (IP or domain): " hostname
    read -p "Enter username (default: root): " username
    username=${username:-root}
elif [[ "$key_type" == "2" ]]; then
    echo -e "${BLUE}Git service detected - SSH config and server installation will be skipped${RESET}"
else
    read -p "Enter hostname (IP or domain, optional): " hostname
    if [[ -n "$hostname" ]]; then
        read -p "Enter username (default: root): " username
        username=${username:-root}
    fi
fi

# Validate inputs
if [[ -z "$key_name" || -z "$key_email" ]]; then
    echo -e "${RED}Error: Key name and email are required${RESET}"
    exit 1
fi

# Validate hostname format if provided
if [[ -n "$hostname" ]]; then
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo -e "${YELLOW}Warning: Hostname format may be invalid${RESET}"
    fi
    # Test if hostname is reachable (optional check)
    if ping -c 1 -W 2 "$hostname" &>/dev/null; then
        echo -e "${GREEN}Hostname $hostname is reachable${RESET}"
    else
        echo -e "${YELLOW}Warning: Hostname $hostname may not be reachable${RESET}"
    fi
fi

# Set the paths for temporary storage
private_key_path="/tmp/ssh_private_key_$key_name"
public_key_path="$private_key_path.pub"
final_private_key_path="$HOME/.config/.ssh/$key_name"
final_public_key_path="$HOME/.config/.ssh/$key_name.pub"

# Check if key already exists
if [[ -f "$final_private_key_path" ]]; then
    echo -e "${YELLOW}Warning: SSH key $key_name already exists at $final_private_key_path${RESET}"
    read -p "Do you want to overwrite it? (y/N): " overwrite
    if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Operation cancelled${RESET}"
        exit 0
    fi
fi

# Generate the SSH key pair
if [[ -n "$key_size_flag" ]]; then
    ssh-keygen -t "$key_type_flag" -b "$key_size_flag" -C "$key_email" -f "$private_key_path" -N "" >/dev/null 2>&1 || { echo -e "${RED}Error generating SSH key${RESET}"; exit 1; }
else
    ssh-keygen -t "$key_type_flag" -C "$key_email" -f "$private_key_path" -N "" >/dev/null 2>&1 || { echo -e "${RED}Error generating SSH key${RESET}"; exit 1; }
fi

# Install keys to ~/.config/.ssh
mkdir -p "$HOME/.config/.ssh"
cp "$private_key_path" "$final_private_key_path" || { echo -e "${RED}Error copying private key${RESET}"; exit 1; }
chmod 600 "$final_private_key_path" || { echo -e "${RED}Error setting permissions${RESET}"; exit 1; }
cp "$public_key_path" "$final_public_key_path" || { echo -e "${RED}Error copying public key${RESET}"; exit 1; }

# Add key to ssh-agent
ssh-add "$final_private_key_path" 2>/dev/null

# Send SOPS entry directly to nvim register (no temp file)
if [[ -n "$NVIM" ]]; then
    # Build SOPS entry: header line + indented private key
    sops_entry="ssh_private_key_$key_name: |"$'\n'"$(sed 's/^/    /' "$private_key_path")"

    # Send to nvim register
    nvim --server "$NVIM" --remote-expr "setreg('+', '$sops_entry')" 2>/dev/null || \
        echo -e "${YELLOW}Warning: Failed to copy SOPS entry to nvim register${RESET}"
fi

# Auto-add SSH config entry (only for servers and other services with hostnames)
if [[ "$key_type" != "2" && -n "$hostname" ]]; then
    ssh_config_entry="
Host $host_alias
  HostName $hostname
  User $username
  IdentityFile ~/.ssh/$key_name
  IdentitiesOnly yes
"

    # Try to add to ~/.config/.ssh/config first, then ~/.ssh/config
    if [[ -f ~/.config/.ssh/config ]]; then
        config_file=~/.config/.ssh/config
    elif [[ -f ~/.ssh/config ]]; then
        config_file=~/.ssh/config
    else
        config_file=~/.config/.ssh/config
        mkdir -p ~/.config/.ssh
        touch "$config_file"
    fi

    # Add entry if it doesn't already exist
    if ! grep -q "^Host $host_alias$" "$config_file" 2>/dev/null; then
        echo "$ssh_config_entry" >> "$config_file"
    fi
fi

# Auto-install public key on server (only for servers, not Git services)
install_key=""
if [[ "$key_type" == "1" && -n "$hostname" ]]; then
    read -p "Install public key on server $hostname now? (y/N): " install_key
    if [[ "$install_key" =~ ^[Yy]$ ]]; then
        if ! ssh-copy-id -i "$final_private_key_path" "$username@$hostname" 2>/dev/null; then
            install_key="n"  # Mark as failed so TODO is added
        fi
    fi
fi

# Clean up temporary files
rm -f "$private_key_path" "$public_key_path"

# Print final output with top border
echo ""
echo -e "${BLUE}════════════════════════════════════════════════════════════════════════════${RESET}"
echo -e "${GREEN}✓ SSH key generation complete!${RESET}"
echo -e "  Private: $final_private_key_path"
echo -e "  Public:  $final_public_key_path"

# Collect TODOs for manual actions
todos=()

if command -v sops &> /dev/null && [[ -f ~/.config/secrets.yaml ]]; then
    todos+=("Add to SOPS: ${GREEN}sops ~/.config/secrets.yaml${RESET} (entry in ${YELLOW}\"+${RESET} register)")
fi

if [[ "$key_type" == "2" ]]; then
    # Git service - show where to add public key
    echo ""
    echo -e "${YELLOW}Public key (add to your Git service):${RESET}"
    cat "$final_public_key_path"
    todos+=("Add public key to Git service (GitHub/GitLab/Azure DevOps)")
fi

if [[ "$key_type" != "2" && -n "$hostname" ]]; then
    todos+=("Run: ${GREEN}hm${RESET} (activate SSH config)")
    if [[ "$install_key" != "y" && "$install_key" != "Y" ]]; then
        todos+=("Install key: ${GREEN}ssh-copy-id -i ~/.ssh/$key_name $host_alias${RESET}")
    fi
fi

# Display all TODOs at the end
if [ ${#todos[@]} -gt 0 ]; then
    echo ""
    echo -e "${BLUE}TODOs:${RESET}"
    for i in "${!todos[@]}"; do
        echo -e "  $((i+1)). ${todos[$i]}"
    done
fi