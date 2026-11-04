#!/bin/bash
# Several output formats from one configuration.
# Sourced by tests/run.sh (not run standalone).

run_multi_format_export_test() {
  local out code=0
  out="$(mktemp)"
  "${REAL_PYTHON3}" "${ROOT_DIR}/tests/integration/check-multi-format.py" >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "public multi-format selection, ordering and partial failure checks"
  if [[ "$code" != "0" ]]; then
    tail -60 "$out"
  fi
  rm -f "$out"
}
