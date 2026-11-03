#!/usr/bin/env bash
# build.sh - glue step for the book example.
#
# Reads the content-only manifest.yaml, generates pdf.config.yaml from it and
# renders through the public CLI (bin/pandoc-pdf render). This script belongs
# to the book, not to the toolkit: it is the tiny generator-specific step that
# turns a content manifest into a toolkit configuration.
#
# The manifest is read with python3 + PyYAML when available, exactly like the
# toolkit's own YAML handling; otherwise it falls back to Ruby's stdlib YAML.
# There is no hand-rolled parser fallback: without either parser the build
# fails with a clear message.
#
# Runs from any working directory; contains no absolute or machine-specific
# paths. Output goes to examples/.output/book/ (gitignored).

set -euo pipefail

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)

MANIFEST="$SCRIPT_DIR/manifest.yaml"
CONFIG="$SCRIPT_DIR/pdf.config.yaml"
CLI="$SCRIPT_DIR/../../bin/pandoc-pdf"

[ -f "$MANIFEST" ] || {
    echo "build.sh: manifest not found: $MANIFEST" >&2
    exit 1
}
[ -f "$CLI" ] || {
    echo "build.sh: pandoc-pdf CLI not found: $CLI" >&2
    exit 1
}

# The generated configuration is identical whichever parser reads the
# manifest: both emitters build the same canonical text from the same fields.
{
    if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
        python3 - "$MANIFEST" <<'PY'
import sys

try:
    import yaml
except Exception:
    sys.stderr.write("build.sh: PyYAML is not importable\n")
    raise SystemExit(3)


def q(value):
    text = str(value)
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"') + '"'


def fail(message):
    sys.stderr.write("build.sh: " + message + "\n")
    raise SystemExit(1)


with open(sys.argv[1], encoding="utf-8") as handle:
    manifest = yaml.safe_load(handle)

if not isinstance(manifest, dict):
    fail("manifest root must be a mapping")

for field in ("title", "author", "language", "front_matter", "chapters", "back_matter"):
    if field not in manifest:
        fail("manifest is missing required field: " + field)

chapters = manifest["chapters"]
if isinstance(chapters, dict):
    if not chapters.get("ordered"):
        fail("chapters mapping must set 'ordered: true'")
    chapters = chapters.get("files")
if not isinstance(chapters, list) or not chapters:
    fail("chapters must be a non-empty ordered list")

reading_order = (
    list(manifest["front_matter"])
    + list(chapters)
    + list(manifest["back_matter"])
)

metadata = ""
description = str(manifest.get("description") or "").strip()
if description:
    lines = []
    current = ""
    for word in description.split():
        if not current:
            current = word
        elif len(current) + 1 + len(word) <= 72:
            current += " " + word
        else:
            lines.append(current)
            current = word
    if current:
        lines.append(current)
    metadata = "  metadata:\n    subject: >-\n" + "".join(
        "      " + line + "\n" for line in lines
    )

config = """version: 1

project:
  name: lighthouse-keeper-book
  base_dir: "."

document:
  title: {title}
  subtitle: {subtitle}
  author: {author}
  publisher: "Example Editions"
  date: "2026"
  rights: "CC0 1.0 Universal - public domain dedication"
  language: {language}
  titlepage: true
{metadata}
input:
  chapters_dir: "content"
  glob: "*.md"
  order: natural
  explicit_files:
{files}
output:
  formats: [pdf]
  dir: "../.output/book"
  file_prefix: "the-lighthouse-keeper"
  suffix: "${{date:YYYYMMDD}}"
  keep_merged_markdown: false

pandoc:
  pdf_engine: xelatex
  toc: true
  toc_depth: 2
  number_sections: true
  template: "templates/book.tex"
  resource_path:
    - "content"

filters:
  emoji:
    enabled: false
  mermaid:
    enabled: false
  extra_lua_filters: []

runtime:
  required_commands:
    - pandoc
    - xelatex
    - python3
  strict: true
"""

sys.stdout.write(config.format(
    title=q(manifest["title"]),
    subtitle=q(manifest.get("subtitle") or ""),
    author=q(manifest["author"]),
    language=q(manifest["language"]),
    metadata=metadata,
    files="".join("    - " + q(path) + "\n" for path in reading_order),
))
PY
    elif command -v ruby >/dev/null 2>&1; then
        ruby -ryaml - "$MANIFEST" <<'RB'
def q(value)
  '"' + value.to_s.gsub('\\') { '\\\\' }.gsub('"', '\\"') + '"'
end

def fail(message)
  warn 'build.sh: ' + message
  exit 1
end

begin
  manifest = YAML.safe_load(File.read(ARGV[0]), permitted_classes: [], aliases: false)
rescue StandardError => e
  fail 'could not parse manifest: ' + e.message
end

fail 'manifest root must be a mapping' unless manifest.is_a?(Hash)

%w[title author language front_matter chapters back_matter].each do |field|
  fail "manifest is missing required field: #{field}" unless manifest.key?(field)
end

chapters = manifest['chapters']
if chapters.is_a?(Hash)
  fail "chapters mapping must set 'ordered: true'" unless chapters['ordered']
  chapters = chapters['files']
end
fail 'chapters must be a non-empty ordered list' unless chapters.is_a?(Array) && !chapters.empty?

reading_order = manifest['front_matter'] + chapters + manifest['back_matter']

description = manifest['description'].to_s.strip
lines = []
current = ''
description.split.each do |word|
  if current.empty?
    current = word
  elsif current.length + 1 + word.length <= 72
    current += ' ' + word
  else
    lines << current
    current = word
  end
end
lines << current unless current.empty?
metadata = lines.empty? ? '' : "  metadata:\n    subject: >-\n" + lines.map { |line| "      #{line}\n" }.join

files = reading_order.map { |path| "    - #{q(path)}\n" }.join

config = <<~CONFIG
  version: 1

  project:
    name: lighthouse-keeper-book
    base_dir: "."

  document:
    title: #{q(manifest['title'])}
    subtitle: #{q(manifest['subtitle'])}
    author: #{q(manifest['author'])}
    publisher: "Example Editions"
    date: "2026"
    rights: "CC0 1.0 Universal - public domain dedication"
    language: #{q(manifest['language'])}
    titlepage: true
  #{metadata}
  input:
    chapters_dir: "content"
    glob: "*.md"
    order: natural
    explicit_files:
  #{files}
  output:
    formats: [pdf]
    dir: "../.output/book"
    file_prefix: "the-lighthouse-keeper"
    suffix: "${date:YYYYMMDD}"
    keep_merged_markdown: false

  pandoc:
    pdf_engine: xelatex
    toc: true
    toc_depth: 2
    number_sections: true
    template: "templates/book.tex"
    resource_path:
      - "content"

  filters:
    emoji:
      enabled: false
    mermaid:
      enabled: false
    extra_lua_filters: []

  runtime:
    required_commands:
      - pandoc
      - xelatex
      - python3
    strict: true
CONFIG

print config
RB
    else
        echo "build.sh: no YAML parser available: install PyYAML (python3 -m pip install pyyaml) or a Ruby with stdlib YAML" >&2
        exit 1
    fi
} > "$CONFIG"

"$CLI" render -c "$CONFIG"
