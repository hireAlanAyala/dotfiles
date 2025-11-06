#!/usr/bin/env bash
# Wrapper script for nvim that detects if running inside nvim and uses remote instead

# Check if $NVIM is set and socket exists
if [[ -n "$NVIM" && -S "$NVIM" ]]; then
    # Inside nvim terminal, use remote to open in parent nvim
    exec nvim --server "$NVIM" --remote "$@"
fi

# Not inside nvim, use regular nvim
exec nvim "$@"
