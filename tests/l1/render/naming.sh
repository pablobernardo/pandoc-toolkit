#!/bin/bash
# How an artifact is named: prefix, suffix, slug and accents.
# Sourced by tests/run.sh (not run standalone).

run_render_output_file_name_test() {
  local sandbox tmpbin capture out

  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  build_config() {
    local prefix_line="$1"
    cat >"${sandbox}/naming.config.yaml" <<CONFIG
project:
  name: naming
  base_dir: ./work

document:
  title: "Project Technical Documentation"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"
${prefix_line}

pandoc:
  pdf_engine: xelatex
CONFIG
  }

  # 1) An explicit name is honoured, not overridden by the title.
  build_config '  file_prefix: "report"'
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/naming.config.yaml" "$sandbox" >"$out" 2>&1 || true
  assert_contains "$capture" "report-manual.pdf" "output.file_prefix names the file"

  # 2) Without a name, the title becomes a slug instead of a raw file name.
  build_config ''
  capture="$(mktemp)"
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/naming.config.yaml" "$sandbox" >"$out" 2>&1 || true
  assert_contains "$capture" "project-technical-documentation-manual.pdf" "the title falls back to a slug"
  assert_not_contains "$capture" "Project Technical Documentation-manual.pdf" "the raw title is never a file name"

  # 3) A name cannot escape the output directory.
  build_config '  file_prefix: "../../etc/passwd"'
  capture="$(mktemp)"
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/naming.config.yaml" "$sandbox" >"$out" 2>&1 || true
  # The slug keeps only [a-z0-9-], so a declared "../.." cannot survive as a path.
  assert_contains "$capture" "out/etc-passwd-manual.pdf" "a declared name cannot traverse out of the output directory"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

# Accents and punctuation must not survive into a file name.

run_render_slug_accents_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  printf '# Uno\n\ncontenido\n' >"${sandbox}/work/chapters/01-one.md"

  cat >"${sandbox}/slug.config.yaml" <<'CONFIG'
project:
  name: slug
  base_dir: ./work

document:
  title: "Informe Ñandú y Açúcar — 2026"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"

pandoc:
  pdf_engine: xelatex
CONFIG

  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/slug.config.yaml" "$sandbox" >"$out" 2>&1 || true
  assert_contains "$capture" "informe-nandu-y-acucar-2026-manual.pdf" "accents and dashes become an ascii slug"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

# Structural guard; real PDF layout is checked separately with the TeX toolchain.
