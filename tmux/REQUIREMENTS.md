# Tmux Session Management System - Requirements

## System Overview

A YAML-based tmux session management system that provides declarative configuration, validation, and automation for tmux session creation and management.

## Core Requirements

### 1. Configuration Management
- **YAML-based configuration** stored in `sessions.yaml`
- **Environment variable expansion** in directory paths (`$HOME`, `$USER`, etc.)
- **Version control integration** with git/Home Manager workflow
- **Backwards compatibility** with existing `tinit` command

### 2. Session Operations
- **Create sessions** from YAML configuration
- **List configured sessions** with status and descriptions
- **Auto-create sessions** on startup based on configuration
- **Attach to default session** automatically
- **Kill sessions** with proper cleanup

### 3. Validation System
- **YAML syntax validation** before processing
- **Configuration structure validation** (required fields, types)
- **Directory existence validation** with helpful error messages
- **Cross-reference validation** (default_session, auto_create references)
- **Session name validation** (no spaces, special characters)

### 4. Error Handling
- **Graceful degradation** on partial failures
- **Detailed error messages** with actionable suggestions
- **Dependency checking** (yq, tmux availability)
- **Config file validation** (existence, readability, syntax)
- **Directory validation** before session creation

## Technical Specifications

### File Structure
```
/home/alan/.config/tmux/
├── sessions.yaml          # Main configuration
├── session-manager.sh     # Core management script
├── validate-sessions.sh   # Validation utility
├── tmux-init.sh          # Compatibility wrapper
├── README.md             # User documentation
└── REQUIREMENTS.md       # This file
```

### Configuration Format
```yaml
sessions:
  session_name:
    description: "Brief description"
    directory: "/path/to/working/directory"
    windows:
      - name: "window_name"
        command: "command to run"

default_session: "session_name"
auto_create:
  - "session1"
  - "session2"
```

### Dependencies
- **yq** (version 3.x with jq-style syntax)
- **tmux** (any modern version)
- **bash** (for script execution)

## Functional Requirements

### Session Manager (`session-manager.sh`)

#### Commands
1. **`create <session_name>`** - Create specific session
2. **`list`** - Show all configured sessions with status
3. **`running`** - Show currently running tmux sessions
4. **`kill <session_name>`** - Terminate specific session
5. **`attach`** - Attach to default session
6. **`auto`** - Create auto-startup sessions and attach (default)

#### Session Creation Logic
1. Validate session name (no spaces, not empty)
2. Check if session already exists (skip if exists)
3. Validate session configuration (directory, windows exist)
4. Check directory exists (fail if missing)
5. Create tmux session in detached mode
6. Create and name windows according to configuration
7. Execute commands in respective windows
8. Report success/failure with detailed messages

#### Window Management
- **Base index awareness** - Respect tmux `base-index` setting
- **Window naming** - Use configured names or defaults
- **Command execution** - Run commands in window context
- **Error handling** - Continue on individual window failures

### Validator (`validate-sessions.sh`)

#### Validation Checks
1. **YAML Syntax** - Valid YAML structure
2. **Required Fields** - sessions, directories, window names
3. **Directory Existence** - Warn if directories missing
4. **Cross-References** - Validate default_session and auto_create
5. **Session Names** - Check for problematic characters
6. **Window Structure** - Validate window configurations

#### Output Format
- **Colored output** with INFO/SUCCESS/WARNING/ERROR levels
- **Configuration summary** with statistics
- **Exit codes** (0 = success, 1 = validation failed)

### Compatibility Layer (`tmux-init.sh`)
- **Maintain existing behavior** of `tinit` command
- **Delegate to session manager** with auto mode
- **Error handling** if session manager missing

## Non-Functional Requirements

### Performance
- **Session creation** < 2 seconds per session
- **Validation** < 1 second for typical configs
- **Memory usage** < 10MB during execution

### Reliability
- **Graceful degradation** on partial failures
- **Error recovery** with helpful messages
- **Data integrity** - No corruption of tmux state

