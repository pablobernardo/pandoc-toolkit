# Instalación — Pandoc PDF Toolkit

Esta guía deja el comando `pandoc-pdf` disponible para humanos, CI y agentes (OpenCode).

## 0) Instalación rápida (recomendada)

Desde la raíz del repositorio:

```bash
make bootstrap
```

Este comando ejecuta `scripts/bootstrap.sh`, que:

- detecta el sistema operativo,
- detecta gestor de paquetes Linux compatible (`apt-get`, `dnf`, `yum`, `pacman`, `zypper`, `apk`),
- instala dependencias comunes (macOS/Linux, cuando es posible),
- garantiza parser YAML disponible (PyYAML o Ruby YAML),
- crea el symlink de `pandoc-pdf` en `~/.local/bin`,
- ejecuta `doctor` para verificar el entorno.

Nota: las versiones críticas de dependencias se gestionan en `docs/dependency-policy.md`.

Opciones útiles:

```bash
make bootstrap-dry                       # muestra acciones sin ejecutar
make bootstrap-yes                       # modo no interactivo
make bootstrap-ci                        # modo CI (--yes --skip-link)
bash scripts/bootstrap.sh --no-install   # solo verifica dependencias + symlink
bash scripts/bootstrap.sh --yes          # equivalente no interactivo
bash scripts/bootstrap.sh --ci           # equivalente CI
```

## 1) Dependencias del sistema

Instala al menos:

- `pandoc`
- una engine TeX (`xelatex` o `lualatex` o `pdflatex`)
- `python3`
- parser YAML: **PyYAML** para Python o **Ruby YAML stdlib**
- `curl`
- `mmdc` (Mermaid CLI)

Referencia rápida para Mermaid CLI:

```bash
npm i -g @mermaid-js/mermaid-cli
```

Opción A (recomendada) — instalar PyYAML:

```bash
python3 -m pip install pyyaml
```

Opción B — usar Ruby con YAML stdlib (viene por defecto en macOS).

## 2) Instalar el CLI en PATH

Desde la raíz de este repo:

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/bin/pandoc-pdf" "$HOME/.local/bin/pandoc-pdf"
```

Agregar PATH (si no está):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Persistencia (zsh):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
```

## 3) Verificar instalación

```bash
pandoc-pdf doctor
```

Si devuelve `Doctor OK`, el entorno está listo.

## 4) Probar con config de ejemplo

```bash
pandoc-pdf validate-config -c examples/pdf.config.example.yaml
```

## 5) Integración con OpenCode (modelos)

Para que los modelos usen el comando correctamente:

1. Asegura que `pandoc-pdf` esté en PATH del entorno donde corre OpenCode.
2. Indica en instrucciones del proyecto que el flujo oficial es:
   - `pandoc-pdf doctor`
   - `pandoc-pdf validate-config -c <config>`
   - `pandoc-pdf render -c <config>`
3. Evita la invocación directa de scripts legacy locales desde prompts.

## Nota de estado actual

El render del CLI es **nativo por defecto** y el entrypoint oficial para automatización es `pandoc-pdf`.
