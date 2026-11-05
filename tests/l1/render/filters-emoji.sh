#!/bin/bash
# The emoji filter: ballot icons, contexts, allowlist and defaults.
# Sourced by tests/run.sh (not run standalone).

run_render_ballot_icons_test() {
  local sandbox tmpbin capture out
  sandbox="$(new_contract_sandbox)"
  tmpbin="$(mktemp -d)"
  write_pandoc_capture_mock "$tmpbin"
  capture="$(mktemp)"
  out="$(mktemp)"

  printf '# Chapter One\n\n- [ ] unchecked\n- [x] checked\n' >"${sandbox}/work/chapters/01-one.md"

  write_contract_config "${sandbox}/skelepress.config.yaml" natural true "" true
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/skelepress" render -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1; then
    pass "render accepts include_ballot_icons=true"
  else
    fail "render should accept include_ballot_icons=true ($(tail -2 "$out"))"
  fi
  assert_contains "$capture" "^PANDOC_EMOJI_BALLOT_ICONS=1$" "include_ballot_icons=true enables ballot glyphs"

  write_contract_config "${sandbox}/skelepress.config.yaml" natural true "" false
  if TMP_PANDOC_CAPTURE="$capture" PATH="${tmpbin}:$PATH" "${sandbox}/bin/skelepress" render -c "${sandbox}/skelepress.config.yaml" >"$out" 2>&1; then
    pass "render accepts include_ballot_icons=false"
  else
    fail "render should accept include_ballot_icons=false ($(tail -2 "$out"))"
  fi
  assert_contains "$capture" "^PANDOC_EMOJI_BALLOT_ICONS=0$" "include_ballot_icons=false disables ballot glyphs"

  rm -rf "$sandbox" "$tmpbin"
  rm -f "$capture" "$out"
}

run_emoji_filter_plain_heading_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "⏭  SKIP emoji filter heading check (pandoc not available)"
    return 0
  fi

  local md tex
  md="$(mktemp)"
  tex="$(mktemp)"
  printf '# Plain Heading\n\nText with an emoji \xe2\x9c\x85 and plain words.\n' >"$md"

  if pandoc "$md" -t latex --lua-filter="${ROOT_DIR}/filters/emoji.lua" >"$tex" 2>&1; then
    pass "emoji filter produces latex output"
  else
    fail "emoji filter should produce latex output ($(tail -2 "$tex"))"
  fi

  assert_contains "$tex" '\\section\{Plain Heading\}' "emoji filter keeps a plain heading plain"
  assert_not_contains "$tex" '\\texorpdfstring' "emoji filter does not format plain headings (needs hyperref otherwise)"

  rm -f "$md" "$tex"
}

run_emoji_filter_contexts_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP emoji filter contexts (pandoc not available)"
    return 0
  fi

  local dir md tex images remaining
  dir="$(mktemp -d)"
  md="$(mktemp)"
  tex="$(mktemp)"

  # A real glyph so the filter substitutes instead of falling back to the character.
  cp "${ROOT_DIR}/filters/emoji/2610.svg" "${dir}/2705.svg"

  cat >"$md" <<'EOF'
# Heading

Paragraph text.

| Col |
|-----|
| cell |

: Caption here

- item
EOF
  # Write the emoji through printf so this test file stays ASCII-clean.
  printf '# Heading \xe2\x9c\x85\n\nParagraph \xe2\x9c\x85 text.\n\n| Col |\n|-----|\n| \xe2\x9c\x85 cell |\n\n: Caption \xe2\x9c\x85 here\n\n- item \xe2\x9c\x85\n' >"$md"

  if PANDOC_EMOJI_DIR="$dir" pandoc "$md" -t latex --lua-filter="${ROOT_DIR}/filters/emoji.lua" >"$tex" 2>&1; then
    pass "emoji filter renders mixed contexts"
  else
    fail "emoji filter should render mixed contexts ($(tail -2 "$tex"))"
  fi

  images="$(grep -c "includesvg\|includegraphics" "$tex" || true)"
  remaining="$(grep -c $'\xe2\x9c\x85' "$tex" || true)"
  assert_exit_code "0" "$remaining" "emoji filter substitutes every emoji context (heading, paragraph, table cell, caption, list)"
  if [[ "${images:-0}" -ge 5 ]]; then
    pass "emoji filter emits an image per substituted emoji"
  else
    fail "emoji filter should emit at least 5 images, got ${images:-0}"
  fi

  rm -rf "$dir"
  rm -f "$md" "$tex"
}

run_emoji_source_allowlist_test() {
  local out code
  out="$(mktemp)"

  set +e
  "${REAL_PYTHON3}" - "${ROOT_DIR}/scripts/runtime/prepare-emojis.py" >"$out" 2>&1 <<'PY'
import importlib.util
import sys

spec = importlib.util.spec_from_file_location("prepare_emojis", sys.argv[1])
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

for base, label in ((module.NOTO_BASE_URL, "noto"), (module.TWEMOJI_BASE_URL, "twemoji")):
    assert module.allowed_url(base + "/probe.svg"), f"{label} base URL is refused by its own allowlist"
assert not module.allowed_url("https://raw.githubusercontent.com/evil/repo/main/2D/svg/x.svg"), \
    "a foreign repository must be refused"
assert not module.allowed_url("http://raw.githubusercontent.com/googlefonts/noto-emoji/main/2D/svg/x.svg"), \
    "plain http must be refused"
PY
  code=$?
  set -e

  assert_exit_code "0" "$code" "each asset base URL is accepted by its own allowlist (an upstream move cannot pass silently)"
  cat "$out" | head -3
  rm -f "$out"
}

# Pandoc 3.2 and later emit \pandocbounded whenever an image is bounded. The
# toolkit template must define it, or every document with an image fails in
# LaTeX. CI installs the distribution pandoc, which is older and never emits the
# macro, so this guard is what stands between a template edit and a broken render
# for anyone on a current release.

run_render_filter_defaults_test() {
  local plan got
  plan="$(mktemp)"
  got="$(mktemp)"

  # stdout only: the human-readable confirmation goes to stderr, and merging the
  # two streams turns the plan into something json.load cannot read.
  SKELEPRESS_LANG=en "$CLI" render -c "${FIXTURES_DIR}/valid-filter-defaults.config.yaml" \
    --dry-run --json >"$plan" 2>/dev/null || true

  # The plan carries the environment as key/value pairs, so read it as JSON
  # instead of grepping for "VAR=value", which is how this test first lied.
  "${REAL_PYTHON3}" - "$plan" >"$got" 2>/dev/null <<'PY'
import json
import sys

try:
    plan = json.load(open(sys.argv[1]))
except Exception:
    print("unparseable plan")
    raise SystemExit(0)

env = plan.get("env", {})
print(env.get("PANDOC_EMOJI_DIR", ""))
print(env.get("PANDOC_EMOJI_BALLOT_ICONS", ""))
print(env.get("PANDOC_MERMAID_BACKGROUND", ""))
print([a for a in plan.get("pandoc", {}).get("argv", []) if "lua-filter" in a])
PY

  assert_contains "$got" "output/emoji$" "an enabled emoji filter defaults to output/emoji"
  assert_contains "$got" "^1$" "ballot icons default to on"
  assert_contains "$got" "^transparent$" "the mermaid background defaults to transparent"
  assert_contains "$got" "inline-code-breaks.lua" "the inline code filter is always in the chain"

  rm -f "$plan" "$got"
}

# A template may be a builtin name instead of a path. The toolkit ships
# templates/book.tex, and the validator and the renderer must agree on what the
# name means: if either side disagrees, the configuration is useless.
