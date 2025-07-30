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
    local account="$1"
    local email="$2"
    local secret_key="$3"
    local password="$4"
    
    if [[ -z "$account" || -z "$email" || -z "$secret_key" || -z "$password" ]]; then
        echo "Usage: op_daemon_signin <account> <email> <secret-key> <password>" >&2
        return 1
    fi
    
    local request=$(cat <<EOF
{
    "command": "signin", 
    "account": "$account",
    "email": "$email", 
    "secret_key": "$secret_key",
    "password": "$password"
}
EOF
)
    
    op_send_request "$request"
}

op_daemon_get() {
    local item="$1"
    local field="${2:-}"
    
    if [[ -z "$item" ]]; then
        echo "Usage: op_daemon_get <item> [field]" >&2
        return 1
    fi
    
    local request=$(cat <<EOF
{
    "command": "get_item",
    "item_name": "$item"$([ -n "$field" ] && echo ", \"field\": \"$field\"")
}
EOF
)
    
    op_send_request "$request"
}

op_daemon_list() {
    local request='{"command": "list_items"}'
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
    op_daemon_get "$item" "password" | jq -r '.data // empty'
}

op_get_field() {
    local item="$1"
    local field="$2"
    op_daemon_get "$item" "$field" | jq -r '.data // empty'
}

# Check if daemon is signed in
op_is_signed_in() {
    op_daemon_status | jq -r '.signed_in // false'
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
    echo "✅ 1Password daemon started successfully"
else
    echo "❌ Failed to start daemon"
    systemctl status onepass-daemon.service
    exit 1
fi

echo ""
echo "🎉 1Password daemon setup complete!"
echo ""
echo "📋 Usage:"
echo "  Source the client library: source /opt/onepass/client.sh"
echo "  Sign in: op_daemon_signin <account> <email> <secret-key> <password>"
echo "  Get password: op_get_password 'My Item'"
echo "  Get field: op_get_field 'My Item' 'username'"
echo "  Check status: op_daemon_status"
echo ""
echo "⚠️  SECURITY NOTICE:"
echo "  - Session tokens are stored only in daemon memory"
echo "  - Sessions timeout after 30 minutes of inactivity"
echo "  - Only users in 'onepass' group can access the daemon"
echo "  - Daemon runs with restricted privileges"
echo ""
echo "📝 Next steps:"
echo "  1. Log out and back in for group membership to take effect"
echo "  2. Or use 'newgrp onepass' in current session"
echo "  3. Source client library and sign in to use"