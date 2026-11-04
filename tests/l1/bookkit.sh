#!/bin/bash
# bookkit area tests. Sourced by tests/run.sh (not run standalone).
#
# The shipped tool (scripts/tools/bookkit/build.py) and its contract, checked
# through its public interface only. No PDF renders here: --check validates the
# manifests and emits the generated configurations, which is what L1 asserts.

run_bookkit_tests() {
  local tool="${ROOT_DIR}/scripts/tools/bookkit/build.py"
  local single="${ROOT_DIR}/examples/book-kit/single"
  local series="${ROOT_DIR}/examples/book-kit/series"
  local scratch out code

  scratch="$(mktemp -d)"

  # The tool's default template is the builtin name `book`, which the toolkit
  # ships, so a project needs no template of its own. The fixture projects keep
  # a copy only for the explicit --template assertion.
  local single_fix="$scratch/single"
  local series_fix="$scratch/series"
  cp -R "$single" "$single_fix"
  cp -R "$series" "$series_fix"
  mkdir -p "$single_fix/templates" "$series_fix/templates"
  printf '%s\n' '\documentclass{book}' '\begin{document}' '$body$' '\end{document}' \
    >"$single_fix/templates/book.tex"
  cp "$single_fix/templates/book.tex" "$series_fix/templates/book.tex"

  # --- Both canonical manifests validate through --check ------------------

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-single" "$single_fix" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "bookkit --check passes for the single-volume project"
  assert_contains "$out" "Check ok: 1 volume" "bookkit --check reports the planned volume"
  if [[ -f "$scratch/out-single/single/pdf.config.yaml" ]]; then
    pass "bookkit --check emits the generated configuration"
    assert_contains "$scratch/out-single/single/pdf.config.yaml" 'template: "book"' \
      "the default template is the builtin name, not a project path"
    assert_contains "$scratch/out-single/single/pdf.config.yaml" 'top_level_division: chapter' \
      "a book project asks pandoc for chapters, since templates/book.tex no longer shifts headings"
  else
    fail "bookkit --check must emit the generated configuration"
  fi
  rm -f "$out"

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-series" "$series_fix" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "bookkit --check passes for the series (an optional missing file still plans)"
  assert_contains "$out" "Check ok: 2 volume" "bookkit --check reports both series volumes"
  rm -f "$out"

  # --- A missing required field fails naming the field --------------------

  local broken="$scratch/missing-field"
  cp -R "$single_fix" "$broken"
  grep -v '^title:' "$broken/manifest.yaml" >"$broken/manifest.yaml.tmp"
  mv "$broken/manifest.yaml.tmp" "$broken/manifest.yaml"

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-broken" "$broken" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "bookkit --check fails when a required field is missing"
  assert_contains "$out" "required fields are missing: title" "the failure names the missing field"
  rm -f "$out"

  # --- An unknown profile fails -------------------------------------------

  local novel="$scratch/unknown-profile"
  cp -R "$single_fix" "$novel"
  sed 's/^profile: book$/profile: novel/' "$novel/manifest.yaml" >"$novel/manifest.yaml.tmp"
  mv "$novel/manifest.yaml.tmp" "$novel/manifest.yaml"

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-novel" "$novel" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "bookkit --check fails on an unknown profile"
  assert_contains "$out" "'profile' must be one of: book" "the failure names the profile and the allowed value"
  rm -f "$out"

  # --- An entry missing its file fails naming volume, logical name, path --

  local lost="$scratch/missing-entry"
  cp -R "$single_fix" "$lost"
  sed 's|chapters/01-clouds\.md|chapters/99-missing.md|' "$lost/manifest.yaml" >"$lost/manifest.yaml.tmp"
  mv "$lost/manifest.yaml.tmp" "$lost/manifest.yaml"

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-lost" "$lost" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "bookkit --check fails when a declared entry file is missing"
  assert_contains "$out" "volume 'missing-entry': chapters entry '1' declares a missing file: chapters/99-missing\.md" \
    "the failure names the volume, the logical name and the path"
  rm -f "$out"

  # --- optional: true with an absent file is skipped with a warning -------

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-optional" "$series_fix" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "an optional entry with an absent file does not fail the plan"
  assert_contains "$out" "volume 'volume-2': back_matter entry 'excerpt' is optional and its file was not found, skipped: back-matter/99-excerpt\.md" \
    "the optional skip names the volume, the entry and the path"
  if [[ -f "$scratch/out-optional/series/volume-2/pdf.config.yaml" ]]; then
    pass "the volume with the optional absent file still plans"
  else
    fail "the volume with an optional absent file must still plan"
  fi
  rm -f "$out"

  # --- print: false is excluded from the generated configuration ----------

  local v1config="$scratch/out-series/series/volume-1/pdf.config.yaml"
  if [[ -f "$v1config" ]]; then
    if grep -q "review-request" "$v1config"; then
      fail "a print: false entry must be excluded from the generated configuration"
    else
      pass "a print: false entry is excluded from the generated configuration"
    fi
    assert_contains "$v1config" "back-matter/01-glossary\.md" \
      "printable entries stay in the generated configuration"
  else
    fail "the series volume-1 configuration must exist for the print: false assertion"
  fi

  # --- toc: false keeps a page out of the contents ------------------------

  if [[ -f "$v1config" ]]; then
    assert_contains "$v1config" "toc-off" "an entry with toc: false gets the switch that hides it"
    assert_contains "$scratch/out-series/series/volume-1/generated/10-toc-off.md" 'BookChaptersUnlisted' \
      "the hide switch calls the template command"
    assert_contains "$scratch/out-series/series/volume-1/generated/11-toc-on.md" 'BookChaptersListed' \
      "the switch is turned back on right after the entry"
    if python3 - "$v1config" <<'PY'
import sys

order = [
    line.strip()
    for line in open(sys.argv[1], encoding="utf-8").read().splitlines()
    if line.strip().startswith("- ")
]


def position(fragment: str) -> int:
    return next(index for index, line in enumerate(order) if fragment in line)


assert position("toc-off") < position("00-dedication") < position("toc-on") < position("01-the-two-lights")
PY
    then
      pass "the unlisted entry is wrapped, and the listed one after it is not"
    else
      fail "toc: false must wrap only its own entry, before the listed one"
    fi
  else
    fail "volume-1 configuration must exist for the toc assertions"
  fi

  # --- chapter_start reaches the generated mode file ----------------------

  local v2mainmatter="$scratch/out-series/series/volume-2/generated/00-mainmatter.md"
  local v1mainmatter="$scratch/out-series/series/volume-1/generated/00-mainmatter.md"
  if [[ -f "$v2mainmatter" ]]; then
    assert_contains "$v2mainmatter" '\\setcounter\{chapter\}\{3\}' \
      "chapter_start: 4 sets the counter to 3 (the chapter command steps it)"
  else
    fail "volume-2 must have a generated mainmatter mode file"
  fi
  if [[ -f "$v1mainmatter" ]]; then
    if grep -q "setcounter" "$v1mainmatter"; then
      fail "a volume without chapter_start must not set the chapter counter"
    else
      pass "a volume without chapter_start emits a plain mainmatter"
    fi
  else
    fail "volume-1 must have a generated mainmatter mode file"
  fi

  # --- chapters: ordered resolves the folder in natural order -------------

  local ordered="$scratch/ordered"
  cp -R "$single_fix" "$ordered"
  cat >"$ordered/manifest.yaml" <<'YAML'
manifest_version: 1
profile: book
title: "Ordered Chapters Test"
chapters: ordered
YAML

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-ordered" "$ordered" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "the chapters: ordered keyword plans from chapters_dir"
  rm -f "$out"
  local orderedconfig="$scratch/out-ordered/ordered/pdf.config.yaml"
  if [[ -f "$orderedconfig" ]]; then
    assert_contains "$orderedconfig" "chapters/01-clouds\.md" "ordered picks up the first chapter"
    assert_contains "$orderedconfig" "chapters/03-rain\.md" "ordered picks up the last chapter"
  else
    fail "the ordered project must emit a generated configuration"
  fi

  # --- A project without a local templates/ still plans -------------------
  # The builtin name ships with the toolkit, so a project needs no template of
  # its own: that is what makes the generated configuration usable from an
  # installed CLI.

  local bare="$scratch/no-template"
  cp -R "$single" "$bare"   # the pristine example: no templates/ inside

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-bare" "$bare" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a project without its own template still plans"
  assert_contains "$scratch/out-bare/no-template/pdf.config.yaml" 'template: "book"' \
    "the generated configuration carries the builtin name"
  rm -f "$out"

  # --- An explicit relative --template still resolves ----------------------

  local relative="$scratch/explicit-relative"
  cp -R "$single" "$relative"
  mkdir -p "$relative/latex"
  cp "$single_fix/templates/book.tex" "$relative/latex/book-template.tex"

  out="$(mktemp)"
  set +e
  # Run from inside the project so the relative template is relative to it,
  # exactly the way an explicit --template has always been resolved.
  (cd "$relative" && python3 "$tool" --check --out "$scratch/out-relative" --template latex/book-template.tex .) >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "an explicit relative --template still resolves"
  rm -f "$out"

  # --- A symlinked project path still generates resolvable paths -----------
  # The output directory is resolved while a project path need not be. When the
  # two spellings differ (macOS reports /var/folders and resolves it to
  # /private/var/folders) a relative path built from one and applied to the other
  # points outside the tree, and the render then fails naming a plausible path.
  # Passing the project through a symlink reproduces that on any platform.

  local real_project="$scratch/real-project"
  local linked_project="$scratch/linked-project"
  cp -R "$single" "$real_project"
  ln -s "$real_project" "$linked_project"

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-linked" "$linked_project" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a symlinked project path still plans"
  # The resolved project name decides the output directory, so find the
  # configuration instead of assuming which spelling it uses.
  local linked_config
  linked_config="$(find "$scratch/out-linked" -name pdf.config.yaml | head -1)"
  if python3 - "$linked_config" <<'PY'
import re
import sys
from pathlib import Path

config = Path(sys.argv[1])
text = config.read_text(encoding="utf-8")
base = re.search(r'base_dir: "([^"]+)"', text).group(1)
entries = re.findall(r'^    - "([^"]+)"', text, re.M)
resolved_base = (config.parent / base).resolve()
missing = [entry for entry in entries if not (resolved_base / entry).exists()]
assert not missing, missing
PY
  then
    pass "every generated path resolves from the declared base_dir"
  else
    fail "generated paths must resolve from base_dir, even through a symlinked project"
  fi
  rm -f "$out"

  rm -rf "$scratch"
}

