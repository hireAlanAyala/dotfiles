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
      resurrect
      {
        # INFO: must be last in tmux plugins list
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-strategy-vim 'session'
          set -g @resurrect-strategy-nvim 'session'
          set -g @resurrect-save-command-strategy 'nvim'
          # Fallback: capture full command for neovim restoration  
          set -g @resurrect-strategy-irb 'default'
          set -g @resurrect-save-shell-history 'on'
          set -g @resurrect-processes 'ssh vim nvim man less more tail top htop watch git "~nvim->nvim" "~vim->vim"'
          set -g @resurrect-hook-pre-restore-pane-processes 'tmux send-keys -t %1 "nvim" Enter'
          set -g @resurrect-hook-post-save-all 'eval $(echo "$SSH_AUTH_SOCK")'
          set -g @resurrect-dir '$HOME/.tmux/resurrect'
          set -g @resurrect-delete-backup-after '30'
          set -g @resurrect-pane-title 'on'
        '';
      }
    ];
    extraConfig = ''
      source-file ~/.config/tmux/.tmux.conf
    '';
  };
}
