#!/usr/bin/env python3
"""Shared schema runtime for the toolkit's validating Python entry points.

Two pieces live here so they exist exactly once:

* the YAML loader — PyYAML when importable, Ruby's stdlib YAML through a
  subprocess otherwise (the same fallback the renderer uses); Ruby resolves
  through one shared rule, the usual install locations first and PATH second,
  so no entry point can disagree about which parser is reachable. Without
  either parser it fails with a clear message, and
* the JSON-Schema-subset validator that applies `schemas/skelepress-config.schema.json`
  (via `validate-config.py`) and the tool-local contracts under
  `scripts/tools/bookkit/` (via its `build.py`).

Supported JSON-Schema subset: `type`, `properties`, `required`,
`additionalProperties`, `items`, `minItems`, `minLength`, `minimum`, `enum`
and `anyOf`. tests/run.sh fails if `schemas/skelepress-config.schema.json` starts
using anything else, so a keyword can never be silently ignored; a new
keyword needs support here first.

Errors go through the toolkit's shared i18n catalogs: every message comes
from `t()`, so a catalog without a key degrades to the English fallback.
The `fail()` helper prints the toolkit's error prefix and exits 1, which is
the contract `validate-config.py` has always exposed.
"""

from __future__ import annotations

import json
import shutil
import subprocess
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


def fail(msg: str) -> NoReturn:
    print(f"❌ {msg}")
    raise SystemExit(1)


class SchemaError(Exception):
    """A validation failure, carrying the already-localized message."""


class YamlError(Exception):
    """A YAML read failure, carrying the parser's own error text.

    The callers render it in their own words, so the exception stays free of
    catalog keys: `kind` is ``parse`` for a document the parser rejected and
    ``ruby_json`` when Ruby parsed the file but its JSON conversion could not
    be read back.
    """

    def __init__(self, message: str, kind: str = "parse") -> None:
        super().__init__(message)
        self.kind = kind


# --- YAML reading -----------------------------------------------------------


def resolve_ruby_binary() -> str | None:
    """Ruby from the usual install locations first, then from PATH.

    A hardcoded candidate keeps the loader working when PATH is minimal (CI, an
    installed CLI, a sandboxed test); a PATH-only lookup cannot.
    """
    candidates = ["/usr/bin/ruby", "/opt/homebrew/bin/ruby"]
    for candidate in candidates:
        if Path(candidate).is_file() and Path(candidate).exists():
            return candidate
    return shutil.which("ruby")


def load_yaml_with_python(path: Path):
    """The PyYAML reading of `path`, or None when PyYAML is not importable."""
    try:
        import yaml  # type: ignore
    except Exception:
        return None
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8"))
    except Exception as e:
        raise YamlError(str(e)) from e


def load_yaml_with_ruby(path: Path):
    """The Ruby stdlib reading of `path`, or None when Ruby is unavailable."""
    ruby_bin = resolve_ruby_binary()
    if ruby_bin is None:
        return None

    if subprocess.run([ruby_bin, "-e", "require 'yaml'; require 'json'"], capture_output=True).returncode != 0:
        return None

    ruby_script = r"""
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

    proc = subprocess.run(
        [ruby_bin, "-e", ruby_script, str(path)],
        capture_output=True,
        text=True,
    )
    if proc.returncode == 2:
        raise YamlError(proc.stderr.strip())
    if proc.returncode != 0:
        return None

    try:
        return json.loads(proc.stdout)
    except Exception as e:
        raise YamlError(str(e), kind="ruby_json") from e


def load_yaml(path: Path):
    """Load a YAML file: PyYAML when importable, Ruby's stdlib otherwise."""
    try:
        data = load_yaml_with_python(path)
        if data is None:
            data = load_yaml_with_ruby(path)
    except YamlError as e:
        if e.kind == "ruby_json":
            fail(t("validate.error.ruby_json_parse", "Could not parse JSON converted from Ruby: {error}", error=e))
        if str(e):
            fail(t("validate.error.yaml_invalid", "Invalid YAML: {error}", error=e))
        fail(t("validate.error.yaml_invalid_generic", "Invalid YAML"))
    if data is None:
        fail(t("validate.error.no_yaml_parser", "No YAML parser available (install PyYAML or Ruby)"))
    return data


