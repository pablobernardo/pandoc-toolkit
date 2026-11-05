#!/bin/bash
# Shared fixtures for the EPUB area: sandboxes and configuration writers.
# Sourced by tests/run.sh (not run standalone).

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

  write_epub_resource_config "${sandbox}/skelepress.config.yaml"
  printf '%s\n' "$sandbox"
}

new_epub_document_metadata_sandbox() {
  local sandbox
  sandbox="$(new_epub_resource_sandbox)"
  # The same project, with the cover declared through document.metadata instead
  # of a metadata file: the two routes must behave the same.
  "${REAL_PYTHON3}" - "${sandbox}/skelepress.config.yaml" <<'PY'
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
