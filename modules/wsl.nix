# wsl.nix - WSL-specific configuration for Home Manager
{ config, lib, pkgs, ... }:

{
  # WSL configuration files
  home.file = {
    # WSL global configuration (applies to all distributions)
    ".wslconfig" = {
      target = "/mnt/c/Users/AlanAyala/.wslconfig";
      text = ''
        [wsl2]
        memory=12GB
        processors=8
        swap=4GB
        localhostForwarding=true
        dns=8.8.8.8
      '';
    };

    # WSL distribution-specific configuration
    "wsl.conf" = {
      target = "/etc/wsl.conf";
      text = ''
        [automount]
        enabled = true
        root = /mnt/
        options = "metadata,umask=22,fmask=11"
        mountFsTab = true

        [interop]
        enabled = true
        # setting this to true causes executables to collide between windows/linux
        appendWindowsPath = false
      '';
    };
  };
}