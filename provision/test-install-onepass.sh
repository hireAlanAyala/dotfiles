#!/bin/bash

# Test 1Password Daemon Installation (E2E)
# Extracted from install.sh for isolated testing

set -euo pipefail

echo "🧪 Testing 1Password daemon installation (E2E)..."
echo "This script extracts the 1Password setup from install.sh"
echo "It will require sudo for system-level installation"
echo ""

# Check if we're on the right system
if [[ "$OSTYPE" != "linux-gnu"* ]]; then
    echo "❌ This script is designed for Linux systems"
    exit 1
fi

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

# Change to config directory
cd "$CONFIG_DIR"

# Setup 1Password daemon early (before Nix) for secret access
echo ""
echo "=== Setting up 1Password CLI daemon ==="
echo "This provides secure access to secrets during installation..."
if [ -f ./provision/setup-onepass-daemon.sh ]; then
    # Check if daemon is already installed
    if systemctl is-active --quiet onepass-daemon.service 2>/dev/null; then
        echo "⚠️  1Password daemon already installed and running"
        echo "To reinstall, first run: sudo systemctl stop onepass-daemon.service"
        echo "Then: sudo systemctl disable onepass-daemon.service"
        echo "And: sudo userdel -r onepass-svc"
        exit 1
    fi
    
    # Run the setup script
    sudo ./provision/setup-onepass-daemon.sh
    echo "✅ 1Password daemon setup complete"
    
    # Source helper functions for use during install
    if [ -f /opt/onepass/client.sh ] && [ -f ./provision/onepass-helpers.sh ]; then
        source /opt/onepass/client.sh
        source ./provision/onepass-helpers.sh
        
        echo ""
        echo "🔐 1Password daemon is ready for use"
        echo "   Available functions: op_interactive_signin, op_safe_get_password, etc."
        echo ""
        
        # Test the installation
        echo "=== Testing daemon functionality ==="
        op_health_check
        echo ""
        
        # Show usage examples
        echo "📋 Usage Examples:"
        echo ""
        echo "1. Sign in interactively:"
        echo "   op_interactive_signin"
        echo ""
        echo "2. Get a password:"
        echo "   PASSWORD=\$(op_safe_get_password 'My Item')"
        echo ""
        echo "3. Get a specific field:"
        echo "   API_KEY=\$(op_safe_get_field 'API Keys' 'github_token')"
        echo ""
        echo "4. Export to environment:"
        echo "   op_export_env 'Secrets' 'api_key' 'MY_API_KEY'"
        echo ""
        
        # Demonstrate usage
        echo "=== Demo: Using 1Password in scripts ==="
        cat << 'DEMO'
#!/bin/bash
# Example: Using 1Password in installation scripts

# Source the helpers
source /opt/onepass/client.sh
source ~/.config/provision/onepass-helpers.sh

# Check if signed in
if [[ "$(op_is_signed_in)" != "true" ]]; then
    echo "Please sign in first:"
    op_interactive_signin
fi

# Get secrets
GITHUB_TOKEN=$(op_safe_get_password 'GitHub Token')
API_KEY=$(op_safe_get_field 'API Keys' 'openai')

# Use in your scripts
echo "Setting up GitHub with token..."
# git config --global github.token "$GITHUB_TOKEN"

echo "Configuring API access..."
# export OPENAI_API_KEY="$API_KEY"
DEMO
        
    else
        echo "⚠️  Helper functions not found, daemon may not be properly installed"
    fi
else
    echo "❌ 1Password daemon setup script not found at ./provision/setup-onepass-daemon.sh"
    exit 1
fi

echo ""
echo "🎉 1Password daemon E2E test complete!"
echo ""
echo "📝 Next steps:"
echo "1. The daemon is now running as a system service"
echo "2. You need to log out and back in for 'onepass' group membership"
echo "3. Or use: newgrp onepass (for current session)"
echo "4. Then sign in: op_interactive_signin"
echo ""
echo "🧹 To clean up this test installation:"
echo "  sudo systemctl stop onepass-daemon.service"
echo "  sudo systemctl disable onepass-daemon.service"
echo "  sudo rm -rf /opt/onepass /var/run/onepass /var/log/onepass"
echo "  sudo rm /etc/systemd/system/onepass-daemon.service"
echo "  sudo userdel -r onepass-svc"
echo "  sudo groupdel onepass"