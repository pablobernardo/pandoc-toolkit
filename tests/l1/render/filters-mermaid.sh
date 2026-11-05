#!/bin/bash
# The mermaid filter: silent degradation, directory gate and failure reporting.
# Sourced by tests/run.sh (not run standalone).

run_render_mermaid_dir_gate_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/skelepress.config.yaml" natural true "" true false
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/skelepress" render \
    -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1; then
    pass "render accepts mermaid.enabled=false"
  else
    fail "render should accept mermaid.enabled=false ($(tail -2 "$out"))"
  fi

  if [[ -d "${sandbox}/work/out/mermaid" ]]; then
    fail "render must not create the mermaid directory when the filter is disabled"
  else
    pass "render skips the mermaid directory when the filter is disabled"
  fi

  write_contract_config "${sandbox}/skelepress.config.yaml" natural true "" true true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/skelepress" render \
    -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1; then
    pass "render accepts mermaid.enabled=true"
  else
    fail "render should accept mermaid.enabled=true ($(tail -2 "$out"))"
  fi

  if [[ -d "${sandbox}/work/out/mermaid" ]]; then
    pass "render creates the mermaid directory when the filter is enabled"
  else
    fail "render must create the mermaid directory when the filter is enabled"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_mermaid_failed_test() {
  local sandbox tmpbin capture out code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  capture="$(mktemp)"
  out="$(mktemp)"

  cat >"${tmpbin}/pandoc" <<'STUB'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
if [[ -n "${PANDOC_MERMAID_OUTPUT_DIR:-}" ]]; then
  echo "deadbeef" > "${PANDOC_MERMAID_OUTPUT_DIR}/_failed.txt"
fi
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="$2"; shift 2 ;;
    *) shift ;;
  esac
done
if [[ -n "$out" ]]; then
  mkdir -p "$(dirname "$out")"
  : > "$out"
fi
exit 0
STUB
  chmod +x "${tmpbin}/pandoc"

  printf '# One\n\ncontent\n' >"${sandbox}/work/chapters/01-one.md"
  write_contract_config "${sandbox}/skelepress.config.yaml" natural true "" true true

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/skelepress" render \
    -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1
  code=$?
  set -e

  if [[ "$code" -ne 0 ]]; then
    pass "render fails when a Mermaid diagram was dropped"
  else
    fail "render must fail when a Mermaid diagram was dropped"
  fi
  assert_contains "$out" "Mermaid diagram" "the render error names the dropped diagrams"
  assert_contains "$out" "skelepress doctor" "the render error points at doctor"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_mermaid_filter_marks_failure_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP mermaid filter failure marking (pandoc not available)"
    return 0
  fi

  local tmpbin dir md out
  tmpbin="$(mktemp -d)"
  dir="$(mktemp -d)"
  md="$(mktemp)"
  out="$(mktemp)"

  cat >"${tmpbin}/mmdc" <<'STUB'
#!/bin/bash
exit 1
STUB
  chmod +x "${tmpbin}/mmdc"

  cat >"$md" <<'MD'
# Diagram

```mermaid
graph TD; A-->B
```
MD

  PANDOC_MERMAID_OUTPUT_DIR="$dir" PATH="${tmpbin}:$PATH" \
    pandoc "$md" -t markdown --lua-filter="${ROOT_DIR}/filters/mermaid.lua" >"$out" 2>&1 || true

  if [[ -s "${dir}/_failed.txt" ]]; then
    pass "the mermaid filter records dropped diagrams"
  else
    fail "the mermaid filter must record dropped diagrams in _failed.txt"
  fi
  assert_contains "$out" "mmdc failed" "the filter explains the failure"

  rm -rf "$tmpbin" "$dir"
  rm -f "$md" "$out"
}
