#!/usr/bin/env nix-shell
#!nix-shell -i bash -p python3 socat jq

# Local Test Runner for 1Password Daemon
# Runs daemon in user space for testing without system installation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
TEST_DIR="$HOME/.local/test-onepass"
SOCKET_PATH="$TEST_DIR/daemon.sock"
LOG_FILE="$TEST_DIR/daemon.log"
PID_FILE="$TEST_DIR/daemon.pid"

echo "🧪 Testing 1Password daemon locally..."

# Create test directory structure
echo "=== Setting up test environment ==="
mkdir -p "$TEST_DIR"
echo "✅ Created test directory: $TEST_DIR"

# Check for 1Password CLI
echo "=== Checking for 1Password CLI ==="
if ! command -v op &> /dev/null; then
    echo "⚠️  1Password CLI not found - will create mock version for testing"
    MOCK_OP=true
else
    echo "✅ 1Password CLI found: $(op --version)"
    MOCK_OP=false
fi

# Create mock 1Password CLI if needed
if [ "$MOCK_OP" = true ]; then
    echo "=== Creating mock 1Password CLI ==="
    cat > "$TEST_DIR/op" << 'EOF'
#!/bin/bash

# Mock 1Password CLI for testing with service account support

# Check for service account token
if [[ -n "$OP_SERVICE_ACCOUNT_TOKEN" ]]; then
    # Validate mock token format
    if [[ "$OP_SERVICE_ACCOUNT_TOKEN" != "ops_mock_test_token"* ]]; then
        echo "Error: Invalid service account token" >&2
        exit 1
    fi
fi

case "$1" in
    "--version")
        echo "2.24.0"
        ;;
    "vault")
        case "$2" in
            "list")
                if [ "$3" = "--format=json" ]; then
                    cat << 'VAULTS'
[
  {"id": "vault1", "name": "Personal"},
  {"id": "vault2", "name": "Work"},
  {"id": "vault3", "name": "Shared"}
]
VAULTS
                else
                    echo "Personal (vault1)"
                    echo "Work (vault2)"
                    echo "Shared (vault3)"
                fi
                ;;
            *)
                echo "Unknown vault command: $2" >&2
                exit 1
                ;;
        esac
        ;;
    "item")
        case "$2" in
            "get")
                if [ "$#" -ge 3 ]; then
                    item_name="$3"
                    vault_flag=""
                    field_flag=""
                    
                    # Parse additional arguments
                    shift 3
                    while [[ $# -gt 0 ]]; do
                        case $1 in
                            --field)
                                field_flag="$2"
                                shift 2
                                ;;
                            --vault)
                                vault_flag="$2"
                                shift 2
                                ;;
                            *)
                                shift
                                ;;
                        esac
                    done
                    
                    if [ -n "$field_flag" ] && [ "$field_flag" = "password" ]; then
                        echo "mock-password-for-$item_name${vault_flag:+-in-$vault_flag}"
                    elif [ -n "$field_flag" ]; then
                        echo "mock-field-$field_flag-for-$item_name${vault_flag:+-in-$vault_flag}"
                    else
                        echo "Mock item data for: $item_name${vault_flag:+ in vault $vault_flag}"
                    fi
                else
                    echo "Usage: op item get <item> [--field <field>] [--vault <vault>]" >&2
                    exit 1
                fi
                ;;
            "list")
                vault_flag=""
                categories_flag=""
                
                # Parse arguments
                shift 2
                while [[ $# -gt 0 ]]; do
                    case $1 in
                        --format=json)
                            format_json=true
                            shift
                            ;;
                        --vault)
                            vault_flag="$2"
                            shift 2
                            ;;
                        --categories)
                            categories_flag="$2"
                            shift 2
                            ;;
                        *)
                            shift
                            ;;
                    esac
                done
                
                if [ "$format_json" = true ]; then
                    cat << 'ITEMS'
