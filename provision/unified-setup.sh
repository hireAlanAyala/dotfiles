#!/bin/bash
set -euo pipefail

# Unified Provisioning Script
# This script adapts its behavior based on the runtime environment (Docker, VPS, GitHub Actions)
# It replaces the separate docker-system-setup.sh and system-setup.sh scripts

# Get script directory and source configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.env"

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "=== Unified System Setup ($(date)) ==="
echo "🔍 Detected environment: $DETECTED_ENV"

# Environment-specific setup functions
setup_packages() {
    echo "📦 Setting up packages for environment: $DETECTED_ENV"
    
    case "$DETECTED_ENV" in
        docker)
            # Docker: packages should already be installed in Dockerfile
            echo "ℹ️  Running in Docker - base packages from Dockerfile"
            if [ -n "$ADDITIONAL_PACKAGES" ]; then
                echo "Installing additional packages: $ADDITIONAL_PACKAGES"
                sudo pacman -S --noconfirm $ADDITIONAL_PACKAGES
            fi
            ;;
        vps|github-actions)
            # VPS: full package installation
            echo "Installing essential packages: $ESSENTIAL_PACKAGES"
            
            # Enable parallel downloads for faster installation
            sudo sed -i "s/^#ParallelDownloads.*/ParallelDownloads = $PARALLEL_DOWNLOADS/" /etc/pacman.conf 2>/dev/null || true
            
            # Update package database and install packages
            sudo pacman -Sy --noconfirm
            sudo pacman -S --noconfirm $ESSENTIAL_PACKAGES
            
            if [ -n "$SECURITY_PACKAGES" ] && should_enable_feature "fail2ban"; then
                echo "Installing security packages: $SECURITY_PACKAGES"
                sudo pacman -S --noconfirm $SECURITY_PACKAGES
            fi
            ;;
        *)
            echo "⚠️  Unknown environment, attempting standard package installation"
            sudo pacman -S --noconfirm $ESSENTIAL_PACKAGES
            ;;
    esac
}

setup_user() {
    echo "👤 Setting up user configuration"
    
    case "$DETECTED_ENV" in
        docker)
            # Docker: user should already exist from Dockerfile
            if ! id "$USERNAME" &>/dev/null; then
                echo "❌ User $USERNAME should exist in Docker - check Dockerfile"
                exit 1
            fi
            echo "✅ User $USERNAME exists (created in Dockerfile)"
            ;;
        vps|github-actions)
            # VPS: create user if it doesn't exist
            if ! id "$USERNAME" &>/dev/null; then
                echo "Creating user: $USERNAME"
                sudo useradd -m -s "$USER_SHELL" -G "$USER_GROUPS" "$USERNAME"
                
                # Set password if provided (VPS/GitHub Actions)
                if [ -n "${ROOT_PASSWORD:-}" ]; then
                    echo "$USERNAME:$ROOT_PASSWORD" | sudo chpasswd
                fi
            else
                echo "✅ User $USERNAME already exists"
            fi
            ;;
    esac
    
    # Configure sudo for all environments
    echo "🔐 Configuring sudo access"
    case "$DETECTED_ENV" in
        docker)
            # Docker: NOPASSWD sudo should be configured in Dockerfile
            if ! sudo -l &>/dev/null; then
                echo "❌ Sudo not properly configured - check Dockerfile"
                exit 1
            fi
            ;;
        vps|github-actions)
            # VPS: configure sudo with password requirement
            echo "%wheel ALL=(ALL) ALL" | sudo tee /etc/sudoers.d/wheel > /dev/null
            sudo chmod 440 /etc/sudoers.d/wheel
            ;;
    esac
}

