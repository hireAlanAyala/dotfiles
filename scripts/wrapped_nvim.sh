#!/usr/bin/env bash

wrapped_nvim() {
  local target
  if [ $# -eq 0 ]; then
    # If no arguments, just run nvim
    nvim
  elif [[ "$1" == "." ]]; then
    # if the first arg is . then pass all flags and open
    nvim "$1" "${@:2}"
  else
    # TODO: change this to cd first then open vim, reason is telescope and other plugins will have the wrong context if you stay in the previous dir
    # Try to resolve the path using zoxide
    target=$(zoxide query "$1" 2>&1)
    
    # Check if zoxide found a match
    if [[ "$target" == "zoxide: no match found" ]] || [ -z "$target" ]; then
      # If zoxide fails or returns empty, use the original argument
      target="$1"
    fi
    nvim "$target" "${@:2}"
  fi
}

wrapped_nvim "$@"
