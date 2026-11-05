#!/bin/bash
# update area tests. Sourced by tests/run.sh (not run standalone).

run_update_check_tests() {
  local tmpbin
  tmpbin="$(mktemp -d)"

  local current_version
  current_version="$("$CLI" --version | awk '{print $2}')"

  cat >"${tmpbin}/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
printf '{"tag_name":"%s"}\n' "${TMP_UPDATE_TAG:-v1.0.0}"
EOF
  chmod +x "${tmpbin}/curl"

  local out
  out="$(mktemp)"

  set +e
  TMP_UPDATE_TAG=v9.9.9 SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" SKELEPRESS_UPDATE_API_URL="https://example.invalid/releases/latest" "$CLI" update --check >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "0" "$code" "update --check succeeds when release metadata is available"
  assert_contains "$out" "Current version: [0-9]+\.[0-9]+\.[0-9]+" "update --check prints current version"
  assert_contains "$out" "Latest version: 9\.9\.9" "update --check prints latest version"
  assert_contains "$out" "Update available: [0-9]+\.[0-9]+\.[0-9]+ -> 9\.9\.9" "update --check reports available update"

  set +e
  TMP_UPDATE_TAG="v${current_version}" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" SKELEPRESS_UPDATE_API_URL="https://example.invalid/releases/latest" "$CLI" update --check >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "update --check succeeds when already up to date"
  assert_contains "$out" "You are already on the latest stable version" "update --check reports up-to-date status"

  assert_exit_code "0" "$code" "update --check sends auth header when token is configured"

  set +e
  SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "update without --check fails with incomplete release metadata"
  assert_contains "$out" "artifact not found in release" "update without --check reports missing release artifact with minimal metadata"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_update_install_tests() {
  local sandbox
  sandbox="$(mktemp -d)"
  local tmpbin
  tmpbin="$(mktemp -d)"

  local os arch artifact_name
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    darwin) os="darwin" ;;
    linux) os="linux" ;;
    *) os="linux" ;;
  esac
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) arch="amd64" ;;
  esac
  artifact_name="skelepress_${os}_${arch}.tar.gz"

  local payload_dir
  payload_dir="${sandbox}/payload"
  mkdir -p "$payload_dir"
  cat >"${payload_dir}/skelepress" <<'EOF'
#!/bin/bash
echo "skelepress 9.9.9"
EOF
  chmod +x "${payload_dir}/skelepress"

  local artifact_path
  artifact_path="${sandbox}/${artifact_name}"
  tar -czf "$artifact_path" -C "$payload_dir" skelepress

  local checksums_path
  checksums_path="${sandbox}/checksums.txt"
  local sha
  sha="$(python3 - <<'PY' "$artifact_path"
import hashlib
import sys
path = sys.argv[1]
h = hashlib.sha256()
with open(path, 'rb') as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b''):
        h.update(chunk)
print(h.hexdigest())
PY
)"
  printf '%s  %s\n' "$sha" "$artifact_name" >"$checksums_path"

  local release_json
  release_json="${sandbox}/release.json"
  cat >"$release_json" <<EOF
{"tag_name":"v9.9.9","assets":[{"name":"${artifact_name}","browser_download_url":"https://downloads.invalid/${artifact_name}"},{"name":"checksums.txt","browser_download_url":"https://downloads.invalid/checksums.txt"}]}
EOF

  cat >"${tmpbin}/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
url=""
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      out="$2"
      shift 2
      ;;
    -H|--header)
      shift 2
      ;;
    -f|-s|-S|-L|--fail|--silent|--show-error|--location)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

if [[ "$url" == *"/releases/tags/"* ]]; then
  cat "$TMP_UPDATE_RELEASE_JSON"
  exit 0
fi

if [[ "$url" == "https://downloads.invalid/${TMP_UPDATE_ARTIFACT}" ]]; then
  cp "$TMP_UPDATE_ARTIFACT_PATH" "$out"
  exit 0
fi

if [[ "$url" == "https://downloads.invalid/checksums.txt" ]]; then
  cp "$TMP_UPDATE_CHECKSUMS_PATH" "$out"
  exit 0
fi

