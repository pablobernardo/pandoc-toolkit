#!/usr/bin/env bash
# What an installation carries, in one place.
#
# The packager and the local installer both build a managed tree, and until they
# shared this list the local one shipped `examples/`, `Makefile` and the whole
# `scripts/` directory — including the repository tooling — while dropping
# `LICENSE` and `README.md`. A local install then tested something the release
# does not ship, which is the one thing an installer must never do.
#
# Repository tooling is deliberately absent: `scripts/dev` and
# `scripts/delivery` are unusable from an installation and are not something a
# consumer should read as supported.

# Shipped whole, from the repository root.
PANDOC_PDF_PAYLOAD=(
  "bin"
  "filters"
  "i18n"
  "schemas"
  "templates"
  "VERSION"
  "README.md"
  "LICENSE"
)

# The only directories under `scripts/` an installation runs.
PANDOC_PDF_SCRIPT_DIRS=(
  "runtime"
  "tools"
)

# Fills `target` with the payload taken from `root`.
populate_payload() {
  local target="$1"
  local root="$2"
  local asset dir

  mkdir -p "${target}/scripts"
  for dir in "${PANDOC_PDF_SCRIPT_DIRS[@]}"; do
    if [[ -e "${root}/scripts/${dir}" ]]; then
      cp -R "${root}/scripts/${dir}" "${target}/scripts/${dir}"
    fi
  done
  for asset in "${PANDOC_PDF_PAYLOAD[@]}"; do
    if [[ -e "${root}/${asset}" ]]; then
      cp -R "${root}/${asset}" "${target}/"
    fi
  done

  # Never ship local Python bytecode caches.
  find "${target}" -name '__pycache__' -type d -prune -exec rm -rf {} + 2>/dev/null || true
  find "${target}" -name '*.pyc' -type f -delete 2>/dev/null || true
}
