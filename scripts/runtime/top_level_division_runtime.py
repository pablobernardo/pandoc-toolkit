#!/usr/bin/env python3
"""What a `pandoc.top_level_division` value means.

The renderer and the validator must agree: any value the validator accepts has
to become the pandoc argument the renderer actually passes. Both ask this
module instead of keeping their own rule, so validation cannot accept a value
the renderer rejects, or the other way round.

The field is optional. Absent, empty, or the explicit value ``default`` passes
no flag at all, so existing configurations keep Pandoc's own behaviour. Any
other value is one of Pandoc's own ``--top-level-division`` choices and becomes
exactly that argument.

The i18n message key both callers share lives here too: one rule, one message.
"""

from __future__ import annotations

DEFAULT = "default"

# Pandoc's own accepted values, in the order the error message lists them. The
# schema enum in schemas/pdf-config.schema.json mirrors this tuple; a test
# fails if the two ever drift apart.
ALLOWED_VALUES = (DEFAULT, "section", "chapter", "part")

# Both the renderer and the validator report an invalid value through this key,
# so a failure reads the same whichever command catches it.
ERROR_KEY = "top_level_division.error.invalid_value"

# The fallback used when a catalog cannot be loaded; the catalogs carry the
# translations under ERROR_KEY.
ERROR_FALLBACK = "Invalid 'pandoc.top_level_division' value: {value}. Supported values: {supported}"


def allowed_values() -> tuple[str, ...]:
    """The values a configuration may use, for messages."""
    return ALLOWED_VALUES


def is_allowed(raw: str) -> bool:
    """Whether a value is one of Pandoc's own top-level division choices."""
    return raw in ALLOWED_VALUES


def argument(raw: object) -> str:
    """The ``--top-level-division=<value>`` argument for a configured value.

    Absent, empty, or ``default`` resolves to no flag (an empty string).
    Anything else must be an allowed value: a ValueError carries the offending
    value, and the caller reports it through ``ERROR_KEY``.
    """
    if raw is None:
        return ""
    value = str(raw).strip()
    if not value or value == DEFAULT:
        return ""
    if not is_allowed(value):
        raise ValueError(value)
    return f"--top-level-division={value}"