setup_ssh() {
    echo "🔑 Setting up SSH configuration"
    
    if should_enable_feature "ssh-hardening"; then
        echo "Running SSH hardening for environment: $DETECTED_ENV"
        if [ -f "$SCRIPT_DIR/ssh-hardening.sh" ]; then
            bash "$SCRIPT_DIR/ssh-hardening.sh"
        else
            echo "⚠️  SSH hardening script not found, skipping"
        fi
    else
        echo "ℹ️  SSH hardening disabled for environment: $DETECTED_ENV"
        
        # Copy SSH keys for VPS environments
        if [ "$DETECTED_ENV" = "vps" ] || [ "$DETECTED_ENV" = "github-actions" ]; then
            if [ -f /root/.ssh/authorized_keys ]; then
                echo "Copying SSH keys to user directory"
                sudo mkdir -p "/home/$USERNAME/.ssh"
                sudo cp /root/.ssh/authorized_keys "/home/$USERNAME/.ssh/"
                sudo chown -R "$USERNAME:$USERNAME" "/home/$USERNAME/.ssh"
                sudo chmod 700 "/home/$USERNAME/.ssh"
                sudo chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
            fi
        fi
    fi
}

setup_security() {
    echo "🛡️  Setting up security configuration"
    
    if should_enable_feature "fail2ban"; then
        echo "Setting up fail2ban and security hardening"
        if [ -f "$SCRIPT_DIR/security-hardening.sh" ]; then
            bash "$SCRIPT_DIR/security-hardening.sh"
        else
            echo "⚠️  Security hardening script not found, skipping"
        fi
    else
        echo "ℹ️  Security hardening disabled for environment: $DETECTED_ENV"
    fi
}

setup_directories() {
    echo "📁 Setting up directory structure"
    
    # Create standard directories
    mkdir -p "$HOME/.config"
    mkdir -p "$HOME/.local/bin"
    mkdir -p "$HOME/.cache"
    
    echo "✅ Created directories: ~/.config, ~/.local/bin, ~/.cache"
}

setup_git() {
    echo "📝 Setting up Git configuration"
    
    # Set basic git configuration for testing/development
    git config --global user.name "$GIT_USER_NAME"
    git config --global user.email "$GIT_USER_EMAIL"
    
    echo "✅ Git configured with name: $GIT_USER_NAME, email: $GIT_USER_EMAIL"
}

setup_gpg() {
    echo "🔐 Setting up GPG configuration"
    
    # Set up GPG environment for non-interactive use
    export GPG_TTY=$(tty) 2>/dev/null || export GPG_TTY=""
    export GNUPGHOME="$HOME/.gnupg"
    
    # Create GPG directory with proper permissions
    mkdir -p "$GNUPGHOME"
    chmod 700 "$GNUPGHOME"
    
    # Import GPG key if provided
    if [ -n "$GPG_KEY_FILE" ] && [ -f "$GPG_KEY_FILE" ]; then
        echo "Importing GPG key from: $GPG_KEY_FILE"
        
        # Import GPG key with batch mode and no TTY
        gpg --batch --yes --import "$GPG_KEY_FILE" 2>/dev/null || {
            echo "Standard import failed, trying with pinentry-mode loopback..."
            gpg --batch --yes --pinentry-mode loopback --import "$GPG_KEY_FILE"
        }
        
        # Remove key file only in VPS environments (not Docker testing)
        if [ "$DETECTED_ENV" = "vps" ] || [ "$DETECTED_ENV" = "github-actions" ]; then
            rm -f "$GPG_KEY_FILE"
        else
            echo "ℹ️  Keeping GPG key file (testing environment)"
        fi
        
        # Trust the key automatically using fingerprint
        FINGERPRINT=$(gpg --list-secret-keys --with-colons 2>/dev/null | grep fpr | cut -d: -f10 | head -1)
        if [ -n "$FINGERPRINT" ]; then
            echo "Trusting GPG key with fingerprint: $FINGERPRINT"
            echo "${FINGERPRINT}:6:" | gpg --batch --yes --import-ownertrust
            echo "✅ GPG key imported and trusted"
        else
            # Fallback: try with ultimate trust without fingerprint verification
            echo "Could not get fingerprint, setting ultimate trust for all imported keys..."
            gpg --list-secret-keys --with-colons 2>/dev/null | grep sec | cut -d: -f5 | while read keyid; do
                echo "$keyid:6:" | gpg --batch --yes --import-ownertrust 2>/dev/null || true
            done
            echo "✅ GPG key imported with fallback trust method"
        fi
        
        # Test SOPS functionality if available
        if command -v sops >/dev/null 2>&1 && [ "$DETECTED_ENV" = "docker" ]; then
            echo "🧪 Testing SOPS functionality..."
            echo "test_secret: hello_world" | sops --encrypt --age "$FINGERPRINT" /dev/stdin > /tmp/test-secret.yaml 2>/dev/null && {
                echo "✅ SOPS encryption test passed"
                sops --decrypt /tmp/test-secret.yaml >/dev/null 2>&1 && {
                    echo "✅ SOPS decryption test passed"
                } || echo "⚠️  SOPS decryption test failed"
                rm -f /tmp/test-secret.yaml
            } || echo "⚠️  SOPS encryption test failed"
        fi
        
    elif [ "$DETECTED_ENV" = "docker" ] && [ "${GENERATE_TEST_KEY:-}" = "true" ]; then
        echo "🔑 Generating test GPG key for Docker environment..."
        cat > /tmp/gpg-test-key-config <<EOF
%echo Generating test GPG key
Key-Type: RSA
Key-Length: 2048
Subkey-Type: RSA
Subkey-Length: 2048
Name-Real: $GIT_USER_NAME
Name-Email: $GIT_USER_EMAIL
Expire-Date: 1y
Passphrase: 
%commit
%echo Test GPG key generated
EOF
        gpg --batch --generate-key /tmp/gpg-test-key-config
        rm -f /tmp/gpg-test-key-config
        echo "✅ Test GPG key generated"
    else
        echo "ℹ️  No GPG key provided, skipping GPG setup"
    fi
    
    # Display GPG status
    if gpg --list-keys >/dev/null 2>&1; then
        echo "📋 GPG keys available:"
        gpg --list-keys --with-colons | grep pub | cut -d: -f5,10 | while IFS=: read keyid name; do
            echo "   Key: $keyid ($name)"
        done
    fi
}

