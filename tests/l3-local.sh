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
    printf '❌ Missing required command for L3: %s\n' "$cmd"
    exit 1
  fi
}

resolve_chromium() {
  if [[ -n "${PUPPETEER_EXECUTABLE_PATH:-}" && -x "${PUPPETEER_EXECUTABLE_PATH}" ]]; then
    printf '%s\n' "${PUPPETEER_EXECUTABLE_PATH}"
    return 0
  fi

  local candidate=""
  for candidate in "/usr/bin/chromium-browser" "$(command -v chromium-browser 2>/dev/null || true)" "$(command -v chromium 2>/dev/null || true)" "$(command -v google-chrome 2>/dev/null || true)"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

main() {
  printf '== L3 local integration (full runtime) ==\n'

  require_cmd pandoc
  require_cmd mmdc

  local chromium_path
  chromium_path="$(resolve_chromium || true)"
  if [[ -z "$chromium_path" ]]; then
    printf '❌ Chromium executable not found. Set PUPPETEER_EXECUTABLE_PATH.\n'
    exit 1
  fi

  rm -rf "${ROOT_DIR}/tests/integration/enabled-filters-project/output"
  rm -rf "${ROOT_DIR}/tests/integration/l3-mermaid-project/output"

  PUPPETEER_EXECUTABLE_PATH="$chromium_path" "${CLI}" doctor -c "${ROOT_DIR}/tests/integration/enabled-filters-project/pdf.config.yaml"
  "${CLI}" validate-config -c "${ROOT_DIR}/tests/integration/enabled-filters-project/pdf.config.yaml"

  PUPPETEER_EXECUTABLE_PATH="$chromium_path" "${CLI}" render -c "${ROOT_DIR}/tests/integration/enabled-filters-project/pdf.config.yaml"
  PUPPETEER_EXECUTABLE_PATH="$chromium_path" "${CLI}" render -c "${ROOT_DIR}/tests/integration/l3-mermaid-project/pdf.config.yaml"

  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/enabled-filters-project/output"/*.pdf 2>/dev/null)"
  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/enabled-filters-project/output"/*.md 2>/dev/null)"
  test -d "${ROOT_DIR}/tests/integration/enabled-filters-project/output/emoji"
  test -d "${ROOT_DIR}/tests/integration/enabled-filters-project/output/mermaid"

  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/l3-mermaid-project/output"/*.pdf 2>/dev/null)"
  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/l3-mermaid-project/output"/*.md 2>/dev/null)"
  test -n "$(ls -1 "${ROOT_DIR}/tests/integration/l3-mermaid-project/output/mermaid"/*.png 2>/dev/null)"

  printf '✅ L3 local integration passed\n'
}

main "$@"
