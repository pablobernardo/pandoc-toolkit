#!/bin/bash
# The LaTeX template: current-Pandoc guards, wrapping, symbols and the builtin name.
# Sourced by tests/run.sh (not run standalone).

run_template_modern_pandoc_guard_test() {
  local template="${ROOT_DIR}/templates/default.tex"

  if grep -q '\\providecommand{\\pandocbounded}' "$template"; then
    pass "the toolkit template defines \\pandocbounded for current Pandoc"
  else
    fail "the toolkit template must define \\pandocbounded: Pandoc 3.2+ emits it and the render dies without it"
  fi
}

# The cover used to be unavoidable and the language fixed to Spanish, so
# `language` and `titlepage` in a metadata file did nothing. They belong to the
# config, and the free-form map carries the rest.

run_template_wrapping_test() {
  local out code
  out="$(mktemp)"
  code=0
  "${REAL_PYTHON3}" - "${ROOT_DIR}/templates/default.tex" >"$out" 2>&1 <<'PY' || code=$?
from pathlib import Path
import sys
s = Path(sys.argv[1]).read_text()
settings = r'\fvset{breaklines=true,breakanywhere=false,breakafter={/.,=}}'
assert settings in s and s.index(settings) > s.index('$highlighting-macros$')
print('wrapping applies after Pandoc definitions')
assert r'\hyphenpenalty=10000' in s and r'\exhyphenpenalty=10000' in s
print('prose words stay whole')
assert r'commandchars=\\\{\}' in s and r'\fvset{fontsize=\small}' in s
print('highlighting escapes and existing code size retained')
assert r'\Needspace{6\baselineskip}' in s and r'\if@nobreak\else' in s
for command in ('section', 'subsection', 'subsubsection', 'paragraph', 'subparagraph'):
    prefix = r'\pretocmd{' + chr(92) + command + '}'
    line = next(line for line in s.splitlines() if line.startswith(prefix))
    assert r'\KeepHeadingWithContent' in line
print('all supported heading levels reserve content space')
PY
  assert_exit_code "0" "$code" "template wrapping settings are effective"
  assert_contains "$out" "prose words stay whole" "template disables syllable hyphenation"
  assert_contains "$out" "highlighting escapes and existing code size retained" "template preserves code styling"
  assert_contains "$out" "all supported heading levels reserve content space" "headings reserve room for following content"
  rm -f "$out"
}

# D14: the six symbols of #83 (☐ ☑ ☒ ✅ ❌ ⚠) are missing from the default
# prose and mono faces, so every PDF drops them. The shared template maps them,
# glyph-only, to an optional GNU FreeSerif face. First slice: prose and inline
# code only; fenced code keeps the baseline behavior until the second slice
# adds the verbatim reactivation. This structural test keeps the contract cheap
# for every run; the rendered matrix (all six symbols in prose and inline code,
# on real engines) lives in tests/integration/unicode-symbols.sh, which needs a
# real TeX toolchain and is not part of `make gate`.

