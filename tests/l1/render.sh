#!/bin/bash
# render area tests. Sourced by tests/run.sh (not run standalone).

run_render_legacy_flag_rejected_test() {
  local out
  out="$(mktemp)"
  set +e
  "$CLI" render --legacy -c "${FIXTURES_DIR}/render.config.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "render rejects --legacy flag"
  assert_contains "$out" "Unknown argument" "render reports invalid legacy flag"
  rm -f "$out"
}

run_render_no_yaml_parser_hints_i18n_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates" "${sandbox}/i18n/locales"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${ROOT_DIR}/i18n/locales/es.json" "${sandbox}/i18n/locales/es.json"
  cp "${ROOT_DIR}/i18n/locales/en.json" "${sandbox}/i18n/locales/en.json"
  cp "${FIXTURES_DIR}/render.config.yaml" "${sandbox}/render.config.yaml"

  cat >"${sandbox}/chapters/title-a.md" <<'EOF'
# Title A
EOF

  cat >"${sandbox}/chapters/title-b.md" <<'EOF'
# Title B
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/metadata.yaml" <<'EOF'
title: Render Test
EOF

  local tmpbin
  tmpbin="$(mktemp -d)"

  # Simula "python3 sin PyYAML": la sonda de detección (`python3 -` con un solo
  # argumento) falla, validate-config se salta (no es lo que mide este test) y el
  # volcado del catálogo (`python3 - <locale.json>`) usa el intérprete real, para
  # que los mensajes salgan traducidos desde el catálogo de verdad.
  cat >"${tmpbin}/python3" <<EOF
#!/bin/bash
set -euo pipefail
if [[ "\${1:-}" == *"validate-config.py" ]]; then
  exit 0
fi
if [[ "\${1:-}" == "-" && \$# -eq 1 ]]; then
  exit 1
fi
exec "${REAL_PYTHON3}" "\$@"
EOF
  chmod +x "${tmpbin}/python3"

  cat >"${tmpbin}/ruby" <<'EOF'
#!/bin/bash
set -euo pipefail
exit 1
EOF
  chmod +x "${tmpbin}/ruby"

  local out
  out="$(mktemp)"

  set +e
  PANDOC_PDF_LANG=es PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render.config.yaml" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "render fails without available YAML parser"
  assert_contains "$out" "No hay parser YAML disponible" "render reports missing YAML parser"
  assert_contains "$out" "Opción 1: python3 -m pip install pyyaml" "render suggests translated option 1"
  assert_contains "$out" "Opción 2: instalar Ruby con stdlib YAML" "render suggests translated option 2"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}

run_render_native_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render.config.yaml" "${sandbox}/render.config.yaml"

  cat >"${sandbox}/chapters/title-a.md" <<'EOF'
# Chapter A

Contenido A
EOF

  cat >"${sandbox}/chapters/title-b.md" <<'EOF'
# Chapter B

Contenido B
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/metadata.yaml" <<'EOF'
title: Render Test
EOF

  local tmpbin
  tmpbin="$(mktemp -d)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_EMOJI_DIR=${PANDOC_EMOJI_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_OUTPUT_DIR=${PANDOC_MERMAID_OUTPUT_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_BACKGROUND=${PANDOC_MERMAID_BACKGROUND:-}" >> "${TMP_PANDOC_CAPTURE}"

out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -n "$out" ]]; then
  mkdir -p "$(dirname "$out")"
  : > "$out"
