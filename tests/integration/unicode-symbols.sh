#!/usr/bin/env bash
# Functional verification for the D14 glyph-only symbol fallback (#83).
#
# Full matrix: prose, inline code, untagged fenced code and highlighted fenced
# code. Fenced code obeys the same six glyph mappings because the six characters
# stay active inside fancyvrb's `Verbatim`/`Highlighting` environments — nothing
# is reactivated explicitly — and without the font the code degrades with the
# rest.
#
# This script is OPTIONAL and is not part of `make gate`: it needs a real
# Pandoc, a TeX engine, pdftotext and pdffonts. It renders through the public
# CLI (`bin/pandoc-pdf render`) and checks the observed effects:
#
#   1. all six symbols (☐ ☑ ☒ ✅ ❌ ⚠) appear in prose, inline code, untagged
#      fenced code and highlighted fenced code, with the emoji filter disabled,
#      and the text surrounding each glyph is intact (exact expected sentences
#      survive extraction, nothing is swallowed);
#   2. the emoji presentation sequence ⚠️ renders in prose and inline code as
#      its base symbol; a failing selector lookahead would surface as a
#      U+FE0F Missing-character warning, which is rejected;
#   3. no Missing-character warning exists for any covered glyph or for FE0F
#      anywhere in the render (the covered glyphs now appear in every context,
#      fenced code included, so any such warning is a failure), while the
#      unsupported control 🔍 still warns: warnings are never suppressed;
#   4. FreeSerif is embedded and the ordinary prose/mono fonts are unchanged,
#      and nothing is rasterized (no image XObjects in the PDF);
#   5. without the font, rendering degrades to the previous behavior: exit 0,
#      Missing-character warnings retained, no FreeSerif embedded;
#   6. EPUB is isolated: the publication keeps the exact Unicode sequences,
#      and when the caller provides a pre-change template snapshot through
#      UNICODE_SYMBOLS_BASE_TEMPLATE, every EPUB member is compared against a
#      baseline-template render, allowing only generated UUID/timestamps.
#   7. hard edges inside code: a fenced block whose first character is a mapped
#      symbol, the adjacency ☑☐, a mapped symbol followed by a backslash or a
#      brace, string literals and comments ending with the ⚠️ sequence.
#
# Engine selection is the caller's choice via UNICODE_SYMBOLS_ENGINE (default
# xelatex); any engine environment (HOME, TMPDIR, TEXMFVAR) is honored as set
# by the caller and never manipulated here. Everything generated lands in a
# fresh per-run directory under examples/.output/unicode-font-u1/, whose path
# is printed.
set -euo pipefail

