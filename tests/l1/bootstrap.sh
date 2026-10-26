#!/bin/bash
# bootstrap area tests. Sourced by tests/run.sh (not run standalone).

run_bootstrap_linux_pkg_manager_detection_tests() {
  local bootstrap_script
  bootstrap_script="${ROOT_DIR}/scripts/bootstrap.sh"

  local tmpbin out

  # Caso 1: apt-get detectado
  tmpbin="$(mktemp -d)"
  cat >"${tmpbin}/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
  chmod +x "${tmpbin}/uname"

  for c in pandoc python3 curl mmdc xelatex apt-get; do
    cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  if PATH="${tmpbin}" /bin/bash "${bootstrap_script}" --dry-run --yes --skip-link >"$out" 2>&1; then
    pass "bootstrap detects apt-get on Linux"
  else
    fail "bootstrap should detect apt-get on Linux"
  fi
  assert_contains "$out" "Detected package manager: apt-get" "bootstrap reports detected apt-get"
  assert_contains "$out" "\[dry-run\] sudo apt-get install -y pandoc" "bootstrap generates expected apt-get command"
  rm -rf "$tmpbin"
  rm -f "$out"

  # Caso 2: dnf detectado
  tmpbin="$(mktemp -d)"
  cat >"${tmpbin}/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
  chmod +x "${tmpbin}/uname"

  for c in pandoc python3 curl mmdc xelatex dnf; do
    cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  if PATH="${tmpbin}" /bin/bash "${bootstrap_script}" --dry-run --yes --skip-link >"$out" 2>&1; then
    pass "bootstrap detects dnf on Linux"
  else
    fail "bootstrap should detect dnf on Linux"
  fi
  assert_contains "$out" "Detected package manager: dnf" "bootstrap reports detected dnf"
  assert_contains "$out" "\[dry-run\] sudo dnf install -y pandoc" "bootstrap generates expected dnf command"
  rm -rf "$tmpbin"
  rm -f "$out"

  # Case 3: without supported package manager
  tmpbin="$(mktemp -d)"
  cat >"${tmpbin}/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
  chmod +x "${tmpbin}/uname"

  for c in pandoc python3 curl mmdc xelatex; do
    cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  set +e
  PATH="${tmpbin}" /bin/bash "${bootstrap_script}" --dry-run --yes --skip-link >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "bootstrap fails when no package manager is detected"
  assert_contains "$out" "No supported package manager detected" "bootstrap reports missing supported package manager"
  rm -rf "$tmpbin"
  rm -f "$out"
}

run_bootstrap_mermaid_browser_warning_test() {
  local tmpbin out code
  tmpbin="$(mktemp -d)"
  out="$(mktemp)"

  for c in pandoc curl xelatex; do
    cat >"${tmpbin}/${c}" <<'STUB'
#!/bin/bash
exit 0
STUB
    chmod +x "${tmpbin}/${c}"
  done
  cat >"${tmpbin}/mmdc" <<'STUB'
#!/bin/bash
echo "Error: Could not find chrome-headless-shell" >&2
exit 1
STUB
  chmod +x "${tmpbin}/mmdc"
  cat >"${tmpbin}/python3" <<STUB
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
STUB
  chmod +x "${tmpbin}/python3"

  set +e
  PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" bash "${ROOT_DIR}/scripts/bootstrap.sh" --no-install --skip-link >"$out" 2>&1
  code=$?
  set -e

  if [[ "$code" -ne 0 ]]; then
    pass "bootstrap exits non-zero when Mermaid cannot render"
  else
    fail "bootstrap should exit non-zero when Mermaid cannot render"
  fi
  assert_contains "$out" "mermaid-cli is installed but has no browser" "bootstrap warns about the missing browser"
  assert_contains "$out" "chrome-headless-shell" "the warning names the Puppeteer install"
  assert_contains "$out" "PUPPETEER_EXECUTABLE_PATH" "the warning names the Chrome alternative"

  rm -rf "$tmpbin"
  rm -f "$out"
}
