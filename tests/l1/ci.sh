#!/bin/bash
# CI dependency declarations; real package installation/rendering runs in L2/L3.

run_ci_render_dependencies_test() {
  local rule
  for rule in fonts svg existing template browser; do
    if python3 - "${ROOT_DIR}/.github/workflows/ci.yml" "$rule" <<'PY'
import re
import shlex
import sys
from pathlib import Path

workflow = Path(sys.argv[1]).read_text().replace("\\\n", " ")
previous = {
    "l2-render-integration": {"pandoc", "texlive-latex-base"},
    "l3-render-full": {"pandoc", "texlive-latex-base", "texlive-xetex", "nodejs", "npm"},
}
for job, old_packages in previous.items():
    block = re.search(r"^  " + job + r":\n(.*?)(?=^  [\w-]+:|\Z)", workflow, re.M | re.S)
    assert block, f"Missing integration job: {job}"
    commands = re.findall(r"^\s+sudo apt-get install -y (.+)$", block[1], re.M)
    packages = {package for command in commands for package in shlex.split(command)}
    rule = sys.argv[2]
    if rule == "browser":
        if job == "l3-render-full":
            assert "chromium-browser" not in packages, "Do not install Snap Chromium in L3"
            assert 'chrome_path="$(command -v google-chrome)"' in block[1]
            assert 'test -x "$chrome_path"' in block[1]
            assert 'test -r "$(npm root -g)/@mermaid-js/mermaid-cli/dist/index.html"' in block[1]
            assert 'PUPPETEER_EXECUTABLE_PATH="$chrome_path" bash tests/l3-local.sh' in block[1]
            assert "@mermaid-js/mermaid-cli@10.9.1" in block[1]
            assert "--no-sandbox" not in block[1]
        continue
    required = {
        "fonts": {"texlive-fonts-recommended"}, "svg": {"librsvg2-bin"},
        "existing": old_packages, "template": {"texlive-latex-extra"},
    }[rule]
    assert required <= packages, f"{job}: missing {sorted(required - packages)}"
    if rule == "template":
        assert "kpsewhich" in block[1] and "templates/default.tex" in block[1]
PY
    then
      pass "CI render dependencies: ${rule} in both L2 and L3"
    else
      fail "CI render dependencies: ${rule} in both L2 and L3"
    fi
  done
}
