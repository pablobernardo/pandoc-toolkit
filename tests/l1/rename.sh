#!/bin/bash
# Public clean-break contract. Old identifiers below are intentional negative probes.
run_rename_contract_tests() {
  local result message output
  output="$(mktemp)" || { fail "rename contract output file could not be created"; return 1; }
  if "${REAL_PYTHON3}" - "$ROOT_DIR" >"$output" <<'PY'
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(sys.argv[1]).resolve()
cli = root / "bin/skelepress"

def check(ok, message, result=None):
    if not ok and result is not None:
        message += f" (exit={result.returncode}, stdout={result.stdout!r}, stderr={result.stderr!r})"
    print(f"{0 if ok else 1}\t{message}")

with tempfile.TemporaryDirectory(prefix="skelepress-rename-") as directory:
    work = Path(directory)
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(("SKELEPRESS_", "PANDOC_PDF_"))}
    env.update(HOME=str(work), XDG_CONFIG_HOME=str(work / "config"), LC_ALL="C", LANG="C",
               PYTHONDONTWRITEBYTECODE="1")

    def run(*args, extra=None):
        return subprocess.run([str(cli), *args], cwd=work,
                              env=dict(env, **(extra or {})), capture_output=True, text=True)

    def snapshot():
        return {str(p.relative_to(work)): p.read_bytes()
                for p in work.rglob("*") if p.is_file()}

    result = run("--version")
    check((result.returncode, result.stdout, result.stderr) == (0, "skelepress 3.0.0\n", ""),
          "renamed version has exact identity and major version", result)
    check(not (root / "bin/pandoc-pdf").exists(), "old CLI entrypoint is absent")
    result = run("--help")
    check(result.returncode == 0 and result.stderr == "" and "Skelepress CLI" in result.stdout
          and "skelepress.config.yaml" in result.stdout and "SKELEPRESS_UPDATE_HOME" in result.stdout
          and not any(s in result.stdout for s in ("pandoc-pdf", "PANDOC_PDF", "pdf.config.yaml")),
          "help advertises only the new command, config and environment", result)

    result = run("locale", "show", extra={"SKELEPRESS_LANG": "en", "PANDOC_PDF_LANG": "es"})
    check((result.returncode, result.stdout, result.stderr) ==
          (0, "language: en\nsource: SKELEPRESS_LANG\n", ""),
          "new locale variable wins and old variable is ignored", result)
    result = run("locale", "show", extra={"PANDOC_PDF_LANG": "es"})
    check((result.returncode, result.stdout, result.stderr) ==
          (0, "language: en\nsource: LC_ALL\n", ""),
          "old locale variable alone has no effect", result)

    # No implicit loader: neither filename substitutes for the required flag.
    config = root / "examples/no-titlepage/skelepress.config.yaml"
    (work / "chapters").mkdir()
    for filename in ("skelepress.config.yaml", "pdf.config.yaml"):
        (work / filename).write_bytes(config.read_bytes())
    for command in ("render", "validate-config"):
        before = snapshot()
        result = run(command)
        check((result.returncode, result.stdout, result.stderr) ==
              (1, "❌ You must provide -c <skelepress.config.yaml>\n", "")
              and snapshot() == before,
              f"{command} still requires explicit config and rejection changes nothing", result)
    # Basenames are not validation rules: explicit historical/arbitrary names
    # remain ordinary paths, not aliases or fallback loading.
    for filename in ("skelepress.config.yaml", "pdf.config.yaml", "custom.yaml"):
        path = work / filename
        path.write_bytes(config.read_bytes())
        before = snapshot()
        result = run("validate-config", "--config", str(path))
        check((result.returncode, result.stdout, result.stderr) == (0, "✅ Config valid\n", "")
              and snapshot() == before,
              f"explicit config path remains supported: {filename}", result)

    result = run("info", "--json")
    data = json.loads(result.stdout)
    check(result.returncode == 0 and result.stderr == "" and data["name"] == "skelepress"
          and data["schema_path"] == str(root / "schemas/skelepress-config.schema.json")
          and data["schema_exists"], "info preserves JSON contract with renamed schema", result)

    out = work / "book-output"
    result = run("book", str(root / "examples/book-kit/single"), "--check", "--out", str(out))
    check(result.returncode == 0 and result.stderr == ""
          and (out / "single/skelepress.config.yaml").is_file()
          and not list(out.rglob("pdf.config.yaml")),
          "book emits only the new configuration filename", result)

    # HOME and every install override are isolated; no existing installation is touched.
    old_root = work / ".local/share/pandoc-pdf"
    old_root.mkdir(parents=True)
    marker = old_root / "untouched"
    marker.write_text("historical installation\n")
    install_env = dict(env, PANDOC_PDF_INSTALL_HOME=str(work / "old-override"),
                       PANDOC_PDF_INSTALL_DIR=str(work / "old-bin"))
    result = subprocess.run(["/bin/bash", str(root / "scripts/delivery/install-local.sh")],
                            cwd=work, env=install_env, capture_output=True, text=True)
    check(result.returncode == 0 and result.stderr == ""
          and (work / ".local/share/skelepress/current/bin/skelepress").is_file()
          and (work / ".local/bin/skelepress").is_symlink()
          and not (work / ".local/bin/pandoc-pdf").exists()
          and not (work / "old-override").exists() and not (work / "old-bin").exists()
          and marker.read_text() == "historical installation\n",
          "installer uses new default root, ignores old overrides and creates no shim", result)
    install_env.update(SKELEPRESS_INSTALL_HOME=str(work / "managed"),
                       SKELEPRESS_INSTALL_DIR=str(work / "new-bin"))
    result = subprocess.run(["/bin/bash", str(root / "scripts/delivery/install-local.sh"), "dev"],
                            cwd=work, env=install_env, capture_output=True, text=True)
    check(result.returncode == 0 and result.stderr == ""
          and (work / "managed/versions/v3.0.0-dev/bin/skelepress").is_file()
          and (work / "new-bin/skelepress-dev").is_symlink()
          and not (work / "new-bin/pandoc-pdf-dev").exists()
          and not (work / "managed/current").exists(),
          "installer honors new overrides and preserves separate development layout", result)
