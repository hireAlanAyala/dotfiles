{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    # defaultKeymap = "viins";
    enableAutosuggestions = true;
    enableSyntaxHighlighting = true;
    history.extended = true;
    shellAliases = {
      v = "nvim";
      work = "cd /mnt/c/Users/AlanAyala/Documents/work";
      wnpm = "/mnt/c/Program\\ Files/nodejs/npm";
      wnpx = "/mnt/c/Program\\ Files/nodejs/npx";
      wgit = "/mnt/c/Program\\ Files/nodejs/npx";
      clip = "/mnt/c/Windows/System32/clip.exe";
      hm = ''
        cd ~/.config &&
        git add . &&
        home-manager switch --flake ~/.config/home-manager/flake.nix#alan &&
        source ~/.zshrc &&
        cd - &&
        echo -e "''${YELLOW_ORANGE}Remember to ensure all relevant files are whitelisted in ~/.config/ .gitignore!''${RESET}"
      '';
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
    initExtra = ''
      # warning colors for hm alias echo
      YELLOW_ORANGE='\033[38;5;214m'
      RESET='\033[0m'
    '';
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
