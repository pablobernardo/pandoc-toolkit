#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="${ROOT_DIR}/bin/pandoc-pdf"
FIXTURES_DIR="${ROOT_DIR}/tests/fixtures"
REAL_PYTHON3="$(command -v python3 || true)"

PASS=0
FAIL=0

green() { printf '\033[0;32m%s\033[0m\n' "$1"; }
red() { printf '\033[0;31m%s\033[0m\n' "$1"; }

pass() {
  PASS=$((PASS + 1))
  green "✅ $1"
}

fail() {
  FAIL=$((FAIL + 1))
  red "❌ $1"
}

assert_exit_code() {
  local expected="$1"
  local actual="$2"
  local msg="$3"
  if [[ "$expected" == "$actual" ]]; then
    pass "$msg"
  else
    fail "$msg (esperado=${expected}, actual=${actual})"
  fi
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  local msg="$3"
  if grep -qE -- "$pattern" "$file"; then
    pass "$msg"
  else
    fail "$msg"
  fi
}

run_help_test() {
  local out
  out="$(mktemp)"
  if "$CLI" --help >"$out" 2>&1; then
    pass "--help devuelve exit 0"
  else
    fail "--help debería devolver exit 0"
  fi
  assert_contains "$out" "Usage:" "--help imprime usage"
  rm -f "$out"
}

run_version_tests() {
  local out
  out="$(mktemp)"

  if "$CLI" --version >"$out" 2>&1; then
    pass "--version devuelve exit 0"
  else
    fail "--version debería devolver exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "--version imprime versión semántica"

  : >"$out"
  if "$CLI" version >"$out" 2>&1; then
    pass "version devuelve exit 0"
  else
    fail "version debería devolver exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "version imprime versión semántica"

  rm -f "$out"
}

run_info_tests() {
  local out
  out="$(mktemp)"

  if "$CLI" info >"$out" 2>&1; then
    pass "info devuelve exit 0"
  else
    fail "info debería devolver exit 0"
  fi
  assert_contains "$out" "^pandoc-pdf [0-9]+\.[0-9]+\.[0-9]+$" "info incluye versión"
  assert_contains "$out" "^root_dir:" "info incluye root_dir"
  assert_contains "$out" "^yaml_parser:" "info incluye parser YAML"
  assert_contains "$out" "schema_path: .*exists=true" "info reporta schema"

  : >"$out"
  if "$CLI" info --json >"$out" 2>&1; then
    pass "info --json devuelve exit 0"
  else
    fail "info --json debería devolver exit 0"
  fi
  assert_contains "$out" '^\{' "info --json imprime objeto JSON"
  assert_contains "$out" '"name": "pandoc-pdf"' "info --json incluye name"
  assert_contains "$out" '"version": "[0-9]+\.[0-9]+\.[0-9]+"' "info --json incluye versión"
  assert_contains "$out" '"schema_exists": true' "info --json incluye existencia de schema"

  rm -f "$out"
}

run_unknown_command_test() {
  local out
  out="$(mktemp)"
  set +e
  "$CLI" comando-inexistente >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "comando desconocido devuelve exit 1"
  assert_contains "$out" "Comando desconocido" "comando desconocido muestra error"
  rm -f "$out"
}

