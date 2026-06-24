# ~/.config/zsh/.zshenv — session env + PATH for every zsh.
# Replaces home-manager's hm-session-vars.sh (was sourced from ~/.zshenv).

typeset -U path

# PATH (formerly home.sessionPath). The two Nix entries can be dropped
# once Nix/home-manager is fully removed.
path=(
  $HOME/.local/bin
  $HOME/bin
  $HOME/go/bin
  $HOME/.cargo/bin
  $HOME/.dotnet/tools
  $HOME/.npm-global/bin
  $HOME/.bun/bin
  $HOME/.vscode/extensions/bin
  $HOME/.nix-profile/bin
  /nix/var/nix/profiles/default/bin
  $path
)

export SHELL=/usr/bin/zsh
export BUN_INSTALL="$HOME/.bun"