run_template_unicode_symbol_fallback_test() {
  local out code
  out="$(mktemp)"
  code=0
  "${REAL_PYTHON3}" - "${ROOT_DIR}/templates/default.tex" >"$out" 2>&1 <<'PY' || code=$?
from pathlib import Path
import re
import sys

s = Path(sys.argv[1]).read_text()

# 1) The font flag is declared before the engine branch, so the pdfLaTeX
#    fallback branch can test it without an undefined control sequence.
newif = s.index(r'\newif\ifSymbolFontFound')
branch = s.index(r'\ifxetexorlua')
assert newif < branch, 'font flag must be declared before the engine branch'

# 2) The lookup is guarded and standard only: file name first (TeX Live), then
#    family name (fontconfig/luaotfload, Debian fonts-freefont-ttf). Without the
#    font the block degrades; no local path is hardcoded.
assert r'\IfFontExistsTF{FreeSerif.ttf}' in s, 'guarded file-name lookup missing'
assert r'\IfFontExistsTF{FreeSerif}' in s, 'guarded family-name lookup missing'
assert '/usr/share' not in s and '/Library/' not in s, 'font lookup must not hardcode local paths'

# 3) The newunicodechar package is optional, guarded together with the font:
#    a TeX installation without it degrades instead of failing the render.
guard = s.index(r'\IfFileExists{newunicodechar.sty}')
missing_pkg = s.index(r'\SymbolFontFoundfalse', guard)
first_mapping = s.index(r'\newunicodechar{☐}')
assert guard < first_mapping < missing_pkg, 'package guard must wrap the mappings and clear the flag when absent'

# 4) Exactly the six symbols are mapped, each to its codepoint.
expected = {'☐': '2610', '☑': '2611', '☒': '2612', '✅': '2705', '❌': '274C', '⚠': '26A0'}
mappings = dict(re.findall(r'\\newunicodechar\{(.)\}\{\\SymbolGlyph\{([0-9A-Fa-f]+)\}\}', s))
assert mappings == expected, 'mappings must be exactly the six symbols, got: %r' % (mappings,)
assert len(re.findall(r'\\newunicodechar\{(.)\}', s)) == 6, 'no standalone selector mapping may exist'

# 5) The mapped glyph switches the font for a single \\char and then consumes a
#    trailing U+FE0F, the selector the issue's ⚠️ carries. Only FE0F is handled,
#    and only there; no other text is stripped.
glyph = re.search(r'\\def\\SymbolGlyph#1\{[^\n]*\}', s).group(0)
assert r'{\SymbolSerifFont\char"#1}' in glyph, 'glyph macro must only switch the font for one char'
assert r'\SymbolMaybeEatSelector' in glyph, 'glyph macro must consume a trailing selector'
assert 'FE0F' in s, 'the lookahead must cover the emoji presentation selector'
assert 'FE0E' not in s, 'the text presentation selector is out of scope for this slice'

# 6) This slice maps prose and inline code only: fenced code keeps the baseline
#    behavior, so no verbatim reactivation may exist yet.
assert r'\fvset{codes=' not in s, 'verbatim reactivation belongs to the second slice'

# 7) The mapping block lives in the XeLaTeX/LuaLaTeX branch only; the pdfLaTeX
#    branch keeps its historical behavior.
assert newif < first_mapping < s.index(r'\usepackage[T1]{fontenc}'), 'mappings must stay inside the XeLaTeX/LuaLaTeX branch'

print('font flag precedes the engine branch')
print('exactly six guarded FreeSerif mappings')
print('package guard and FE0F-only selector scoping hold')
PY

  assert_exit_code "0" "$code" "template unicode symbol fallback satisfies the structural contract"
  assert_contains "$out" "exactly six guarded FreeSerif mappings" "template maps exactly the six symbols to FreeSerif"
  assert_contains "$out" "package guard and FE0F-only selector scoping hold" "package is optional and selectors are scoped to the mapped sequences"
  rm -f "$out"
}

# Accepting a missing setting is half the job: the renderer has to use the value it
# documents, or the relaxation only moves the surprise to render time.

# pandoc.top_level_division moved the H1-as-\chapter decision from the template
# to the contract: the renderer passes the flag, so the template must not
# redefine heading commands any more.

run_book_template_top_level_division_test() {
  local template="${ROOT_DIR}/templates/book.tex"

  if grep -qE '^\\let\\(section|subsection|subsubsection|paragraph|subparagraph)\\' "$template"; then
    fail "templates/book.tex must not shift heading levels with \\let: pandoc.top_level_division replaces it"
  else
    pass "templates/book.tex contains no \\let heading shift"
  fi

  if grep -q 'documentclass\[.*\]{book}' "$template"; then
    pass "the book template keeps the book class that defines \\chapter"
  else
    fail "the book template must keep its book class: --top-level-division=chapter emits \\chapter"
  fi

  if grep -q 'tableofcontents' "$template"; then
    pass "the book template keeps its table of contents"
  else
    fail "the book template must keep \\tableofcontents"
  fi
}

run_builtin_template_test() {
  local sandbox out code cfg

  sandbox="$(new_contract_sandbox)"
  cp "${ROOT_DIR}/templates/book.tex" "${sandbox}/templates/book.tex"
  printf '# Chapter One\n\ncontent one\n' >"${sandbox}/work/chapters/01-one.md"

  cfg="${sandbox}/pdf.config.yaml"
  write_contract_config "$cfg" natural true "" true
  python3 - "$cfg" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(
    text.replace("  resource_path:", "  template: book\n  resource_path:", 1)
)
PY

  set +e
  "${sandbox}/bin/pandoc-pdf" validate-config -c "$cfg" >/dev/null 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a builtin template name validates"

  out="$(mktemp)"
  set +e
  "${sandbox}/bin/pandoc-pdf" render --dry-run --json -c "$cfg" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a builtin template name plans a render"
  assert_contains "$out" "${sandbox}/templates/book.tex" \
    "the plan resolves a builtin name inside the toolkit, not the project"

  python3 - "$cfg" <<'PY'
import sys

path = sys.argv[1]
text = open(path, encoding="utf-8").read()
open(path, "w", encoding="utf-8").write(text.replace("template: book", "template: boook", 1))
PY

  set +e
  "${sandbox}/bin/pandoc-pdf" validate-config -c "$cfg" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "an unknown template name is rejected"
  assert_contains "$out" "book" "the failure names the valid template names"

  rm -rf "$sandbox"
  rm -f "$out"
}
