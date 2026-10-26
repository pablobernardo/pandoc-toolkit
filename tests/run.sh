#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT_DIR}/bin/pandoc-pdf"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"
REAL_PYTHON3="$(command -v python3 || true)"

# Keep functional tests deterministic in English.
export PANDOC_PDF_LANG="en"

PASS=0
FAIL=0

green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
red() { printf '\033[0;31m%s\033[0m\n' "$1"; }

pass() {
  PASS=$((PASS + 1))
  if [[ "${TEST_VERBOSE:-1}" == "1" ]]; then
    green "✅ PASS [${PASS}] $1"
  else
    green "✅ PASS [${PASS}]"
  fi
}

fail() {
  FAIL=$((FAIL + 1))
  red "❌ FAIL [${FAIL}] $1"
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$msg"
  else
    fail "$msg (expected=${expected}, actual=${actual})"
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if grep -qE -- "$pattern" "$file"; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if grep -qE -- "$pattern" "$file"; then
    fail "$msg"
  else
    pass "$msg"
  fi
}

run_help_test() {
  local out
  out="$(mktemp)"
  if "$CLI" --help >"$out" 2>&1; then
    pass "--help returns exit 0"
  else
    fail "--help should return exit 0"
  fi
  assert_contains "$out" "Usage:" "--help prints usage"
  assert_contains "$out" "pandoc-pdf update --check" "--help includes update check command"
  rm -f "$out"
}

run_help_i18n_notes_test() {
  local out
  out="$(mktemp)"

  if PANDOC_PDF_LANG=es "$CLI" --help >"$out" 2>&1; then
    pass "--help for es locale returns exit 0"
  else
    fail "--help for es locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementación nativa\." "--help translates render note in es"

  if PANDOC_PDF_LANG=pt "$CLI" --help >"$out" 2>&1; then
    pass "--help for pt locale returns exit 0"
  else
    fail "--help for pt locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementação nativa\." "--help translates render note in pt"

  if PANDOC_PDF_LANG=gl "$CLI" --help >"$out" 2>&1; then
    pass "--help for gl locale returns exit 0"
  else
    fail "--help for gl locale should return exit 0"
  fi
  assert_contains "$out" "render usa implementación nativa\." "--help translates render note in gl"

  rm -f "$out"
}

run_version_tests() {
  local out
  out="$(mktemp)"

  if "$CLI" --version >"$out" 2>&1; then
    pass "--version returns exit 0"
  else
    fail "--version should return exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "--version prints semantic version"

  : >"$out"
  if "$CLI" version >"$out" 2>&1; then
    pass "version returns exit 0"
  else
    fail "version should return exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "version prints semantic version"

  rm -f "$out"
}

run_info_tests() {
  local out
  out="$(mktemp)"

  if "$CLI" info >"$out" 2>&1; then
    pass "info returns exit 0"
  else
    fail "info should return exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "info includes version"
  assert_contains "$out" "^root_dir:" "info includes root_dir"
  assert_contains "$out" "^yaml_parser:" "info includes YAML parser"
  assert_contains "$out" "schema_path: .*exists=true" "info reports schema"

  : >"$out"
  if "$CLI" info --json >"$out" 2>&1; then
    pass "info --json returns exit 0"
  else
    fail "info --json should return exit 0"
  fi
  assert_contains "$out" '^\{' "info --json prints JSON object"
  assert_contains "$out" '"name": "pandoc-pdf"' "info --json includes name"
  assert_contains "$out" '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "info --json includes version"
  assert_contains "$out" '"schema_exists": true' "info --json includes schema existence"

  rm -f "$out"
}

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

