#!/usr/bin/env python3
"""build.py - the bookkit tool.

One adapter for both book shapes:

* A **single volume**: a project directory with a ``manifest.yaml`` and no
  ``series.yaml``. The project directory is itself the volume.
* A **series**: a project directory with a ``series.yaml`` that holds the
  shared facts (collection, author, publisher, rights, language) and an
  ordered ``volumes`` list of volume directory names, each with its own
  ``manifest.yaml``.

Both YAML files are validated against this tool's own contract
(``manifest.schema.json`` and ``series.schema.json``) before anything else
happens. For every volume the tool then:

1. merges the series defaults under the volume's own overrides;
2. resolves every declared content path against the volume directory,
   failing when a printable file is missing, warning and skipping when an
   entry is declared ``optional``, and silently excluding ``print: false``
   entries;
3. generates the LaTeX mode-switch files (``\\mainmatter``, plus
   ``\\setcounter{chapter}`` when the volume declares ``chapter_start``,
   and ``\\appendix`` before the back matter) into the run output, so the
   content files carry no LaTeX markers;
4. writes one ``pdf.config.yaml`` per volume into the run output;
5. renders it through the public CLI (``bin/pandoc-pdf render``), unless
   ``--check`` asked only for validation and the generated configurations.

The tool belongs to the book, not to the pdf.config contract: the toolkit
only ever sees a standard ``pdf.config.yaml``. It runs from any working
directory, uses no absolute paths and no network, and reads YAML through the
toolkit's own shared loader (``scripts/runtime/schema_runtime.py``): PyYAML
when available, Ruby's stdlib YAML through a subprocess otherwise; without
either parser it fails with a clear message.
"""

from __future__ import annotations

import argparse
import importlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import NoReturn

TOOL_DIR = Path(__file__).resolve().parent
TOOLKIT_ROOT = TOOL_DIR.parents[2]
RUNTIME_DIR = TOOLKIT_ROOT / "scripts" / "runtime"
if str(RUNTIME_DIR) not in sys.path:
    sys.path.insert(0, str(RUNTIME_DIR))

# The shared runtime lives two directories up; it is imported by path so the
# tool works no matter where it is invoked from.
schema_runtime = importlib.import_module("schema_runtime")
load_yaml = schema_runtime.load_yaml
validate_with_schema = schema_runtime.validate_with_schema

CLI = TOOLKIT_ROOT / "bin" / "pandoc-pdf"
MANIFEST_SCHEMA = TOOL_DIR / "manifest.schema.json"
SERIES_SCHEMA = TOOL_DIR / "series.schema.json"
# The default template is the project's own templates/book.tex (see
# default_template): the toolkit ships no template path of its own, and the
# old checkout-only default (examples/book/templates/book.tex) exists in no
# installed artifact.
DEFAULT_OUT = Path(".output") / "bookkit"

LANG_CODES = ("en", "es", "pt", "gl")


def die(message: str) -> NoReturn:
    print(f"build.py: error: {message}", file=sys.stderr)
    raise SystemExit(1)


def warn(message: str) -> None:
    print(f"build.py: warning: {message}", file=sys.stderr)


# --- Small helpers ----------------------------------------------------------


def slugify(value: str) -> str:
    """Lowercase, ASCII, single dashes; the toolkit's own naming rule."""

    decomposed = value.encode("ascii", "ignore").decode("ascii").lower()
    return re.sub(r"[^a-z0-9]+", "-", decomposed).strip("-") or "volume"


def quoted(value: str) -> str:
    """A safe double-quoted YAML scalar."""

    return '"' + str(value).replace("\\", "\\\\").replace('"', '\\"') + '"'


def relpath(target: Path, start: Path) -> str:
    """A relative path with forward slashes, usable inside a config."""

    return Path(os.path.relpath(target, start)).as_posix()


def natural_key(name: str) -> list[tuple[int, int, str]]:
    """Sort key where digit runs compare numerically (chapter-2 < chapter-10).

    Mirrors the toolkit's own 'natural' order (scripts/runtime/render-native.py).
    """

    return [(0, len(part), part) if part.isdigit() else (1, 0, part) for part in re.split(r"(\d+)", name.lower())]


def default_template(project: Path) -> Path:
    """The project's own template: <project>/templates/book.tex.

    The tool no longer defaults to the toolkit's book example
    (examples/book/templates/book.tex): that path only exists in a toolkit
    checkout, never in an installed artifact. A consumer copies the example
    template into the project, or passes --template with its own.
    """
    default = project / "templates" / "book.tex"
    if not default.is_file():
        die(
            f"no book template in the project: {default.as_posix()}:"
            " copy the toolkit's example template"
            " (examples/book/templates/book.tex) into the project's"
            " templates/ directory, or pass --template with a book-class"
            " LaTeX template"
        )
    return default


