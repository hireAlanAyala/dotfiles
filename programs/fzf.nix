{
  programs.fzf.enable = true;
  # Disable HM's auto-generated zsh integration: it emits an unguarded
  # `source <(fzf --zsh)` that runs in non-tty interactive shells (e.g. nvim's
  # `zsh -ic` for :!/system()), where fzf's option-restore throws
  # "can't change option: zle" into captured output and corrupts the clipboard.
  # fzf is instead loaded in init_extra.zsh under a `[[ -t 0 ]]` guard.
  programs.fzf.enableZshIntegration = false;
}
