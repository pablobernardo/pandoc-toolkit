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
4. writes one ``skelepress.config.yaml`` per volume into the run output;
5. renders it through the public CLI (``bin/skelepress render``), unless
   ``--check`` asked only for validation and the generated configurations.

The tool belongs to the book, not to the pdf.config contract: the toolkit
only ever sees a standard ``skelepress.config.yaml``. It runs from any working
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
template_runtime = importlib.import_module("template_runtime")
is_bare_name = template_runtime.is_bare_name

CLI = TOOLKIT_ROOT / "bin" / "skelepress"
MANIFEST_SCHEMA = TOOL_DIR / "manifest.schema.json"
SERIES_SCHEMA = TOOL_DIR / "series.schema.json"
# The default template is the builtin name: the toolkit ships templates/book.tex
# inside the artifact, so one generated configuration works in a checkout and in
# an installation. --template still accepts a path.
DEFAULT_TEMPLATE = "book"
DEFAULT_OUT = Path(".skelepress")

LANG_CODES = ("en", "es", "pt", "gl")

# How the contents are separated into blocks, at the two boundaries the
# adapter controls: before the first chapter and before the first appendix.
TOC_SEPARATORS = ("none", "space", "rule", "label")
DEFAULT_TOC_SEPARATORS = "space"


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


def default_template_hint() -> str:
    """What to tell a consumer whose explicit template path does not exist."""
    return (
        "pass --template with a book-class LaTeX template, or omit it to use"
        f" the toolkit's builtin '{DEFAULT_TEMPLATE}' template"
    )


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
    listed: bool

    def __init__(self, section: str, logical: str, raw: object, volume: str) -> None:
        self.section = section
        self.logical = logical
        self.volume = volume
        if isinstance(raw, str):
            self.file = raw
            self.do_print = True
            self.optional = False
            self.listed = True
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
        listed = raw.get("toc", True)
        if not isinstance(listed, bool):
            die(f"volume '{volume}': entry '{logical}' ({section}): 'toc' must be a boolean")
        self.listed = listed

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


def resolve_listed(entries: list[Entry], volume_dir: Path) -> list[tuple[str, bool]]:
    """The same resolution, keeping whether each entry belongs in the contents."""
    resolved: list[tuple[str, bool]] = []
    for entry in entries:
        path = entry.resolve(volume_dir)
        if path is not None:
            resolved.append((path, entry.listed))
    return resolved


def with_toc_guards(
    pairs: list[tuple[str, bool]],
    generated_dir: Path,
    volume_dir: Path,
    counter: list[int],
) -> list[str]:
    """Interleave the switches the template understands around unlisted entries.

    An entry declared ``toc: false`` is surrounded by two generated mode files,
    so its heading stays out of the contents without the tool reading or
    rewriting the Markdown. The template keeps the quoted chapter command out of
    the table of contents until the switch is turned back on.
    """
    files: list[str] = []
    for path, listed in pairs:
        if listed:
            files.append(path)
            continue
        off = generated_dir / f"{counter[0]:02d}-toc-off.md"
        counter[0] += 1
        write_mode_file(off, "\\BookChaptersUnlisted\n")
        on = generated_dir / f"{counter[0]:02d}-toc-on.md"
        counter[0] += 1
        write_mode_file(on, "\\BookChaptersListed\n")
        files.append(relpath(off, volume_dir))
        files.append(path)
        files.append(relpath(on, volume_dir))
    return files


_LATEX_SPECIALS = {
    "\\": r"\textbackslash{}",
    "{": r"\{",
    "}": r"\}",
    "%": r"\%",
    "#": r"\#",
    "&": r"\&",
    "_": r"\_",
    "$": r"\$",
    "~": r"\textasciitilde{}",
    "^": r"\textasciicircum{}",
}


def latex_escape(text: str) -> str:
    """A short label, safe to embed in the contents file."""
    return "".join(_LATEX_SPECIALS.get(char, char) for char in text)


def toc_separator_block(style: str, label: str | None, macro: str) -> str:
    """The LaTeX that separates one block of the contents.

    The block defines its own macro before using it, so a volume built with a
    custom book-class template compiles without that template declaring anything.
    """
    if style == "none":
        return ""
    if style == "space":
        body = r"\protect\vspace{1.2em}"
    elif style == "rule":
        body = (
            r"\protect\vspace{0.8em}\protect\noindent"
            r"\protect\rule{\protect\linewidth}{0.4pt}"
            r"\protect\par\protect\vspace{0.6em}"
        )
    else:
        body = (
            r"\protect\vspace{1em}\protect\noindent{\protect\bfseries "
            + latex_escape(label or "")
            + r"}\protect\par\protect\vspace{0.4em}"
        )
    return (
        f"\\providecommand{{\\{macro}}}{{\\addtocontents{{toc}}{{{body}}}}}"
        f"\n\\{macro}\n"
    )