# `pandoc-pdf book` is the front door to the shipped tool: the same arguments,
# the same stdout and the same exit code as invoking build.py directly. No PDF
# renders here: --check exercises the whole forwarding path.
run_book_command_test() {
  local tool="${ROOT_DIR}/scripts/tools/bookkit/build.py"
  local single="${ROOT_DIR}/examples/book-kit/single"
  local scratch

  scratch="$(mktemp -d)"
  local proj="$scratch/single"
  cp -R "$single" "$proj"

  # --- --help lists the command -------------------------------------------

  local help_out
  help_out="$(mktemp)"
  "$CLI" --help >"$help_out" 2>&1
  assert_contains "$help_out" "pandoc-pdf book" "--help lists the book subcommand"
  rm -f "$help_out"

  # --- The subcommand matches the direct tool invocation ------------------

  local direct_out cli_out
  direct_out="$(mktemp)"
  cli_out="$(mktemp)"
  mkdir -p "$scratch/run-direct" "$scratch/run-cli"
  set +e
  (cd "$scratch/run-direct" && python3 "$tool" --check --out out "$proj") >"$direct_out" 2>&1
  local direct_code=$?
  (cd "$scratch/run-cli" && "$CLI" book --check --out out "$proj") >"$cli_out" 2>&1
  local cli_code=$?
  set -e
  assert_exit_code "0" "$direct_code" "the direct tool invocation passes for the example project"
  assert_exit_code "$direct_code" "$cli_code" "pandoc-pdf book exits with the tool's own exit code"
  if cmp -s "$direct_out" "$cli_out"; then
    pass "pandoc-pdf book prints exactly what the direct tool invocation prints"
  else
    fail "pandoc-pdf book must forward stdout unchanged to the tool"
  fi
  rm -f "$direct_out" "$cli_out"

  # --- A failing invocation still fails with the tool's own message -------

  local broken="$scratch/broken"
  cp -R "$proj" "$broken"
  grep -v '^title:' "$broken/manifest.yaml" >"$broken/manifest.yaml.tmp"
  mv "$broken/manifest.yaml.tmp" "$broken/manifest.yaml"

  local out
  out="$(mktemp)"
  set +e
  "$CLI" book --check --out "$scratch/out-broken" "$broken" >"$out" 2>&1
  local broken_code=$?
  set -e
  assert_exit_code "1" "$broken_code" "pandoc-pdf book fails when the tool fails"
  assert_contains "$out" "required fields are missing: title" \
    "the failure carries the tool's own message"
  rm -f "$out"

  rm -rf "$scratch"
}

