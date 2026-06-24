#!/usr/bin/env bash

# Show all 2FA codes in an nvim buffer.
# Reads base32 TOTP secrets from SOPS-encrypted ~/.config/secrets.yaml and
# generates codes with oathtool. Native (was nix-shell): needs sops,
# oath-toolkit (oathtool), and yq (go-yq) on PATH.

show_all_2fa() {
    local temp_file="/tmp/2fa_codes_$(date +%s).txt"

    echo "=== 2FA Codes - $(date) ===" > "$temp_file"
    echo "" >> "$temp_file"

    local count
    count=$(sops -d ~/.config/secrets.yaml | yq '.totp_secrets // {} | length')
    if [[ -z "$count" || "$count" == "0" ]]; then
        echo 'No TOTP secrets found in ~/.config/secrets.yaml' >> "$temp_file"
        echo 'Add them under: totp_secrets:' >> "$temp_file"
    else
        sops -d ~/.config/secrets.yaml \
            | yq '.totp_secrets // {} | to_entries | .[] | .key + ":" + .value' \
            | while IFS=':' read -r service secret; do
                [[ -n "$secret" && "$secret" != "null" ]] || continue
                if code=$(oathtool --totp --base32 "$secret" 2>/dev/null); then
                    printf "%-20s (%s)\n" "$service:" "$code" >> "$temp_file"
                else
                    printf "%-20s %s\n" "$service:" "ERROR: Invalid secret" >> "$temp_file"
                fi
            done
    fi

    echo "" >> "$temp_file"
    echo "=== Codes refresh every 30 seconds ===" >> "$temp_file"
    echo "Press :q to quit, :e! to refresh" >> "$temp_file"

    nvim -R +"set filetype=text" +"set nonumber" +"set norelativenumber" "$temp_file"

    rm -f "$temp_file"
}

# Allow direct execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_all_2fa
fi
