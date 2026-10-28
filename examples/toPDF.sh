#!/usr/bin/env bash
set -euo pipefail

# Render both examples from wherever this script is invoked.
cd "$(dirname "$0")"

PANDOC_PDF_BIN="${PANDOC_PDF_BIN:-../bin/pandoc-pdf}"

if [[ ! -x "$PANDOC_PDF_BIN" ]]; then
  echo "❌ pandoc-pdf not executable at ${PANDOC_PDF_BIN}" >&2
  exit 1
fi

"$PANDOC_PDF_BIN" render -c ohmyfake/pdf.config.yaml
"$PANDOC_PDF_BIN" render -c test/pdf.config.yaml
"$PANDOC_PDF_BIN" render -c manual/pdf.config.yaml
"$PANDOC_PDF_BIN" render -c documentation/pdf.config.yaml
