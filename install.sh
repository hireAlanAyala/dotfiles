#!/bin/bash

# Ask for the username
echo "Enter your username:"
read username

# Ask for the home directory
echo "Enter your home directory:"
read homeDirectory

# Create the Nix file
echo "{ username = \"$username\"; homeDirectory = \"$homeDirectory\"; }" > user-config.nix
