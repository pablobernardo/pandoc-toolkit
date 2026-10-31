#!/bin/bash
# EPUB export, phase 1 of issue #94: an optional output.format, a format-aware
# plan and preflight, and EPUB3 output from the existing renderer.
# All mutations stay inside a temporary sandbox.

write_epub_config() {
  local path="$1"
  local format="${2:-epub}"
  local title="${3:-EPUB Sandbox Guide}"
  local language="${4:-es}"
  local keep_md="${5:-false}"
  cat >"$path" <<EOF
version: 1

project:
  name: epub-sandbox
  base_dir: ./work

document:
  title: "${title}"
  author: "EPUB Author"
  language: "${language}"

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  dir: "out"
  file_prefix: "epub-guide"
  suffix: "manual"
  keep_merged_markdown: ${keep_md}
  format: ${format}

pandoc:
  pdf_engine: xelatex
  toc: true
  toc_depth: 2
  number_sections: false
  resource_path:
    - "chapters"

filters:
  emoji:
    enabled: false
  mermaid:
    enabled: false
  extra_lua_filters: []

runtime:
  required_commands:
    - pandoc
  strict: true

compat:
  legacy_clearpage_between_h1: false
EOF
}

new_epub_sandbox() {
  local sandbox
  sandbox="$(new_contract_sandbox)"
  cp "${ROOT_DIR}/templates/epub-header.html" "${sandbox}/templates/epub-header.html"
  printf '# Chapter One\n\nContent one.\n' >"${sandbox}/work/chapters/chapter-1.md"
  printf '\n## Section\n\nContent two.\n' >"${sandbox}/work/chapters/chapter-2.md"
  printf '%s\n' "$sandbox"
}

run_epub_config_validation_test() {
  local sandbox out
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"

  write_epub_config "${sandbox}/pdf.config.yaml" epub
  if "${sandbox}/bin/pandoc-pdf" validate-config -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "config accepts output.format=epub"
  else
    fail "config should accept output.format=epub ($(tail -2 "$out"))"
  fi

  write_epub_config "${sandbox}/pdf.config.yaml" pdf
  if "${sandbox}/bin/pandoc-pdf" validate-config -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "config accepts output.format=pdf"
  else
    fail "config should accept output.format=pdf ($(tail -2 "$out"))"
  fi

  write_epub_config "${sandbox}/pdf.config.yaml" mobi
  local code=0
  "${sandbox}/bin/pandoc-pdf" validate-config -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1 || code=$?
  assert_exit_code "1" "$code" "config rejects an unsupported output.format"
  assert_contains "$out" "must be one of: pdf, epub" "rejection names the supported formats"

  rm -rf "$sandbox"
  rm -f "$out"
}

run_epub_plan_json_test() {
  local sandbox plan out
  sandbox="$(new_epub_sandbox)"
  plan="$(mktemp)"
  out="$(mktemp)"

  write_epub_config "${sandbox}/pdf.config.yaml" epub
  if "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$plan" 2>"$out"; then
    pass "render --dry-run --json exits 0 for output.format=epub"
  else
    fail "render --dry-run --json should support output.format=epub ($(tail -2 "$out"))"
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
path.write_text(text.replace("  format: epub\n", ""), encoding="utf-8")
PY
  "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$without_format" 2>"$out" || code=$?

  assert_exit_code "0" "$code" "an omitted output.format still plans a PDF"
  if "${REAL_PYTHON3}" - "$with_format" "$without_format" <<'PY'
import json
import sys

with_format = json.load(open(sys.argv[1], encoding="utf-8"))
without_format = json.load(open(sys.argv[2], encoding="utf-8"))
sys.exit(0 if with_format == without_format else 1)
PY
  then
    pass "output.format=pdf is identical to omitting it"
  else
    fail "output.format=pdf must be identical to omitting it"
  fi

  assert_json_expr "$without_format" 'd["pandoc"]["target"]["pdf"].endswith("epub-guide-manual.pdf")' "an omitted format keeps the pdf target"
  assert_json_expr "$without_format" 'any(arg.startswith("--pdf-engine=xelatex") for arg in d["pandoc"]["argv"])' "an omitted format keeps the TeX engine"

  rm -rf "$sandbox"
  rm -f "$with_format" "$without_format" "$out"
}