path_dirname() {
  local p="$1"
  if [[ "$p" == */* ]]; then
    printf '%s\n' "${p%/*}"
  else
    printf '.\n'
  fi
}

SCRIPT_DIR="$(cd -- "$(path_dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
CLI="${ROOT_DIR}/bin/pandoc-pdf"
OUT="${ROOT_DIR}/examples/.output/unicode-font-u1"
ENGINE="${UNICODE_SYMBOLS_ENGINE:-xelatex}"

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf '❌ Missing required command: %s\n' "$1"
    exit 1
  fi
}

fail() {
  printf '❌ %s\n' "$1"
  exit 1
}

require_cmd pandoc
require_cmd pdftotext
require_cmd pdffonts
require_cmd python3
require_cmd unzip
require_cmd "$ENGINE"

# Fresh per-run directory: never reuse or delete a previous run's output.
RUN_ID="$(date +%Y%m%d-%H%M%S)-$$"
RUN_DIR="${OUT}/run-${RUN_ID}"
FIXTURE="${RUN_DIR}/fixture"
mkdir -p "${FIXTURE}/chapters" "${FIXTURE}/templates"

printf '== Unicode symbol fallback: all four contexts (%s) ==\n' "$ENGINE"
printf 'run directory: %s\n' "$RUN_DIR"

# The fixture exercises the six symbols in all four contexts: prose, inline
# code, untagged fenced code and highlighted fenced code. Ordinary letters stay
# adjacent so the surrounding fonts stay visible, and 🔍 (U+1F50D) is carried
# only as an unsupported-character diagnostic control (S3): no font covers it
# and its warning must survive.
cat >"${FIXTURE}/chapters/01-symbols.md" <<'EOF'
# Symbol fallback verification

SECTION-PROSE pending ☐, done ☑, cancelled ☒, success ✅, failure ❌, warning ⚠
and the sequence ⚠️, next to ordinary words (☐) and punctuation.

SECTION-INLINE The command `run ☐☑☒✅❌⚠ now` stays monospaced, and
`report ⚠️ here` keeps the warning sequence inline too.

SECTION-UNTAGGED

```
untagged code ☐☑☒✅❌⚠ and ⚠️ a=b
```

SECTION-HIGHLIGHTED

```python
# highlighted code ☐☑☒✅❌⚠ and ⚠️
print("hello")
```

SECTION-HARD

```
☐ first character of the fenced block
untagged line ends with the warning sequence ⚠️
☑\path and ☒{x} with the adjacency ☑☐
```

```python
# highlighted comment ends with the warning sequence ⚠️
print("string literal ☐ ☑ ✅ end")
```

SECTION-END A control character no font covers for diagnostics: 🔍.
EOF

# The runs exercise the current production template, copied fresh each run.
cp "${ROOT_DIR}/templates/default.tex" "${FIXTURE}/templates/default.tex"

write_pdf_config() {
  local path="$1" prefix="$2" template="$3"
  cat >"$path" <<EOF
version: 1

project:
  name: unicode-symbols-u1
  base_dir: "."

document:
  title: "Symbol Fallback Verification"
  language: "en"
  titlepage: false

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  formats: [pdf]
  dir: "out"
  file_prefix: "${prefix}"
  suffix: "u1"
  keep_merged_markdown: true

pandoc:
  pdf_engine: "${ENGINE}"
  toc: false
  toc_depth: 2
  number_sections: false
  template: "${template}"
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
    - "${ENGINE}"
    - python3
  strict: true
EOF
}

write_epub_config() {
  local path="$1" prefix="$2" template="$3"
  cat >"$path" <<EOF
version: 1

project:
  name: unicode-symbols-u1
  base_dir: "."

document:
  title: "Symbol Fallback Verification"
  language: "en"
  titlepage: false

input:
  chapters_dir: "chapters"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  formats: [epub]
  dir: "out"
  file_prefix: "${prefix}"
  suffix: "u1"
  keep_merged_markdown: true

pandoc:
  pdf_engine: "${ENGINE}"
  toc: false
  toc_depth: 2
  number_sections: false
  template: "${template}"
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
    - python3
  strict: true
EOF
}

render() {
  local config="$1" log="$2"
  local code=0
  "$CLI" render -c "$config" >"$log" 2>&1 || code=$?
  printf '%s' "$code"
}

# --- 1) Supported-font run: the prose and inline matrix ----------------------
write_pdf_config "${FIXTURE}/pdf.config.yaml" "symbols" "templates/default.tex"
code="$(render "${FIXTURE}/pdf.config.yaml" "${RUN_DIR}/render-symbols.log")"
[[ "$code" == "0" ]] || fail "supported-font render exited ${code} (log: ${RUN_DIR}/render-symbols.log)"

local_pdf="${FIXTURE}/out/symbols-u1.pdf"
[[ -f "$local_pdf" ]] || fail "supported-font render produced no PDF"

pdftotext "$local_pdf" "${RUN_DIR}/symbols.txt"
pdffonts "$local_pdf" >"${RUN_DIR}/symbols.pdffonts.txt"

python3 - "${RUN_DIR}/symbols.txt" <<'PY' || fail "prose/inline content check failed (see ${RUN_DIR}/symbols.txt)"
import sys

text = " ".join(open(sys.argv[1], encoding="utf-8").read().split())
symbols = ["☐", "☑", "☒", "✅", "❌", "⚠"]
markers = ["SECTION-PROSE", "SECTION-INLINE", "SECTION-UNTAGGED", "SECTION-HIGHLIGHTED", "SECTION-HARD", "SECTION-END"]
positions = []
for marker in markers:
    index = text.find(marker)
    assert index >= 0, f"marker {marker} not found in extraction"
    positions.append(index)

regions = dict(zip(markers[:-1], zip(positions[:-1], positions[1:])))

# Exact expected sentences: presence alone could hide swallowed characters or
# spaces, so the full surrounding content must survive extraction. ⚠️ extracts
# as its base symbol ⚠ (the selector is not a glyph); that limitation is
# documented, not claimed away.
expected_sentences = {
    "SECTION-PROSE":
        "pending ☐, done ☑, cancelled ☒, success ✅, failure ❌, warning ⚠ "
        "and the sequence ⚠, next to ordinary words (☐) and punctuation.",
    "SECTION-INLINE":
        "The command run ☐☑☒✅❌⚠ now stays monospaced, and report ⚠ here "
        "keeps the warning sequence inline too.",
    "SECTION-UNTAGGED":
        "untagged code ☐☑☒✅❌⚠ and ⚠ a=b",
    "SECTION-HIGHLIGHTED":
        "# highlighted code ☐☑☒✅❌⚠ and ⚠ print(\"hello\")",
}
for context, sentence in expected_sentences.items():
    assert sentence in text, f"{context}: expected sentence lost or altered"
    region = text[regions[context][0]:regions[context][1]]
    missing = [s for s in symbols if s not in region]
    assert not missing, f"{context}: missing symbols {missing}"

# Fenced code stays code: the surrounding ASCII of both blocks survives verbatim,
# so reactivation never turns the block into prose.
assert "a=b" in text[regions["SECTION-UNTAGGED"][0]:regions["SECTION-UNTAGGED"][1]], \
    "untagged fenced block lost its ASCII content"
assert 'print("hello")' in text, "highlighted fenced block lost its code content"

# Hard edges inside code, asserted on the normalized extraction: a fenced block
# whose first character is ☐, the adjacency ☑☐, a mapped symbol followed by a
# backslash or a brace, a python string literal with symbols, and comments and
# lines ending with the ⚠️ sequence (which extracts as its base symbol ⚠).
hard = text[regions["SECTION-HARD"][0]:regions["SECTION-HARD"][1]]
for fragment in [
    "☐ first character of the fenced block",
    "warning sequence ⚠",
    "☑\\path",
    "☒{x}",
    "☑☐",
    'print("string literal ☐ ☑ ✅ end")',
    "highlighted comment ends with the warning sequence ⚠",
]:
    assert fragment in hard, f"hard edge lost or altered: {fragment}"
print("all six symbols intact in prose, inline and both fenced-code contexts")
print("hard edges intact: first-char symbol, adjacency, backslash, brace, string literal, trailing ⚠")
PY

# Warnings are never suppressed, and no covered glyph may warn: the six
# symbols and the ⚠️ sequence now appear in every context, fenced code included,
# so any Missing-character diagnostic for them (or for FE0F, which would mean
# the selector lookahead failed) is a regression, while 🔍 must still warn.
covered_warning_re='☐|☑|☒|✅|❌|⚠|FE0F'
if grep "Missing character" "${RUN_DIR}/render-symbols.log" | grep -qE "${covered_warning_re}"; then
  fail "a covered glyph or FE0F produced a Missing-character warning (log: ${RUN_DIR}/render-symbols.log)"
fi
grep -q "Missing character" "${RUN_DIR}/render-symbols.log" \
  || fail "the unsupported-character diagnostic (🔍) was suppressed"
grep -qE "🔍|1F50D" "${RUN_DIR}/render-symbols.log" \
  || fail "the Missing-character warning does not identify 🔍 (U+1F50D)"

# Nothing may be rasterized: the fallback maps glyphs, it never substitutes
# images. Checked at the PDF level (no image XObjects), and the pandoc argv
# recorded in the render log must not contain an emoji lua filter.
if command -v pdfimages >/dev/null 2>&1; then
  image_rows="$(pdfimages -list "$local_pdf" | tail -n +3 | wc -l | tr -d ' ')"
  [[ "$image_rows" == "0" ]] || fail "the PDF contains ${image_rows} image objects; the fallback must not rasterize"
fi
if grep -qE -- "--lua-filter=[^ ]*emoji" "${RUN_DIR}/render-symbols.log"; then
  fail "the render log's pandoc invocation contains an emoji lua filter"
fi

grep -q "FreeSerif" "${RUN_DIR}/symbols.pdffonts.txt" \
  || fail "FreeSerif is not embedded in the supported-font PDF"
grep -qE "Pagella|Times New Roman|Latin Modern" "${RUN_DIR}/symbols.pdffonts.txt" \
  || fail "the ordinary prose font disappeared"
grep -qE "Mono" "${RUN_DIR}/symbols.pdffonts.txt" \
  || fail "the ordinary mono font disappeared"
printf 'fonts: FreeSerif embedded, ordinary prose/mono fonts preserved, no rasterization\n'
printf 'warnings: 🔍 retained, none for covered glyphs or FE0F\n'

# --- 2) Absent-font run: degradation to the previous behavior ----------------
sed -e 's/FreeSerif\.ttf/unicode-u1-absent.ttf/g' \
    -e 's/{FreeSerif}/{Unicode U1 Absent Font}/g' \
    "${ROOT_DIR}/templates/default.tex" >"${FIXTURE}/templates/absent.tex"
write_pdf_config "${FIXTURE}/pdf.absent.config.yaml" "absent" "templates/absent.tex"
code="$(render "${FIXTURE}/pdf.absent.config.yaml" "${RUN_DIR}/render-absent.log")"
[[ "$code" == "0" ]] || fail "absent-font render exited ${code} (log: ${RUN_DIR}/render-absent.log)"

local_absent="${FIXTURE}/out/absent-u1.pdf"
[[ -f "$local_absent" ]] || fail "absent-font render produced no PDF"
pdffonts "$local_absent" >"${RUN_DIR}/absent.pdffonts.txt"
if grep -q "FreeSerif" "${RUN_DIR}/absent.pdffonts.txt"; then
  fail "FreeSerif must not be embedded when the font is absent"
fi
grep -q "Missing character" "${RUN_DIR}/render-absent.log" \
  || fail "absent-font run must retain the Missing-character diagnostics"
printf 'absent font: renders with baseline behavior and retained warnings\n'

# --- 3) EPUB isolation -------------------------------------------------------
# The publication must keep the exact Unicode sequences...
write_epub_config "${FIXTURE}/epub.config.yaml" "symbols" "templates/default.tex"
code="$(render "${FIXTURE}/epub.config.yaml" "${RUN_DIR}/render-epub.log")"
[[ "$code" == "0" ]] || fail "epub render exited ${code} (log: ${RUN_DIR}/render-epub.log)"

local_epub="${FIXTURE}/out/symbols-u1.epub"
[[ -f "$local_epub" ]] || fail "epub render produced no publication"

# ...and, when the caller supplies a pre-change template snapshot, every EPUB
# member must equal the baseline-template render byte for byte, with only the
# generated UUID and timestamps normalized.
if [[ -n "${UNICODE_SYMBOLS_BASE_TEMPLATE:-}" ]]; then
  [[ -f "${UNICODE_SYMBOLS_BASE_TEMPLATE}" ]] \
    || fail "UNICODE_SYMBOLS_BASE_TEMPLATE is set but the file does not exist: ${UNICODE_SYMBOLS_BASE_TEMPLATE}"
  cp "${UNICODE_SYMBOLS_BASE_TEMPLATE}" "${FIXTURE}/templates/baseline.tex"
  write_epub_config "${FIXTURE}/epub.baseline.config.yaml" "baseline" "templates/baseline.tex"
  code="$(render "${FIXTURE}/epub.baseline.config.yaml" "${RUN_DIR}/render-epub-baseline.log")"
  [[ "$code" == "0" ]] || fail "baseline epub render exited ${code} (log: ${RUN_DIR}/render-epub-baseline.log)"
  baseline_epub="${FIXTURE}/out/baseline-u1.epub"
  [[ -f "$baseline_epub" ]] || fail "baseline epub render produced no publication"

  python3 - "$local_epub" "$baseline_epub" <<'PY' || fail "EPUB member equality against the pre-change template failed"
import re
import subprocess
import sys

UUID_RE = re.compile(r"urn:uuid:[0-9a-fA-F-]+")
DC_DATE_RE = re.compile(r"(<dc:date(?:\s[^>]*)?>)[^<]*(</dc:date>)")
MODIFIED_RE = re.compile(r'(<meta\s+property="dcterms:modified"\s*>)[^<]*(</meta>)')

def members(epub):
    names = subprocess.run(
        ["unzip", "-Z1", epub], capture_output=True, text=True, check=True
    ).stdout.split()
    out = {}
    for name in names:
        data = subprocess.run(["unzip", "-p", epub, name], capture_output=True, check=True).stdout
        text = data.decode("utf-8", errors="surrogateescape")
        text = UUID_RE.sub("urn:uuid:NORMALIZED", text)
        text = DC_DATE_RE.sub(r"\1NORMALIZED\2", text)
        text = MODIFIED_RE.sub(r"\1NORMALIZED\2", text)
        out[name] = text.encode("utf-8", errors="surrogateescape")
    return out

current = members(sys.argv[1])
baseline = members(sys.argv[2])
assert set(current) == set(baseline), (
    f"EPUB member sets differ: {set(current) ^ set(baseline)}"
)
different = sorted(name for name in current if current[name] != baseline[name])
assert not different, f"EPUB members differ beyond UUID/timestamps: {different}"
print(f"all {len(current)} EPUB members equal to the pre-change-template render")
PY
else
  printf 'note: UNICODE_SYMBOLS_BASE_TEMPLATE not set; skipping the EPUB member-equality comparison\n'
fi

python3 - "$local_epub" <<'PY' || fail "EPUB isolation check failed"
import subprocess
import sys

sequences = ["☐", "☑", "☒", "✅", "❌", "⚠️"]
names = subprocess.run(
    ["unzip", "-Z1", sys.argv[1]], capture_output=True, text=True, check=True
).stdout.split()
body = "".join(
    subprocess.run(["unzip", "-p", sys.argv[1], name], capture_output=True, text=True).stdout
    for name in names if name.endswith((".xhtml", ".html", ".ncx", ".opf"))
)
missing = [s for s in sequences if s not in body]
assert not missing, f"EPUB lost sequences: {missing}"
print("EPUB keeps the exact Unicode sequences, including ⚠️ with U+FE0F")
PY

printf '✅ unicode symbol fallback verification passed (%s)\n' "$ENGINE"
printf 'artifacts: %s\n' "$RUN_DIR"
