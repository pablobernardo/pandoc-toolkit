#!/usr/bin/env python3
"""Check that the Markdown in the tree points at things that exist.

Two classes of drift are caught, because both have happened here:

1. A relative link (`[text](docs/foo.md)`) whose target was renamed or removed.
2. A backticked repository path (`docs/foo.md`) mentioned in prose, which no
   link checker sees but which also goes stale.

Fenced code blocks are skipped: examples inside them are illustrative, not
references. Usage: check-docs.py [root]
"""

from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

REPO_ROOTS = (
    ".agents", ".github", "bin", "docs", "examples", "filters", "i18n",
    "odd", "schemas", "scripts", "templates", "tests",
)
LINK = re.compile(r"\[[^\]]*\]\(([^)\s]+)")
# A path mention is a backticked token anchored on a real top-level directory
# and ending in a file extension, so prose like `pdf.config.yaml` is ignored.
_ROOTS = "|".join(re.escape(r) for r in REPO_ROOTS)
MENTION = re.compile(rf"`((?:{_ROOTS})/[\w./-]*\.\w+)`")

# Files that record history are allowed to name what was removed: that is their
# job. Everything else must point at something that exists today.
HISTORY = {"CHANGELOG.md"}
HISTORY_PREFIXES = ("odd/",)


def markdown_files(root: Path) -> list[Path]:
    return sorted(
        p for p in root.rglob("*.md")
        if ".git" not in p.parts and "node_modules" not in p.parts
    )


def references(text: str):
    """Yield (kind, target) for each reference outside a fenced code block."""
    fenced = False
    for number, line in enumerate(text.splitlines(), start=1):
        if line.lstrip().startswith("```"):
            fenced = not fenced
            continue
        if fenced:
            continue
        for match in LINK.finditer(line):
            target = match.group(1).split("#", 1)[0]
            if target and not target.startswith(("http://", "https://", "mailto:", "/")):
                yield number, "link", target
        for match in MENTION.finditer(line):
            yield number, "mention", match.group(1)


PERSONAL_PATH = re.compile(r"/(?:Users|home)/[A-Za-z0-9._-]+/")
TEXT_SUFFIXES = {
    ".md", ".py", ".sh", ".lua", ".yaml", ".yml", ".json", ".tex", ".txt",
    ".toml", ".cfg", ".ini",
}


def published_files(root: Path) -> list[Path]:
    """The files that would ship: git's index, or the tree when there is no git."""
    try:
        listed = subprocess.run(
            ["git", "-C", str(root), "ls-files", "-z"],
            capture_output=True, text=True, check=True,
        ).stdout
        return [root / name for name in listed.split("\0") if name]
    except (OSError, subprocess.SubprocessError):
        skip = {".git", "node_modules", ".atl"}
        return [
            path for path in root.rglob("*")
            if path.is_file() and not skip & set(path.parts)
        ]


def personal_paths(root: Path) -> list[str]:
    """Absolute home paths leak a machine's layout into a published repository."""
    problems = []
    for path in published_files(root):
        if path.suffix not in TEXT_SUFFIXES:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        for number, line in enumerate(text.splitlines(), start=1):
            if PERSONAL_PATH.search(line):
                problems.append(
                    f"{path.relative_to(root)}:{number}: absolute home path in a published file"
                )
    return problems


def main() -> int:
    root = Path(sys.argv[1] if len(sys.argv) > 1 else ".").resolve()
    problems: list[str] = []
    files = markdown_files(root)

    for path in files:
        relative = path.relative_to(root)
        for line, kind, target in references(path.read_text(encoding="utf-8")):
            if (kind == "mention"
                    and (relative.as_posix() in HISTORY
                         or relative.as_posix().startswith(HISTORY_PREFIXES))):
                continue
            if (path.parent / target).exists() or (root / target).exists():
                continue
            problems.append(f"{relative}:{line}: {kind} to missing {target}")

    problems.extend(personal_paths(root))

    for problem in problems:
        print(f"❌ {problem}")

    if problems:
        print(f"❌ {len(problems)} reference(s) point at something that does not exist")
        return 1

    print(f"✅ docs OK: {len(files)} markdown files, no broken reference")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