run_epub_render_structure_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP epub render structure (pandoc not available)"
    return 0
  fi

  local sandbox out epub md pdf code=0
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-guide-manual.epub"
  md="${sandbox}/work/out/epub-guide-manual.md"
  pdf="${sandbox}/work/out/epub-guide-manual.pdf"

  write_epub_config "${sandbox}/pdf.config.yaml" epub
  "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "render produces an EPUB from the public CLI"

  if [[ -s "$epub" ]]; then
    pass "render writes the epub file"
  else
    fail "render must write the epub file ($(tail -3 "$out"))"
  fi
  if [[ -e "$pdf" ]]; then
    fail "an epub render must not write a pdf file"
  else
    pass "an epub render writes no pdf file"
  fi
  if [[ -e "$md" ]]; then
    fail "an epub render honours output.keep_merged_markdown=false"
  else
    pass "an epub render honours output.keep_merged_markdown=false"
  fi
  assert_contains "$out" "epub-guide-manual\.epub" "the renderer reports the epub output path"

  while IFS=$'\t' read -r result message; do
    if [[ "$result" == "0" ]]; then pass "$message"; else fail "$message"; fi
  done < <("${REAL_PYTHON3}" - "$epub" <<'PY'
import sys
import xml.etree.ElementTree as ET
import zipfile

path = sys.argv[1]

def check(ok, message):
    print(f"{0 if ok else 1}\t{message}")

try:
    archive = zipfile.ZipFile(path)
except Exception as error:  # noqa: BLE001 - a broken archive is a test result
    check(False, "the epub is a readable zip archive")
    print(f"1\tdetail: {error}")
    sys.exit(0)

check(True, "the epub is a readable zip archive")
infos = archive.infolist()
check(infos[0].filename == "mimetype", "mimetype is the first archive entry")
check(infos[0].compress_type == zipfile.ZIP_STORED, "mimetype is stored uncompressed")
check(archive.read("mimetype") == b"application/epub+zip", "mimetype declares application/epub+zip")

container_ns = {"c": "urn:oasis:names:tc:opendocument:xmlns:container"}
try:
    container = ET.fromstring(archive.read("META-INF/container.xml"))
except Exception:
    check(False, "META-INF/container.xml is well-formed XML")
    sys.exit(0)
check(True, "META-INF/container.xml is well-formed XML")
rootfile = container.find(".//c:rootfile", container_ns)
check(rootfile is not None and (rootfile.get("media-type") or "") == "application/oebps-package+xml",
      "container.xml points at an OEBPS package")

opf_path = rootfile.get("full-path") if rootfile is not None else ""
opf_dir = opf_path.rsplit("/", 1)[0] if "/" in opf_path else ""
names = set(archive.namelist())
try:
    package = ET.fromstring(archive.read(opf_path))
except Exception:
    check(False, "the package document is well-formed XML")
    sys.exit(0)
check(True, "the package document is well-formed XML")
check(package.get("version") == "3.0", "the package document declares EPUB 3.0")

dc = {"dc": "http://purl.org/dc/elements/1.1/"}
titles = [e.text for e in package.findall(".//dc:title", dc)]
languages = [e.text for e in package.findall(".//dc:language", dc)]
identifiers = [e.text for e in package.findall(".//dc:identifier", dc)]
check(titles == ["EPUB Sandbox Guide"], "the package carries the configured title")
authors = [e.text for e in package.findall(".//dc:creator", dc)]
check(authors == ["EPUB Author"], "the package carries the configured author")
check(bool(languages) and (languages[0] or "").startswith("es"), "the package carries the configured language")
check(bool(identifiers) and bool(identifiers[0]), "the package carries an identifier")

opf_ns = {"o": "http://www.idpf.org/2007/opf"}
items = package.findall(".//o:manifest/o:item", opf_ns)
check(bool(items), "the manifest lists items")
nav_items = [i for i in items if "nav" in (i.get("properties") or "").split()]
check(len(nav_items) == 1, "the manifest declares exactly one navigation document")
nav_href = nav_items[0].get("href") if nav_items else ""
nav_path = f"{opf_dir}/{nav_href}" if opf_dir else nav_href
check(nav_path in names, "the navigation document exists in the archive")
if nav_path in names:
    try:
        ET.fromstring(archive.read(nav_path))
        check(True, "the navigation document is well-formed XML")
    except Exception:
        check(False, "the navigation document is well-formed XML")

spine = package.findall(".//o:spine/o:itemref", opf_ns)
check(bool(spine), "the spine orders at least one document")
by_id = {i.get("id"): i.get("href") for i in items}
resolved = [by_id.get(ref.get("idref")) for ref in spine]
check(all(resolved), "every spine reference resolves to a manifest item")
check(all((f"{opf_dir}/{href}" if opf_dir else href) in names for href in resolved if href),
      "every spine document exists in the archive")

chapters = [n for n in names if "/text/ch" in n]
check(bool(chapters), "the archive contains the chapter documents")
# Check every spine document, including title and navigation.
for href in resolved:
    if not href:
        continue
    name = f"{opf_dir}/{href}" if opf_dir else href
    root = ET.fromstring(archive.read(name))
    styles = "\n".join(e.text or "" for e in root.findall(".//{http://www.w3.org/1999/xhtml}style"))
    check("page-break-before: auto" in styles and "break-before: auto" in styles,
          f"{href} overrides the redundant initial heading page break")
archive.close()
PY
)

  rm -rf "$sandbox"
  rm -f "$out"
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

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$out"
}

run_epub_metadata_precedence_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP epub metadata precedence (pandoc not available)"
    return 0
  fi
  local sandbox out code=0
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  write_epub_config "${sandbox}/pdf.config.yaml" epub
  printf '\ntitle: File Title\nauthor: File Author\nlang: pt\n' >"${sandbox}/work/metadata.yaml"
  "${REAL_PYTHON3}" - "${sandbox}/pdf.config.yaml" <<'PYTEST'
import sys
from pathlib import Path
p = Path(sys.argv[1])
p.write_text(p.read_text().replace("pandoc:\n", 'pandoc:\n  metadata_file: "metadata.yaml"\n'))
PYTEST
  "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB renders with a metadata file"
  if "${REAL_PYTHON3}" - "${sandbox}/work/out/epub-guide-manual.epub" <<'PYTEST'
import sys, zipfile
import xml.etree.ElementTree as ET
with zipfile.ZipFile(sys.argv[1]) as z:
    container = ET.fromstring(z.read("META-INF/container.xml"))
    root = container.find(".//{urn:oasis:names:tc:opendocument:xmlns:container}rootfile")
    opf = ET.fromstring(z.read(root.get("full-path")))
    ns = {"dc": "http://purl.org/dc/elements/1.1/"}
    assert [e.text for e in opf.findall(".//dc:title", ns)] == ["File Title"]
    assert [e.text for e in opf.findall(".//dc:creator", ns)] == ["File Author"]
    assert [e.text for e in opf.findall(".//dc:language", ns)] == ["es"]
PYTEST
  then pass "EPUB metadata file wins for title/author; configured language stays authoritative"
  else fail "EPUB metadata precedence must match the document contract"
  fi
  rm -rf "$sandbox"
  rm -f "$out"
}
