#!/usr/bin/env nix-shell
#!nix-shell -i bash -p python3 socat jq

# Test Production-like 1Password Daemon Setup
# Runs daemon in user space but mimics production configuration

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PROD_DIR="$HOME/.local/onepass-prod-test"
SOCKET_PATH="$PROD_DIR/run/daemon.sock"
LOG_FILE="$PROD_DIR/log/daemon.log"
PID_FILE="$PROD_DIR/run/daemon.pid"

echo "🔐 Setting up production-like 1Password daemon (user space)..."
echo ""
echo "This simulates the production daemon setup without requiring sudo."
echo "In real production, this would run as a system service."
echo ""

# Create directory structure mimicking production
echo "=== Creating directory structure ==="
mkdir -p "$PROD_DIR"/{opt,run,log}
echo "✅ Created production-like directories"

# Check for 1Password CLI
echo "=== Checking 1Password CLI ==="
if ! command -v op &> /dev/null; then
    echo "⚠️  1Password CLI not found - production daemon requires it"
    echo "Install with: brew install 1password-cli (macOS) or download from 1password.com"
    exit 1
else
    echo "✅ 1Password CLI found: $(op --version)"
fi

# Copy daemon with production paths
echo "=== Installing daemon ==="
sed "s|SOCKET_PATH = \"/var/run/onepass/daemon.sock\"|SOCKET_PATH = \"$SOCKET_PATH\"|; \
     s|LOG_FILE = \"/var/log/onepass/daemon.log\"|LOG_FILE = \"$LOG_FILE\"|; \
     s|PID_FILE = \"/var/run/onepass/daemon.pid\"|PID_FILE = \"$PID_FILE\"|" \
    "$SCRIPT_DIR/onepass-daemon.py" > "$PROD_DIR/opt/daemon.py"

chmod +x "$PROD_DIR/opt/daemon.py"
echo "✅ Daemon installed"

# Copy client library with production paths
echo "=== Installing client library ==="
sed "s|SOCKET_PATH=\"/var/run/onepass/daemon.sock\"|SOCKET_PATH=\"$SOCKET_PATH\"|" \
    /opt/onepass/client.sh 2>/dev/null > "$PROD_DIR/opt/client.sh" || \
cat > "$PROD_DIR/opt/client.sh" << EOF
#!/bin/bash

# Production 1Password Daemon Client Library

SOCKET_PATH="$SOCKET_PATH"

op_send_request() {
    local request="\$1"
    if [[ ! -S "\$SOCKET_PATH" ]]; then
        echo '{"status": "error", "message": "Daemon not running"}' >&2
        return 1
    fi
    
    echo "\$request" | socat - "UNIX-CONNECT:\$SOCKET_PATH" 2>/dev/null
}

op_daemon_signin() {
    echo "⚠️  Production signin requires 1Password service account"
    echo "For testing, use: account='test-account' email='test@example.com'"
    echo ""
    read -p "Account: " account
    read -p "Email: " email
    read -p "Secret Key: " secret_key
    echo -n "Password: "
    read -s password
    echo ""
    
    local request=\$(cat <<REQ
{
    "command": "signin", 
    "account": "\$account",
    "email": "\$email", 
    "secret_key": "\$secret_key",
    "password": "\$password"
}
REQ
)
    
    op_send_request "\$request"
}

op_daemon_get() {
    local item="\$1"
    local field="\${2:-}"
    
    local request=\$(cat <<REQ
{
    "command": "get_item",
    "item_name": "\$item"\$([ -n "\$field" ] && echo ", \"field\": \"\$field\"")
}
REQ
)
    
    op_send_request "\$request"
}

op_daemon_list() {
    local request='{"command": "list_items"}'
    op_send_request "\$request"
}

op_daemon_status() {
    local request='{"command": "status"}'
    op_send_request "\$request"
}

op_daemon_signout() {
    local request='{"command": "signout"}'
    op_send_request "\$request"
}
EOF

chmod +x "$PROD_DIR/opt/client.sh"

# Copy helper functions
cp "$SCRIPT_DIR/onepass-helpers.sh" "$PROD_DIR/opt/helpers.sh"
sed -i "s|/opt/onepass/client.sh|$PROD_DIR/opt/client.sh|g" "$PROD_DIR/opt/helpers.sh"

echo "✅ Client libraries installed"

# Create systemd-like service script
echo "=== Creating service management script ==="
cat > "$PROD_DIR/service.sh" << EOF
#!/bin/bash

