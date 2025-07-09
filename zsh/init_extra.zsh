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
# alias ai="node ~/documents/terminal_ai/index.js"
alias ai="aichat"
alias fucking="sudo env PATH=$PATH"
# SSH Key Management
alias gen-ssh-key="bash ~/.config/.ssh/generate_ssh_key.sh"
alias ssh-keyman="bash ~/.config/ssh/ssh-keyman.sh"
alias rotate-keys="bash ~/.config/ssh/rotate-keys.sh"
alias deploy-keys="bash ~/.config/ssh/deploy-keys.sh"
alias backup-ssh="bash ~/.config/ssh/backup-restore.sh"
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
