{
  config,
  pkgs,
  lib,
  home-manager,
  ...
}:

# TODO:
# - add the following tools: nerdfont
# - add command for creating reports out of data

{
  nixpkgs.config.allowUnfree = true;

  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # WARNING: You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  home.packages = with pkgs; [
    # Custom derivations and scripts
    (callPackage ../derivations/discordo.nix { })
    (callPackage ../derivations/extract-otp-secrets.nix { })
    (callPackage ../derivations/mcp-chrome-bridge.nix { })
    (callPackage ../derivations/claude.nix { })
    (writeShellScriptBin "show-2fa" (builtins.readFile ../scripts/show_all_2fa.sh))
    (writeShellScriptBin "hm" (builtins.readFile ../scripts/hm.sh))
    #(writeShellScriptBin "mouse-jiggle" (builtins.readFile ../scripts/mouse-jiggle.sh))

    # core
    gcc
    unzip

    # ai
    # claude-code
    ollama

    # Development languages and runtimes
    go
    nodejs_22
    python3Packages.git-filter-repo
    temurin-bin # java openJDK
    jbang
    clojure
    leiningen
    lua
    rustc
    cargo

    # Node.js ecosystem
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.nodemon
    pnpm
    yarn-berry

    # .NET ecosystem
    dotnetCorePackages.dotnet_8.sdk
    netcoredbg
    # dotnet-sdk_8
    fsautocomplete

    # Cloud and DevOps
    azure-functions-core-tools
    azure-cli
    linode-cli
    podman
    docker
    docker-compose
    ngrok

    # Development tools
    gnumake
    air
    direnv
    tree
    keychain
    cloc
    tokei # project code statistics
    nixfmt # Nix formatter
    sops # secrets management CLI

    # Databases
    postgresql_15
    sqlite

    # data processing
    miller

    # Terminal Core
    reptyr
    ttyd

    # CLI utilities
    jq # sed but for json
    fzf
    bat
    fd
    zoxide
    ripgrep
    yq
    htop
    zbar # QR code reader
    viu # terminal image viewer
    chafa # terminal image viewer with better compatibility
    _1password-cli

    # Media and graphics
    mpv
    imagemagick

    # Communication and entertainment
    irssi
    spotify-player

    # Data tools
    visidata

    # Hardware
    arduino-cli

    # Nerd Fonts
    nerd-fonts.iosevka
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
    nerd-fonts.hack
  ];

  home.file = { };

  sops = {
    defaultSopsFile = ../secrets.yaml;
    gnupg.home = "${config.home.homeDirectory}/.gnupg";
    secrets = {
      # keys to decrypt
      hpg_plus_supabase_access_token = { };
    };
  };

  # GPG configuration for SOPS automation
  programs.gpg = {
    enable = true;
    settings = {
      use-agent = true;
      pinentry-mode = "loopback";
    };
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 28800; # 8 hours
    maxCacheTtl = 86400; # 24 hours
    enableSshSupport = true;
    extraConfig = ''
      allow-loopback-pinentry
      pinentry-program ${pkgs.pinentry-tty}/bin/pinentry-tty
    '';
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    # WARNING: This only applies to programs launched from home-manager,
    # not the whole system
    SHELL = "${pkgs.zsh}/bin/zsh";

    # API keys from SOPS secrets
    HPG_PLUS_SUPABASE_ACCESS_TOKEN = "$(cat ${config.sops.secrets.hpg_plus_supabase_access_token.path})";
  };

  home.sessionPath = [
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "$HOME/.local/bin"
    "$HOME/bin"
    "$HOME/go/bin"
    "$HOME/.cargo/bin"
    "$HOME/.dotnet/tools"
    "$HOME/.npm-global/bin"
    "$HOME/.vscode/extensions/bin"

  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Docs for programs config httd:s://nix-community.github.io/home-manager/options.html#opt-home.packages

  # PKG configurations
  imports = [
    ../programs/bash.nix
    ../programs/bat.nix
    ../programs/eza.nix
    ../programs/fzf.nix
    ../programs/ripgrep.nix
    ../programs/zoxide.nix
    ../programs/zsh.nix
    ../programs/git.nix
    ../programs/neovim.nix
    ../programs/tmux.nix
    ../programs/onepassword.nix
    # System modules
    ../modules/symlinks.nix
  ];
}
