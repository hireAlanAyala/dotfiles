
● Here's a list of dangerous operations to consider protecting against:

  System & Configuration Files

  - /etc/* - System configuration files
  - /boot/* - Boot loader and kernel files
  - /usr/bin/*, /usr/sbin/* - System binaries
  - ~/.ssh/* - SSH keys and config
  - ~/.gnupg/* - GPG keys
  - /etc/passwd, /etc/shadow - User accounts
  - /etc/sudoers - Sudo permissions

  Sensitive User Data

  - ~/.aws/*, ~/.azure/*, ~/.gcloud/* - Cloud credentials
  - ~/.kube/* - Kubernetes configs
  - ~/.docker/* - Docker credentials
  - ~/.npmrc, ~/.pypirc - Package manager tokens
  - ~/.netrc - Network credentials
  - ~/.bash_history, ~/.zsh_history - Command history
  - ~/.env, .env.* - Environment files with secrets

  Destructive Commands

  - rm -rf / or any system directory
  - dd commands (can overwrite disks)
  - mkfs.* (formats filesystems)
  - chmod -R 777 (makes everything world-writable)
  - chown -R (changes ownership recursively)
  - :(){:|:&};: (fork bomb)

  Version Control

  - .git/config - Could expose remote URLs/tokens
  - .git/hooks/* - Could inject malicious hooks
  - Force pushing to main/master branches
  - Deleting branches or tags

  Package Managers

  - Installing unknown packages via npm/pip/cargo
  - Running npm audit fix --force
  - Adding untrusted package repositories

  Network Operations

  - Opening firewall ports
  - Modifying /etc/hosts
  - Creating reverse shells
  - Downloading/executing remote scripts

  Consider creating hooks to protect against these based on your specific security needs.

╭──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╮
│ >                                                                                                                                                        │
╰──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────╯
  ? for shortcuts





