#!/usr/bin/env bash
set -euo pipefail

path_dirname() {
  local p="$1"
  if [[ "$p" == */* ]]; then
    printf '%s\n' "${p%/*}"
  else
    printf '.\n'
  fi
}

SCRIPT_DIR="$(cd -- "$(path_dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
CLI_PATH="${ROOT_DIR}/bin/pandoc-pdf"
LOCAL_BIN_DIR="${HOME}/.local/bin"
LINK_PATH="${LOCAL_BIN_DIR}/pandoc-pdf"

DRY_RUN=false
NO_INSTALL=false
SKIP_LINK=false
ASSUME_YES=false

MERMAID_CLI_VERSION="${MERMAID_CLI_VERSION:-10.9.1}"
PYYAML_VERSION="${PYYAML_VERSION:-6.0.2}"

I18N_HELPER="${ROOT_DIR}/scripts/i18n.sh"
if [[ ! -f "$I18N_HELPER" ]]; then
  echo "❌ bootstrap: cannot find ${I18N_HELPER}; the installation looks incomplete" >&2
  exit 1
fi

I18N_ROOT="$ROOT_DIR"
# shellcheck source=../scripts/i18n.sh
source "$I18N_HELPER"

LANG_CODE="$(resolve_lang)"
i18n_load_catalog "$LANG_CODE"

usage() {
  cat <<EOF
$(t "bootstrap.title" "Installation bootstrap — Pandoc PDF Toolkit")

$(t "bootstrap.usage" "Usage:")
  scripts/bootstrap.sh [--dry-run] [--no-install] [--skip-link] [--yes] [--ci]

$(t "bootstrap.options" "Options:")
  --dry-run    $(t "bootstrap.opt.dryrun" "Show commands without executing")
  --no-install $(t "bootstrap.opt.noinstall" "Do not install dependencies (verify only)")
  --skip-link  $(t "bootstrap.opt.skiplink" "Do not create symlink in ~/.local/bin/pandoc-pdf")
  --yes        $(t "bootstrap.opt.yes" "Non-interactive mode (auto-accept installation)")
  --ci         $(t "bootstrap.opt.ci" "CI alias: equivalent to --yes --skip-link")
EOF
}

log() {
  printf '👉 %s\n' "$*"
}

run_cmd() {
  local cmd="$1"
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '[dry-run] %s\n' "${cmd}"
    return 0
  fi
  /bin/bash -lc "${cmd}"
}

confirm_install() {
  if [[ "${ASSUME_YES}" == "true" ]]; then
    log "$(t "bootstrap.non_interactive" "Non-interactive mode enabled (--yes): continuing without prompt")"
    return 0
  fi

  printf '⚠️  %s ' "$(t "bootstrap.confirm" "System installations will be executed. Continue? [y/N]")"
  local answer=""
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      echo "❌ $(t "bootstrap.cancelled" "Installation cancelled by user")"
      return 1
      ;;
  esac
}

has_cmd() {
  command -v "$1" >/dev/null 2>&1
}

has_python_yaml() {
  python3 - <<'PY' >/dev/null 2>&1
import yaml  # noqa: F401
PY
}

has_ruby_yaml() {
  ruby -e 'require "yaml"' >/dev/null 2>&1
}

ensure_yaml_parser() {
  if has_python_yaml || has_ruby_yaml; then
    return 0
  fi

  if ! has_cmd python3; then
    echo "❌ $(t "bootstrap.error.no_python" "Cannot install YAML parser: python3 is not available")"
    return 1
  fi

  log "$(t "bootstrap.install.pyyaml" "Installing PyYAML for python3") (${PYYAML_VERSION})"
  run_cmd "python3 -m pip install --user pyyaml==${PYYAML_VERSION}"

  if has_python_yaml || has_ruby_yaml; then
    return 0
  fi

  echo "❌ $(t "bootstrap.error.yaml_parser" "Could not enable a YAML parser (PyYAML or Ruby YAML)")"
  return 1
}

install_macos() {
  if ! has_cmd brew; then
    echo "❌ $(t "bootstrap.error.no_brew" "Homebrew is not installed. Install it from https://brew.sh")"
    return 1
  fi

  local missing=()
  has_cmd pandoc || missing+=(pandoc)
  has_cmd python3 || missing+=(python)
  has_cmd curl || missing+=(curl)
  has_cmd node || missing+=(node)
  has_cmd npm || missing+=(node)

  if [[ ${#missing[@]} -gt 0 ]]; then
    log "$(t "bootstrap.install.homebrew_deps" "Installing Homebrew dependencies"): ${missing[*]}"
    run_cmd "brew install ${missing[*]}"
  fi

  if ! has_cmd mmdc; then
    log "$(t "bootstrap.install.mermaid" "Installing Mermaid CLI") (${MERMAID_CLI_VERSION})"
    run_cmd "npm install -g @mermaid-js/mermaid-cli@${MERMAID_CLI_VERSION}"
  fi

  if ! has_cmd xelatex && ! has_cmd lualatex && ! has_cmd pdflatex; then
    log "$(t "bootstrap.install.basictex" "No TeX engine detected. Installing BasicTeX (may take a while).")"
    run_cmd "brew install --cask basictex"
  fi
}

install_linux() {
  local pkg_manager=""
  for mgr in apt-get dnf yum pacman zypper apk; do
    if has_cmd "${mgr}"; then
      pkg_manager="${mgr}"
      break
    fi
  done

  if [[ -z "${pkg_manager}" ]]; then
    echo "❌ $(t "bootstrap.error.no_pkg_manager" "No supported package manager detected (apt-get, dnf, yum, pacman, zypper, apk).")"
    echo "   $(t "bootstrap.error.manual_install" "Install dependencies manually as documented in docs/install.md")"
    return 1
  fi

  log "$(t "bootstrap.detected_pkg_manager" "Detected package manager"): ${pkg_manager}"
  case "${pkg_manager}" in
    apt-get)
      run_cmd "sudo apt-get update"
      run_cmd "sudo apt-get install -y pandoc python3 curl texlive-xetex nodejs npm"
      ;;
    dnf)
      run_cmd "sudo dnf install -y pandoc python3 curl texlive-xetex nodejs npm"
      ;;
    yum)
      run_cmd "sudo yum install -y pandoc python3 curl texlive-xetex nodejs npm"
      ;;
    pacman)
      run_cmd "sudo pacman -Sy --noconfirm pandoc python curl texlive-xetex nodejs npm"
      ;;
    zypper)
      run_cmd "sudo zypper --non-interactive refresh"
      run_cmd "sudo zypper --non-interactive install pandoc python3 curl texlive-xetex nodejs npm"
      ;;
    apk)
      run_cmd "sudo apk add pandoc python3 py3-pip curl texlive-full nodejs npm"
      ;;
  esac

  if ! has_cmd mmdc; then
    log "$(t "bootstrap.install.mermaid" "Installing Mermaid CLI") (${MERMAID_CLI_VERSION})"
    run_cmd "sudo npm install -g @mermaid-js/mermaid-cli@${MERMAID_CLI_VERSION}"
  fi
}

verify_dependencies() {
  local required=(pandoc python3 curl mmdc)
  local missing=()

  for cmd in "${required[@]}"; do
    has_cmd "${cmd}" || missing+=("${cmd}")
  done

  if ! has_cmd xelatex && ! has_cmd lualatex && ! has_cmd pdflatex; then
    missing+=("xelatex|lualatex|pdflatex")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "❌ $(t "bootstrap.error.missing_deps" "Missing dependencies"): ${missing[*]}"
    return 1
  fi

  if ! has_python_yaml && ! has_ruby_yaml; then
    echo "❌ $(t "bootstrap.error.missing_yaml" "Missing YAML parser: install PyYAML or Ruby with YAML")"
    return 1
  fi

  echo "✅ $(t "bootstrap.deps_detected" "Dependencies detected")"
}

create_symlink() {
  if [[ "${SKIP_LINK}" == "true" ]]; then
    log "$(t "bootstrap.skip_link" "Skipping symlink creation due to --skip-link")"
    return 0
  fi

  run_cmd "mkdir -p \"${LOCAL_BIN_DIR}\""
  run_cmd "ln -sf \"${CLI_PATH}\" \"${LINK_PATH}\""
  echo "✅ $(t "bootstrap.symlink_created" "Symlink created"): ${LINK_PATH}"
  local path_msg
  path_msg="$(t "bootstrap.path_hint" "Ensure {path} is in PATH")"
  echo "ℹ️  $(interp "$path_msg" "path" "${LOCAL_BIN_DIR}")"
}

run_doctor() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '[dry-run] %s\n' "${CLI_PATH} doctor"
    return 0
  fi

  if [[ -x "${CLI_PATH}" ]]; then
    log "$(t "bootstrap.run_doctor" "Running doctor")"
    "${CLI_PATH}" doctor
  fi
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run)
        DRY_RUN=true
        shift
        ;;
      --no-install)
        NO_INSTALL=true
        shift
        ;;
      --skip-link)
        SKIP_LINK=true
        shift
        ;;
      --yes)
        ASSUME_YES=true
        shift
        ;;
      --ci)
        ASSUME_YES=true
        SKIP_LINK=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        local msg
        msg="$(t "bootstrap.error.unknown_arg" "Unknown argument: {arg}")"
        echo "❌ $(interp "$msg" "arg" "$1")"
        usage
        exit 1
        ;;
    esac
  done

  local os
  os="$(uname -s)"
  log "$(t "bootstrap.detected_os" "Detected system"): ${os}"

  if [[ "${NO_INSTALL}" != "true" ]]; then
    confirm_install
    case "${os}" in
      Darwin)
        install_macos
        ;;
      Linux)
        install_linux
        ;;
      *)
        local msg
        msg="$(t "bootstrap.error.unsupported_os" "System not supported by automatic bootstrap: {os}")"
        echo "❌ $(interp "$msg" "os" "${os}")"
        echo "   $(t "bootstrap.error.manual_install" "Install dependencies manually as documented in docs/install.md")"
        ;;
    esac

    ensure_yaml_parser
  else
    log "$(t "bootstrap.skip_install" "Skipping installation due to --no-install")"
  fi

  verify_dependencies
  create_symlink
  run_doctor
}

main "$@"
