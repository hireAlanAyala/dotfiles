# CLAUDE.md - Codebase Architecture Guide

## Overview

This is a **personal dotfiles configuration repository** built around **Nix Home Manager** for managing development environment configurations in a declarative way. The codebase is designed for a Linux development environment and follows a modular architecture with extensive customization for development workflows.

## Codebase Type
- **Personal Dotfiles Repository** - Configuration management for development environment
- **Nix/Home Manager Based** - Declarative system configuration
- **Linux Focused** - Optimized for Linux development
- **Multi-language Development** - Supports Go, Node.js, Python, Java, Clojure, C#/.NET

## Architecture Overview

### Core Structure
```
/home/alan/.config/
├── home-manager/          # Main Nix flake configuration
│   ├── flake.nix         # Flake definition with inputs/outputs
│   ├── home.nix          # Main home-manager configuration
│   └── flake.lock        # Locked dependency versions
├── programs/             # Modular program configurations
├── derivations/          # Custom Nix package derivations
├── scripts/              # Shell scripts and utilities
├── zsh/                  # Zsh configuration and scripts
└── [tool-configs]/       # Individual tool configurations
```

### Key Components

1. **Home Manager Core** (`home-manager/`)
   - `flake.nix`: Defines the Nix flake with nixpkgs and home-manager inputs
   - `home.nix`: Main configuration importing program modules and declaring packages
   - Supports multiple users (alan, wolfy) with different configurations

2. **Modular Program Configurations** (`programs/`)
   - Each tool has its own `.nix` file for configuration
   - Examples: `git.nix`, `zsh.nix`, `neovim.nix`, `helix.nix`, `tmux.nix`
   - Imported via the `imports` section in `home.nix`

3. **Custom Derivations** (`derivations/`)
   - Custom Nix packages not available in nixpkgs
   - Examples: `aichat.nix`, `claude_code.nix`, `discordo.nix`
   - Built and installed as part of the home-manager configuration

4. **Scripts** (`scripts/`)
   - `claude_code.sh`: Wrapper for Claude Code CLI installation/execution
   - `wrapped_nvim.sh`: Neovim wrapper script
   - `setup-zsh.sh`: Zsh setup utilities

5. **Shell Configuration** (`zsh/`)
   - `init_extra.zsh`: Main zsh configuration with aliases, exports, and functions
   - `scripts/hm.zsh`: Home Manager update script
   - `scripts/path.sh`: Path management utilities

## Package Management

### Primary: Nix Home Manager
- **Declarative Configuration**: All packages declared in `home.nix`
- **Reproducible Builds**: Locked dependencies via `flake.lock`
- **Cross-platform**: Works on Linux and macOS
- **Rollback Support**: `home-manager generations` for environment history

### Package Categories
- **Development Tools**: go, nodejs, python, java, clojure, dotnet
- **CLI Utilities**: ripgrep, fzf, bat, zoxide, jq, htop
- **Editors**: neovim (kickstart.nvim), helix
- **Terminal**: tmux, zsh, oh-my-zsh
- **Cloud/DevOps**: azure-cli, docker, docker-compose
- **Databases**: postgresql, sqlite

## Development Workflows

### Primary Workflow
1. **Edit Configuration**: Modify files in `/home/alan/.config/`
2. **Apply Changes**: Run `hm` alias (executes `zsh/scripts/hm.zsh`)
3. **Automatic**: Git stages all changes and runs `home-manager switch`
4. **Reload**: Sources `.zshrc` and provides success feedback

### Key Commands
- `hm`: Update home-manager configuration
- `claude`: Run Claude Code CLI
- `v`/`nvim`: Neovim editor
- `tinit`: Initialize tmux session

## Editor Configurations

### Neovim (Primary)
- **Base**: kickstart.nvim configuration
- **Location**: `/home/alan/.config/nvim/`
- **Features**: LSP, TreeSitter, Telescope, Git integration
- **Managed**: Via Home Manager with minimal wrapper

### Helix (Secondary)
- **Theme**: Custom "mytheme" with fleet_dark inheritance
- **Features**: Relative line numbers, LSP, custom keybindings
- **Vi-mode**: Insert mode with 'jk' to normal mode

## Build/Deployment System

### Nix Flakes
- **Build System**: Nix with flake.nix configuration
- **Deployment**: Home Manager switch applies configuration
- **Testing**: `nix-build` for individual derivations
- **Updates**: `nix flake update` to update dependencies

### Installation Process
1. Run `./install.sh` - Applies home-manager configuration
2. Configure GitHub CLI authentication
3. Set up GPG for encrypted secrets (SOPS)
4. Configure SSH keys for various services

## Security & Secrets Management

### SOPS (Secrets OPerationS)
- **File**: `secrets.yaml` - Encrypted secrets storage
- **Keys**: SSH private keys, API tokens, Discord auth
- **Encryption**: Age/PGP encryption for git-safe secret storage
- **Usage**: GPG_TTY properly configured for terminal access

### SSH Configuration
- Multiple SSH keys for different services (GitHub, Azure, Linode)
- Automatic SSH agent startup in zsh configuration
- Key generation script: `gen-ssh-key` alias

## Testing Framework
- **None Currently**: No formal testing framework
- **Validation**: Nix build system provides compile-time validation
- **Testing**: Manual testing via `nix-build` for derivations

## Common Development Patterns

### Adding New Tools
1. Add package to `home.nix` packages list
2. Create configuration file in `programs/` if needed
3. Add to imports in `home.nix`
4. Run `hm` to apply changes

### Custom Software
1. Create derivation in `derivations/`
2. Add to `home.nix` with `callPackage`
3. Test with `nix-build`

### Script Integration
1. Create script in `scripts/`
2. Add to `home.nix` with `writeShellScriptBin`
3. Available as command after `hm`

## Notable Features

### Multi-Environment Support
- Personal and work configurations
- Different git users (TODO: implement switching)
- Environment-specific paths and settings

### Development Languages Supported
- **Go**: Full toolchain with air for hot reloading
- **Node.js**: TypeScript, pnpm, development tools
- **Python**: Python 3 with development packages
- **Java**: OpenJDK with Clojure and Leiningen
- **C#/.NET**: .NET 8 SDK with debugger and F# support
- **Rust**: Available through system package manager

## Current TODOs & Roadmap
- VM development environment automation
- Git user switching mechanism
- OS-agnostic configuration
- Client-server development environment
- OS-level logging and note-taking
- Nerd font integration
- Pre-commit hooks and automation

## Important Files for Claude Code Instances

### Essential Configuration Files
- `/home/alan/.config/home-manager/home.nix` - Main configuration
- `/home/alan/.config/zsh/init_extra.zsh` - Shell environment
- `/home/alan/.config/programs/` - Tool-specific configurations
- `/home/alan/.config/scripts/` - Utility scripts
- `/home/alan/.config/secrets.yaml` - Encrypted secrets (SOPS)

### Key Scripts
- `hm`: Home Manager update workflow
- `claude`: Claude Code CLI wrapper
- `tinit`: tmux session initialization

### Documentation
- `/home/alan/.config/readme/install.md` - Installation instructions
- `/home/alan/.config/home-manager/notes.md` - Home Manager usage notes
- `/home/alan/.config/readme/ssh.md` - SSH configuration guide

This architecture provides a robust, declarative, and reproducible development environment that can be version-controlled and easily replicated across different machines.
