# Arquitectura Propuesta — Generador PDF Multi-Repo (Pandoc)

## 1) Problema a resolver

Hoy el pipeline de `.pandoc` funciona, pero está acoplado a convenciones locales (`chapters/`, `output/`, rutas fijas en filtros Lua). Eso complica reutilizarlo en otros repos y escalar mantenimiento.

Objetivo: movernos a un **toolkit global versionado** con configuración declarativa por repo, sin perder compatibilidad con el flujo actual.

---

## 2) Contrato de configuración (por repositorio)

Archivo recomendado en cada repo consumidor: `pdf.config.yaml`

```yaml
version: 1

project:
  name: sample-project
  base_dir: .

document:
  title: "Project Technical Documentation"
  subtitle: "Compliance and Operations"
  publisher: "ACME Corp"
  author: "Engineering Team"
  date: "2026-04-21"
  rights: "Internal Use"

input:
  chapters_dir: "docs"
  glob: "*.md"
  order: natural
  explicit_files: []

output:
  dir: "build/pdf"
  file_prefix: "report"
  suffix: "${date:YYYYMMDD}"
  keep_merged_markdown: true

pandoc:
  pdf_engine: xelatex
  toc: true
  toc_depth: 2
  number_sections: true
  template: "templates/default.tex"
  metadata_file: ""
  resource_path:
    - "docs"
    - "docs/media"
    - "build/pdf/emoji"

filters:
  emoji:
    enabled: true
    emoji_dir: "build/pdf/emoji"
    include_ballot_icons: true
  mermaid:
    enabled: true
    output_dir: "build/pdf/mermaid"
    background: transparent
  extra_lua_filters: []

runtime:
  required_commands:
    - pandoc
    - python3
    - curl
    - mmdc
  strict: true

compat:
  legacy_clearpage_between_h1: true
```

### Reglas del contrato

1. **`version` obligatorio** para evolución sin romper repos viejos.
2. Paths se resuelven contra `project.base_dir`.
3. Si `explicit_files` no está vacío, tiene prioridad sobre `glob`.
4. Si `metadata_file` está vacío, usar metadatos de `document`.
5. Filtros pueden deshabilitarse por documento.

### Convención de ejemplos en este toolkit

- Usar nombres neutrales (`sample-project`, `ACME Corp`).
- Evitar rutas o nomenclatura específicas de un cliente/repositorio.
- Mantener ejemplos reproducibles en cualquier estructura estándar.

---

## 3) Estructura propuesta del toolkit global

```text
pandoc-toolkit/
  bin/
    pandoc-pdf               # CLI principal
  templates/
    default.tex
    iso-light.tex
  filters/
    emoji.lua
    mermaid.lua
  scripts/
    prepare-emojis.py
    preflight.sh
  schemas/
    pdf-config.schema.json
  examples/
    pdf.config.example.yaml
  docs/
    migration.md
    usage.md
```

### Principios

- **Core estable + config por repo**.
- **Versionado semántico** del toolkit (`v0.x`, `v1.x`).
- **Sin hardcode de rutas** dentro de filtros.
- **Preflight explícito** de dependencias antes de renderizar.

---

## 4) Compatibilidad con este repo (plan de migración)

### Fase 1 — Endurecer local

1. Parametrizar rutas en `emoji.lua` y `mermaid.lua` (leer desde metadata/vars Pandoc).
2. Consolidar preparación de emojis en `prepare-emojis.py` y eliminar duplicados legacy.
3. Completar preflight (`pandoc`, engine TeX, `python3`, `curl`, `mmdc`).

### Fase 2 — Extraer toolkit

1. Mover scripts/filtros/template al repo `pandoc-toolkit`.
2. Publicar versión `v0.1.0`.
3. En cada repo consumidor, dejar wrapper mínimo que invoque toolkit con `pdf.config.yaml`.

### Fase 3 — Escalar a otros repos

1. Reusar toolkit por tag/version.
2. Personalizar solo `pdf.config.yaml` + template opcional.
3. Mantener changelog de breaking changes por `version` de config.

---

## 5) Tradeoffs (decisión recomendada)

### Opción A — Toolkit global (RECOMENDADA)
- ✅ Mejor mantenibilidad y escalabilidad
- ✅ Upgrade controlado por versión
- ⚠️ Requiere diseñar contrato de config al inicio

### Opción B — Git submodule de `.pandoc`
- ✅ Implementación rápida
- ⚠️ Fricción operativa en equipos
- ⚠️ Menor flexibilidad para overrides finos

### Opción C — Copia por repo
- ✅ Costo inicial bajo
- ❌ Deriva técnica garantizada
- ❌ Alto costo de mantenimiento futuro

---

## 6) Criterios de listo para producción

- [ ] Un solo entrypoint (`pandoc-pdf`).
- [ ] Config validada contra schema.
- [ ] Rutas 100% declarativas (sin hardcode).
- [ ] Compatibilidad probada en al menos 2 repos con estructuras distintas.
- [ ] Documentación de migración y fallback legacy.
