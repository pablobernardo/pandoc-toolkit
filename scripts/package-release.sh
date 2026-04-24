#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-${ROOT_DIR}/dist}"

mkdir -p "${OUT_DIR}"

STAGING_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "${STAGING_DIR}"
}
trap cleanup EXIT

# Toolkit runtime layout required by bin/pandoc-pdf
cp -R "${ROOT_DIR}/bin" "${STAGING_DIR}/bin"
cp -R "${ROOT_DIR}/scripts" "${STAGING_DIR}/scripts"
cp -R "${ROOT_DIR}/schemas" "${STAGING_DIR}/schemas"
cp -R "${ROOT_DIR}/templates" "${STAGING_DIR}/templates"
cp -R "${ROOT_DIR}/defaults" "${STAGING_DIR}/defaults"
cp -R "${ROOT_DIR}/filters" "${STAGING_DIR}/filters"
cp -R "${ROOT_DIR}/i18n" "${STAGING_DIR}/i18n"
cp "${ROOT_DIR}/VERSION" "${STAGING_DIR}/VERSION"
cp "${ROOT_DIR}/README.md" "${STAGING_DIR}/README.md"
cp "${ROOT_DIR}/LICENSE" "${STAGING_DIR}/LICENSE"

chmod +x "${STAGING_DIR}/bin/pandoc-pdf"

artifacts=(
  "pandoc-pdf_darwin_amd64.tar.gz"
  "pandoc-pdf_darwin_arm64.tar.gz"
  "pandoc-pdf_linux_amd64.tar.gz"
  "pandoc-pdf_linux_arm64.tar.gz"
)

for artifact in "${artifacts[@]}"; do
  tar -czf "${OUT_DIR}/${artifact}" -C "${STAGING_DIR}" .
done

checksums_file="${OUT_DIR}/checksums.txt"
rm -f "${checksums_file}"
for artifact in "${artifacts[@]}"; do
  if command -v shasum >/dev/null 2>&1; then
    checksum="$(shasum -a 256 "${OUT_DIR}/${artifact}" | awk '{print $1}')"
  else
    checksum="$(sha256sum "${OUT_DIR}/${artifact}" | awk '{print $1}')"
  fi
  printf '%s  %s\n' "${checksum}" "${artifact}" >> "${checksums_file}"
done

echo "Release artifacts generated in ${OUT_DIR}" 
