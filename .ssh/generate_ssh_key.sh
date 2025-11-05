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
echo -e "${BLUE}Generating SSH key pair...${RESET}"
if [[ -n "$key_size_flag" ]]; then
    ssh-keygen -t "$key_type_flag" -b "$key_size_flag" -C "$key_email" -f "$private_key_path" -N "" || { echo -e "${RED}Error generating SSH key${RESET}"; exit 1; }
else
    ssh-keygen -t "$key_type_flag" -C "$key_email" -f "$private_key_path" -N "" || { echo -e "${RED}Error generating SSH key${RESET}"; exit 1; }
fi

# Ensure ~/.config/.ssh directory exists
mkdir -p "$HOME/.config/.ssh"

# Copy private key to ~/.config/.ssh with correct permissions
cp "$private_key_path" "$final_private_key_path" || { echo -e "${RED}Error copying private key to ~/.config/.ssh/${RESET}"; exit 1; }
chmod 600 "$final_private_key_path" || { echo -e "${RED}Error setting private key permissions${RESET}"; exit 1; }
echo -e "${GREEN}Private key installed at $final_private_key_path with correct permissions${RESET}"

# Copy public key to ~/.config/.ssh
cp "$public_key_path" "$final_public_key_path" || { echo -e "${RED}Error copying public key to ~/.config/.ssh/${RESET}"; exit 1; }
echo -e "${GREEN}Public key installed at $final_public_key_path${RESET}"

# Add key to ssh-agent
if ssh-add "$final_private_key_path" 2>/dev/null; then
    echo -e "${GREEN}SSH key added to ssh-agent${RESET}"
else
    echo -e "${YELLOW}Warning: Could not add key to ssh-agent (agent may not be running)${RESET}"
fi

# Copy the private key to the clipboard for SOPS
echo -e "\n${BLUE}Copying private key to clipboard for SOPS...${RESET}"
if command -v pbcopy &> /dev/null; then
    # macOS
    cat "$private_key_path" | pbcopy
    echo -e "${GREEN}Private key copied to clipboard (macOS)${RESET}"
elif command -v xclip &> /dev/null; then
    # Linux (xclip)
    cat "$private_key_path" | xclip -selection clipboard
    echo -e "${GREEN}Private key copied to clipboard (Linux with xclip)${RESET}"
elif command -v wl-copy &> /dev/null; then
    # Linux (Wayland wl-copy)
    cat "$private_key_path" | wl-copy
    echo -e "${GREEN}Private key copied to clipboard (Linux with wl-copy)${RESET}"
elif [[ -f "/mnt/c/Windows/System32/clip.exe" ]]; then
    # WSL
    cat "$private_key_path" | /mnt/c/Windows/System32/clip.exe
    echo -e "${GREEN}Private key copied to clipboard (WSL)${RESET}"
else
    echo -e "${YELLOW}Warning: No clipboard utility found. You'll need to manually copy the private key${RESET}"
    echo -e "${YELLOW}Private key location: $private_key_path${RESET}"
fi

# Auto-add to SOPS
echo -e "\n${BLUE}Adding private key to SOPS...${RESET}"
if command -v sops &> /dev/null && [[ -f ~/.config/secrets.yaml ]]; then
    # Create properly formatted YAML entry with indentation
    temp_yaml="/tmp/sops_entry_$key_name.yaml"
    echo "ssh_private_key_$key_name: |" > "$temp_yaml"
    sed 's/^/    /' "$private_key_path" >> "$temp_yaml"

    # Decrypt, append new key, re-encrypt
    temp_decrypted="/tmp/secrets_decrypted_$key_name.yaml"
    if sops -d ~/.config/secrets.yaml > "$temp_decrypted" 2>/dev/null; then
        # Check if key already exists
        if grep -q "^ssh_private_key_$key_name:" "$temp_decrypted"; then
            echo -e "${YELLOW}Warning: ssh_private_key_$key_name already exists in SOPS${RESET}"
        else
            # Append new key entry
            cat "$temp_yaml" >> "$temp_decrypted"
            # Re-encrypt
            if sops -e "$temp_decrypted" > ~/.config/secrets.yaml 2>/dev/null; then
                echo -e "${GREEN}✓ Private key added to SOPS secrets${RESET}"
            else
                echo -e "${YELLOW}Could not encrypt secrets. Manual addition required.${RESET}"
            fi
        fi
        rm -f "$temp_decrypted"
    else
        echo -e "${YELLOW}Could not decrypt secrets. Manual addition required:${RESET}"
        echo -e "${YELLOW}1. Run: sops ~/.config/secrets.yaml${RESET}"
        echo -e "${YELLOW}2. Add this entry (each line indented with 4 spaces):${RESET}"
        cat "$temp_yaml"
    fi
    rm -f "$temp_yaml"
