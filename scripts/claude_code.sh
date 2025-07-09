#!/usr/bin/env bash
# ../scripts/claude_code.sh

export NPM_CONFIG_PREFIX="$HOME/.npm-global"
export PATH="$HOME/.npm-global/bin:$PATH"

if [ ! -f "$HOME/.npm-global/bin/claude" ]; then
    echo "Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
fi

exec "$HOME/.npm-global/bin/claude" "$@"
