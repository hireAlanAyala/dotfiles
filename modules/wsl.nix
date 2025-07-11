# wsl.nix - WSL-specific configuration for Home Manager
{ config, lib, pkgs, ... }:

{
  # WSL configuration files
  home.file = {
    # WSL global configuration (applies to all distributions)
    ".wslconfig" = {
      # WARNING: changes to this obj must be applied to windows file manually
      target = "/mnt/c/Users/AlanAyala/.wslconfig";
      text = ''
        [wsl2]
        memory=12GB
        processors=8
        swap=4GB
        localhostForwarding=true
        
        # Network improvements (24H2 features)
        networkingMode=mirrored
        firewall=false
        dnsTunneling=true
        dnsProxy=true
        autoMemoryReclaim=gradual
        dns=8.8.8.8
        ipv6=true
        
        # Connectivity troubleshooting
        # ignoredPorts=4000,3000,8080
        
        # Performance optimizations
        nestedVirtualization=true
        sparse=true
        pageReporting=true
        vmIdleTimeout=60000
        
        # Debugging (can be disabled in production)
        debugConsole=true
        # safeMode=true
        
        # Better systemd support
        kernelCommandLine=cgroup_no_v1=all systemd.unified_cgroup_hierarchy=1
      '';
    };

    # WSL distribution-specific configuration
    "wsl.conf" = {
      target = "/etc/wsl.conf";
      text = ''
        [automount]
        enabled = true
        root = /mnt/
        options = "metadata,uid=1000,gid=1000,umask=022,fmask=111,case=off"
        mountFsTab = true
        crossDistro = true

        [interop]
        enabled = true
        # setting this to true causes executables to collide between windows/linux
        appendWindowsPath = false

        [boot]
        systemd = true

        [user]
        default = alan

        [network]
        generateHosts = false
        generateResolvConf = true
        hostname = alan-wsl
      '';
    };
  };
}
