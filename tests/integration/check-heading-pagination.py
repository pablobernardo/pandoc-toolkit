#!/usr/bin/env python3
"""Render through the public CLI and check headings against extracted PDF pages.

Requires pandoc, xelatex and pdftotext. Keeps the review PDF in examples/.output/.
Run from any directory: python3 tests/integration/check-heading-pagination.py
"""
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "examples/.output/heading-review"
WORK.mkdir(parents=True, exist_ok=True)

# Leave very little space on a page, then ask the normal renderer to place a
# heading and its content. Explicit page breaks isolate the individual cases.
near_bottom = "\n\\clearpage\n\\null\n\\vspace*{\\dimexpr\\textheight-4\\baselineskip\\relax}\n\n"
cases = []
checks = []
for level in range(1, 6):
    heading = f"HeadingLevel{level}"
    body = f"ContentLevel{level}"
    cases.append(near_bottom + "#" * level + f" {heading}\n\n{body} starts here. "
                 + "This paragraph provides several lines of ordinary text. " * 12 + "\n")
    checks.append((heading, body))

for heading, content, marker in [
    ("HeadingBeforeList", "- ListContent starts here.\n- Another item.\n", "ListContent"),
    ("HeadingBeforeCode", "```bash\necho CodeContent\n```\n", "CodeContent"),
    ("HeadingBeforeTable", "| TableContent | Value |\n| --- | --- |\n| Example | One |\n", "TableContent"),
]:
    cases.append(near_bottom + f"## {heading}\n\n" + content)
    checks.append((heading, marker))
cases.append(near_bottom + "## ParentHeading\n\n### ChildHeading\n\nConsecutiveContent starts here.\n")
checks.extend([("ParentHeading", "ChildHeading"), ("ChildHeading", "ConsecutiveContent")])
(WORK / "headings.md").write_text("".join(cases))
config = {
    "version": 1,
    "project": {"name": "heading-review", "base_dir": "../../.."},
    "document": {"title": "Heading pagination review", "language": "en", "titlepage": False},
    "input": {"chapters_dir": "examples/.output/heading-review", "glob": "*.md",
              "order": "natural", "explicit_files": ["headings.md"]},
    "output": {"dir": "examples/.output/heading-review", "file_prefix": "heading-pagination",
               "suffix": "review", "keep_merged_markdown": True},
    "pandoc": {"pdf_engine": "xelatex", "toc": False, "toc_depth": 3, "number_sections": False,
               "resource_path": ["."]},
    "filters": {"emoji": {"enabled": False}, "mermaid": {"enabled": False}, "extra_lua_filters": []},
    "runtime": {"required_commands": ["pandoc", "xelatex"], "strict": True},
    "compat": {"legacy_clearpage_between_h1": False},
}
config_path = WORK / "config.json"
config_path.write_text(json.dumps(config, indent=2) + "\n")
result = subprocess.run([str(ROOT / "bin/pandoc-pdf"), "render", "-c", str(config_path)],
                        cwd=ROOT, capture_output=True, text=True, timeout=120)
(WORK / "render.log").write_text(result.stdout + result.stderr)
if result.returncode:
    raise SystemExit(result.stdout + result.stderr)
pdf = WORK / "heading-pagination-review.pdf"
result = subprocess.run(["pdftotext", "-layout", str(pdf), "-"],
                        capture_output=True, text=True, check=True, timeout=15)
pages = result.stdout.split("\f")
for heading, marker in checks:
    heading_pages = [i for i, page in enumerate(pages) if heading in page]
    marker_pages = [i for i, page in enumerate(pages) if marker in page]
    assert len(heading_pages) == len(marker_pages) == 1, (heading, marker, "missing or duplicated")
    assert heading_pages == marker_pages, (heading, marker, "orphaned heading")
    print(f"PASS: {heading} stays with {marker} on PDF page {heading_pages[0] + 1}")
print(f"Review PDF: {pdf.relative_to(ROOT)}")
