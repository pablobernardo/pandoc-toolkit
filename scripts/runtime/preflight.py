#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
import sys
from pathlib import Path

try:
    from i18n_runtime import t
except Exception:
    def t(_key: str, fallback: str, **kwargs: object) -> str:
        try:
            return fallback.format(**kwargs)
        except Exception:
            return fallback

try:
    from schema_runtime import YamlError, load_yaml_with_python, load_yaml_with_ruby
except Exception:  # imported as a module from elsewhere: fix the path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from schema_runtime import YamlError, load_yaml_with_python, load_yaml_with_ruby


DEFAULT_REQUIRED = ["pandoc", "python3", "curl", "mmdc"]
# The minimum interpreter the renderer runs on: the Python macOS ships
# (3.9.6). bin/skelepress starts render-native.py with `python3` from PATH, so
# doctor checks that resolved interpreter, and an older one cannot render.
PYTHON_MINIMUM = (3, 9)
TEX_ENGINES = ["xelatex", "lualatex", "pdflatex"]
FORMAT_PDF = "pdf"
FORMAT_EPUB = "epub"


def fail(msg: str) -> None:
    print(msg)
    raise SystemExit(1)


def load_config_for_preflight(path: Path):
    """Read the config with the best parser reachable, degrading in order.

    The full parser goes first, the minimal reader second (so an environment
    without PyYAML still answers the few keys doctor needs), and Ruby last. Both
    parsers come from ``schema_runtime``, the toolkit's single YAML rule, so the
    gate cannot disagree with ``validate-config`` about what a file says.

    A file the parser actually rejected is a user error, not a reason to
    degrade, so it fails with the preflight wording instead of being retried.
    """
    cfg = None
    try:
        cfg = load_yaml_with_python(path)
        if cfg is None:
            cfg = load_yaml_minimal_for_preflight(path)
        if cfg is None:
            cfg = load_yaml_with_ruby(path)
    except YamlError as e:
        if e.kind == "ruby_json":
            fail(
                f"❌ {t('preflight.error.ruby_yaml_parse', 'Error parsing YAML converted by Ruby: {error}', error=e)}"
            )
        fail(f"❌ {t('preflight.error.config_parse', 'Could not parse config for preflight: {error}', error=e)}")

    if cfg is None:
        fail(
            f"❌ {t('preflight.error.no_yaml_parser', 'Preflight with -c requires PyYAML or Ruby YAML available')}"
        )
    return cfg


def load_yaml_minimal_for_preflight(path: Path):
    """
    Minimal fallback parser to extract ONLY:
      - pandoc.pdf_engine
      - runtime.required_commands / strict
      - output.formats (inline or block list)
    Avoid depending on PyYAML/Ruby in isolated PATH environments.
    """
    text = path.read_text(encoding="utf-8")
    lines = text.splitlines()

    in_runtime = False
    in_pandoc = False
    in_output = False
    in_required_commands = False
    runtime_indent = -1
    pandoc_indent = -1
    output_indent = -1
    required_indent = -1

    pdf_engine: str | None = None
    required_commands: list[str] = []
    strict_value: bool | None = None
    output_formats: list[str] | None = None
    in_formats = False
    formats_indent = -1

    for raw_line in lines:
        line = raw_line.split("#", 1)[0].rstrip()
        if not line.strip():
            continue

        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        if in_formats and indent <= formats_indent and not stripped.startswith("-"):
            in_formats = False

        if in_required_commands and indent <= required_indent and not stripped.startswith("-"):
            in_required_commands = False

        if in_runtime and indent <= runtime_indent and stripped and not stripped.startswith("-"):
            in_runtime = False
            in_required_commands = False

        if in_pandoc and indent <= pandoc_indent and stripped and not stripped.startswith("-"):
            in_pandoc = False

        if in_output and indent <= output_indent and stripped and not stripped.startswith("-"):
            in_output = False

        key_match = re.match(r"^([A-Za-z_][A-Za-z0-9_]*):\s*(.*)$", stripped)
        if key_match:
            key, value = key_match.group(1), key_match.group(2)

            if key == "runtime":
                in_runtime = True
                runtime_indent = indent
                in_required_commands = False
                continue

            if key == "pandoc":
                in_pandoc = True
                pandoc_indent = indent
                continue

            if key == "output":
                in_output = True
                output_indent = indent
                continue

            if in_output and key == "formats":
                # Multiline flow syntax (and other nontrivial YAML) needs the
                # full parser. Never turn an unparsed selection into no PDF.
                if value and not (value.startswith("[") and value.endswith("]")):
                    return None
                output_formats = []
                formats_indent = indent
                in_formats = True
                if value.startswith("[") and value.endswith("]"):
                    output_formats = [v.strip().strip("\"'") for v in value[1:-1].split(",") if v.strip()]
                    in_formats = False
                continue

            if in_runtime and key == "required_commands":
                in_required_commands = True
                required_indent = indent
                # inline form: required_commands: [pandoc, mmdc]
                if value.startswith("[") and value.endswith("]"):
                    inline_vals = [v.strip().strip('"\'') for v in value[1:-1].split(",") if v.strip()]
                    required_commands.extend(inline_vals)
                continue

            if in_runtime and key == "strict":
                raw_strict = value.strip().strip("\"'").lower()
                if raw_strict in {"true", "false"}:
                    strict_value = raw_strict == "true"
                continue

            if in_pandoc and key == "pdf_engine":
                v = value.strip().strip('"\'')
                if v:
                    pdf_engine = v
                continue

        if in_formats and stripped.startswith("-") and output_formats is not None:
            output_formats.append(stripped[1:].strip().strip("\"'"))

        if in_required_commands and stripped.startswith("-"):
            item = stripped[1:].strip().strip('"\'')
            if item:
                required_commands.append(item)

    if not required_commands and pdf_engine is None and strict_value is None and output_formats is None:
        return None

    data: dict[str, object] = {}
    runtime_data: dict[str, object] = {}
    if required_commands:
        runtime_data["required_commands"] = required_commands
    if strict_value is not None:
        runtime_data["strict"] = strict_value
    if runtime_data:
        data["runtime"] = runtime_data
    if pdf_engine is not None:
        data["pandoc"] = {"pdf_engine": pdf_engine}
    if output_formats is not None:
        data["output"] = {"formats": output_formats}
    return data


