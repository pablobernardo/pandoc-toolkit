#!/bin/bash
# Real publication metadata and the image cover.
# Sourced by tests/run.sh (not run standalone).

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
