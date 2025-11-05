# symlinks.nix - Centralized symlink management for Home Manager
{
  config,
  lib,
  pkgs,
  ...
}:

let
  windowsUser = "AlanAyala";
  windowsUserPath = "/mnt/c/Users/${windowsUser}";
in
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
    "windows/Documents".source = config.lib.file.mkOutOfStoreSymlink "${windowsUserPath}/Documents";
    "windows/Downloads".source = config.lib.file.mkOutOfStoreSymlink "${windowsUserPath}/Downloads";
    "windows/Desktop".source = config.lib.file.mkOutOfStoreSymlink "${windowsUserPath}/Desktop";
    "windows/Pictures".source = config.lib.file.mkOutOfStoreSymlink "${windowsUserPath}/Pictures";
    "windows/Videos".source = config.lib.file.mkOutOfStoreSymlink "${windowsUserPath}/Videos";

    # Windows system drives
    "windows/c".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c";

    # Development folders (if they exist on Windows)
    # "windows/dev".source = config.lib.file.mkOutOfStoreSymlink "/mnt/c/dev";
    # "windows/projects".source = config.lib.file.mkOutOfStoreSymlink "${windowsUserPath}/projects";
  };

  # ====================== Docker ======================
  home.file = {
    ".docker/desktop/docker.sock".source =
      config.lib.file.mkOutOfStoreSymlink "/mnt/wsl/docker-desktop-bind-mounts/Ubuntu/docker.sock";
  };

  # ====================== Claude Code ======================
  home.file = {
    # I wonder why I symlinked specific files and not the entire folder. was it to keep claude from polluting my source files?
    ".claude/settings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/claude/settings.json";
    ".claude/.mcp.json".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/claude/.mcp.json";
    ".claude/commands".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/claude/commands";
  };

  # ====================== Documentation ======================
  # Manual symlinks not managed by Home Manager (for reference):
  # ~/.azure -> ${windowsUserPath}/.azure
  # ~/.aws -> ${windowsUserPath}/.aws
  # ~/.docker/contexts -> ${windowsUserPath}/.docker/contexts
}
