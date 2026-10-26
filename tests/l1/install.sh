#!/bin/bash
# install area tests. Sourced by tests/run.sh (not run standalone).

run_install_local_dev_link_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  local out
  out="$(mktemp)"

  local install_home install_bin
  install_home="${sandbox}/managed"
  install_bin="${sandbox}/bin"

  if PANDOC_PDF_INSTALL_HOME="$install_home" PANDOC_PDF_INSTALL_DIR="$install_bin" /bin/bash "${ROOT_DIR}/scripts/install-local.sh" dev >"$out" 2>&1; then
    pass "install-local dev completes successfully"
  else
    fail "install-local dev should complete successfully"
  fi

  if [[ -L "${install_bin}/pandoc-pdf-dev" ]]; then
    pass "install-local dev creates pandoc-pdf-dev symlink"
  else
    fail "install-local dev should create pandoc-pdf-dev symlink"
  fi

  set +e
  "${install_bin}/pandoc-pdf-dev" --version >>"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "0" "$code" "pandoc-pdf-dev symlink is executable"
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "pandoc-pdf-dev reports toolkit version"

  rm -rf "$sandbox"
  rm -f "$out"
}