# The contents are one list; a book reads better when the front matter, the
# chapters and the appendices do not run together. The adapter inserts the
# separation at the two boundaries it already controls, and the style is the
# volume's choice.
# A case states its own contents style: the example declares one, so a copy has
# to drop it first or the appended key would simply duplicate it.
strip_toc_fields() {
  python3 - "$1" <<'PYEOF'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
kept = []
in_labels = False
for line in path.read_text(encoding="utf-8").splitlines():
    if line.startswith("toc_separators:"):
        in_labels = False
        continue
    if line.startswith("toc_labels:"):
        in_labels = True
        continue
    if in_labels and line.startswith("  "):
        continue
    in_labels = False
    kept.append(line)
path.write_text("\n".join(kept) + "\n", encoding="utf-8")
PYEOF
}

run_bookkit_toc_separators_test() {
  local tool="${ROOT_DIR}/scripts/tools/bookkit/build.py"
  local single="${ROOT_DIR}/examples/book-kit/single"
  local scratch out code
  scratch="$(mktemp -d)"

  # Declares one style on a copy of the example and returns its mainmatter file.
  mainmatter_for() {
    local name="$1" style="$2" extra="${3:-}"
    local dir="$scratch/$name"
    cp -R "$single" "$dir"
    strip_toc_fields "$dir/manifest.yaml"
    printf '\ntoc_separators: %s\n%s' "$style" "$extra" >>"$dir/manifest.yaml"
    # Half of these cases are expected to fail, so neither the tool nor the
    # search may end the suite: the exit code is recorded and asserted instead.
    set +e
    python3 "$tool" --check --out "$scratch/out-$name" "$dir" >"$scratch/log-$name" 2>&1
    echo $? >"$scratch/code-$name"
    set -e
    find "$scratch/out-$name" -name "00-mainmatter.md" 2>/dev/null | head -1 || true
  }

  # --- The default separates the blocks ------------------------------------

  local plain="$scratch/plain"
  cp -R "$single" "$plain"
  strip_toc_fields "$plain/manifest.yaml"
  python3 "$tool" --check --out "$scratch/out-plain" "$plain" >/dev/null 2>&1
  local default_mm
  default_mm="$(find "$scratch/out-plain" -name "00-mainmatter.md" | head -1)"
  if grep -q "BookTocSeparatorChapters" "$default_mm" 2>/dev/null; then
    pass "a volume without toc_separators still separates the contents"
  else
    fail "the default toc_separators did not reach the generated mode file"
  fi

  # --- none emits nothing --------------------------------------------------

  local none_mm
  none_mm="$(mainmatter_for none none)"
  if grep -q "BookTocSeparator" "$none_mm" 2>/dev/null; then
    fail "toc_separators: none must not emit a separator"
  else
    pass "toc_separators: none emits no separator"
  fi

  # --- rule and label reach the contents with their own mark --------------

  local rule_mm label_mm
  rule_mm="$(mainmatter_for rule rule)"
  assert_contains "$rule_mm" "protect\\\\rule" "toc_separators: rule draws a rule in the contents"

  label_mm="$(mainmatter_for label label "$(printf 'toc_labels:\n  chapters: "Capítulos"\n  appendices: "Apéndices"\n')")"
  assert_contains "$label_mm" "Capítulos" "toc_separators: label prints the declared word"

  # --- The two failures a manifest can make -------------------------------

  mainmatter_for label_missing label
  assert_exit_code "1" "$(cat "$scratch/code-label_missing")" "a label style without labels fails"
  assert_contains "$scratch/log-label_missing" "toc_labels" "the failure names the field it is missing"

  mainmatter_for bogus bogus
  assert_exit_code "1" "$(cat "$scratch/code-bogus")" "an unknown style fails"
  assert_contains "$scratch/log-bogus" "none, space, rule, label" "the failure lists the styles"

  rm -rf "$scratch"
}

# A series may set a field once instead of repeating it per volume, so the
# example declares the contents separation in series.yaml. The merge copies a
# fixed list of shared fields, and a field missing from it is ignored without a
# word, which is worth its own assertion.
run_bookkit_series_defaults_test() {
  local tool="${ROOT_DIR}/scripts/tools/bookkit/build.py"
  local series="${ROOT_DIR}/examples/book-kit/series"
  local scratch out code
  scratch="$(mktemp -d)"

  cp -R "$series" "$scratch/series"
  strip_toc_fields "$scratch/series/series.yaml"
  printf '\ntoc_separators: rule\n' >>"$scratch/series/series.yaml"

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out" "$scratch/series" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a series-level toc_separators is accepted"

  local mainmatter
  mainmatter="$(find "$scratch/out" -name "00-mainmatter.md" | head -1)"
  if grep -q "protect\\\\rule" "$mainmatter" 2>/dev/null; then
    pass "a series-level toc_separators reaches every volume"
  else
    fail "a series-level toc_separators was ignored by the volume"
  fi

  rm -f "$out"
  rm -rf "$scratch"
}
