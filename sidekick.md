# Tmux Terminal Persistence Strategy

## Overview
The tmux persistence implementation uses named tmux sessions combined with JSON state files for session restoration.

## Creating Persistence

### Session Creation
- **Session ID**: Generated as `"sidekick <tool_name> <sanitized_cwd>"` (session.lua:44)
- **Command**: `tmux new -A -s <session_id>` (tmux.lua:14)
  - `-A`: Attach to existing session or create new one
  - `-s`: Specify session name

### State Persistence
- **Location**: `~/.local/state/nvim/sidekick/<session_id>.json` (session.lua:14)
- **Data**: Session object containing:
  - `id`: Session identifier
  - `cwd`: Working directory 
  - `tool`: Tool name
  - `mux`: Multiplexer backend ("tmux")

## Restoring Persistence

### Session Discovery
- **List Sessions**: `tmux list-sessions -F "#{session_name}"` (tmux.lua:20)
- **Filter**: Only sessions matching `"sidekick .*"` pattern (tmux.lua:26)

### Session Restoration
1. Discover existing tmux sessions via `_sessions()` 
2. Load JSON state for each session ID using `Session.get()` (mux/init.lua:50)
3. Attach to session using `-A` flag (auto-attach/create)

## Key Strategy
- **Dual persistence**: tmux session + JSON metadata
- **Auto-attach**: tmux `-A` flag handles attach-or-create logic
- **State hydration**: JSON files restore session context beyond tmux scope

## Session Deletion Behavior

When a tmux session is deleted (via `tmux kill-session` or other means):

1. **Tmux side**: Session disappears from `tmux list-sessions` output
2. **Sidekick side**: `M.sessions()` only returns sessions that exist in both tmux AND have valid JSON state files (mux/init.lua:49-54)
3. **Orphaned state**: JSON file remains in `~/.local/state/nvim/sidekick/` but becomes inaccessible

### Pros
- **Simple implementation** - No complex cleanup logic or session monitoring
- **Fast session discovery** - Only queries active tmux sessions, ignores orphaned state
- **Fault tolerant** - Missing JSON files or dead sessions don't break the system
- **Manual recovery** - Users can manually delete state files if needed

### Cons
- **State file accumulation** - JSON files pile up in `~/.local/state/nvim/sidekick/` over time
- **Disk bloat** - No automatic cleanup means indefinite storage growth
- **Inconsistent state** - Mismatch between filesystem state and actual sessions
- **No session history** - Can't distinguish between deliberately killed vs accidentally lost sessions

## Session Updates

### Update Behavior
- **Overwrite policy**: `Session.save()` always overwrites existing JSON files (session.lua:13-16)
- **Save timing**: Only saves when mux is enabled and terminal starts (terminal.lua:129)
- **No versioning**: No backup or history of session changes

### Potential Issues
- **ID conflicts**: Multiple tools in same directory can create conflicting session IDs
- **Collision resolution**: Last session wins, previous gets silently overwritten
- **Corrupt data**: Malformed JSON files cause errors but don't self-heal (session.lua:32)
- **Schema evolution**: Tool field migration suggests ongoing data format changes (session.lua:29)

## Neovim-Tmux Integration

### Restoration Trigger
- **User action**: Restoration happens when user invokes `:Sidekick show <tool>` or similar commands
- **On-demand**: No automatic restoration on Neovim startup
- **Manual invocation**: User must explicitly request to show/attach to existing sessions

### Restoration Process
1. **Session discovery**: 
   - Execute `tmux list-sessions -F "#{session_name}"` to get active sessions
   - Filter for sessions matching `"sidekick .*"` pattern
   - Load corresponding JSON files from `~/.local/state/nvim/sidekick/<session_id>.json`
2. **Buffer creation**: 
   - `vim.api.nvim_create_buf(false, true)` creates new terminal buffer
   - Apply buffer options and keymaps for terminal interaction
