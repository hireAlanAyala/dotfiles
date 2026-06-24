# ~/.config/zsh/.zprofile — login zsh (was home-manager programs.zsh profileExtra).

# Auto-start Hyprland via uwsm on TTY1
if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" = 1 ]; then
  exec uwsm start hyprland-uwsm.desktop
fi
