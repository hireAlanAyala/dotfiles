#!/usr/bin/env bash

# Show all 2FA codes in a nvim buffer
# Uses SOPS + nix-shell for security isolation

show_all_2fa() {
    local temp_file="/tmp/2fa_codes_$(date +%s).txt"
    
    # Create header
    echo "=== 2FA Codes - $(date) ===" > "$temp_file"
    echo "" >> "$temp_file"
    
    # Use nix-shell for isolation and generate all codes
    nix-shell -p oath-toolkit yq --run "
        # Get all TOTP secrets from SOPS
        secrets=\$(sops -d ~/.config/secrets.yaml | yq '.totp_secrets // {}')
        
        # Check if we have any secrets
        if [[ \"\$secrets\" == \"{}\" || \"\$secrets\" == \"null\" ]]; then
            echo 'No TOTP secrets found in ~/.config/secrets.yaml' >> '$temp_file'
            echo 'Add them under: totp_secrets:' >> '$temp_file'
            exit 0
        fi
        
        # Generate codes for each service
        echo \"\$secrets\" | yq -r 'to_entries[] | .key + \":\" + .value' | while IFS=':' read -r service secret; do
            if [[ -n \"\$secret\" && \"\$secret\" != \"null\" ]]; then
                code=\$(oathtool --totp --base32 \"\$secret\" 2>/dev/null)
                if [[ \$? -eq 0 ]]; then
                    printf \"%-20s (%s)\n\" \"\$service:\" \"\$code\" >> '$temp_file'
                else
                    printf \"%-20s %s\n\" \"\$service:\" \"ERROR: Invalid secret\" >> '$temp_file'
                fi
            fi
        done
    "
    
    # Add footer
    echo "" >> "$temp_file"
    echo "=== Codes refresh every 30 seconds ===" >> "$temp_file"
    echo "Press :q to quit, :e! to refresh" >> "$temp_file"
    
    # Open in nvim with readonly mode
    nvim -R +"set filetype=text" +"set nonumber" +"set norelativenumber" "$temp_file"
    
    # Cleanup
    rm -f "$temp_file"
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_all_2fa
fi