exit 1
EOF
  chmod +x "${tmpbin}/curl"

  local out install_dir install_dir_dry
  out="$(mktemp)"
  install_dir="${sandbox}/bin"
  install_dir_dry="${sandbox}/dry-bin"

  set +e
  TMP_UPDATE_RELEASE_JSON="$release_json" TMP_UPDATE_ARTIFACT="$artifact_name" TMP_UPDATE_ARTIFACT_PATH="$artifact_path" TMP_UPDATE_CHECKSUMS_PATH="$checksums_path" SKELEPRESS_UPDATE_HOME="${sandbox}/managed" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --dry-run --install-dir "$install_dir_dry" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "0" "$code" "update --dry-run returns success"
  assert_contains "$out" "Target version: 9\.9\.9" "update --dry-run prints target version"
  assert_contains "$out" "Install path: .*/dry-bin/skelepress" "update --dry-run prints install path"
  assert_contains "$out" "Managed root: .*/managed" "update --dry-run prints managed root"

  if [[ -f "${install_dir_dry}/skelepress" ]]; then
    fail "update --dry-run should not install binary"
  else
    pass "update --dry-run does not write binary"
  fi

  set +e
  TMP_UPDATE_RELEASE_JSON="$release_json" TMP_UPDATE_ARTIFACT="$artifact_name" TMP_UPDATE_ARTIFACT_PATH="$artifact_path" TMP_UPDATE_CHECKSUMS_PATH="$checksums_path" SKELEPRESS_UPDATE_HOME="${sandbox}/managed" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --yes --install-dir "$install_dir" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "update --to installs target version"
  assert_contains "$out" "Updated to version 9\.9\.9" "update --to reports installed version"

  if [[ -x "${install_dir}/skelepress" ]]; then
    pass "update --to writes executable binary"
  else
    fail "update --to should write executable binary"
  fi

  if [[ -x "${sandbox}/managed/versions/v9.9.9/bin/skelepress" ]]; then
    pass "update --to stores toolkit under managed versions directory"
  else
    fail "update --to should store toolkit in managed versions directory"
  fi

  local installed_version_out
  installed_version_out="$("${install_dir}/skelepress")"
  if [[ "$installed_version_out" == "skelepress 9.9.9" ]]; then
    pass "installed binary reports target version"
  else
    fail "installed binary should report target version"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}


run_update_dev_command_blocked_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin"
  ln -sf "$CLI" "${sandbox}/bin/skelepress-dev"

  local out
  out="$(mktemp)"

  set +e
  SKELEPRESS_LANG=en "${sandbox}/bin/skelepress-dev" update --yes >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "update install is blocked for skelepress-dev invocation"
  assert_contains "$out" "update is disabled for skelepress-dev" "update reports dev invocation policy"

  rm -rf "$sandbox"
  rm -f "$out"
}

# The installers declare where they put things with SKELEPRESS_INSTALL_HOME and
# SKELEPRESS_INSTALL_DIR; the updater used to ignore both and silently write to
# the default locations. The resolution order is: the variable named for this
# command, then the installer variable, then the historical default; for the
# binary directory --install-dir comes first, then SKELEPRESS_INSTALL_DIR (a
# declared directory beats the skelepress found on PATH), then the writable
# directory of the skelepress on PATH, then ~/.local/bin.
run_update_resolution_precedence_tests() {
  local sandbox tmpbin out code
  sandbox="$(mktemp -d)"
  tmpbin="$(mktemp -d)"
  out="$(mktemp)"

  local os arch artifact_name
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    darwin) os="darwin" ;;
    linux) os="linux" ;;
    *) os="linux" ;;
  esac
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) arch="amd64" ;;
  esac
  artifact_name="skelepress_${os}_${arch}.tar.gz"

  local release_json
  release_json="${sandbox}/release.json"
  cat >"$release_json" <<EOF
{"tag_name":"v9.9.9","assets":[{"name":"${artifact_name}","browser_download_url":"https://downloads.invalid/${artifact_name}"},{"name":"checksums.txt","browser_download_url":"https://downloads.invalid/checksums.txt"}]}
EOF

  cat >"${tmpbin}/curl" <<'MOCK'
