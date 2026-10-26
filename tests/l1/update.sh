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
if [[ -n "${TMP_EXPECT_AUTH_TOKEN:-}" ]]; then
  found="0"
  for arg in "$@"; do
    if [[ "$arg" == "Authorization: Bearer ${TMP_EXPECT_AUTH_TOKEN}" ]]; then
      found="1"
      break
    fi
  done
  [[ "$found" == "1" ]] || exit 1
fi
printf '{"tag_name":"%s"}\n' "${TMP_UPDATE_TAG:-v1.0.0}"
EOF
  chmod +x "${tmpbin}/curl"

  local out
  out="$(mktemp)"

  set +e
  TMP_UPDATE_TAG=v9.9.9 PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" PANDOC_PDF_UPDATE_API_URL="https://example.invalid/releases/latest" "$CLI" update --check >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "0" "$code" "update --check succeeds when release metadata is available"
  assert_contains "$out" "Current version: [0-9]+\.[0-9]+\.[0-9]+" "update --check prints current version"
  assert_contains "$out" "Latest version: 9\.9\.9" "update --check prints latest version"
  assert_contains "$out" "Update available: [0-9]+\.[0-9]+\.[0-9]+ -> 9\.9\.9" "update --check reports available update"

  set +e
  TMP_UPDATE_TAG="v${current_version}" PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" PANDOC_PDF_UPDATE_API_URL="https://example.invalid/releases/latest" "$CLI" update --check >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "update --check succeeds when already up to date"
  assert_contains "$out" "You are already on the latest stable version" "update --check reports up-to-date status"

  set +e
  TMP_EXPECT_AUTH_TOKEN=token-123 TMP_UPDATE_TAG=v1.0.0 PANDOC_PDF_UPDATE_TOKEN=token-123 PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" PANDOC_PDF_UPDATE_API_URL="https://example.invalid/releases/latest" "$CLI" update --check >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "update --check sends auth header when token is configured"

  set +e
  PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update >"$out" 2>&1
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
  artifact_name="pandoc-pdf_${os}_${arch}.tar.gz"

  local payload_dir
  payload_dir="${sandbox}/payload"
  mkdir -p "$payload_dir"
  cat >"${payload_dir}/pandoc-pdf" <<'EOF'
#!/bin/bash
echo "pandoc-pdf 9.9.9"
EOF
  chmod +x "${payload_dir}/pandoc-pdf"

  local artifact_path
  artifact_path="${sandbox}/${artifact_name}"
  tar -czf "$artifact_path" -C "$payload_dir" pandoc-pdf

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
  TMP_UPDATE_RELEASE_JSON="$release_json" TMP_UPDATE_ARTIFACT="$artifact_name" TMP_UPDATE_ARTIFACT_PATH="$artifact_path" TMP_UPDATE_CHECKSUMS_PATH="$checksums_path" PANDOC_PDF_UPDATE_HOME="${sandbox}/managed" PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --dry-run --install-dir "$install_dir_dry" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "0" "$code" "update --dry-run returns success"
  assert_contains "$out" "Target version: 9\.9\.9" "update --dry-run prints target version"
  assert_contains "$out" "Install path: .*/dry-bin/pandoc-pdf" "update --dry-run prints install path"
  assert_contains "$out" "Managed root: .*/managed" "update --dry-run prints managed root"

  if [[ -f "${install_dir_dry}/pandoc-pdf" ]]; then
    fail "update --dry-run should not install binary"
  else
    pass "update --dry-run does not write binary"
  fi

  set +e
  TMP_UPDATE_RELEASE_JSON="$release_json" TMP_UPDATE_ARTIFACT="$artifact_name" TMP_UPDATE_ARTIFACT_PATH="$artifact_path" TMP_UPDATE_CHECKSUMS_PATH="$checksums_path" PANDOC_PDF_UPDATE_HOME="${sandbox}/managed" PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --yes --install-dir "$install_dir" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "update --to installs target version"
  assert_contains "$out" "Updated to version 9\.9\.9" "update --to reports installed version"

  if [[ -x "${install_dir}/pandoc-pdf" ]]; then
    pass "update --to writes executable binary"
  else
    fail "update --to should write executable binary"
  fi

  if [[ -x "${sandbox}/managed/versions/v9.9.9/bin/pandoc-pdf" ]]; then
    pass "update --to stores toolkit under managed versions directory"
  else
    fail "update --to should store toolkit in managed versions directory"
  fi

  local installed_version_out
  installed_version_out="$("${install_dir}/pandoc-pdf")"
  if [[ "$installed_version_out" == "pandoc-pdf 9.9.9" ]]; then
    pass "installed binary reports target version"
  else
    fail "installed binary should report target version"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}

