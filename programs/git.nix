{
  programs.gh = {
    enable = true;
    settings.git_protocol = "ssh";
  };

  # TODO: be able to switch github users (can potentially use gcm - git credit manager for a solution that works on github, gitlabs, and others)
  programs.git = {
    enable = true;
    userName = "Alan Walker";
    userEmail = "kanonbolt128@gmail.com";
    aliases = {
      # st = "status";
      # s = "status --short";
      # ci = "commit";
      # br = "branch";
      # co = "checkout";
      # ff = "merge --ff-only";
      # df = "diff";
      # lg = "log -p";
      # edit-unmerged =
      #   "!f() { git ls-files --unmerged | cut -f2 | sort -u ; }; emacs `f`";
      # add-unmerged =
      #   "!f() { git ls-files --unmerged | cut -f2 | sort -u ; }; git add `f`";
      # clone = "clone --recursive";
    };
    extraConfig = {
      core = {
        editor = "nvim";
        # whitespace = "trailing-space,space-before-tab";
        # excludesfile = "/home/ghedamat/.gitignore_global";
      };
      # push = { default = "tracking"; };
      # merge = {
      #   keepBackup = false;
      #   tool = "custom";
      #   #tool = "nvimdiff";
      # };
      # github = { user = "ghedamat"; };
      # color = {
      #   branch = "auto";
      #   diff = "auto";
      #   status = "auto";
      # };
      # "color \"branch\"" = {
      #   current = "yellow reverse";
      #   local = "yellow";
      #   remote = "green";
      # };
      # "color \"diff\"" = {
      #   meta = "yellow bold";
      #   frag = "magenta bold";
      #   old = "red bold";
      #   new = "green bold";
      # };
      # "color \"status\"" = {
      #   added = "yellow";
      #   changed = "green";
      #   untracked = "cyan";
      # };
      # "diff" = { tool = "nvimdiff"; };
      # "difftool" = { prompt = true; };
      # "difftool \"nvimdiff\"" = { cmd = ''nvim -d "$LOCAL" "$REMOTE"''; };

      # "mergetool" = { prompt = true; };
      # "mergetool \"nvimdiff\"" = { cmd = ''nvim -d "$LOCAL" "$REMOTE"''; };
    };
  };
}
