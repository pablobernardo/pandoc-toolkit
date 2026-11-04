#!/bin/bash
# The PDF image cover: document.metadata (or the metadata file) declares
# cover-image, the image page precedes the typographic title page and prints
# even with titlepage: false, and a relative path resolves against
# project.base_dir. Sourced by tests/run.sh (not run standalone).

# A tiny valid PNG generated in place: no binary fixture is committed.
write_cover_png() {
  "${REAL_PYTHON3}" - "$1" <<'PY'
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


png(sys.argv[1], 600, 800, (200, 60, 30))
PY
}

count_in_capture() {
  grep -oE -- "$2" "$1" 2>/dev/null | wc -l | tr -d ' '
}

run_render_pdf_cover_plan_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"
  mkdir -p "${sandbox}/work/assets"
  write_cover_png "${sandbox}/work/assets/cover.png"

  cat >"${sandbox}/cover.config.yaml" <<'CONFIG'
version: 1

project:
  name: cover-plan
  base_dir: ./work

document:
  title: "Cover Doc"
  author: "Cover Author"
  metadata:
    cover-image: "assets/cover.png"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"

pandoc:
  pdf_engine: xelatex
  toc: false
  number_sections: false
CONFIG

  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/cover.config.yaml" "$sandbox" >"$out" 2>&1; then
    pass "renderer accepts a document.metadata cover-image"
  else
    fail "renderer should accept a document.metadata cover-image ($(tail -2 "$out"))"
  fi

  assert_contains "$capture" "cover-image=.*/work/assets/cover\.png" \
    "a relative document.metadata cover-image is resolved against base_dir"
  if [[ "$(count_in_capture "$capture" 'cover-image=')" == "1" ]]; then
    pass "the plan carries the cover-image metadata key exactly once"
  else
    fail "the plan must carry the cover-image metadata key exactly once ($(count_in_capture "$capture" 'cover-image='))"
  fi
  assert_not_contains "$capture" "cover-image=assets/cover\.png" \
    "the raw project-relative value is not passed to pandoc"

  # Without the key nothing cover-related may reach the command line.
  cat >"${sandbox}/nocover.config.yaml" <<'CONFIG'
version: 1

project:
  name: nocover-plan
  base_dir: ./work

document:
  title: "Cover Doc"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"

pandoc:
  pdf_engine: xelatex
  toc: false
  number_sections: false
CONFIG

  capture="$(mktemp)"
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/nocover.config.yaml" "$sandbox" >"$out" 2>&1 || true
  assert_not_contains "$capture" "cover-image" \
    "a document without cover-image emits no cover option"

  # The metadata file wins and keeps the same resolution rule.
  cat >"${sandbox}/work/metadata.yaml" <<'EOF'
title: "Cover Doc"
cover-image: assets/cover.png
EOF
  cat >"${sandbox}/filecover.config.yaml" <<'CONFIG'
version: 1

project:
  name: filecover-plan
  base_dir: ./work

document:
  title: "Cover Doc"

input:
  chapters_dir: "chapters"
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"

pandoc:
  pdf_engine: xelatex
  toc: false
  number_sections: false
  metadata_file: "metadata.yaml"
