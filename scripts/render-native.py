#!/usr/bin/env python3
from __future__ import annotations

import json
import unicodedata
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import NoReturn

try:
    import yaml  # type: ignore
except Exception:  # PyYAML is optional: Ruby's stdlib YAML is the fallback.
    yaml = None

try:
    from i18n_runtime import t
except Exception:
    def t(key: str, fallback: str, **kwargs: object) -> str:
        try:
            return fallback.format(**kwargs)
        except Exception:
            return fallback


ORDER_NATURAL = "natural"
ORDER_ALPHABETICAL = "alphabetical"
ORDER_CHOICES = (ORDER_NATURAL, ORDER_ALPHABETICAL)

def slugify(value: str) -> str:
    """A file name derived from a title: lowercase, ASCII, single dashes."""
    decomposed = unicodedata.normalize("NFKD", value)
    ascii_only = decomposed.encode("ascii", "ignore").decode("ascii")
    slug = re.sub(r"[^a-z0-9]+", "-", ascii_only.lower()).strip("-")
    return slug or "document"


def file_stem(document: dict, output: dict) -> str:
    """One rule for both sources: a declared name, or the title, becomes a slug.

    Slugging by construction is also what makes a declared name unable to escape
    the output directory: nothing but [a-z0-9-] survives.
    """
    declared = str(output.get("file_prefix") or "").strip()
    return slugify(declared or str(document.get("title") or "document"))


DOCUMENT_VAR_FIELDS = ("title", "subtitle", "publisher", "author", "date", "rights")

# babel wants a language name, the contract uses the code.
BABEL_LANGS = {"en": "english", "es": "spanish", "pt": "portuguese", "gl": "galician"}
# English is the default: the toolkit is consumed across languages, so the
# fallback cannot be the language of one of them. Declare document.language to
# get another one.
DEFAULT_BABEL_LANGUAGE = "english"

PLAN_VERSION = 1

FORMAT_PDF = "pdf"
FORMAT_EPUB = "epub"
FORMAT_CHOICES = (FORMAT_PDF, FORMAT_EPUB)

# EPUB records BCP 47 language tags, not babel names.
EPUB_LANGS = {"en": "en", "es": "es", "pt": "pt", "gl": "gl"}
DEFAULT_EPUB_LANGUAGE = "en"

MISSING_SVG = (
    """<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 16 16\">\n"
    "  <rect width=\"16\" height=\"16\" rx=\"2\" ry=\"2\" fill=\"#ddd\" stroke=\"#999\"/>\n"
    "  <text x=\"8\" y=\"11\" font-size=\"10\" text-anchor=\"middle\" fill=\"#666\">?</text>\n"
    "</svg>\n"""
)


def die(msg: str) -> NoReturn:
    print(f"❌ {msg}")
    raise SystemExit(1)


def natural_key(path: Path) -> list[tuple[int, int, str]]:
    """Sort key where digit runs compare numerically (chapter-2 < chapter-10)."""
    parts = re.split(r"(\d+)", path.name.lower())
    return [(0, len(part), part) if part.isdigit() else (1, 0, part) for part in parts]


def select_chapter_files(input_cfg: dict, chapters_dir: Path) -> list[Path]:
    explicit_files = input_cfg.get("explicit_files") or []
    if explicit_files:
        selected_files = []
        for name in explicit_files:
            candidate = chapters_dir / str(name)
            if not candidate.exists():
                die(t("render.error.explicit_file_missing", "Explicit file not found: {path}", path=candidate))
            selected_files.append(candidate)
        return selected_files

    pattern = str(input_cfg.get("glob", "*.md"))
    order = str(input_cfg.get("order", ORDER_NATURAL)).strip().lower()
    files = list(chapters_dir.glob(pattern))

    if order == ORDER_ALPHABETICAL:
        return sorted(files, key=lambda p: p.name)
    if order == ORDER_NATURAL:
        return sorted(files, key=natural_key)

    die(
        t(
            "render.error.order_invalid",
            "Invalid 'input.order' value: {value}. Supported values: {supported}",
            value=order,
            supported=", ".join(ORDER_CHOICES),
        )
    )


def resolve_suffix(raw_suffix: str | None) -> str:
    if not raw_suffix:
        return datetime.now().strftime("%Y%m%d")
    return raw_suffix.replace("${date:YYYYMMDD}", datetime.now().strftime("%Y%m%d"))


