{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # defaultKeymap = "viins";
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    history.extended = true;
    shellAliases = {
      work = "cd /mnt/c/Users/AlanAyala/Documents/work";
      hm = "home-manager switch --flake ~/.config/home-manager/flake.nix#alan";
      ai = "node ~/documents/terminal_ai/index.js";
      fucking = "sudo env PATH=$PATH";
    };
    oh-my-zsh = {
      enable = true;
      # TODO: set up powerlevel10k theme
      theme = "clean";
      plugins = [ "git" "vi-mode" "web-search" ];
    };
    initExtra = ''
      source <(fzf --zsh)
      HISTFILE=~/.zsh_history
      HISTSIZE=10000
      SAVEHIST=10000
      setopt appendhistory
    '';
  };
}