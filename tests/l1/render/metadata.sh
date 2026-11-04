#!/bin/bash
# Document variables and metadata precedence in the PDF.
# Sourced by tests/run.sh (not run standalone).

run_render_document_vars_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render succeeds without metadata_file"
  else
    fail "render should succeed without metadata_file ($(tail -2 "$out"))"
  fi

  assert_contains "$capture" "-V title=S1 Document" "document.title is passed as a template variable"
  assert_contains "$capture" "-V subtitle=S1 Subtitle" "document.subtitle is passed as a template variable"
  assert_contains "$capture" "-V publisher=S1 Publisher" "document.publisher is passed as a template variable"
  assert_contains "$capture" "-V author=S1 Author" "document.author is passed as a template variable"
  assert_contains "$capture" "-V date=2026-01-02" "document.date is passed as a template variable"
  assert_contains "$capture" "-V rights=S1 Rights" "document.rights is passed as a template variable"

  printf 'title: Metadata Title\nauthor: Metadata Author\n' >"${sandbox}/work/metadata.yaml"
  write_contract_config "${sandbox}/pdf.config.yaml" natural true "metadata.yaml" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render succeeds with metadata_file"
  else
    fail "render should succeed with metadata_file ($(tail -2 "$out"))"
  fi

  assert_contains "$capture" "--metadata-file=.*metadata.yaml" "metadata_file is forwarded to pandoc"
  assert_not_contains "$capture" "-V author=" "metadata_file wins over document.* variables"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_document_metadata_test() {
  local sandbox tmpbin capture out

  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  cat >"${sandbox}/docmeta.config.yaml" <<'CONFIG'
project:
  name: docmeta
  base_dir: ./work

document:
  title: "Doc Meta"
  language: en
  titlepage: false
  metadata:
    keywords: "compliance, operations"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"

pandoc:
  pdf_engine: xelatex
CONFIG

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/docmeta.config.yaml" "$sandbox" >"$out" 2>&1; then
    pass "renderer accepts document language, titlepage and metadata"
  else
    fail "renderer should accept the new document fields ($(tail -2 "$out"))"
  fi

  assert_contains "$capture" "babel-lang=english" "document.language selects the babel language"
  assert_contains "$capture" "titlepage=false" "document.titlepage reaches the template when disabled"
  assert_contains "$capture" "keywords=compliance, operations" "the free-form metadata map reaches Pandoc"

  cat >"${sandbox}/defaults.config.yaml" <<'CONFIG'
project:
  name: defaults
  base_dir: ./work

document:
  title: "Defaults"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"

pandoc:
  pdf_engine: xelatex
CONFIG

  capture="$(mktemp)"
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/defaults.config.yaml" "$sandbox" >"$out" 2>&1; then
    pass "renderer accepts a config without language or titlepage"
  else
    fail "renderer should fall back when language and titlepage are absent"
  fi
  assert_contains "$capture" "babel-lang=english" "the default babel language is English, not the language of one consumer"
  assert_contains "$capture" "titlepage=true" "the cover is enabled by default"

  # Flipping the default must not break the mapping for other languages.
  sed 's/  title: "Defaults"/  title: "Defaults"\n  language: es/' "${sandbox}/defaults.config.yaml" >"${sandbox}/spanish.config.yaml"
  capture="$(mktemp)"
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/spanish.config.yaml" "$sandbox" >"$out" 2>&1 || true
  assert_contains "$capture" "babel-lang=spanish" "document.language still selects Spanish explicitly"
  # The argv alone cannot prove the switch works: the template has to branch on
  # it. An earlier version emitted an unconditional -V titlepage=true and the
  # flag was silently powerless.
  local template="${ROOT_DIR}/templates/default.tex"
  if grep -q '\\titlepagefalse' "$template" && grep -q '\$if(titlepage)\$' "$template"; then
    pass "the template honours titlepage instead of forcing the cover"
  else
    fail "the template must branch on titlepage and be able to disable the cover"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

# The file name was the document title, spaces and accents included, and
# output.file_prefix was a required field that did nothing. An explicit name now
# wins, the fallback is a slug, and a name can never leave the output directory.