#!/bin/bash
cat "$TMP_UPDATE_RELEASE_JSON"
printf '200\n'
MOCK
  chmod +x "${tmpbin}/curl"
  export TMP_UPDATE_RELEASE_JSON="$release_json"

  local home_dir update_home install_home path_dir declared_dir flag_dir readonly_dir
  home_dir="${sandbox}/home"
  update_home="${sandbox}/update-home"
  install_home="${sandbox}/install-home"
  path_dir="${sandbox}/path-bin"
  declared_dir="${sandbox}/declared-bin"
  flag_dir="${sandbox}/flag-bin"
  readonly_dir="${sandbox}/readonly-bin"
  mkdir -p "$home_dir" "$path_dir" "$declared_dir" "$flag_dir" "$readonly_dir"
  printf '#!/bin/bash\n' >"${path_dir}/skelepress"
  printf '#!/bin/bash\n' >"${readonly_dir}/skelepress"
  chmod +x "${path_dir}/skelepress" "${readonly_dir}/skelepress"
  chmod 555 "$readonly_dir"

  set +e
  SKELEPRESS_UPDATE_HOME="$update_home" SKELEPRESS_INSTALL_HOME="$install_home" HOME="$home_dir" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "update --dry-run resolves with both managed-home variables set"
  assert_contains "$out" "Managed root: ${update_home}" "SKELEPRESS_UPDATE_HOME beats SKELEPRESS_INSTALL_HOME"

  set +e
  SKELEPRESS_INSTALL_HOME="$install_home" HOME="$home_dir" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_contains "$out" "Managed root: ${install_home}" "SKELEPRESS_INSTALL_HOME sets the managed root"

  set +e
  HOME="$home_dir" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_contains "$out" "Managed root: ${home_dir}/\.local/share/skelepress" "without variables the managed root is the default under HOME"

  set +e
  SKELEPRESS_INSTALL_DIR="$declared_dir" HOME="$home_dir" SKELEPRESS_LANG=en PATH="${tmpbin}:${path_dir}:$PATH" "$CLI" update --to v9.9.9 --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_contains "$out" "Install path: ${declared_dir}/skelepress" "SKELEPRESS_INSTALL_DIR beats the skelepress found on PATH"

  set +e
  SKELEPRESS_INSTALL_DIR="$declared_dir" HOME="$home_dir" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --dry-run --install-dir "$flag_dir" >"$out" 2>&1
  code=$?
  set -e
  assert_contains "$out" "Install path: ${flag_dir}/skelepress" "--install-dir beats SKELEPRESS_INSTALL_DIR"

  set +e
  HOME="$home_dir" SKELEPRESS_LANG=en PATH="${tmpbin}:${path_dir}:$PATH" "$CLI" update --to v9.9.9 --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_contains "$out" "Install path: ${path_dir}/skelepress" "the writable directory of the skelepress on PATH is the install dir"

  set +e
  HOME="$home_dir" SKELEPRESS_LANG=en PATH="${tmpbin}:${readonly_dir}:$PATH" "$CLI" update --to v9.9.9 --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_contains "$out" "Install path: ${home_dir}/\.local/bin/skelepress" "an unwritable PATH directory falls back to HOME/.local/bin"

  chmod 755 "$readonly_dir"
  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}

run_update_rollback_on_validation_failure_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  local tmpbin
  tmpbin="$(mktemp -d)"

  local os arch artifact_name
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
  case "$os" in
    darwin) os="darwin" ;;
    linux) os="linux" ;;
    *) os="linux" ;;
  esac
  case "$arch" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) arch="amd64" ;;
  esac
  artifact_name="skelepress_${os}_${arch}.tar.gz"

  local payload_dir
  payload_dir="${sandbox}/payload"
  mkdir -p "$payload_dir"
  cat >"${payload_dir}/skelepress" <<'EOF'
#!/bin/bash
echo "skelepress invalid"
EOF
  chmod +x "${payload_dir}/skelepress"

  local artifact_path
  artifact_path="${sandbox}/${artifact_name}"
  tar -czf "$artifact_path" -C "$payload_dir" skelepress

  local checksums_path
  checksums_path="${sandbox}/checksums.txt"
  local sha
  sha="$(python3 - <<'PY' "$artifact_path"
import hashlib
import sys
path = sys.argv[1]
h = hashlib.sha256()
with open(path, 'rb') as f:
    for chunk in iter(lambda: f.read(1024 * 1024), b''):
        h.update(chunk)
print(h.hexdigest())
PY
)"
  printf '%s  %s\n' "$sha" "$artifact_name" >"$checksums_path"

  local release_json
  release_json="${sandbox}/release.json"
  cat >"$release_json" <<EOF
{"tag_name":"v9.9.9","assets":[{"name":"${artifact_name}","browser_download_url":"https://downloads.invalid/${artifact_name}"},{"name":"checksums.txt","browser_download_url":"https://downloads.invalid/checksums.txt"}]}
EOF

  cat >"${tmpbin}/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
url=""
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      out="$2"
      shift 2
      ;;
    -H|--header)
      shift 2
      ;;
    -f|-s|-S|-L|--fail|--silent|--show-error|--location)
      shift
      ;;
    *)
      url="$1"
      shift
      ;;
  esac
done

if [[ "$url" == *"/releases/tags/"* ]]; then
  cat "$TMP_UPDATE_RELEASE_JSON"
  exit 0
fi

if [[ "$url" == "https://downloads.invalid/${TMP_UPDATE_ARTIFACT}" ]]; then
  cp "$TMP_UPDATE_ARTIFACT_PATH" "$out"
  exit 0
fi

if [[ "$url" == "https://downloads.invalid/checksums.txt" ]]; then
  cp "$TMP_UPDATE_CHECKSUMS_PATH" "$out"
  exit 0
