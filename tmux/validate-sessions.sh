#!/bin/bash

# Tmux Sessions Configuration Validator
# Validates sessions.yaml for syntax and structural correctness

CONFIG_FILE="${1:-$HOME/.config/tmux/sessions.yaml}"
EXIT_CODE=0

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
    EXIT_CODE=1
}

validate_yaml_syntax() {
    log_info "Validating YAML syntax..."
    
    if ! yq . "$CONFIG_FILE" > /dev/null 2>&1; then
        log_error "Invalid YAML syntax in $CONFIG_FILE"
        return 1
    fi
    
    log_success "YAML syntax is valid"
    return 0
}

validate_required_fields() {
    log_info "Validating required fields..."
    
    # Check if sessions exist
    local sessions_exist=$(yq ".sessions" "$CONFIG_FILE")
    if [[ "$sessions_exist" == "null" ]]; then
        log_error "Missing required field: sessions"
        return 1
    fi
    
    # Check if default_session exists
    local default_session=$(yq -r ".default_session" "$CONFIG_FILE")
    if [[ "$default_session" == "null" ]]; then
        log_warning "No default_session specified"
    fi
    
    # Check if auto_create exists
    local auto_create=$(yq ".auto_create" "$CONFIG_FILE")
    if [[ "$auto_create" == "null" ]]; then
        log_warning "No auto_create sessions specified"
    fi
    
    log_success "Required fields validation passed"
    return 0
}

validate_session_structure() {
    log_info "Validating session structure..."
    
    local sessions=$(yq ".sessions | keys[]" "$CONFIG_FILE")
    local session_count=0
    
    if [[ -z "$sessions" ]]; then
        log_error "No sessions defined"
        return 1
    fi
    
    echo "$sessions" | while IFS= read -r session_name; do
        session_count=$((session_count + 1))
        log_info "Validating session: $session_name"
        
        # Check required session fields
        local description=$(yq -r ".sessions.$session_name.description" "$CONFIG_FILE")
        local directory=$(yq -r ".sessions.$session_name.directory" "$CONFIG_FILE")
        local windows=$(yq ".sessions.$session_name.windows" "$CONFIG_FILE")
        
        if [[ "$description" == "null" ]]; then
            log_warning "Session '$session_name' missing description"
        fi
        
        if [[ "$directory" == "null" ]]; then
            log_error "Session '$session_name' missing required field: directory"
        else
            # Expand environment variables for validation
            local expanded_dir=$(eval echo "$directory")
            if [[ ! -d "$expanded_dir" ]]; then
                log_warning "Session '$session_name' directory does not exist: $expanded_dir"
            fi
        fi
        
        if [[ "$windows" == "null" ]]; then
            log_error "Session '$session_name' missing required field: windows"
        else
            validate_windows_structure "$session_name"
        fi
    done
    
    log_success "Session structure validation completed"
    return 0
}

validate_windows_structure() {
    local session_name="$1"
    local windows_count=$(yq ".sessions.$session_name.windows | length" "$CONFIG_FILE")
    
    if [[ "$windows_count" -eq 0 ]]; then
        log_error "Session '$session_name' has no windows defined"
        return 1
    fi
    
    for ((i=0; i<windows_count; i++)); do
        local window_name=$(yq -r ".sessions.$session_name.windows[$i].name" "$CONFIG_FILE")
        local window_command=$(yq -r ".sessions.$session_name.windows[$i].command" "$CONFIG_FILE")
        
        if [[ "$window_name" == "null" ]]; then
            log_error "Session '$session_name' window $i missing required field: name"
        fi
        
        if [[ "$window_command" == "null" ]]; then
            log_warning "Session '$session_name' window '$window_name' has no command specified"
        fi
    done
}

validate_references() {
    log_info "Validating cross-references..."
    
    # Validate default_session reference
    local default_session=$(yq -r ".default_session" "$CONFIG_FILE")
    if [[ "$default_session" != "null" ]]; then
        local session_exists=$(yq ".sessions.$default_session" "$CONFIG_FILE")
        if [[ "$session_exists" == "null" ]]; then
            log_error "default_session '$default_session' is not defined in sessions"
        fi
    fi
    
    # Validate auto_create references
    local auto_create_sessions=$(yq ".auto_create[]" "$CONFIG_FILE" 2>/dev/null)
    if [[ -n "$auto_create_sessions" ]]; then
        echo "$auto_create_sessions" | while IFS= read -r session_name; do
            session_name=$(echo "$session_name" | tr -d '"')
            local session_exists=$(yq ".sessions.$session_name" "$CONFIG_FILE")
            if [[ "$session_exists" == "null" ]]; then
                log_error "auto_create session '$session_name' is not defined in sessions"
            fi
        done
    fi
    
    log_success "Cross-references validation passed"
    return 0
}

validate_session_names() {
    log_info "Validating session names..."
    
    local sessions=$(yq ".sessions | keys[]" "$CONFIG_FILE")
    
    echo "$sessions" | while IFS= read -r session_name; do
        session_name=$(echo "$session_name" | tr -d '"')
        
        # Check for invalid characters in session names
        if [[ "$session_name" =~ [[:space:]] ]]; then
            log_error "Session name '$session_name' contains spaces (not recommended)"
        fi
        
        if [[ "$session_name" =~ [^a-zA-Z0-9_-] ]]; then
            log_warning "Session name '$session_name' contains special characters (may cause issues)"
        fi
        
        # Check for reserved tmux session names
        if [[ "$session_name" == "0" ]] || [[ "$session_name" == "1" ]]; then
            log_warning "Session name '$session_name' is a number (may cause confusion)"
        fi
    done
    
    log_success "Session names validation completed"
    return 0
}

generate_summary() {
    log_info "Configuration Summary:"
    echo
    
    local sessions_count=$(yq ".sessions | length" "$CONFIG_FILE")
    local default_session=$(yq -r ".default_session" "$CONFIG_FILE")
    local auto_create_count=$(yq ".auto_create | length" "$CONFIG_FILE" 2>/dev/null || echo "0")
    
    echo "  Sessions defined: $sessions_count"
    echo "  Default session: $default_session"
    echo "  Auto-create sessions: $auto_create_count"
    echo
    
    if [[ "$sessions_count" -gt 0 ]]; then
        echo "  Configured sessions:"
        local sessions=$(yq ".sessions | keys[]" "$CONFIG_FILE")
        echo "$sessions" | while IFS= read -r session_name; do
            session_name=$(echo "$session_name" | tr -d '"')
            local windows_count=$(yq ".sessions.$session_name.windows | length" "$CONFIG_FILE")
            echo "    - $session_name ($windows_count windows)"
        done
    fi
}

main() {
    echo "Tmux Sessions Configuration Validator"
    echo "====================================="
    echo
    
    # Check if config file exists
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    log_info "Validating configuration file: $CONFIG_FILE"
    echo
    
    # Run validation checks
    validate_yaml_syntax || EXIT_CODE=1
    validate_required_fields || EXIT_CODE=1
    validate_session_structure || EXIT_CODE=1
    validate_references || EXIT_CODE=1
    validate_session_names || EXIT_CODE=1
    
    echo
    generate_summary
    
    echo
    if [[ $EXIT_CODE -eq 0 ]]; then
        log_success "Configuration validation passed!"
    else
        log_error "Configuration validation failed!"
    fi
    
    exit $EXIT_CODE
}

# Check if yq is available
if ! command -v yq &> /dev/null; then
    log_error "yq is required but not installed. Please install yq to use this validator."
    exit 1
fi

main "$@"