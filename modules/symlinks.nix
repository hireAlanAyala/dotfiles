# symlinks.nix - Centralized symlink management for Home Manager
{ config, lib, pkgs, ... }:

{
  # Home directory symlinks
  home.file = {
    # ====================== SSH Configuration ======================
    ".ssh/config".source = ../.ssh/config;
    ".ssh/authorized_keys".source = ../.ssh/authorized_keys;
  };

  # ====================== Windows Interop Symlinks ======================
  # Organized Windows folder integration under ~/windows/ directory
  home.file = {
    # Windows user folders
    "windows/Documents".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/Users/AlanAyala/Documents";
    "windows/Downloads".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/Users/AlanAyala/Downloads";
    "windows/Desktop".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/Users/AlanAyala/Desktop";
    "windows/Pictures".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/Users/AlanAyala/Pictures";
    "windows/Videos".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/Users/AlanAyala/Videos";
    
    # Windows system drives
    "windows/c".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c";
    
    # Development folders (if they exist on Windows)
    # "windows/dev".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/dev";
    # "windows/projects".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/Users/AlanAyala/projects";
  };

  # ====================== Documentation ======================
  # Manual symlinks not managed by Home Manager (for reference):
  # ~/.azure -> /mnt/c/Users/AlanAyala/.azure
  # ~/.aws -> /mnt/c/Users/AlanAyala/.aws  
  # ~/.docker/contexts -> /mnt/c/Users/AlanAyala/.docker/contexts
}
