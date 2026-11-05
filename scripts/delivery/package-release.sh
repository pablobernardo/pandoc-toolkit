#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${1:-${ROOT_DIR}/dist}"

mkdir -p "${OUT_DIR}"

STAGING_DIR="$(mktemp -d)"
ARCHIVE_TMP="$(mktemp)"
cleanup() {
  rm -rf "${STAGING_DIR}"
  rm -f "${ARCHIVE_TMP}"
}
trap cleanup EXIT

# One payload, shared with the local installer: what an installation carries is
# decided in `payload.sh`, so the artifact and a local install cannot drift.
# The packager asks for the committed content, so a file nobody versioned cannot
# travel and an uncommitted edit cannot change the hash a release is accepted on.
# shellcheck source=payload.sh
source "${ROOT_DIR}/scripts/delivery/payload.sh"
populate_payload "${STAGING_DIR}" "${ROOT_DIR}" tracked

chmod +x "${STAGING_DIR}/bin/skelepress"

artifacts=(
  "skelepress_darwin_amd64.tar.gz"
  "skelepress_darwin_arm64.tar.gz"
  "skelepress_linux_amd64.tar.gz"
  "skelepress_linux_arm64.tar.gz"
)

# The payload is platform-independent (shell + Python + Lua + assets), so the
# archive is built once and published under every supported platform name.
# A future compiled distribution will build one real binary per platform.
#
# Build the archive deterministically: fixed member order, mtime, owner and
# mode, and a gzip header without a timestamp, so packaging the same tree twice
# yields the same hash and a published checksum can be compared with the
# approved candidate. tar(1) cannot promise that across GNU and BSD
# implementations.
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required to package the release" >&2
  exit 1
fi
python3 - "${STAGING_DIR}" "${ARCHIVE_TMP}" <<'PY'
import gzip
import os
import sys
import tarfile

source, target = sys.argv[1], sys.argv[2]
FIXED_MTIME = 0


def members(root):
    entries = []
    for directory, dirnames, filenames in os.walk(root):
        dirnames.sort()
        filenames.sort()
        for name in dirnames + filenames:
            path = os.path.join(directory, name)
            entries.append((os.path.relpath(path, root), path))
    # Sorting the full relative paths keeps every directory ahead of its
    # children, whichever order os.walk visited them in.
    return sorted(entries)


with open(target, "wb") as raw, gzip.GzipFile(
    filename="", mode="wb", fileobj=raw, mtime=0, compresslevel=9
) as gzipped:
    with tarfile.open(fileobj=gzipped, mode="w", format=tarfile.GNU_FORMAT) as archive:
        for name, path in members(source):
            info = archive.gettarinfo(path, arcname=name)
            info.mtime = FIXED_MTIME
            info.uid = 0
            info.gid = 0
            info.uname = ""
            info.gname = ""
            if info.isdir():
                info.mode = 0o755
                archive.addfile(info)
            elif info.issym():
                info.mode = 0o777
                archive.addfile(info)
            else:
                info.mode = 0o755 if os.access(path, os.X_OK) else 0o644
                with open(path, "rb") as handle:
                    archive.addfile(info, handle)
PY
for artifact in "${artifacts[@]}"; do
  cp "${ARCHIVE_TMP}" "${OUT_DIR}/${artifact}"
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