PY
  then
    while IFS=$'\t' read -r result message; do
      if [[ "$result" == "0" ]]; then pass "$message"; else fail "$message"; fi
    done < "$output"
  else
    rm -f "$output"
    fail "rename contract producer failed"
    return 1
  fi
  rm -f "$output"
}

run_rename_symlink_root_test() {
  local sandbox code=0
  sandbox="$(mktemp -d)"
  ln -s "$ROOT_DIR" "${sandbox}/checkout"

  /bin/bash -s -- "${sandbox}/checkout" "$REAL_PYTHON3" \
    >"${sandbox}/stdout" 2>"${sandbox}/stderr" <<'BASH' || code=$?
set -euo pipefail
ROOT_DIR="$1"
REAL_PYTHON3="$2"
PASS=0
FAIL=0
source "${ROOT_DIR}/tests/lib.sh"
source "${ROOT_DIR}/tests/l1/rename.sh"
run_rename_contract_tests
printf "Summary: PASS=%s FAIL=%s\n" "$PASS" "$FAIL"
[[ "$FAIL" -eq 0 ]]
BASH

  if [[ "$code" -ne 0 ]]; then
    printf 'Symlink-root probe stdout:\n%s\n' "$(<"${sandbox}/stdout")"
    printf 'Symlink-root probe stderr:\n%s\n' "$(<"${sandbox}/stderr")"
  fi
  assert_exit_code "0" "$code" "rename contract passes through a symlink root"
  assert_contains "${sandbox}/stdout" '^Summary: PASS=14 FAIL=0$' \
    "symlink-root probe preserves all fourteen rename assertions"
  if [[ ! -s "${sandbox}/stderr" ]]; then
    pass "symlink-root probe has empty stderr"
  else
    fail "symlink-root probe has empty stderr"
  fi

  rm -rf "$sandbox"
}
