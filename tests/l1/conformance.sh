#!/bin/bash
# Exercise the checker through its public interface; all mutations stay in temp trees.
run_plan_conformance_tests() {
  local result message
  while IFS=$'\t' read -r result message; do
    if [[ "$result" == "0" ]]; then pass "$message"; else fail "$message"; fi
  done < <("${REAL_PYTHON3}" - "$ROOT_DIR" "$CLI" <<'PY'
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

root = Path(sys.argv[1])
checker = root / "scripts/check-plan-conformance.py"
env = dict(os.environ, PANDOC_PDF_BIN=sys.argv[2], PANDOC_PDF_LANG="en")

def check(ok, message):
    print(f"{0 if ok else 1}\t{message}")

def run(tree, *args):
    return subprocess.run([sys.executable, str(checker), str(tree), *args],
                          env=env, capture_output=True, text=True)

cases = sorted((root / "tests/conformance/cases").glob("*.yaml"))
check(len(cases) >= 4, "conformance discovers at least four cases")
result = run(root)
check(result.returncode == 0 and f"{len(cases)} case(s) conform" in result.stdout,
      "all recorded render plans conform")
version = (root / "VERSION").read_text().strip()
literal = sorted(p.name for p in (root / "tests/conformance/expected").glob("*.json")
                 if f'"{version}"' in p.read_text())
check(not literal, f"expectations do not record the toolkit version ({version})")
for case in cases:
    result = subprocess.run([sys.argv[2], "validate-config", "-c", str(case)],
                            env=env, capture_output=True, text=True)
    check(result.returncode == 0, f"conformance config validates: {case.stem}")
with tempfile.TemporaryDirectory(prefix="plan-conformance-") as directory:
    tree = Path(directory)
    shutil.copytree(root / "tests/conformance", tree / "tests/conformance")
    expected = tree / "tests/conformance/expected/minimal.plan.json"
    if not expected.exists():
        check(False, "perturbed expectation fails and names minimal with a readable diff")
        check(False, "missing expectation fails and names added case")
        check(False, "update regenerates expectations and relocated cases conform")
        check(False, "JSON object key order is ignored")
        check(False, "JSON array order remains significant")
        sys.exit(0)
    original = expected.read_text()
    payload = json.loads(original)
    payload["plan_version"] = 999
    expected.write_text(json.dumps(payload))
    result = run(tree)
    check(result.returncode == 1 and "minimal" in result.stderr
          and "--- expected" in result.stderr and "+++ actual" in result.stderr
          and "999" in result.stderr, "perturbed expectation fails and names minimal with a readable diff")
    expected.write_text(original)
    added = tree / "tests/conformance/cases/added.yaml"
    shutil.copyfile(tree / "tests/conformance/cases/minimal.yaml", added)
    result = run(tree)
    check(result.returncode == 1 and "added" in result.stderr
          and "Missing expected plan" in result.stderr,
          "missing expectation fails and names added case")
    result = run(tree, "--update")
    rerun = run(tree)
    check(result.returncode == 0 and rerun.returncode == 0
          and "5 case(s) conform" in rerun.stdout,
          "update regenerates expectations and relocated cases conform")
    payload = json.loads(expected.read_text())
    expected.write_text(json.dumps(dict(reversed(list(payload.items())))))
    check(run(tree).returncode == 0, "JSON object key order is ignored")
    payload["pandoc"]["argv"].reverse()
    expected.write_text(json.dumps(payload))
    result = run(tree)
    check(result.returncode == 1 and "minimal" in result.stderr,
          "JSON array order remains significant")
PY
  )
}