def write_mode_file(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def merge_defaults(manifest: dict, defaults: dict) -> dict:
    """Series facts sit under the volume's own overrides."""
    # Every field a series may set once for all of its volumes. A field missing
    # from this tuple is silently ignored at series level, which is why the two
    # contents fields belong here: the examples declare them exactly there.
    shared = (
        "collection",
        "author",
        "publisher",
        "rights",
        "language",
        "toc_separators",
        "toc_labels",
    )
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
    template: str,
) -> Path:
    """Write the generated files and one skelepress.config.yaml; return the config path."""

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

    front = resolve_listed(
        ordered_entries("front_matter", merged.get("front_matter"), volume_name), volume_dir
    )
    chapters_raw = merged.get("chapters")
    if isinstance(chapters_raw, str):
        chapters_dir = merged.get("chapters_dir", "chapters")
        chapters = resolve_entries(ordered_chapters(chapters_dir, volume_name, volume_dir), volume_dir)
    else:
        chapters = resolve_entries(chapter_entries(chapters_raw, volume_name), volume_dir)
    back = resolve_listed(
        ordered_entries("back_matter", merged.get("back_matter"), volume_name), volume_dir
    )

    toc_separators = merged.get("toc_separators", DEFAULT_TOC_SEPARATORS)
    if toc_separators not in TOC_SEPARATORS:
        die(
            f"volume '{volume_name}': 'toc_separators' must be one of"
            f" {', '.join(TOC_SEPARATORS)} (got {toc_separators!r})"
        )
    toc_labels = merged.get("toc_labels") or {}
    if not isinstance(toc_labels, dict):
        die(f"volume '{volume_name}': 'toc_labels' must be a map of label names")
    if toc_separators == "label":
        needed = ["chapters"] + (["appendices"] if back else [])
        missing = [name for name in needed if not str(toc_labels.get(name, "")).strip()]
        if missing:
            die(
                f"volume '{volume_name}': 'toc_separators: label' needs a"
                f" 'toc_labels' entry for {', '.join(missing)}"
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
    mainmatter_text += toc_separator_block(
        toc_separators, toc_labels.get("chapters"), "BookTocSeparatorChapters"
    )
    write_mode_file(mainmatter_file, mainmatter_text)

    # 00 and 01 name the two structural switches; the contents guards start at
    # 10 so the numbering never collides as entries are added.
    guard_counter = [10]
    explicit_files = with_toc_guards(front, generated_dir, volume_dir, guard_counter)
    explicit_files.append(relpath(mainmatter_file, volume_dir))
    explicit_files += list(chapters)
    if back:
        appendix_file = generated_dir / "01-appendix.md"
        write_mode_file(
            appendix_file,
            "\\appendix\n"
            + toc_separator_block(
                toc_separators, toc_labels.get("appendices"), "BookTocSeparatorAppendices"
            ),
        )
        explicit_files.append(relpath(appendix_file, volume_dir))
        explicit_files += with_toc_guards(back, generated_dir, volume_dir, guard_counter)

    out_volume_dir.mkdir(parents=True, exist_ok=True)
    config_path = out_volume_dir / "skelepress.config.yaml"
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
    template: str,
) -> str:
    """One standard skelepress.config.yaml per volume, emitted as canonical text.

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
            # The book template receives \chapter for top-level headings through
            # the contract instead of a \let heading shift in the template.
            "  top_level_division: chapter",
            f"  template: {quoted(template if is_bare_name(template) else relpath(Path(template), volume_dir))}",
            "  resource_path:",
            # Assets a chapter references resolve from the volume root, which is
            # where the content folders and any media directory now live.
            '    - "."',
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
            " into standard skelepress.config.yaml files and render them through bin/skelepress."
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

    explicit_template: str | None = None
    if args.template:
        raw_template = args.template.strip()
        if is_bare_name(raw_template):
            # A name is a template the toolkit ships, so the validator and the
            # renderer resolve it and there is no path to check here.
            explicit_template = raw_template
        else:
            resolved_template = Path(raw_template).resolve()
            if not resolved_template.is_file():
                die(f"book template not found: {resolved_template}")
            explicit_template = str(resolved_template)

    projects: list[tuple[Path, str]] = []
    for raw in args.projects:
        # Resolve the project before anything computes a path against it. The
        # output directory is already resolved, and on a platform where the two
        # spellings differ -- macOS gives /var/folders and resolves it to
        # /private/var/folders -- a relative path built from one and applied to
        # the other points outside the tree. The generated configuration then
        # names files that do not exist, and the render fails with a path that
        # looks plausible.
        project = Path(raw).resolve()
        if not project.is_dir():
            die(f"not a directory: {project}")
        if not (project / "series.yaml").is_file() and not (project / "manifest.yaml").is_file():
            die(f"no series.yaml or manifest.yaml in: {project}")
        template = explicit_template if explicit_template else DEFAULT_TEMPLATE
        projects.append((project, template))

    # Contract validation first, for every project, before anything is built:
    # a manifest that fails validation never reaches the build.
    plans: list[tuple[Path, str, Path, dict, dict, bool, str]] = []
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
        die(f"skelepress CLI not found: {CLI}")

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
