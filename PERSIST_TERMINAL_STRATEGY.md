# NAME
tmux attach
## STATUS
FAILS
## COMMANDS
tmux a -s session_NAME
## CHALLENGES
does not dump scrollback history older than the viewport into the nvim terminal.

# NAME
tmux capture-pane + attach
## STATUS
WORKS!
## COMMANDS
tmux a -s session_name
tmux capture-pane -e -J -p -S -10000 -t _config_c858e7_claude | sed '/^[[:space:]]*$/d' (dumps scrollback into nvim)
## CHALLENGES
Causes nested tmux sessions. Which essentially runs two tmux UIs. 
hard to access the nested tmux session and trigger bindings from there

### Unverified potential challenges
Can cause TUIs from burning screens into the scrollback cluttering the history

Clean screen restore for full-screen TUIs. Apps like vim/nvim, less/man, htop, tig, fzf, ranger, etc. won’t “flip” to a separate buffer and restore your old shell view on exit. Their last frame stays in the pane and your prompt is now many lines up.

## Potential Improvements
Have nvim sessions persist in a dedicated tmux server
set -g terminal-overrides 'xterm*:Tc,xterm*:smcup@:rmcup@' for that server (disables the tmux alternate screen)
