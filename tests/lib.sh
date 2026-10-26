#!/bin/bash
# Shared assertions for the L1 suite. Sourced by tests/run.sh;
# expects ROOT_DIR, CLI, FIXTURES_DIR, REAL_PYTHON3, PASS and FAIL to exist.

green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
red() { printf '\033[0;31m%s\033[0m\n' "$1"; }

pass() {
  PASS=$((PASS + 1))
  if [[ "${TEST_VERBOSE:-1}" == "1" ]]; then
    green "✅ PASS [${PASS}] $1"
  else
    green "✅ PASS [${PASS}]"
  fi
}

fail() {
  FAIL=$((FAIL + 1))
  red "❌ FAIL [${FAIL}] $1"
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$msg"
  else
    fail "$msg (expected=${expected}, actual=${actual})"
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if grep -qE -- "$pattern" "$file"; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if grep -qE -- "$pattern" "$file"; then
    fail "$msg"
  else
    pass "$msg"
  fi
}

# Fixture helpers shared by the area files.

line_of_match() {
  local file="$1"
  local pattern="$2"
  { grep -n -m1 -E -- "$pattern" "$file" 2>/dev/null || true; } | cut -d: -f1
}

write_pandoc_capture_mock() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat >"${bin_dir}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
{
  echo "ARGS:$*"
  echo "PANDOC_EMOJI_DIR=${PANDOC_EMOJI_DIR:-}"
  echo "PANDOC_EMOJI_BALLOT_ICONS=${PANDOC_EMOJI_BALLOT_ICONS:-}"
  echo "PANDOC_MERMAID_OUTPUT_DIR=${PANDOC_MERMAID_OUTPUT_DIR:-}"
  echo "PANDOC_MERMAID_BACKGROUND=${PANDOC_MERMAID_BACKGROUND:-}"
} > "${TMP_PANDOC_CAPTURE}"
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -n "$out" ]]; then
  mkdir -p "$(dirname "$out")"
  : > "$out"
fi
exit 0
EOF
  chmod +x "${bin_dir}/pandoc"
}

new_contract_sandbox() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/work/chapters" "${sandbox}/templates"
  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp -R "${ROOT_DIR}/scripts" "${sandbox}/scripts"
  rm -rf "${sandbox}/scripts/__pycache__"
  cp -R "${ROOT_DIR}/schemas" "${sandbox}/schemas"
  cp -R "${ROOT_DIR}/filters" "${sandbox}/filters"
  cp -R "${ROOT_DIR}/i18n" "${sandbox}/i18n"
  cp "${ROOT_DIR}/VERSION" "${sandbox}/VERSION"
  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF
  printf '%s\n' "$sandbox"
}

write_contract_config() {
  local path="$1"
  local order="$2"
  local keep_md="$3"
  local metadata_file="$4"
  local ballot="$5"
  local mermaid="${6:-false}"
  cat >"$path" <<EOF
version: 1

project:
  name: s1-contract
  base_dir: ./work

document:
  title: "S1 Document"
  subtitle: "S1 Subtitle"
  publisher: "S1 Publisher"
  author: "S1 Author"
  date: "2026-01-02"
  rights: "S1 Rights"

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: ${order}
  explicit_files: []

output:
  dir: "out"
  file_prefix: "s1"
  suffix: "manual"
  keep_merged_markdown: ${keep_md}

pandoc:
  pdf_engine: lualatex
  toc: false
  toc_depth: 2
  number_sections: false
  metadata_file: "${metadata_file}"
  resource_path:
    - "chapters"

filters:
  emoji:
    enabled: true
    emoji_dir: "out/emoji"
    include_ballot_icons: ${ballot}
  mermaid:
    enabled: ${mermaid}
    output_dir: "out/mermaid"
    background: "transparent"
  extra_lua_filters: []

runtime:
  required_commands:
    - pandoc
  strict: true

compat:
  legacy_clearpage_between_h1: false
EOF
}

assert_json_expr() {
  local file="$1"
  local expr="$2"
  local msg="$3"

  if "${REAL_PYTHON3}" - "$file" "$expr" <<'PY' >/dev/null 2>&1
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
scope = {"d": data, "any": any, "all": all, "len": len, "str": str, "sorted": sorted, "None": None}
sys.exit(0 if bool(eval(sys.argv[2], {"__builtins__": {}}, scope)) else 1)
PY
  then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_file_exists() {
  if [[ -f "$1" ]]; then
    pass "$2"
  else
    fail "$2 (missing: $1)"
  fi
}

assert_file_absent() {
  if [[ -e "$1" ]]; then
    fail "$2 (exists: $1)"
  else
    pass "$2"
  fi
}