3. **Tmux attachment**: 
   - `vim.fn.jobstart({"tmux", "new", "-A", "-s", session_id, ...tool_cmd})` 
   - `-A`: Attach to existing session or create if missing
   - Runs in session's original working directory (`cwd`)
4. **Terminal integration**: 
   - Neovim embeds tmux session as terminal job in the buffer
   - Sets up autocmds for `BufEnter` (auto-insert) and `TermClose` (cleanup)

### Scrollback Inheritance
- **Full inheritance**: tmux `-A` (attach) preserves complete session state including scrollback buffer
- **No Neovim buffer**: Scrollback exists only in tmux, not accessible via Neovim buffer commands
- **Tmux-native**: Use tmux copy-mode (`Ctrl-b [`) to access scrollback history
- **Fresh buffer**: Each restoration creates new Neovim terminal buffer, previous buffer content lost

### Integration Behavior
- **Separate processes**: Neovim terminal ↔ tmux session are independent processes
- **Terminal pass-through**: Neovim acts as display layer, tmux handles persistence
- **Window management**: Neovim manages window/buffer, tmux manages session/scrollback

## Attachment Strategy Comparison

### Direct Attachment (`tmux new -A`)
**Pros:**
- **Scrollback preservation**: Inherits complete tmux session state including history
- **Simplicity**: Single command handles create-or-attach logic
- **Portability**: Works anywhere tmux is installed

**Cons:**
- **Nested tmux issues**: Creates tmux-within-tmux when nvim already runs in tmux
- **Key binding conflicts**: Inner and outer tmux compete for prefix keys (Ctrl-b)
- **Terminal escape complexity**: Multiple layers of terminal interpretation
- **Resource overhead**: Redundant tmux processes running simultaneously
- **User confusion**: Unclear which tmux layer is being controlled
- **Forced switching**: Must attach to current buffer immediately
- **Single attachment**: Harder to support multiple Neovim buffers per session
- **Limited flexibility**: No custom pre/post-attach logic

### Detached Creation + Custom Attachment
**Pros:**
- **Nested tmux detection**: Custom script can detect and handle tmux nesting intelligently
- **Context-aware attachment**: Different strategies based on whether nvim is in tmux
- **Key binding isolation**: Can avoid conflicts through script logic
- **Background creation**: Can create terminal buffers without switching focus
- **Multiple attachments**: Same session can have multiple Neovim buffer connections
- **Flexible buffer management**: Conditional switching, deferred attachment
- **Smart environment handling**: Scripts can adapt to nested terminal contexts

**Cons:**
- **Scrollback loss**: New sessions start fresh, no history inheritance (less critical in nested context)
- **Script complexity**: Must handle nested tmux detection and appropriate responses
- **External dependencies**: Requires custom attachment scripts
- **Potential failure points**: Scripts can fail, have permission issues, or go missing

**Note**: In nested tmux scenarios (nvim running inside tmux), the custom script approach becomes significantly more valuable as it can avoid the pitfalls of automatic tmux nesting.

## Sidekick Author's Likely Usage Pattern

**Evidence suggests the Sidekick author is NOT running nvim inside tmux:**

1. **No nesting detection**: Uses `tmux new -A` without checking `$TMUX` environment variable
2. **No conflict handling**: No mention of key binding conflicts (Ctrl-b prefix collision)
3. **Simple session naming**: `"sidekick <tool> <cwd>"` suggests primary sessions, not nested ones
4. **Direct attachment assumption**: Implementation assumes clean terminal environment
5. **No escape complexity**: No handling of multiple terminal interpretation layers
6. **Missing nested concerns**: Documentation lacks any mention of tmux-within-tmux issues

**Likely usage pattern:**
```
Terminal → nvim → :Sidekick → tmux session (primary)
```

**vs. nested usage pattern:**
```
Terminal → tmux → nvim → terminal buffer → tmux session (nested)
```

This explains why Sidekick's simpler direct attachment works for their use case but would be problematic in nested tmux environments.

