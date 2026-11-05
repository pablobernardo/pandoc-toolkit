#!/bin/bash
# Configuration rules specific to an EPUB job.
# Sourced by tests/run.sh (not run standalone).

run_epub_config_validation_test() {
  local sandbox out
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"

  write_epub_config "${sandbox}/skelepress.config.yaml" epub
  if "${sandbox}/bin/skelepress" validate-config -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1; then
    pass "config accepts output.formats=epub"
  else
    fail "config should accept output.formats=epub ($(tail -2 "$out"))"
  fi

  write_epub_config "${sandbox}/skelepress.config.yaml" pdf
  if "${sandbox}/bin/skelepress" validate-config -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1; then
    pass "config accepts output.formats=pdf"
  else
    fail "config should accept output.formats=pdf ($(tail -2 "$out"))"
  fi

  write_epub_config "${sandbox}/skelepress.config.yaml" mobi
  local code=0
  "${sandbox}/bin/skelepress" validate-config -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1 || code=$?
  assert_exit_code "1" "$code" "config rejects an unsupported output.formats"
  assert_contains "$out" "must be one of: pdf, epub" "rejection names the supported formats"

  rm -rf "$sandbox"
  rm -f "$out"
}
