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

# Enable zle and bind Ctrl+V to edit command line in editor
autoload -U edit-command-line
zle -N edit-command-line
bindkey '^e' edit-command-line

export VISUAL=nvim
export EDITOR=nvim
# export TERM="screen-256color"
export TERM="xterm-256color"

# ---------------------- Aliases ------------------------
alias v="nvim"
alias path="echo -e ${PATH//:/\\n}"
alias fucking="sudo env PATH=$PATH"
alias gen-ssh-key="bash ~/.config/.ssh/generate_ssh_key.sh"
alias gpg-restart="pkill -f gpg-agent; pkill -f gpg; gpg-connect-agent /bye"
alias 2fa="show-2fa"

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
alias tinit="~/.config/tmux/tmux-init.sh"

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

# History options should be set in .zshrc and after oh-my-zsh sourcing.
# See https://github.com/nix-community/home-manager/issues/177.
HISTSIZE="10000"
SAVEHIST="10000"

HISTFILE="$HOME/.zsh_history"
mkdir -p "$(dirname "$HISTFILE")"

setopt HIST_FCNTL_LOCK
unsetopt APPEND_HISTORY
setopt HIST_IGNORE_DUPS
unsetopt HIST_IGNORE_ALL_DUPS
setopt HIST_IGNORE_SPACE
unsetopt HIST_EXPIRE_DUPS_FIRST
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# allows terminal emulator to show true color
export COLORTERM=truecolor

autoload -U colors && colors

# Docker Desktop Socket
export DOCKER_HOST=unix://$HOME/.docker/desktop/docker.sock
