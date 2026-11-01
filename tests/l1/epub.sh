#!/bin/bash
# EPUB export, phase 1 of issue #94: an optional output.formats, a format-aware
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
  formats: [${format}]

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
    pass "config accepts output.formats=epub"
  else
    fail "config should accept output.formats=epub ($(tail -2 "$out"))"
  fi

  write_epub_config "${sandbox}/pdf.config.yaml" pdf
  if "${sandbox}/bin/pandoc-pdf" validate-config -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1; then
    pass "config accepts output.formats=pdf"
  else
    fail "config should accept output.formats=pdf ($(tail -2 "$out"))"
  fi

  write_epub_config "${sandbox}/pdf.config.yaml" mobi
  local code=0
  "${sandbox}/bin/pandoc-pdf" validate-config -c "${sandbox}/pdf.config.yaml" >"$out" 2>&1 || code=$?
  assert_exit_code "1" "$code" "config rejects an unsupported output.formats"
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
  "${REAL_PYTHON3}" - "${sandbox}/pdf.config.yaml" <<'PY'
import sys
from pathlib import Path
path = Path(sys.argv[1])
path.write_text(path.read_text().replace('  author: "EPUB Author"',
    '  author: "EPUB Author"\n  subtitle: "A Practical Guide"\n'
    '  publisher: "Example Press"\n  date: "2026"\n  rights: "Example rights"'))
chapter = path.parent / 'work/chapters/chapter-1.md'
rows = '\n'.join(f'| `filters.example.setting_{i}` | default {i} | enabled |' for i in range(1, 9))
chapter.write_text(chapter.read_text() + '\n| Setting | Default | When |\n|---|---|---|\n' + rows + '\n\nAfter table.\n')
PY
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
import re
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
title_path = next((n for n in names if n.endswith('/title_page.xhtml')), None)
check(title_path is not None, "the EPUB retains its internal title page")
if title_path:
    title_root = ET.fromstring(archive.read(title_path))
    fields = {e.get('class'): ''.join(e.itertext()).strip() for e in title_root.iter() if e.get('class')}
    check(all(fields.get(k) == v for k, v in {
        'title': 'EPUB Sandbox Guide', 'subtitle': 'A Practical Guide',
        'author': 'EPUB Author', 'publisher': 'Example Press',
        'date': '2026', 'rights': 'Example rights'}.items()),
        "the title-page layout preserves every configured text field")
    css = '\n'.join(e.text or '' for e in title_root.findall('.//{http://www.w3.org/1999/xhtml}style'))
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    rules = {s.strip(): dict(re.findall(r'([\w-]+)\s*:\s*([^;]+);', body))
             for s, body in re.findall(r'([^{}]+)\{([^{}]*)\}', css)}
    expected = {
        'section.titlepage .title': {'font-size': '2em', 'line-height': '1.15', 'text-align': 'center'},
        'section.titlepage .subtitle': {'margin': '0 0 3em', 'font-size': '1.15em'},
        'section.titlepage .author': {'margin': '0 0 1.25em'},
        'section.titlepage .publisher': {'margin': '0 0 0.35em'},
        'section.titlepage .date': {'margin': '0'},
        'section.titlepage .rights': {'margin': '3em 0 0', 'font-size': '0.75em'},
    }
    check(all(all(rules.get(selector, {}).get(k) == v for k, v in props.items())
              for selector, props in expected.items()),
          "EPUB title-page typography separates subtitle, credits and rights")
    title_rules = {s: props for s, props in rules.items() if 'section.titlepage' in s}
    check(bool(title_rules) and all(
        all(part.strip().startswith('section.titlepage') for part in selector.split(','))
        and not any(k in props for k in ('height', 'min-height', 'position'))
        for selector, props in title_rules.items()),
        "title-page styles stay scoped and use reflowable layout")
chapter_root = ET.fromstring(archive.read(next(n for n in chapters if n.endswith('ch001.xhtml'))))
ns = {'h': 'http://www.w3.org/1999/xhtml'}
rows = chapter_root.findall('.//h:table/h:tbody/h:tr', ns)
check(len(rows) == 8 and all(
    [''.join(cell.itertext()) for cell in row.findall('h:td', ns)]
    == [f'filters.example.setting_{i}', f'default {i}', 'enabled']
    for i, row in enumerate(rows, 1)),
    "EPUB preserves all eight table rows and every cell")
