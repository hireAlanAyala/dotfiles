# Shell commands: no inline comments

Never put inline `#` comments in shell commands or command blocks meant to be
copy-pasted. This user's zsh does not treat `#` as a comment interactively, so an
inline comment breaks the paste. Keep code blocks as pure runnable commands and
put any explanation in prose before or after the block — not on the command line.

Bad:
```
cp ../other/.env .                # gitignored; points at Hono :3001
```
Good (explain in prose, keep the command clean):
```
cp ../other/.env .
```

# Inspecting terminal output (nvim terminal logs)

This machine runs an nvim `terminal-persist` plugin that streams each terminal's
output to a log file, so you can read what commands were run and what servers
printed without asking the user to copy-paste.

**To find the output of a terminal in the current project:**

1. Read `<project-root>/.nvim/terminal-sessions.json`. It maps each terminal to:
   - `name` — the human label (e.g. `commands`, `server`, `btop`)
   - `log`  — absolute path to its live output log (or `null` if not logged)
2. Pick the terminal by `name`, then read its `log` file.
3. The log is the raw PTY stream, so strip ANSI/carriage returns when reading:
   ```
   sed -r "s/\x1b\[[0-9;?]*[a-zA-Z]//g; s/\r//g" <log>
   ```

**Important properties:**

- Logs are **live-only**: each exists exactly as long as its tmux session, and
  self-deletes when the terminal closes. A missing/`null` log means that terminal
  isn't running or isn't logged — don't treat its absence as an error.
- **Agent terminals (names starting with `a_`) are never logged** (`log: null`).
  Don't look for their output here.
- Only terminals created *after* the plugin loaded are logged; long-lived
  pre-existing ones may have `log: null` until recreated.
- Logs live under `~/.local/state/nvim/term-logs/`, but use the project's
  `.nvim/terminal-sessions.json` as the index rather than guessing filenames.
