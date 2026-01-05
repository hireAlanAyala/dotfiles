#!/usr/bin/env zsh

# enables extra zsh glob matching features, and sets behavior to remove things that don't match the glob
setopt extended_glob null_glob


# 	$HOME/bin
# 	$HOME/.local/bin
# 	$SCRIPTS
# )

# remove duplicate entries and non-existant directories
# typeset -U path
# path=($^path(N-/))
#
# export PATH

# --------------------- SSH --------------------------
# informs gpg about the terminal connected to standard input
# this is needed for sops to succesfully use the gpg key
GPG_TTY=$(tty)
export GPG_TTY

# use esc to enter vi mode
set -o vi

# Enable zle and bind Ctrl+E to edit command line in editor
if [[ -o interactive ]]; then
    autoload -U edit-command-line
    zle -N edit-command-line
    bindkey '^e' edit-command-line
fi

export VISUAL=nvim

# Use nvim wrapper that automatically handles nested nvim detection
# The wrapper checks tmux environment and uses --remote if inside nvim
export EDITOR="$HOME/.config/scripts/nvim-prevent-nesting-wrapper.sh"

# export TERM="screen-256color"
# Only set TERM if not in tmux (tmux will set it correctly)
if [[ -z "$TMUX" ]]; then
  export TERM="xterm-256color"
fi

# ---------------------- Aliases ------------------------
alias battery='cat /sys/class/power_supply/BAT0/capacity'
alias keyboard='upower -i /org/freedesktop/UPower/devices/keyboard_dev_E4_EC_E9_C1_11_5B | grep percentage'

alias cls='printf "\e[2J\e[3J\e[H"'
alias path="echo -e ${PATH//:/\\n}"
alias fucking='sudo env "PATH=$PATH"'
alias sshgen="bash ~/.config/.ssh/generate_ssh_key.sh"
alias gpg-restart="pkill -f gpg-agent; pkill -f gpg; gpg-connect-agent /bye"
alias 2fa="show-2fa"

alias v="nvim"
alias c="~/.config/scripts/c"
alias fd='fd --hidden --no-ignore'
alias tinit="~/.config/tmux/tmux-init.sh"
alias nvim-control="$HOME/.config/scripts/nvim-control.sh"

# Docker helpers
export DOCKER_HOST=unix:///var/run/docker.sock

# Individual service shortcuts
totp-get() {
    local service="$1"
    nix-shell -p oath-toolkit yq --run "
        secret=\$(sops -d ~/.config/secrets.yaml | yq .totp_secrets.$service)
        if [[ -n \"\$secret\" && \"\$secret\" != \"null\" ]]; then
            oathtool --totp --base32 \"\$secret\"
        else
            echo \"Secret not found for: $service\"
            exit 1
        fi
    "
}

# 1Password CLI helper functions
op-quick-signin() {
    echo "⚠️  Security Warning: Manual 1Password CLI authentication"
    echo "   Any process under your user can potentially access your 1Password account"
    echo "   Consider using the 1Password app for better security"
    echo ""
    read -q "REPLY?Continue with manual authentication? (y/n): "
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        eval $(op signin)
    else
        echo "Authentication cancelled"
    fi
}

op-get-password() {
    if [[ -z "$1" ]]; then
        echo "Usage: op-get-password <item-name>"
        return 1
    fi
    op item get "$1" --fields password
}

op-get-field() {
    if [[ -z "$1" || -z "$2" ]]; then
        echo "Usage: op-get-field <item-name> <field-name>"
        return 1
    fi
    op item get "$1" --fields "$2"
}

# SSH Agent with keychain - auto-discover private keys
if command -v keychain &> /dev/null; then
    # Auto-discover private keys in ~/.ssh
    local ssh_keys=()
    for key in ~/.ssh/*; do
        if [[ -f "$key" && ! "$key" =~ \.(pub|old|backup)$ && ! "$(basename "$key")" =~ ^(known_hosts|config|authorized_keys)$ ]]; then
            ssh_keys+=($(basename "$key"))
        fi
    done
    
    if [ ${#ssh_keys[@]} -gt 0 ]; then
        eval $(keychain --eval --quiet "${ssh_keys[@]}")
    fi
fi

# PATH is handled by NIX

# Directories
export GOBIN="$HOME/.local/bin"
export GOPATH="$HOME/go/"
export GOPROXY="https://proxy.golang.org"

# clojure
export PATH=$PATH:~/.local/share/nvim/lazy/vim-iced/bin


# start ssh agent if not running
if [ -z "$SSH_AUTH_SOCK" ] || ! ps -p "$SSH_AGENT_PID" > /dev/null 2>&1; then
  eval "$(ssh-agent -s)"
  ssh-add ~/.ssh/azure_hpg 2>/dev/null
fi

# allows nix to apply shell packages when I cd into a repo with nix as the package manager
eval "$(direnv hook zsh)"

# mise - polyglot runtime manager (node, python, etc)
eval "$(mise activate zsh)"

# Allow Node to require() global npm packages
export NODE_PATH="$HOME/.npm-global/lib/node_modules"

# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
HISTSIZE="10000"
SAVEHIST="10000"

HISTFILE="$HOME/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_FCNTL_LOCK
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_IGNORE_DUPS
unsetopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
unsetopt HIST_EXPIRE_DUPS_FIRST
unsetopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# allows terminal emulator to show true color
export COLORTERM=truecolor

autoload -U colors && colors

# Docker Desktop Socket
export DOCKER_HOST=unix://$HOME/.docker/desktop/docker.sock

# Starship prompt
eval "$(starship init zsh)"

# Atuin - shell history manager
# Vanilla zsh has no concept of "session" - all shells share one history file with interleaved commands.
# Atuin tracks session metadata, so up arrow = current session only, ctrl-r = search all history.
eval "$(atuin init zsh)"

# Use clean environment for yay to avoid Nix linker conflicts
# Nix adds its own linker to PATH which can't find Arch libraries during AUR builds
# This ensures AUR packages link against system glibc, not Nix's
yay() {
    PATH="/usr/bin:/usr/local/bin:$HOME/.local/bin" command yay "$@"
}
