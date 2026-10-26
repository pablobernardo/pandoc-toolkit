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
