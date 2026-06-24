# symlinks.nix - Centralized symlink management for Home Manager
{
  config,
  lib,
  pkgs,
  ...
}:

{
  # Home directory symlinks
  home.file = {
    # ====================== SSH Configuration ======================
    ".ssh/config".source = ../.ssh/config;
    ".ssh/authorized_keys".source = ../.ssh/authorized_keys;
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
    # Global instructions preloaded into every Claude Code session on this machine.
    ".claude/CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/claude/CLAUDE.md";
  };
}
