#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
from datetime import datetime
from copy import deepcopy
from pathlib import Path

import yaml


def die(msg: str) -> None:
    print(f"❌ {msg}")
    raise SystemExit(1)


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
        die(f"No se pudo parsear YAML: {e}")

    if data is None:
        return {}
    if not isinstance(data, dict):
        die(f"La raíz de {path} debe ser un objeto/map")
    return data


def main() -> None:
    if len(sys.argv) < 3:
        die("Uso: render-native.py <config.yaml> <toolkit_root>")

    cfg_path = Path(sys.argv[1])
    root_dir = Path(sys.argv[2])

    if not cfg_path.exists():
        die(f"Config no encontrada: {cfg_path}")

    cfg_user = load_yaml_map(cfg_path)
    cfg = cfg_user

    defaults_path = root_dir / "defaults/default.yaml"
    if defaults_path.exists():
        defaults_cfg = load_yaml_map(defaults_path)
        cfg = deep_merge(defaults_cfg, cfg)

    required = ["project", "document", "input", "output", "pandoc"]
    for key in required:
        if key not in cfg or not isinstance(cfg[key], dict):
            die(f"Sección obligatoria inválida o ausente: {key}")

    project = cfg["project"]
    document = cfg["document"]
    input_cfg = cfg["input"]
    output = cfg["output"]
    pandoc = cfg["pandoc"]

    base_dir = project.get("base_dir")
    if not base_dir:
        die("'project.base_dir' es obligatorio")

    base_dir_path = (cfg_path.parent / str(base_dir)).resolve()
    title = document.get("title") or output.get("file_prefix") or "document"
    suffix = resolve_suffix(output.get("suffix"))

    chapters_dir = base_dir_path / str(input_cfg.get("chapters_dir", "chapters"))
    if not chapters_dir.exists():
        die(f"No existe input.chapters_dir: {chapters_dir}")

    explicit_files = input_cfg.get("explicit_files") or []
    if explicit_files:
        selected_files = []
        for name in explicit_files:
            candidate = chapters_dir / str(name)
            if not candidate.exists():
                die(f"Archivo explícito no encontrado: {candidate}")
            selected_files.append(candidate)
    else:
        pattern = str(input_cfg.get("glob", "*.md"))
        selected_files = sorted(chapters_dir.glob(pattern), key=lambda p: p.name)

    if not selected_files:
        die("No se encontraron capítulos para renderizar")

    output_dir = base_dir_path / str(output.get("dir", "output"))
    output_dir.mkdir(parents=True, exist_ok=True)
    filename_out = f"{title}-{suffix}"
    pdf_out = output_dir / f"{filename_out}.pdf"
    md_out = output_dir / f"{filename_out}.md"

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

    user_pandoc_cfg = cfg_user.get("pandoc") if isinstance(cfg_user.get("pandoc"), dict) else {}
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
                print("⚠️  No se pudieron preparar emojis automáticamente; continúo con fallback")

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
        cmd.append(f"--resource-path={':'.join(resource_path_values)}")
    if metadata_path and metadata_path.exists():
        cmd.append(f"--metadata-file={metadata_path}")
    cmd.extend(["-o", str(pdf_out)])

    env = os.environ.copy()
    env["PANDOC_EMOJI_DIR"] = str(emoji_dir)
    env["PANDOC_MERMAID_OUTPUT_DIR"] = str(mermaid_output_dir)
    env["PANDOC_MERMAID_BACKGROUND"] = str(mermaid_cfg.get("background", "transparent"))

    print("✅ Modo nativo activo")
    print(f"📄 Markdown combinado: {md_out}")
    print(f"🖨️  PDF de salida: {pdf_out}")
    print(f"▶ Ejecutando: {' '.join(cmd)}")

    result = subprocess.run(cmd, env=env)
    raise SystemExit(result.returncode)


if __name__ == "__main__":
    main()
