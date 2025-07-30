{
  # 1Password Daemon Integration for Nix Home Manager
  # Works with system-installed 1Password daemon for secure secret access
  
  # Shell aliases for 1Password daemon operations
  programs.zsh.shellAliases = {
    # Daemon-based operations (secure)
    "op-signin" = "op_interactive_signin";
    "op-status" = "op_status";
    "op-signout" = "op_daemon_signout";
    "op-get" = "op_safe_get_password";
    "op-field" = "op_safe_get_field";
    "op-list" = "op_list_formatted";
    "op-search" = "op_search";
    "op-health" = "op_health_check";
    "op-help" = "op_help";
  };
  
  # Initialize 1Password helpers in shell
  programs.zsh.initContent = ''
    # Load 1Password daemon helpers if available
    if [[ -f /opt/onepass/client.sh ]] && [[ -f ~/.config/provision/onepass-helpers.sh ]]; then
      source /opt/onepass/client.sh
      source ~/.config/provision/onepass-helpers.sh
    fi
  '';
}