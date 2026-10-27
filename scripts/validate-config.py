#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

try:
    from i18n_runtime import t
except Exception:
    def t(_key: str, fallback: str, **kwargs: object) -> str:
        try:
            return fallback.format(**kwargs)
        except Exception:
            return fallback


def fail(msg: str) -> None:
    print(f"❌ {msg}")
    raise SystemExit(1)


def load_yaml_with_python(path: Path):
    try:
        import yaml  # type: ignore
    except Exception:
        return None
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as e:
        fail(t("validate.error.yaml_invalid", "Invalid YAML: {error}", error=e))


def load_yaml_with_ruby(path: Path):
    if subprocess.run(["ruby", "-e", "require 'yaml'; require 'json'"], capture_output=True).returncode != 0:
        return None

    ruby_script = r"""
require 'yaml'
require 'json'
path = ARGV[0]
begin
  data = YAML.safe_load(File.read(path), permitted_classes: [], aliases: false)
  puts JSON.generate(data)
rescue => e
  STDERR.puts "Invalid YAML: #{e.message}"
  exit 2
end
"""

    proc = subprocess.run(
        ["ruby", "-e", ruby_script, str(path)],
        capture_output=True,
        text=True,
    )
    if proc.returncode == 2:
        fail(proc.stderr.strip() or t("validate.error.yaml_invalid_generic", "Invalid YAML"))
    if proc.returncode != 0:
        return None

    try:
        return json.loads(proc.stdout)
    except Exception as e:
        fail(t("validate.error.ruby_json_parse", "Could not parse JSON converted from Ruby: {error}", error=e))


def path_label(path: list[str]) -> str:
    return "root" if not path else ".".join(path)


# Supported JSON-Schema subset: type, properties, required, additionalProperties,
# items, minItems, minLength, minimum and enum. tests/run.sh fails if the schema
# starts using anything else, so a keyword can never be silently ignored.
def check_type(value: Any, expected: str) -> bool:
    if expected == "object":
        return isinstance(value, dict)
    if expected == "array":
        return isinstance(value, list)
    if expected == "string":
        return isinstance(value, str)
    if expected == "integer":
        return isinstance(value, int) and not isinstance(value, bool)
    if expected == "boolean":
        return isinstance(value, bool)
    return True


def validate_with_schema(data: Any, schema: dict[str, Any], path: list[str] | None = None) -> None:
    path = path or []
    label = path_label(path)

    expected_type = schema.get("type")
    if isinstance(expected_type, str) and not check_type(data, expected_type):
        if label == "root":
            fail(t("validate.error.root_type", "Root must be of type {type}", type=expected_type))
        fail(t("validate.error.field_type", "'{label}' must be of type {type}", label=label, type=expected_type))

    enum_values = schema.get("enum")
    if isinstance(enum_values, list) and enum_values and data not in enum_values:
        fail(
            t(
                "validate.error.not_in_enum",
                "'{label}' must be one of: {allowed} (got '{value}')",
                label=label,
                allowed=", ".join(str(item) for item in enum_values),
                value=data,
            )
        )

    if expected_type == "object":
        if not isinstance(data, dict):
            fail(t("validate.error.object_type", "'{label}' must be of type object", label=label))

        required = schema.get("required", [])
        if required:
            missing = [k for k in required if k not in data]
            if missing:
                fail(
                    t(
                        "validate.error.missing_required",
                        "In '{label}' required fields are missing: {fields}",
                        label=label,
                        fields=", ".join(missing),
                    )
                )

        additional_props = schema.get("additionalProperties", True)
        properties = schema.get("properties", {})
        if isinstance(additional_props, dict):
            # JSON Schema allows a schema here: every key not declared in
            # `properties` must satisfy it, and the failure names the key.
            for key, value in data.items():
                if key not in properties:
                    validate_with_schema(value, additional_props, [*path, key])
        elif additional_props is False:
            extra = sorted([k for k in data.keys() if k not in properties])
            if extra:
                fail(
                    t(
                        "validate.error.extra_fields",
                        "In '{label}' there are disallowed fields: {fields}",
                        label=label,
                        fields=", ".join(extra),
                    )
                )

        for key, prop_schema in properties.items():
            if key in data:
                validate_with_schema(data[key], prop_schema, [*path, key])

    elif expected_type == "array":
        if not isinstance(data, list):
            fail(t("validate.error.array_type", "'{label}' must be of type array", label=label))

        min_items = schema.get("minItems")
        if isinstance(min_items, int) and len(data) < min_items:
            fail(t("validate.error.min_items", "'{label}' must have at least {count} item(s)", label=label, count=min_items))

        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for idx, item in enumerate(data):
                validate_with_schema(item, item_schema, [*path, f"[{idx}]"])

    elif expected_type == "string":
        if not isinstance(data, str):
            fail(t("validate.error.string_type", "'{label}' must be of type string", label=label))
        min_length = schema.get("minLength")
        if isinstance(min_length, int) and len(data) < min_length:
            fail(t("validate.error.not_empty", "'{label}' cannot be empty", label=label))

    elif expected_type == "integer":
        if not (isinstance(data, int) and not isinstance(data, bool)):
            fail(t("validate.error.integer_type", "'{label}' must be of type integer", label=label))
        minimum = schema.get("minimum")
        if isinstance(minimum, int) and data < minimum:
            fail(t("validate.error.minimum", "'{label}' must be >= {minimum}", label=label, minimum=minimum))

    elif expected_type == "boolean":
        if not isinstance(data, bool):
            fail(t("validate.error.boolean_type", "'{label}' must be of type boolean", label=label))


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
    if template_raw:
        template_path = resolve_from_base(base_dir_path, template_raw)
        if not template_path.exists() or not template_path.is_file():
            fail(
                t(
                    "validate.error.invalid_template",
                    "Invalid path in 'pandoc.template': file does not exist ({path})",
                    path=template_path,
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

    data = load_yaml_with_python(cfg_path)
    if data is None:
        data = load_yaml_with_ruby(cfg_path)
    if data is None:
        fail(t("validate.error.no_yaml_parser", "No YAML parser available (install PyYAML or Ruby)"))

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