check(rules.get('table', {}).get('display') == 'table'
      and rules.get('table', {}).get('overflow') == 'visible'
      and rules.get('table', {}).get('break-inside') == 'auto'
      and rules.get('table', {}).get('page-break-inside') == 'auto',
      "EPUB tables remain fragmentable tables rather than scroll containers")
check(rules.get('table th, table td', {}).get('overflow-wrap') == 'anywhere'
      and rules.get('table code', {}).get('overflow-wrap') == 'anywhere',
      "EPUB table cells and code can wrap long settings without horizontal scrolling")
check('After table.' in ''.join(chapter_root.itertext()),
      "EPUB retains the paragraph following a table")
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

# A phase-2 fixture: an existing cover image in the metadata file, a content
# image referenced from the chapter, and two Markdown task boxes whose SVGs are
# already versioned, so the fixture needs no network access.
write_epub_resource_config() {
  local path="$1"
  cat >"$path" <<'EOF'
version: 1

project:
  name: epub-resources
  base_dir: ./work

document:
  title: "EPUB Resource Guide"
  author: "Resource Author"
  language: "en"

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  dir: "out"
  file_prefix: "epub-resources"
  suffix: "manual"
  keep_merged_markdown: true
  formats: [epub]

pandoc:
  pdf_engine: xelatex
  toc: false
  toc_depth: 2
  number_sections: false
  metadata_file: "metadata.yaml"
  resource_path:
    - "chapters"

filters:
  emoji:
    enabled: true
    emoji_dir: "out/emoji"
    include_ballot_icons: true
  mermaid:
    enabled: false
  extra_lua_filters: []

runtime:
  required_commands:
    - pandoc
  strict: true

compat:
  legacy_clearpage_between_h1: true
EOF
}

new_epub_resource_sandbox() {
  local sandbox
  sandbox="$(new_epub_sandbox)"
  mkdir -p "${sandbox}/work/assets"

  "${REAL_PYTHON3}" - "${sandbox}/work/assets" <<'PY'
import struct
import sys
import zlib
from pathlib import Path


def png(path, width, height, rgb):
    def chunk(kind, payload):
        body = kind + payload
        return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    rows = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))
    Path(path).write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(rows))
        + chunk(b"IEND", b"")
    )


assets = Path(sys.argv[1])
png(assets / "cover.png", 60, 80, (200, 60, 30))
png(assets / "figure.png", 40, 20, (30, 120, 200))
PY

  cat >"${sandbox}/work/metadata.yaml" <<'EOF'
title: "EPUB Resource Guide"
author: "Resource Author"
lang: en
cover-image: assets/cover.png
EOF

  cat >"${sandbox}/work/chapters/chapter-1.md" <<'EOF'
# Resource Chapter

![A blue rectangle](assets/figure.png)

- [ ] pending task
- [x] finished task
EOF

  cat >"${sandbox}/work/chapters/chapter-2.md" <<'EOF'
# Second Chapter

Text only.
EOF

  write_epub_resource_config "${sandbox}/pdf.config.yaml"
  printf '%s\n' "$sandbox"
}