run_update_install_private_api_asset_test() {
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
  artifact_name="pandoc-pdf_${os}_${arch}.tar.gz"

  local payload_dir
  payload_dir="${sandbox}/payload"
  mkdir -p "$payload_dir"
  cat >"${payload_dir}/pandoc-pdf" <<'EOF'
#!/bin/bash
echo "pandoc-pdf 8.8.8"
EOF
  chmod +x "${payload_dir}/pandoc-pdf"

  local artifact_path
  artifact_path="${sandbox}/${artifact_name}"
  tar -czf "$artifact_path" -C "$payload_dir" pandoc-pdf

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

  local artifact_api checksums_api
  artifact_api="https://api.github.com/repos/pablobernardo/pandoc-toolkit/releases/assets/asset-888"
  checksums_api="https://api.github.com/repos/pablobernardo/pandoc-toolkit/releases/assets/checksums-888"

  local release_json
  release_json="${sandbox}/release.json"
  cat >"$release_json" <<EOF
{"tag_name":"v8.8.8","assets":[{"name":"${artifact_name}","url":"${artifact_api}","browser_download_url":"https://downloads.invalid/${artifact_name}"},{"name":"checksums.txt","url":"${checksums_api}","browser_download_url":"https://downloads.invalid/checksums.txt"}]}
EOF

  cat >"${tmpbin}/curl" <<'EOF'
#!/bin/bash
set -euo pipefail
url=""
out=""
auth_ok="0"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      out="$2"
      shift 2
      ;;
    -H|--header)
      if [[ "${2:-}" == "Authorization: Bearer ${TMP_EXPECT_AUTH_TOKEN}" ]]; then
        auth_ok="1"
      fi
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

if [[ -n "${TMP_EXPECT_AUTH_TOKEN:-}" && "$auth_ok" != "1" ]]; then
  exit 1
fi

if [[ "$url" == *"/releases/tags/"* ]]; then
  cat "$TMP_UPDATE_RELEASE_JSON"
  exit 0
fi

if [[ "$url" == "$TMP_UPDATE_ARTIFACT_API" ]]; then
  cp "$TMP_UPDATE_ARTIFACT_PATH" "$out"
  exit 0
fi

if [[ "$url" == "$TMP_UPDATE_CHECKSUMS_API" ]]; then
  cp "$TMP_UPDATE_CHECKSUMS_PATH" "$out"
  exit 0
fi

exit 1
EOF
  chmod +x "${tmpbin}/curl"

  local out install_dir
  out="$(mktemp)"
  install_dir="${sandbox}/bin"

  set +e
  TMP_EXPECT_AUTH_TOKEN=token-888 TMP_UPDATE_RELEASE_JSON="$release_json" TMP_UPDATE_ARTIFACT_API="$artifact_api" TMP_UPDATE_ARTIFACT_PATH="$artifact_path" TMP_UPDATE_CHECKSUMS_API="$checksums_api" TMP_UPDATE_CHECKSUMS_PATH="$checksums_path" PANDOC_PDF_UPDATE_TOKEN=token-888 PANDOC_PDF_UPDATE_HOME="${sandbox}/managed" PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v8.8.8 --yes --install-dir "$install_dir" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "0" "$code" "update uses API asset URLs for authenticated private releases"
  assert_contains "$out" "Updated to version 8\.8\.8" "update reports installed version from API asset download"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}

run_update_dev_command_blocked_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin"
  ln -sf "$CLI" "${sandbox}/bin/pandoc-pdf-dev"

  local out
  out="$(mktemp)"

  set +e
  PANDOC_PDF_LANG=en "${sandbox}/bin/pandoc-pdf-dev" update --yes >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "update install is blocked for pandoc-pdf-dev invocation"
  assert_contains "$out" "update is disabled for pandoc-pdf-dev" "update reports dev invocation policy"

  rm -rf "$sandbox"
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
  artifact_name="pandoc-pdf_${os}_${arch}.tar.gz"

  local payload_dir
  payload_dir="${sandbox}/payload"
  mkdir -p "$payload_dir"
  cat >"${payload_dir}/pandoc-pdf" <<'EOF'
#!/bin/bash
echo "pandoc-pdf invalid"
EOF
  chmod +x "${payload_dir}/pandoc-pdf"

  local artifact_path
  artifact_path="${sandbox}/${artifact_name}"
  tar -czf "$artifact_path" -C "$payload_dir" pandoc-pdf

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

  cat >"${managed_root}/versions/v1.0.0/bin/pandoc-pdf" <<'EOF'
#!/bin/bash
echo "pandoc-pdf 1.0.0"
EOF
  chmod +x "${managed_root}/versions/v1.0.0/bin/pandoc-pdf"

  ln -sfn "${managed_root}/versions/v1.0.0" "${managed_root}/current"
  ln -sfn "${managed_root}/current/bin/pandoc-pdf" "${install_dir}/pandoc-pdf"

  local out
  out="$(mktemp)"

  set +e
  TMP_UPDATE_RELEASE_JSON="$release_json" TMP_UPDATE_ARTIFACT="$artifact_name" TMP_UPDATE_ARTIFACT_PATH="$artifact_path" TMP_UPDATE_CHECKSUMS_PATH="$checksums_path" PANDOC_PDF_UPDATE_HOME="$managed_root" PANDOC_PDF_LANG=en PATH="${tmpbin}:$PATH" "$CLI" update --to v9.9.9 --yes --install-dir "$install_dir" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "update rolls back when post-install version validation fails"
  assert_contains "$out" "update installation failed" "update reports install failure after rollback"

  local after_version
  after_version="$("${install_dir}/pandoc-pdf")"
  if [[ "$after_version" == "pandoc-pdf 1.0.0" ]]; then
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
