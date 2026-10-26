"""Test double for PyYAML, used only by tests/run.sh.

Parses YAML by delegating to Ruby's stdlib YAML (already a supported parser of
this toolkit) and returning the equivalent plain Python data. It exists so the
Python renderer path can be exercised on machines without PyYAML installed.

Not shipped: it lives under tests/ and is injected through PYTHONPATH.
"""

from __future__ import annotations

import json
import shutil
import subprocess

_RUBY_SCRIPT = r"""
require 'yaml'
require 'json'
data = YAML.safe_load(STDIN.read, permitted_classes: [], aliases: false)
puts JSON.generate(data)
"""


def safe_load(text):
    """Return the YAML document in *text* as plain Python data."""
    ruby = shutil.which("ruby")
    if ruby is None:
        raise RuntimeError("yaml shim requires ruby in PATH")

    proc = subprocess.run(
        [ruby, "-e", _RUBY_SCRIPT],
        input=text,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or "ruby YAML parse failed")

    return json.loads(proc.stdout)
