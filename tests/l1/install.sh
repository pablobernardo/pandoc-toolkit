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

  if SKELEPRESS_INSTALL_HOME="$install_home" SKELEPRESS_INSTALL_DIR="$install_bin" /bin/bash "${ROOT_DIR}/scripts/delivery/install-local.sh" dev >"$out" 2>&1; then
    pass "install-local dev completes successfully"
  else
    fail "install-local dev should complete successfully"
  fi

  if [[ -L "${install_bin}/skelepress-dev" ]]; then
    pass "install-local dev creates skelepress-dev symlink"
  else
    fail "install-local dev should create skelepress-dev symlink"
  fi

  set +e
  "${install_bin}/skelepress-dev" --version >>"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "0" "$code" "skelepress-dev symlink is executable"
  assert_contains "$out" "^skelepress [0-9]+\.[0-9]+\.[0-9]+$" "skelepress-dev reports toolkit version"

  # A development install owns its own directory and leaves the stable one
  # alone: the managed layout is named after the release tag, with the `v` the
  # network installer uses, and `current` belongs to releases.
  local version
  version="$(cat "${ROOT_DIR}/VERSION")"
  if [[ -d "${install_home}/versions/v${version}-dev" ]]; then
    pass "a development install uses a v-prefixed directory of its own"
  else
    fail "a development install must land in versions/v${version}-dev"
  fi

  if [[ -e "${install_home}/current" ]]; then
    fail "a development install must not repoint the stable current link"
  else
    pass "a development install leaves the stable current link alone"
  fi

  # The local installer builds the released payload, not a copy of the repo, so
  # a local install cannot test something the artifact does not ship.
  local payload_dir
  payload_dir="${install_home}/versions/v${version}-dev"
  if [[ -e "${payload_dir}/LICENSE" && ! -e "${payload_dir}/examples" \
    && ! -e "${payload_dir}/Makefile" && ! -e "${payload_dir}/scripts/dev" ]]; then
    pass "a local install carries the released payload and nothing else"
  else
    fail "a local install must carry the released payload, not the repository"
  fi

  rm -rf "$sandbox"
  rm -f "$out"
}

run_install_local_release_layout_test() {
  local sandbox out
  sandbox="$(mktemp -d)"
  out="$(mktemp)"

  local install_home install_bin
  install_home="${sandbox}/managed"
  install_bin="${sandbox}/bin"

  set +e
  SKELEPRESS_INSTALL_HOME="$install_home" SKELEPRESS_INSTALL_DIR="$install_bin" \
    /bin/bash "${ROOT_DIR}/scripts/delivery/install-local.sh" >"$out" 2>&1
  local code=$?
  set -e

  local version
  version="$(cat "${ROOT_DIR}/VERSION")"
  assert_exit_code "0" "$code" "a release-shaped local install completes"
  if [[ -L "${install_home}/current" && -d "${install_home}/versions/v${version}" ]]; then
    pass "a release-shaped local install uses the v-prefixed tag and sets current"
  else
    fail "a release-shaped local install must use versions/v${version} and point current at it"
  fi
  assert_contains "$out" "Installed skelepress ${version} from local repo" \
    "the release-shaped install reports the version it installed"

  rm -rf "$sandbox"
  rm -f "$out"
}
