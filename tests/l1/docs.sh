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
