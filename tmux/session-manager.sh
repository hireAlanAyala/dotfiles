#!/bin/bash

# Tmux Session Manager - YAML-based session management
# Usage: session-manager.sh [command] [session_name]

CONFIG_FILE="${CONFIG_FILE:-$HOME/.config/tmux/sessions.yaml}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if session exists
session_exists() {
    local session_name="$1"
    if [[ -z "$session_name" ]]; then
        return 1
    fi
    tmux has-session -t "$session_name" 2>/dev/null
}

# Check if tmux server is running
tmux_server_running() {
    tmux list-sessions &>/dev/null
}

# Validate session name
validate_session_name() {
    local session_name="$1"
    
    if [[ -z "$session_name" ]]; then
        log_error "Session name cannot be empty"
        return 1
    fi
    
    if [[ "$session_name" =~ [[:space:]] ]]; then
        log_error "Session name '$session_name' contains spaces"
        return 1
    fi
    
    if [[ "$session_name" =~ ^[0-9]+$ ]]; then
        log_warning "Session name '$session_name' is numeric (may cause confusion)"
    fi
    
    return 0
}

# Get session configuration from YAML
get_session_config() {
    local session_name="$1"
    local field="$2"
    
    if [[ -z "$field" ]]; then
        yq ".sessions[\"$session_name\"]" "$CONFIG_FILE"
    else
        yq ".sessions[\"$session_name\"].$field" "$CONFIG_FILE"
    fi
}

# Create a single session from YAML config
create_session() {
    local session_name="$1"
    
    # Validate session name
    if ! validate_session_name "$session_name"; then
        return 1
    fi
    
    # Check if tmux server is running
    if ! tmux_server_running; then
        log_info "Starting tmux server..."
    fi
    
    # Check if session already exists
    if session_exists "$session_name"; then
        log_warning "Session '$session_name' already exists."
        return 0
    fi
    
    # Check if session is defined in config
    local session_config=$(get_session_config "$session_name")
    if [[ "$session_config" == "null" ]] || [[ -z "$session_config" ]]; then
        log_error "Session '$session_name' not found in configuration."
        log_info "Available sessions: $(yq -r ".sessions | keys[]" "$CONFIG_FILE" | tr '\n' ' ')"
        return 1
    fi
    
    # Get session details
    local description=$(yq -r ".sessions[\"$session_name\"].description" "$CONFIG_FILE")
    local directory=$(yq -r ".sessions[\"$session_name\"].directory" "$CONFIG_FILE")
    local windows_count=$(yq ".sessions[\"$session_name\"].windows | length" "$CONFIG_FILE")
    
    # Validate session configuration
    if [[ "$directory" == "null" ]]; then
        log_error "Session '$session_name' missing required field: directory"
        return 1
    fi
    
    if [[ "$windows_count" == "null" ]] || [[ "$windows_count" -eq 0 ]]; then
        log_error "Session '$session_name' has no windows defined"
        return 1
    fi
    
    # Expand environment variables in directory
    directory=$(eval echo "$directory")
    
    # Check if directory exists
    if [[ ! -d "$directory" ]]; then
        log_error "Directory does not exist: $directory"
        log_info "You may need to create the directory first: mkdir -p '$directory'"
        return 1
    fi
    
    log_info "Creating session '$session_name': $description"
    
    # Create the session in detached mode
    if ! tmux new-session -d -s "$session_name" -c "$directory" 2>/dev/null; then
        log_error "Failed to create tmux session '$session_name'"
        return 1
    fi
    
    # Create windows
    for ((i=0; i<windows_count; i++)); do
        local window_name=$(yq -r ".sessions[\"$session_name\"].windows[$i].name" "$CONFIG_FILE")
        local window_command=$(yq -r ".sessions[\"$session_name\"].windows[$i].command" "$CONFIG_FILE")
        
        # Validate window configuration
        if [[ "$window_name" == "null" ]] || [[ -z "$window_name" ]]; then
            log_error "Session '$session_name' window $i missing name"
            continue
        fi
        
        if [[ $i -eq 0 ]]; then
            # Rename the first window (created with the session)
            if ! tmux rename-window -t "$session_name:1" "$window_name" 2>/dev/null; then
                log_warning "Failed to rename first window to '$window_name'"
            fi
        else
            # Create new window
            if ! tmux new-window -t "$session_name" -n "$window_name" -c "$directory" 2>/dev/null; then
                log_error "Failed to create window '$window_name'"
                continue
            fi
        fi
        
        # Send command if specified
        if [[ "$window_command" != "null" && "$window_command" != "" ]]; then
            if ! tmux send-keys -t "$session_name:$window_name" "$window_command" Enter 2>/dev/null; then
                log_warning "Failed to send command to window '$window_name': $window_command"
            fi
        fi
    done
    
    log_success "Session '$session_name' created successfully."
}