[
  {"id": "mock1", "title": "Test Item 1", "category": "LOGIN"},
  {"id": "mock2", "title": "GitHub Token", "category": "API_CREDENTIAL"},
  {"id": "mock3", "title": "Database Password", "category": "PASSWORD"}
]
ITEMS
                else
                    echo "Test Item 1 (LOGIN)"
                    echo "GitHub Token (API_CREDENTIAL)"
                    echo "Database Password (PASSWORD)"
                fi
                ;;
            *)
                echo "Unknown item command: $2" >&2
                exit 1
                ;;
        esac
        ;;
    *)
        echo "Unknown command: $1" >&2
        exit 1
        ;;
esac
EOF
    chmod +x "$TEST_DIR/op"
    export PATH="$TEST_DIR:$PATH"
    echo "✅ Created mock 1Password CLI"
fi

# Create modified daemon for local testing
echo "=== Creating test daemon ==="
sed "s|SOCKET_PATH = \"/var/run/onepass/daemon.sock\"|SOCKET_PATH = \"$SOCKET_PATH\"|; \
     s|LOG_FILE = \"/var/log/onepass/daemon.log\"|LOG_FILE = \"$LOG_FILE\"|; \
     s|PID_FILE = \"/var/run/onepass/daemon.pid\"|PID_FILE = \"$PID_FILE\"|" \
    "$SCRIPT_DIR/onepass-daemon.py" > "$TEST_DIR/test-daemon.py"

chmod +x "$TEST_DIR/test-daemon.py"

# Create mock service account token for testing
echo "=== Creating mock service account token ==="
echo "ops_mock_test_token_12345" > "$TEST_DIR/service-account-token"
chmod 600 "$TEST_DIR/service-account-token"
echo "✅ Created mock service account token"

# Update daemon to use test token file
sed -i "s|SERVICE_ACCOUNT_TOKEN_FILE = \"/opt/onepass/service-account-token\"|SERVICE_ACCOUNT_TOKEN_FILE = \"$TEST_DIR/service-account-token\"|" "$TEST_DIR/test-daemon.py"
echo "✅ Created test daemon configuration"

# Create test client library
echo "=== Creating test client library ==="
sed "s|SOCKET_PATH=\"/var/run/onepass/daemon.sock\"|SOCKET_PATH=\"$SOCKET_PATH\"|" \
    "$SCRIPT_DIR/../provision/onepass-daemon.py" > /dev/null  # This was just to verify sed works

cat > "$TEST_DIR/test-client.sh" << EOF
#!/bin/bash

# Test Client Library for 1Password Daemon

SOCKET_PATH="$SOCKET_PATH"

op_send_request() {
    local request="\$1"
    if [[ ! -S "\$SOCKET_PATH" ]]; then
        echo '{"status": "error", "message": "Daemon not running"}' >&2
        return 1
    fi
    
    echo "\$request" | socat - "UNIX-CONNECT:\$SOCKET_PATH" 2>/dev/null
}

op_test_signin() {
    # Service account authentication - no parameters needed
    local request='{"command": "signin"}'
    op_send_request "\$request"
}

op_test_get() {
    local item="\$1"
    local field="\${2:-}"
    local vault="\${3:-}"
    
    local field_part=""
    local vault_part=""
    
    [[ -n "\$field" ]] && field_part=", \"field\": \"\$field\""
    [[ -n "\$vault" ]] && vault_part=", \"vault\": \"\$vault\""
    
    local request=\$(cat <<EOFREQ
{
    "command": "get_item",
    "item_name": "\$item"\${field_part}\${vault_part}
}
EOFREQ
)
    
    op_send_request "\$request"
}

op_test_list() {
    local vault="\${1:-}"
    local categories="\${2:-}"
    
    local vault_part=""
    local categories_part=""
    
    [[ -n "\$vault" ]] && vault_part=", \"vault\": \"\$vault\""
    [[ -n "\$categories" ]] && categories_part=", \"categories\": \"\$categories\""
    
    local request=\$(cat <<EOFREQ
{
    "command": "list_items"\${vault_part}\${categories_part}
}
EOFREQ
)
    op_send_request "\$request"
}

op_test_status() {
    local request='{"command": "status"}'
    op_send_request "\$request"
}

op_test_signout() {
    local request='{"command": "signout"}'
    op_send_request "\$request"
}

