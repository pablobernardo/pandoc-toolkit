#!/bin/bash
# The render command surface: accepted options, rejected legacy flags and hidden defaults.
# Sourced by tests/run.sh (not run standalone).

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
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/scripts/runtime" "${sandbox}/chapters" "${sandbox}/templates" "${sandbox}/i18n/locales"

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

  # Simulates "python3 without PyYAML": the detection probe (`python3 -` with a
  # single argument) fails, validate-config is skipped (this test does not measure
  # it), and the catalog dump (`python3 - <locale.json>`) uses the real
  # interpreter, so the messages really come translated from the catalog.
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
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/partial.config.yaml" "$sandbox" >"$out" 2>&1; then
    pass "renderer accepts a config without the optional sections"
  else
    fail "renderer should accept a config without the optional sections ($(tail -2 "$out"))"
  fi

  # The project base is the only search entry a configuration gets: it is not a
  # hidden default resource directory, it is where the project says it lives.
  local base_path
  base_path="$(cd "${sandbox}/work" && pwd -P)"
  assert_contains "$capture" "--resource-path=${base_path}( |$)" "a config without resource_path searches only its project base"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}
