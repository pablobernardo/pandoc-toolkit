#!/usr/bin/env python3
"""What a `pandoc.template` value means.

The renderer and the validator must agree: any value the validator accepts has to
resolve to the template the renderer actually uses. Both ask this module instead
of keeping their own rule, so validation cannot accept a name the renderer
rejects, or the other way round.

Three forms:

- empty: the toolkit default template;
- a known bare name (`book`) - no separator and no dot: the toolkit's own
  ``templates/<name>.tex``, which ships inside the artifact, so the same
  configuration works in a checkout and in an installation;
- anything else: a path, which the caller resolves against ``base_dir``.
"""

from __future__ import annotations

from pathlib import Path

DEFAULT_TEMPLATE = "templates/default.tex"

# A bare name is a product name, not a file. Adding a template is one entry here,
# and both the renderer and the validator pick it up.
BUILTIN_TEMPLATES = {
    "book": "templates/book.tex",
}


def is_bare_name(raw: str) -> bool:
    """A value with no separator and no dot is a name, never a path."""
    return raw != "" and "/" not in raw and "\\" not in raw and "." not in raw


def known_names() -> tuple[str, ...]:
    """The names a configuration may use, for messages."""
    return tuple(sorted(BUILTIN_TEMPLATES))


def builtin_path(root_dir: Path, raw: str) -> Path | None:
    """The shipped template for a known name, or None when the name is unknown."""
    relative = BUILTIN_TEMPLATES.get(raw)
    if relative is None:
        return None
    return root_dir / relative


def default_path(root_dir: Path) -> Path:
    """The template used when the configuration declares none."""
    return root_dir / DEFAULT_TEMPLATE
