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
