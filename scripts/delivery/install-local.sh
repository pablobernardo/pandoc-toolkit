#!/usr/bin/env bash
set -euo pipefail

MANAGED_HOME="${PANDOC_PDF_INSTALL_HOME:-${HOME}/.local/share/pandoc-pdf}"
INSTALL_BIN_DIR="${PANDOC_PDF_INSTALL_DIR:-${HOME}/.local/bin}"
REPO_ROOT="${PANDOC_PDF_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
VERSION_FILE="${REPO_ROOT}/VERSION"

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "❌ ${VERSION_FILE} not found — not a valid toolkit repo" >&2
  exit 1
fi

if [[ ! -x "${REPO_ROOT}/bin/pandoc-pdf" ]]; then
  echo "❌ ${REPO_ROOT}/bin/pandoc-pdf not found or not executable" >&2
  exit 1
fi

version="$(cat "$VERSION_FILE")"
if [[ -z "$version" ]]; then
  echo "❌ VERSION file is empty" >&2
  exit 1
fi

# The payload is the released one, from the same list the packager uses, so a
# local install exercises what an installation actually receives.
# shellcheck source=payload.sh
source "${REPO_ROOT}/scripts/delivery/payload.sh"

# A managed version directory is named after the release tag, which carries the
# `v` the network installer uses. A development build gets its own directory so
# it can never overwrite the stable installation of the same version.
mode="${1:-release}"
if [[ "$mode" == "dev" ]]; then
  version_dir="${MANAGED_HOME}/versions/v${version}-dev"
else
  version_dir="${MANAGED_HOME}/versions/v${version}"
fi
current_link="${MANAGED_HOME}/current"

mkdir -p "${MANAGED_HOME}/versions" "${INSTALL_BIN_DIR}"
rm -rf "$version_dir"
mkdir -p "$version_dir"
populate_payload "$version_dir" "$REPO_ROOT"

if [[ "$mode" == "dev" ]]; then
  # A development install must not displace the stable one: `current` and
  # `pandoc-pdf` keep pointing wherever they pointed, and the development
  # entrypoint is its own name.
  dev_link="${INSTALL_BIN_DIR}/pandoc-pdf-dev"
  ln -sfn "${REPO_ROOT}/bin/pandoc-pdf" "$dev_link"
  echo "✅ Installed pandoc-pdf ${version} (development) from local repo"
  echo "   Dev link: ${dev_link} -> ${REPO_ROOT}/bin/pandoc-pdf"
else
  ln -sfn "$version_dir" "$current_link"
  ln -sfn "${current_link}/bin/pandoc-pdf" "${INSTALL_BIN_DIR}/pandoc-pdf"
  echo "✅ Installed pandoc-pdf ${version} from local repo"
  echo "   Binary: ${INSTALL_BIN_DIR}/pandoc-pdf"
fi

echo "   Managed root: ${MANAGED_HOME}"
echo "   Version dir: ${version_dir}"
