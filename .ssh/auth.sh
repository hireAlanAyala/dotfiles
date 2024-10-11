#!/usr/bin/env bash

# reads decrypted secrets into memory without storing them
decrypted=$(sops -d secrets.yaml)

echo "$decrypted"

ssh_key=$(echo "$decrypted" | yq '.ssh_private_key')
github_token=$(echo "$decrypted" | yq '.github_token')

# Write a function that iterates through all the keys in decrypted, grabs keys that start with ssh_private_key
# and adds a private key file and a public key file into ~/.ssh using ssh_private_key<rest of name> as the file name
# echo "$ssh_key" > ~/.ssh/id_rsa
# chmod 600 ~/.ssh/id_rsa

# Example 2: Authenticate GitHub CLI with the extracted token
# echo "$github_token" | gh auth login --with-token

# Step 4: Clean up (nothing to delete since we didn’t write to disk)
# If you wrote any secrets to files (like SSH keys), ensure correct permissions are set, and avoid leaving decrypted files behind.

