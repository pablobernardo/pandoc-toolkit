# Build the release payload from tracked content
Branch: `fix/payload-from-tracked`; delivery: one code PR closing #110.
Scope: `scripts/delivery/` and the release-area test. The published layout, the four platform names and the local installer's source do not change.

## Specs

- S1: The packager builds its staging tree from the content of a commit, not from the working copy. Maintainer, verbatim: "Hazlo empaquetar desde archivos versionados (git ls-files o git archive)".
- S2: "pruébalo con un archivo sin versionar dentro del payload: no debe viajar."
- S3: #110 acceptance: "Archive contents are identical whether the tree is dirty or clean." An uncommitted edit to a tracked payload file must not reach the artifact.
- S4: #110 acceptance: "Published artifact layout and the four platform names are unchanged", and the existing payload assertions keep passing (runtime, bookkit tool, `bin/pandoc-pdf`, no `scripts/dev` or `scripts/delivery`, no bytecode).
- S5: The local installer keeps building from the working tree, because exercising uncommitted work is its purpose. Only the packager is commit-bound.
- S6: A tree that is not a Git work tree is refused with an explanation rather than silently packaging the working copy, because a silent difference between two builders is the defect being fixed.

## Tasks

- T1 [S1–S6] done; route: parent inline; `populate_payload` takes a source mode (`worktree` default, `tracked` from `HEAD`), the packager asks for `tracked` and `install-local.sh` keeps the working tree; one test registered in `tests/run.sh`, RED 3 FAIL → GREEN 16 PASS across the three release tests and 10 PASS across the two install tests; gate 553/0 with 176 i18n keys, 73 documentation files and 4 conforming cases. The artifact rebuilt from the commit still hashes to `40efd2445adf96cb0734096ccfbc4447b9b2ed2b12419c7382b6797a17cd6c35`, the published one. Commit: `248e4dd`.

## Log

- L1 — Maintainer, verbatim: "#110 como unidad de código: package-release.sh construye desde el árbol de trabajo (scripts/delivery/payload.sh hace cp -R), no desde el commit. Hazlo empaquetar desde archivos versionados (git ls-files o git archive) y pruébalo con un archivo sin versionar dentro del payload: no debe viajar. Es el defecto que obliga a clonar limpio en cada aceptación."
- L2 — `git archive` was chosen over `git ls-files` because the issue's second acceptance criterion is that a dirty tree and a clean tree produce the same archive: enumerating tracked paths and copying them would still ship an uncommitted edit, while archiving `HEAD` cannot. `mapfile` was avoided on purpose: the L1 job runs on `macos-15`, whose bash is 3.2.
- L3 — `install-local.sh` keeps the working tree deliberately (S5). Pointing it at `HEAD` would make a development install test the last commit instead of the work in progress, which is the only reason that mode exists.
- L4 — The clean build of the current commit reproduces `40efd2445adf96cb0734096ccfbc4447b9b2ed2b12419c7382b6797a17cd6c35`, the published 2.5.0 artifact, so the tracked payload is byte-identical to what shipped and the layout did not change.
