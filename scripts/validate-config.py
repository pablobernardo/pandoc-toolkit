#!/usr/bin/env python3
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any


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
        fail(f"YAML inválido: {e}")


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
  STDERR.puts "YAML inválido: #{e.message}"
  exit 2
end
"""

    proc = subprocess.run(
        ["ruby", "-e", ruby_script, str(path)],
        capture_output=True,
        text=True,
    )
    if proc.returncode == 2:
        fail(proc.stderr.strip() or "YAML inválido")
    if proc.returncode != 0:
        return None

    try:
        return json.loads(proc.stdout)
    except Exception as e:
        fail(f"No se pudo parsear JSON convertido desde Ruby: {e}")


def path_label(path: list[str]) -> str:
    return "root" if not path else ".".join(path)


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
            fail(f"La raíz debe ser de tipo {expected_type}")
        fail(f"'{label}' debe ser de tipo {expected_type}")

    if expected_type == "object":
        if not isinstance(data, dict):
            fail(f"'{label}' debe ser de tipo object")

        required = schema.get("required", [])
        if required:
            missing = [k for k in required if k not in data]
            if missing:
                fail(f"En '{label}' faltan campos obligatorios: {', '.join(missing)}")

        additional_props = schema.get("additionalProperties", True)
        properties = schema.get("properties", {})
        if additional_props is False:
            extra = sorted([k for k in data.keys() if k not in properties])
            if extra:
                fail(f"En '{label}' hay campos no permitidos: {', '.join(extra)}")

        for key, prop_schema in properties.items():
            if key in data:
                validate_with_schema(data[key], prop_schema, [*path, key])

    elif expected_type == "array":
        if not isinstance(data, list):
            fail(f"'{label}' debe ser de tipo array")

        min_items = schema.get("minItems")
        if isinstance(min_items, int) and len(data) < min_items:
            fail(f"'{label}' debe tener al menos {min_items} elemento(s)")

        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for idx, item in enumerate(data):
                validate_with_schema(item, item_schema, [*path, f"[{idx}]"])

    elif expected_type == "string":
        if not isinstance(data, str):
            fail(f"'{label}' debe ser de tipo string")
        min_length = schema.get("minLength")
        if isinstance(min_length, int) and len(data) < min_length:
            fail(f"'{label}' no puede estar vacío")

    elif expected_type == "integer":
        if not (isinstance(data, int) and not isinstance(data, bool)):
            fail(f"'{label}' debe ser de tipo integer")
        minimum = schema.get("minimum")
        if isinstance(minimum, int) and data < minimum:
            fail(f"'{label}' debe ser >= {minimum}")

    elif expected_type == "boolean":
        if not isinstance(data, bool):
            fail(f"'{label}' debe ser de tipo boolean")


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
        fail("'project.base_dir' es obligatorio")

    base_dir_path = (cfg_path.parent / base_dir).resolve()

    chapters_dir_raw = str(input_cfg.get("chapters_dir", "")).strip()
    if chapters_dir_raw:
        chapters_dir_path = resolve_from_base(base_dir_path, chapters_dir_raw)
        if not chapters_dir_path.exists() or not chapters_dir_path.is_dir():
            fail(f"Ruta inválida en 'input.chapters_dir': no existe directorio ({chapters_dir_path})")

    template_raw = str(pandoc_cfg.get("template", "")).strip()
    if template_raw:
        template_path = resolve_from_base(base_dir_path, template_raw)
        if not template_path.exists() or not template_path.is_file():
            fail(f"Ruta inválida en 'pandoc.template': no existe fichero ({template_path})")

    extra_filters = filters_cfg.get("extra_lua_filters") or []
    if isinstance(extra_filters, list):
        for idx, raw in enumerate(extra_filters):
            raw_path = str(raw).strip()
            if not raw_path:
                continue
            filter_path = resolve_from_base(base_dir_path, raw_path)
            if not filter_path.exists() or not filter_path.is_file():
                fail(
                    f"Ruta inválida en 'filters.extra_lua_filters[{idx}]': "
                    f"no existe fichero ({filter_path})"
                )


def main() -> None:
    if len(sys.argv) < 3:
        fail("Uso: validate-config.py <config.yaml> <schema.json>")

    cfg_path = Path(sys.argv[1])
    schema_path = Path(sys.argv[2])

    if not cfg_path.exists():
        fail(f"Config no encontrada: {cfg_path}")
    if not schema_path.exists():
        fail(f"Schema no encontrado: {schema_path}")

    data = load_yaml_with_python(cfg_path)
    if data is None:
        data = load_yaml_with_ruby(cfg_path)
    if data is None:
        fail("No hay parser YAML disponible (instalá PyYAML o Ruby)")

    if not isinstance(data, dict):
        fail("La raíz del YAML debe ser un objeto/map")

    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except Exception as e:
        fail(f"Schema JSON inválido: {e}")

    if not isinstance(schema, dict):
        fail("Schema inválido: la raíz debe ser un objeto")

    validate_with_schema(data, schema)
    validate_runtime_paths(data, cfg_path)
    print("✅ Config válida")


if __name__ == "__main__":
    main()
