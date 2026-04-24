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
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CLI="${ROOT_DIR}/bin/pandoc-pdf"

require_cmd() {
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    printf '❌ Missing required command for L2: %s\n' "$cmd"
    exit 1
  fi
}

main() {
  printf '== L2 local integration (semi-real) ==\n'

  require_cmd pandoc

  rm -rf "${ROOT_DIR}/tests/integration/minimal-project/output"
  rm -rf "${ROOT_DIR}/tests/integration/enabled-filters-project/output"

  "${CLI}" validate-config -c "${ROOT_DIR}/tests/integration/minimal-project/pdf.config.yaml"
  "${CLI}" render -c "${ROOT_DIR}/tests/integration/minimal-project/pdf.config.yaml"

  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/minimal-project/output"/*.pdf 2>/dev/null)"
  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/minimal-project/output"/*.md 2>/dev/null)"

  "${CLI}" validate-config -c "${ROOT_DIR}/tests/integration/enabled-filters-project/pdf.config.yaml"
  "${CLI}" validate-config -c "${ROOT_DIR}/tests/integration/l3-mermaid-project/pdf.config.yaml"

  "${CLI}" render -c "${ROOT_DIR}/tests/integration/enabled-filters-project/pdf.config.yaml"

  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/enabled-filters-project/output"/*.pdf 2>/dev/null)"
  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/enabled-filters-project/output"/*.md 2>/dev/null)"
  test -d "${ROOT_DIR}/tests/integration/enabled-filters-project/output/emoji"
  test -d "${ROOT_DIR}/tests/integration/enabled-filters-project/output/mermaid"

  printf '✅ L2 local integration passed\n'
}

main "$@"
