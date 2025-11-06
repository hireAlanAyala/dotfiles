#!/usr/bin/env bash
# nvim-control - Send commands to parent nvim instance with optional output capture

set -e

# Usage info
usage() {
  cat << EOF
Usage: nvim-control [OPTIONS] COMMAND

Send commands to the parent nvim instance.
Automatically escapes to normal mode before executing commands.

OPTIONS:
  --socket PATH     Use specific socket path (bypasses auto-discovery)
  --test            Test socket discovery and show which method found it
  --output          Capture and print the output of the command
  --no-escape       Skip escaping to normal mode (for raw input)
  --help            Show this help message

EXAMPLES:
  # Execute a command
  nvim-control ':echo "hello"<CR>'

  # Run Lua code
  nvim-control ':lua vim.notify("Task complete!")<CR>'

  # Get output
  nvim-control --output ':lua return vim.fn.getcwd()<CR>'

  # Use specific socket
  nvim-control --socket /run/user/1000/nvim.12345.0 ':echo "hi"<CR>'

  # Test socket discovery
  nvim-control --test

  # Trigger a keymap
  nvim-control '<leader>tp'

  # Send raw input without escaping
  nvim-control --no-escape 'iHello World<Esc>'

EOF
  exit 0
}

# Parse arguments
OUTPUT=0
NO_ESCAPE=0
TEST=0
SOCKET_ARG=""
COMMAND=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --socket)
      SOCKET_ARG="$2"
      shift 2
      ;;
    --test)
      TEST=1
      shift
      ;;
    --output)
      OUTPUT=1
      shift
      ;;
    --no-escape)
      NO_ESCAPE=1
      shift
      ;;
    --help|-h)
      usage
      ;;
    *)
      COMMAND="$1"
      shift
      ;;
  esac
done

# Check if COMMAND is provided (not required for --test)
if [[ -z "$COMMAND" ]] && [[ $TEST -eq 0 ]]; then
  echo "Error: No command provided" >&2
  usage
fi