run_epub_resource_path_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP epub resources (pandoc not available)"
    return 0
  fi

  local sandbox elsewhere out epub code=0
  sandbox="$(new_epub_resource_sandbox)"
  elsewhere="$(mktemp -d)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-resources-manual.epub"

  # The cover image and the content image are declared relative to the project,
  # so the command must not depend on where it is invoked.
  (
    cd "$elsewhere" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB resources resolve when the command runs outside the project"

  if [[ -s "$epub" ]]; then
    pass "render writes the epub from an unrelated working directory"
  else
    fail "render must write the epub from an unrelated working directory ($(tail -3 "$out"))"
  fi

  while IFS=$'\t' read -r result message; do
    if [[ "$result" == "0" ]]; then pass "$message"; else fail "$message"; fi
  done < <("${REAL_PYTHON3}" - "$epub" "${sandbox}/work/assets" "${sandbox}/filters/emoji/2610.svg" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET
import zipfile

epub = pathlib.Path(sys.argv[1])
assets = pathlib.Path(sys.argv[2])
ballot = pathlib.Path(sys.argv[3])


def check(ok, message):
    print(f"{0 if ok else 1}\t{message}")


try:
    archive = zipfile.ZipFile(epub)
except Exception as error:  # noqa: BLE001 - a broken archive is a test result
    check(False, "the epub is a readable zip archive")
    print(f"1\tdetail: {error}")
    sys.exit(0)

check(True, "the epub is a readable zip archive")
names = set(archive.namelist())
container = ET.fromstring(archive.read("META-INF/container.xml"))
rootfile = container.find(".//{urn:oasis:names:tc:opendocument:xmlns:container}rootfile")
opf_path = rootfile.get("full-path")
opf_dir = opf_path.rsplit("/", 1)[0] if "/" in opf_path else ""
package = ET.fromstring(archive.read(opf_path))
opf = {"o": "http://www.idpf.org/2007/opf"}

items = package.findall(".//o:manifest/o:item", opf)
covers = [item for item in items if "cover-image" in (item.get("properties") or "").split()]
check(len(covers) == 1, "the manifest declares exactly one cover-image item")
cover_id = covers[0].get("id") if covers else ""
metas = package.findall(".//o:metadata/o:meta", opf)
check([m.get("content") for m in metas if m.get("name") == "cover"] == [cover_id],
      "the package points its cover meta at the cover-image item")

spine = package.findall(".//o:spine/o:itemref", opf)
first = spine[0].get("idref") if spine else ""
check(first == "cover_xhtml", "the image cover opens the spine")
by_id = {item.get("id"): item.get("href") for item in items}
cover_href = by_id.get(first) or ""
cover_path = f"{opf_dir}/{cover_href}" if opf_dir else cover_href
check(bool(cover_href) and cover_path in names, "the cover document exists in the archive")

media = {archive.read(name) for name in names if name.startswith(f"{opf_dir}/media/")}
check(assets.joinpath("figure.png").read_bytes() in media,
      "the content image is embedded byte for byte")
check(ballot.read_bytes() in media,
      "the emoji SVG comes from the versioned emoji directory")

chapter = next(name for name in names if name.endswith("ch001.xhtml"))
chapter_root = ET.fromstring(archive.read(chapter))
html = {"h": "http://www.w3.org/1999/xhtml"}
images = chapter_root.findall(".//h:img", html)
check(len([i for i in images if "emoji" in (i.get("class") or "").split()]) == 2,
      "each task-list box becomes an emoji image")
check(all(opf_dir + "/" + (image.get("src") or "").removeprefix("../") in names for image in images),
      "every chapter image resolves to an archive entry")
archive.close()
PY
)

  rm -rf "$sandbox" "$elsewhere"
  rm -f "$out"
}

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

new_epub_document_metadata_sandbox() {
  local sandbox
  sandbox="$(new_epub_resource_sandbox)"
  # The same project, with the cover declared through document.metadata instead
  # of a metadata file: the two routes must behave the same.
  "${REAL_PYTHON3}" - "${sandbox}/pdf.config.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace('  metadata_file: "metadata.yaml"', '  metadata_file: ""')
text = text.replace('  language: "en"',
                    '  language: "en"\n  metadata:\n    cover-image: "assets/cover.png"')
path.write_text(text)
PY
  printf '%s\n' "$sandbox"
}

