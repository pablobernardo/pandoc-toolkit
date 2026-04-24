#!/usr/bin/env bash
set -euo pipefail

OWNER="${PANDOC_PDF_RELEASE_OWNER:-pablobernardo}"
REPO="${PANDOC_PDF_RELEASE_REPO:-pandoc-toolkit}"
API_BASE="${PANDOC_PDF_RELEASE_API_BASE:-https://api.github.com/repos/${OWNER}/${REPO}/releases}"

INSTALL_BIN_DIR="${PANDOC_PDF_INSTALL_DIR:-${HOME}/.local/bin}"
MANAGED_HOME="${PANDOC_PDF_INSTALL_HOME:-${HOME}/.local/share/pandoc-pdf}"
TOKEN="${PANDOC_PDF_UPDATE_TOKEN:-${GH_TOKEN:-}}"

if ! command -v curl >/dev/null 2>&1; then
  echo "❌ install requires curl" >&2
  exit 1
fi

os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m | tr '[:upper:]' '[:lower:]')"
case "$os" in
  darwin) os="darwin" ;;
  linux) os="linux" ;;
  *) echo "❌ unsupported OS: ${os}" >&2; exit 1 ;;
esac
case "$arch" in
  x86_64|amd64) arch="amd64" ;;
  arm64|aarch64) arch="arm64" ;;
  *) echo "❌ unsupported architecture: ${arch}" >&2; exit 1 ;;
esac

artifact="pandoc-pdf_${os}_${arch}.tar.gz"

curl_json() {
  local url="$1"
  if [[ -n "$TOKEN" ]]; then
    curl -fsSL -H "Authorization: Bearer ${TOKEN}" "$url"
  else
    curl -fsSL "$url"
  fi
}

download_to() {
  local url="$1"
  local out="$2"
  if [[ -n "$TOKEN" ]]; then
    curl -fsSL -H "Authorization: Bearer ${TOKEN}" "$url" -o "$out"
  else
    curl -fsSL "$url" -o "$out"
  fi
}

release_json="$(curl_json "${API_BASE}/latest")"
tag="$(python3 - <<'PY' "$release_json"
import json, sys
data=json.loads(sys.argv[1])
print(data.get("tag_name", ""))
PY
)"
if [[ -z "$tag" ]]; then
  echo "❌ latest release payload has no tag_name" >&2
  exit 1
fi

artifact_url="$(python3 - <<'PY' "$release_json" "$artifact"
import json, sys
data=json.loads(sys.argv[1])
name=sys.argv[2]
for a in data.get("assets", []):
    if a.get("name") == name:
        print(a.get("browser_download_url", ""))
        break
PY
)"

checksums_url="$(python3 - <<'PY' "$release_json"
import json, sys
data=json.loads(sys.argv[1])
for a in data.get("assets", []):
    if a.get("name") == "checksums.txt":
        print(a.get("browser_download_url", ""))
        break
PY
)"

if [[ -z "$artifact_url" || -z "$checksums_url" ]]; then
  echo "❌ release assets missing (${artifact} or checksums.txt)" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT
artifact_path="${tmpdir}/${artifact}"
checksums_path="${tmpdir}/checksums.txt"
extract_dir="${tmpdir}/extract"
mkdir -p "$extract_dir"

download_to "$artifact_url" "$artifact_path"
download_to "$checksums_url" "$checksums_path"

expected="$(awk -v n="$artifact" '$2==n {print $1; exit}' "$checksums_path")"
if [[ -z "$expected" ]]; then
  echo "❌ checksums.txt does not include ${artifact}" >&2
  exit 1
fi

if command -v shasum >/dev/null 2>&1; then
  actual="$(shasum -a 256 "$artifact_path" | awk '{print $1}')"
else
  actual="$(sha256sum "$artifact_path" | awk '{print $1}')"
fi

if [[ "$expected" != "$actual" ]]; then
  echo "❌ checksum mismatch for ${artifact}" >&2
  exit 1
fi

tar -xzf "$artifact_path" -C "$extract_dir"
if [[ ! -x "${extract_dir}/bin/pandoc-pdf" ]]; then
  echo "❌ extracted artifact does not contain bin/pandoc-pdf" >&2
  exit 1
fi

mkdir -p "${MANAGED_HOME}/versions" "${INSTALL_BIN_DIR}"
version_dir="${MANAGED_HOME}/versions/${tag}"
current_link="${MANAGED_HOME}/current"
rm -rf "$version_dir"
mkdir -p "$version_dir"
cp -R "${extract_dir}/." "$version_dir/"
ln -sfn "$version_dir" "$current_link"
ln -sfn "${current_link}/bin/pandoc-pdf" "${INSTALL_BIN_DIR}/pandoc-pdf"

echo "✅ Installed pandoc-pdf ${tag}"
echo "   Binary: ${INSTALL_BIN_DIR}/pandoc-pdf"
echo "   Managed root: ${MANAGED_HOME}"
