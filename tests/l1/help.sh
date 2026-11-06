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
  assert_contains "$out" "skelepress update --check" "--help includes update check command"
  local command description
  while IFS="|" read -r command description; do
    assert_contains "$out" "${command}[[:space:]]+${description}" "help explains ${command}"
  done <<'EOF'
version|Show the toolkit version
info|Show installation and runtime information
locale|Show or save the CLI language
update|Check for or install a toolkit release
doctor|Check dependencies before rendering
validate-config|Validate a configuration against its schema
render|Render a validated configuration to PDF or EPUB
book|Validate manifests and build volumes or series
EOF
  assert_contains "$out" "skelepress book --help" "help points to working detailed book help"
  assert_contains "$out" "docs/usage.md" "help points to other command documentation"
  local alias alias_out
  alias_out="$(mktemp)"
  for alias in help -h; do
    if "$CLI" "$alias" >"$alias_out" 2>&1 && cmp -s "$out" "$alias_out"; then
      pass "${alias} returns the same successful general help"
    else
      fail "${alias} must return the same successful general help"
    fi
  done
  rm -f "$out" "$alias_out"
}

run_help_i18n_notes_test() {
  local out
  out="$(mktemp)"

  if SKELEPRESS_LANG=es "$CLI" --help >"$out" 2>&1; then
    pass "--help for es locale returns exit 0"
  else
    fail "--help for es locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementación nativa\." "--help translates render note in es"

  if SKELEPRESS_LANG=pt "$CLI" --help >"$out" 2>&1; then
    pass "--help for pt locale returns exit 0"
  else
    fail "--help for pt locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementação nativa\." "--help translates render note in pt"

  if SKELEPRESS_LANG=gl "$CLI" --help >"$out" 2>&1; then
    pass "--help for gl locale returns exit 0"
  else
    fail "--help for gl locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementación nativa\." "--help translates render note in gl"

  rm -f "$out"
}
