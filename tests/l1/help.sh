#!/bin/bash
# help area tests. Sourced by tests/run.sh (not run standalone).

run_help_test() {
  local out
  out="$(mktemp)"
  if "$CLI" --help >"$out" 2>&1; then
    pass "--help returns exit 0"
  else
    fail "--help should return exit 0"
  fi
  assert_contains "$out" "Usage:" "--help prints usage"
  assert_contains "$out" "pandoc-pdf update --check" "--help includes update check command"
  rm -f "$out"
}

run_help_i18n_notes_test() {
  local out
  out="$(mktemp)"

  if PANDOC_PDF_LANG=es "$CLI" --help >"$out" 2>&1; then
    pass "--help for es locale returns exit 0"
  else
    fail "--help for es locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementación nativa\." "--help translates render note in es"

  if PANDOC_PDF_LANG=pt "$CLI" --help >"$out" 2>&1; then
    pass "--help for pt locale returns exit 0"
  else
    fail "--help for pt locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementação nativa\." "--help translates render note in pt"

  if PANDOC_PDF_LANG=gl "$CLI" --help >"$out" 2>&1; then
    pass "--help for gl locale returns exit 0"
  else
    fail "--help for gl locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementación nativa\." "--help translates render note in gl"

  rm -f "$out"
}
