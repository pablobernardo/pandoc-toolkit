#!/bin/bash
# i18n area tests. Sourced by tests/run.sh (not run standalone).

run_i18n_catalog_consistency_test() {
  local out
  out="$(mktemp)"

  if "${REAL_PYTHON3}" "${ROOT_DIR}/scripts/check-i18n.py" "${ROOT_DIR}" >"$out" 2>&1; then
    pass "i18n check validates catalogs and placeholders"
  else
    fail "i18n check should validate catalogs"
  fi
  assert_contains "$out" "i18n OK" "i18n check reports OK status"

  rm -f "$out"
}

run_unknown_command_test() {
  local out
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" unknown-command >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "unknown command returns exit 1"
  assert_contains "$out" "Unknown command" "unknown command shows error"
  rm -f "$out"
}

run_i18n_default_fallback_english_test() {
  local out
  local tmp_home
  local project_env
  local project_env_backup
  out="$(mktemp)"
  tmp_home="$(mktemp -d)"
  project_env="${ROOT_DIR}/.pandoc-pdf.env"
  project_env_backup=""

  if [[ -f "$project_env" ]]; then
    project_env_backup="$(mktemp)"
    cp "$project_env" "$project_env_backup"
    rm -f "$project_env"
  fi

  set +e
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" env -u PANDOC_PDF_LANG -u LC_ALL -u LANG "$CLI" unknown-command >"$out" 2>&1
  local code=$?
  set -e

  if [[ -n "$project_env_backup" ]]; then
    cp "$project_env_backup" "$project_env"
    rm -f "$project_env_backup"
  fi

  assert_exit_code "1" "$code" "default fallback keeps exit 1"
  assert_contains "$out" "Unknown command" "default fallback uses English"
  rm -rf "$tmp_home"
  rm -f "$out"
}

run_i18n_force_english_unknown_command_test() {
  local out
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" unknown-command >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "unknown command keeps exit 1 in English"
  assert_contains "$out" "Unknown command" "unknown command translates to English"
  assert_contains "$out" "Usage:" "help uses English title"
  rm -f "$out"
}

run_shared_i18n_runtime_test() {
  if [[ ! -f "${ROOT_DIR}/scripts/i18n.sh" ]]; then
    fail "scripts/i18n.sh must exist: it is the single shell i18n runtime"
    return 0
  fi
  pass "scripts/i18n.sh exists"

  local entry
  for entry in bin/pandoc-pdf scripts/bootstrap.sh; do
    if grep -q 'scripts/i18n.sh' "${ROOT_DIR}/${entry}"; then
      pass "${entry} sources the shared i18n runtime"
    else
      fail "${entry} must source scripts/i18n.sh instead of duplicating locale logic"
    fi
    if grep -qE '^resolve_lang\(\) \{|^list_supported_locales\(\) \{' "${ROOT_DIR}/${entry}"; then
      fail "${entry} still defines its own locale resolution"
    else
      pass "${entry} has no local locale resolution"
    fi
  done

  local out
  out="$(mktemp)"
  if PANDOC_PDF_LANG=es bash "${ROOT_DIR}/scripts/bootstrap.sh" --help >"$out" 2>&1; then
    pass "bootstrap --help runs with the shared runtime"
  else
    fail "bootstrap --help should run with the shared runtime"
  fi
  assert_contains "$out" "Bootstrap de instalación" "bootstrap inherits the project language"
  rm -f "$out"
}
