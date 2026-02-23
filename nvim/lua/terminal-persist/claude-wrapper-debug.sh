#!/bin/bash
set -euo pipefail

log_file="/tmp/claude-wrapper.log"

stamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
{
  printf "%s" "$stamp"
  printf " pid=%s" "$$"
  printf " cwd=%s" "$PWD"
  printf " %s" "$*"
  printf "\n"
} >> "$log_file"
