#!/usr/bin/env bash

# Define the source and target directories
source_dir="$HOME/.config/.ssh"
target_dir="$HOME/.ssh"

# List of files to symlink
files_to_link=("config" "known_hosts" "authorized_keys")

# Ensure the target directory exists
if [ ! -d "$target_dir" ]; then
    mkdir -p "$target_dir"
    echo "Created $target_dir directory."
fi

# Loop through the list of files and create symlinks
for file in "${files_to_link[@]}"; do
    source_file="$source_dir/$file"
    target_file="$target_dir/$file"
    
    # Check if the source file exists
    if [ -e "$source_file" ]; then
        # Backup existing file or symlink in the target directory, if any
        if [ -e "$target_file" ]; then
            mv "$target_file" "$target_file.nix-backup"
            echo "Backed up existing $file to $file.nix-backup"
        fi
        
        # Create the symlink
        ln -s "$source_file" "$target_file"
        echo "Symlink created: $target_file -> $source_file"
    else
        echo "Warning: $source_file does not exist. Skipping."
    fi
done

