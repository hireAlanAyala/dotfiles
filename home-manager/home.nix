{ config, pkgs, ... }:

# TODO: 
# - add chatgpt command
# - setup ssh
# - integrate wsl with my clipboard
# - setup a way to spin up a virtual machine from one command and code in it
# - add a way to store encrypted secrets in my git
# - add the following tools: bat, ripgrep, awk, nerdfont, python, fzf
# - add a way to switch between git users (personal, work)
# - add command for creating reports out of data
# - configure nix to import OS user settings from a git untracked file
# - change nix config to be OS agnostic
# - use a remote server to create a client - server development environment
# - add commands for OS level logging (must be able to log to a file and the terminal at the same time)
# - add OS level note taking

{
  # This value determines the Home Manager release that your configuration is
  # compatible with. This helps avoid breakage when a new Home Manager release
  # introduces backwards incompatible changes.
  #
  # You should not change this value, even if you update Home Manager. If you do
  # want to update the value, then make sure to first check the Home Manager
  # release notes.
  home.stateVersion = "23.05"; # Please read the comment before changing.

  # if a tool is project specific consider installing it with npm i -D <tool> instead of here
  home.packages = [
    pkgs.zellij
    pkgs.nodejs_20
    pkgs.nodePackages.typescript
    pkgs.nodePackages.typescript-language-server
    pkgs.docker
    pkgs.postgresql_15
    pkgs.fzf
    pkgs.bat
    
    # TODO: add node packages ->  eslint, prettier, vite-create

    # # It is sometimes useful to fine-tune packages, for example, by applying
    # # overrides. You can do that directly here, just don't forget the
    # # parentheses. Maybe you want to install Nerd Fonts with a limited number of
    # # fonts?
    # (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

    # # You can also create simple shell scripts directly inside your
    # # configuration. For example, this adds a command 'my-hello' to your
    # # environment:
    # (pkgs.writeShellScriptBin "my-hello" ''
    #   echo "Hello, ${config.home.username}!"
    # '')
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
    # EDITOR = "emacs";
  };

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  # Docs for programs config httd:s://nix-community.github.io/home-manager/options.html#opt-home.packages

  imports = [
    # TODO: only import this for linux and not macos
    ../programs/bash.nix
    ../programs/bat.nix
    ../programs/exa.nix
    ../programs/fzf.nix
    ../programs/zsh.nix
    ../programs/helix.nix
    ../programs/git.nix
    ../programs/neovim.nix

  ];

}