run_epub_document_metadata_cover_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP epub document metadata cover (pandoc not available)"
    return 0
  fi

  local sandbox elsewhere plan out epub code=0
  sandbox="$(new_epub_document_metadata_sandbox)"
  elsewhere="$(mktemp -d)"
  plan="$(mktemp)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-resources-manual.epub"

  # A duplicated --metadata cover-image pair reaches pandoc as a MetaList and the
  # EPUB writer refuses it, so the plan must carry the key exactly once.
  "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml" --dry-run --json >"$plan" 2>"$out" || code=$?
  assert_exit_code "0" "$code" "an epub plan with a document.metadata cover renders"
  assert_json_expr "$plan" \
    'len([a for a in d["pandoc"]["argv"] if a.startswith("cover-image=")]) == 1' \
    "the plan carries the cover-image metadata key exactly once"
  assert_json_expr "$plan" \
    '[a for a in d["pandoc"]["argv"] if a.startswith("cover-image=")][0].endswith("/work/assets/cover.png")' \
    "the plan resolves the document.metadata cover against the project base"

  code=0
  (
    cd "$elsewhere" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "a document.metadata cover renders from an unrelated directory"

  if [[ -s "$epub" ]]; then
    pass "render writes the epub with a document.metadata cover"
  else
    fail "render must write the epub with a document.metadata cover ($(tail -3 "$out"))"
  fi

  while IFS=$'\t' read -r result message; do
    if [[ "$result" == "0" ]]; then pass "$message"; else fail "$message"; fi
  done < <("${REAL_PYTHON3}" - "$epub" "${sandbox}/work/assets/cover.png" <<'PY'
import pathlib
import sys
import xml.etree.ElementTree as ET
import zipfile

epub = pathlib.Path(sys.argv[1])
cover = pathlib.Path(sys.argv[2]).read_bytes()


def check(ok, message):
    print(f"{0 if ok else 1}\t{message}")


try:
    archive = zipfile.ZipFile(epub)
except Exception as error:  # noqa: BLE001 - a broken archive is a test result
    check(False, "the epub is a readable zip archive")
    print(f"1\tdetail: {error}")
    sys.exit(0)

names = set(archive.namelist())
container = ET.fromstring(archive.read("META-INF/container.xml"))
rootfile = container.find(".//{urn:oasis:names:tc:opendocument:xmlns:container}rootfile")
opf_path = rootfile.get("full-path")
opf_dir = opf_path.rsplit("/", 1)[0] if "/" in opf_path else ""
package = ET.fromstring(archive.read(opf_path))
opf = {"o": "http://www.idpf.org/2007/opf"}
items = package.findall(".//o:manifest/o:item", opf)
covers = [item for item in items if "cover-image" in (item.get("properties") or "").split()]
check(len(covers) == 1, "the manifest declares exactly one cover-image item")
media = {archive.read(name) for name in names if name.startswith(f"{opf_dir}/media/")}
check(cover in media, "the declared cover is embedded byte for byte")
archive.close()
PY
)

  rm -rf "$sandbox" "$elsewhere"
  rm -f "$plan" "$out"
}

run_epub_heading_emoji_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP epub heading emoji (pandoc not available)"
    return 0
  fi

  local sandbox out epub nav chapter sandbox_emoji code=0
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-guide-manual.epub"
  sandbox_emoji="${sandbox}/work/out/emoji"

  # Seeded so the fixture never needs the network: the preparation step only
  # fetches what is missing.
  mkdir -p "$sandbox_emoji"
  cat >"${sandbox_emoji}/2705.svg" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><rect width="16" height="16" fill="#090"/></svg>
EOF

  cat >"${sandbox}/work/chapters/chapter-1.md" <<'EOF'
# Compatibility Check ✅

Inline emoji in a paragraph ✅ stays an image.
EOF
  printf '# Second Chapter\n\nText only.\n' >"${sandbox}/work/chapters/chapter-2.md"

  write_epub_config "${sandbox}/pdf.config.yaml" epub
  "${REAL_PYTHON3}" - "${sandbox}/pdf.config.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace('  emoji:\n    enabled: false',
                    '  emoji:\n    enabled: true\n    emoji_dir: "out/emoji"\n    include_ballot_icons: false')