DAEMON_PID_FILE="$PID_FILE"
DAEMON_SCRIPT="$PROD_DIR/opt/daemon.py"
LOG_FILE="$LOG_FILE"

case "\$1" in
    start)
        if [ -f "\$DAEMON_PID_FILE" ] && kill -0 \$(cat "\$DAEMON_PID_FILE") 2>/dev/null; then
            echo "Daemon already running (PID: \$(cat "\$DAEMON_PID_FILE"))"
            exit 1
        fi
        echo "Starting 1Password daemon..."
        python3 "\$DAEMON_SCRIPT" >> "\$LOG_FILE" 2>&1 &
        echo \$! > "\$DAEMON_PID_FILE"
        sleep 2
        if kill -0 \$(cat "\$DAEMON_PID_FILE") 2>/dev/null; then
            echo "✅ Daemon started (PID: \$(cat "\$DAEMON_PID_FILE"))"
        else
            echo "❌ Failed to start daemon"
            exit 1
        fi
        ;;
    stop)
        if [ -f "\$DAEMON_PID_FILE" ]; then
            PID=\$(cat "\$DAEMON_PID_FILE")
            if kill -0 "\$PID" 2>/dev/null; then
                echo "Stopping daemon (PID: \$PID)..."
                kill "\$PID"
                rm -f "\$DAEMON_PID_FILE"
                echo "✅ Daemon stopped"
            else
                echo "Daemon not running"
                rm -f "\$DAEMON_PID_FILE"
            fi
        else
            echo "Daemon not running"
        fi
        ;;
    status)
        if [ -f "\$DAEMON_PID_FILE" ] && kill -0 \$(cat "\$DAEMON_PID_FILE") 2>/dev/null; then
            echo "✅ Daemon is running (PID: \$(cat "\$DAEMON_PID_FILE"))"
        else
            echo "❌ Daemon is not running"
        fi
        ;;
    restart)
        \$0 stop
        sleep 1
        \$0 start
        ;;
    logs)
        tail -f "\$LOG_FILE"
        ;;
    *)
        echo "Usage: \$0 {start|stop|status|restart|logs}"
        exit 1
        ;;
esac
EOF

chmod +x "$PROD_DIR/service.sh"
echo "✅ Service management script created"

# Create environment setup script
echo "=== Creating environment setup ==="
cat > "$PROD_DIR/setup-env.sh" << 'EOF'
#!/bin/bash

# Source this file to set up 1Password daemon environment
export ONEPASS_TEST_DIR="'$PROD_DIR'"

echo "🔐 1Password Daemon Test Environment"
echo ""
echo "Service commands:"
echo "  $ONEPASS_TEST_DIR/service.sh start   - Start daemon"
echo "  $ONEPASS_TEST_DIR/service.sh stop    - Stop daemon"
echo "  $ONEPASS_TEST_DIR/service.sh status  - Check status"
echo "  $ONEPASS_TEST_DIR/service.sh logs    - View logs"
echo ""
echo "Client usage:"
echo "  source $ONEPASS_TEST_DIR/opt/client.sh"
echo "  source $ONEPASS_TEST_DIR/opt/helpers.sh"
echo "  op_daemon_signin"
echo "  op_daemon_status"
echo ""

alias op-prod-start="$ONEPASS_TEST_DIR/service.sh start"
alias op-prod-stop="$ONEPASS_TEST_DIR/service.sh stop"
alias op-prod-status="$ONEPASS_TEST_DIR/service.sh status"
alias op-prod-logs="$ONEPASS_TEST_DIR/service.sh logs"
EOF

echo ""
echo "🎉 Production-like daemon setup complete!"
echo ""
echo "📋 Quick Start:"
echo "  1. Start daemon:  $PROD_DIR/service.sh start"
echo "  2. Source client: source $PROD_DIR/opt/client.sh"
echo "  3. Source helpers: source $PROD_DIR/opt/helpers.sh"
echo "  4. Sign in:       op_daemon_signin"
echo ""
echo "Or source the environment:"
echo "  source $PROD_DIR/setup-env.sh"
echo ""
echo "📁 Installation location: $PROD_DIR"
echo ""
echo "⚠️  Notes:"
echo "  - This runs in user space (no sudo required)"
echo "  - Real production uses system service with onepass-svc user"
echo "  - For testing, use: account='test-account' email='test@example.com'"
echo "  - For real use, you need 1Password service account tokens"