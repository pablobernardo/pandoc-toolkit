#!/bin/bash
# info area tests. Sourced by tests/run.sh (not run standalone).

run_version_tests() {
  local out
  out="$(mktemp)"

  if "$CLI" --version >"$out" 2>&1; then
    pass "--version returns exit 0"
  else
    fail "--version should return exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "--version prints semantic version"

  : >"$out"
  if "$CLI" version >"$out" 2>&1; then
    pass "version returns exit 0"
  else
    fail "version should return exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "version prints semantic version"

  rm -f "$out"
}

run_info_tests() {
  local out
  out="$(mktemp)"

  if "$CLI" info >"$out" 2>&1; then
    pass "info returns exit 0"
  else
    fail "info should return exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "info includes version"
  assert_contains "$out" "^root_dir:" "info includes root_dir"
  assert_contains "$out" "^yaml_parser:" "info includes YAML parser"
  assert_contains "$out" "schema_path: .*exists=true" "info reports schema"

  : >"$out"
  if "$CLI" info --json >"$out" 2>&1; then
    pass "info --json returns exit 0"
  else
    fail "info --json should return exit 0"
  fi
  assert_contains "$out" '^\{' "info --json prints JSON object"
  assert_contains "$out" '"name": "pandoc-pdf"' "info --json includes name"
  assert_contains "$out" '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "info --json includes version"
  assert_contains "$out" '"schema_exists": true' "info --json includes schema existence"

  rm -f "$out"
}