run_doctor_success_with_mocked_path() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 curl mmdc xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  if PATH="$tmpbin" /bin/bash "$CLI" doctor >"$out" 2>&1; then
    pass "doctor pasa con dependencias mockeadas"
  else
    fail "doctor debería pasar con dependencias mockeadas"
  fi
  assert_contains "$out" "Doctor OK" "doctor reporta OK"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_failure_missing_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(python3 curl mmdc xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PATH="$tmpbin" /bin/bash "$CLI" doctor >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor falla si falta pandoc"
  assert_contains "$out" "pandoc" "doctor informa dependencia faltante"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_with_config_required_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-required-cmd.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor -c falla por comando requerido faltante"
  assert_contains "$out" "mycustomcmd" "doctor -c informa comando faltante del config"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_rejects_invalid_required_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-invalid-required-cmd.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor -c falla con nombre de comando inválido"
  assert_contains "$out" "Nombre de comando inválido" "doctor -c informa comando inválido"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_bootstrap_linux_pkg_manager_detection_tests() {
  local bootstrap_script
  bootstrap_script="${ROOT_DIR}/scripts/bootstrap.sh"

  local tmpbin out

  # Caso 1: apt-get detectado
  tmpbin="$(mktemp -d)"
  cat >"${tmpbin}/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
  chmod +x "${tmpbin}/uname"

  for c in pandoc python3 curl mmdc xelatex apt-get; do
    cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  if PATH="${tmpbin}" /bin/bash "${bootstrap_script}" --dry-run --yes --skip-link >"$out" 2>&1; then
    pass "bootstrap detecta apt-get en Linux"
  else
    fail "bootstrap debería detectar apt-get en Linux"
  fi
  assert_contains "$out" "Gestor de paquetes detectado: apt-get" "bootstrap informa apt-get detectado"
  assert_contains "$out" "\[dry-run\] sudo apt-get install -y pandoc" "bootstrap genera comando apt-get esperado"
  rm -rf "$tmpbin"
  rm -f "$out"

  # Caso 2: dnf detectado
  tmpbin="$(mktemp -d)"
  cat >"${tmpbin}/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
  chmod +x "${tmpbin}/uname"

  for c in pandoc python3 curl mmdc xelatex dnf; do
    cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  if PATH="${tmpbin}" /bin/bash "${bootstrap_script}" --dry-run --yes --skip-link >"$out" 2>&1; then
    pass "bootstrap detecta dnf en Linux"
  else
    fail "bootstrap debería detectar dnf en Linux"
  fi
  assert_contains "$out" "Gestor de paquetes detectado: dnf" "bootstrap informa dnf detectado"
  assert_contains "$out" "\[dry-run\] sudo dnf install -y pandoc" "bootstrap genera comando dnf esperado"
  rm -rf "$tmpbin"
  rm -f "$out"

  # Caso 3: sin gestor soportado
  tmpbin="$(mktemp -d)"
  cat >"${tmpbin}/uname" <<'EOF'
#!/bin/bash
echo Linux
EOF
  chmod +x "${tmpbin}/uname"

  for c in pandoc python3 curl mmdc xelatex; do
    cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  set +e
  PATH="${tmpbin}" /bin/bash "${bootstrap_script}" --dry-run --yes --skip-link >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "bootstrap falla si no detecta gestor de paquetes"
  assert_contains "$out" "No se ha detectado un gestor de paquetes soportado" "bootstrap informa falta de gestor soportado"
  rm -rf "$tmpbin"
  rm -f "$out"
}

run_validate_config_tests() {
  local out_ok
  out_ok="$(mktemp)"
  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid.config.yaml" >"$out_ok" 2>&1; then
    pass "validate-config pasa con config válida"
  else
    fail "validate-config debería pasar con config válida"
  fi
  assert_contains "$out_ok" "Config válida" "validate-config imprime éxito"
  rm -f "$out_ok"

  local out_no_template
  out_no_template="$(mktemp)"
  if "$CLI" validate-config -c "${FIXTURES_DIR}/valid-missing-template.config.yaml" >"$out_no_template" 2>&1; then
    pass "validate-config pasa si no se informa pandoc.template"
  else
    fail "validate-config debería pasar sin pandoc.template (usa default)"
  fi
  assert_contains "$out_no_template" "Config válida" "validate-config confirma config válida sin template"
  rm -f "$out_no_template"

  local out_bad
  out_bad="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-version.yaml" >"$out_bad" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "validate-config falla si falta version"
  assert_contains "$out_bad" "version" "validate-config informa campo faltante"
  rm -f "$out_bad"

  local out_type
  out_type="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-type-runtime-strict.yaml" >"$out_type" 2>&1
  local code_type=$?
  set -e
  assert_exit_code "1" "$code_type" "validate-config falla por tipo inválido"
  assert_contains "$out_type" "runtime\.strict" "validate-config informa tipo inválido"
  rm -f "$out_type"

  local out_extra
  out_extra="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-extra-root-field.yaml" >"$out_extra" 2>&1
  local code_extra=$?
  set -e
  assert_exit_code "1" "$code_extra" "validate-config falla por campo extra"
  assert_contains "$out_extra" "no permitidos" "validate-config informa additionalProperties"
  rm -f "$out_extra"

  local out_template_path
  out_template_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-template-path.yaml" >"$out_template_path" 2>&1
  local code_template_path=$?
  set -e
  assert_exit_code "1" "$code_template_path" "validate-config falla si no existe pandoc.template"
  assert_contains "$out_template_path" "pandoc\.template" "validate-config informa ruta inválida de template"
  rm -f "$out_template_path"

  local out_chapters_path
  out_chapters_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-chapters-dir.yaml" >"$out_chapters_path" 2>&1
  local code_chapters_path=$?
  set -e
  assert_exit_code "1" "$code_chapters_path" "validate-config falla si no existe input.chapters_dir"
  assert_contains "$out_chapters_path" "input\.chapters_dir" "validate-config informa ruta inválida de chapters_dir"
  rm -f "$out_chapters_path"

  local out_extra_filter_path
  out_extra_filter_path="$(mktemp)"
  set +e
  "$CLI" validate-config -c "${FIXTURES_DIR}/invalid-missing-extra-filter-path.yaml" >"$out_extra_filter_path" 2>&1
  local code_extra_filter_path=$?
  set -e
  assert_exit_code "1" "$code_extra_filter_path" "validate-config falla si no existe extra_lua_filter"
  assert_contains "$out_extra_filter_path" "extra_lua_filters\[0\]" "validate-config informa ruta inválida de extra_lua_filter"
  rm -f "$out_extra_filter_path"
}

run_render_legacy_flag_rejected_test() {
  local out
  out="$(mktemp)"
  set +e
  "$CLI" render --legacy -c "${FIXTURES_DIR}/render.config.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "render rechaza flag --legacy"
  assert_contains "$out" "Argumento no reconocido" "render informa flag legacy inválido"
  rm -f "$out"
}

run_render_native_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/render-native.rb" "${sandbox}/scripts/render-native.rb"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/render-native.rb" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render.config.yaml" "${sandbox}/render.config.yaml"

  cat >"${sandbox}/chapters/title-a.md" <<'EOF'
# Capítulo A

Contenido A
EOF

  cat >"${sandbox}/chapters/title-b.md" <<'EOF'
# Capítulo B

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

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render.config.yaml" >"$out" 2>&1; then
    pass "render nativo ejecuta pandoc"
  else
    fail "render nativo debería ejecutar pandoc"
  fi

  assert_contains "$out" "Modo nativo activo" "render informa modo nativo"
  assert_contains "$capture" "custom-output/Render Test-${suffix}\.pdf" "render nativo respeta output.dir"
  assert_contains "$capture" "PANDOC_EMOJI_DIR=.*output/emoji" "render nativo exporta emoji dir"
  assert_contains "$capture" "PANDOC_MERMAID_OUTPUT_DIR=.*output/mermaid" "render nativo exporta mermaid dir"
  assert_contains "$capture" "PANDOC_MERMAID_BACKGROUND=transparent" "render nativo exporta background"

  if [[ -f "$md_file" ]]; then
    pass "render nativo genera markdown combinado"
  else
    fail "render nativo debe generar markdown combinado"
  fi

  if [[ -f "$pdf_file" ]]; then
    pass "render nativo genera pdf de salida"
  else
    fail "render nativo debe generar pdf de salida"
  fi

  assert_contains "$md_file" "\\\\clearpage" "render nativo aplica clearpage entre H1"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_native_advanced_paths_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/filters" "${sandbox}/assets/media" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/render-native.rb" "${sandbox}/scripts/render-native.rb"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/render-native.rb" "${sandbox}/scripts/prepare-emojis.py"
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
    pass "render avanzado ejecuta pandoc"
  else
    fail "render avanzado debería ejecutar pandoc"
  fi

  assert_contains "$capture" "--lua-filter=.*/filters/custom\.lua" "render avanzado incluye extra_lua_filter"
  assert_contains "$capture" "PANDOC_EMOJI_DIR=.*/dist/assets/emoji" "render avanzado respeta emoji_dir"
  assert_contains "$capture" "PANDOC_MERMAID_OUTPUT_DIR=.*/dist/assets/mermaid" "render avanzado respeta mermaid output_dir"
  assert_contains "$capture" "PANDOC_MERMAID_BACKGROUND=white" "render avanzado respeta background mermaid"
  assert_contains "$capture" "--resource-path=.*/chapters:.*/assets/media" "render avanzado compone resource_path"

  if grep -q -- "--metadata-file=" "$capture"; then
    fail "render avanzado no debería pasar metadata-file cuando está vacío"
  else
    pass "render avanzado omite metadata-file vacío"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_defaults_merge_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/work/chapters" "${sandbox}/defaults" "${sandbox}/templates" "${sandbox}/scripts"

  cp "${ROOT_DIR}/defaults/default.yaml" "${sandbox}/defaults/default.yaml"
  cp "${ROOT_DIR}/scripts/render-native.rb" "${sandbox}/scripts/render-native.rb"
  chmod +x "${sandbox}/scripts/render-native.rb"

  cat >"${sandbox}/work/chapters/01-defaults.md" <<'EOF'
# Defaults

Contenido con defaults
EOF

  cat >"${sandbox}/templates/default.tex" <<'EOF'
\documentclass{article}
\begin{document}
$body$
\end{document}
EOF

  cat >"${sandbox}/pdf.config.yaml" <<'EOF'
project:
  name: defaults-test
  base_dir: ./work

document:
  title: "Defaults Merge"

input:
  chapters_dir: "chapters"
  explicit_files:
    - "01-defaults.md"

output:
  dir: "out"
  file_prefix: "defaults"
  suffix: "manual"

pandoc:
  pdf_engine: lualatex
  toc: false

filters:
  emoji:
    enabled: false
  mermaid:
    enabled: false
EOF

  local tmpbin
  tmpbin="$(mktemp -d)"

  cat >"${tmpbin}/pandoc" <<'EOF'
#!/bin/bash
set -euo pipefail
echo "ARGS:$*" > "${TMP_PANDOC_CAPTURE}"
exit 0
EOF
  chmod +x "${tmpbin}/pandoc"

  local capture out
  capture="$(mktemp)"
  out="$(mktemp)"

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" ruby "${sandbox}/scripts/render-native.rb" "${sandbox}/pdf.config.yaml" "${sandbox}" >"$out" 2>&1; then
    pass "render aplica merge defaults + override local"
  else
    fail "render debería aplicar merge de defaults"
  fi

  assert_contains "$capture" "--pdf-engine=lualatex" "render defaults permite override local de pdf_engine"
  assert_contains "$capture" "--template=.*/templates/default\.tex" "render defaults aplica template por defecto del toolkit"
  assert_contains "$capture" "--number-sections" "render defaults aplica number_sections por defecto"
  assert_contains "$capture" "--resource-path=.*/chapters" "render defaults aplica resource_path por defecto"

  if grep -q -- "--toc" "$capture"; then
    fail "render defaults no debería incluir --toc cuando config local lo desactiva"
  else
    pass "render defaults respeta override local de toc=false"
  fi

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_missing_explicit_file_test() {
  local sandbox
  sandbox="$(mktemp -d)"
  mkdir -p "${sandbox}/bin" "${sandbox}/schemas" "${sandbox}/scripts" "${sandbox}/chapters" "${sandbox}/templates"

  cp "$CLI" "${sandbox}/bin/pandoc-pdf"
  chmod +x "${sandbox}/bin/pandoc-pdf"
  cp "${ROOT_DIR}/scripts/validate-config.py" "${sandbox}/scripts/validate-config.py"
  cp "${ROOT_DIR}/scripts/render-native.py" "${sandbox}/scripts/render-native.py"
  cp "${ROOT_DIR}/scripts/render-native.rb" "${sandbox}/scripts/render-native.rb"
  cp "${ROOT_DIR}/scripts/prepare-emojis.py" "${sandbox}/scripts/prepare-emojis.py"
  chmod +x "${sandbox}/scripts/validate-config.py" "${sandbox}/scripts/render-native.py" "${sandbox}/scripts/render-native.rb" "${sandbox}/scripts/prepare-emojis.py"
  cp "${ROOT_DIR}/schemas/pdf-config.schema.json" "${sandbox}/schemas/pdf-config.schema.json"
  cp "${FIXTURES_DIR}/render-missing-explicit.config.yaml" "${sandbox}/render-missing-explicit.config.yaml"

  cat >"${sandbox}/chapters/01-intro.md" <<'EOF'
# Intro

Solo un archivo presente
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
  "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/render-missing-explicit.config.yaml" >"$out" 2>&1
  local code=$?
  set -e

  assert_exit_code "1" "$code" "render falla si explicit_files referencia archivo ausente"
  assert_contains "$out" "Archivo explícito no encontrado" "render informa archivo faltante"

  rm -rf "$sandbox"
  rm -f "$out"
}

main() {
  echo "== Ejecutando tests de pandoc-pdf =="
  run_help_test
  run_version_tests
  run_info_tests
  run_unknown_command_test
  run_doctor_success_with_mocked_path
  run_doctor_failure_missing_cmd
  run_doctor_with_config_required_cmd
  run_doctor_rejects_invalid_required_cmd
  run_bootstrap_linux_pkg_manager_detection_tests
  run_validate_config_tests
  run_render_legacy_flag_rejected_test
  run_render_native_test
  run_render_native_advanced_paths_test
  run_render_defaults_merge_test
  run_render_missing_explicit_file_test

  echo ""
  echo "Resumen: PASS=${PASS} FAIL=${FAIL}"
  if [[ "$FAIL" -gt 0 ]]; then
    exit 1
  fi
}

main "$@"
