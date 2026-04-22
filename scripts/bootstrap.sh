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

usage() {
  cat <<'EOF'
Bootstrap de instalación — Pandoc PDF Toolkit

Uso:
  scripts/bootstrap.sh [--dry-run] [--no-install] [--skip-link] [--yes] [--ci]

Opciones:
  --dry-run    Muestra comandos sin ejecutarlos
  --no-install No intenta instalar dependencias (solo verifica)
  --skip-link  No crea symlink en ~/.local/bin/pandoc-pdf
  --yes        Modo no interactivo (acepta instalación automáticamente)
  --ci         Alias para CI: equivalente a --yes --skip-link
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
    log "Modo no interactivo activo (--yes): se continúa sin confirmación"
    return 0
  fi

  printf '⚠️  Se van a ejecutar instalaciones del sistema. ¿Continuar? [y/N] '
  local answer=""
  read -r answer
  case "${answer}" in
    y|Y|yes|YES)
      return 0
      ;;
    *)
      echo "❌ Instalación cancelada por el usuario"
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
    echo "❌ No se puede instalar parser YAML: python3 no está disponible"
    return 1
  fi

  log "Instalando PyYAML para python3 (${PYYAML_VERSION})"
  run_cmd "python3 -m pip install --user pyyaml==${PYYAML_VERSION}"

  if has_python_yaml || has_ruby_yaml; then
    return 0
  fi

  echo "❌ No se ha podido habilitar un parser YAML (PyYAML o Ruby YAML)"
  return 1
}

install_macos() {
  if ! has_cmd brew; then
    echo "❌ Homebrew no está instalado. Instálalo desde https://brew.sh"
    return 1
  fi

  local missing=()
  has_cmd pandoc || missing+=(pandoc)
  has_cmd python3 || missing+=(python)
  has_cmd curl || missing+=(curl)
  has_cmd node || missing+=(node)
  has_cmd npm || missing+=(node)

  if [[ ${#missing[@]} -gt 0 ]]; then
    log "Instalando dependencias Homebrew: ${missing[*]}"
    run_cmd "brew install ${missing[*]}"
  fi

  if ! has_cmd mmdc; then
    log "Instalando Mermaid CLI (${MERMAID_CLI_VERSION})"
    run_cmd "npm install -g @mermaid-js/mermaid-cli@${MERMAID_CLI_VERSION}"
  fi

  if ! has_cmd xelatex && ! has_cmd lualatex && ! has_cmd pdflatex; then
    log "No se ha detectado motor TeX. Instalando BasicTeX (puede tardar)."
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
    echo "❌ No se ha detectado un gestor de paquetes soportado (apt-get, dnf, yum, pacman, zypper, apk)."
    echo "   Instala dependencias manualmente según docs/install.md"
    return 1
  fi

  log "Gestor de paquetes detectado: ${pkg_manager}"
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
    log "Instalando Mermaid CLI (${MERMAID_CLI_VERSION})"
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
    echo "❌ Dependencias faltantes: ${missing[*]}"
    return 1
  fi

  if ! has_python_yaml && ! has_ruby_yaml; then
    echo "❌ Falta parser YAML: instalá PyYAML o Ruby con YAML"
    return 1
  fi

  echo "✅ Dependencias detectadas"
}

create_symlink() {
  if [[ "${SKIP_LINK}" == "true" ]]; then
    log "Se omite creación de symlink por --skip-link"
    return 0
  fi

  run_cmd "mkdir -p \"${LOCAL_BIN_DIR}\""
  run_cmd "ln -sf \"${CLI_PATH}\" \"${LINK_PATH}\""
  echo "✅ Symlink creado: ${LINK_PATH}"
  echo "ℹ️  Asegúrate de tener ${LOCAL_BIN_DIR} en PATH"
}

run_doctor() {
  if [[ "${DRY_RUN}" == "true" ]]; then
    printf '[dry-run] %s\n' "${CLI_PATH} doctor"
    return 0
  fi

  if [[ -x "${CLI_PATH}" ]]; then
    log "Ejecutando doctor"
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
        echo "❌ Argumento no reconocido: $1"
        usage
        exit 1
        ;;
    esac
  done

  local os
  os="$(uname -s)"
  log "Sistema detectado: ${os}"

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
        echo "❌ Sistema no soportado por bootstrap automático: ${os}"
        echo "   Revisa la instalación manual en docs/install.md"
        ;;
    esac

    ensure_yaml_parser
  else
    log "Se omite instalación por --no-install"
  fi

  verify_dependencies
  create_symlink
  run_doctor
}

main "$@"