path.write_text(text)
PY

  (
    cd "${sandbox}/work" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB renders with an emoji in a heading"

  if [[ -s "$epub" ]]; then
    pass "render writes the epub with an emoji in a heading"
  else
    fail "render must write the epub with an emoji in a heading ($(tail -3 "$out"))"
  fi

  nav="${sandbox}/nav.xhtml"
  chapter="${sandbox}/chapter.xhtml"
  if [[ -s "$epub" ]]; then
    unzip -p "$epub" EPUB/nav.xhtml >"$nav" 2>/dev/null
    unzip -p "$epub" EPUB/text/ch001.xhtml >"$chapter" 2>/dev/null
  fi

  assert_not_contains "$nav" '<img' "the navigation document carries no image, which EPUB rejects as link text"
  assert_not_contains "$nav" '\.\./media' "the navigation document resolves no path outside the package"
  assert_contains "$nav" 'Compatibility Check ✅' "the navigation entry keeps the heading text including the emoji"
  assert_contains "$chapter" 'class="emoji"' "an inline emoji in a paragraph is still replaced by an image"

  # The filter is shared by both formats, so the PDF side must keep its images.
  printf '# Heading ✅\n' >"${sandbox}/heading.md"
  if PANDOC_EMOJI_DIR="$sandbox_emoji" pandoc "${sandbox}/heading.md" -t latex \
    --lua-filter="${ROOT_DIR}/filters/emoji.lua" >"${sandbox}/heading.tex" 2>/dev/null; then
    pass "the emoji filter runs for latex output"
  else
    fail "the emoji filter must run for latex output"
  fi
  assert_contains "${sandbox}/heading.tex" 'includesvg|includegraphics' "a heading emoji stays an image in PDF output"

  rm -rf "$sandbox"
  rm -f "$out"
}

run_chapter_link_rewrite_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP chapter links (pandoc not available)"
    return 0
  fi

  local sandbox out epub md ch1 code=0
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-guide-manual.epub"
  md="${sandbox}/work/out/epub-guide-manual.md"
  ch1="${sandbox}/ch1.xhtml"

  printf '# First Chapter\n\nSee [the second chapter](chapter-2.md).\n' >"${sandbox}/work/chapters/chapter-1.md"
  printf '# Second Chapter\n\nText only.\n' >"${sandbox}/work/chapters/chapter-2.md"
  write_epub_config "${sandbox}/pdf.config.yaml" epub "EPUB Sandbox Guide" es true

  (
    cd "${sandbox}/work" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB renders with a link to a sibling chapter"
  assert_contains "$md" '\]\(#ch-chapter-2\)' "a sibling chapter link becomes an in-document anchor"
  assert_contains "$md" '\[\]\{#ch-chapter-2\}' "the target chapter carries the matching anchor"

  unzip -p "$epub" EPUB/text/ch001.xhtml >"$ch1" 2>/dev/null
  assert_not_contains "$ch1" 'chapter-2\.md' "no dead link to a chapter file survives in the EPUB"
  assert_contains "$ch1" 'ch002\.xhtml#ch-chapter-2|href="#ch-chapter-2"' "the link resolves inside the publication"

  rm -rf "$sandbox"
  rm -f "$out"

  # A project with no sibling links must stay byte-identical: no anchors, no rewrites.
  local plain_md
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  plain_md="${sandbox}/work/out/epub-guide-manual.md"
  printf '# First Chapter\n\nPlain text.\n' >"${sandbox}/work/chapters/chapter-1.md"
  printf '# Second Chapter\n\nText only.\n' >"${sandbox}/work/chapters/chapter-2.md"
  write_epub_config "${sandbox}/pdf.config.yaml" epub "EPUB Sandbox Guide" es true
  code=0
  (
    cd "${sandbox}/work" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/pdf.config.yaml"
  ) >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "EPUB renders without sibling links"
  assert_not_contains "$plain_md" '\[\]\{#' "a project without sibling links gets no injected anchors"

  rm -rf "$sandbox"
  rm -f "$out"
}

run_multi_format_export_test() {
  local out code=0
  out="$(mktemp)"
  "${REAL_PYTHON3}" "${ROOT_DIR}/tests/integration/check-multi-format.py" >"$out" 2>&1 || code=$?
  assert_exit_code "0" "$code" "public multi-format selection, ordering and partial failure checks"
  if [[ "$code" != "0" ]]; then
    tail -60 "$out"
  fi
  rm -f "$out"
}
