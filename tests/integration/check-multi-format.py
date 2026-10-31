#!/usr/bin/env python3
"""Exercise multi-format behavior through the public CLI in isolated projects."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


class FormatsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root / "chapters").mkdir()
        (self.root / "chapters/one.md").write_text("# One\n\nHello.\n")
        self.config = {
            "version": 1, "project": {"name": "formats", "base_dir": str(self.root)},
            "document": {"title": "Formats", "author": "Example Author"},
            "input": {"chapters_dir": "chapters", "glob": "*.md", "order": "natural", "explicit_files": []},
            "output": {"dir": "out", "suffix": "test", "keep_merged_markdown": False},
            "pandoc": {"pdf_engine": "xelatex", "toc": True, "toc_depth": 2,
                       "number_sections": False, "resource_path": ["chapters"]},
            "filters": {"emoji": {"enabled": False}, "mermaid": {"enabled": False}, "extra_lua_filters": []},
            "runtime": {"required_commands": ["pandoc"], "strict": True},
        }
        self.bin = self.root / "bin"
        self.bin.mkdir()
        for name in ("pandoc", "xelatex"):
            p = self.bin / name
            p.write_text(f"#!{sys.executable}\n" + '''import os, pathlib, sys
if "-o" in sys.argv:
    target = pathlib.Path(sys.argv[sys.argv.index("-o") + 1])
    if target.suffix == os.environ.get("FAIL_SUFFIX"):
        print("fixture render failure", file=sys.stderr)
        sys.exit(7)
    target.write_text("fixture artifact")
''')
            p.chmod(0o755)
        self.env = {**os.environ, "PANDOC_PDF_LANG": "en", "PATH": str(self.bin) + os.pathsep + os.environ["PATH"]}

    def run_cli(self, *args):
        path = self.root / "pdf.config.yaml"
        path.write_text(json.dumps(self.config))
        return subprocess.run([str(ROOT / "bin/pandoc-pdf"), *args, "-c", str(path)],
                              capture_output=True, text=True, env=self.env)

    def test_default_and_explicit_pdf_plan(self):
        default = self.run_cli("render", "--dry-run", "--json")
        self.config["output"]["formats"] = ["pdf"]
        explicit = self.run_cli("render", "--dry-run", "--json")
        self.assertEqual((default.returncode, default.stdout, default.stderr),
                         (explicit.returncode, explicit.stdout, explicit.stderr))
        self.assertEqual(default.returncode, 0)
        self.assertEqual(json.loads(default.stdout)["plan_version"], 1)
        self.assertFalse((self.root / "out").exists())

    def test_ordered_multi_plan_and_human_output(self):
        for formats in (["pdf", "epub"], ["epub", "pdf"]):
            self.config["output"]["formats"] = formats
            result = self.run_cli("render", "--dry-run", "--json")
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            plan = json.loads(result.stdout)
            self.assertEqual(plan["plan_version"], 2)
            self.assertEqual([next(k for k in j["pandoc"]["target"] if k != "markdown") for j in plan["jobs"]], formats)
            human = self.run_cli("render", "--dry-run")
            self.assertEqual(human.returncode, 0, human.stdout + human.stderr)
            self.assertIn(".pdf", human.stdout)
            self.assertIn(".epub", human.stdout)
            self.assertFalse((self.root / "out").exists())

    def test_invalid_selection_has_no_side_effects(self):
        for value in ([], "epub", ["mobi"], ["pdf", "mobi"]):
            self.config["output"]["formats"] = value
            result = self.run_cli("render")
            self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
            self.assertEqual(result.stderr, "")
            self.assertIn("output.formats", result.stdout)
            self.assertFalse((self.root / "out").exists())
        del self.config["output"]["formats"]
        self.config["output"]["format"] = "epub"
        result = self.run_cli("render")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "❌ In 'output' there are disallowed fields: format\n")
        self.assertEqual(result.stderr, "")
        self.assertFalse((self.root / "out").exists())

    def test_preflight_requires_union_of_formats(self):
        self.config["pandoc"]["pdf_engine"] = "missing-test-engine"
        self.config["output"]["formats"] = ["epub"]
        epub = self.run_cli("doctor")
        self.assertEqual(epub.returncode, 0, epub.stdout + epub.stderr)
        self.config["output"]["formats"] = ["epub", "pdf"]
        both = self.run_cli("doctor")
        self.assertEqual(both.returncode, 1)
        self.assertIn("missing-test-engine", both.stdout)
        self.assertEqual(both.stderr, "")
        self.assertFalse((self.root / "out").exists())
        self.config["output"]["formats"] = ["epub"]
        self.config["runtime"]["required_commands"].append("missing-test-engine")
        explicit = self.run_cli("doctor")
        self.assertEqual(explicit.returncode, 1)
        self.assertIn("missing-test-engine", explicit.stdout)
        self.assertEqual(explicit.stderr, "")

    def test_minimal_preflight_multiline_flow_formats_requires_pdf_engine(self):
        python = self.bin / "python3"
        python.write_text(f'#!/bin/sh\nexec "{sys.executable}" -S "$@"\n')
        python.chmod(0o755)
        path = self.root / "pdf.config.yaml"
        path.write_text(
            "output:\n  formats: [\n    epub,\n    pdf\n  ]\n"
            "pandoc:\n  pdf_engine: missing-test-engine\n"
            "runtime:\n  required_commands: [pandoc]\n  strict: true\n"
        )
        before = path.read_bytes()
        result = subprocess.run([str(ROOT / "bin/pandoc-pdf"), "doctor", "-c", str(path)],
                                capture_output=True, text=True, env=self.env)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stdout, "❌ Doctor detected missing dependencies:\n   - missing-test-engine\n")
        self.assertEqual(result.stderr, "")
        self.assertEqual(path.read_bytes(), before)
        self.assertFalse((self.root / "out").exists())

    def test_both_outputs_and_markdown_cleanup(self):
        self.config["output"]["formats"] = ["pdf", "epub", "pdf"]
        result = self.run_cli("render")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(result.stderr, "")
        for ext in ("pdf", "epub"):
            self.assertEqual((self.root / f"out/formats-test.{ext}").read_text(), "fixture artifact")
        self.assertFalse((self.root / "out/formats-test.md").exists())
        self.assertEqual(result.stdout.count("Native mode enabled"), 2)

    def test_partial_failures_keep_successes_in_both_orders(self):
        for formats in (["pdf", "epub"], ["epub", "pdf"]):
            for failed in formats:
                with self.subTest(formats=formats, failed=failed):
                    self.config["output"]["formats"] = formats
                    self.env["FAIL_SUFFIX"] = "." + failed
                    for p in (self.root / "out").glob("*"):
                        p.unlink()
                    result = self.run_cli("render")
                    self.assertEqual(result.returncode, 1)
                    self.assertEqual(result.stderr, "fixture render failure\n")
                    self.assertIn(f"Export failed ({failed})", result.stdout)
                    good = "epub" if failed == "pdf" else "pdf"
                    self.assertEqual((self.root / f"out/formats-test.{good}").read_text(), "fixture artifact")
                    self.assertFalse((self.root / f"out/formats-test.{failed}").exists())
                    self.assertTrue((self.root / "out/formats-test.md").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
