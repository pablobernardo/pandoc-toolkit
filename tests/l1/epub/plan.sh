#!/bin/bash
# The EPUB plan: no engine, no template and no LaTeX-only markup in the argv.
# Sourced by tests/run.sh (not run standalone).

run_epub_plan_json_test() {
  local sandbox plan out
  sandbox="$(new_epub_sandbox)"
  plan="$(mktemp)"
  out="$(mktemp)"

  write_epub_config "${sandbox}/pdf.config.yaml" epub
  if "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$plan" 2>"$out"; then
    pass "render --dry-run --json exits 0 for output.formats=epub"
  else
    fail "render --dry-run --json should support output.formats=epub ($(tail -2 "$out"))"
  fi

  assert_json_expr "$plan" 'd["pandoc"]["target"]["epub"].endswith("epub-guide-manual.epub")' "plan targets an epub file"
  assert_json_expr "$plan" '"pdf" not in d["pandoc"]["target"]' "an epub plan does not declare a pdf target"
  assert_json_expr "$plan" 'not any(arg.startswith("--pdf-engine") for arg in d["pandoc"]["argv"])' "an epub plan does not select a TeX engine"
  assert_json_expr "$plan" 'not any(arg.startswith("--template") for arg in d["pandoc"]["argv"])' "an epub plan does not use the LaTeX template"
  assert_json_expr "$plan" 'not any(arg.startswith("babel-lang=") or arg.startswith("titlepage=") or arg == "fig-pos=!htbp" for arg in d["pandoc"]["argv"])' "an epub plan drops LaTeX-only variables"
  assert_json_expr "$plan" '"title=EPUB Sandbox Guide" in d["pandoc"]["argv"]' "an epub plan carries the document title as real metadata"
  assert_json_expr "$plan" '"lang=es" in d["pandoc"]["argv"]' "an epub plan carries the document language as real metadata"
  assert_json_expr "$plan" 'd["pandoc"]["argv"][-2] == "-o" and d["pandoc"]["argv"][-1].endswith(".epub")' "an epub plan writes through -o to the epub path"

  if [[ -e "${sandbox}/work/out" ]]; then
    fail "an epub dry run must not create output files or directories"
  else
    pass "an epub dry run has no side effects"
  fi

  rm -rf "$sandbox"
  rm -f "$plan" "$out"
}

run_epub_explicit_pdf_matches_default_test() {
  local sandbox with_format without_format out code=0
  sandbox="$(new_epub_sandbox)"
  with_format="$(mktemp)"
  without_format="$(mktemp)"
  out="$(mktemp)"

  write_epub_config "${sandbox}/pdf.config.yaml" pdf
  "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$with_format" 2>"$out" || code=$?

  write_epub_config "${sandbox}/pdf.config.yaml" epub
  "${REAL_PYTHON3}" - "${sandbox}/pdf.config.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")
path.write_text(text.replace("  formats: [epub]\n", ""), encoding="utf-8")
PY
  "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$without_format" 2>"$out" || code=$?

  assert_exit_code "0" "$code" "an omitted output.formats still plans a PDF"
  if "${REAL_PYTHON3}" - "$with_format" "$without_format" <<'PY'
import json
import sys

with_format = json.load(open(sys.argv[1], encoding="utf-8"))
without_format = json.load(open(sys.argv[2], encoding="utf-8"))
sys.exit(0 if with_format == without_format else 1)
PY
  then
    pass "output.formats=pdf is identical to omitting it"
  else
    fail "output.formats=pdf must be identical to omitting it"
  fi

  assert_json_expr "$without_format" 'd["pandoc"]["target"]["pdf"].endswith("epub-guide-manual.pdf")' "an omitted format keeps the pdf target"
  assert_json_expr "$without_format" 'any(arg.startswith("--pdf-engine=xelatex") for arg in d["pandoc"]["argv"])' "an omitted format keeps the TeX engine"

  rm -rf "$sandbox"
  rm -f "$with_format" "$without_format" "$out"
}

run_epub_preflight_no_tex_test() {
  local sandbox tmpbin out code=0
  sandbox="$(new_epub_sandbox)"
  tmpbin="$(mktemp -d)"
  out="$(mktemp)"

  local c
  for c in pandoc curl; do
    printf '#!/bin/bash\nexit 0\n' >"${tmpbin}/${c}"
    chmod +x "${tmpbin}/${c}"
  done
  cat >"${tmpbin}/python3" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
  chmod +x "${tmpbin}/python3"

  write_epub_config "${sandbox}/pdf.config.yaml" epub
  PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "doctor passes an epub config without any TeX engine"
  assert_contains "$out" "Doctor OK" "doctor reports OK for epub without TeX"

  write_epub_config "${sandbox}/pdf.config.yaml" pdf
  code=0
  PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1 || code=$?
  assert_exit_code "1" "$code" "doctor still requires a TeX engine for pdf"
  assert_contains "$out" "xelatex" "the pdf failure names the missing engine"

  local formats
  for formats in epub 'epub, pdf'; do
    write_epub_config "${sandbox}/pdf.config.yaml" "$formats"
    "${REAL_PYTHON3}" - "${sandbox}/pdf.config.yaml" "$formats" <<'PY'
import sys
from pathlib import Path
p = Path(sys.argv[1])
formats = sys.argv[2].split(", ")
p.write_text(p.read_text().replace("formats: [" + sys.argv[2] + "]",
                                  "formats:\n" + "\n".join("    - " + f for f in formats)))
PY
    code=0
    PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1 || code=$?
    if [[ "$formats" == epub ]]; then
      assert_exit_code "0" "$code" "doctor reads a block EPUB formats list without TeX"
    else
      assert_exit_code "1" "$code" "doctor requires TeX for a block EPUB/PDF formats list"
      assert_contains "$out" "xelatex" "multi-format preflight names the missing engine"
    fi
  done

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}
