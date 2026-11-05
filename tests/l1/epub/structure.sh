#!/bin/bash
# Publication structure: split chapters, heading page breaks and navigation emoji.
# Sourced by tests/run.sh (not run standalone).

run_epub_render_structure_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP epub render structure (pandoc not available)"
    return 0
  fi

  local sandbox out epub md pdf result message code=0
  sandbox="$(new_epub_sandbox)"
  out="$(mktemp)"
  epub="${sandbox}/work/out/epub-guide-manual.epub"
  md="${sandbox}/work/out/epub-guide-manual.md"
  pdf="${sandbox}/work/out/epub-guide-manual.pdf"

  write_epub_config "${sandbox}/skelepress.config.yaml" epub
  "${REAL_PYTHON3}" - "${sandbox}/skelepress.config.yaml" <<'PY'
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
  "${sandbox}/bin/skelepress" render -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1 || code=$?
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

  if "${REAL_PYTHON3}" - "$epub" >"$out" <<'PY'
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
  then
    while IFS=$'\t' read -r result message; do
      if [[ "$result" == "0" ]]; then pass "$message"; else fail "$message"; fi
    done < "$out"
  else
    rm -rf "$sandbox"
    rm -f "$out"
    fail "EPUB structure producer failed"
    return 1
  fi

  rm -rf "$sandbox"
  rm -f "$out"
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

  write_epub_config "${sandbox}/skelepress.config.yaml" epub
  "${REAL_PYTHON3}" - "${sandbox}/skelepress.config.yaml" <<'PY'
import sys
from pathlib import Path

path = Path(sys.argv[1])
text = path.read_text()
text = text.replace('  emoji:\n    enabled: false',
                    '  emoji:\n    enabled: true\n    emoji_dir: "out/emoji"\n    include_ballot_icons: false')
path.write_text(text)
PY

  (
    cd "${sandbox}/work" && "${sandbox}/bin/skelepress" render -c "${sandbox}/skelepress.config.yaml"
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

# An EPUB is a closed artefact: a document inside it can only link to something
# the package carries. A relative link to a file elsewhere in the repository
# renders happily and is then rejected by EPUBCheck with RSC-007, which is how
# `docs/usage.md` and `docs/books.md` broke the documentation publication. The
# same link also leads nowhere in the PDF's own index.
run_epub_document_links_stay_inside_publication_test() {
  local output

  output="$("${REAL_PYTHON3}" - "$ROOT_DIR" <<'PY' 2>&1
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "scripts" / "runtime"))
from schema_runtime import load_yaml  # noqa: E402

config = load_yaml(root / "examples" / "documentation" / "skelepress.config.yaml")
given = config["input"]
chapters = given.get("chapters_dir") or "."
rendered = given.get("explicit_files") or []
base = (root / "examples" / "documentation" / (config["project"].get("base_dir") or ".")).resolve()
chapters_root = (base / chapters).resolve()

if not rendered:
    print("NO-RENDERED-FILES")
    raise SystemExit(0)

links = re.compile(r"\]\(([^)\s]+)")
problems = []
for name in rendered:
    document = chapters_root / name
    if not document.is_file():
        problems.append("MISSING " + str(document))
        continue
    for target in links.findall(document.read_text(encoding="utf-8")):
        if "://" in target or target.startswith("#") or target.startswith("mailto:"):
            continue
        resolved = (document.parent / target).resolve()
        try:
            resolved.relative_to(chapters_root)
        except ValueError:
            problems.append("ESCAPES " + chapters + "/" + name + " -> " + target)

for line in problems:
    print(line)
print("CLEAN" if not problems else "DIRTY")
PY
)"

  if printf '%s\n' "$output" | grep -q '^NO-RENDERED-FILES$'; then
    fail "the documentation example must declare the documents it renders"
  elif printf '%s\n' "$output" | grep -q '^CLEAN$'; then
    pass "every link in a rendered document stays inside the publication"
  else
    fail "a rendered document links outside the publication: $(printf '%s\n' "$output" | grep -E '^(ESCAPES|MISSING) ' | head -4 | tr '\n' ' ')"
  fi
}