# --- Schema subset ----------------------------------------------------------


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


def _validate(data: Any, schema: dict[str, Any], path: list[str]) -> None:
    """The validator proper: raises SchemaError instead of exiting, so anyOf
    can try each branch and report one failure only when every branch fails."""
    label = path_label(path)

    expected_type = schema.get("type")
    if isinstance(expected_type, str) and not check_type(data, expected_type):
        if label == "root":
            raise SchemaError(t("validate.error.root_type", "Root must be of type {type}", type=expected_type))
        raise SchemaError(t("validate.error.field_type", "'{label}' must be of type {type}", label=label, type=expected_type))

    enum_values = schema.get("enum")
    if isinstance(enum_values, list) and enum_values and data not in enum_values:
        raise SchemaError(
            t(
                "validate.error.not_in_enum",
                "'{label}' must be one of: {allowed} (got '{value}')",
                label=label,
                allowed=", ".join(str(item) for item in enum_values),
                value=data,
            )
        )

    # anyOf: the data must satisfy at least one branch. Branch failures are
    # collected, not reported, because the useful message is about the value
    # not matching any allowed shape, not about the first branch's internals.
    any_of = schema.get("anyOf")
    if isinstance(any_of, list) and any_of:
        matched = False
        for branch in any_of:
            try:
                _validate(data, branch, path)
            except SchemaError:
                continue
            matched = True
            break
        if not matched:
            raise SchemaError(
                t("validate.error.no_any_of_match", "'{label}' does not match any allowed shape", label=label)
            )

    if expected_type == "object":
        if not isinstance(data, dict):
            raise SchemaError(t("validate.error.object_type", "'{label}' must be of type object", label=label))

        required = schema.get("required", [])
        if required:
            missing = [k for k in required if k not in data]
            if missing:
                raise SchemaError(
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
                    _validate(value, additional_props, [*path, key])
        elif additional_props is False:
            extra = sorted(k for k in data if k not in properties)
            if extra:
                raise SchemaError(
                    t(
                        "validate.error.extra_fields",
                        "In '{label}' there are disallowed fields: {fields}",
                        label=label,
                        fields=", ".join(extra),
                    )
                )

        for key, prop_schema in properties.items():
            if key in data:
                _validate(data[key], prop_schema, [*path, key])

    elif expected_type == "array":
        if not isinstance(data, list):
            raise SchemaError(t("validate.error.array_type", "'{label}' must be of type array", label=label))

        min_items = schema.get("minItems")
        if isinstance(min_items, int) and len(data) < min_items:
            raise SchemaError(t("validate.error.min_items", "'{label}' must have at least {count} item(s)", label=label, count=min_items))

        item_schema = schema.get("items")
        if isinstance(item_schema, dict):
            for idx, item in enumerate(data):
                _validate(item, item_schema, [*path, f"[{idx}]"])

    elif expected_type == "string":
        if not isinstance(data, str):
            raise SchemaError(t("validate.error.string_type", "'{label}' must be of type string", label=label))
        min_length = schema.get("minLength")
        if isinstance(min_length, int) and len(data) < min_length:
            raise SchemaError(t("validate.error.not_empty", "'{label}' cannot be empty", label=label))

    elif expected_type == "integer":
        if not (isinstance(data, int) and not isinstance(data, bool)):
            raise SchemaError(t("validate.error.integer_type", "'{label}' must be of type integer", label=label))
        minimum = schema.get("minimum")
        if isinstance(minimum, int) and data < minimum:
            raise SchemaError(t("validate.error.minimum", "'{label}' must be >= {minimum}", label=label, minimum=minimum))

    elif expected_type == "boolean":
        if not isinstance(data, bool):
            raise SchemaError(t("validate.error.boolean_type", "'{label}' must be of type boolean", label=label))


def validate_with_schema(data: Any, schema: dict[str, Any], path: list[str] | None = None) -> None:
    """Validate `data` against `schema`; on failure print and exit like fail()."""
    try:
        _validate(data, schema, path or [])
    except SchemaError as error:
        fail(str(error))
