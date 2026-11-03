#!/usr/bin/env bash
set -euo pipefail

path_dirname() {
  local p="$1"
  if [[ "$p" == */* ]]; then
    printf '%s\n' "${p%/*}"
  else
    printf '.\n'
  fi
}

SCRIPT_DIR="$(cd -- "$(path_dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/preflight.py" "$@"
