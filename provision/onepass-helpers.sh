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

# Service account authentication check
op_check_authentication() {
    echo "🔐 1Password Service Account Authentication"
    echo ""
    
    local result=$(op_daemon_status)
    local status=$(echo "$result" | jq -r '.status')
    local authenticated=$(echo "$result" | jq -r '.authenticated')
    local auth_type=$(echo "$result" | jq -r '.auth_type')
    
    if [[ "$status" == "success" && "$authenticated" == "true" ]]; then
        echo "✅ Authenticated using $auth_type"
        return 0
    else
        echo "❌ Not authenticated - service account token required"
        echo "📋 Configure service account: sudo /opt/onepass/configure-service-account.sh"
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
    
    local authenticated=$(echo "$result" | jq -r '.authenticated')
    local auth_type=$(echo "$result" | jq -r '.auth_type')
    local last_activity=$(echo "$result" | jq -r '.last_activity')
    
    if [[ "$authenticated" == "true" ]]; then
        echo "✅ Authenticated with $auth_type (last activity: $(date -d "@$last_activity" 2>/dev/null || echo "unknown"))"
    else
        echo "❌ Not authenticated"
    fi
}

# Safe password retrieval with error handling
op_safe_get_password() {
    local item="$1"
    local vault="${2:-}"
    
    if [[ -z "$item" ]]; then
        echo "Usage: op_safe_get_password 'Item Name' [vault]" >&2
        return 1
    fi
    
    # Check if authenticated first
    if [[ "$(op_is_authenticated)" != "true" ]]; then
        echo "❌ Not authenticated with 1Password" >&2
        echo "Run 'sudo /opt/onepass/configure-service-account.sh' to configure service account" >&2
        return 1
    fi
    
    local result=$(op_daemon_get "$item" "password" "$vault")
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
    local vault="${3:-}"
    
    if [[ -z "$item" || -z "$field" ]]; then
        echo "Usage: op_safe_get_field 'Item Name' 'field_name' [vault]" >&2
        return 1
    fi
    
    # Check if authenticated first
    if [[ "$(op_is_authenticated)" != "true" ]]; then
        echo "❌ Not authenticated with 1Password" >&2
        echo "Run 'sudo /opt/onepass/configure-service-account.sh' to configure service account" >&2
        return 1
    fi
    
    local result=$(op_daemon_get "$item" "$field" "$vault")
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
    local vault="${1:-}"
    local categories="${2:-}"
    
    local result=$(op_daemon_list "$vault" "$categories")
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" == "success" ]]; then
        echo "📋 1Password Items${vault:+ in vault $vault}${categories:+ ($categories)}:"
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
    local vault="${2:-}"
    
    if [[ -z "$query" ]]; then
        echo "Usage: op_search 'search term' [vault]" >&2
        return 1
    fi
    
    local result=$(op_daemon_list "$vault")
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" == "success" ]]; then
        echo "🔍 Search results for '$query'${vault:+ in vault $vault}:"
        echo "$result" | jq -r --arg query "$query" '.data[] | select(.title | test($query; "i")) | "  • \(.title) (\(.category))"' | sort
    else
        local error=$(echo "$result" | jq -r '.message')
        echo "❌ Failed to search items: $error" >&2
        return 1
    fi
}

# List vaults in a formatted way
op_list_vaults_formatted() {
    local result=$(op_daemon_list_vaults)
    local status=$(echo "$result" | jq -r '.status')
    
    if [[ "$status" == "success" ]]; then
        echo "🗂️  Available Vaults:"
        echo "$result" | jq -r '.data[] | "  • \(.name) (ID: \(.id))"' | sort
    else
        local error=$(echo "$result" | jq -r '.message')
        echo "❌ Failed to list vaults: $error" >&2
        return 1
    fi
}

# Environment variable setter (useful for install scripts)
op_export_env() {
    local item="$1"
    local field="$2"
    local env_var="$3"
    local vault="${4:-}"
    
    if [[ -z "$item" || -z "$field" || -z "$env_var" ]]; then
        echo "Usage: op_export_env 'Item Name' 'field_name' 'ENV_VAR_NAME' [vault]" >&2
        return 1
    fi
    
    local value=$(op_safe_get_field "$item" "$field" "$vault")
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
        local authenticated=$(echo "$result" | jq -r '.authenticated // false')
        if [[ "$authenticated" == "true" ]]; then
            echo "✅ Authentication: Service account authenticated"
        else
            echo "⚠️  Authentication: Not authenticated"
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
🔐 1Password Daemon Helper Functions (Service Account)

AUTHENTICATION:
  op_check_authentication   Check service account authentication status
  op_status                  Show current authentication status
  op_daemon_signout          Clear authentication state

ITEM OPERATIONS:
  op_safe_get_password 'Item' [vault]         Get password for item
  op_safe_get_field 'Item' 'field' [vault]   Get specific field from item
  op_list_formatted [vault] [categories]      List items in formatted output
  op_search 'query' [vault]                   Search items by name
  op_daemon_list_vaults                       List available vaults

UTILITY:
  op_export_env 'Item' 'field' 'VAR' [vault] Export field as environment variable
  op_health_check                             Check daemon health
  op_help                                     Show this help

EXAMPLES:
  # Check authentication
  op_check_authentication
  
  # Get a password
  PASSWORD=$(op_safe_get_password 'GitHub')
  
  # Get password from specific vault
  PASSWORD=$(op_safe_get_password 'GitHub' 'Work')
  
  # Export API key for scripts
  op_export_env 'API Keys' 'openai_key' 'OPENAI_API_KEY'
  
  # Search for items
  op_search 'github'
  
  # List all vaults
  op_daemon_list_vaults

SERVICE ACCOUNT SETUP:
  sudo /opt/onepass/configure-service-account.sh

SECURITY NOTES:
  - Uses 1Password service account for authentication
  - Service account token stored securely on disk
  - Restricted to 'onepass' group members
  - Daemon runs with minimal privileges
EOF
}

# Show welcome message if sourced interactively
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] && [[ -t 1 ]]; then
    echo "🔐 1Password helpers loaded. Run 'op_help' for usage information."
fi