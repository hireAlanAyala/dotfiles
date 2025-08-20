#!/bin/bash

# 1Password Daemon Setup Script
# Sets up secure 1Password CLI daemon for system installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CONFIG_DIR="$(dirname "$SCRIPT_DIR")"

echo "🔐 Setting up 1Password CLI daemon..."

# Check if running as root (required for system setup)
if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

# Install 1Password CLI if not present
echo "=== Installing 1Password CLI ==="
if ! command -v op &> /dev/null; then
    echo "📥 Downloading 1Password CLI..."
    
    # Detect architecture
    ARCH=$(uname -m)
    case $ARCH in
        x86_64) OP_ARCH="amd64" ;;
        aarch64) OP_ARCH="arm64" ;;
        armv7l) OP_ARCH="arm" ;;
        *) echo "❌ Unsupported architecture: $ARCH"; exit 1 ;;
    esac
    
    # Download and install
    OP_VERSION="2.24.0"  # Update as needed
    OP_URL="https://cache.agilebits.com/dist/1P/op2/pkg/v${OP_VERSION}/op_linux_${OP_ARCH}_v${OP_VERSION}.zip"
    
    cd /tmp
    wget -O op.zip "$OP_URL"
    unzip -o op.zip
    chmod +x op
    mv op /usr/local/bin/
    rm op.zip
    
    echo "✅ 1Password CLI installed"
else
    echo "✅ 1Password CLI already installed: $(op --version)"
fi

# Create onepass-svc user
echo "=== Creating service user ==="
if ! id -u onepass-svc &>/dev/null; then
    useradd -r -s /bin/false -d /opt/onepass -m onepass-svc
    echo "✅ Created onepass-svc user"
else
    echo "✅ onepass-svc user already exists"
fi

# Create onepass group and add current user
echo "=== Setting up groups ==="
if ! getent group onepass &>/dev/null; then
    groupadd onepass
    echo "✅ Created onepass group"
else
    echo "✅ onepass group already exists"
fi

# Add onepass-svc to onepass group
usermod -a -G onepass onepass-svc

# Add the original user (who ran sudo) to onepass group
ORIGINAL_USER="${SUDO_USER:-$USER}"
if [[ "$ORIGINAL_USER" != "root" ]]; then
    usermod -a -G onepass "$ORIGINAL_USER"
    echo "✅ Added $ORIGINAL_USER to onepass group"
fi

# Create directory structure
echo "=== Setting up directories ==="
mkdir -p /opt/onepass
mkdir -p /var/run/onepass
mkdir -p /var/log/onepass

# Set ownership and permissions
chown -R onepass-svc:onepass /opt/onepass
chown -R onepass-svc:onepass /var/run/onepass
chown -R onepass-svc:onepass /var/log/onepass

chmod 750 /opt/onepass
chmod 770 /var/run/onepass
chmod 750 /var/log/onepass

# Copy daemon script
echo "=== Installing daemon ==="
cp "$SCRIPT_DIR/onepass-daemon.py" /opt/onepass/
chmod +x /opt/onepass/onepass-daemon.py
chown onepass-svc:onepass /opt/onepass/onepass-daemon.py

# Create systemd service
echo "=== Creating systemd service ==="
cat > /etc/systemd/system/onepass-daemon.service << 'EOF'
[Unit]
Description=1Password CLI Daemon
After=network.target
Wants=network.target

[Service]
Type=simple
User=onepass-svc
Group=onepass
ExecStart=/usr/bin/python3 /opt/onepass/onepass-daemon.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

# Security settings
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/run/onepass /var/log/onepass
ProtectControlGroups=true
ProtectKernelModules=true
ProtectKernelTunables=true
RestrictNamespaces=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable service
systemctl daemon-reload
systemctl enable onepass-daemon.service

echo "✅ Systemd service created and enabled"

# Create client library
echo "=== Creating client library ==="
cat > /opt/onepass/client.sh << 'EOF'
#!/bin/bash

# 1Password Daemon Client Library
# Functions for communicating with the 1Password daemon

SOCKET_PATH="/var/run/onepass/daemon.sock"

op_send_request() {
    local request="$1"
    if [[ ! -S "$SOCKET_PATH" ]]; then
        echo '{"status": "error", "message": "Daemon not running"}' >&2
        return 1
    fi
    
    echo "$request" | socat - "UNIX-CONNECT:$SOCKET_PATH" 2>/dev/null
}

op_daemon_signin() {
    # Service account authentication - no parameters needed
    # This function is kept for backward compatibility
    local request='{"command": "signin"}'
    op_send_request "$request"
}

op_daemon_get() {
    local item="$1"
    local field="${2:-}"
    local vault="${3:-}"
    
    if [[ -z "$item" ]]; then
        echo "Usage: op_daemon_get <item> [field] [vault]" >&2
        return 1
    fi
    
    local field_part=""
    local vault_part=""
    
    [[ -n "$field" ]] && field_part=", \"field\": \"$field\""
    [[ -n "$vault" ]] && vault_part=", \"vault\": \"$vault\""
    
    local request=$(cat <<EOF
{
    "command": "get_item",
    "item_name": "$item"${field_part}${vault_part}
}
EOF
)
    
    op_send_request "$request"
}

