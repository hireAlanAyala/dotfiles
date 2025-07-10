# symlinks.nix - Centralized symlink management for Home Manager
{ config, lib, pkgs, ... }:

{
  # Home directory symlinks
  home.file = {
    # ====================== SSH Configuration ======================
    ".ssh/config".source = ../.ssh/config;
    ".ssh/authorized_keys".source = ../.ssh/authorized_keys;
  };

  # ====================== Documentation ======================
  # Manual symlinks not managed by Home Manager (for reference):
  # ~/.azure -> /mnt/c/Users/AlanAyala/.azure
  # ~/.aws -> /mnt/c/Users/AlanAyala/.aws  
  # ~/.docker/contexts -> /mnt/c/Users/AlanAyala/.docker/contexts
}