# --- Manifest model ---------------------------------------------------------


class Entry:
    """One declared content entry: a path string or a map with file/print/optional.

    The contract schemas already enforce the shape; these checks remain as
    the tool's own defense and keep the documented error messages.
    """

    section: str
    logical: str
    volume: str
    file: str
    do_print: bool
    optional: bool

    def __init__(self, section: str, logical: str, raw: object, volume: str) -> None:
        self.section = section
        self.logical = logical
        self.volume = volume
        if isinstance(raw, str):
            self.file = raw
            self.do_print = True
            self.optional = False
            return
        if not isinstance(raw, dict):
            die(
                f"volume '{volume}': entry '{logical}' ({section})"
                " must be a path string or a mapping with 'file'"
            )
        file_value = raw.get("file")
        if not isinstance(file_value, str) or not file_value.strip():
            die(
                f"volume '{volume}': entry '{logical}' ({section})"
                " must declare a 'file' path"
            )
        self.file = file_value
        do_print = raw.get("print", True)
        if not isinstance(do_print, bool):
            die(f"volume '{volume}': entry '{logical}' ({section}): 'print' must be a boolean")
        self.do_print = do_print
        optional = raw.get("optional", False)
        if not isinstance(optional, bool):
            die(f"volume '{volume}': entry '{logical}' ({section}): 'optional' must be a boolean")
        self.optional = optional

    def resolve(self, volume_dir: Path) -> str | None:
        """The declared path when it belongs in the PDF, else None.

        ``print: false`` excludes the entry silently. A missing file fails
        with the volume, the logical name and the path, unless the entry is
        declared ``optional``, in which case it is skipped with a warning.
        """
        if not self.do_print:
            return None
        if not (volume_dir / self.file).is_file():
            if self.optional:
                warn(
                    f"volume '{self.volume}': {self.section} entry '{self.logical}'"
                    " is optional and its file was not found, skipped: "
                    f"{self.file}"
                )
                return None
            die(
                f"volume '{self.volume}': {self.section} entry '{self.logical}'"
                f" declares a missing file: {self.file}"
            )
        return self.file


def ordered_entries(section: str, raw: object, volume: str) -> list[Entry]:
    """front_matter/back_matter: an ordered map of logical name to entry."""

    if raw is None:
        return []
    if not isinstance(raw, dict) or not raw:
        die(f"volume '{volume}': '{section}' must be a non-empty map of name to entry")
    return [Entry(section, str(name), value, volume) for name, value in raw.items()]


def ordered_chapters(chapters_dir: str, volume: str, volume_dir: Path) -> list[Entry]:
    """chapters: ordered — every *.md in chapters_dir, in natural order."""

    base = volume_dir / chapters_dir
    if not base.is_dir():
        die(f"volume '{volume}': 'chapters_dir' is not a directory: {chapters_dir}")
    names = sorted((p.name for p in base.glob("*.md") if p.is_file()), key=natural_key)
    if not names:
        die(f"volume '{volume}': no chapters found in '{chapters_dir}'")
    return [
        Entry("chapters", str(index + 1), (Path(chapters_dir) / name).as_posix(), volume)
        for index, name in enumerate(names)
    ]


def chapter_entries(raw: object, volume: str) -> list[Entry]:
    """chapters: an explicit ordered list of entries (schema already enforced)."""

    if not isinstance(raw, list) or not raw:
        die(f"volume '{volume}': 'chapters' must be the keyword 'ordered' or a non-empty list")
    return [
        Entry("chapters", str(index + 1), item, volume)
        for index, item in enumerate(raw)
    ]


# --- Volume build -----------------------------------------------------------


def resolve_entries(entries: list[Entry], volume_dir: Path) -> list[str]:
    resolved = []
    for entry in entries:
        path = entry.resolve(volume_dir)
        if path is not None:
            resolved.append(path)
    return resolved


