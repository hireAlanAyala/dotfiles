#!/bin/bash
# Install Nix-managed fonts to Windows
# This script copies and installs fonts from Nix Home Manager to Windows

FONTS_SOURCE="$HOME/.nix-profile/share/fonts/truetype/NerdFonts"

install_fonts() {
    if [ ! -d "$FONTS_SOURCE" ]; then
        echo "❌ Nix fonts directory not found: $FONTS_SOURCE"
        echo "ℹ️  Make sure Home Manager is installed and nerd-fonts are configured"
        return 1
    fi
    
    echo "📦 Installing fonts from Nix to Windows..."
    
    # Create a temporary directory for font installation
    local temp_dir="/tmp/windows-fonts-$$"
    mkdir -p "$temp_dir"
    
    local font_count=0
    
    # Copy all .ttf files to temp directory first
    for font_dir in "$FONTS_SOURCE"/*; do
        if [ -d "$font_dir" ]; then
            for ttf_file in "$font_dir"/*.ttf; do
                if [ -f "$ttf_file" ]; then
                    cp "$ttf_file" "$temp_dir"/
                    font_count=$((font_count + 1))
                fi
            done
        fi
    done
    
    if [ $font_count -eq 0 ]; then
        echo "❌ No font files found to install"
        rm -rf "$temp_dir"
        return 1
    fi
    
    echo "Found $font_count font files to install"
    
    # Try to install fonts using PowerShell for proper registration
    echo "Installing fonts via PowerShell..."
    
    # Convert temp directory to Windows path
    local win_temp_dir=$(wslpath -w "$temp_dir")
    
    # Create PowerShell script to install fonts
    local install_script="
    Add-Type -AssemblyName System.Drawing
    \$installed = 0
    \$skipped = 0
    \$systemFontsPath = [System.Environment]::GetFolderPath('Fonts')
    \$userFontsPath = Join-Path \$env:USERPROFILE 'AppData\\Local\\Microsoft\\Windows\\Fonts'
    
    Write-Host \"Checking font directories:\"
    Write-Host \"  System: \$systemFontsPath\"
    Write-Host \"  User: \$userFontsPath\"
    Write-Host \"\"
    
    Get-ChildItem '$win_temp_dir' -Filter '*.ttf' | ForEach-Object {
        try {
            \$fontFile = \$_.Name
            \$fontPath = \$_.FullName
            \$systemTarget = Join-Path \$systemFontsPath \$fontFile
            \$userTarget = Join-Path \$userFontsPath \$fontFile
            
            # Check if font is already installed in either location
            if ((Test-Path \$systemTarget) -or (Test-Path \$userTarget)) {
                \$location = if (Test-Path \$systemTarget) { \"system\" } else { \"user\" }
                \$skipped++
                return
            }
            
            # Get font name for display
            \$fontCollection = New-Object System.Drawing.Text.PrivateFontCollection
            \$fontCollection.AddFontFile(\$fontPath)
            \$fontName = \$fontCollection.Families[0].Name
            
            # Install font (tries system first, falls back to user)
            try {
                \$shell = New-Object -ComObject Shell.Application
                \$fontsFolder = \$shell.Namespace(0x14)
                \$fontsFolder.CopyHere(\$fontPath, 0x10 + 0x4)  # 0x10 = no UI, 0x4 = no confirmation
                \$installed++
                Write-Host \"Installed: \$fontName (\$fontFile)\"
            } catch {
                Write-Host \"Failed to install \$fontFile via system folder, trying user folder...\"
                # Try user fonts folder as fallback
                if (!(Test-Path \$userFontsPath)) {
                    New-Item -ItemType Directory -Path \$userFontsPath -Force | Out-Null
                }
                Copy-Item \$fontPath \$userFontsPath -Force
                \$installed++
                Write-Host \"Installed to user folder: \$fontName (\$fontFile)\"
            }
        } catch {
            Write-Host \"Failed to install \$(\$_.Name): \$_\"
        }
    }
    Write-Host \"Successfully installed \$installed fonts, skipped \$skipped already installed\"
    "
    
    if /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -Command "$install_script"; then
        echo "✅ Fonts installed and registered successfully"
        rm -rf "$temp_dir"
        return 0
    else
        echo "❌ PowerShell installation failed, copying to Windows temp for manual install..."
        
        # Copy to Windows temp directory for manual installation
        local win_temp="/mnt/c/temp/nix-fonts"
        mkdir -p "$win_temp"
        cp "$temp_dir"/*.ttf "$win_temp"/
        
        echo "ℹ️  Fonts copied to: $(wslpath -w "$win_temp")"
        echo "ℹ️  To install manually:"
        echo "    1. Open Windows Explorer to: $(wslpath -w "$win_temp")"
        echo "    2. Select all TTF files (Ctrl+A)"
        echo "    3. Right-click and select 'Install' or 'Install for all users'"
        
        rm -rf "$temp_dir"
        return 1
    fi
}

# Show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Install Nix-managed fonts to Windows"
    echo ""
    echo "Options:"
    echo "  --help, -h    Show this help message"
    echo ""
    echo "This script installs fonts from:"
    echo "  $FONTS_SOURCE"
    echo ""
    echo "To Windows fonts directory with proper registration."
}

# Main script logic
case "$1" in
    --help|-h)
        show_help
        ;;
    *)
        install_fonts
        ;;
esac
