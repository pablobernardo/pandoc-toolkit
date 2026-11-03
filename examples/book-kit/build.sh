#!/usr/bin/env bash
# Runner for the book-kit example: the adapter itself is the shipped tool at
# scripts/tools/bookkit/build.py. This script only resolves the example's own
# paths and forwards them, so it works from any working directory.
set -euo pipefail

HERE="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

exec python3 "${HERE}/../../scripts/tools/bookkit/build.py" \
  --out "${HERE}/../.output/book-kit" \
  "${HERE}/single" "${HERE}/series" "$@"