def write_mode_file(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def merge_defaults(manifest: dict, defaults: dict) -> dict:
    """Series facts sit under the volume's own overrides."""
    shared = ("collection", "author", "publisher", "rights", "language")
    merged = dict(manifest)
    for key in shared:
        if key not in merged and key in defaults:
            merged[key] = defaults[key]
    return merged


def build_volume(
    manifest: dict,
    volume_name: str,
    volume_dir: Path,
    defaults: dict,
    out_volume_dir: Path,
    template: Path,
) -> Path:
    """Write the generated files and one pdf.config.yaml; return the config path."""

    merged = merge_defaults(manifest, defaults)

    title_value = merged.get("title")
    if not isinstance(title_value, str) or not title_value.strip():
        die(f"volume '{volume_name}': manifest must declare a non-empty 'title'")
    title: str = title_value

    chapter_start = merged.get("chapter_start")
    if chapter_start is not None and (
        not isinstance(chapter_start, int)
        or isinstance(chapter_start, bool)
        or chapter_start < 1
    ):
        die(f"volume '{volume_name}': 'chapter_start' must be an integer of 1 or more")

    language = merged.get("language")
    if language is not None and language not in LANG_CODES:
        die(
            f"volume '{volume_name}': 'language' must be one of"
            f" {', '.join(LANG_CODES)} (got {language!r})"
        )

    front = resolve_entries(
        ordered_entries("front_matter", merged.get("front_matter"), volume_name), volume_dir
    )
    chapters_raw = merged.get("chapters")
    if isinstance(chapters_raw, str):
        chapters_dir = merged.get("chapters_dir", "content/chapters")
        chapters = resolve_entries(ordered_chapters(chapters_dir, volume_name, volume_dir), volume_dir)
    else:
        chapters = resolve_entries(chapter_entries(chapters_raw, volume_name), volume_dir)
    back = resolve_entries(
        ordered_entries("back_matter", merged.get("back_matter"), volume_name), volume_dir
    )

    # Generated mode files live in the run output, never inside the content
    # directories. explicit_files resolves against the volume directory
    # (input.chapters_dir is "."), so the tool computes the relative hops.
    generated_dir = out_volume_dir / "generated"
    mainmatter_file = generated_dir / "00-mainmatter.md"
    mainmatter_text = "\\mainmatter\n"
    if chapter_start is not None:
        # The first chapter of this volume gets the declared number: the
        # counter is set to N-1 because the chapter command steps it.
        mainmatter_text += f"\\setcounter{{chapter}}{{{chapter_start - 1}}}\n"
    write_mode_file(mainmatter_file, mainmatter_text)

    explicit_files = list(front) + [relpath(mainmatter_file, volume_dir)] + list(chapters)
    if back:
        appendix_file = generated_dir / "01-appendix.md"
        write_mode_file(appendix_file, "\\appendix\n")
        explicit_files += [relpath(appendix_file, volume_dir)] + list(back)

    out_volume_dir.mkdir(parents=True, exist_ok=True)
    config_path = out_volume_dir / "pdf.config.yaml"
    config_path.write_text(
        emit_config(merged, title, volume_dir, out_volume_dir, explicit_files, template),
        encoding="utf-8",
    )
    return config_path


def emit_config(
    manifest: dict,
    title: str,
    volume_dir: Path,
    out_volume_dir: Path,
    explicit_files: list[str],
    template: Path,
) -> str:
    """One standard pdf.config.yaml per volume, emitted as canonical text.

    The text is written by hand instead of a YAML dumper so the result is
    byte-identical whichever parser read the manifests.
    """
    slug = slugify(title)
    lines = [
        "# Generated by scripts/tools/bookkit/build.py. Do not edit:",
        "# change the volume's manifest.yaml (and series.yaml) instead.",
        "version: 1",
        "",
        "project:",
        f"  name: {quoted(slug)}",
        f"  base_dir: {quoted(relpath(volume_dir, out_volume_dir))}",
        "",
        "document:",
        f"  title: {quoted(title)}",
    ]
    for key in ("subtitle", "author", "publisher", "date", "rights"):
        value = manifest.get(key)
        if isinstance(value, str) and value.strip():
            lines.append(f"  {key}: {quoted(value)}")
    language = manifest.get("language")
    if isinstance(language, str) and language:
        lines.append(f"  language: {quoted(language)}")
    lines.append("  titlepage: true")
    metadata = {
        key: str(manifest[key])
        for key in ("collection", "isbn", "audience", "description")
        if isinstance(manifest.get(key), str) and manifest[key].strip()
    }
    if metadata:
        lines.append("  metadata:")
        lines.extend(f"    {key}: {quoted(value)}" for key, value in metadata.items())
    lines.extend(
        [
            "",
            "input:",
            '  chapters_dir: "."',
            '  glob: "*.md"',
            "  order: natural",
            "  explicit_files:",
        ]
    )
    lines.extend(f"    - {quoted(path)}" for path in explicit_files)
    lines.extend(
        [
            "",
            "output:",
            "  formats: [pdf]",
            f"  dir: {quoted(relpath(out_volume_dir, volume_dir))}",
            f"  file_prefix: {quoted(slug)}",
            '  suffix: "${date:YYYYMMDD}"',
            "  keep_merged_markdown: false",
            "",
            "pandoc:",
            "  pdf_engine: xelatex",
            "  toc: true",
            "  toc_depth: 2",
            "  number_sections: true",
            f"  template: {quoted(relpath(template, volume_dir))}",
            "  resource_path:",
            '    - "content"',
            "",
            "filters:",
            "  emoji:",
            "    enabled: false",
            "  mermaid:",
            "    enabled: false",
            "  extra_lua_filters: []",
            "",
            "runtime:",
            "  required_commands:",
            "    - pandoc",
            "    - xelatex",
            "    - python3",
            "  strict: true",
            "",
        ]
    )
    return "\n".join(lines)


# --- Contracts --------------------------------------------------------------


def load_contract(path: Path, schema_path: Path) -> dict:
    """Load a YAML file and validate it against one of this tool's schemas."""

    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except Exception as error:
        die(f"invalid contract schema {schema_path.name}: {error}")
    data = load_yaml(path)
    if not isinstance(data, dict):
        die(f"root of {path} must be a mapping")
    validate_with_schema(data, schema)
    return data


# --- Main -------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description=(
            "bookkit: turn declarative book manifests (manifest.yaml, series.yaml)"
            " into standard pdf.config.yaml files and render them through bin/pandoc-pdf."
        )
    )
    parser.add_argument(
        "projects",
        nargs="+",
        help="project directories: a volume directory with manifest.yaml, or a series directory with series.yaml",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="validate the manifests against the contract and emit the generated configurations without rendering",
    )
    parser.add_argument(
        "--out",
        default=str(DEFAULT_OUT),
        help=f"run output directory (default: {DEFAULT_OUT.as_posix()})",
    )
    parser.add_argument(
        "--template",
        default=None,
        help="book-class LaTeX template for the generated configurations (default: <project>/templates/book.tex)",
    )
    args = parser.parse_args()

    explicit_template: Path | None = None
    if args.template:
        explicit_template = Path(args.template).resolve()
        if not explicit_template.is_file():
            die(f"book template not found: {explicit_template}")

    projects: list[tuple[Path, Path]] = []
    for raw in args.projects:
        project = Path(raw)
        if not project.is_dir():
            die(f"not a directory: {project}")
        if not (project / "series.yaml").is_file() and not (project / "manifest.yaml").is_file():
            die(f"no series.yaml or manifest.yaml in: {project}")
        template = explicit_template if explicit_template else default_template(project)
        projects.append((project, template))

    # Contract validation first, for every project, before anything is built:
    # a manifest that fails validation never reaches the build.
    plans: list[tuple[Path, str, Path, dict, dict, bool, Path]] = []
    for project, template in projects:
        series_path = project / "series.yaml"
        if series_path.is_file():
            series = load_contract(series_path, SERIES_SCHEMA)
            for volume_name in series["volumes"]:
                volume_dir = project / volume_name
                if not (volume_dir / "manifest.yaml").is_file():
                    die(f"series '{project.name}': volume '{volume_name}' has no manifest.yaml")
                manifest = load_contract(volume_dir / "manifest.yaml", MANIFEST_SCHEMA)
                plans.append((project, volume_name, volume_dir, series, manifest, True, template))
        else:
            manifest = load_contract(project / "manifest.yaml", MANIFEST_SCHEMA)
            plans.append((project, project.name, project, {}, manifest, False, template))

    if not args.check and not CLI.is_file():
        die(f"pandoc-pdf CLI not found: {CLI}")

    out_root = Path(args.out).resolve()
    failures: list[str] = []
    for project, volume_name, volume_dir, defaults, manifest, is_series, template in plans:
        # A series nests one output directory per volume; a single-volume
        # project is its own volume and does not repeat its name.
        out_volume_dir = (
            out_root / project.name / volume_name if is_series else out_root / project.name
        )
        print(f"==> {project.name}/{volume_name}")
        config_path = build_volume(manifest, volume_name, volume_dir, defaults, out_volume_dir, template)
        print(f"    config: {relpath(config_path, Path.cwd())}")

        if args.check:
            continue

        result = subprocess.run([str(CLI), "render", "-c", str(config_path)])
        pdfs = sorted(out_volume_dir.glob("*.pdf"))
        if result.returncode == 0 and pdfs:
            for pdf in pdfs:
                print(f"    [ok] {relpath(pdf, Path.cwd())}")
        else:
            failures.append(f"{project.name}/{volume_name}")
            print(f"    [FAIL] {project.name}/{volume_name} (exit {result.returncode})")

    if args.check:
        print(f"Check ok: {len(plans)} volume(s) validated, configurations in {relpath(out_root, Path.cwd())}")
        return
    if failures:
        die(f"render failed for: {', '.join(failures)}")
    print(f"Done: {len(plans)} volume(s) rendered into {relpath(out_root, Path.cwd())}")


if __name__ == "__main__":
    main()
