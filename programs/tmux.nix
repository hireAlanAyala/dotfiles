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
      {
        plugin = resurrect;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          # Use default strategy instead of session strategy
          # This will restore nvim with file arguments instead of session files
          set -g @resurrect-strategy-vim 'default'
          set -g @resurrect-strategy-nvim 'default'
          set -g @resurrect-dir '$HOME/.tmux/resurrect'
          
          # Process restoration list - simplified for NixOS
          set -g @resurrect-processes 'nvim vim ssh man less more tail top htop watch git claude'
          
          # NixOS-specific fixes for process restoration
          set -g @resurrect-save-command-strategy 'ps'
        '';
      }
      {
        # INFO: must be last in tmux plugins list
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '5'
        '';
      }
    ];
    terminal = "tmux-256color";
    extraConfig = ''
      set -ga terminal-overrides ",*256col*:Tc"
      source-file ~/.config/tmux/.tmux.conf
      
      # Additional resurrect configuration for NixOS
      set -g @resurrect-restore-processes 'nvim'
      set -g @resurrect-processes-filter 'nvim->nvim'
    '';
  };
}
