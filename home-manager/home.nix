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
    # Shell-script wrappers still sourced from this repo.
    (writeShellScriptBin "show-2fa" (builtins.readFile ../scripts/show_all_2fa.sh))
    (writeShellScriptBin "hm" (builtins.readFile ../scripts/hm.sh))
    #(writeShellScriptBin "mouse-jiggle" (builtins.readFile ../scripts/mouse-jiggle.sh))

    # Nix tooling — goes away when home-manager itself is dropped.
    # Everything else migrated off Nix:
    #   pacman/AUR -> arch/packages-{pacman,aur}.txt
    #   mise       -> java (temurin-21), dotnet (8)
    #   npm -g     -> mcp-chrome-bridge
    #   dotnet tool -> fsautocomplete
    nixfmt # Nix formatter
  ];

  home.file = { };

  # sops = {
  #   defaultSopsFile = ../secrets.yaml;
  #   gnupg.home = "${config.home.homeDirectory}/.gnupg";
  #   secrets = {
  #     # keys to decrypt
  #     hpg_plus_supabase_access_token = { };
  #   };
  # };

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

    # API keys from SOPS secrets (disabled until sops is configured)
    # HPG_PLUS_SUPABASE_ACCESS_TOKEN = "$(cat ${config.sops.secrets.hpg_plus_supabase_access_token.path})";
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
