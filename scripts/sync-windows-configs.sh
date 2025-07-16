#!/bin/bash
# Generic Windows configuration sync utility
# Usage: sync-windows-configs.sh [config_name] or sync-windows-configs.sh --all
#
# INFO: these must be synced from bash because nix can't configure windows settings
# windows cannot follow linux created symlinks
# source: https://blog.trailofbits.com/2024/02/12/why-windows-cant-follow-wsl-symlinks/

CONFIG_DIR="/home/alan/.config/windows-configs"
WINDOWS_USER="AlanAyala"

# Configuration mappings: source_file:target_path
declare -A CONFIGS=(
    ["terminal"]="$CONFIG_DIR/terminal-settings.json:/mnt/c/Users/$WINDOWS_USER/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json"
    ["wsl"]="$CONFIG_DIR/wslconfig:.wslconfig:/mnt/c/Users/$WINDOWS_USER/.wslconfig"
    # Add more configs here as needed
    # ["vscode"]="$CONFIG_DIR/vscode-settings.json:/mnt/c/Users/$WINDOWS_USER/AppData/Roaming/Code/User/settings.json"
)

sync_config() {
    local config_name="$1"
    local config_mapping="${CONFIGS[$config_name]}"
    
    if [ -z "$config_mapping" ]; then
        echo "❌ Unknown config: $config_name"
        echo "Available configs: ${!CONFIGS[@]}"
        return 1
    fi
    
    local source_file="${config_mapping%%:*}"
    local target_path="${config_mapping#*:}"
    
    
    # Regular file handling
    if [ ! -f "$source_file" ]; then
        echo "❌ Source file not found: $source_file"
        return 1
    fi
    
    # Create target directory if it doesn't exist
    local target_dir="$(dirname "$target_path")"
    mkdir -p "$target_dir" 2>/dev/null || true
    
    # Backup existing file if it exists
    if [ -f "$target_path" ]; then
        cp "$target_path" "$target_path.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    # Copy the file
    if cp "$source_file" "$target_path"; then
        echo "✅ Synced $config_name: $source_file → $target_path"
        return 0
    else
        echo "❌ Failed to sync $config_name"
        return 1
    fi
}

sync_all() {
    echo "Syncing all Windows configurations..."
    local failed=0
    
    for config_name in "${!CONFIGS[@]}"; do
        if ! sync_config "$config_name"; then
            failed=$((failed + 1))
        fi
    done
    
    if [ $failed -eq 0 ]; then
        echo "✅ All configurations synced successfully!"
    else
        echo "❌ $failed configuration(s) failed to sync"
        return 1
    fi
}

show_help() {
    echo "Usage: $0 [OPTIONS] [CONFIG_NAME]"
    echo ""
    echo "Options:"
    echo "  --all, -a     Sync all configurations"
    echo "  --list, -l    List available configurations"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "Available configurations:"
    for config in "${!CONFIGS[@]}"; do
        echo "  $config"
    done
}

list_configs() {
    echo "Available configurations:"
    for config_name in "${!CONFIGS[@]}"; do
        local config_mapping="${CONFIGS[$config_name]}"
        local source_file="${config_mapping%%:*}"
        local target_path="${config_mapping#*:}"
        local status="❌"
        
        if [ -f "$source_file" ] || [ -d "$source_file" ]; then
            status="✅"
        fi
        
        echo "  $status $config_name"
        echo "    Source: $source_file"
        echo "    Target: $target_path"
        echo ""
    done
}

# Main script logic
case "$1" in
    --all|-a)
        sync_all
        ;;
    --list|-l)
        list_configs
        ;;
    --help|-h|"")
        show_help
        ;;
    *)
        sync_config "$1"
        ;;
esac
