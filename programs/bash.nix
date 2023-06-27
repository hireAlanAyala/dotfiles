# bash must be managed by home-manager so that I can force zsh as a shell on shell spawn
# can remove once I find a better way
{
  programs.bash = {
    enable = true;
    bashrcExtra = "
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

      if [ -e /home/alan/.nix-profile/etc/profile.d/nix.sh ]; then . /home/alan/.nix-profile/etc/profile.d/nix.sh; fi # added by Nix installer

      # forces zsh as default shell
      zsh
    ";
  };
}