run_validate_config_tests() {
  local out_ok
  out_ok="$(mktemp)"
  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid.config.yaml" >"$out_ok" 2>&1; then
    pass "validate-config passes with valid config"
  else
    fail "validate-config should pass with valid config"
  fi
  assert_contains "$out_ok" "(Config valid|Config válida)" "validate-config prints success"
  rm -f "$out_ok"

  local out_no_template
  out_no_template="$(mktemp)"
  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid-missing-template.config.yaml" >"$out_no_template" 2>&1; then
    pass "validate-config passes when pandoc.template is not provided"
  else
    fail "validate-config should pass without pandoc.template (uses default)"
  fi
  assert_contains "$out_no_template" "(Config valid|Config válida)" "validate-config confirms valid config without template"
  rm -f "$out_no_template"

  local out_bad
  out_bad="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-version.yaml" >"$out_bad" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "validate-config fails when version is missing"
  assert_contains "$out_bad" "version" "validate-config reports missing field"
  rm -f "$out_bad"

  local out_type
  out_type="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-type-runtime-strict.yaml" >"$out_type" 2>&1
  local code_type=$?
  set -e
  assert_exit_code "1" "$code_type" "validate-config fails due to invalid type"
  assert_contains "$out_type" "runtime\.strict" "validate-config reports invalid type"
  rm -f "$out_type"

  local out_extra
  out_extra="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-extra-root-field.yaml" >"$out_extra" 2>&1
  local code_extra=$?
  set -e
  assert_exit_code "1" "$code_extra" "validate-config fails due to extra field"
  assert_contains "$out_extra" "(disallowed|no permitidos)" "validate-config reports additionalProperties"
  rm -f "$out_extra"

  local out_template_path
  out_template_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-template-path.yaml" >"$out_template_path" 2>&1
  local code_template_path=$?
  set -e
  assert_exit_code "1" "$code_template_path" "validate-config fails when pandoc.template does not exist"
  assert_contains "$out_template_path" "pandoc\.template" "validate-config reports invalid template path"
  rm -f "$out_template_path"

  local out_chapters_path
  out_chapters_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-chapters-dir.yaml" >"$out_chapters_path" 2>&1
  local code_chapters_path=$?
  set -e
  assert_exit_code "1" "$code_chapters_path" "validate-config fails when input.chapters_dir does not exist"
  assert_contains "$out_chapters_path" "input\.chapters_dir" "validate-config reports invalid chapters_dir path"
  rm -f "$out_chapters_path"

  local out_extra_filter_path
  out_extra_filter_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-extra-filter-path.yaml" >"$out_extra_filter_path" 2>&1
  local code_extra_filter_path=$?
  set -e
  assert_exit_code "1" "$code_extra_filter_path" "validate-config fails when extra_lua_filter does not exist"
  assert_contains "$out_extra_filter_path" "extra_lua_filters\[0\]" "validate-config reports invalid extra_lua_filter path"
  rm -f "$out_extra_filter_path"
}

run_validate_metadata_file_test() {
  local out code
  out="$(mktemp)"

  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid.config.yaml" >"$out" 2>&1; then
    pass "validate-config accepts a config whose metadata_file exists"
  else
    fail "validate-config should accept valid.config.yaml ($(tail -2 "$out"))"
  fi

  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-metadata-file.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "validate-config rejects a metadata_file that does not exist"
  assert_contains "$out" "pandoc.metadata_file" "the error names the pandoc.metadata_file field"
  assert_contains "$out" "nope-missing.yaml" "the error names the missing file"

  rm -f "$out"
}

run_render_legacy_flag_rejected_test() {
  local out
  out="$(mktemp)"
  set +e
  "$CLI" render --legacy -c "${FIXTURES_DIR}/render.config.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "render rejects --legacy flag"
  assert_contains "$out" "Unknown argument" "render reports invalid legacy flag"
  rm -f "$out"
}

run_render_no_yaml_parser_hints_i18n_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates" "${sandbox}/i18n/locales"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${ROOT_DIR}/i18n/locales/es.json" "${sandbox}/i18n/locales/es.json"
  cp "${ROOT_DIR}/i18n/locales/en.json" "${sandbox}/i18n/locales/en.json"
  cp "${FIXTURES_DIR}/render.config.yaml" "${sandbox}/render.config.yaml"

  cat >"${sandbox}/chapters/title-a.md" <<'EOF'
# Title A
EOF

  cat >"${sandbox}/chapters/title-b.md" <<'EOF'
# Title B
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/metadata.yaml" <<'EOF'
title: Render Test
EOF

  local tmpbin
  tmpbin="$(mktemp -d)"

  # Simula "python3 sin PyYAML": la sonda de detección (`python3 -` con un solo
  # argumento) falla, validate-config se salta (no es lo que mide este test) y el
  # volcado del catálogo (`python3 - <locale.json>`) usa el intérprete real, para
  # que los mensajes salgan traducidos desde el catálogo de verdad.
  cat >"${tmpbin}/python3" <<EOF
