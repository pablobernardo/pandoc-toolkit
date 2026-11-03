#!/usr/bin/env python3
from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def _to_int(value: str, default: int) -> int:
    try:
        return int(value)
    except Exception:
        return default


def _load_sarif(path: Path) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        raise SystemExit(f"❌ Could not parse SARIF file {path}: {exc}")

    if not isinstance(data, dict):
        raise SystemExit(f"❌ Invalid SARIF payload in {path}: root must be object")
    return data


def _count_levels(payload: dict) -> dict[str, int]:
    counts = {"error": 0, "warning": 0, "note": 0, "none": 0}
    runs = payload.get("runs", [])
    if not isinstance(runs, list):
        return counts

    for run in runs:
        if not isinstance(run, dict):
            continue
        results = run.get("results", [])
        if not isinstance(results, list):
            continue
        for result in results:
            if not isinstance(result, dict):
                continue
            level = result.get("level", "warning")
            if not isinstance(level, str):
                level = "warning"
            level = level.lower()
            if level not in counts:
                level = "warning"
            counts[level] += 1
    return counts


def main() -> None:
    if len(sys.argv) != 3:
        raise SystemExit("Usage: enforce-security-thresholds.py <sarif-file> <tool>")

    sarif_file = Path(sys.argv[1]).resolve()
    tool = sys.argv[2].strip().lower()
    if tool not in {"semgrep", "gitleaks"}:
        raise SystemExit("❌ Tool must be one of: semgrep, gitleaks")

    payload = _load_sarif(sarif_file)
    counts = _count_levels(payload)

    env_prefix = tool.upper()
    error_threshold = _to_int(os.getenv(f"{env_prefix}_ERROR_THRESHOLD", "0"), 0)
    warning_threshold = _to_int(os.getenv(f"{env_prefix}_WARNING_THRESHOLD", "0"), 0)

    errors = counts["error"]
    warnings = counts["warning"]
    notes = counts["note"]

    print(
        f"[{tool}] findings: error={errors}, warning={warnings}, note={notes} "
        f"(max-allowed error={error_threshold}, warning={warning_threshold})"
    )

    violations: list[str] = []
    if errors > error_threshold:
        violations.append(f"error findings ({errors}) exceed max allowed {error_threshold}")
    if warnings > warning_threshold:
        violations.append(f"warning findings ({warnings}) exceed max allowed {warning_threshold}")

    if violations:
        raise SystemExit(f"❌ {tool} threshold violation: {'; '.join(violations)}")


if __name__ == "__main__":
    main()