setup_dotfiles() {
    echo "🏠 Setting up dotfiles"
    
    case "$DETECTED_ENV" in
        docker)
            echo "ℹ️  Docker environment - dotfiles mounted at /mnt/config"
            echo "💡 Copy them manually: cp -r /mnt/config/home-manager ~/.config/"
            ;;
        vps|github-actions)
            if [ -n "$DOTFILES_REPO" ] && [ "$DOTFILES_REPO" != "https://github.com/yourusername/dotfiles.git" ]; then
                echo "Cloning dotfiles from: $DOTFILES_REPO"
                git clone "$DOTFILES_REPO" "$DOTFILES_DIR" || echo "⚠️  Failed to clone dotfiles"
            else
                echo "ℹ️  Dotfiles repo not configured or using placeholder URL"
            fi
            ;;
    esac
}

# Main execution flow
main() {
    echo "🚀 Starting unified setup with configuration:"
    echo "   Username: $USERNAME"
    echo "   Environment: $DETECTED_ENV"
    echo "   Essential packages: $ESSENTIAL_PACKAGES"
    echo ""
    
    setup_packages
    setup_user
    setup_directories
    setup_git
    setup_gpg
    setup_ssh
    setup_security
    setup_dotfiles
    
    echo ""
    echo "✅ Unified setup completed successfully!"
    echo "📋 Summary:"
    echo "   - Environment: $DETECTED_ENV"
    echo "   - User: $USERNAME ($(id "$USERNAME" 2>/dev/null || echo "not found"))"
    echo "   - Home: $HOME"
    echo "   - Git: $GIT_USER_NAME <$GIT_USER_EMAIL>"
    
    if [ "$DETECTED_ENV" = "docker" ]; then
        echo ""
        echo "🐳 Docker-specific next steps:"
        echo "   1. Copy config: cp -r /mnt/config/home-manager ~/.config/"
        echo "   2. Test GPG: /tmp/docker-gpg-ssh-setup.sh"
        echo "   3. Test Home Manager: cd ~/.config/home-manager && nix build"
    fi
}

# Run main function
main "$@"