#!/bin/bash
set -euo pipefail
if [[ "\${1:-}" == *"validate-config.py" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "-" && \$# -eq 1 ]]; then
  exit 1
fi
exec "${REAL_PYTHON3}" "\$@"
EOF
  chmod +x "${tmpbin}/python3"

  cat >"${tmpbin}/ruby" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 1
EOF
  chmod +x "${tmpbin}/ruby"

  local out
  out="$(mktemp)"

  set +e
  PANDOC_PDF_LANG=es PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render.config.yaml" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "render fails without available YAML parser"
  assert_contains "$out" "No hay parser YAML disponible" "render reports missing YAML parser"
  assert_contains "$out" "Opción 1: python3 -m pip install pyyaml" "render suggests translated option 1"
  assert_contains "$out" "Opción 2: instalar Ruby con stdlib YAML" "render suggests translated option 2"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}

run_render_native_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render.config.yaml" "${sandbox}/render.config.yaml"

  cat >"${sandbox}/chapters/title-a.md" <<'EOF'
# Chapter A

Contenido A
EOF

  cat >"${sandbox}/chapters/title-b.md" <<'EOF'
# Chapter B

Contenido B
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/metadata.yaml" <<'EOF'
title: Render Test
EOF

  local tmpbin
  tmpbin="$(mktemp -d)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_EMOJI_DIR=${PANDOC_EMOJI_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_OUTPUT_DIR=${PANDOC_MERMAID_OUTPUT_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_BACKGROUND=${PANDOC_MERMAID_BACKGROUND:-}" >> "${TMP_PANDOC_CAPTURE}"

out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n "$out" ]]; then
  mkdir -p "$(dirname "$out")"
  : > "$out"
fi
exit 0
EOF
  chmod +x "${tmpbin}/pandoc"

  local capture out suffix md_file pdf_file
  capture="$(mktemp)"
  out="$(mktemp)"
  suffix="$(date +%Y%m%d)"
  md_file="${sandbox}/custom-output/Render Test-${suffix}.md"
  pdf_file="${sandbox}/custom-output/Render Test-${suffix}.pdf"

  if PANDOC_PDF_LANG=es TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render.config.yaml" >"$out" 2>&1; then
    pass "native render runs pandoc"
  else
    fail "native render should run pandoc"
  fi

  assert_contains "$out" "Native mode enabled" "render reports native mode"
  assert_contains "$capture" "custom-output/Render Test-${suffix}\.pdf" "native render respects output.dir"
  assert_contains "$capture" "PANDOC_EMOJI_DIR=.*output/emoji" "native render exports emoji dir"
  assert_contains "$capture" "PANDOC_MERMAID_OUTPUT_DIR=.*output/mermaid" "native render exports mermaid dir"
  assert_contains "$capture" "PANDOC_MERMAID_BACKGROUND=transparent" "native render exports background"

  if [[ -f "$md_file" ]]; then
    pass "native render generates merged markdown"
  else
    fail "native render must generate merged markdown"
  fi

  if [[ -f "$pdf_file" ]]; then
    pass "native render generates output pdf"
  else
    fail "native render must generate output pdf"
  fi

  assert_contains "$md_file" "\\\\clearpage" "native render applies clearpage between H1"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_native_advanced_paths_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/filters" "${sandbox}/assets/media" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render-extra-filter.config.yaml" "${sandbox}/render-extra-filter.config.yaml"

  cat >"${sandbox}/chapters/01-intro.md" <<'EOF'
# Intro

Contenido avanzado
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/filters/custom.lua" <<'EOF'
function Str(el)
  return el
end
EOF

  local tmpbin
  tmpbin="$(mktemp -d)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_EMOJI_DIR=${PANDOC_EMOJI_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_OUTPUT_DIR=${PANDOC_MERMAID_OUTPUT_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_BACKGROUND=${PANDOC_MERMAID_BACKGROUND:-}" >> "${TMP_PANDOC_CAPTURE}"
