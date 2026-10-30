run_documentation_skill_test() {
  local out err code
  out="$(mktemp)"
  err="$(mktemp)"
  set +e
  python3 - "${ROOT_DIR}" >"$out" 2>"$err" <<'PY'
import json
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
path = root / "skills/pandoc-pdf-documentation/SKILL.md"
text = path.read_text(encoding="utf-8")
frontmatter = re.match(r"\A---\n(.*?)\n---\n", text, re.S)
assert frontmatter, "skill needs YAML frontmatter"
fields = dict(line.split(": ", 1) for line in frontmatter[1].splitlines())
assert fields["name"] == path.parent.name
assert re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", fields["name"])
assert len(fields["name"]) <= 64
# A JSON-quoted scalar is valid YAML without requiring a YAML parser in CI.
description = json.loads(fields["description"])
assert isinstance(description, str) and 0 < len(description) <= 1024
assert "Markdown" in description and "PDF" in description
links = re.findall(r"\]\(([^)]+)\)", text[frontmatter.end():])
assert links and all(link.startswith("https://github.com/pablobernardo/pandoc-toolkit/") for link in links), "references must survive installation outside the toolkit"
print("skill structure OK")
PY
  code=$?
  set -e
  assert_exit_code "0" "$code" "consumer skill has portable Agent Skills metadata and references"
  if [[ "$(<"$out")" == "skill structure OK" ]]; then
    pass "skill structural check reports its result"
  else
    fail "skill structural check reports its result"
  fi
  if [[ ! -s "$err" ]]; then
    pass "skill structural check has no diagnostics"
  else
    fail "skill structural check has no diagnostics"
  fi
  rm -f "$out" "$err"
}

run_docs_consistency_test() {
  local out code tree covered
  out="$(mktemp)"
  tree="$(mktemp -d)"

  set +e
  python3 "${ROOT_DIR}/scripts/check-docs.py" "${ROOT_DIR}" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "every markdown reference points at something that exists"
  assert_contains "$out" "markdown files" "the check reports how much it covered"

  covered=$(sed -n 's/.*docs OK: \([0-9]*\) markdown files.*/\1/p' "$out" | head -1)
  if [[ "${covered:-0}" -ge 20 ]]; then
    pass "the check covers the whole tree (${covered} markdown files)"
  else
    fail "the check must cover the whole tree, it covered ${covered:-0}"
  fi

  # A relative link whose target is gone must fail.
  mkdir -p "${tree}/docs"
  printf '# Doc\n\nSee [the other doc](missing.md).\n' >"${tree}/docs/a.md"
  set +e
  python3 "${ROOT_DIR}/scripts/check-docs.py" "$tree" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "a broken link fails the check"
  assert_contains "$out" "missing.md" "the failure names the missing target"

  # A backticked path in prose must fail too: no link checker sees those.
  printf '# Doc\n\nThe file `docs/gone.md` was removed.\n' >"${tree}/docs/a.md"
  set +e
  python3 "${ROOT_DIR}/scripts/check-docs.py" "$tree" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "a backticked path that does not exist fails the check"
  assert_contains "$out" "docs/gone.md" "the failure names the backticked path"

  # Commands inside fenced blocks are examples, not references.
  printf '# Doc\n\n```bash\ncat docs/not-there.md\n```\n' >"${tree}/docs/a.md"
  set +e
  python3 "${ROOT_DIR}/scripts/check-docs.py" "$tree" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "paths inside fenced code blocks are not references"

  # History is allowed to name what was removed: that is what it records.
  rm -f "${tree}/docs/a.md"
  printf '# Changelog\n\nRemoved `scripts/gone.rb` in 1.2.0.\n' >"${tree}/CHANGELOG.md"
  set +e
  python3 "${ROOT_DIR}/scripts/check-docs.py" "$tree" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "a history file may name what was removed"

  # An absolute home path would publish a machine's layout.
  rm -f "${tree}/CHANGELOG.md"
  # Built at run time so this test file does not itself contain the pattern.
  local leaky="/Users"
  printf '# Doc\n\nSee `%s/someone/code/repo/.env`.\n' "$leaky" >"${tree}/docs/a.md"
  set +e
  python3 "${ROOT_DIR}/scripts/check-docs.py" "$tree" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "an absolute home path fails the check"
  assert_contains "$out" "absolute home path" "the failure names the leak"

  rm -rf "$tree"
  rm -f "$out"
}

