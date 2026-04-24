#!/usr/bin/env python3
from __future__ import annotations

import json
import re
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

PLACEHOLDER_RE = re.compile(r"\{([a-zA-Z_][a-zA-Z0-9_]*)\}")


def fail(msg: str) -> None:
    print(t("check_i18n.error.prefix", "❌ i18n check: {msg}", msg=msg))
    raise SystemExit(1)


def load_catalog(path: Path) -> dict[str, str]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(t("check_i18n.error.invalid_catalog", "invalid catalog at {path}: {error}", path=path, error=exc))

    if not isinstance(data, dict):
        fail(t("check_i18n.error.invalid_catalog_root", "invalid catalog at {path}: root must be object", path=path))

    result: dict[str, str] = {}
    for key, value in data.items():
        if not isinstance(key, str) or not key.strip():
            fail(t("check_i18n.error.invalid_key", "invalid key in {path}: {key}", path=path, key=repr(key)))
        if not isinstance(value, str) or not value.strip():
            fail(t("check_i18n.error.invalid_value", "invalid value for key '{key}' in {path}", key=key, path=path))
        result[key] = value
    return result


def placeholders(msg: str) -> set[str]:
    return set(PLACEHOLDER_RE.findall(msg))


def main() -> None:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(__file__).resolve().parents[1]
    locales_dir = root / "i18n/locales"
    if not locales_dir.exists():
        fail(t("check_i18n.error.locales_dir_missing", "locales directory does not exist: {path}", path=locales_dir))

    files = sorted(locales_dir.glob("*.json"))
    if not files:
        fail(t("check_i18n.error.no_catalogs", "no i18n catalogs found"))

    if not (locales_dir / "es.json").exists():
        fail(t("check_i18n.error.missing_base_es", "missing base catalog es.json"))

    catalogs = {f.stem: load_catalog(f) for f in files}
    base = catalogs["es"]
    base_keys = set(base.keys())

    for locale, cat in catalogs.items():
        keys = set(cat.keys())
        missing = sorted(base_keys - keys)
        extra = sorted(keys - base_keys)
        if missing:
            fail(
                t(
                    "check_i18n.error.missing_keys",
                    "{locale}: missing keys compared to es: {keys}",
                    locale=locale,
                    keys=", ".join(missing),
                )
            )
        if extra:
            fail(
                t(
                    "check_i18n.error.extra_keys",
                    "{locale}: extra keys not present in es: {keys}",
                    locale=locale,
                    keys=", ".join(extra),
                )
            )

        for key in sorted(base_keys):
            p_base = placeholders(base[key])
            p_loc = placeholders(cat[key])
            if p_base != p_loc:
                fail(
                    t(
                        "check_i18n.error.placeholder_mismatch",
                        "{locale}: placeholder mismatch in '{key}' (es={es_placeholders}, {locale}={locale_placeholders})",
                        locale=locale,
                        key=key,
                        es_placeholders=sorted(p_base),
                        locale_placeholders=sorted(p_loc),
                    )
                )

    print(t("check_i18n.ok", "✅ i18n OK: {locales} locales, {keys} keys verified", locales=len(catalogs), keys=len(base_keys)))


if __name__ == "__main__":
    main()
