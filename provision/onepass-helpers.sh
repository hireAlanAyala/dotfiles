#!/bin/bash

# 1Password Helper Functions
# Enhanced client functions for use during installation and in daily workflows

# Source the main client library
if [[ -f /opt/onepass/client.sh ]]; then
    source /opt/onepass/client.sh
else
    echo "❌ 1Password daemon client library not found" >&2
    return 1
fi

# Interactive signin with security warning
op_interactive_signin() {
    echo "🔐 1Password Interactive Sign-in"
    echo ""
    echo "⚠️  SECURITY WARNING:"
    echo "   This will authenticate with 1Password CLI using manual credentials"
    echo "   The daemon stores session tokens in memory only, but any process"
    echo "   in the 'onepass' group can potentially access your vault"
    echo ""
    
    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Authentication cancelled"
        return 1
    fi
    
    echo ""
    read -p "Account subdomain (e.g., 'my' for my.1password.com): " account
    read -p "Email address: " email
    read -p "Secret Key: " secret_key
    echo -n "Master Password: "
    read -s password
    echo ""
    
    echo "🔄 Signing in..."
    local result=$(op_daemon_signin "$account" "$email" "$secret_key" "$password")
    local status=$(echo "$result" | jq -r '.status')
    local message=$(echo "$result" | jq -r '.message')
    
    if [[ "$status" == "success" ]]; then
        echo "✅ $message"
        return 0
    else
        echo "❌ $message"
        return 1
    fi
}

# Quick status check with formatted output
op_status() {
    local result=$(op_daemon_status)
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" != "success" ]]; then
        echo "❌ Daemon not responding"
        return 1
    fi
    
    local signed_in=$(echo "$result" | jq -r '.signed_in')
    local last_activity=$(echo "$result" | jq -r '.last_activity')
    
    if [[ "$signed_in" == "true" ]]; then
        echo "✅ Signed in (last activity: $(date -d "@$last_activity" 2>/dev/null || echo "unknown"))"
    else
        echo "❌ Not signed in"
    fi
}

# Safe password retrieval with error handling
op_safe_get_password() {
    local item="$1"
    
    if [[ -z "$item" ]]; then
        echo "Usage: op_safe_get_password 'Item Name'" >&2
        return 1
    fi
    
    # Check if signed in first
    if [[ "$(op_is_signed_in)" != "true" ]]; then
        echo "❌ Not signed in to 1Password" >&2
        echo "Run 'op_interactive_signin' first" >&2
        return 1
    fi
    
    local result=$(op_daemon_get "$item" "password")
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" == "success" ]]; then
        echo "$result" | jq -r '.data'
    else
        local error=$(echo "$result" | jq -r '.message')
        echo "❌ Failed to get password for '$item': $error" >&2
        return 1
    fi
}

# Safe field retrieval with error handling
op_safe_get_field() {
    local item="$1"
    local field="$2"
    
    if [[ -z "$item" || -z "$field" ]]; then
        echo "Usage: op_safe_get_field 'Item Name' 'field_name'" >&2
        return 1
    fi
    
    # Check if signed in first
    if [[ "$(op_is_signed_in)" != "true" ]]; then
        echo "❌ Not signed in to 1Password" >&2
        echo "Run 'op_interactive_signin' first" >&2
        return 1
    fi
    
    local result=$(op_daemon_get "$item" "$field")
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" == "success" ]]; then
        echo "$result" | jq -r '.data'
    else
        local error=$(echo "$result" | jq -r '.message')
        echo "❌ Failed to get $field for '$item': $error" >&2
        return 1
    fi
}

# List items in a formatted way
op_list_formatted() {
    local result=$(op_daemon_list)
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" == "success" ]]; then
        echo "📋 1Password Items:"
        echo "$result" | jq -r '.data[] | "  • \(.title) (\(.category))"' | sort
    else
        local error=$(echo "$result" | jq -r '.message')
        echo "❌ Failed to list items: $error" >&2
        return 1
    fi
}

# Search for items by name
op_search() {
    local query="$1"
    
    if [[ -z "$query" ]]; then
        echo "Usage: op_search 'search term'" >&2
        return 1
    fi
    
    local result=$(op_daemon_list)
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" == "success" ]]; then
        echo "🔍 Search results for '$query':"
        echo "$result" | jq -r --arg query "$query" '.data[] | select(.title | test($query; "i")) | "  • \(.title) (\(.category))"' | sort
    else
        local error=$(echo "$result" | jq -r '.message')
        echo "❌ Failed to search items: $error" >&2
        return 1
    fi
}

# Environment variable setter (useful for install scripts)
op_export_env() {
    local item="$1"
    local field="$2"
    local env_var="$3"
    
    if [[ -z "$item" || -z "$field" || -z "$env_var" ]]; then
        echo "Usage: op_export_env 'Item Name' 'field_name' 'ENV_VAR_NAME'" >&2
        return 1
    fi
    
    local value=$(op_safe_get_field "$item" "$field")
    if [[ $? -eq 0 && -n "$value" ]]; then
        export "$env_var"="$value"
        echo "✅ Exported $env_var from 1Password"
    else
        echo "❌ Failed to export $env_var" >&2
        return 1
    fi
}

# Check daemon health
op_health_check() {
    echo "🏥 1Password Daemon Health Check"
    echo ""
    
    # Check if systemd service is running
    if systemctl is-active --quiet onepass-daemon.service 2>/dev/null; then
        echo "✅ Systemd service: Running"
    else
        echo "❌ Systemd service: Not running"
        return 1
    fi
    
    # Check if socket exists
    if [[ -S "/var/run/onepass/daemon.sock" ]]; then
        echo "✅ Socket: Available"
    else
        echo "❌ Socket: Not found"
        return 1
    fi
    
    # Check daemon status
    local result=$(op_daemon_status 2>/dev/null)
    if [[ -n "$result" ]]; then
        echo "✅ Daemon: Responding"
        local signed_in=$(echo "$result" | jq -r '.signed_in // false')
        if [[ "$signed_in" == "true" ]]; then
            echo "✅ Authentication: Signed in"
        else
            echo "⚠️  Authentication: Not signed in"
        fi
    else
        echo "❌ Daemon: Not responding"
        return 1
    fi
    
    echo ""
    echo "🎉 Health check complete"
}

# Show usage help
op_help() {
    cat << 'EOF'
🔐 1Password Daemon Helper Functions

AUTHENTICATION:
  op_interactive_signin     Interactive sign-in with security warning
  op_status                 Show current authentication status
  op_daemon_signout         Sign out and clear session

ITEM OPERATIONS:
  op_safe_get_password 'Item'           Get password for item
  op_safe_get_field 'Item' 'field'     Get specific field from item
  op_list_formatted                     List all items in formatted output
  op_search 'query'                     Search items by name

UTILITY:
  op_export_env 'Item' 'field' 'VAR'   Export field as environment variable
  op_health_check                       Check daemon health
  op_help                              Show this help

EXAMPLES:
  # Sign in interactively
  op_interactive_signin
  
  # Get a password
  PASSWORD=$(op_safe_get_password 'GitHub')
  
  # Export API key for scripts
  op_export_env 'API Keys' 'openai_key' 'OPENAI_API_KEY'
  
  # Search for items
  op_search 'github'

SECURITY NOTES:
  - Session tokens stored in daemon memory only
  - 30-minute inactivity timeout
  - Restricted to 'onepass' group members
  - Daemon runs with minimal privileges
EOF
}

# Show welcome message if sourced interactively
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] && [[ -t 1 ]]; then
    echo "🔐 1Password helpers loaded. Run 'op_help' for usage information."
fi