op_daemon_list() {
    local vault="${1:-}"
    local categories="${2:-}"
    
    local vault_part=""
    local categories_part=""
    
    [[ -n "$vault" ]] && vault_part=", \"vault\": \"$vault\""
    [[ -n "$categories" ]] && categories_part=", \"categories\": \"$categories\""
    
    local request=$(cat <<EOF
{
    "command": "list_items"${vault_part}${categories_part}
}
EOF
)
    op_send_request "$request"
}

op_daemon_list_vaults() {
    local request='{"command": "list_vaults"}'
    op_send_request "$request"
}

op_daemon_status() {
    local request='{"command": "status"}'
    op_send_request "$request"
}

op_daemon_signout() {
    local request='{"command": "signout"}'
    op_send_request "$request"
}

# Convenience functions that extract just the data
op_get_password() {
    local item="$1"
    local vault="${2:-}"
    op_daemon_get "$item" "password" "$vault" | jq -r '.data // empty'
}

op_get_field() {
    local item="$1"
    local field="$2"
    local vault="${3:-}"
    op_daemon_get "$item" "$field" "$vault" | jq -r '.data // empty'
}

# Check if daemon is authenticated
op_is_authenticated() {
    op_daemon_status | jq -r '.authenticated // false'
}

# Backward compatibility alias
op_is_signed_in() {
    op_is_authenticated
}
EOF

chmod +x /opt/onepass/client.sh
chown onepass-svc:onepass /opt/onepass/client.sh

# Install socat if not present (needed for socket communication)
echo "=== Installing socat ==="
if ! command -v socat &> /dev/null; then
    if command -v apt-get &> /dev/null; then
        apt-get update && apt-get install -y socat jq
    elif command -v yum &> /dev/null; then
        yum install -y socat jq
    elif command -v dnf &> /dev/null; then
        dnf install -y socat jq
    else
        echo "⚠️  Please install socat and jq manually"
    fi
    echo "✅ socat and jq installed"
else
    echo "✅ socat already available"
fi

# Start the daemon
echo "=== Starting daemon ==="
systemctl start onepass-daemon.service

# Wait a moment for startup
sleep 2

# Check status
if systemctl is-active --quiet onepass-daemon.service; then
    echo "✅ 1Password daemon installed successfully"
else
    echo "❌ Failed to install daemon"
    systemctl status onepass-daemon.service
    exit 1
fi

# Service account token setup
echo ""
echo "=== Service Account Setup ==="
echo "⚠️  This daemon now requires a 1Password service account token."
echo "ℹ️  Service accounts provide secure, non-interactive authentication."
echo ""
echo "To configure a service account token:"
echo "  1. Create a service account in your 1Password account:"
echo "     https://my.1password.com/integrations/directory"
echo "  2. Copy the service account token"
echo "  3. Run: sudo /opt/onepass/configure-service-account.sh"
echo ""

# Create service account configuration script
cat > /opt/onepass/configure-service-account.sh << 'EOF'
#!/bin/bash

# Service Account Configuration Script
# Securely configures 1Password service account token

set -euo pipefail

if [[ $EUID -ne 0 ]]; then
   echo "❌ This script must be run as root (use sudo)"
   exit 1
fi

echo "🔐 Configuring 1Password Service Account..."
echo ""
echo "Please paste your service account token (input will be hidden):"
read -s -p "Service Account Token: " TOKEN
echo ""

if [[ -z "$TOKEN" ]]; then
    echo "❌ No token provided"
    exit 1
fi

# Validate token format (should start with ops_)
if [[ ! "$TOKEN" =~ ^ops_ ]]; then
    echo "⚠️  Warning: Token doesn't start with 'ops_' - this may not be a valid service account token"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Write token to secure file
echo "$TOKEN" > /opt/onepass/service-account-token
chmod 600 /opt/onepass/service-account-token
chown onepass-svc:onepass /opt/onepass/service-account-token

echo "✅ Service account token configured"

# Test the token by restarting the daemon
echo "🔄 Testing service account..."
systemctl restart onepass-daemon.service
sleep 3

if systemctl is-active --quiet onepass-daemon.service; then
    echo "✅ Service account validation successful!"
    echo "✅ 1Password daemon is running with service account authentication"
else
    echo "❌ Service account validation failed"
    echo "📋 Check logs: journalctl -u onepass-daemon.service -f"
    exit 1
fi
EOF

chmod +x /opt/onepass/configure-service-account.sh
chown root:root /opt/onepass/configure-service-account.sh

echo ""
echo "🎉 1Password daemon setup complete!"
echo ""
echo "📋 Usage:"
echo "  Source the client library: source /opt/onepass/client.sh"
echo "  Get password: op_get_password 'My Item'"
echo "  Get field: op_get_field 'My Item' 'username'"
echo "  List vaults: op_daemon_list_vaults"
echo "  Check status: op_daemon_status"
echo ""
echo "⚠️  SECURITY NOTICE:"
echo "  - Uses service account token for authentication"
echo "  - Service account token is stored securely at /opt/onepass/service-account-token"
echo "  - Only users in 'onepass' group can access the daemon"
echo "  - Daemon runs with restricted privileges"
echo ""
echo "📝 Next steps:"
echo "  1. Configure service account: sudo /opt/onepass/configure-service-account.sh"
echo "  2. Log out and back in for group membership to take effect"
echo "  3. Or use 'newgrp onepass' in current session"
echo "  4. Source client library to use: source /opt/onepass/client.sh"