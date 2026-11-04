#!/bin/bash
# The native path: which pandoc runs, from where, and what it is given.
# Sourced by tests/run.sh (not run standalone).

run_render_native_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/scripts/runtime" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/runtime/i18n.sh" "${sandbox}/scripts/runtime/i18n.sh"
  cp "${ROOT_DIR}/scripts/runtime/validate-config.py" "${sandbox}/scripts/runtime/validate-config.py"
  cp "${ROOT_DIR}/scripts/runtime/schema_runtime.py" "${sandbox}/scripts/runtime/schema_runtime.py"
  cp "${ROOT_DIR}/scripts/runtime/template_runtime.py" "${sandbox}/scripts/runtime/template_runtime.py"
  cp "${ROOT_DIR}/scripts/runtime/render-native.py" "${sandbox}/scripts/runtime/render-native.py"
  cp "${ROOT_DIR}/scripts/runtime/prepare-emojis.py" "${sandbox}/scripts/runtime/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/runtime/validate-config.py" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/scripts/runtime/prepare-emojis.py"
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
  md_file="${sandbox}/custom-output/report-${suffix}.md"
  pdf_file="${sandbox}/custom-output/report-${suffix}.pdf"

  if PANDOC_PDF_LANG=es TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render.config.yaml" >"$out" 2>&1; then
    pass "native render runs pandoc"
  else
    fail "native render should run pandoc"
  fi

  assert_contains "$out" "Native mode enabled" "render reports native mode"
  assert_contains "$capture" "custom-output/report-${suffix}\.pdf" "native render respects output.dir"
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
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/scripts/runtime" "${sandbox}/chapters" "${sandbox}/filters" "${sandbox}/assets/media" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/runtime/i18n.sh" "${sandbox}/scripts/runtime/i18n.sh"
  cp "${ROOT_DIR}/scripts/runtime/validate-config.py" "${sandbox}/scripts/runtime/validate-config.py"
  cp "${ROOT_DIR}/scripts/runtime/schema_runtime.py" "${sandbox}/scripts/runtime/schema_runtime.py"
  cp "${ROOT_DIR}/scripts/runtime/template_runtime.py" "${sandbox}/scripts/runtime/template_runtime.py"
  cp "${ROOT_DIR}/scripts/runtime/render-native.py" "${sandbox}/scripts/runtime/render-native.py"
  cp "${ROOT_DIR}/scripts/runtime/prepare-emojis.py" "${sandbox}/scripts/runtime/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/runtime/validate-config.py" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/scripts/runtime/prepare-emojis.py"
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

  # The project base is always the last search entry: a declared resource_path
  # keeps priority, and a relative asset declared against the project resolves
  # even when the command runs from somewhere else.
  local base_path
  base_path="$(cd "${sandbox}" && pwd -P)"
  assert_contains "$capture" "--resource-path=[^ ]*:${base_path}( |$)" "advanced render appends the project base to resource_path"

  if grep -q -- "--metadata-file=" "$capture"; then
    fail "advanced render should not pass metadata-file when empty"
  else
    pass "advanced render omits empty metadata-file"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_missing_explicit_file_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/scripts/runtime" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/runtime/i18n.sh" "${sandbox}/scripts/runtime/i18n.sh"
  cp "${ROOT_DIR}/scripts/runtime/validate-config.py" "${sandbox}/scripts/runtime/validate-config.py"
  cp "${ROOT_DIR}/scripts/runtime/schema_runtime.py" "${sandbox}/scripts/runtime/schema_runtime.py"
  cp "${ROOT_DIR}/scripts/runtime/template_runtime.py" "${sandbox}/scripts/runtime/template_runtime.py"
  cp "${ROOT_DIR}/scripts/runtime/render-native.py" "${sandbox}/scripts/runtime/render-native.py"
  cp "${ROOT_DIR}/scripts/runtime/prepare-emojis.py" "${sandbox}/scripts/runtime/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/runtime/validate-config.py" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/scripts/runtime/prepare-emojis.py"
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