exit 0
EOF
  chmod +x "${tmpbin}/pandoc"

  local capture out
  capture="$(mktemp)"
  out="$(mktemp)"

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render-extra-filter.config.yaml" >"$out" 2>&1; then
    pass "advanced render runs pandoc"
  else
    fail "advanced render should run pandoc"
  fi

  assert_contains "$capture" "--lua-filter=.*/filters/custom\.lua" "advanced render includes extra_lua_filter"
  assert_contains "$capture" "PANDOC_EMOJI_DIR=.*/dist/assets/emoji" "advanced render respects emoji_dir"
  assert_contains "$capture" "PANDOC_MERMAID_OUTPUT_DIR=.*/dist/assets/mermaid" "advanced render respects mermaid output_dir"
  assert_contains "$capture" "PANDOC_MERMAID_BACKGROUND=white" "advanced render respects mermaid background"
  assert_contains "$capture" "--resource-path=.*/chapters:.*/assets/media" "advanced render composes resource_path"

  if grep -q -- "--metadata-file=" "$capture"; then
    fail "advanced render should not pass metadata-file when empty"
  else
    pass "advanced render omits empty metadata-file"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_no_hidden_defaults_test() {
  if [[ -e "${ROOT_DIR}/scripts/render-native.rb" ]]; then
    fail "the Ruby renderer must not come back: there is one renderer, in Python"
  else
    pass "there is a single renderer (no render-native.rb)"
  fi

  if [[ -e "${ROOT_DIR}/defaults/default.yaml" ]]; then
    fail "the toolkit must not ship a config defaults baseline"
  else
    pass "the toolkit ships no config defaults baseline"
  fi

  if ! command -v ruby >/dev/null 2>&1; then
    echo "SKIP hidden defaults check (ruby not available)"
    return 0
  fi

  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  cat >"${sandbox}/partial.config.yaml" <<'EOF'
project:
  name: partial
  base_dir: ./work

document:
  title: "Partial Document"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  file_prefix: "partial"
  suffix: "manual"

pandoc:
  pdf_engine: lualatex
EOF

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/render-native.py" "${sandbox}/partial.config.yaml" "$sandbox" >"$out" 2>&1; then
    pass "renderer accepts a config without the optional sections"
  else
    fail "renderer should accept a config without the optional sections ($(tail -2 "$out"))"
  fi

  assert_not_contains "$capture" "--resource-path" "a config without resource_path gets no hidden default resource path"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_missing_explicit_file_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render-missing-explicit.config.yaml" "${sandbox}/render-missing-explicit.config.yaml"

  cat >"${sandbox}/chapters/01-intro.md" <<'EOF'
# Intro

Only one file present
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/metadata.yaml" <<'EOF'
title: Missing explicit
EOF

  local out
  out="$(mktemp)"

  set +e
  PANDOC_PDF_LANG=es "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render-missing-explicit.config.yaml" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "render fails when explicit_files references missing file"
  assert_contains "$out" "Explicit file not found" "render reports missing file"

  rm -rf "$sandbox"
  rm -f "$out"
}

# ---------------------------------------------------------------------------
# S1 — config contract alignment
#   input.order / output.keep_merged_markdown / document.* template vars /
#   filters.emoji.include_ballot_icons / runtime.strict
# ---------------------------------------------------------------------------

line_of_match() {
  local file="$1"
  local pattern="$2"
  { grep -n -m1 -E -- "$pattern" "$file" 2>/dev/null || true; } | cut -d: -f1
}

write_pandoc_capture_mock() {
  local bin_dir="$1"
  mkdir -p "$bin_dir"
  cat >"${bin_dir}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
{
  echo "ARGS:$*"
  echo "PANDOC_EMOJI_DIR=${PANDOC_EMOJI_DIR:-}"
  echo "PANDOC_EMOJI_BALLOT_ICONS=${PANDOC_EMOJI_BALLOT_ICONS:-}"
  echo "PANDOC_MERMAID_OUTPUT_DIR=${PANDOC_MERMAID_OUTPUT_DIR:-}"
  echo "PANDOC_MERMAID_BACKGROUND=${PANDOC_MERMAID_BACKGROUND:-}"
} > "${TMP_PANDOC_CAPTURE}"
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -n "$out" ]]; then
  mkdir -p "$(dirname "$out")"
  : > "$out"
fi
exit 0
EOF
  chmod +x "${bin_dir}/pandoc"
}

new_contract_sandbox() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/work/chapters" "${sandbox}/templates"
  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp -R "${ROOT_DIR}/scripts" "${sandbox}/scripts"
  rm -rf "${sandbox}/scripts/__pycache__"
  cp -R "${ROOT_DIR}/schemas" "${sandbox}/schemas"
  cp -R "${ROOT_DIR}/filters" "${sandbox}/filters"
  cp -R "${ROOT_DIR}/i18n" "${sandbox}/i18n"
  cp "${ROOT_DIR}/VERSION" "${sandbox}/VERSION"
  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF
  printf '%s\n' "$sandbox"
}

