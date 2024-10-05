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
      wnpm = "/mnt/c/Program\\ Files/nodejs/npm";
      wnpx = "/mnt/c/Program\\ Files/nodejs/npx";
      wgit = "/mnt/c/Program\\ Files/nodejs/npx";
      hm = "home-manager switch --flake ~/.config/home-manager/flake.nix#alan";
      ai = "node ~/documents/terminal_ai/index.js";
      fuckingInit = "sudo dockerd";
      fucking = "sudo env PATH=$PATH";
    };
    oh-my-zsh = {
      enable = true;
      # TODO: set up powerlevel10k theme
      theme = "clean";
      plugins = [ "git" "vi-mode" "web-search" ];
    };
  };
}