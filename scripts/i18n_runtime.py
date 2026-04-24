#!/usr/bin/env python3
from __future__ import annotations

import json
import os
from pathlib import Path


def _locales_dir() -> Path:
    return Path(__file__).resolve().parents[1] / "i18n" / "locales"


def _available_locales() -> set[str]:
    dir_path = _locales_dir()
    if not dir_path.exists():
        return {"en"}
    locales = {p.stem for p in dir_path.glob("*.json") if p.stem}
    return locales or {"en"}


def _resolve_lang(raw: str | None = None) -> str:
    value = raw or os.environ.get("PANDOC_PDF_LANG") or os.environ.get("LC_ALL") or os.environ.get("LANG") or "en"
    value = value.split(".", 1)[0].split("@", 1)[0].replace("_", "-").lower()
    available = _available_locales()

    if value in available:
        return value

    base = value.split("-", 1)[0]
    if base in available:
        return base

    if "en" in available:
        return "en"

    return sorted(available)[0]


def _load_catalog(lang: str) -> dict[str, str]:
    path = _locales_dir() / f"{lang}.json"
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception:
        return {}
    return data if isinstance(data, dict) else {}


_LANG = _resolve_lang()
_CATALOG = _load_catalog(_LANG)


def t(key: str, fallback: str, **kwargs: object) -> str:
    template = _CATALOG.get(key)
    if not isinstance(template, str) or not template.strip():
        template = fallback
    try:
        return template.format(**kwargs)
    except Exception:
        return template
