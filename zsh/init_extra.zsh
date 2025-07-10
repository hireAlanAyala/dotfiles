#!/usr/bin/env zsh

echo -e "''${YELLOW_ORANGE}If sourcing this fails you might have to set zsh as the login shell. Ex: sudo nano /etc/shells, add shell then chsh -s $(which zsh)''${RESET}"
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

export VISUAL=nvim
export EDITOR=nvim
# export TERM="screen-256color"
export TERM="xterm-256color"

# ---------------------- Aliases ------------------------
alias wsl="/mnt/c/Windows/System32/wsl.exe"
alias v="nvim"
alias path="bash ~/.config/zsh/scripts/path.sh"
alias onedrive='cd /mnt/c/Users/AlanAyala/Documents/work/scripts/Upload\ New\ Storyboard\ Products\ \(NEW\)\ -\ Copy && wnpm run prod && cd -'
alias work="cd /mnt/c/Users/AlanAyala/Documents/work"
alias wnpm="/mnt/c/Program\ Files/nodejs/npm"
alias wnpx="/mnt/c/Program\ Files/nodejs/npx"
alias wgit="/mnt/c/Program\ Files/nodejs/npx"
alias wpython="/mnt/c/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Python\ 3.11"
alias clip="/mnt/c/Windows/System32/clip.exe"
alias hm='zsh ~/.config/zsh/scripts/hm.zsh'
alias fucking="sudo env PATH=$PATH"
alias gen-ssh-key="bash ~/.config/.ssh/generate_ssh_key.sh"
alias gpg-restart="pkill -f gpg-agent; pkill -f gpg; gpg-connect-agent /bye"

# 2FA aliases using SOPS + nix-shell isolation
alias 2fa="show-2fa"
alias totp="show-2fa"
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
        if [[ -f "$key" && ! "$key" =~ \.(pub|old)$ && ! "$(basename "$key")" =~ ^(known_hosts|config|authorized_keys)$ ]]; then
            ssh_keys+=($(basename "$key"))
        fi
    done
    
    if [ ${#ssh_keys[@]} -gt 0 ]; then
        eval $(keychain --eval --quiet "${ssh_keys[@]}")
    fi
fi
alias tinit="~/.config/tmux/tmux-init.sh"

# Directories
export GOBIN="$HOME/.local/bin"
export GOPATH="$HOME/go/"
export GOPROXY="https://proxy.golang.org"

# clojure
export PATH=$PATH:~/.local/share/nvim/lazy/vim-iced/bin

wcd() {
    cd $(wslpath "$1")
}

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


# warning colors for hm alias echo
YELLOW_ORANGE='\033[38;5;214m'
RESET='\033[0m'

# allows terminal emulator to show true color
export COLORTERM=truecolor

autoload -U colors && colors
