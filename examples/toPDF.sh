#!/usr/bin/env bash
set -euo pipefail

# Render every example from wherever this script is invoked.
cd "$(dirname "$0")"

PANDOC_PDF_BIN="${PANDOC_PDF_BIN:-../bin/pandoc-pdf}"
# FORMATS narrows what every example renders, for an environment that carries one
# toolchain and not the other: the EPUB acceptance job has no LaTeX. It derives a
# temporary configuration from the example's own one, in the same directory so
# every relative path keeps resolving, and deletes it on exit: same contract, no
# second configuration to drift from. Unset, each example renders what it declares.
FORMATS="${FORMATS:-}"

if [[ ! -x "$PANDOC_PDF_BIN" ]]; then
  echo "❌ pandoc-pdf not executable at ${PANDOC_PDF_BIN}" >&2
  exit 1
fi

derived_configs=()
cleanup() {
  if (( ${#derived_configs[@]} > 0 )); then
    rm -f "${derived_configs[@]}"
  fi
}
trap cleanup EXIT

render_example() {
  local config="$1"
  if [[ -z "$FORMATS" ]]; then
    "$PANDOC_PDF_BIN" render -c "$config"
    return
  fi

  local derived
  derived="$(dirname "$config")/.formats-override.config.yaml"
  sed -E "s/^([[:space:]]*formats:)[[:space:]]*\[[^]]*\]/\1 [${FORMATS}]/" "$config" >"$derived"
  # A configuration whose formats are not an inline list is not something this
  # runner can narrow safely, so say so instead of rendering the wrong thing.
  if ! grep -qE "^[[:space:]]*formats: \[${FORMATS}\]" "$derived"; then
    echo "❌ FORMATS=${FORMATS}: could not narrow the formats of ${config}" >&2
    exit 1
  fi
  derived_configs+=("$derived")
  "$PANDOC_PDF_BIN" render -c "$derived"
}

render_example ohmyfake/pdf.config.yaml
render_example no-titlepage/pdf.config.yaml
render_example manual/pdf.config.yaml
render_example documentation/pdf.config.yaml

# The book volumes are declared as manifests, and bookkit generates PDF-only
# configurations for them, so a request that leaves pdf out has nothing to render
# here. Skipping it is what keeps the EPUB acceptance job free of LaTeX.
if [[ -z "$FORMATS" || "$FORMATS" == *pdf* ]]; then
  # The book example declares manifests instead of a configuration, so it goes
  # through the subcommand that turns them into one config per volume and renders
  # each: same runner, same CLI, one shape fewer.
  "$PANDOC_PDF_BIN" book --out .output/book-kit book-kit/single book-kit/series
else
  echo "→ book-kit skipped: its volumes generate PDF-only configurations"
fi
