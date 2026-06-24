# ~/.config/zsh/.zshrc — interactive zsh (was home-manager programs.zsh).
# All real configuration lives in init_extra.zsh.

typeset -U path cdpath fpath manpath

source ~/.config/zsh/init_extra.zsh

# Keep the gpg-agent pointed at the current TTY for pinentry.
export GPG_TTY=$TTY
gpg-connect-agent --quiet updatestartuptty /bye >/dev/null 2>&1
