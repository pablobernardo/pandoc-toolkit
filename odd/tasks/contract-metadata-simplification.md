# Contract: metadata without a mandatory metadata file

The configuration requires `pandoc.metadata_file`, which makes five of the six
`document` fields inert in every valid config, and forces a legacy YAML file that
the toolkit's own template does not need. This change makes the modern path work,
keeps the legacy one, and lets arbitrary Pandoc metadata live in the config.

## Specs

- **S1** — `pandoc.metadata_file` stops being required. When present it wins and
  nothing else is passed, exactly as today (D5). When absent, `document.*` are
  passed as template variables, which is the behaviour the renderer already
  implements and the schema currently forbids.
- **S2** — `output.file_prefix` stops being required: it is a fallback for the
  file name, not the name, and requiring it misleads.
- **S3** — The file name keeps coming from `document.title`. Changing it to
  `file_prefix` would rename every consumer's PDF, so it is explicitly out of
  scope for this change.
- **S4** — `document.language` selects the babel language: `en`, `es`, `pt`, `gl`,
  defaulting to the value the template hardcodes today so no existing output
  changes. It is what makes `language` in a `metadata.yaml` meaningful; with the
  toolkit template it is currently inert.
- **S5** — `document.titlepage` is a real switch, default `true`. Today the cover
  is unconditional and the `titlepage` key of a metadata file does nothing.
- **S6** — `document.metadata` is a free-form map of scalar keys that the renderer
  passes to Pandoc, so `keywords`, `subject` or any template variable no longer
  need a side file. `metadata_file`, when present, still wins over it.

## Tasks

- **T1** — Schema and validator: `metadata_file` and `file_prefix` optional,
  `language` (enum), `titlepage` (boolean), `metadata` (map of scalars). The
  validator currently understands `additionalProperties` only as a boolean, so it
  must also accept a schema for the extra values, with a guard test.
- **T2** — Renderer and template: language mapped to a babel name, `titlepage`
  emitted only when enabled, `document.metadata` passed through, and the template
  using both variables instead of hardcoding Spanish and an unconditional cover.
  The recorded conformance plans change with the contract, so they are refreshed
  in this task.
- **T3** — Documentation, examples and CHANGELOG: the contract version, the
  reference config, and the examples dropping `metadata.yaml`.

## Log

- **L1** (user, verbatim): "revisa si ves alguna incongruencia entre los ejemplos
  que subí, pregunta antes de hacer cambios"
- **L2** (user, verbatim): "el metadata.yml es de donde se sacan los textos
  practicamente solo para la portada por eso no coincide y en el pdf.config.yml
  ese nombre que sale es el que se le pone al archivo, revisa lo que estamos
  haciendo por si podemos simplificar y no romper nada, al final metadata se
  identifica como metadatos del archivo que viene heredado de una implementación
  legacy"
- **L3** (user, verbatim): "miramos de integrar entonces el contenido de
  metadata.yaml en el pdf.config.yaml? propones eso? no nos falta ninguna
  variable para que no se necesite el metadata.yaml?"
- **L4** (decision): scope is S1, S4, S5 and S6 plus the free-form map; S3 is
  deferred because it renames every consumer's output.