fi
exit 0
EOF
  chmod +x "${tmpbin}/pandoc"

  local capture out suffix md_file pdf_file
  capture="$(mktemp)"
  out="$(mktemp)"
  suffix="$(date +%Y%m%d)"
  md_file="${sandbox}/custom-output/Render Test-${suffix}.md"
  pdf_file="${sandbox}/custom-output/Render Test-${suffix}.pdf"

  if PANDOC_PDF_LANG=es TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render.config.yaml" >"$out" 2>&1; then
    pass "native render runs pandoc"
  else
    fail "native render should run pandoc"
  fi

  assert_contains "$out" "Native mode enabled" "render reports native mode"
  assert_contains "$capture" "custom-output/Render Test-${suffix}\.pdf" "native render respects output.dir"
  assert_contains "$capture" "PANDOC_EMOJI_DIR=.*output/emoji" "native render exports emoji dir"
  assert_contains "$capture" "PANDOC_MERMAID_OUTPUT_DIR=.*output/mermaid" "native render exports mermaid dir"
  assert_contains "$capture" "PANDOC_MERMAID_BACKGROUND=transparent" "native render exports background"

  if [[ -f "$md_file" ]]; then
    pass "native render generates merged markdown"
  else
    fail "native render must generate merged markdown"
  fi

  if [[ -f "$pdf_file" ]]; then
    pass "native render generates output pdf"
  else
    fail "native render must generate output pdf"
  fi

  assert_contains "$md_file" "\\\\clearpage" "native render applies clearpage between H1"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_native_advanced_paths_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/filters" "${sandbox}/assets/media" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render-extra-filter.config.yaml" "${sandbox}/render-extra-filter.config.yaml"

  cat >"${sandbox}/chapters/01-intro.md" <<'EOF'
# Intro

Contenido avanzado
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/filters/custom.lua" <<'EOF'
function Str(el)
  return el
end
EOF

  local tmpbin
  tmpbin="$(mktemp -d)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_EMOJI_DIR=${PANDOC_EMOJI_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_OUTPUT_DIR=${PANDOC_MERMAID_OUTPUT_DIR:-}" >> "${TMP_PANDOC_CAPTURE}"
echo "PANDOC_MERMAID_BACKGROUND=${PANDOC_MERMAID_BACKGROUND:-}" >> "${TMP_PANDOC_CAPTURE}"
exit 0
EOF
  chmod +x "${tmpbin}/pandoc"

  local capture out
  capture="$(mktemp)"
  out="$(mktemp)"

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render-extra-filter.config.yaml" >"$out" 2>&1; then
    pass "advanced render runs pandoc"
  else
    fail "advanced render should run pandoc"
  fi

  assert_contains "$capture" "--lua-filter=.*/filters/custom\.lua" "advanced render includes extra_lua_filter"
  assert_contains "$capture" "PANDOC_EMOJI_DIR=.*/dist/assets/emoji" "advanced render respects emoji_dir"
  assert_contains "$capture" "PANDOC_MERMAID_OUTPUT_DIR=.*/dist/assets/mermaid" "advanced render respects mermaid output_dir"
  assert_contains "$capture" "PANDOC_MERMAID_BACKGROUND=white" "advanced render respects mermaid background"
  assert_contains "$capture" "--resource-path=.*/chapters:.*/assets/media" "advanced render composes resource_path"

  if grep -q -- "--metadata-file=" "$capture"; then
    fail "advanced render should not pass metadata-file when empty"
  else
    pass "advanced render omits empty metadata-file"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_no_hidden_defaults_test() {
  if [[ -e "${ROOT_DIR}/scripts/render-native.rb" ]]; then
    fail "the Ruby renderer must not come back: there is one renderer, in Python"
  else
    pass "there is a single renderer (no render-native.rb)"
  fi

  if [[ -e "${ROOT_DIR}/defaults/default.yaml" ]]; then
    fail "the toolkit must not ship a config defaults baseline"
  else
    pass "the toolkit ships no config defaults baseline"
  fi

  if ! command -v ruby >/dev/null 2>&1; then
    echo "SKIP hidden defaults check (ruby not available)"
    return 0
  fi

  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  cat >"${sandbox}/partial.config.yaml" <<'EOF'
project:
  name: partial
  base_dir: ./work

document:
  title: "Partial Document"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  file_prefix: "partial"
  suffix: "manual"

pandoc:
  pdf_engine: lualatex
EOF

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/render-native.py" "${sandbox}/partial.config.yaml" "$sandbox" >"$out" 2>&1; then
    pass "renderer accepts a config without the optional sections"
  else
    fail "renderer should accept a config without the optional sections ($(tail -2 "$out"))"
  fi

  assert_not_contains "$capture" "--resource-path" "a config without resource_path gets no hidden default resource path"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_missing_explicit_file_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/i18n.sh" "${sandbox}/scripts/i18n.sh"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render-missing-explicit.config.yaml" "${sandbox}/render-missing-explicit.config.yaml"

  cat >"${sandbox}/chapters/01-intro.md" <<'EOF'
# Intro

Only one file present
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/metadata.yaml" <<'EOF'
title: Missing explicit
EOF

  local out
  out="$(mktemp)"

  set +e
  PANDOC_PDF_LANG=es "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render-missing-explicit.config.yaml" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "render fails when explicit_files references missing file"
  assert_contains "$out" "Explicit file not found" "render reports missing file"

  rm -rf "$sandbox"
  rm -f "$out"
}