# Find the correct Neovim socket
find_nvim_socket() {
  # 1. Try reading from terminal-persist state file (most reliable - session level socket)
  local search_dir="$(pwd)"
  while [[ "$search_dir" != "/" ]]; do
    local state_file="$search_dir/.nvim/terminal-sessions.json"

    if [[ -f "$state_file" ]]; then
      # Extract session-level socket (at root of JSON, not per-terminal)
      local socket=$(sed -n 's/.*"nvim_socket"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$state_file" 2>/dev/null | head -1)

      if [[ -n "$socket" ]] && [[ -S "$socket" ]]; then
        # Verify it's responsive
        if nvim --server "$socket" --remote-expr "1" &>/dev/null; then
          echo "$socket"
          return 0
        fi
      fi
    fi

    # Move up one directory
    search_dir=$(dirname "$search_dir")
  done

  # 2. Try $NVIM if set
  if [[ -n "$NVIM" ]] && [[ -S "$NVIM" ]]; then
    # Verify it's actually responsive
    if nvim --server "$NVIM" --remote-expr "1" &>/dev/null; then
      echo "$NVIM"
      return 0
    fi
  fi

  # 3. Look for project-specific socket based on current directory
  local cwd="$(pwd)"
  local socket_dir="${XDG_RUNTIME_DIR:-/tmp}"

  # Calculate the same hash that Neovim uses
  local project_hash=$(echo -n "$cwd" | sha256sum | cut -c1-8)
  local project_socket="$socket_dir/nvim-project-${project_hash}.sock"

  if [[ -S "$project_socket" ]] && nvim --server "$project_socket" --remote-expr "1" &>/dev/null; then
    echo "$project_socket"
    return 0
  fi

  # 4. Search for any valid nvim socket in the runtime directory
  for socket in "$socket_dir"/nvim*.sock "$socket_dir"/nvim.*.0; do
    if [[ -S "$socket" ]] && nvim --server "$socket" --remote-expr "1" &>/dev/null; then
      echo "$socket"
      return 0
    fi
  done

  return 1
}

# Verbose version for testing
find_nvim_socket_verbose() {
  echo "=== Neovim Socket Discovery Test ===" >&2
  echo "" >&2

  # 1. Try reading from terminal-persist state file
  echo "1. Checking terminal-persist state file (searching upward)..." >&2
  local search_dir="$(pwd)"
  local found_state=0

  while [[ "$search_dir" != "/" ]]; do
    local state_file="$search_dir/.nvim/terminal-sessions.json"
    echo "   Checking: $state_file" >&2

    if [[ -f "$state_file" ]]; then
      found_state=1
      echo "   ✓ State file found" >&2
      local socket=$(sed -n 's/.*"nvim_socket"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$state_file" 2>/dev/null | head -1)

      if [[ -n "$socket" ]]; then
        echo "   Session socket from state: $socket" >&2
        if [[ -S "$socket" ]]; then
          echo "   ✓ Socket file exists" >&2
          if nvim --server "$socket" --remote-expr "1" &>/dev/null; then
            echo "   ✓ Socket is responsive" >&2
            echo "   ✅ FOUND via state file (session-level socket)" >&2
            echo "$socket"
            return 0
          else
            echo "   ✗ Socket not responsive" >&2
          fi
        else
          echo "   ✗ Socket file doesn't exist" >&2
        fi
      else
        echo "   ✗ No nvim_socket key in state file" >&2
      fi
      break
    fi

    search_dir=$(dirname "$search_dir")
  done

  if [[ $found_state -eq 0 ]]; then
    echo "   ✗ No state file found (searched up to root)" >&2
  fi
  echo "" >&2

  # 2. Try $NVIM
  echo "2. Checking \$NVIM environment variable..." >&2
  if [[ -n "$NVIM" ]]; then
    echo "   \$NVIM = $NVIM" >&2
    if [[ -S "$NVIM" ]]; then
      echo "   ✓ Socket file exists" >&2
      if nvim --server "$NVIM" --remote-expr "1" &>/dev/null; then
        echo "   ✓ Socket is responsive" >&2
        echo "   ✅ FOUND via \$NVIM" >&2
        echo "$NVIM"
        return 0
      else
        echo "   ✗ Socket not responsive" >&2
      fi
    else
      echo "   ✗ Socket file doesn't exist" >&2
    fi
  else
    echo "   ✗ \$NVIM not set" >&2
  fi
  echo "" >&2

  # 3. Try project socket
  echo "3. Checking project-specific socket..." >&2
  local cwd="$(pwd)"
  local socket_dir="${XDG_RUNTIME_DIR:-/tmp}"
  local project_hash=$(echo -n "$cwd" | sha256sum | cut -c1-8)
  local project_socket="$socket_dir/nvim-project-${project_hash}.sock"

  echo "   Project dir: $cwd" >&2
  echo "   Project hash: $project_hash" >&2
  echo "   Project socket: $project_socket" >&2

  if [[ -S "$project_socket" ]]; then
    echo "   ✓ Socket file exists" >&2
    if nvim --server "$project_socket" --remote-expr "1" &>/dev/null; then
      echo "   ✓ Socket is responsive" >&2
      echo "   ✅ FOUND via project socket" >&2
      echo "$project_socket"
      return 0
    else
      echo "   ✗ Socket not responsive" >&2
    fi
  else
    echo "   ✗ Socket file doesn't exist" >&2
  fi
  echo "" >&2

  # 4. Search runtime directory
  echo "4. Searching runtime directory..." >&2
  echo "   Runtime dir: $socket_dir" >&2
  local found_any=0
  for socket in "$socket_dir"/nvim*.sock "$socket_dir"/nvim.*.0; do
    if [[ -S "$socket" ]]; then
      found_any=1
      echo "   Checking: $socket" >&2
      if nvim --server "$socket" --remote-expr "1" &>/dev/null; then
        echo "   ✓ Responsive!" >&2
        echo "   ✅ FOUND via runtime directory search" >&2
        echo "$socket"
        return 0
      else
        echo "   ✗ Not responsive" >&2
      fi
    fi
  done

  if [[ $found_any -eq 0 ]]; then
    echo "   ✗ No socket files found" >&2
  fi
  echo "" >&2

  echo "❌ No responsive Neovim instance found" >&2
  return 1
}

# Test mode - show socket discovery process
if [[ $TEST -eq 1 ]]; then
  SOCKET=$(find_nvim_socket_verbose)
  EXIT_CODE=$?
  echo "" >&2
  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "==================================" >&2
    echo "Result: $SOCKET" >&2
    echo "==================================" >&2
    exit 0
  else
    exit 1
  fi
fi

# Find and validate the Neovim socket
if [[ -n "$SOCKET_ARG" ]]; then
  # User provided socket via --socket flag
  if [[ ! -S "$SOCKET_ARG" ]]; then
    echo "Error: '$SOCKET_ARG' is not a valid socket file" >&2
    exit 1
  fi

  if ! nvim --server "$SOCKET_ARG" --remote-expr "1" &>/dev/null; then
    echo "Error: Socket '$SOCKET_ARG' exists but is not responsive" >&2
    exit 1
  fi

  NVIM="$SOCKET_ARG"
else
  # Auto-discover socket
  NVIM=$(find_nvim_socket)
  if [[ -z "$NVIM" ]]; then
    echo "Error: No responsive Neovim instance found." >&2
    echo "Tried: state file, \$NVIM, project socket, and runtime directory" >&2
    echo "Run with --test flag to see detailed discovery process" >&2
    echo "Or use --socket PATH to specify a socket manually" >&2
    exit 1
  fi
fi

# Escape to normal mode unless --no-escape is set
# <C-\><C-N> works from any mode: terminal, insert, or normal
ESCAPE_SEQ=""
if [[ $NO_ESCAPE -eq 0 ]]; then
  ESCAPE_SEQ='<C-\><C-N>'
fi

# Handle output capture
if [[ $OUTPUT -eq 1 ]]; then
  # Create temp file
  TEMP_FILE=$(mktemp)
  trap "rm -f $TEMP_FILE" EXIT

  # Wrap command to write output to temp file
  # Strip the trailing <CR> if present
  BASE_CMD="${COMMAND%<CR>}"

  # Create Lua wrapper that captures result
  WRAPPED_CMD="${ESCAPE_SEQ}:lua (function() local result = $BASE_CMD; vim.fn.writefile({vim.inspect(result)}, '$TEMP_FILE') end)()<CR>"

  # Send command
  nvim --server "$NVIM" --remote-send "$WRAPPED_CMD"

  # Wait a moment for file to be written
  sleep 0.1

  # Read and print result
  if [[ -f "$TEMP_FILE" ]]; then
    cat "$TEMP_FILE"
  fi
else
  # Just send the command without capturing output
  nvim --server "$NVIM" --remote-send "${ESCAPE_SEQ}${COMMAND}"
fi
