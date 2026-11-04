#!/bin/bash
# No LaTeX-only markup in a publication.
# Sourced by tests/run.sh (not run standalone).

run_epub_latex_markup_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP epub latex markup (pandoc not available)"
    return 0
  fi

  local sandbox out epub md code=0
  sandbox="$(new_epub_resource_sandbox)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-resources-manual.epub"
  md="${sandbox}/work/out/epub-resources-manual.md"

  # compat.legacy_clearpage_between_h1 is true, so the PDF plan inserts the
  # command; an EPUB has no TeX to interpret it and must not carry it at all.
  # Run from the project base so this test isolates the LaTeX markup, not paths.
  (
    cd "${sandbox}/work" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB renders with the legacy clearpage switch enabled"

  assert_file_exists "$md" "an epub render keeps the merged markdown when configured"
  assert_not_contains "$md" 'clearpage' "the merged markdown of an EPUB carries no LaTeX clearpage"

  while IFS=$'\t' read -r result message; do
    if [[ "$result" == "0" ]]; then pass "$message"; else fail "$message"; fi
  done < <("${REAL_PYTHON3}" - "$epub" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1]) as archive:
    body = " ".join(
        archive.read(name).decode("utf-8", "ignore")
        for name in archive.namelist()
        if name.endswith(".xhtml")
    )

for marker in ("\\clearpage", "\\vspace"):
    print(f"{0 if marker not in body else 1}\tthe EPUB carries no {marker} LaTeX command")
PY
)

  rm -rf "$sandbox"
  rm -f "$out"
}
