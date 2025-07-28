# bash must be managed by home-manager so that I can force zsh as a shell on shell spawn
# can remove once I find a better way
# WARNING: running zsh at the start of a new terminal creates a bug when running nix-shell that doesn't give you access to the packages you installed. You have to exit out of zsh first.
{
  programs.bash = {
    enable = true;
    bashrcExtra = ''
      # if running bash
      if [ -n '$BASH_VERSION' ]; then
          # include .bashrc if it exists
          if [ -f '$HOME/.bashrc' ]; then
      	. '$HOME/.bashrc'
          fi
      fi

      # set PATH so it includes user's private bin if it exists
      if [ -d '$HOME/bin' ] ; then
          PATH='$HOME/bin:$PATH'
      fi

      # set PATH so it includes user's private bin if it exists
      if [ -d '$HOME/.local/bin' ] ; then
          PATH='$HOME/.local/bin:$PATH'
      fi

      # Source Nix daemon for multi-user installation
      if [ -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]; then 
        . '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'
      fi

      # forces zsh as default shell
      zsh
      chsh -s $(which zsh)
      export DOCKER_HOST=unix://$HOME/.docker/desktop/docker.sock
      export BUN_INSTALL="$HOME/.bun"
      export PATH=$BUN_INSTALL/bin:$PATH
    '';
  };
}
