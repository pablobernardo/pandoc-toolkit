#!/bin/bash
# doctor area tests. Sourced by tests/run.sh (not run standalone).

run_doctor_success_with_mocked_path() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 curl mmdc xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  if PATH="$tmpbin" /bin/bash "$CLI" doctor >"$out" 2>&1; then
    pass "doctor passes with mocked dependencies"
  else
    fail "doctor should pass with mocked dependencies"
  fi
  assert_contains "$out" "Doctor OK" "doctor reports OK"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_failure_missing_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(python3 curl mmdc xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PATH="$tmpbin" /bin/bash "$CLI" doctor >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor fails when pandoc is missing"
  assert_contains "$out" "pandoc" "doctor reports missing dependency"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_with_config_required_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-required-cmd.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor -c fails for missing required command"
  assert_contains "$out" "mycustomcmd" "doctor -c reports missing command from config"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_rejects_invalid_required_cmd() {
  local tmpbin
  tmpbin="$(mktemp -d)"
  local cmds=(python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  local out
  out="$(mktemp)"
  set +e
  SKELEPRESS_LANG=es PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-invalid-required-cmd.yaml" >"$out" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor -c fails with invalid command name"
  assert_contains "$out" "Invalid command name" "doctor -c reports invalid command"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_strict_semantics_test() {
  local tmpbin out code
  tmpbin="$(mktemp -d)"
  local cmds=(pandoc python3 xelatex)

  for c in "${cmds[@]}"; do
    if [[ "$c" == "python3" ]]; then
      cat >"${tmpbin}/${c}" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
    else
      cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    fi
    chmod +x "${tmpbin}/${c}"
  done

  out="$(mktemp)"
  set +e
  SKELEPRESS_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-required-cmd.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "runtime.strict=true fails on missing required command"

  set +e
  SKELEPRESS_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-strict-false.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "runtime.strict=false does not fail on missing required command"
  assert_contains "$out" "mycustomcmd" "runtime.strict=false still reports the missing command"

  # Sin motor TeX no hay PDF: strict=false no puede perdonarlo.
  local tmpbin_no_tex
  tmpbin_no_tex="$(mktemp -d)"
  cat >"${tmpbin_no_tex}/pandoc" <<'EOF'
#!/bin/bash
exit 0
EOF
  cat >"${tmpbin_no_tex}/python3" <<EOF
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
EOF
  chmod +x "${tmpbin_no_tex}/pandoc" "${tmpbin_no_tex}/python3"

  set +e
  SKELEPRESS_LANG=en PATH="$tmpbin_no_tex" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-config-strict-false.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "runtime.strict=false still fails when the TeX engine is missing"
  assert_contains "$out" "xelatex" "the missing TeX engine is named"

  rm -rf "$tmpbin" "$tmpbin_no_tex"
  rm -f "$out"
}

run_doctor_python_minimum_test() {
  # The toolkit declares Python 3.9 as the minimum (the interpreter macOS
  # ships), so doctor must refuse an older python3 naming both versions. The
  # mocked python3 answers the version probe with an old release but otherwise
  # behaves like the real one, because preflight itself runs under python3.
  local tmpbin out code
  tmpbin="$(mktemp -d)"
  out="$(mktemp)"

  for c in pandoc curl mmdc xelatex; do
    cat >"${tmpbin}/${c}" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "${tmpbin}/${c}"
  done

  cat >"${tmpbin}/python3" <<EOF
#!/bin/bash
if [[ "\${1:-}" == "--version" ]]; then
  echo "Python 3.8.0"
  exit 0
fi
exec "${REAL_PYTHON3}" "\$@"
EOF
  chmod +x "${tmpbin}/python3"

  set +e
  SKELEPRESS_LANG=en PATH="${tmpbin}" /bin/bash "$CLI" doctor >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "doctor refuses python3 below the declared minimum"
  assert_contains "$out" "3\.8\.0" "the refusal names the version found"
  assert_contains "$out" "3\.9" "the refusal names the required minimum"

  # The supported interpreter passes: same PATH, python3 at the minimum.
  cat >"${tmpbin}/python3" <<EOF
#!/bin/bash
if [[ "\${1:-}" == "--version" ]]; then
  echo "Python 3.9.6"
  exit 0
fi
exec "${REAL_PYTHON3}" "\$@"
EOF
  chmod +x "${tmpbin}/python3"

  if SKELEPRESS_LANG=en PATH="${tmpbin}" /bin/bash "$CLI" doctor >"$out" 2>&1; then
    pass "doctor accepts python3 at the declared minimum"
  else
    fail "doctor should accept python3 at the declared minimum"
  fi
  assert_contains "$out" "Doctor OK" "doctor still reports OK on the supported interpreter"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_mermaid_smoke_test() {
  local tmpbin out code
  tmpbin="$(mktemp -d)"
  out="$(mktemp)"

  cat >"${tmpbin}/pandoc" <<'STUB'
#!/bin/bash
exit 0
STUB
  cat >"${tmpbin}/xelatex" <<'STUB'
#!/bin/bash
exit 0
STUB
  cat >"${tmpbin}/mmdc" <<'STUB'
#!/bin/bash
if [[ "${1:-}" == "--version" ]]; then
  echo "12.0.0"
  exit 0
fi
echo "Error: Could not find chrome-headless-shell" >&2
exit 1
STUB
  cat >"${tmpbin}/python3" <<STUB
#!/bin/bash
exec "${REAL_PYTHON3}" "\$@"
STUB
  chmod +x "${tmpbin}/pandoc" "${tmpbin}/xelatex" "${tmpbin}/mmdc" "${tmpbin}/python3"

  set +e
  SKELEPRESS_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-mermaid.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "1" "$code" "doctor fails when mmdc cannot render a diagram"
  assert_contains "$out" "Mermaid diagrams cannot be rendered" "doctor names the mermaid failure"
  assert_contains "$out" "PUPPETEER_EXECUTABLE_PATH" "doctor gives the Chrome remediation"
  assert_contains "$out" "12.0.0" "doctor names the mermaid-cli version it found"

  set +e
  SKELEPRESS_LANG=en PATH="$tmpbin" /bin/bash "$CLI" doctor -c "${FIXTURES_DIR}/doctor-mermaid-warn.config.yaml" >"$out" 2>&1
  code=$?
  set -e
  assert_exit_code "0" "$code" "runtime.strict=false keeps doctor green on a mermaid failure"
  assert_contains "$out" "PUPPETEER_EXECUTABLE_PATH" "the warning still shows the remediation"

  rm -rf "$tmpbin"
  rm -f "$out"
}

run_doctor_config_parse_error_test() {
  # The config is generated here instead of living under tests/fixtures: its
  # whole point is being unparseable, and a versioned file that every YAML
  # linter is right to reject would be permanent noise in the tree.
  local cfgdir out cfgdir_cleanup
  cfgdir="$(mktemp -d)"
  cfgdir_cleanup="$cfgdir"
  cat >"${cfgdir}/broken.config.yaml" <<'YAML'
version: 1
pandoc:
  pdf_engine: xelatex
output:
  formats: |
    pdf
  broken: [unclosed
YAML

  local out_file
  out_file="$(mktemp)"
  set +e
  SKELEPRESS_LANG=en /bin/bash "$CLI" doctor -c "${cfgdir}/broken.config.yaml" >"$out_file" 2>&1
  local code=$?
  set -e
  assert_exit_code "1" "$code" "doctor -c fails when the YAML does not parse"
  assert_contains "$out_file" "Could not parse config for preflight" "doctor names the YAML parse failure"
  assert_not_contains "$out_file" "Traceback" "the config loader reports a parse failure without crashing"

  rm -rf "$cfgdir_cleanup"
  rm -f "$out_file"
}

# docs/dependency-policy.md declares Python 3.9 as the floor. The test that proves
# a render works there only runs on a machine that has 3.9 — macOS, and the weekly
# job — so a pull request on Linux would not notice a 3.10-only construct coming
# back. This scans the source instead, which runs everywhere.
#
# Only constructs that genuinely need more than 3.9 are listed. `dict | dict`,
# `functools.cache`, `str.removeprefix` and `str.removesuffix` arrived in 3.9 and
# are allowed; flagging them would be a false positive.
run_scripts_python_minimum_guard_test() {
  local output

  output="$("${REAL_PYTHON3}" - "$ROOT_DIR" <<'PY' 2>&1
import io
import re
import sys
import tokenize
from pathlib import Path

root = Path(sys.argv[1])

RULES = [
    (re.compile(r"\bzip\s*\([^)]*\bstrict\s*="), "zip(..., strict=) needs Python 3.10"),
    (re.compile(r"^\s*match\s+[^=]" ), "match statements need Python 3.10"),
    (re.compile(r"\bitertools\.pairwise\b"), "itertools.pairwise needs Python 3.10"),
    (re.compile(r"\basyncio\.timeout\b"), "asyncio.timeout needs Python 3.11"),
    (re.compile(r"^\s*except\s*\*"), "except* needs Python 3.11"),
    (re.compile(r"\bimport\s+tomllib\b|\bfrom\s+tomllib\b"), "tomllib needs Python 3.11"),
    (re.compile(r"^\s*type\s+\w+\s*="), "the type statement needs Python 3.12"),
]

# Self-check: a detector that matches nothing would pass this test while hiding
# everything. Each snippet must be caught, and each allowed one must not be.
MUST_FLAG = [
    "zip(chapters, texts, strict=True)",
    "match value:",
    "itertools.pairwise(items)",
    "asyncio.timeout(5)",
    "except* ValueError:",
    "import tomllib",
    "type Alias = int",
]
MUST_ALLOW = [
    "merged = first | second",
    "@functools.cache",
    "name.removeprefix('x')",
    "name.removesuffix('x')",
    "for index, raw_path in enumerate(chapters):",
    "# zip(..., strict=True) needs 3.10, so this uses index access",
    "'zip(..., strict=True) sits in a string, not in code'",
]

# Comments and string literals are not code: a comment may name a construct, and
# a guard that fires on documentation of the rule would punish explaining it.
SKIPPED = {
    tokenize.COMMENT,
    tokenize.STRING,
    tokenize.NL,
    tokenize.NEWLINE,
    tokenize.INDENT,
    tokenize.DEDENT,
    tokenize.ENDMARKER,
}


def code_lines(text):
    """Return {row: (spaced, compact)} built from code tokens only."""
    lines = {}
    for token in tokenize.generate_tokens(io.StringIO(text).readline):
        if token.type in SKIPPED:
            continue
        row = token.start[0]
        spaced, compact = lines.setdefault(row, [[], []])
        spaced.append(token.string)
        compact.append(token.string)
    return {
        row: (" ".join(spaced), "".join(compact))
        for row, (spaced, compact) in lines.items()
    }


def hits(text):
    # Two renderings, because the rules need both: keyword rules rely on the
    # spacing that keeps `type Alias` apart, and dotted names need it removed.
    try:
        lines = code_lines(text)
    except (tokenize.TokenError, IndentationError):
        return []
    found = []
    for row in sorted(lines):
        spaced, compact = lines[row]
        for pattern, reason in RULES:
            if pattern.search(spaced) or pattern.search(compact):
                found.append((row, reason))
                break
    return found


problems = []
for snippet in MUST_FLAG:
    if not hits(snippet):
        problems.append("DETECTOR-MISS " + snippet)
for snippet in MUST_ALLOW:
    if hits(snippet):
        problems.append("FALSE-POSITIVE " + snippet)

sources = sorted(root.glob("scripts/**/*.py"))
if not sources:
    problems.append("NO-SOURCES scripts/**/*.py matched nothing")

for source in sources:
    relative = source.relative_to(root)
    text = source.read_text(encoding="utf-8", errors="replace")
    try:
        code_lines(text)
    except (tokenize.TokenError, IndentationError) as exc:
        problems.append(f"UNSCANNABLE {relative}: {exc}")
        continue
    for row, reason in hits(text):
        problems.append(f"{relative}:{row} {reason}")

for line in problems:
    print(line)
print(f"SCANNED {len(sources)}")
PY
)"

  if printf '%s\n' "$output" | grep -qE '^(DETECTOR-MISS|FALSE-POSITIVE|NO-SOURCES|UNSCANNABLE)'; then
    fail "the Python minimum scan is broken: $(printf '%s\n' "$output" | grep -E '^(DETECTOR-MISS|FALSE-POSITIVE|NO-SOURCES|UNSCANNABLE)' | head -3 | tr '\n' ' ')"
  elif printf '%s\n' "$output" | grep -qE '^scripts/'; then
    fail "a construct newer than the declared 3.9 minimum is in the tree: $(printf '%s\n' "$output" | grep -E '^scripts/' | head -3 | tr '\n' ' ')"
  else
    pass "no script uses a construct newer than the declared Python minimum"
  fi
}