RUBY_YAML_SCRIPT = r"""
require 'yaml'
require 'json'
path = ARGV[0]
begin
  data = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  puts JSON.generate(data)
rescue => e
  STDERR.puts e.message
  exit 2
end
"""


def load_yaml_via_ruby(path: Path) -> dict | None:
    """Parse YAML through Ruby's stdlib and return plain data. None when Ruby is unavailable."""
    ruby_bin = shutil.which("ruby")
    if ruby_bin is None:
        return None

    proc = subprocess.run(
        [ruby_bin, "-e", RUBY_YAML_SCRIPT, str(path)],
        capture_output=True,
        text=True,
    )
    if proc.returncode == 2:
        die(t("render.error.yaml_parse", "Could not parse YAML: {error}", error=proc.stderr.strip() or "invalid YAML"))
    if proc.returncode != 0:
        return None
    try:
        return json.loads(proc.stdout)
    except Exception as e:
        die(t("render.error.yaml_parse", "Could not parse YAML: {error}", error=e))


def load_yaml_map(path: Path) -> dict:
    if yaml is not None:
        try:
            data = yaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception as e:
            die(t("render.error.yaml_parse", "Could not parse YAML: {error}", error=e))
    else:
        data = load_yaml_via_ruby(path)
        if data is None:
            die(t("render.error.no_yaml_parser", "No YAML parser available (install PyYAML or Ruby with stdlib YAML)"))

    if data is None:
        return {}
    if not isinstance(data, dict):
        die(t("render.error.yaml_root_object", "Root of {path} must be an object/map", path=path))
    return data


def toolkit_version(root_dir: Path) -> str:
    version_file = root_dir / "VERSION"
    try:
        value = version_file.read_text(encoding="utf-8").strip()
    except OSError:
        return ""
    return value


