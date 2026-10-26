#!/bin/bash
# locale area tests. Sourced by tests/run.sh (not run standalone).

run_locale_command_tests() {
  local out
  local tmp_home
  out="$(mktemp)"
  tmp_home="$(mktemp -d)"

  if HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" env -u PANDOC_PDF_LANG -u LC_ALL -u LANG "$CLI" locale show >"$out" 2>&1; then
    pass "locale show returns exit 0"
  else
    fail "locale show should return exit 0"
  fi
  assert_contains "$out" "language: en" "locale show uses default fallback en"
  assert_contains "$out" "source: default" "locale show reports default source"

  if HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" PANDOC_PDF_LANG=es "$CLI" locale show >"$out" 2>&1; then
    pass "locale show respects PANDOC_PDF_LANG"
  else
    fail "locale show should respect PANDOC_PDF_LANG"
  fi
  assert_contains "$out" "(language|idioma): es" "locale show reflects Spanish locale"
  assert_contains "$out" "(source|fuente): PANDOC_PDF_LANG" "locale show reports PANDOC_PDF_LANG source"

  if HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$CLI" locale set pt >"$out" 2>&1; then
    pass "locale set pt saves global configuration"
  else
    fail "locale set pt should save global configuration"
  fi
  assert_contains "$out" "Global locale saved to: .*config\.env" "locale set reports global path"
  assert_contains "$tmp_home/.config/pandoc-pdf/config.env" "^export PANDOC_PDF_LANG=pt$" "locale set writes global config"

  if HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" env -u PANDOC_PDF_LANG -u LC_ALL -u LANG "$CLI" locale show >"$out" 2>&1; then
    pass "locale show uses global config"
  else
    fail "locale show should use global config"
  fi
  assert_contains "$out" "(language|idioma): pt" "locale show reflects global locale"
  assert_contains "$out" "(source|fuente|origem|orixe): global_config" "locale show reports global source"

  if HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$CLI" locale set --project es >"$out" 2>&1; then
    pass "locale set --project es saves project configuration"
  else
    fail "locale set --project es should return exit 0"
  fi
  assert_contains "$out" "Project locale saved to: .*\.pandoc-pdf\.env" "locale set --project reports file"
  assert_contains "${ROOT_DIR}/.pandoc-pdf.env" "^export PANDOC_PDF_LANG=es$" "locale set --project writes export to file"

  if HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" env -u PANDOC_PDF_LANG -u LC_ALL -u LANG "$CLI" locale show >"$out" 2>&1; then
    pass "locale show prioritizes project config"
  else
    fail "locale show should prioritize project config"
  fi
  assert_contains "$out" "(language|idioma): es" "locale show reflects project locale"
  assert_contains "$out" "(source|fuente|origem|orixe): project_config" "locale show reports project source"

  set +e
  HOME="$tmp_home" XDG_CONFIG_HOME="$tmp_home/.config" "$CLI" locale set fr >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "locale set fails with unsupported locale"
  assert_contains "$out" "Unsupported locale" "locale set reports unsupported locale"

  rm -f "$out" "${ROOT_DIR}/.pandoc-pdf.env"
  rm -rf "$tmp_home"
}

run_locale_missing_target_message_test() {
  local out code
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en "$CLI" locale set >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "locale set without target fails"
  assert_contains "$out" "--project" "locale set error names the real --project option"
  assert_not_contains "$out" "--team" "locale set error does not mention the removed --team option"
  rm -f "$out"
}