elif command -v sops &> /dev/null; then
    echo -e "${YELLOW}secrets.yaml not found at ~/.config/secrets.yaml${RESET}"
else
    echo -e "${YELLOW}sops command not found, skipping SOPS integration${RESET}"
fi

# Auto-add SSH config entry (only for servers and other services with hostnames)
if [[ "$key_type" == "2" ]]; then
    echo -e "\n${BLUE}Skipping SSH config entry for Git service${RESET}"
    echo -e "${YELLOW}For Git services, add the public key to your account's SSH settings${RESET}"
elif [[ -n "$hostname" ]]; then
    echo -e "\n${BLUE}Adding SSH config entry...${RESET}"
    ssh_config_entry="
Host $key_name
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
    
    # Check if entry already exists
    if grep -q "^Host $key_name$" "$config_file"; then
        echo -e "${YELLOW}SSH config entry for $key_name already exists in $config_file${RESET}"
    else
        echo "$ssh_config_entry" >> "$config_file"
        echo -e "${GREEN}✓ SSH config entry added to $config_file${RESET}"
        if [[ "$config_file" == *".config/.ssh/config"* ]]; then
            echo -e "${BLUE}Note: Run 'hm' to activate the SSH config changes${RESET}"
        fi
    fi
else
    echo -e "${YELLOW}No hostname provided. Manual SSH config entry:${RESET}"
    echo -e "${YELLOW}Host $key_name${RESET}"
    echo -e "${YELLOW}  HostName example.com${RESET}"
    echo -e "${YELLOW}  User $username${RESET}"
    echo -e "${YELLOW}  IdentityFile ~/.ssh/$key_name${RESET}"
    echo -e "${YELLOW}  IdentitiesOnly yes${RESET}"
fi

# Auto-install public key on server (only for servers, not Git services)
if [[ "$key_type" == "2" ]]; then
    echo -e "\n${YELLOW}=== PUBLIC KEY FOR GIT SERVICE ===${RESET}"
    echo -e "${YELLOW}Copy this public key to your Git service account:${RESET}"
    cat "$final_public_key_path"
    echo -e "\n${YELLOW}Common locations:${RESET}"
    echo -e "${YELLOW}- GitHub: Settings → SSH and GPG keys → New SSH key${RESET}"
    echo -e "${YELLOW}- GitLab: User Settings → SSH Keys${RESET}"
    echo -e "${YELLOW}- Azure DevOps: User settings → SSH public keys${RESET}"
elif [[ "$key_type" == "1" && -n "$hostname" ]]; then
    echo -e "\n${BLUE}Public key installation...${RESET}"
    echo -e "${YELLOW}Public key content:${RESET}"
    cat "$final_public_key_path"
    echo ""
    
    read -p "Install public key on server $hostname now? (y/N): " install_key
    if [[ "$install_key" =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Installing public key on $hostname...${RESET}"
        if ssh-copy-id -i "$final_private_key_path" "$username@$hostname" 2>/dev/null; then
            echo -e "${GREEN}✓ Public key successfully installed on $hostname${RESET}"
        else
            echo -e "${YELLOW}Could not auto-install. Try manually:${RESET}"
            echo -e "${YELLOW}ssh-copy-id -i ~/.ssh/$key_name $key_name${RESET}"
        fi
    else
        echo -e "${YELLOW}To install later, run:${RESET}"
        echo -e "${YELLOW}ssh-copy-id -i ~/.ssh/$key_name $key_name${RESET}"
    fi
else
    echo -e "${YELLOW}=== PUBLIC KEY FOR SERVER ===${RESET}"
    echo -e "${YELLOW}To install on server, run:${RESET}"
    echo -e "${YELLOW}ssh-copy-id -i ~/.ssh/$key_name $key_name${RESET}"
    echo -e "${YELLOW}Or manually add this public key to server's ~/.ssh/authorized_keys:${RESET}"
    cat "$final_public_key_path"
fi

# Clean up temporary files
rm -f "$private_key_path" "$public_key_path"

echo -e "\n${GREEN}✓ SSH key generation complete!${RESET}"
echo -e "${GREEN}✓ Private key: $final_private_key_path${RESET}"
echo -e "${GREEN}✓ Public key: $final_public_key_path${RESET}"
echo -e "${GREEN}✓ Key added to ssh-agent${RESET}"
echo -e "${GREEN}✓ Private key copied to clipboard${RESET}"
if command -v sops &> /dev/null && [[ -f ~/.config/secrets.yaml ]]; then
    echo -e "${GREEN}✓ Private key added to SOPS secrets${RESET}"
fi
if [[ "$key_type" != "2" && -n "$hostname" ]]; then
    echo -e "${GREEN}✓ SSH config entry created${RESET}"
fi
if [[ "$key_type" == "2" ]]; then
    echo -e "${GREEN}✓ Ready for Git service configuration${RESET}"
fi