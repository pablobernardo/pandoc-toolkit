# Migrating to 2.1.0

2.1.0 adds EPUB output and changes where relative assets are resolved. Published
2.0.1 configurations need no edits: `output.formats` is optional, omitting it
keeps the PDF behaviour, and configuration contract `version: 1` is unchanged.

## EPUB output

`output.formats: [epub]` produces an EPUB3 publication. It carries an existing
cover image declared through `cover-image` in the metadata file or in
`document.metadata`, embeds emoji and Mermaid resources, keeps cross-references
between chapters working as internal anchors, and drops LaTeX-only markup such
as the generated `\clearpage`. Nothing generates a cover, and PDF output is
unchanged.

## Relative assets resolve from the project base

`project.base_dir` is now appended last to the Pandoc resource path, so a
relative image or cover resolves regardless of the directory the command runs
from; a declared `pandoc.resource_path` keeps its priority, so anything that
resolved before still resolves. A project that relied on being invoked from a
particular directory should either run from the project base or declare that
entry explicitly.

## If you used the prototype format key

The singular `output.format` was a prototype on `main` and never shipped in a
release. If you used it, replace it. Before:

```yaml
output:
  format: epub
```

After (retain the other output fields):

```yaml
output:
  formats: [epub]
```

Use `formats: [pdf, epub]` to produce both in declared order, or omit the field
for the unchanged PDF default. An empty list, an unknown format, or the old
singular key fails validation before rendering. Duplicate formats run once.
Configuration contract `version: 1` is unchanged.

Multi-output is not transactional: preflight checks all requirements first;
after it passes, each format is attempted. A failed format causes exit 1,
successful files remain, and merged Markdown is retained for diagnosis.

## Integrations reading JSON plans

A single unique format retains the version-1 plan. A multi-format request
returns a version-2 envelope with ordered `jobs`, each a version-1 plan.
Check `plan_version` before reading the top-level `pandoc` object. No CLI
flags have changed. Existing PDF-only integrations keep their recorded plans.
