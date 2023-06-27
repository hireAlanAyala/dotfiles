#!/bin/bash

# WARNING:
# - script doesn't check if it's ran already before adding to a file (could cause duplicate additions if ran more than once)

echo "Setting up development environment"

# TODO: detect the OS and install nix

# activates hm config
# TODO: allow passing the user as an argument
# TODO: allow hm to backup existing files automatically
home-manager switch --flake ./home-manager/flake.nix#alan

# TODO: automatically login to gh cli
