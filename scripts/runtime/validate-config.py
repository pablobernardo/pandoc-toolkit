#!/usr/bin/env python3
"""Contract validator for pdf.config.yaml.

The YAML loader and the JSON-Schema-subset validator live in the shared
schema_runtime module so the bookkit tool (scripts/tools/bookkit) applies
exactly the same rules; this file keeps the pdf-config-specific path checks
and the CLI contract.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any, NoReturn

try:
    from i18n_runtime import t
except Exception:
    def t(_key: str, fallback: str, **kwargs: object) -> str:
        try:
            return fallback.format(**kwargs)
        except Exception:
            return fallback

try:
    from schema_runtime import load_yaml, validate_with_schema
except Exception:  # imported as a module from elsewhere: fix the path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    from schema_runtime import load_yaml, validate_with_schema

try:
    import template_runtime
except Exception:  # imported as a module from elsewhere: fix the path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import template_runtime

try:
    import top_level_division_runtime
except Exception:  # imported as a module from elsewhere: fix the path
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import top_level_division_runtime

# The toolkit root, so a builtin template name resolves where the renderer looks
# for it: a name is a shipped template, not a project file.
TOOLKIT_ROOT = Path(__file__).resolve().parents[2]


def fail(msg: str) -> NoReturn:
    print(f"❌ {msg}")
    raise SystemExit(1)



def resolve_from_base(base_dir_path: Path, raw_path: str) -> Path:
    p = Path(raw_path)
    if p.is_absolute():
        return p
    return (base_dir_path / p).resolve()


def validate_runtime_paths(data: dict[str, Any], cfg_path: Path) -> None:
    project = data.get("project") or {}
    input_cfg = data.get("input") or {}
    pandoc_cfg = data.get("pandoc") or {}
    filters_cfg = data.get("filters") or {}

    base_dir = str(project.get("base_dir", "")).strip()
    if not base_dir:
        fail(t("validate.error.base_dir_required", "'project.base_dir' is required"))

    base_dir_path = (cfg_path.parent / base_dir).resolve()

    chapters_dir_raw = str(input_cfg.get("chapters_dir", "")).strip()
    if chapters_dir_raw:
        chapters_dir_path = resolve_from_base(base_dir_path, chapters_dir_raw)
        if not chapters_dir_path.exists() or not chapters_dir_path.is_dir():
            fail(
                t(
                    "validate.error.invalid_chapters_dir",
                    "Invalid path in 'input.chapters_dir': directory does not exist ({path})",
                    path=chapters_dir_path,
                )
            )

    template_raw = str(pandoc_cfg.get("template", "")).strip()
    if template_raw and template_runtime.is_bare_name(template_raw):
        # A bare name is a template that ships with the toolkit. The renderer
        # resolves it against the toolkit root, so validation only has to know the
        # name and that the file is there.
        builtin_template = template_runtime.builtin_path(TOOLKIT_ROOT, template_raw)
        if builtin_template is None:
            fail(
                t(
                    "template.error.unknown_name",
                    "Unknown template name '{name}'; use a path or one of: {allowed}",
                    name=template_raw,
                    allowed=", ".join(template_runtime.known_names()),
                )
            )
        if not builtin_template.is_file():
            fail(
                t(
                    "validate.error.invalid_template",
                    "Invalid path in 'pandoc.template': file does not exist ({path})",
                    path=builtin_template,
                )
            )
    elif template_raw:
        template_path = resolve_from_base(base_dir_path, template_raw)
        if not template_path.exists() or not template_path.is_file():
            fail(
                t(
                    "validate.error.invalid_template",
                    "Invalid path in 'pandoc.template': file does not exist ({path})",
                    path=template_path,
                )
            )

    top_level_division_raw = pandoc_cfg.get("top_level_division")
    if top_level_division_raw is not None:
        # The schema enum already rejects a value outside the four Pandoc
        # choices; this check keeps the shared module load-bearing on both
        # sides, so validation cannot drift from what the renderer passes.
        try:
            top_level_division_runtime.argument(top_level_division_raw)
        except ValueError as e:
            fail(
                t(
                    top_level_division_runtime.ERROR_KEY,
                    top_level_division_runtime.ERROR_FALLBACK,
                    value=e.args[0] if e.args else "",
                    supported=", ".join(top_level_division_runtime.allowed_values()),
                )
            )

    metadata_raw = str(pandoc_cfg.get("metadata_file", "")).strip()
    if metadata_raw:
        metadata_path = resolve_from_base(base_dir_path, metadata_raw)
        if not metadata_path.exists() or not metadata_path.is_file():
            fail(
                t(
                    "validate.error.invalid_metadata_file",
                    "Invalid path in 'pandoc.metadata_file': file does not exist ({path})",
                    path=metadata_path,
                )
            )

    extra_filters = filters_cfg.get("extra_lua_filters") or []
    if isinstance(extra_filters, list):
        for idx, raw in enumerate(extra_filters):
            raw_path = str(raw).strip()
            if not raw_path:
                continue
            filter_path = resolve_from_base(base_dir_path, raw_path)
            if not filter_path.exists() or not filter_path.is_file():
                fail(
                    t(
                        "validate.error.invalid_extra_filter",
                        "Invalid path in 'filters.extra_lua_filters[{idx}]': file does not exist ({path})",
                        idx=idx,
                        path=filter_path,
                    )
                )


def main() -> None:
    if len(sys.argv) < 3:
        fail(t("validate.error.usage", "Usage: validate-config.py <config.yaml> <schema.json>"))

    cfg_path = Path(sys.argv[1])
    schema_path = Path(sys.argv[2])

    if not cfg_path.exists():
        fail(t("validate.error.config_not_found", "Config not found: {path}", path=cfg_path))
    if not schema_path.exists():
        fail(t("validate.error.schema_not_found", "Schema not found: {path}", path=schema_path))

    data = load_yaml(cfg_path)

    if not isinstance(data, dict):
        fail(t("validate.error.yaml_root_object", "YAML root must be an object/map"))

    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except Exception as e:
        fail(t("validate.error.schema_json_invalid", "Invalid JSON schema: {error}", error=e))

    if not isinstance(schema, dict):
        fail(t("validate.error.schema_root_object", "Invalid schema: root must be an object"))

    validate_with_schema(data, schema)
    validate_runtime_paths(data, cfg_path)
    print(f"✅ {t('validate.ok', 'Config valid')}")


if __name__ == "__main__":
    main()