CONFIG

  capture="$(mktemp)"
  TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" \
    "${REAL_PYTHON3}" "${sandbox}/scripts/runtime/render-native.py" "${sandbox}/filecover.config.yaml" "$sandbox" >"$out" 2>&1 || true
  assert_contains "$capture" "cover-image=.*/work/assets/cover\.png" \
    "a relative cover-image in the metadata file is resolved against base_dir too"

  # Both shipped templates must branch on cover-image, place the image page
  # before the title page and use a matching geometry pair.
  local template cover_line doc_line invoke_line
  for template in default.tex book.tex; do
    if grep -q 'if.cover-image' "${ROOT_DIR}/templates/${template}" \
      && grep -q '\\newgeometry' "${ROOT_DIR}/templates/${template}" \
      && grep -q '\\restoregeometry' "${ROOT_DIR}/templates/${template}"; then
      pass "${template} branches on cover-image with a newgeometry/restoregeometry pair"
    else
      fail "${template} must branch on cover-image with a newgeometry/restoregeometry pair"
    fi
    cover_line="$(line_of_match "${ROOT_DIR}/templates/${template}" 'if.cover-image')"
    doc_line="$(line_of_match "${ROOT_DIR}/templates/${template}" 'begin.document')"
    invoke_line="$(grep -n '\\doTitlePage' "${ROOT_DIR}/templates/${template}" | tail -1 | cut -d: -f1)"
    if [[ -n "$cover_line" && -n "$doc_line" && -n "$invoke_line" \
      && "$doc_line" -lt "$cover_line" && "$cover_line" -lt "$invoke_line" ]]; then
      pass "${template} renders the image page inside the document body, before the title page"
    else
      fail "${template} must render the image page inside the document body, before the title page"
    fi
  done

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_render_pdf_cover_render_test() {
  local sandbox elsewhere out pdf
  for tool in pandoc xelatex pdftotext pdfinfo; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "SKIP pdf cover render ($tool not available)"
      return 0
    fi
  done

  sandbox="$(new_contract_sandbox)"
  elsewhere="$(mktemp -d)"
  out="$(mktemp)"
  mkdir -p "${sandbox}/work/templates" "${sandbox}/work/assets"
  cp "${ROOT_DIR}/templates/default.tex" "${sandbox}/work/templates/default.tex"
  cp "${ROOT_DIR}/templates/book.tex" "${sandbox}/work/templates/book.tex"
  write_cover_png "${sandbox}/work/assets/cover.png"

  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  # Rendered from an unrelated working directory: a relative cover-image and a
  # relative template must both resolve against project.base_dir.
  cat >"${sandbox}/cover.config.yaml" <<'CONFIG'
version: 1

project:
  name: cover-render
  base_dir: ./work

document:
  title: "Cover Doc"
  author: "Cover Author"
  metadata:
    cover-image: "assets/cover.png"

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"
  keep_merged_markdown: true

pandoc:
  pdf_engine: xelatex
  toc: false
  toc_depth: 2
  number_sections: false
  resource_path:
    - "chapters"
  template: "templates/default.tex"

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
CONFIG

  if (cd "$elsewhere" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/cover.config.yaml" >"$out" 2>&1); then
    pass "render writes a PDF with a cover image from an unrelated working directory"
  else
    fail "render should write a PDF with a cover image from an unrelated working directory ($(tail -3 "$out"))"
  fi

  pdf="${sandbox}/work/out/cover-doc-manual.pdf"
  assert_file_exists "$pdf" "the render produced the PDF"

  local pages
  pages="$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/ {print $2}')"
  if [[ "$pages" == "3" ]]; then
    pass "cover page, title page and content give three pages (pages=${pages})"
  else
    fail "the cover PDF must have three pages (cover, title, content), got pages=${pages}"
  fi

  if [[ -z "$(pdftotext -f 1 -l 1 "$pdf" - 2>/dev/null | tr -d '[:space:]')" ]]; then
    pass "page 1 is the image cover (no extractable text)"
  else
    fail "page 1 must be the image cover with no extractable text ($(pdftotext -f 1 -l 1 "$pdf" - 2>/dev/null | head -3))"
  fi

  if pdftotext -f 2 -l 2 "$pdf" - 2>/dev/null | grep -q "Cover Doc"; then
    pass "page 2 is the typographic title page"
  else
    fail "page 2 must be the typographic title page ($(pdftotext -f 2 -l 2 "$pdf" - 2>/dev/null | head -3))"
  fi

  # A cover is not a title page: it prints even with titlepage: false.
  sed 's/  title: "Cover Doc"/  title: "Cover Doc"\n  titlepage: false/' \
    "${sandbox}/cover.config.yaml" >"${sandbox}/notitle.config.yaml"
  if (cd "$elsewhere" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/notitle.config.yaml" >"$out" 2>&1); then
    pass "render writes a PDF with a cover image and titlepage: false"
  else
    fail "render should write a PDF with a cover image and titlepage: false ($(tail -3 "$out"))"
  fi

  pages="$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/ {print $2}')"
  if [[ "$pages" == "2" ]]; then
    pass "with titlepage: false the image and the content give two pages (pages=${pages})"
  else
    fail "with titlepage: false the PDF must have two pages (cover, content), got pages=${pages}"
  fi

  if [[ -z "$(pdftotext -f 1 -l 1 "$pdf" - 2>/dev/null | tr -d '[:space:]')" ]]; then
    pass "with titlepage: false page 1 is still the image cover"
  else
    fail "with titlepage: false page 1 must still be the image cover ($(pdftotext -f 1 -l 1 "$pdf" - 2>/dev/null | head -3))"
  fi

  if pdftotext -f 2 -l 2 "$pdf" - 2>/dev/null | grep -q "Chapter One" \
    && ! pdftotext -f 2 -l 2 "$pdf" - 2>/dev/null | grep -q "Cover Author"; then
    pass "with titlepage: false no typeset title page follows the cover"
  else
    fail "with titlepage: false page 2 must be the content with no typeset title page ($(pdftotext -f 2 -l 2 "$pdf" - 2>/dev/null | head -3))"
  fi

  # Previous behavior, pinned: without cover-image the title page opens the PDF.
  cat >"${sandbox}/plain.config.yaml" <<'CONFIG'
version: 1

project:
  name: plain-render
  base_dir: ./work

document:
  title: "Cover Doc"
  author: "Cover Author"

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  dir: "out"
  suffix: "manual"
  keep_merged_markdown: true

pandoc:
  pdf_engine: xelatex
  toc: false
  toc_depth: 2
  number_sections: false
  resource_path:
    - "chapters"
  template: "templates/default.tex"

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
CONFIG

  if (cd "$elsewhere" && "${sandbox}/bin/pandoc-pdf" render -c "${sandbox}/plain.config.yaml" >"$out" 2>&1); then
    pass "render succeeds without cover-image"
  else
    fail "render should succeed without cover-image ($(tail -3 "$out"))"
  fi

  pages="$(pdfinfo "$pdf" 2>/dev/null | awk '/^Pages:/ {print $2}')"
  if [[ "$pages" == "2" ]]; then
    pass "without cover-image the PDF keeps title page and content (pages=${pages})"
  else
    fail "without cover-image the PDF must keep two pages, got pages=${pages}"
  fi

  if pdftotext -f 1 -l 1 "$pdf" - 2>/dev/null | grep -q "Cover Doc"; then
    pass "without cover-image page 1 is the typographic title page, as before"
  else
    fail "without cover-image page 1 must stay the typographic title page ($(pdftotext -f 1 -l 1 "$pdf" - 2>/dev/null | head -3))"
  fi

  rm -rf "$sandbox" "$elsewhere"
  rm -f "$out"
}