### Usability
- **Clear error messages** with actionable suggestions
- **Consistent command interface** across all operations
- **Comprehensive documentation** with examples

### Maintainability
- **Modular design** with separate validation/management
- **Clear separation of concerns** between components
- **Extensive error handling** for edge cases

## Testing Requirements

### Smoke Test Checklist

#### Basic Functionality
- [ ] `tinit` creates all auto-startup sessions
- [ ] `tinit` attaches to default session
- [ ] Sessions have correct names and working directories
- [ ] Windows are created with proper names
- [ ] Commands execute in correct windows

#### Validation Testing
- [ ] `validate-sessions.sh` passes on valid config
- [ ] Validation catches YAML syntax errors
- [ ] Validation catches missing required fields
- [ ] Validation warns about missing directories
- [ ] Validation catches invalid cross-references

#### Error Handling
- [ ] Creating nonexistent session shows available options
- [ ] Session names with spaces are rejected
- [ ] Missing directories cause session creation to fail
- [ ] Missing dependencies are detected
- [ ] Invalid YAML syntax prevents execution

#### Edge Cases
- [ ] Hyphenated session names work correctly
- [ ] Environment variables expand properly
- [ ] Empty commands don't break window creation
- [ ] Existing sessions are skipped gracefully
- [ ] Tmux base-index setting is respected

### Test Data Setup
```bash
# Create test config
cat > /tmp/test-sessions.yaml << 'EOF'
sessions:
  test-session:
    description: "Test session"
    directory: "/tmp"
    windows:
      - name: "test"
        command: "echo hello"
      - name: "empty"
        command: ""

default_session: "test-session"
auto_create:
  - "test-session"
EOF

# Run tests
CONFIG_FILE=/tmp/test-sessions.yaml ~/.config/tmux/session-manager.sh create test-session
CONFIG_FILE=/tmp/test-sessions.yaml ~/.config/tmux/validate-sessions.sh
```

## Integration Requirements

### Home Manager Integration
- **Configuration files** managed by Home Manager
- **Scripts** available in PATH through Home Manager
- **Git tracking** of configuration changes
- **Rebuild integration** with `hm` command

### Tmux Integration
- **Respects tmux configuration** (base-index, prefix, etc.)
- **Works with existing keybindings** and plugins
- **Maintains session state** until explicit termination
- **Compatible with tmux attach/detach** workflows

### Shell Integration
- **`tinit` alias** maintains existing behavior
- **Error codes** for script integration
- **Environment variable** support for config paths

## Future Enhancement Opportunities

### Session Persistence
- **Session state saving** across reboots
- **Session restoration** with window layouts
- **Session templates** for common patterns

### Advanced Features
- **Session dependencies** (create A before B)
- **Dynamic session creation** from templates
- **Session monitoring** and health checks
- **Integration with other development tools**

### User Experience
- **Interactive session browser** with fuzzy finding
- **Session status dashboard** in tmux status bar
- **Auto-completion** for session names
- **Session history** and analytics

## Acceptance Criteria

### Must Have
1. All existing `tinit` functionality preserved
2. YAML configuration fully functional
3. Validation prevents broken configurations
4. Error handling provides actionable feedback
5. Documentation covers all use cases

### Should Have
1. Performance meets specified requirements
2. Edge cases handled gracefully
3. Integration with Home Manager seamless
4. Backwards compatibility maintained

### Could Have
1. Advanced validation features
2. Performance optimizations
3. Additional convenience commands
4. Enhanced error reporting

## Maintenance Guidelines

### Code Quality
- **Shell script best practices** (set -e, proper quoting)
- **Consistent error handling** patterns
- **Comprehensive logging** with appropriate levels
- **Modular design** for easy extension

### Documentation
- **Keep README.md updated** with configuration changes
- **Update REQUIREMENTS.md** for new features
- **Maintain inline comments** for complex logic
- **Provide examples** for common use cases

### Testing
- **Run smoke tests** after significant changes
- **Validate configuration** before committing
- **Test edge cases** identified during development
- **Verify backwards compatibility** with existing setups