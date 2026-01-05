{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # defaultKeymap = "viins";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      # TODO: set up powerlevel10k theme
      theme = "clean";
      plugins = [ "git" "vi-mode" "web-search" ];
    };
    initContent = builtins.readFile ../zsh/init_extra.zsh;
    profileExtra = ''
      # Auto-start Hyprland via uwsm on TTY1
      if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        exec uwsm start hyprland-uwsm.desktop
      fi
    '';
  };
}
