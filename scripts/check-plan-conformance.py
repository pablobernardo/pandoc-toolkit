#!/usr/bin/env python3
"""Compare public render plans with recorded, implementation-independent JSON.

Normalization (recursively, including argv option values and path lists):
* the absolute case filename becomes <CASE>, its directory becomes <CASES>;
* the suite root and the CLI-reported toolkit root become <REPO>;
* the toolkit version becomes <VERSION>, so a release does not break every
  expectation;
* absolute system temporary directories become <TMP> (the first directory
  below the system temp root is treated as the volatile allocation name);
* other absolute paths become <ABS>/<basename>, removing machine-local parents.
Known prefixes win over temporary/absolute fallbacks; path suffixes and array
order are retained. No fields, versions, booleans, or non-path values are ignored.
Cases use a literal output suffix, not the renderer's current-date substitution.
The checker does not parse YAML or import the renderer. ROOT is the tree holding
tests/conformance; PANDOC_PDF_BIN selects a different CLI installation.
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path, PurePosixPath, PureWindowsPath


def normalize(plan: object, root: Path, case: Path) -> object:
    toolkit = plan.get("toolkit", {}) if isinstance(plan, dict) else {}
    installed = toolkit.get("root") if isinstance(toolkit, dict) else None
    prefixes = [(str(case), "<CASE>"), (str(case.parent), "<CASES>"),
                (str(root), "<REPO>")]
    if isinstance(installed, str) and Path(installed).is_absolute():
        prefixes.append((installed, "<REPO>"))
    prefixes.sort(key=lambda item: len(item[0]), reverse=True)
    # Recognition only: these directories are never opened or written here.
    temp_roots = {tempfile.gettempdir(), "/tmp", "/private/tmp", "/var/tmp"}  # noqa: S108

    def path_value(value: str) -> str:
        for prefix, token in prefixes:
            if value == prefix or value.startswith(prefix + "/"):
                return token + value[len(prefix):]
        for prefix in sorted(temp_roots, key=len, reverse=True):
            if value.startswith(prefix.rstrip("/") + "/"):
                parts = value[len(prefix.rstrip("/")) + 1:].split("/")
                return "/".join(["<TMP>"] + parts[1:])
        if PureWindowsPath(value).is_absolute():
            return "<ABS>/" + PureWindowsPath(value).name
        if PurePosixPath(value).is_absolute():
            return "<ABS>/" + PurePosixPath(value).name
        return value

    def visit(value: object) -> object:
        if isinstance(value, dict):
            return {key: visit(item) for key, item in value.items()}
        if isinstance(value, list):
            return [visit(item) for item in value]
        if isinstance(value, str):
            # Pandoc embeds paths in --option=value and colon-separated lists.
            option, separator, argument = value.partition("=")
            raw = argument if separator else value
            normalized = (
                ":".join(path_value(part) for part in raw.split(os.pathsep))
                if option == "--resource-path" and separator else path_value(raw)
            )
            return option + separator + normalized if separator else normalized
        return value

    normalized = visit(plan)
    # The version changes on release and says nothing about conformance: recording
    # it would break every expectation on each bump, which is the kind of friction
    # that gets a check disabled.
    if isinstance(normalized, dict):
        toolkit = normalized.get("toolkit")
        if isinstance(toolkit, dict) and "version" in toolkit:
            toolkit["version"] = "<VERSION>"
    return normalized


def formatted(value: object) -> str:
    return json.dumps(value, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("root", nargs="?", type=Path,
                        default=Path(__file__).resolve().parent.parent,
                        help="tree containing tests/conformance (default: repository)")
    parser.add_argument("--update", action="store_true",
                        help="regenerate recorded expectations from the selected CLI")
    args = parser.parse_args()
    root = args.root.resolve()
    suite = root / "tests/conformance"
    cases = sorted((suite / "cases").glob("*.yaml"))
    if not cases:
        print(f"No conformance cases found in {suite / 'cases'}", file=sys.stderr)
        return 1
    cli = os.environ.get("PANDOC_PDF_BIN") or str(root / "bin/pandoc-pdf")
    for case in cases:
        expected = suite / "expected" / f"{case.stem}.plan.json"
        try:
            if not args.update and not expected.is_file():
                print(f"{case.stem}: Missing expected plan: {expected}", file=sys.stderr)
                return 1
            result = subprocess.run(
                [cli, "render", "-c", str(case), "--dry-run", "--json"],
                capture_output=True, text=True,
                env=dict(os.environ, PANDOC_PDF_LANG="en"),
            )
            if result.returncode:
                print(f"{case.stem}: CLI exited {result.returncode}\n"
                      f"{result.stdout}{result.stderr}", file=sys.stderr)
                return 1
            actual = normalize(json.loads(result.stdout), root, case)
            if args.update:
                expected.parent.mkdir(parents=True, exist_ok=True)
                expected.write_text(formatted(actual), encoding="utf-8")
            else:
                recorded = json.loads(expected.read_text(encoding="utf-8"))
                # Canonical serialization also distinguishes true from 1.
                if formatted(recorded) != formatted(actual):
                    print(f"{case.stem}: render plan differs", file=sys.stderr)
                    print("".join(difflib.unified_diff(
                        formatted(recorded).splitlines(keepends=True),
                        formatted(actual).splitlines(keepends=True),
                        fromfile="expected", tofile="actual", n=3,
                    )), end="", file=sys.stderr)
                    return 1
        except (OSError, ValueError) as error:
            print(f"{case.stem}: {error}", file=sys.stderr)
            return 1
    action = "updated" if args.update else "conform"
    print(f"{len(cases)} case(s) {action}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
