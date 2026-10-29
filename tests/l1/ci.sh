#!/bin/bash
# CI dependency declarations; real package installation/rendering runs in L2/L3.

run_ci_render_dependencies_test() {
  local rule
  for rule in fonts svg existing; do
    if python3 - "${ROOT_DIR}/.github/workflows/ci.yml" "$rule" <<'PY'
import re
import shlex
import sys
from pathlib import Path

workflow = Path(sys.argv[1]).read_text().replace("\\\n", " ")
previous = {
    "l2-render-integration": {"pandoc", "texlive-latex-base"},
    "l3-render-full": {"pandoc", "texlive-latex-base", "texlive-xetex", "nodejs", "npm", "chromium-browser"},
}
for job, old_packages in previous.items():
    block = re.search(r"^  " + job + r":\n(.*?)(?=^  [\w-]+:|\Z)", workflow, re.M | re.S)
    assert block, f"Missing integration job: {job}"
    commands = re.findall(r"^\s+sudo apt-get install -y (.+)$", block[1], re.M)
    packages = {package for command in commands for package in shlex.split(command)}
    required = {"fonts": {"texlive-fonts-recommended"}, "svg": {"librsvg2-bin"}, "existing": old_packages}[sys.argv[2]]
    assert required <= packages, f"{job}: missing {sorted(required - packages)}"
PY
    then
      pass "CI render dependencies: ${rule} in both L2 and L3"
    else
      fail "CI render dependencies: ${rule} in both L2 and L3"
    fi
  done
}
