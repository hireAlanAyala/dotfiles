{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    plugins = with pkgs.tmuxPlugins; [
      vim-tmux-navigator
      {
        plugin = dracula;
        extraConfig = ''
          set -g @dracula-show-powerline true
          set -g @dracula-transparent-powerline-bg true
          set -g @dracula-show-flags true
          set -g @dracula-show-left-icon session
          #set -g status-position top

          set -g @dracula-plugins "cpu-usage ram-usage"
          set -g @dracula-cpu-usage-colors "pink dark_gray"
          set -g @dracula-show-empty-plugins false
          set -g @dracula-show-edge-icons true
        '';
      }
    ];
    terminal = "tmux-256color";
    extraConfig = ''
      # WARNING: This file (tmux.conf) is managed by Nix/home-manager - DO NOT EDIT
      # To add custom configuration, edit ~/.config/tmux/editable-tmux.conf
      
      set -ga terminal-overrides ",*256col*:Tc"
      source-file ~/.config/tmux/editable-tmux.conf
    '';
  };
}
