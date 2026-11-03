#!/usr/bin/env python3
"""build.py - the book-kit adapter.

One adapter for both book shapes:

* A **single volume**: a project directory with a ``manifest.yaml`` and no
  ``series.yaml``. The project directory is itself the volume.
* A **series**: a project directory with a ``series.yaml`` that holds the
  shared facts (collection, author, publisher, rights, language) and an
  ordered ``volumes`` list of volume directory names, each with its own
  ``manifest.yaml``.

For every volume the adapter:

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
5. renders it through the public CLI (``bin/pandoc-pdf render``).

The adapter belongs to the book, not to the toolkit: the toolkit only ever
sees a standard ``pdf.config.yaml``. It runs from any working directory,
uses no absolute paths and no network, and reads YAML with PyYAML when
available, falling back to Ruby's stdlib YAML through a subprocess (the
same fallback the toolkit itself uses); without either parser it fails
with a clear message.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path
from typing import NoReturn

try:
    import yaml as pyyaml  # type: ignore
except Exception:  # PyYAML is optional: Ruby's stdlib YAML is the fallback.
    pyyaml = None

SCRIPT_DIR = Path(__file__).resolve().parent
TOOLKIT_ROOT = SCRIPT_DIR.parents[1]
CLI = TOOLKIT_ROOT / "bin" / "pandoc-pdf"
# The example may point at its sibling example's template. A real consumer
# copies the template into its own repository and points at its own copy.
BOOK_TEMPLATE = TOOLKIT_ROOT / "examples" / "book" / "templates" / "book.tex"
DEFAULT_OUT = SCRIPT_DIR.parent / ".output" / "book-kit"

LANG_CODES = ("en", "es", "pt", "gl")


def die(message: str) -> NoReturn:
    print(f"build.py: error: {message}", file=sys.stderr)
    raise SystemExit(1)


def warn(message: str) -> None:
    print(f"build.py: warning: {message}", file=sys.stderr)


# --- YAML reading -----------------------------------------------------------


# Mirrors the toolkit's own fallback (scripts/render-native.py): parse with
# Ruby's stdlib YAML under safe_load and hand back plain data as JSON.
RUBY_YAML_SCRIPT = (
    "begin;"
    "data = YAML.safe_load(File.read(ARGV[0]), permitted_classes: [], aliases: false);"
    "puts JSON.generate(data);"
    "rescue => e;"
    "STDERR.puts e.message;"
    "exit 2;"
    "end"
)


def load_yaml_file(path: Path) -> dict:
    """Read a YAML file into a plain dict, via PyYAML or the Ruby fallback."""

    data: object = None
    if pyyaml is not None:
        try:
            data = pyyaml.safe_load(path.read_text(encoding="utf-8"))
        except Exception as error:
            die(f"could not parse YAML: {path}: {error}")
    else:
        ruby_bin = shutil.which("ruby")
        if ruby_bin is None:
            die(
                "no YAML parser available: install PyYAML"
                " (python3 -m pip install pyyaml) or a Ruby with stdlib YAML"
            )
        proc = subprocess.run(
            [ruby_bin, "-ryaml", "-rjson", "-e", RUBY_YAML_SCRIPT, str(path)],
            capture_output=True,
            text=True,
        )
        if proc.returncode == 2:
            die(f"could not parse YAML: {path}: {proc.stderr.strip() or 'invalid YAML'}")
        if proc.returncode != 0:
            die(f"could not read YAML: {path}: {proc.stderr.strip() or 'ruby failed'}")
        try:
            data = json.loads(proc.stdout)
        except Exception as error:
            die(f"could not read YAML: {path}: {error}")

    if data is None:
        return {}
    if not isinstance(data, dict):
        die(f"root of {path} must be a mapping")
    return data


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


# --- Manifest model ---------------------------------------------------------


class Entry:
    """One declared content entry: a path string or a map with file/print/optional."""

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


def chapter_entries(raw: object, volume: str) -> list[Entry]:
    """chapters: an ordered list of entries, or a mapping with ordered: true."""
    if isinstance(raw, dict):
        if not raw.get("ordered"):
            die(f"volume '{volume}': 'chapters' mapping must set 'ordered: true'")
        raw = raw.get("files")
    if not isinstance(raw, list) or not raw:
        die(f"volume '{volume}': 'chapters' must be a non-empty ordered list")
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
    volume_name: str,
    volume_dir: Path,
    defaults: dict,
    out_volume_dir: Path,
) -> Path:
    """Write the generated files and one pdf.config.yaml; return the config path."""

    manifest = merge_defaults(load_yaml_file(volume_dir / "manifest.yaml"), defaults)

    title_value = manifest.get("title")
    if not isinstance(title_value, str) or not title_value.strip():
        die(f"volume '{volume_name}': manifest must declare a non-empty 'title'")
    title: str = title_value

    chapter_start = manifest.get("chapter_start")
    if chapter_start is not None and (
        not isinstance(chapter_start, int)
        or isinstance(chapter_start, bool)
        or chapter_start < 1
    ):
        die(f"volume '{volume_name}': 'chapter_start' must be an integer of 1 or more")

    language = manifest.get("language")
    if language is not None and language not in LANG_CODES:
        die(
            f"volume '{volume_name}': 'language' must be one of"
            f" {', '.join(LANG_CODES)} (got {language!r})"
        )

    front = resolve_entries(
        ordered_entries("front_matter", manifest.get("front_matter"), volume_name), volume_dir
    )
    chapters = resolve_entries(chapter_entries(manifest.get("chapters"), volume_name), volume_dir)
    back = resolve_entries(
        ordered_entries("back_matter", manifest.get("back_matter"), volume_name), volume_dir
    )

    # Generated mode files live in the run output, never inside the content
    # directories. explicit_files resolves against the volume directory
    # (input.chapters_dir is "."), so the adapter computes the relative hops.
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
        emit_config(manifest, title, volume_dir, out_volume_dir, explicit_files),
        encoding="utf-8",
    )
    return config_path


def emit_config(
    manifest: dict,
    title: str,
    volume_dir: Path,
    out_volume_dir: Path,
    explicit_files: list[str],
) -> str:
    """One standard pdf.config.yaml per volume, emitted as canonical text.

    The text is written by hand instead of a YAML dumper so the result is
    byte-identical whichever parser read the manifests.
    """
    slug = slugify(title)
    lines = [
        "# Generated by examples/book-kit/build.py. Do not edit:",
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
        for key in ("collection", "isbn")
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
            f"  template: {quoted(relpath(BOOK_TEMPLATE, volume_dir))}",
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


# --- Shape discovery --------------------------------------------------------


def discover_projects() -> list[Path]:
    """Project directories: they hold a series.yaml (series) or a manifest.yaml."""
    projects = []
    for child in sorted(SCRIPT_DIR.iterdir()):
        if not child.is_dir() or child.name.startswith("."):
            continue
        if (child / "series.yaml").is_file() or (child / "manifest.yaml").is_file():
            projects.append(child)
    return projects


def project_volumes(project_dir: Path) -> list[tuple[str, Path, dict]]:
    """The volumes of one project as (name, directory, series defaults) triples."""
    series_path = project_dir / "series.yaml"
    if not series_path.is_file():
        return [(project_dir.name, project_dir, {})]

    series = load_yaml_file(series_path)
    volume_names = series.get("volumes")
    if not isinstance(volume_names, list) or not volume_names:
        die(f"series.yaml of {project_dir.name} must list at least one volume")
    volumes: list[tuple[str, Path, dict]] = []
    for volume_name in volume_names:
        if not isinstance(volume_name, str) or not volume_name.strip():
            die(
                f"series.yaml of {project_dir.name}: every entry in 'volumes'"
                " must be a directory name"
            )
        volume_dir = project_dir / volume_name
        if not (volume_dir / "manifest.yaml").is_file():
            die(f"series '{project_dir.name}': volume '{volume_name}' has no manifest.yaml")
        volumes.append((volume_name, volume_dir, series))
    return volumes


# --- Main -------------------------------------------------------------------


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Render the book-kit examples through bin/pandoc-pdf."
    )
    parser.add_argument("projects", nargs="*", help="project names to build (default: every project)")
    parser.add_argument("--out", default=str(DEFAULT_OUT), help="run output directory")
    args = parser.parse_args()

    if not CLI.is_file():
        die(f"pandoc-pdf CLI not found: {CLI}")
    if not BOOK_TEMPLATE.is_file():
        die(f"book template not found: {BOOK_TEMPLATE}")

    projects = discover_projects()
    if args.projects:
        wanted = set(args.projects)
        projects = [project for project in projects if project.name in wanted]
        missing = wanted - {project.name for project in projects}
        if missing:
            die(f"no such project(s): {', '.join(sorted(missing))}")
    if not projects:
        die(f"no book projects found next to {SCRIPT_DIR}")

    out_root = Path(args.out).resolve()
    failures: list[str] = []
    for project in projects:
        is_series = (project / "series.yaml").is_file()
        for volume_name, volume_dir, defaults in project_volumes(project):
            # A series nests one output directory per volume; a single-volume
            # project is its own volume and does not repeat its name.
            out_volume_dir = (
                out_root / project.name / volume_name if is_series else out_root / project.name
            )
            print(f"==> {project.name}/{volume_name}")
            config_path = build_volume(volume_name, volume_dir, defaults, out_volume_dir)
            print(f"    config: {relpath(config_path, Path.cwd())}")

            result = subprocess.run([str(CLI), "render", "-c", str(config_path)])
            pdfs = sorted(out_volume_dir.glob("*.pdf"))
            if result.returncode == 0 and pdfs:
                for pdf in pdfs:
                    print(f"    [ok] {relpath(pdf, Path.cwd())}")
            else:
                failures.append(f"{project.name}/{volume_name}")
                print(f"    [FAIL] {project.name}/{volume_name} (exit {result.returncode})")

    if failures:
        die(f"render failed for: {', '.join(failures)}")
    print(f"Done: {len(projects)} project(s) rendered into {relpath(out_root, Path.cwd())}")


if __name__ == "__main__":
    main()
