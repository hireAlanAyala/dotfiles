{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # defaultKeymap = "viins";
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    oh-my-zsh = {
      enable = true;
      # TODO: set up powerlevel10k theme
      theme = "clean";
      plugins = [ "git" "vi-mode" "web-search" ];
    };
    initContent = builtins.readFile ../zsh/init_extra.zsh;
    envExtra = ''
      if [[ -z "$NVIM" ]]; then
        # Your normal Zsh setup, including ZLE
      else
        # Minimal setup for Neovim, avoiding ZLE
        unsetopt zle
      fi

    '';
  };
}