fi

exit 1
EOF
  chmod +x "${tmpbin}/curl"

  local managed_root install_dir
  managed_root="${sandbox}/managed"
  install_dir="${sandbox}/bin"
  mkdir -p "${managed_root}/versions/v1.0.0/bin" "$install_dir"

  cat >"${managed_root}/versions/v1.0.0/bin/skelepress" <<'EOF'
#!/bin/bash
echo "skelepress 1.0.0"
EOF
  chmod +x "${managed_root}/versions/v1.0.0/bin/skelepress"

  ln -sfn "${managed_root}/versions/v1.0.0" "${managed_root}/current"
  ln -sfn "${managed_root}/current/bin/skelepress" "${install_dir}/skelepress"

  local out
  out="$(mktemp)"

  set +e
  TMP_UPDATE_RELEASE_JSON="$release_json" TMP_UPDATE_ARTIFACT="$artifact_name" TMP_UPDATE_ARTIFACT_PATH="$artifact_path" TMP_UPDATE_CHECKSUMS_PATH="$checksums_path" SKELEPRESS_UPDATE_HOME="$managed_root" SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --yes --install-dir "$install_dir" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "update rolls back when post-install version validation fails"
  assert_contains "$out" "update installation failed" "update reports install failure after rollback"

  local after_version
  after_version="$("${install_dir}/skelepress")"
  if [[ "$after_version" == "skelepress 1.0.0" ]]; then
    pass "rollback restores previously installed binary"
  else
    fail "rollback should restore previous binary"
  fi

  local current_target
  current_target="$(readlink "${managed_root}/current" || true)"
  if [[ "$current_target" == "${managed_root}/versions/v1.0.0" ]]; then
    pass "rollback restores current pointer"
  else
    fail "rollback should restore current pointer"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}

# The updater used to say "could not fetch latest release metadata" for a missing
# release, an exhausted quota and a dead network alike, and then suggested a token
# for private repositories. Public repositories need no token for a download; what
# they need is to be told which of the three happened.
run_update_diagnostics_tests() {
  local tmpbin out code
  tmpbin="$(mktemp -d)"
  out="$(mktemp)"

  cat >"${tmpbin}/curl" <<'MOCK'
#!/bin/bash
set -euo pipefail
for arg in "$@"; do
  if [[ "${TMP_FORBID_AUTH:-0}" == "1" && "$arg" == "Authorization:"* ]]; then
    exit 99
  fi
done
printf '%s\n' "${TMP_UPDATE_BODY:-{\"tag_name\":\"v1.0.0\"}}"
printf '%s\n' "${TMP_UPDATE_HTTP_STATUS:-200}"
MOCK
  chmod +x "${tmpbin}/curl"

  # 404: the release does not exist yet.
  set +e
  TMP_UPDATE_HTTP_STATUS=404 TMP_UPDATE_BODY='{"message":"Not Found"}' \
    SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" \
    SKELEPRESS_UPDATE_API_URL="https://example.invalid/releases/latest" \
    "$CLI" update --check >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "a missing release fails update --check"
  assert_contains "$out" "no release published" "a 404 says the release does not exist yet"

  # 403: the anonymous quota is spent.
  set +e
  TMP_UPDATE_HTTP_STATUS=403 TMP_UPDATE_BODY='{"message":"rate limit exceeded"}' \
    SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" \
    SKELEPRESS_UPDATE_API_URL="https://example.invalid/releases/latest" \
    "$CLI" update --check >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "an exhausted quota fails update --check"
  assert_contains "$out" "quota" "a 403 names the anonymous quota"

  # Anything else: the status is reported rather than guessed.
  set +e
  TMP_UPDATE_HTTP_STATUS=500 TMP_UPDATE_BODY='{"message":"boom"}' \
    SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" \
    SKELEPRESS_UPDATE_API_URL="https://example.invalid/releases/latest" \
    "$CLI" update --check >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "an unexpected status fails update --check"
  assert_contains "$out" "500" "an unexpected status is reported by number"

  # The token is gone: no Authorization header may be sent even when the old
  # variable is exported, or the removal is cosmetic.
  set +e
  TMP_FORBID_AUTH=1 TMP_UPDATE_HTTP_STATUS=200 SKELEPRESS_UPDATE_TOKEN=token-123 \
    SKELEPRESS_LANG=en PATH="${tmpbin}:$PATH" \
    SKELEPRESS_UPDATE_API_URL="https://example.invalid/releases/latest" \
    "$CLI" update --check >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "update --check never sends an Authorization header"

  rm -rf "$tmpbin"
  rm -f "$out"
}