write_contract_config() {
  local path="$1"
  local order="$2"
  local keep_md="$3"
  local metadata_file="$4"
  local ballot="$5"
  local mermaid="${6:-false}"
  cat >"$path" <<EOF
version: 1

project:
  name: s1-contract
  base_dir: ./work

document:
  title: "S1 Document"
  subtitle: "S1 Subtitle"
  publisher: "S1 Publisher"
  author: "S1 Author"
  date: "2026-01-02"
  rights: "S1 Rights"

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: ${order}
  explicit_files: []

output:
  dir: "out"
  file_prefix: "s1"
  suffix: "manual"
  keep_merged_markdown: ${keep_md}

pandoc:
  pdf_engine: lualatex
  toc: false
  toc_depth: 2
  number_sections: false
  metadata_file: "${metadata_file}"
  resource_path:
    - "chapters"

filters:
  emoji:
    enabled: true
    emoji_dir: "out/emoji"
    include_ballot_icons: ${ballot}
  mermaid:
    enabled: ${mermaid}
    output_dir: "out/mermaid"
    background: "transparent"
  extra_lua_filters: []

runtime:
  required_commands:
    - pandoc
  strict: true

compat:
  legacy_clearpage_between_h1: false
EOF
}

run_render_order_semantics_test() {
  local sandbox tmpbin capture out merged
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  merged="${sandbox}/work/out/S1 Document-manual.md"

  printf '# Chapter Two\n\ncontent two\n' >"${sandbox}/work/chapters/chapter-2.md"
  printf '# Chapter Ten\n\ncontent ten\n' >"${sandbox}/work/chapters/chapter-10.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts input.order=natural"
  else
    fail "render should accept input.order=natural ($(tail -2 "$out"))"
  fi

  local pos_two pos_ten
  pos_two="$(line_of_match "$merged" '^# Chapter Two')"
  pos_ten="$(line_of_match "$merged" '^# Chapter Ten')"
  if [[ -n "$pos_two" && -n "$pos_ten" && "$pos_two" -lt "$pos_ten" ]]; then
    pass "input.order=natural sorts chapter-2 before chapter-10"
  else
    fail "input.order=natural must sort chapter-2 before chapter-10 (two=${pos_two:-none}, ten=${pos_ten:-none})"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" alphabetical true "" true
  rm -f "$merged"
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts input.order=alphabetical"
  else
    fail "render should accept input.order=alphabetical ($(tail -2 "$out"))"
  fi

  pos_two="$(line_of_match "$merged" '^# Chapter Two')"
  pos_ten="$(line_of_match "$merged" '^# Chapter Ten')"
  if [[ -n "$pos_two" && -n "$pos_ten" && "$pos_ten" -lt "$pos_two" ]]; then
    pass "input.order=alphabetical sorts chapter-10 before chapter-2"
  else
    fail "input.order=alphabetical must sort chapter-10 before chapter-2 (two=${pos_two:-none}, ten=${pos_ten:-none})"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" bogus true "" true
  local code
  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "render rejects an unsupported input.order"
  assert_contains "$out" "input.order" "unsupported input.order names the field"
  assert_contains "$out" "alphabetical" "unsupported input.order lists supported values"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_keep_merged_markdown_test() {
  local sandbox tmpbin capture out merged pdf
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  merged="${sandbox}/work/out/S1 Document-manual.md"
  pdf="${sandbox}/work/out/S1 Document-manual.pdf"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural false "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts output.keep_merged_markdown=false"
  else
    fail "render should accept output.keep_merged_markdown=false ($(tail -2 "$out"))"
  fi

  if [[ -f "$pdf" ]]; then
    pass "keep_merged_markdown=false still writes the PDF"
  else
    fail "keep_merged_markdown=false must still write the PDF"
  fi

  if [[ -f "$merged" ]]; then
    fail "keep_merged_markdown=false must remove the merged markdown"
  else
    pass "keep_merged_markdown=false removes the merged markdown"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts output.keep_merged_markdown=true"
  else
    fail "render should accept output.keep_merged_markdown=true ($(tail -2 "$out"))"
  fi

  if [[ -f "$merged" ]]; then
    pass "keep_merged_markdown=true keeps the merged markdown"
  else
    fail "keep_merged_markdown=true must keep the merged markdown"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_document_vars_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render succeeds without metadata_file"
  else
    fail "render should succeed without metadata_file ($(tail -2 "$out"))"
  fi

  assert_contains "$capture" "-V title=S1 Document" "document.title is passed as a template variable"
  assert_contains "$capture" "-V subtitle=S1 Subtitle" "document.subtitle is passed as a template variable"
  assert_contains "$capture" "-V publisher=S1 Publisher" "document.publisher is passed as a template variable"
  assert_contains "$capture" "-V author=S1 Author" "document.author is passed as a template variable"
  assert_contains "$capture" "-V date=2026-01-02" "document.date is passed as a template variable"
  assert_contains "$capture" "-V rights=S1 Rights" "document.rights is passed as a template variable"

  printf 'title: Metadata Title\nauthor: Metadata Author\n' >"${sandbox}/work/metadata.yaml"
  write_contract_config "${sandbox}/pdf.config.yaml" natural true "metadata.yaml" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render succeeds with metadata_file"
  else
    fail "render should succeed with metadata_file ($(tail -2 "$out"))"
  fi

  assert_contains "$capture" "--metadata-file=.*metadata.yaml" "metadata_file is forwarded to pandoc"
  assert_not_contains "$capture" "-V author=" "metadata_file wins over document.* variables"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_ballot_icons_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\n- [ ] unchecked\n- [x] checked\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts include_ballot_icons=true"
  else
    fail "render should accept include_ballot_icons=true ($(tail -2 "$out"))"
  fi
  assert_contains "$capture" "^PANDOC_EMOJI_BALLOT_ICONS=1$" "include_ballot_icons=true enables ballot glyphs"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" false
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts include_ballot_icons=false"
  else
    fail "render should accept include_ballot_icons=false ($(tail -2 "$out"))"
  fi
  assert_contains "$capture" "^PANDOC_EMOJI_BALLOT_ICONS=0$" "include_ballot_icons=false disables ballot glyphs"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
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

run_package_release_artifact_test() {
  local out_dir artifact
  out_dir="$(mktemp -d)"

  if bash "${ROOT_DIR}/scripts/package-release.sh" "$out_dir" >/dev/null 2>&1; then
    pass "package-release builds artifacts"
  else
    fail "package-release should build artifacts"
  fi

  for artifact in pandoc-pdf_darwin_amd64.tar.gz pandoc-pdf_darwin_arm64.tar.gz pandoc-pdf_linux_amd64.tar.gz pandoc-pdf_linux_arm64.tar.gz; do
    if [[ -f "${out_dir}/${artifact}" ]]; then
      pass "package-release emits ${artifact}"
    else
      fail "package-release must emit ${artifact}"
    fi
  done

  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | grep -qE '__pycache__|\.pyc$'; then
    fail "package-release artifact must not ship Python bytecode caches"
  else
    pass "package-release artifact excludes Python bytecode caches"
  fi

  if tar -tzf "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | grep -qxE '\./bin/pandoc-pdf'; then
    pass "package-release artifact contains the CLI entrypoint"
  else
    fail "package-release artifact must contain ./bin/pandoc-pdf"
  fi

  local expected actual
  expected="$(awk '$2=="pandoc-pdf_linux_arm64.tar.gz" {print $1}' "${out_dir}/checksums.txt")"
  if command -v shasum >/dev/null 2>&1; then
    actual="$(shasum -a 256 "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | awk '{print $1}')"
  else
    actual="$(sha256sum "${out_dir}/pandoc-pdf_linux_arm64.tar.gz" | awk '{print $1}')"
  fi
  if [[ -n "$expected" && "$expected" == "$actual" ]]; then
    pass "package-release checksums match the emitted artifacts"
  else
    fail "package-release checksums must match the emitted artifacts"
  fi

  rm -rf "$out_dir"
}

run_emoji_filter_plain_heading_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "⏭  SKIP emoji filter heading check (pandoc not available)"
    return 0
  fi

  local md tex
  md="$(mktemp)"
  tex="$(mktemp)"
  printf '# Plain Heading\n\nText with an emoji \xe2\x9c\x85 and plain words.\n' >"$md"

  if pandoc "$md" -t latex --lua-filter="${ROOT_DIR}/filters/emoji.lua" >"$tex" 2>&1; then
    pass "emoji filter produces latex output"
  else
    fail "emoji filter should produce latex output ($(tail -2 "$tex"))"
  fi

  assert_contains "$tex" '\\section\{Plain Heading\}' "emoji filter keeps a plain heading plain"
  assert_not_contains "$tex" '\\texorpdfstring' "emoji filter does not format plain headings (needs hyperref otherwise)"

  rm -f "$md" "$tex"
}

