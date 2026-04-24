# Instalación — Pandoc PDF Toolkit

Esta guía deja el comando `pandoc-pdf` disponible para humanos, CI y agentes (OpenCode).

## 0) Instalación rápida desde release (recomendada para usuarios finales)

Sin clonar repositorio:

```bash
curl -fsSL https://raw.githubusercontent.com/pablobernardo/pandoc-toolkit/main/scripts/install.sh | bash
```

Esto instala en layout gestionado:

- `~/.local/share/pandoc-pdf/versions/<tag>`
- `~/.local/share/pandoc-pdf/current`
- `~/.local/bin/pandoc-pdf`

Si el repositorio de releases es privado, exporta token antes de instalar:

```bash
export PANDOC_PDF_UPDATE_TOKEN=<tu_token>
# o GH_TOKEN
```

## 1) Instalación de desarrollo (desde repo)

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

## 2) Instalar desde repo local al layout gestionado

Clonado el repo, querés instalarlo en el mismo layout que usa `install-release` (para que `update` funcione correctamente) y además tener la opción de crear el symlink de desarrollo:

```bash
make install-local          # instala al layout gestionado (versions/<tag> + current + bin)
make install-local-dev      # instala al layout gestionado + symlink pandoc-pdf-dev -> bin/pandoc-pdf del repo
```

Esto copia el contenido del repo a `~/.local/share/pandoc-pdf/versions/<VERSION>` y crea los symlinks correspondientes. Usando `install-local-dev`, además queda disponible `pandoc-pdf-dev` que apunta al entrypoint de desarrollo `bin/pandoc-pdf` del repo.

## 3) Dependencias del sistema

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

## 4) Instalar el CLI en PATH (desarrollo)

> **Para usuarios finales:** usar `make install-local` (sección 2) en lugar de esta sección.

Esta sección describe la instalación para **desarrollo local** (desde el repo clonado):

```bash
mkdir -p "$HOME/.local/bin"
ln -sf "$(pwd)/bin/pandoc-pdf" "$HOME/.local/bin/pandoc-pdf"
```

Para desarrollo activo, crear también el symlink de desarrollo que evita colisiones con la instalación estable:

```bash
ln -sfn "$(pwd)/bin/pandoc-pdf" ~/.local/bin/pandoc-pdf-dev
```

Agregar PATH (si no está):

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Persistencia (zsh):

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
```

## 5) Verificar instalación

```bash
pandoc-pdf doctor
```

Si devuelve `Doctor OK`, el entorno está listo.

## 6) Probar con config de ejemplo

```bash
pandoc-pdf validate-config -c examples/pdf.config.example.yaml
```

## 7) Integración con OpenCode (modelos)

Para que los modelos usen el comando correctamente:

1. Asegura que `pandoc-pdf` esté en PATH del entorno donde corre OpenCode.
2. Indica en instrucciones del proyecto que el flujo oficial es:
   - `pandoc-pdf doctor`
   - `pandoc-pdf validate-config -c <config>`
   - `pandoc-pdf render -c <config>`
3. Evita la invocación directa de scripts legacy locales desde prompts.

## Nota de estado actual

El render del CLI es **nativo por defecto** y el entrypoint oficial para automatización es `pandoc-pdf`.
