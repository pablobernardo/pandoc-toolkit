# Unreleased EPUB configuration migration

Published 2.0.1 configurations need no changes. EPUB has not been released yet;
this migration concerns only configurations used with development `main`.
Toolkit VERSION stays 2.0.1 until release preparation is explicitly authorized.

## Replace the prototype format key

Before:

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
