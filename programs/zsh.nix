{
  # WARNING: Do not enable zsh integrations here (enableCompletion, autosuggestion,
  # syntaxHighlighting, oh-my-zsh, etc). They lack TTY guards and cause
  # "can't change option: zle" warnings when running shell commands from vim (:!).
  # All zsh plugins must be loaded in init_extra.zsh with [[ -t 0 ]] guards.
  programs.zsh = {
    enable = true;
    initContent = builtins.readFile ../zsh/init_extra.zsh;
    profileExtra = ''
      # Auto-start Hyprland via uwsm on TTY1
      if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
        exec uwsm start hyprland-uwsm.desktop
      fi
    '';
  };
}
