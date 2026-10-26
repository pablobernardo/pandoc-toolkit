#!/bin/bash
# doctor area tests. Sourced by tests/run.sh (not run standalone).

run_doctor_success_with_mocked_path() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 curl mmdc xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  if PATH="$tmpbin" /bin/bash "$CLI" doctor >"$out" 2>&1; then
    pass "doctor passes with mocked dependencies"
  else
    fail "doctor should pass with mocked dependencies"
  fi
  assert_contains "$out" "Doctor OK" "doctor reports OK"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_failure_missing_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(python3 curl mmdc xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PATH="$tmpbin" /bin/bash "$CLI" doctor >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor fails when pandoc is missing"
  assert_contains "$out" "pandoc" "doctor reports missing dependency"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_with_config_required_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-required-cmd.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor -c fails for missing required command"
  assert_contains "$out" "mycustomcmd" "doctor -c reports missing command from config"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_rejects_invalid_required_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=es PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-invalid-required-cmd.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor -c fails with invalid command name"
  assert_contains "$out" "Invalid command name" "doctor -c reports invalid command"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_strict_semantics_test() {
  local tmpbin out code
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  set +e
  PANDOC_PDF_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-required-cmd.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "runtime.strict=true fails on missing required command"

  set +e
  PANDOC_PDF_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-strict-false.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "runtime.strict=false does not fail on missing required command"
  assert_contains "$out" "mycustomcmd" "runtime.strict=false still reports the missing command"

  # Sin motor TeX no hay PDF: strict=false no puede perdonarlo.
  local tmpbin_no_tex
  tmpbin_no_tex="$(mktemp -d)"
  cat >"${tmpbin_no_tex}/pandoc" <<'EOF'
#!/bin/bash
exit 0
EOF
  cat >"${tmpbin_no_tex}/python3" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
  chmod +x "${tmpbin_no_tex}/pandoc" "${tmpbin_no_tex}/python3"

  set +e
  PANDOC_PDF_LANG=en PATH="$tmpbin_no_tex" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-strict-false.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "runtime.strict=false still fails when the TeX engine is missing"
  assert_contains "$out" "xelatex" "the missing TeX engine is named"

  rm -rf "$tmpbin" "$tmpbin_no_tex"
  rm -f "$out"
}

run_doctor_mermaid_smoke_test() {
  local tmpbin out code
  tmpbin="$(mktemp -d)"
  out="$(mktemp)"

  cat >"${tmpbin}/pandoc" <<'STUB'
#!/bin/bash
exit 0
STUB
  cat >"${tmpbin}/xelatex" <<'STUB'
#!/bin/bash
exit 0
STUB
  cat >"${tmpbin}/mmdc" <<'STUB'
#!/bin/bash
if [[ "${1:-}" == "--version" ]]; then
  echo "12.0.0"
  exit 0
fi
echo "Error: Could not find chrome-headless-shell" >&2
exit 1
STUB
  cat >"${tmpbin}/python3" <<STUB
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
STUB
  chmod +x "${tmpbin}/pandoc" "${tmpbin}/xelatex" "${tmpbin}/mmdc" "${tmpbin}/python3"

  set +e
  PANDOC_PDF_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-mermaid.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "doctor fails when mmdc cannot render a diagram"
  assert_contains "$out" "Mermaid diagrams cannot be rendered" "doctor names the mermaid failure"
  assert_contains "$out" "PUPPETEER_EXECUTABLE_PATH" "doctor gives the Chrome remediation"
  assert_contains "$out" "12.0.0" "doctor names the mermaid-cli version it found"

  set +e
  PANDOC_PDF_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-mermaid-warn.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "runtime.strict=false keeps doctor green on a mermaid failure"
  assert_contains "$out" "PUPPETEER_EXECUTABLE_PATH" "the warning still shows the remediation"

  rm -rf "$tmpbin"
  rm -f "$out"
}