assert_json_expr() {
  local file="$1"
  local expr="$2"
  local msg="$3"

  if "${REAL_PYTHON3}" - "$file" "$expr" <<'PY' >/dev/null 2>&1
import json
import sys

data = json.load(open(sys.argv[1], encoding="utf-8"))
scope = {"d": data, "any": any, "all": all, "len": len, "str": str, "sorted": sorted, "None": None}
sys.exit(0 if bool(eval(sys.argv[2], {"__builtins__": {}}, scope)) else 1)
PY
  then
    pass "$msg"
  else
    fail "$msg"
  fi
}

run_render_plan_json_test() {
  if [[ -z "${REAL_PYTHON3}" ]]; then
    echo "SKIP render plan json (python3 not available)"
    return 0
  fi

  local sandbox tmpbin capture plan out code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  plan="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter Two\n\ncontent two\n' >"${sandbox}/work/chapters/chapter-2.md"
  printf '# Chapter Ten\n\ncontent ten\n' >"${sandbox}/work/chapters/chapter-10.md"
  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$plan" 2>"$out"
  code=$?
  set -e
  assert_exit_code "0" "$code" "render --dry-run --json exits 0"

  if "${REAL_PYTHON3}" -c "import json,sys; json.load(open(sys.argv[1]))" "$plan" >/dev/null 2>&1; then
    pass "render --dry-run --json emits valid JSON"
  else
    fail "render --dry-run --json must emit valid JSON ($(head -3 "$out"))"
  fi

  assert_json_expr "$plan" 'd["plan_version"] == 1' "plan declares plan_version 1"
  assert_json_expr "$plan" '[p.split("/")[-1] for p in d["chapters"]] == ["chapter-2.md", "chapter-10.md"]' "plan lists chapters in effective order"
  assert_json_expr "$plan" 'd["pandoc"]["argv"][0] == "pandoc"' "plan argv starts with pandoc"
  assert_json_expr "$plan" '"--pdf-engine=lualatex" in d["pandoc"]["argv"]' "plan reflects pdf_engine from config"
  assert_json_expr "$plan" 'd["env"]["PANDOC_EMOJI_BALLOT_ICONS"] == "1"' "plan carries the emoji ballot environment"
  assert_json_expr "$plan" 'd["side_effects"]["keep_merged_markdown"] is True' "plan declares keep_merged_markdown"
  assert_json_expr "$plan" 'd["side_effects"]["emoji"]["dir"].endswith("/work/out/emoji")' "plan resolves the emoji directory"
  assert_json_expr "$plan" 'd["toolkit"]["version"] != ""' "plan reports the toolkit version"

  if [[ -s "$capture" ]]; then
    fail "render --dry-run must not invoke pandoc"
  else
    pass "render --dry-run does not invoke pandoc"
  fi

  if [[ -e "${sandbox}/work/out" ]]; then
    fail "render --dry-run must not create output files or directories"
  else
    pass "render --dry-run has no side effects"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$plan" "$out"
}

