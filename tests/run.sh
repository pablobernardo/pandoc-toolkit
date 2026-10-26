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

# Shared assertions plus one file per area; this file only orchestrates.
source "${ROOT_DIR}/tests/lib.sh"
# shellcheck disable=SC1090,SC1091  # area paths are resolved at runtime
for area in "${ROOT_DIR}"/tests/l1/*.sh; do
  [[ -e "$area" ]] || continue
  source "$area"
done

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

run_schema_keyword_support_test() {
  if [[ -z "${REAL_PYTHON3}" ]]; then
    echo "SKIP schema keyword support (python3 not available)"
    return 0
  fi

  local out
  out="$(mktemp)"
  if "${REAL_PYTHON3}" - "${ROOT_DIR}/schemas/pdf-config.schema.json" >"$out" 2>&1 <<'PY'
import json
import sys

# Keywords validate-config.py actually implements, plus pure annotations.
SUPPORTED = {
    "type", "properties", "required", "additionalProperties",
    "items", "minItems", "minLength", "minimum", "enum",
}
ANNOTATIONS = {"$schema", "$id", "title", "description", "default", "examples"}

schema = json.load(open(sys.argv[1], encoding="utf-8"))
used = set()


def walk(node):
    if isinstance(node, dict):
        for key, value in node.items():
            if key == "properties":
                for subschema in value.values():
                    walk(subschema)
                continue
            used.add(key)
            walk(value)
    elif isinstance(node, list):
        for item in node:
            walk(item)


walk(schema)
unknown = sorted(used - SUPPORTED - ANNOTATIONS)
if unknown:
    print("unsupported JSON-Schema keywords: " + ", ".join(unknown))
    raise SystemExit(1)
PY
  then
    pass "the schema only uses keywords the validator implements"
  else
    fail "the schema uses keywords validate-config.py ignores: $(cat "$out")"
  fi
  rm -f "$out"
}

run_validate_order_enum_test() {
  local out code
  out="$(mktemp)"

  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-order-value.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "validate-config rejects an input.order outside the enum"
  assert_contains "$out" "input.order" "the enum error names the field"
  assert_contains "$out" "alphabetical" "the enum error lists the allowed values"

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
  run_schema_keyword_support_test
  run_validate_order_enum_test
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
