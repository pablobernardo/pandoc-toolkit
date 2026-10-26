#!/usr/bin/env python3
from __future__ import annotations

import os
import re
import subprocess
import sys
from datetime import datetime
from copy import deepcopy
from pathlib import Path
from typing import NoReturn

import yaml

try:
    from i18n_runtime import t
except Exception:
    def t(key: str, fallback: str, **kwargs: object) -> str:
        try:
            return fallback.format(**kwargs)
        except Exception:
            return fallback


def die(msg: str) -> NoReturn:
    print(f"❌ {msg}")
    raise SystemExit(1)


ORDER_NATURAL = "natural"
ORDER_ALPHABETICAL = "alphabetical"
ORDER_CHOICES = (ORDER_NATURAL, ORDER_ALPHABETICAL)

DOCUMENT_VAR_FIELDS = ("title", "subtitle", "publisher", "author", "date", "rights")


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


def deep_merge(base: dict, override: dict) -> dict:
    merged = deepcopy(base)
    for key, value in override.items():
        if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def load_yaml_map(path: Path) -> dict:
    try:
        data = yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as e:
        die(t("render.error.yaml_parse", "Could not parse YAML: {error}", error=e))

    if data is None:
        return {}
    if not isinstance(data, dict):
        die(t("render.error.yaml_root_object", "Root of {path} must be an object/map", path=path))
    return data


def main() -> None:
    if len(sys.argv) < 3:
        die(t("render.error.usage", "Usage: render-native.py <config.yaml> <toolkit_root>"))

    cfg_path = Path(sys.argv[1])
    root_dir = Path(sys.argv[2])

    if not cfg_path.exists():
        die(t("render.error.config_not_found", "Config not found: {path}", path=cfg_path))

    cfg_user = load_yaml_map(cfg_path)
    cfg = cfg_user

    defaults_path = root_dir / "defaults/default.yaml"
    if defaults_path.exists():
        defaults_cfg = load_yaml_map(defaults_path)
        cfg = deep_merge(defaults_cfg, cfg)

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
    title = document.get("title") or output.get("file_prefix") or "document"
    suffix = resolve_suffix(output.get("suffix"))

    chapters_dir = base_dir_path / str(input_cfg.get("chapters_dir", "chapters"))
    if not chapters_dir.exists():
        die(t("render.error.chapters_dir_missing", "input.chapters_dir does not exist: {path}", path=chapters_dir))

    selected_files = select_chapter_files(input_cfg, chapters_dir)

    if not selected_files:
        die(t("render.error.no_chapters", "No chapters found to render"))

    output_dir = base_dir_path / str(output.get("dir", "output"))
    output_dir.mkdir(parents=True, exist_ok=True)
    filename_out = f"{title}-{suffix}"
    pdf_out = output_dir / f"{filename_out}.pdf"
    md_out = output_dir / f"{filename_out}.md"

    keep_merged_markdown = bool(output.get("keep_merged_markdown", True))

    compat = cfg.get("compat", {})
    insert_clearpage = bool(compat.get("legacy_clearpage_between_h1", True))

    parts = []
    for i, file in enumerate(selected_files):
        text = file.read_text(encoding="utf-8", errors="ignore")
        if i > 0 and insert_clearpage:
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

    md_out.write_text("".join(parts), encoding="utf-8")

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

    emoji_dir = Path(str(emoji_cfg.get("emoji_dir", "output/emoji")))
    if not emoji_dir.is_absolute():
        emoji_dir = (base_dir_path / emoji_dir).resolve()
    emoji_dir.mkdir(parents=True, exist_ok=True)

    missing_svg = emoji_dir / "_missing.svg"
    if not missing_svg.exists():
        missing_svg.write_text(
            """<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 16 16\">\n"
            "  <rect width=\"16\" height=\"16\" rx=\"2\" ry=\"2\" fill=\"#ddd\" stroke=\"#999\"/>\n"
            "  <text x=\"8\" y=\"11\" font-size=\"10\" text-anchor=\"middle\" fill=\"#666\">?</text>\n"
            "</svg>\n""",
            encoding="utf-8",
        )

    if bool(emoji_cfg.get("enabled", True)):
        prepare_script = root_dir / "scripts/prepare-emojis.py"
        if prepare_script.exists():
            prep_cmd = [
                sys.executable,
                str(prepare_script),
                str(md_out),
                str(emoji_dir),
                str(root_dir / "filters/emoji"),
            ]
            prep = subprocess.run(prep_cmd)
            if prep.returncode != 0:
                print(f"⚠️  {t('render.warn.emoji_prepare', 'Could not auto-prepare emojis; continuing with fallback')}")

    mermaid_output_dir = Path(str(mermaid_cfg.get("output_dir", "output/mermaid")))
    if not mermaid_output_dir.is_absolute():
        mermaid_output_dir = (base_dir_path / mermaid_output_dir).resolve()
    mermaid_output_dir.mkdir(parents=True, exist_ok=True)

    cmd = [
        "pandoc",
        str(md_out),
        f"--pdf-engine={pandoc.get('pdf_engine', 'xelatex')}",
        f"--template={template_path}",
    ]

    if bool(emoji_cfg.get("enabled", True)):
        cmd.append(f"--lua-filter={root_dir / 'filters/emoji.lua'}")
    if bool(mermaid_cfg.get("enabled", True)):
        cmd.append(f"--lua-filter={root_dir / 'filters/mermaid.lua'}")

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

    cmd.extend(["-V", "titlepage=true", "-V", "fig-pos=!htbp"])
    if resource_path_values:
        cmd.append(f"--resource-path={os.pathsep.join(resource_path_values)}")
    uses_metadata_file = metadata_path is not None and metadata_path.exists()
    if uses_metadata_file:
        cmd.append(f"--metadata-file={metadata_path}")
    else:
        for field in DOCUMENT_VAR_FIELDS:
            value = document.get(field)
            if isinstance(value, str) and value.strip():
                cmd.extend(["-V", f"{field}={value}"])
    cmd.extend(["-o", str(pdf_out)])

    env = os.environ.copy()
    env["PANDOC_EMOJI_DIR"] = str(emoji_dir)
    env["PANDOC_EMOJI_BALLOT_ICONS"] = "1" if bool(emoji_cfg.get("include_ballot_icons", True)) else "0"
    env["PANDOC_MERMAID_OUTPUT_DIR"] = str(mermaid_output_dir)
    env["PANDOC_MERMAID_BACKGROUND"] = str(mermaid_cfg.get("background", "transparent"))

    print(f"✅ {t('render.mode.native', 'Native mode enabled')}")
    print(f"📄 {t('render.output.markdown', 'Merged markdown: {path}', path=md_out)}")
    print(f"🖨️  {t('render.output.pdf', 'Output PDF: {path}', path=pdf_out)}")
    print(f"▶ {t('render.command.exec', 'Running: {command}', command=' '.join(cmd))}")

    result = subprocess.run(cmd, env=env)
    if result.returncode == 0 and not keep_merged_markdown:
        md_out.unlink(missing_ok=True)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
