{ config, pkgs, lib, home-manager, ... }:

# TODO: 
# - add chatgpt command
# - setup ssh
# - setup a way to spin up a virtual machine from one command and code in it
# - add a way to store encrypted secrets in my git
# - add the following tools: nerdfont
# - add a way to switch between git users (personal, work)
# - add command for creating reports out of data
# - configure nix to import OS user settings from a git untracked file
# - change nix config to be OS agnostic
# - use a remote server to create a client - server development environment
# - add commands for OS level logging (must be able to log to a file and the terminal at the same time)
# - add OS level note taking
# - ensure zsh is the added to sudo nano /etc/shells and set as the login shell on install chsh -s $(which zsh)

{
  # Allow unfree packages globally
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
    (callPackage ../derivations/win32yank.nix { })
    (callPackage ../derivations/discordo.nix {})
    (callPackage ../derivations/extract-otp-secrets.nix {})
    # (callPackage ../derivations/claude_code.nix {})
    # (writeShellScriptBin "claude" (builtins.readFile ../scripts/claude_code.sh))
    (writeShellScriptBin "wrapped_nvim" (builtins.readFile ../scripts/wrapped_nvim.sh))
    (writeShellScriptBin "show-2fa" (builtins.readFile ../scripts/show_all_2fa.sh))

    # ai
    claude-code
    
    # Development languages and runtimes
    go
    nodejs_20
    python3Packages.git-filter-repo
    temurin-bin # java openJDK
    jbang
    clojure
    leiningen
    lua
    
    # Node.js ecosystem
    nodePackages.typescript
    nodePackages.typescript-language-server
    nodePackages.nodemon
    pnpm
    
    # .NET ecosystem
    dotnetCorePackages.dotnet_8.sdk
    netcoredbg
    # dotnet-sdk_8
    fsautocomplete
    
    # Cloud and DevOps
    azure-functions-core-tools
    azure-cli
    docker
    docker-compose
    
    # Development tools
    air
    direnv
    tree
    sops
    keychain
    cloc
    
    # Databases
    postgresql_15
    sqlite
    
    # CLI utilities
    jq # sed but for json
    fzf
    bat
    zoxide
    ripgrep
    yq
    htop
    zbar # QR code reader
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
    
    # INFO: How to debug duplicate packages
    # sometimes a package already exists from the OS package manager
    # apt-mark showmanual (Shows packages installed manually by apt)
    # nix-env -q (Shows packages installed manually by nix-env)
    # which <package-name> (shows the path of the package, should come from nix-profile)
    # if you don't want to risk removing a package from apt, you can ensure the package is
    # referenced from nix instead of apt like this: export PATH="$HOME/.nix-profile/bin:$PATH"
    
    # TODO: add node packages ->  eslint, prettier, vite-create
    # replibyte careful this is installed locally using the native linux package manager | also been added to bin
    
    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })
  ];

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';

  };

  # You can also manage environment variables but you will have to manually
  # source
  #
  #  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
  #
  # or
  #
  #  /etc/profiles/per-user/wolfy/etc/profile.d/hm-session-vars.sh
  #
  # if you don't want to manage your shell through Home Manager.
  home.sessionVariables = {
    EDITOR = "nvim";
    # WARNING: This only applies to programs launched from home-manager,
    # not the whole system
    SHELL = "${pkgs.zsh}/bin/zsh"; 
  };

  home.sessionPath = [
    "$HOME/.nix-profile/bin"
    "/nix/var/nix/profiles/default/bin"
    "$HOME/.local/bin"
  ];

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;

  # Docs for programs config httd:s://nix-community.github.io/home-manager/options.html#opt-home.packages

  # PKG configurations
  imports = [
    # TODO: only import this for linux and not macos
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
    # System modules
    ../modules/symlinks.nix
    ../modules/wsl.nix
  ];
}
