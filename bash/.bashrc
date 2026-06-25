# ~/.config/bash/.bashrc — was home-manager programs.bash.
# Login shell is already zsh; this hands off any stray interactive bash to zsh.

if [ -d "$HOME/.local/bin" ]; then PATH="$HOME/.local/bin:$PATH"; fi
if [ -d "$HOME/bin" ]; then PATH="$HOME/bin:$PATH"; fi

export DOCKER_HOST="unix://$HOME/.docker/desktop/docker.sock"
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Bare Nix is kept (single-user) for dev-shells; make its tools available.
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
  . "$HOME/.nix-profile/etc/profile.d/nix.sh"
elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

# Interactive bash -> exec into zsh.
case $- in
  *i*) command -v zsh >/dev/null 2>&1 && exec zsh ;;
esac