def build_plan(cfg_user: dict, cfg_path: Path, root_dir: Path) -> dict:
    """Compute the render plan. Pure: no writes, no directory creation, no subprocess."""
    cfg = cfg_user

    required = ["project", "document", "input", "output", "pandoc"]
    for key in required:
        if key not in cfg or not isinstance(cfg[key], dict):
            die(t("render.error.required_section", "Invalid or missing required section: {section}", section=key))

    project = cfg["project"]
    document = cfg["document"]
    input_cfg = cfg["input"]
    output = cfg["output"]
    pandoc = cfg["pandoc"]

    base_dir = project.get("base_dir")
    if not base_dir:
        die(t("render.error.base_dir_required", "'project.base_dir' is required"))

    base_dir_path = (cfg_path.parent / str(base_dir)).resolve()
    stem = file_stem(document, output)
    suffix = resolve_suffix(output.get("suffix"))

    chapters_dir = base_dir_path / str(input_cfg.get("chapters_dir", "chapters"))
    if not chapters_dir.exists():
        die(t("render.error.chapters_dir_missing", "input.chapters_dir does not exist: {path}", path=chapters_dir))

    selected_files = select_chapter_files(input_cfg, chapters_dir)
    if not selected_files:
        die(t("render.error.no_chapters", "No chapters found to render"))

    # Normalise: a consumer using "../out" should not see that in the report.
    output_dir = (base_dir_path / str(output.get("dir", "output"))).resolve()
    filename_out = f"{stem}-{suffix}"

    format_name = str(output.get("format") or FORMAT_PDF).strip().lower()
    if format_name not in FORMAT_CHOICES:
        die(
            t(
                "render.error.format_invalid",
                "Invalid 'output.format' value: {value}. Supported values: {supported}",
                value=format_name,
                supported=", ".join(FORMAT_CHOICES),
            )
        )

    artifact_out = output_dir / f"{filename_out}.{format_name}"
    md_out = output_dir / f"{filename_out}.md"

    keep_merged_markdown = bool(output.get("keep_merged_markdown", True))

    compat = cfg.get("compat", {})
    insert_clearpage = bool(compat.get("legacy_clearpage_between_h1", True))

    raw_user_pandoc = cfg_user.get("pandoc")
    user_pandoc_cfg = raw_user_pandoc if isinstance(raw_user_pandoc, dict) else {}
    user_template_raw = str(user_pandoc_cfg.get("template", "")).strip()

    if user_template_raw:
        template_path = Path(user_template_raw)
        if not template_path.is_absolute():
            template_path = (base_dir_path / template_path).resolve()
    else:
        template_default_raw = str(pandoc.get("template", "templates/default.tex")).strip() or "templates/default.tex"
        template_path = Path(template_default_raw)
        if not template_path.is_absolute():
            template_path = (root_dir / template_path).resolve()

    metadata_path = None
    metadata_raw = str(pandoc.get("metadata_file", ""))
    if metadata_raw.strip():
        metadata_path = Path(metadata_raw)
        if not metadata_path.is_absolute():
            metadata_path = (base_dir_path / metadata_path).resolve()

    resource_path_values = []
    for item in pandoc.get("resource_path", []):
        p = Path(str(item))
        if not p.is_absolute():
            p = (base_dir_path / p).resolve()
        resource_path_values.append(str(p))

    filters = cfg.get("filters", {})
    emoji_cfg = filters.get("emoji", {})
    mermaid_cfg = filters.get("mermaid", {})

    emoji_enabled = bool(emoji_cfg.get("enabled", True))
    mermaid_enabled = bool(mermaid_cfg.get("enabled", True))

    emoji_dir = Path(str(emoji_cfg.get("emoji_dir", "output/emoji")))
    if not emoji_dir.is_absolute():
        emoji_dir = (base_dir_path / emoji_dir).resolve()

    mermaid_output_dir = Path(str(mermaid_cfg.get("output_dir", "output/mermaid")))
    if not mermaid_output_dir.is_absolute():
        mermaid_output_dir = (base_dir_path / mermaid_output_dir).resolve()

    prepare_script = root_dir / "scripts/prepare-emojis.py"
    prepare_argv = None
    if emoji_enabled and prepare_script.exists():
        prepare_argv = [
            "python3",
            str(prepare_script),
            str(md_out),
            str(emoji_dir),
            str(root_dir / "filters/emoji"),
        ]

    cmd = ["pandoc", str(md_out)]
    # EPUB is not typeset: a TeX engine and the LaTeX template are PDF-only, and
    # pandoc leaves pdf_engine unused for it (the field stays required for now).
    if format_name == FORMAT_PDF:
        cmd.extend([
            f"--pdf-engine={pandoc.get('pdf_engine', 'xelatex')}",
            f"--template={template_path}",
        ])

    if emoji_enabled:
        cmd.append(f"--lua-filter={root_dir / 'filters/emoji.lua'}")
    if mermaid_enabled:
        cmd.append(f"--lua-filter={root_dir / 'filters/mermaid.lua'}")

    # Always on: inline code cannot break in LaTeX, and a long path running past
    # the margin is not something a consumer should have to configure away.
    cmd.append(f"--lua-filter={root_dir / 'filters/inline-code-breaks.lua'}")

    for extra in filters.get("extra_lua_filters", []):
        extra_path = Path(str(extra))
        if not extra_path.is_absolute():
            extra_path = (base_dir_path / extra_path).resolve()
        cmd.append(f"--lua-filter={extra_path}")

    if bool(pandoc.get("toc", True)):
        cmd.append("--toc")
        cmd.append(f"--toc-depth={int(pandoc.get('toc_depth', 2))}")
    if bool(pandoc.get("number_sections", True)):
        cmd.append("--number-sections")

    if format_name == FORMAT_PDF:
        # The cover switch is emitted below with the rest of the document options;
        # an unconditional -V here would make titlepage: false impossible.
        cmd.extend(["-V", "fig-pos=!htbp"])
    if resource_path_values:
        cmd.append(f"--resource-path={os.pathsep.join(resource_path_values)}")

    language = str(document.get("language") or "").strip()

    if format_name == FORMAT_EPUB:
        cmd.append(f"--include-in-header={root_dir / 'templates/epub-header.html'}")
        # An EPUB3 package needs dc:title and dc:language to be a valid
        # publication; pandoc writes them from metadata, not from -V variables.
        # Match PDF precedence: a metadata file replaces document text fields;
        # document.language remains authoritative for either format.
        if metadata_path is not None and metadata_path.exists():
            cmd.append(f"--metadata-file={metadata_path}")
        else:
            for field in DOCUMENT_VAR_FIELDS:
                value = document.get(field)
                if isinstance(value, str) and value.strip():
                    cmd.extend(["--metadata", f"{field}={value}"])
            for key, value in (document.get("metadata") or {}).items():
                cmd.extend(["--metadata", f"{key}={value}"])
        cmd.extend(["--metadata", f"lang={EPUB_LANGS.get(language, DEFAULT_EPUB_LANGUAGE)}"])
        cmd.extend(["-o", str(artifact_out)])
    else:
        uses_metadata_file = metadata_path is not None and metadata_path.exists()
        if uses_metadata_file:
            cmd.append(f"--metadata-file={metadata_path}")
        else:
            for field in DOCUMENT_VAR_FIELDS:
                value = document.get(field)
                if isinstance(value, str) and value.strip():
                    cmd.extend(["-V", f"{field}={value}"])

            # Free-form metadata is only meaningful when no metadata file wins (D5).
            extra_metadata = document.get("metadata")
            if isinstance(extra_metadata, dict):
                for key, value in extra_metadata.items():
                    cmd.extend(["--metadata", f"{key}={value}"])

        # Language and the cover switch are typesetting decisions, not cover text, so
        # they apply even when a metadata file provides the title page.
        cmd.extend(["-V", f"babel-lang={BABEL_LANGS.get(language, DEFAULT_BABEL_LANGUAGE)}"])
        titlepage = document.get("titlepage", True)
        cmd.extend(["--metadata", "titlepage=true" if titlepage is not False else "titlepage=false"])
        cmd.extend(["-o", str(artifact_out)])

    return {
        "plan_version": PLAN_VERSION,
        "toolkit": {"version": toolkit_version(root_dir), "root": str(root_dir)},
        "config": {"path": str(cfg_path), "base_dir": str(base_dir_path)},
        "chapters": [str(p) for p in selected_files],
        "pandoc": {
            # The produced artifact is named after the format, so a PDF plan keeps
            # its recorded shape and an EPUB plan cannot claim to produce a PDF.
            "target": {"markdown": str(md_out), format_name: str(artifact_out)},
            "argv": cmd,
            "cwd": None,
        },
        "env": {
            "PANDOC_EMOJI_DIR": str(emoji_dir),
            "PANDOC_EMOJI_BALLOT_ICONS": "1" if bool(emoji_cfg.get("include_ballot_icons", True)) else "0",
            "PANDOC_MERMAID_OUTPUT_DIR": str(mermaid_output_dir),
            "PANDOC_MERMAID_BACKGROUND": str(mermaid_cfg.get("background", "transparent")),
        },
        "side_effects": {
            "keep_merged_markdown": keep_merged_markdown,
            "clearpage_between_h1": insert_clearpage,
            "emoji": {
                "enabled": emoji_enabled,
                "dir": str(emoji_dir),
                "missing_svg": str(emoji_dir / "_missing.svg"),
                "prepare_argv": prepare_argv,
            },
            "mermaid": {
                "enabled": mermaid_enabled,
                "dir": str(mermaid_output_dir),
                "background": str(mermaid_cfg.get("background", "transparent")),
            },
        },
    }


