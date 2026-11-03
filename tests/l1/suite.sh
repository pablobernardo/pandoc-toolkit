#!/bin/bash
# Suite integrity tests. Sourced by tests/run.sh (not run standalone).

# The orchestrator calls each test by name from a hand-written list. A function
# defined in an area file but never listed silently stops protecting anything,
# and a listed name with no definition aborts the run. Compare both directions so
# neither can happen unnoticed.
run_suite_registration_test() {
  local defined registered missing extra
  defined="$(mktemp)"
  registered="$(mktemp)"

  # shellcheck disable=SC2129  # one redirection per pipeline keeps each list separate
  grep -hoE '^run_[a-z0-9_]+\(\)' "${ROOT_DIR}"/tests/l1/*.sh 2>/dev/null \
    | sed 's/()$//' | sort -u >"$defined" || true
  grep -oE '^[[:space:]]+run_[a-z0-9_]+' "${ROOT_DIR}/tests/run.sh" 2>/dev/null \
    | tr -d ' ' | sort -u >"$registered" || true

  missing="$(comm -23 "$defined" "$registered" | tr '\n' ' ')"
  extra="$(comm -13 "$defined" "$registered" | tr '\n' ' ')"

  if [[ -n "$missing" ]]; then
    fail "defined test functions missing from tests/run.sh: ${missing}"
  else
    pass "every defined test function is registered in tests/run.sh"
  fi

  if [[ -n "$extra" ]]; then
    fail "tests/run.sh calls test functions that are not defined: ${extra}"
  else
    pass "tests/run.sh only calls defined test functions"
  fi

  rm -f "$defined" "$registered"
}
