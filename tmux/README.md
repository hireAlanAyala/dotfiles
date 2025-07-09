# Tmux Session Management

A YAML-based tmux session management system for declarative session configuration and automation.

## Overview

This system replaces hardcoded session creation scripts with a declarative YAML configuration approach, making it easy to manage, version control, and modify tmux session layouts.

## Quick Start

```bash
# Create all auto-startup sessions and attach to default
tinit

# Create a specific session
~/.config/tmux/session-manager.sh create ai

# List all configured sessions
~/.config/tmux/session-manager.sh list

# Validate configuration
~/.config/tmux/validate-sessions.sh
```

## Files

- `sessions.yaml` - Main configuration file defining all sessions
- `session-manager.sh` - Core session management script
- `validate-sessions.sh` - Configuration validation utility
- `tmux-init.sh` - Compatibility wrapper (maintains existing `tinit` behavior)

## Configuration Format

### Basic Structure

```yaml
# sessions.yaml
sessions:
  session_name:
    description: "Brief description of the session"
    directory: "/path/to/working/directory"
    windows:
      - name: "window_name"
        command: "command to run in window"
      - name: "another_window"
        command: ""  # Empty command = just open shell

default_session: "session_name"  # Session to attach to after creation
auto_create:  # Sessions to create automatically on startup
  - "session1"
  - "session2"
```

### Example Configuration

```yaml
sessions:
  ai:
    description: "AI development and chat session"
    directory: "$HOME/.config"
    windows:
      - name: "claude"
        command: "claude"

  config:
    description: "System configuration and dotfiles"
    directory: "$HOME/.config"
    windows:
      - name: "editor"
        command: "v ."

  webapp:
    description: "Web application development"
    directory: "$HOME/projects/webapp"
    windows:
      - name: "commands"
        command: ""
      - name: "server"
        command: "npm run dev"
      - name: "editor"
        command: "code ."

default_session: "config"
auto_create:
  - "ai"
  - "config"
  - "webapp"
```

## Session Manager Commands

### Create Session
```bash
~/.config/tmux/session-manager.sh create <session_name>
```
Creates a specific session from the configuration. If the session already exists, it will skip creation.

### List Sessions
```bash
~/.config/tmux/session-manager.sh list
```
Shows all configured sessions with their descriptions, directories, and running status.

### Show Running Sessions
```bash
~/.config/tmux/session-manager.sh running
```
Lists all currently running tmux sessions.

### Kill Session
```bash
~/.config/tmux/session-manager.sh kill <session_name>
```
Terminates a running session.

### Attach to Default
```bash
~/.config/tmux/session-manager.sh attach
```
Attaches to the default session (creates it if it doesn't exist).

### Auto Mode (Default)
```bash
~/.config/tmux/session-manager.sh auto
# or simply:
~/.config/tmux/session-manager.sh
```
Creates all auto-startup sessions and attaches to the default session.

## Validation

### Validate Configuration
```bash
~/.config/tmux/validate-sessions.sh
```

The validator checks for:
- **YAML syntax errors**
- **Required fields** (sessions, directories, window names)
- **Directory existence** (warns if directories don't exist)
- **Cross-references** (default_session and auto_create references)
- **Session name validity** (warns about problematic characters)
- **Configuration completeness**

### Validation Output
- 🔵 **INFO**: General information
- 🟢 **SUCCESS**: Validation passed
- 🟡 **WARNING**: Non-critical issues
- 🔴 **ERROR**: Critical problems that need fixing

## Directory Variables

Environment variables are expanded in directory paths:
- `$HOME` → `/home/username`
- `$USER` → `username`
- `${HOME}/projects` → `/home/username/projects`

## Integration with Existing Workflow

### Home Manager Integration
The system integrates with your existing Home Manager workflow:

1. Edit `sessions.yaml` to add/modify sessions
2. Run `hm` to apply changes and version control
3. Use `tinit` as usual - it automatically uses the new configuration

### Aliases and Commands
- `tinit` - Unchanged behavior, now powered by YAML config
- Your existing tmux keybindings still work
- All sessions are created with your existing tmux configuration

## Troubleshooting

### Common Issues

#### Session Creation Fails
```bash
# Check if directories exist
~/.config/tmux/validate-sessions.sh

# Verify tmux is running
tmux list-sessions

# Check specific session config
yq ".sessions.session_name" ~/.config/tmux/sessions.yaml
```

#### Window Numbering Issues
The system respects your tmux `base-index` setting. If you have `base-index 1`, windows start at 1, not 0.

#### Command Execution Problems
- Commands are executed in the session's working directory
- Environment variables are available in commands
- Commands run in the background; use `tmux attach -t session_name` to see output

#### YAML Syntax Errors
```bash
# Validate YAML syntax
~/.config/tmux/validate-sessions.sh

# Check specific YAML issues
yq . ~/.config/tmux/sessions.yaml
```

### Debug Mode
Add debug output to session manager:
```bash
# Edit session-manager.sh and add:
set -x  # Enable debug mode
```

## Advanced Usage

### Dynamic Session Creation
Create sessions on-demand without modifying the config:
```bash
# This won't work - sessions must be pre-configured
~/.config/tmux/session-manager.sh create non_existent_session
```

### Custom Session Templates
You can create template sessions in the config and modify them:
```yaml
sessions:
  template_web:
    description: "Web development template"
    directory: "$HOME/projects"
    windows:
      - name: "commands"
        command: ""
      - name: "server"
        command: "npm run dev"
      - name: "editor"
        command: "code ."
```

### Session Persistence
Sessions persist until:
- Tmux server is killed
- System reboot
- Explicit session termination

To restore sessions after reboot, run `tinit` again.

## Migration from Old System

### What Changed
- Session creation is now declarative (YAML vs. shell functions)
- Better error handling and validation
- Cross-reference validation
- Structured configuration

### What Stayed the Same
- `tinit` command behavior
- Session layouts and window arrangements
- Tmux keybindings and configuration
- Integration with Home Manager workflow

### Migration Steps
1. Your existing sessions are already configured in `sessions.yaml`
2. The old `tmux-init.sh` now calls the new session manager
3. No manual migration needed - everything works as before

## Best Practices

### Session Configuration
- Use descriptive session names (avoid numbers, spaces)
- Include meaningful descriptions
- Verify directories exist before committing config
- Group related sessions logically

### Directory Management
- Use environment variables for portable configs
- Create directories if they don't exist
- Use absolute paths for reliability

### Command Configuration
- Keep commands simple and reliable
- Use `""` for empty commands (just open shell)
- Test commands manually before adding to config

### Validation Workflow
1. Edit `sessions.yaml`
2. Run `~/.config/tmux/validate-sessions.sh`
3. Fix any errors or warnings
4. Run `hm` to apply changes
5. Test with `tinit` or specific session creation

## Version Control

The YAML configuration is tracked in your dotfiles repository:
- Changes are version controlled
- Easy to rollback problematic configs
- Portable across different machines
- Shareable session configurations

## Performance

- Session creation is fast (< 1 second per session)
- YAML parsing is minimal overhead
- No performance impact on existing tmux usage
- Validation runs independently of session creation