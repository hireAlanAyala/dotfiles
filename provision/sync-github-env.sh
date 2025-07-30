#!/bin/bash
set -euo pipefail

# GitHub Actions Environment Sync Script
# This script helps synchronize the unified configuration with GitHub Actions workflows

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.env"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration file not found: $CONFIG_FILE"
    exit 1
fi

echo "=== GitHub Actions Environment Sync ==="

# Source the configuration
source "$CONFIG_FILE"

# Generate environment variables for GitHub Actions
generate_github_env() {
    echo "Generating GitHub Actions environment variables..."
    
    cat << EOF
# GitHub Actions Environment Variables (Generated from provision/config.env)
# Add these to your workflow file or use the sync mechanism in sync-env-template.yml

USERNAME=$USERNAME
SSH_PORT=$SSH_PORT
INSTANCE_LABEL=$INSTANCE_LABEL
INSTANCE_TYPE=$INSTANCE_TYPE
INSTANCE_REGION=$INSTANCE_REGION
ESSENTIAL_PACKAGES="$ESSENTIAL_PACKAGES"
SECURITY_PACKAGES="$SECURITY_PACKAGES"
SSH_WAIT_TIMEOUT=$SSH_WAIT_TIMEOUT
DELETION_WAIT_TIMEOUT=$DELETION_WAIT_TIMEOUT
RUNTIME_ENV=github-actions

# Feature flags
ENABLE_FIREWALL=$ENABLE_FIREWALL
ENABLE_FAIL2BAN=$ENABLE_FAIL2BAN
ENABLE_KERNEL_HARDENING=$ENABLE_KERNEL_HARDENING
ENABLE_SSH_HARDENING=$ENABLE_SSH_HARDENING
ENABLE_AUTO_UPDATES=$ENABLE_AUTO_UPDATES
EOF
}

# Update existing workflow files
update_workflow_files() {
    echo "Checking for workflow files to update..."
    
    local workflow_dir="$PROJECT_ROOT/.github/workflows"
    if [ -d "$workflow_dir" ]; then
        for workflow in "$workflow_dir"/*.yml "$workflow_dir"/*.yaml; do
            if [ -f "$workflow" ]; then
                echo "Found workflow: $(basename "$workflow")"
                
                # Check if it's using hardcoded values that should be from config
                if grep -q "USERNAME.*developer\|SSH_PORT.*2222\|INSTANCE_TYPE.*g6-standard-2" "$workflow"; then
                    echo "  ⚠️  This workflow appears to have hardcoded values that could use config.env"
                    echo "     Consider updating it to source provision/config.env"
                fi
            fi
        done
    else
        echo "No .github/workflows directory found"
    fi
}

# Validate configuration for GitHub Actions compatibility
validate_github_config() {
    echo "Validating configuration for GitHub Actions..."
    
    local errors=0
    
    # Check required variables
    if [ -z "$USERNAME" ]; then
        echo "❌ USERNAME is not set"
        ((errors++))
    fi
    
    if [ -z "$INSTANCE_LABEL" ]; then
        echo "❌ INSTANCE_LABEL is not set"
        ((errors++))
    fi
    
    if [ -z "$ESSENTIAL_PACKAGES" ]; then
        echo "❌ ESSENTIAL_PACKAGES is not set"
        ((errors++))
    fi
    
    # Validate instance type format
    if [[ ! "$INSTANCE_TYPE" =~ ^g6-(nanode|standard|dedicated)-.+ ]]; then
        echo "⚠️  INSTANCE_TYPE ($INSTANCE_TYPE) may not be a valid Linode instance type"
    fi
    
    # Validate region
    if [[ ! "$INSTANCE_REGION" =~ ^(us-east|us-west|eu-west|ap-south).*$ ]]; then
        echo "⚠️  INSTANCE_REGION ($INSTANCE_REGION) may not be a valid Linode region"
    fi
    
    if [ $errors -eq 0 ]; then
        echo "✅ Configuration validation passed"
    else
        echo "❌ Configuration validation failed with $errors errors"
        return 1
    fi
}

# Generate secrets template
generate_secrets_template() {
    echo "Generating GitHub Secrets template..."
    
    cat << EOF

# Required GitHub Repository Secrets
# Add these secrets to your GitHub repository settings

LINODE_API_TOKEN=your_linode_api_token_here
ROOT_PASSWORD=your_secure_password_here
GPG_PRIVATE_KEY=your_gpg_private_key_here  # Optional, for SOPS encrypted secrets

# Optional secrets (if using custom configurations)
DOTFILES_REPO=https://github.com/yourusername/dotfiles.git  # If different from current repo
EOF
}

# Show comparison between Docker and GitHub Actions environments
show_environment_comparison() {
    echo "Environment Comparison:"
    echo ""
    echo "📊 Feature Support Matrix:"
    printf "%-20s %-10s %-15s\n" "Feature" "Docker" "GitHub Actions"
    printf "%-20s %-10s %-15s\n" "---" "---" "---"
    printf "%-20s %-10s %-15s\n" "Package Install" "✅" "✅"
    printf "%-20s %-10s %-15s\n" "User Creation" "✅" "✅"  
    printf "%-20s %-10s %-15s\n" "GPG/SOPS" "✅" "✅"
    printf "%-20s %-10s %-15s\n" "SSH Hardening" "❌" "✅"
    printf "%-20s %-10s %-15s\n" "Firewall (UFW)" "❌" "✅"
    printf "%-20s %-10s %-15s\n" "Fail2ban" "❌" "✅"
    printf "%-20s %-10s %-15s\n" "Systemd Services" "❌" "✅"
    printf "%-20s %-10s %-15s\n" "Kernel Hardening" "❌" "✅"
}

# Main execution
main() {
    local action="${1:-help}"
    
    case "$action" in
        "env"|"environment")
            generate_github_env
            ;;
        "secrets")
            generate_secrets_template
            ;;
        "validate")
            validate_github_config
            ;;
        "check"|"workflows")
            update_workflow_files
            ;;
        "compare"|"comparison")
            show_environment_comparison
            ;;
        "all")
            validate_github_config
            echo ""
            generate_github_env > /tmp/github-env.txt
            echo "✅ GitHub environment variables saved to: /tmp/github-env.txt"
            echo ""
            generate_secrets_template > /tmp/github-secrets.txt
            echo "✅ GitHub secrets template saved to: /tmp/github-secrets.txt"
            echo ""
            update_workflow_files
            echo ""
            show_environment_comparison
            ;;
        "help"|*)
            cat << EOF
Usage: $0 [action]

Actions:
  env         Generate GitHub Actions environment variables
  secrets     Generate GitHub repository secrets template
  validate    Validate configuration for GitHub Actions
  workflows   Check workflow files for hardcoded values
  compare     Show feature comparison between Docker and GitHub Actions
  all         Run all checks and generate all templates
  help        Show this help message

Examples:
  $0 env > github-env.txt
  $0 validate
  $0 all
EOF
            ;;
    esac
}

main "$@"