def command_exists(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def resolved_python3_version() -> tuple[int, int, int] | None:
    """Ask the python3 the renderer will run for its version.

    The renderer is started as ``python3 render-native.py``, so the check probes
    the ``python3`` resolved from PATH instead of assuming the interpreter
    running this preflight. Only ``--version`` is asked: no network and no
    package operation. Returns None when the version cannot be read; the
    missing-command check already covers a python3 that does not run at all.
    """
    import subprocess

    python3 = shutil.which("python3")
    if python3 is None:
        return None

    try:
        proc = subprocess.run([python3, "--version"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None

    if proc.returncode != 0:
        return None

    match = re.search(r"Python (\d+)\.(\d+)(?:\.(\d+))?", proc.stdout or "")
    if not match:
        return None
    return (int(match.group(1)), int(match.group(2)), int(match.group(3) or 0))


def is_valid_command_name(cmd: str) -> bool:
    return re.match(r"^[A-Za-z0-9._+-]+$", cmd) is not None


def parse_config_path(argv: list[str]) -> Path | None:
    if not argv:
        return None

    # Backward-compatible: allow direct path as first positional argument.
    if len(argv) == 1 and not argv[0].startswith("-"):
        return Path(argv[0])

    if len(argv) == 2 and argv[0] in {"-c", "--config"}:
        return Path(argv[1])

    fail(f"❌ {t('preflight.error.usage', 'Usage: preflight.py [-c <skelepress.config.yaml>]')}")


def mermaid_cli_version() -> str | None:
    """Return the mermaid-cli version, or None when it cannot be read."""
    import shutil
    import subprocess

    mmdc = shutil.which("mmdc")
    if mmdc is None:
        return None

    try:
        proc = subprocess.run([mmdc, "--version"], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None

    if proc.returncode != 0:
        return None

    lines = (proc.stdout or "").strip().splitlines()
    return lines[0].strip() if lines else None


def mermaid_smoke_check() -> str | None:
    """Render a two-node diagram. Returns an error string, or None when mmdc works."""
    import shutil
    import subprocess
    import tempfile

    mmdc = shutil.which("mmdc")
    if mmdc is None:
        return None

    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / "smoke.mmd"
        target = Path(tmp) / "smoke.png"
        source.write_text("graph TD\n  A --> B\n", encoding="utf-8")
        try:
            proc = subprocess.run(
                [mmdc, "-i", str(source), "-o", str(target), "-b", "transparent", "-q"],
                capture_output=True,
                text=True,
                timeout=120,
            )
        except Exception as e:
            return str(e)

        # mermaid-cli exits non-zero when it cannot render (measured: 1 when the
        # Puppeteer browser is missing), so the exit code is the contract.
        if proc.returncode == 0:
            return None

        detail = (proc.stderr or proc.stdout or "").strip().splitlines()
        return detail[0] if detail else f"mmdc exited {proc.returncode}"


def main() -> None:
    config_path = parse_config_path(sys.argv[1:])

    required = list(DEFAULT_REQUIRED)
    preferred_engine = None
    strict = True
    mermaid_enabled = True
    output_formats = [FORMAT_PDF]

    if config_path:
        if not config_path.exists():
            fail(f"❌ {t('preflight.error.config_not_found', 'Config not found for preflight: {path}', path=config_path)}")

        cfg = load_config_for_preflight(config_path)

        if isinstance(cfg, dict):
            runtime = cfg.get("runtime")
            if isinstance(runtime, dict):
                runtime_cmds = runtime.get("required_commands")
                if isinstance(runtime_cmds, list):
                    required = [str(c) for c in runtime_cmds if str(c).strip()]
                runtime_strict = runtime.get("strict")
                if isinstance(runtime_strict, bool):
                    strict = runtime_strict

            filters = cfg.get("filters")
            if isinstance(filters, dict):
                mermaid = filters.get("mermaid")
                if isinstance(mermaid, dict) and mermaid.get("enabled") is False:
                    mermaid_enabled = False

            pandoc = cfg.get("pandoc")
            if isinstance(pandoc, dict):
                engine = pandoc.get("pdf_engine")
                if isinstance(engine, str) and engine.strip():
                    preferred_engine = engine.strip()

            output = cfg.get("output")
            if isinstance(output, dict):
                declared_formats = output.get("formats")
                if isinstance(declared_formats, list):
                    output_formats = declared_formats

    needs_tex = FORMAT_PDF in output_formats
    # A python3 below the declared minimum cannot run the renderer, so this is
    # not waivable by runtime.strict=false: without an interpreter there is no
    # render to continue with.
    found_python = resolved_python3_version()
    if found_python is not None and found_python < PYTHON_MINIMUM:
        found_str = ".".join(str(part) for part in found_python)
        required_str = ".".join(str(part) for part in PYTHON_MINIMUM)
        fail(
            f"❌ {t('doctor.error.python_version', 'python3 {found} is below the required minimum {required}', found=found_str, required=required_str)}"
        )

    missing: list[str] = []
    missing_engine: list[str] = []
    for cmd in required:
        if not is_valid_command_name(cmd):
            fail(
                f"❌ {t('preflight.error.invalid_required_command', 'Invalid command name in runtime.required_commands: {cmd}', cmd=cmd)}"
            )
        # A PDF is typeset, so engine names are resolved as one requirement below.
        # An EPUB needs no TeX engine implicitly, but a command the consumer
        # declares explicitly is still enforced.
        if needs_tex and cmd in TEX_ENGINES:
            continue
        if not command_exists(cmd):
            missing.append(cmd)

    if needs_tex:
        required_has_tex = any(cmd in TEX_ENGINES for cmd in required)
        if preferred_engine:
            if not command_exists(preferred_engine):
                missing_engine.append(preferred_engine)
        elif required_has_tex:
            found = any(command_exists(tex) for tex in TEX_ENGINES)
            if not found:
                missing_engine.append("xelatex|lualatex|pdflatex")

    # Without a TeX engine there is no PDF, so runtime.strict=false cannot waive it.
    if missing_engine and not strict:
        print(t("doctor.error.tex_required", "A TeX engine is required to render a PDF; runtime.strict=false cannot waive it."))

    missing = missing + missing_engine
    mermaid_error = None
    if mermaid_enabled and "mmdc" in required and command_exists("mmdc"):
        mermaid_error = mermaid_smoke_check()

    if mermaid_error:
        print(f"❌ {t('doctor.mermaid.failed', 'Mermaid diagrams cannot be rendered: mmdc is installed but could not produce an image')}")
        # The version is the first thing to check when a diagram fails: Homebrew
        # ships a release that downloads no browser.
        version = mermaid_cli_version()
        if version:
            print(t("doctor.mermaid.version", "   mermaid-cli {version} detected", version=version))
        print(f"   - {mermaid_error}")
        print(t("doctor.mermaid.hint1", "   Fix A: install the Puppeteer browser: npx puppeteer browsers install chrome-headless-shell"))
        print(t("doctor.mermaid.hint2", "   Fix B: point Puppeteer at an installed Chrome: export PUPPETEER_EXECUTABLE_PATH=/path/to/chrome"))
        if strict:
            raise SystemExit(1)
        print(t("doctor.warn.continue", "Continuing because runtime.strict=false"))

    if missing:
        if not strict and not missing_engine:
            print(
                f"⚠️  {t('doctor.warn.missing', 'Doctor warnings: missing dependencies (runtime.strict=false):')}"
            )
            for m in missing:
                print(f"   - {m}")
            print(t("doctor.warn.continue", "Continuing because runtime.strict=false"))
            return
        print(f"❌ {t('doctor.missing', 'Doctor detected missing dependencies:')}")
        for m in missing:
            print(f"   - {m}")
        raise SystemExit(1)

    print(f"✅ {t('doctor.ok', 'Doctor OK: dependencies available')}")


if __name__ == "__main__":
    main()