def merged_markdown(chapters: list[str], insert_clearpage: bool) -> str:
    parts = []
    for index, raw_path in enumerate(chapters):
        text = Path(raw_path).read_text(encoding="utf-8", errors="ignore")
        if index > 0 and insert_clearpage:
            first_nonempty = ""
            for line in text.splitlines():
                if line.strip():
                    first_nonempty = line
                    break
            if first_nonempty.startswith("# "):
                parts.append("\n\n\\clearpage\n\n")
        parts.append("\n")
        parts.append(text)
        parts.append("\n\n")
    return "".join(parts)


def artifact_target(plan: dict) -> tuple[str, str]:
    """The artifact the plan produces: the single target that is not the merged markdown."""
    target = plan["pandoc"]["target"]
    for name in FORMAT_CHOICES:
        if name in target:
            return name, target[name]
    die(t("render.error.plan_target_missing", "Render plan declares no output artifact"))


def output_label_key(format_name: str) -> str:
    return "render.output.epub" if format_name == FORMAT_EPUB else "render.output.pdf"


def execute_plan(plan: dict) -> int:
    """Materialise and run the plan. This is the only function with side effects."""
    target = plan["pandoc"]["target"]
    format_name, artifact_raw = artifact_target(plan)
    md_out = Path(target["markdown"])
    artifact_out = Path(artifact_raw)
    side_effects = plan["side_effects"]

    md_out.parent.mkdir(parents=True, exist_ok=True)
    md_out.write_text(
        merged_markdown(plan["chapters"], bool(side_effects["clearpage_between_h1"])),
        encoding="utf-8",
    )

    emoji = side_effects["emoji"]
    if emoji["enabled"]:
        emoji_dir = Path(emoji["dir"])
        emoji_dir.mkdir(parents=True, exist_ok=True)
        missing_svg = Path(emoji["missing_svg"])
        if not missing_svg.exists():
            missing_svg.write_text(MISSING_SVG, encoding="utf-8")

        prepare_argv = emoji["prepare_argv"]
        if prepare_argv:
            prep = subprocess.run(prepare_argv)
            if prep.returncode != 0:
                print(f"⚠️  {t('render.warn.emoji_prepare', 'Could not auto-prepare emojis; continuing with fallback')}")

    if side_effects["mermaid"]["enabled"]:
        Path(side_effects["mermaid"]["dir"]).mkdir(parents=True, exist_ok=True)

    env = os.environ.copy()
    env.update(plan["env"])

    mermaid_failures = Path(side_effects["mermaid"]["dir"]) / "_failed.txt"
    if mermaid_failures.exists():
        mermaid_failures.unlink(missing_ok=True)

    print(f"✅ {t('render.mode.native', 'Native mode enabled')}")
    print(f"📄 {t('render.output.markdown', 'Merged markdown: {path}', path=md_out)}")
    print(f"🖨️  {t(output_label_key(format_name), 'Output: {path}', path=artifact_out)}")
    print(f"▶ {t('render.command.exec', 'Running: {command}', command=' '.join(plan['pandoc']['argv']))}")

    result = subprocess.run(plan["pandoc"]["argv"], env=env)
    if result.returncode == 0 and not side_effects["keep_merged_markdown"]:
        md_out.unlink(missing_ok=True)

    failed = []
    if mermaid_failures.exists():
        failed = [line for line in mermaid_failures.read_text(encoding="utf-8").splitlines() if line.strip()]
        mermaid_failures.unlink(missing_ok=True)

    if result.returncode == 0 and failed:
        printed = ", ".join(failed[:10])
        print(
            t(
                "render.error.mermaid_failed",
                "❌ {count} Mermaid diagram(s) could not be rendered and would print as code: {diagrams}",
                count=len(failed),
                diagrams=printed,
            )
        )
        print(
            t(
                "render.error.mermaid_failed.hint",
                "   Run `pandoc-pdf doctor` to diagnose, or set filters.mermaid.enabled: false to drop the diagrams on purpose.",
            )
        )
        return 1

    return result.returncode