run_examples_validate_test() {
  local f code count=0
  while IFS= read -r f; do
    count=$((count + 1))
    set +e
    PANDOC_PDF_LANG=en "$CLI" validate-config -c "$f" >/dev/null 2>&1
    code=$?
    set -e
    assert_exit_code "0" "$code" "example config validates: ${f#"${ROOT_DIR}/"}"
  done < <(find "${ROOT_DIR}/examples" -name 'pdf.config*.yaml' | sort)

  if [[ "$count" -ge 1 ]]; then
    pass "the examples are exercised (${count} config(s))"
  else
    fail "no example config was found: the test would pass without checking anything"
  fi
}

# A hand-written reading order goes stale the moment a document is added, which is
# exactly the drift this example exists to demonstrate a guard against.
run_documentation_example_coverage_test() {
  local planned expected missing

  planned="$(PANDOC_PDF_LANG=en "$CLI" render -c "${ROOT_DIR}/examples/documentation/pdf.config.yaml" \
    --dry-run --json 2>/dev/null \
    | "${REAL_PYTHON3}" -c 'import json,sys; print("\n".join(sorted(p.split("/")[-1] for p in json.load(sys.stdin)["chapters"])))' 2>/dev/null)"

  expected="$(cd "${ROOT_DIR}/docs" && ls -1 *.md | grep -v '^README\.md$' | sort)"
  missing="$(comm -13 <(printf '%s\n' "$planned" | sort) <(printf '%s\n' "$expected" | sort) | tr -d ' ')"

  if [[ -z "$missing" ]]; then
    pass "the documentation example includes every document under docs/"
  else
    fail "the documentation example is missing: ${missing//$'\n'/, }"
  fi

  if [[ -n "$planned" ]]; then
    pass "the documentation example plans at least one document"
  else
    fail "the documentation example plans nothing: the check above would pass vacuously"
  fi
}

run_emoji_showcase_example_test() {
  if ! command -v pandoc >/dev/null 2>&1; then
    echo "SKIP emoji showcase contexts (pandoc not available)"
    return 0
  fi

  local out code context
  out="$(mktemp)"
  set +e
  "${REAL_PYTHON3}" - "${ROOT_DIR}/examples/ohmyfake/chapters/06-a-fake-that-tells-the-truth.md" >"$out" 2>&1 <<'PY'
import json
import subprocess
import sys

parsed = subprocess.run(["pandoc", sys.argv[1], "-f", "markdown", "-t", "json"],
                        capture_output=True, text=True, check=True)
blocks = json.loads(parsed.stdout)["blocks"]
glyphs = {"\U0001f9ea", "\U0001f50d"}

def has_emoji(node):
    if isinstance(node, dict):
        if node.get("t") == "Str" and any(g in node["c"] for g in glyphs):
            return True
        return any(has_emoji(value) for value in node.values())
    return isinstance(node, list) and any(has_emoji(value) for value in node)

for name, kind in (("heading", "Header"), ("paragraph", "Para"),
                   ("list", "BulletList"), ("table", "Table")):
    present = any(block["t"] == kind and has_emoji(block) for block in blocks)
    print(f"{name}={'PASS' if present else 'FAIL'}")
PY
  code=$?
  set -e
  assert_exit_code "0" "$code" "the public emoji example parses through Pandoc"
  for context in heading paragraph list table; do
    assert_contains "$out" "^${context}=PASS$" "the public example shows emoji in a ${context}"
  done
  rm -f "$out"
}