run_render_dry_run_human_test() {
  local sandbox tmpbin capture out code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"
  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "render --dry-run exits 0"
  assert_contains "$out" "pandoc " "render --dry-run prints the pandoc invocation"
  assert_not_contains "$out" "Running:" "render --dry-run does not claim pandoc ran"

  if [[ -e "${sandbox}/work/out" ]]; then
    fail "render --dry-run (human) must not create output files"
  else
    pass "render --dry-run (human) has no side effects"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}


run_emoji_filter_contexts_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP emoji filter contexts (pandoc not available)"
    return 0
  fi

  local dir md tex images remaining
  dir="$(mktemp -d)"
  md="$(mktemp)"
  tex="$(mktemp)"

  # A real glyph so the filter substitutes instead of falling back to the character.
  cp "${ROOT_DIR}/filters/emoji/2610.svg" "${dir}/2705.svg"

  cat >"$md" <<'EOF'
# Heading

Paragraph text.

| Col |
|-----|
| cell |

: Caption here

- item
EOF
  # Write the emoji through printf so this test file stays ASCII-clean.
  printf '# Heading \xe2\x9c\x85\n\nParagraph \xe2\x9c\x85 text.\n\n| Col |\n|-----|\n| \xe2\x9c\x85 cell |\n\n: Caption \xe2\x9c\x85 here\n\n- item \xe2\x9c\x85\n' >"$md"

  if PANDOC_EMOJI_DIR="$dir" pandoc "$md" -t latex --lua-filter="${ROOT_DIR}/filters/emoji.lua" >"$tex" 2>&1; then
    pass "emoji filter renders mixed contexts"
  else
    fail "emoji filter should render mixed contexts ($(tail -2 "$tex"))"
  fi

  images="$(grep -c "includesvg\|includegraphics" "$tex" || true)"
  remaining="$(grep -c $'\xe2\x9c\x85' "$tex" || true)"
  assert_exit_code "0" "$remaining" "emoji filter substitutes every emoji context (heading, paragraph, table cell, caption, list)"
  if [[ "${images:-0}" -ge 5 ]]; then
    pass "emoji filter emits an image per substituted emoji"
  else
    fail "emoji filter should emit at least 5 images, got ${images:-0}"
  fi

  rm -rf "$dir"
  rm -f "$md" "$tex"
}