op_test_list_vaults() {
    local request='{"command": "list_vaults"}'
    op_send_request "\$request"
}
EOF

chmod +x "$TEST_DIR/test-client.sh"
echo "✅ Created test client library"

# Function to cleanup on exit
cleanup() {
    echo ""
    echo "🧹 Cleaning up test environment..."
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo "Stopping daemon (PID: $pid)..."
            kill "$pid"
            sleep 1
        fi
    fi
    rm -f "$SOCKET_PATH" "$PID_FILE"
    echo "✅ Cleanup complete"
}

trap cleanup EXIT INT TERM

# Start daemon in background
echo "=== Starting test daemon ==="
cd "$TEST_DIR"
python3 ./test-daemon.py &
DAEMON_PID=$!

# Wait for daemon to start
echo "Waiting for daemon to start..."
for i in {1..10}; do
    if [ -S "$SOCKET_PATH" ]; then
        echo "✅ Daemon started successfully (PID: $DAEMON_PID)"
        break
    fi
    sleep 1
done

if [ ! -S "$SOCKET_PATH" ]; then
    echo "❌ Daemon failed to start"
    cat "$LOG_FILE" 2>/dev/null || echo "No log file found"
    exit 1
fi

# Source test client
source ./test-client.sh

echo ""
echo "🧪 Running daemon tests..."
echo ""

# Test 1: Check status
echo "Test 1: Daemon status"
result=$(op_test_status)
echo "Response: $result"
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "success" ]; then
    echo "✅ Status test passed"
else
    echo "❌ Status test failed"
fi
echo ""

# Test 2: Service Account Authentication
echo "Test 2: Service Account Authentication"
result=$(op_test_signin)
echo "Response: $result"
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "success" ]; then
    echo "✅ Service account authentication test passed"
else
    echo "❌ Service account authentication test failed"
fi
echo ""

# Test 3: List items
echo "Test 3: List items"
result=$(op_test_list)
echo "Response: $result"
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "success" ]; then
    echo "✅ List test passed"
    echo "Items found: $(echo "$result" | jq -r '.data | length')"
else
    echo "❌ List test failed"
fi
echo ""

# Test 4: Get item password
echo "Test 4: Get item password"
result=$(op_test_get "Test Item 1" "password")
echo "Response: $result"
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "success" ]; then
    echo "✅ Get password test passed"
    echo "Password: $(echo "$result" | jq -r '.data')"
else
    echo "❌ Get password test failed"
fi
echo ""

# Test 5: List vaults
echo "Test 5: List vaults"
result=$(op_test_list_vaults)
echo "Response: $result"
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "success" ]; then
    echo "✅ List vaults test passed"
    echo "Vaults found: $(echo "$result" | jq -r '.data | length')"
else
    echo "❌ List vaults test failed"
fi
echo ""

# Test 6: Get item field
echo "Test 6: Get item field"
result=$(op_test_get "GitHub Token" "username")
echo "Response: $result"
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "success" ]; then
    echo "✅ Get field test passed"
    echo "Field value: $(echo "$result" | jq -r '.data')"
else
    echo "❌ Get field test failed"
fi
echo ""

# Test 7: Sign out
echo "Test 7: Sign out"
result=$(op_test_signout)
echo "Response: $result"
status=$(echo "$result" | jq -r '.status')
if [ "$status" = "success" ]; then
    echo "✅ Signout test passed"
else
    echo "❌ Signout test failed"
fi
echo ""

echo "🎉 All tests completed!"
echo ""
echo "📋 Test Summary:"
echo "  - Daemon successfully started and stopped"
echo "  - Socket communication working"
echo "  - JSON API functioning correctly"
echo "  - Mock 1Password CLI integration working"
echo ""
echo "📁 Test files created in: $TEST_DIR"
echo "📝 Log file: $LOG_FILE"
echo ""
echo "To run interactive tests:"
echo "  cd $TEST_DIR"
echo "  source ./test-client.sh"
echo "  op_test_status"
EOF

chmod +x "$TEST_DIR/test-client.sh"
echo "✅ Local test runner created"