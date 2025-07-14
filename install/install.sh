#!/bin/bash

# WARNING:
# - script doesn't check if it's ran already before adding to a file (could cause duplicate additions if ran more than once)

echo "Setting up development environment"

# TODO: detect the OS and install nix
# when installing for the first time, use this https://crates.io/crates/nix-installer

# activates hm config
# TODO: allow passing the user as an argument
# TODO: allow hm to backup existing files automatically
home-manager switch --flake ./home-manager/flake.nix#alan

# TODO: automatically login to gh cli
#
# TODO: add zsh to /etc/shells and force zsh as default shell