def print_plan(plan: dict) -> None:
    target = plan["pandoc"]["target"]
    format_name, artifact_raw = artifact_target(plan)
    print(t("render.plan.title", "Render plan (dry run, nothing written)"))
    print(f"📄 {t('render.output.markdown', 'Merged markdown: {path}', path=target['markdown'])}")
    print(f"🖨️  {t(output_label_key(format_name), 'Output: {path}', path=artifact_raw)}")
    print(
        f"▶ {t('render.plan.command', 'Command: {command}', command=' '.join(plan['pandoc']['argv']))}"
    )


def main() -> None:
    argv = sys.argv[1:]
    plan_mode = None
    positional: list[str] = []
    for arg in argv:
        if arg == "--plan-json":
            plan_mode = "json"
        elif arg == "--plan":
            plan_mode = plan_mode or "human"
        else:
            positional.append(arg)

    if len(positional) < 2:
        die(t("render.error.usage", "Usage: render-native.py <config.yaml> <toolkit_root> [--plan|--plan-json]"))

    cfg_path = Path(positional[0])
    root_dir = Path(positional[1])

    if not cfg_path.exists():
        die(t("render.error.config_not_found", "Config not found: {path}", path=cfg_path))

    cfg_user = load_yaml_map(cfg_path)
    plan = build_plan(cfg_user, cfg_path, root_dir)

    if plan_mode == "json":
        print(json.dumps(plan, indent=2, ensure_ascii=False))
        raise SystemExit(0)
    if plan_mode == "human":
        print_plan(plan)
        raise SystemExit(0)

    raise SystemExit(execute_plan(plan))


if __name__ == "__main__":
    main()
