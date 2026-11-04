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
  sed 's|content/chapters/01-clouds\.md|content/chapters/99-missing.md|' "$lost/manifest.yaml" >"$lost/manifest.yaml.tmp"
  mv "$lost/manifest.yaml.tmp" "$lost/manifest.yaml"

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-lost" "$lost" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "bookkit --check fails when a declared entry file is missing"
  assert_contains "$out" "volume 'missing-entry': chapters entry '1' declares a missing file: content/chapters/99-missing\.md" \
    "the failure names the volume, the logical name and the path"
  rm -f "$out"

  # --- optional: true with an absent file is skipped with a warning -------

  out="$(mktemp)"
  set +e
  python3 "$tool" --check --out "$scratch/out-optional" "$series_fix" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "an optional entry with an absent file does not fail the plan"
  assert_contains "$out" "volume 'volume-2': back_matter entry 'excerpt' is optional and its file was not found, skipped: content/back-matter/99-excerpt\.md" \
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
    assert_contains "$v1config" "content/back-matter/01-glossary\.md" \
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
    assert_contains "$orderedconfig" "content/chapters/01-clouds\.md" "ordered picks up the first chapter"
    assert_contains "$orderedconfig" "content/chapters/03-rain\.md" "ordered picks up the last chapter"
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
