# Dotfiles Project Improvement Suggestions

# WSL
enable system d (think it will need a fresh nix install)

# claude code
install with nix instead of npm

## Development Workflow
- **Config validation**: Test configurations in isolation before applying

## Tool Integration
- **Direnv integration**: Per-project development environments
- **Nix-shell templates**: Common development shells for different languages
- **Docker/Podman**: Container development workflow integration

## Monitoring & Debugging
- **Home Manager generations cleanup**: Auto-remove old generations

## Security Enhancements
- **SOPS key rotation**: Automated secret rotation workflow
- **SSH key management**: Centralized key generation and rotation
- **Audit logging**: Track configuration changes and access

## Quality of Life
- **Fuzzy config search**: Quick access to configuration files
- **Interactive setup**: Guided first-time setup script
- **Config diffing**: Easy comparison between generations