run_render_keep_merged_on_pandoc_failure_test() {
  local sandbox tmpbin capture out merged code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  mkdir -p "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
echo "failing on purpose" >&2
exit 7
EOF
  chmod +x "${tmpbin}/pandoc"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"
  write_contract_config "${sandbox}/pdf.config.yaml" natural false "" true
  merged="${sandbox}/work/out/S1 Document-manual.md"

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1
  code=$?
  set -e

  assert_exit_code "7" "$code" "render propagates pandoc's exit code"
  if [[ -f "$merged" ]]; then
    pass "keep_merged_markdown=false preserves the markdown when pandoc fails"
  else
    fail "keep_merged_markdown=false must keep the markdown when pandoc fails (diagnosis)"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_mermaid_dir_gate_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true false
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts mermaid.enabled=false"
  else
    fail "render should accept mermaid.enabled=false ($(tail -2 "$out"))"
  fi

  if [[ -d "${sandbox}/work/out/mermaid" ]]; then
    fail "render must not create the mermaid directory when the filter is disabled"
  else
    pass "render skips the mermaid directory when the filter is disabled"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts mermaid.enabled=true"
  else
    fail "render should accept mermaid.enabled=true ($(tail -2 "$out"))"
  fi

  if [[ -d "${sandbox}/work/out/mermaid" ]]; then
    pass "render creates the mermaid directory when the filter is enabled"
  else
    fail "render must create the mermaid directory when the filter is enabled"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
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

main() {
  echo "== Running pandoc-pdf tests =="
  run_help_test
  run_help_i18n_notes_test
  run_version_tests
  run_info_tests
  run_i18n_catalog_consistency_test
  run_shared_i18n_runtime_test
  run_unknown_command_test
  run_i18n_default_fallback_english_test
  run_i18n_force_english_unknown_command_test
  run_locale_command_tests
  run_update_check_tests
  run_update_install_tests
  run_update_install_private_api_asset_test
  run_update_dev_command_blocked_test
  run_update_rollback_on_validation_failure_test
  run_install_local_dev_link_test
  run_doctor_success_with_mocked_path
  run_doctor_failure_missing_cmd
  run_doctor_with_config_required_cmd
  run_doctor_rejects_invalid_required_cmd
  run_bootstrap_linux_pkg_manager_detection_tests
  run_validate_config_tests
  run_validate_metadata_file_test
  run_render_legacy_flag_rejected_test
  run_render_no_yaml_parser_hints_i18n_test
  run_render_native_test
  run_render_native_advanced_paths_test
  run_render_missing_explicit_file_test
  run_no_hidden_defaults_test
  run_render_order_semantics_test
  run_render_keep_merged_markdown_test
  run_render_document_vars_test
  run_render_ballot_icons_test
  run_doctor_strict_semantics_test
  run_locale_missing_target_message_test
  run_package_release_artifact_test
  run_emoji_filter_plain_heading_test
  run_emoji_filter_contexts_test
  run_render_keep_merged_on_pandoc_failure_test
  run_render_mermaid_dir_gate_test
  run_render_plan_json_test
  run_render_dry_run_human_test

  echo ""
  echo "Summary: PASS=${PASS} FAIL=${FAIL}"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
