#!/usr/bin/env bash
set -euo pipefail

MANAGED_HOME="${PANDOC_PDF_INSTALL_HOME:-${HOME}/.local/share/pandoc-pdf}"
INSTALL_BIN_DIR="${PANDOC_PDF_INSTALL_DIR:-${HOME}/.local/bin}"
REPO_ROOT="${PANDOC_PDF_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
VERSION_FILE="${REPO_ROOT}/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ${VERSION_FILE} not found — not a valid toolkit repo" >&2
  exit 1
fi

if [[ ! -x "${REPO_ROOT}/bin/pandoc-pdf" ]]; then
  echo "❌ ${REPO_ROOT}/bin/pandoc-pdf not found or not executable" >&2
  exit 1
fi

tag="$(cat "$VERSION_FILE")"
if [[ -z "$tag" ]]; then
  echo "❌ VERSION file is empty" >&2
  exit 1
fi

# Files/dirs to include in the managed installation
ASSETS=(
  "bin"
  "filters"
  "templates"
  "schemas"
  "i18n"
  "scripts"
  "examples"
  "Makefile"
  "VERSION"
)

mkdir -p "${MANAGED_HOME}/versions" "${INSTALL_BIN_DIR}"
version_dir="${MANAGED_HOME}/versions/${tag}"
current_link="${MANAGED_HOME}/current"

rm -rf "$version_dir"
mkdir -p "$version_dir"

for asset in "${ASSETS[@]}"; do
  if [[ -e "${REPO_ROOT}/${asset}" ]]; then
    cp -R "${REPO_ROOT}/${asset}" "$version_dir/"
  fi
done

ln -sfn "$version_dir" "$current_link"
ln -sfn "${current_link}/bin/pandoc-pdf" "${INSTALL_BIN_DIR}/pandoc-pdf"

echo "✅ Installed pandoc-pdf ${tag} from local repo"
echo "   Binary: ${INSTALL_BIN_DIR}/pandoc-pdf"
echo "   Managed root: ${MANAGED_HOME}"
echo "   Version dir: ${version_dir}"

if [[ "${1:-}" == "dev" ]]; then
  dev_link="${INSTALL_BIN_DIR}/pandoc-pdf-dev"
  ln -sfn "${REPO_ROOT}/bin/pandoc-pdf" "$dev_link"
  echo "   Dev link: ${dev_link} -> ${REPO_ROOT}/bin/pandoc-pdf"
fi