# ---------------------------------------------------------------------------
# S1 — config contract alignment
#   input.order / output.keep_merged_markdown / document.* template vars /
#   filters.emoji.include_ballot_icons / runtime.strict
# ---------------------------------------------------------------------------

run_render_order_semantics_test() {
  local sandbox tmpbin capture out merged
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  merged="${sandbox}/work/out/S1 Document-manual.md"

  printf '# Chapter Two\n\ncontent two\n' >"${sandbox}/work/chapters/chapter-2.md"
  printf '# Chapter Ten\n\ncontent ten\n' >"${sandbox}/work/chapters/chapter-10.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts input.order=natural"
  else
    fail "render should accept input.order=natural ($(tail -2 "$out"))"
  fi

  local pos_two pos_ten
  pos_two="$(line_of_match "$merged" '^# Chapter Two')"
  pos_ten="$(line_of_match "$merged" '^# Chapter Ten')"
  if [[ -n "$pos_two" && -n "$pos_ten" && "$pos_two" -lt "$pos_ten" ]]; then
    pass "input.order=natural sorts chapter-2 before chapter-10"
  else
    fail "input.order=natural must sort chapter-2 before chapter-10 (two=${pos_two:-none}, ten=${pos_ten:-none})"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" alphabetical true "" true
  rm -f "$merged"
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts input.order=alphabetical"
  else
    fail "render should accept input.order=alphabetical ($(tail -2 "$out"))"
  fi

  pos_two="$(line_of_match "$merged" '^# Chapter Two')"
  pos_ten="$(line_of_match "$merged" '^# Chapter Ten')"
  if [[ -n "$pos_two" && -n "$pos_ten" && "$pos_ten" -lt "$pos_two" ]]; then
    pass "input.order=alphabetical sorts chapter-10 before chapter-2"
  else
    fail "input.order=alphabetical must sort chapter-10 before chapter-2 (two=${pos_two:-none}, ten=${pos_ten:-none})"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" bogus true "" true
  local code
  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "render rejects an unsupported input.order"
  assert_contains "$out" "input.order" "unsupported input.order names the field"
  assert_contains "$out" "alphabetical" "unsupported input.order lists supported values"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_keep_merged_markdown_test() {
  local sandbox tmpbin capture out merged pdf
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"
  merged="${sandbox}/work/out/S1 Document-manual.md"
  pdf="${sandbox}/work/out/S1 Document-manual.pdf"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural false "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts output.keep_merged_markdown=false"
  else
    fail "render should accept output.keep_merged_markdown=false ($(tail -2 "$out"))"
  fi

  if [[ -f "$pdf" ]]; then
    pass "keep_merged_markdown=false still writes the PDF"
  else
    fail "keep_merged_markdown=false must still write the PDF"
  fi

  if [[ -f "$merged" ]]; then
    fail "keep_merged_markdown=false must remove the merged markdown"
  else
    pass "keep_merged_markdown=false removes the merged markdown"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts output.keep_merged_markdown=true"
  else
    fail "render should accept output.keep_merged_markdown=true ($(tail -2 "$out"))"
  fi

  if [[ -f "$merged" ]]; then
    pass "keep_merged_markdown=true keeps the merged markdown"
  else
    fail "keep_merged_markdown=true must keep the merged markdown"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

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

run_render_ballot_icons_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\n- [ ] unchecked\n- [x] checked\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts include_ballot_icons=true"
  else
    fail "render should accept include_ballot_icons=true ($(tail -2 "$out"))"
  fi
  assert_contains "$capture" "^PANDOC_EMOJI_BALLOT_ICONS=1$" "include_ballot_icons=true enables ballot glyphs"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" false
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts include_ballot_icons=false"
  else
    fail "render should accept include_ballot_icons=false ($(tail -2 "$out"))"
  fi
  assert_contains "$capture" "^PANDOC_EMOJI_BALLOT_ICONS=0$" "include_ballot_icons=false disables ballot glyphs"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_emoji_filter_plain_heading_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "⏭  SKIP emoji filter heading check (pandoc not available)"
    return 0
  fi

  local md tex
  md="$(mktemp)"
  tex="$(mktemp)"
  printf '# Plain Heading\n\nText with an emoji \xe2\x9c\x85 and plain words.\n' >"$md"

  if pandoc "$md" -t latex --lua-filter="${ROOT_DIR}/filters/emoji.lua" >"$tex" 2>&1; then
    pass "emoji filter produces latex output"
  else
    fail "emoji filter should produce latex output ($(tail -2 "$tex"))"
  fi

  assert_contains "$tex" '\\section\{Plain Heading\}' "emoji filter keeps a plain heading plain"
  assert_not_contains "$tex" '\\texorpdfstring' "emoji filter does not format plain headings (needs hyperref otherwise)"

  rm -f "$md" "$tex"
}

run_render_plan_json_test() {
  if [[ -z "${REAL_PYTHON3}" ]]; then
    echo "SKIP render plan json (python3 not available)"
    return 0
  fi

  local sandbox tmpbin capture plan out code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  plan="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter Two\n\ncontent two\n' >"${sandbox}/work/chapters/chapter-2.md"
  printf '# Chapter Ten\n\ncontent ten\n' >"${sandbox}/work/chapters/chapter-10.md"
  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$plan" 2>"$out"
  code=$?
  set -e
  assert_exit_code "0" "$code" "render --dry-run --json exits 0"

  if "${REAL_PYTHON3}" -c "import json,sys; json.load(open(sys.argv[1]))" "$plan" >/dev/null 2>&1; then
    pass "render --dry-run --json emits valid JSON"
  else
    fail "render --dry-run --json must emit valid JSON ($(head -3 "$out"))"
  fi

  assert_json_expr "$plan" 'd["plan_version"] == 1' "plan declares plan_version 1"
  assert_json_expr "$plan" '[p.split("/")[-1] for p in d["chapters"]] == ["chapter-2.md", "chapter-10.md"]' "plan lists chapters in effective order"
  assert_json_expr "$plan" 'd["pandoc"]["argv"][0] == "pandoc"' "plan argv starts with pandoc"
  assert_json_expr "$plan" '"--pdf-engine=lualatex" in d["pandoc"]["argv"]' "plan reflects pdf_engine from config"
  assert_json_expr "$plan" 'd["env"]["PANDOC_EMOJI_BALLOT_ICONS"] == "1"' "plan carries the emoji ballot environment"
  assert_json_expr "$plan" 'd["side_effects"]["keep_merged_markdown"] is True' "plan declares keep_merged_markdown"
  assert_json_expr "$plan" 'd["side_effects"]["emoji"]["dir"].endswith("/work/out/emoji")' "plan resolves the emoji directory"
  assert_json_expr "$plan" 'd["toolkit"]["version"] != ""' "plan reports the toolkit version"

  if [[ -s "$capture" ]]; then
    fail "render --dry-run must not invoke pandoc"
  else
    pass "render --dry-run does not invoke pandoc"
  fi

  if [[ -e "${sandbox}/work/out" ]]; then
    fail "render --dry-run must not create output files or directories"
  else
    pass "render --dry-run has no side effects"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$plan" "$out"
}

run_render_dry_run_human_test() {
  local sandbox tmpbin capture out code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"
  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" --dry-run >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "render --dry-run exits 0"
  assert_contains "$out" "pandoc " "render --dry-run prints the pandoc invocation"
  assert_not_contains "$out" "Running:" "render --dry-run does not claim pandoc ran"

  if [[ -e "${sandbox}/work/out" ]]; then
    fail "render --dry-run (human) must not create output files"
  else
    pass "render --dry-run (human) has no side effects"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_emoji_filter_contexts_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP emoji filter contexts (pandoc not available)"
    return 0
  fi

  local dir md tex images remaining
  dir="$(mktemp -d)"
  md="$(mktemp)"
  tex="$(mktemp)"

  # A real glyph so the filter substitutes instead of falling back to the character.
  cp "${ROOT_DIR}/filters/emoji/2610.svg" "${dir}/2705.svg"

  cat >"$md" <<'EOF'
# Heading

Paragraph text.

| Col |
|-----|
| cell |

: Caption here

- item
EOF
  # Write the emoji through printf so this test file stays ASCII-clean.
  printf '# Heading \xe2\x9c\x85\n\nParagraph \xe2\x9c\x85 text.\n\n| Col |\n|-----|\n| \xe2\x9c\x85 cell |\n\n: Caption \xe2\x9c\x85 here\n\n- item \xe2\x9c\x85\n' >"$md"

  if PANDOC_EMOJI_DIR="$dir" pandoc "$md" -t latex --lua-filter="${ROOT_DIR}/filters/emoji.lua" >"$tex" 2>&1; then
    pass "emoji filter renders mixed contexts"
  else
    fail "emoji filter should render mixed contexts ($(tail -2 "$tex"))"
  fi

  images="$(grep -c "includesvg\|includegraphics" "$tex" || true)"
  remaining="$(grep -c $'\xe2\x9c\x85' "$tex" || true)"
  assert_exit_code "0" "$remaining" "emoji filter substitutes every emoji context (heading, paragraph, table cell, caption, list)"
  if [[ "${images:-0}" -ge 5 ]]; then
    pass "emoji filter emits an image per substituted emoji"
  else
    fail "emoji filter should emit at least 5 images, got ${images:-0}"
  fi

  rm -rf "$dir"
  rm -f "$md" "$tex"
}

run_render_keep_merged_on_pandoc_failure_test() {
  local sandbox tmpbin capture out merged code
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  mkdir -p "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
echo "failing on purpose" >&2
exit 7
EOF
  chmod +x "${tmpbin}/pandoc"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"
  write_contract_config "${sandbox}/pdf.config.yaml" natural false "" true
  merged="${sandbox}/work/out/S1 Document-manual.md"

  set +e
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1
  code=$?
  set -e

  assert_exit_code "7" "$code" "render propagates pandoc's exit code"
  if [[ -f "$merged" ]]; then
    pass "keep_merged_markdown=false preserves the markdown when pandoc fails"
  else
    fail "keep_merged_markdown=false must keep the markdown when pandoc fails (diagnosis)"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_mermaid_dir_gate_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true false
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts mermaid.enabled=false"
  else
    fail "render should accept mermaid.enabled=false ($(tail -2 "$out"))"
  fi

  if [[ -d "${sandbox}/work/out/mermaid" ]]; then
    fail "render must not create the mermaid directory when the filter is disabled"
  else
    pass "render skips the mermaid directory when the filter is disabled"
  fi

  write_contract_config "${sandbox}/pdf.config.yaml" natural true "" true true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render \
    -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "render accepts mermaid.enabled=true"
  else
    fail "render should accept mermaid.enabled=true ($(tail -2 "$out"))"
  fi

  if [[ -d "${sandbox}/work/out/mermaid" ]]; then
    pass "render creates the mermaid directory when the filter is enabled"
  else
    fail "render must create the mermaid directory when the filter is enabled"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}