# Create all sessions marked for auto-creation
create_auto_sessions() {
    local auto_sessions=$(yq -r ".auto_create[]" "$CONFIG_FILE")
    
    if [[ "$auto_sessions" == "null" ]]; then
        log_info "No auto-create sessions configured."
        return 0
    fi
    
    log_info "Creating auto-startup sessions..."
    
    echo "$auto_sessions" | while IFS= read -r session_name; do
        create_session "$session_name"
    done
}

# List all configured sessions
list_sessions() {
    log_info "Available session configurations:"
    echo
    
    local sessions=$(yq -r ".sessions | keys[]" "$CONFIG_FILE")
    
    echo "$sessions" | while IFS= read -r session_name; do
        local description=$(get_session_config "$session_name" "description")
        local directory=$(get_session_config "$session_name" "directory")
        local status="[NOT RUNNING]"
        
        if session_exists "$session_name"; then
            status="[RUNNING]"
        fi
        
        echo -e "  ${BLUE}$session_name${NC} $status"
        echo -e "    Description: $description"
        echo -e "    Directory: $directory"
        echo
    done
}

# Attach to default session
attach_default() {
    local default_session=$(yq -r ".default_session" "$CONFIG_FILE")
    
    if [[ "$default_session" == "null" ]]; then
        log_warning "No default session configured."
        return 1
    fi
    
    if ! session_exists "$default_session"; then
        log_info "Default session '$default_session' doesn't exist, creating it..."
        create_session "$default_session"
    fi
    
    log_info "Attaching to default session '$default_session'..."
    tmux attach -t "$default_session"
}

# Kill a session
kill_session() {
    local session_name="$1"
    
    if session_exists "$session_name"; then
        tmux kill-session -t "$session_name"
        log_success "Session '$session_name' killed."
    else
        log_warning "Session '$session_name' is not running."
    fi
}

# Show running sessions
show_running() {
    log_info "Running tmux sessions:"
    tmux list-sessions 2>/dev/null || log_warning "No tmux sessions running."
}

# Main function
main() {
    case "${1:-auto}" in
        "create")
            if [[ -z "$2" ]]; then
                log_error "Usage: $0 create <session_name>"
                exit 1
            fi
            create_session "$2"
            ;;
        "list")
            list_sessions
            ;;
        "running")
            show_running
            ;;
        "kill")
            if [[ -z "$2" ]]; then
                log_error "Usage: $0 kill <session_name>"
                exit 1
            fi
            kill_session "$2"
            ;;
        "attach")
            attach_default
            ;;
        "auto"|"")
            create_auto_sessions
            attach_default
            ;;
        "help"|"-h"|"--help")
            echo "Tmux Session Manager - YAML-based session management"
            echo
            echo "Usage: $0 [command] [session_name]"
            echo
            echo "Commands:"
            echo "  auto          Create auto-startup sessions and attach to default (default)"
            echo "  create <name> Create a specific session"
            echo "  list          List all configured sessions"
            echo "  running       Show running tmux sessions"
            echo "  kill <name>   Kill a specific session"
            echo "  attach        Attach to default session"
            echo "  help          Show this help message"
            ;;
        *)
            log_error "Unknown command: $1"
            log_info "Use '$0 help' for usage information."
            exit 1
            ;;
    esac
}

# Check dependencies
check_dependencies() {
    if ! command -v yq &> /dev/null; then
        log_error "yq is required but not installed. Please install yq to use this tool."
        exit 1
    fi
    
    if ! command -v tmux &> /dev/null; then
        log_error "tmux is required but not installed. Please install tmux to use this tool."
        exit 1
    fi
}

# Check if config file exists and is readable
check_config_file() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Please create the configuration file or run from the correct directory."
        exit 1
    fi
    
    if [[ ! -r "$CONFIG_FILE" ]]; then
        log_error "Configuration file is not readable: $CONFIG_FILE"
        exit 1
    fi
    
    # Test basic YAML syntax
    if ! yq . "$CONFIG_FILE" &>/dev/null; then
        log_error "Configuration file contains invalid YAML syntax: $CONFIG_FILE"
        log_info "Run: ~/.config/tmux/validate-sessions.sh to check for errors"
        exit 1
    fi
}

check_dependencies
check_config_file

main "$@"