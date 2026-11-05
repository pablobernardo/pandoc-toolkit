# Rename the project to skelepress (3.0.0)
Branch: `feat/skelepress-3.0.0`; delivery: one major release. The plan and its decisions live in #164; this document is the execution spec.
Scope: the name only. No behaviour, no schema shape, no pipeline change. Clean break: no shim, no aliases, no dual config loading.

## Specs

- S1: The command is `skelepress`. The repository, the workflow titles, the skill, the release assets and the managed layout use the same name. #164, verbatim: "le llamamos skelepress".
- S2: The configuration file is `skelepress.config.yaml`, and the schema is `schemas/skelepress-config.schema.json`. `pdf.config.yaml` is **not** accepted: there is one consumer, the maintainer, who deletes the old files by hand.
- S3: The environment variables are `SKELEPRESS_*`. All 17 `PANDOC_PDF_*` names are renamed, and nothing reads both.
- S4: No compatibility path exists: no `pandoc-pdf` shim, no variable aliases, no fallback filename. The 3.0.0 changelog states the break and the absence of a migration path — #164, verbatim: "lo de la guia de migración da un poco igual porque solo lo estoy usando yo".
- S5: `AGENTS.md` is amended so the breaking-change policy requires a migration guide **when the change reaches a consumer other than the maintainer**. Until it is amended, the policy contradicts the release.
- S6: Nothing else changes: same commands, same flags, same messages (except the name inside them), same schema shape, same output bytes for a given input, same `VERSION` scheme and tag convention.
- S7: The rename is verified mechanically, not by eye: after the change, `git grep -i 'pandoc-pdf\|PANDOC_PDF'` returns nothing outside the changelog history and the notes that record the old name, and `make gate` is green.

## The mapping

| Before | After |
| --- | --- |
| `bin/pandoc-pdf` | `bin/skelepress` |
| `pandoc-pdf` (command, every mention) | `skelepress` |
| `pandoc-pdf-dev` | `skelepress-dev` |
| `PANDOC_PDF_*` (17 variables) | `SKELEPRESS_*` |
| `pdf.config.yaml` | `skelepress.config.yaml` |
| `schemas/pdf-config.schema.json` | `schemas/skelepress-config.schema.json` |
| `~/.local/share/pandoc-pdf` | `~/.local/share/skelepress` |
| `pandoc-pdf_<os>_<arch>.tar.gz` | `skelepress_<os>_<arch>.tar.gz` |
| `pandoc-toolkit` (repository, docs, URLs) | `skelepress` |
| skill `pandoc-pdf-documentation` | `skelepress-documentation` |

`VERSION`, the tag convention, the commands, their flags and the contract `version` field keep their current form.

## Risks that this release must answer

- **The published releases keep their asset names.** `v2.5.2` and every earlier tag publish `pandoc-pdf_*`. The new release workflow must not assume its own name when reading the *previous* release: `pandoc-pdf update` (future `skelepress update`) resolves the artifact name from the platform, so a 3.0.0 binary looking for `skelepress_*` is right, but any code that inspects history must tolerate both.
- **An existing installation at the old managed root** `~/.local/share/pandoc-pdf` stays there. The maintainer removes it by hand; nothing detects or migrates it, and nothing may silently write to the new root while the old binary is still on `PATH`.
- **The repository rename on GitHub** keeps a redirect, so old clones keep working, but every `https://github.com/pablobernardo/pandoc-toolkit/...` URL in the docs must be rewritten in the same change.
- **The suite is the safety net.** 570 tests reference the command; if the rename is applied inconsistently, the gate fails loudly. Do not silence failures by relaxing assertions.

## Tasks

- T1 [S5] pending; route: parent; amend `AGENTS.md`.
- T2 [S1, S2, S3, S6] pending; route: parent; mechanical rename in one pass, file renames with `git mv`, then the mapping applied by a reviewed script rather than by hand.
- T3 [S7] pending; route: parent; `git grep` zero-leftover check, `make gate` green, and a `--version` smoke test.
- T4 [S1, S6] pending; route: parent; GitHub repository rename, workflow names, skill directory, and the docs URLs.
- T5 [S4] pending; route: parent delivery; metadata PR, changelog entry that states the break, squash merge.
- T6 [S4] pending; route: parent, after the maintainer's decision; annotated tag `v3.0.0` and one release.
- T7 [S4] pending; route: parent acceptance; published assets, clean install, and the update from 2.5.2 (which will exercise the old-name artifact resolution against the new release).

## Log

- L1 — Maintainer, verbatim: "me gusta skelepress ponlo como issue que el otro que me dijiste ya existe en github".
- L2 — Decisions confirmed in #164: name `skelepress`, config `skelepress.config.yaml`, clean break, policy amended, order `2.5.2 → 3.0.0 → features`.
- L3 — Not started. This document exists so the rename is executed from a written mapping rather than from memory, which is where the three data errors of this cycle came from.
