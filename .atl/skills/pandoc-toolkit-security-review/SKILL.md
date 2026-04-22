---
name: pandoc-toolkit-security-review
description: >
  Skill para revisar riesgos de seguridad en cambios del toolkit pandoc-pdf,
  centrada en entradas de configuración, ejecución de procesos y cadena de suministro.
  Trigger: cuando se modifiquen scripts CLI/render/preflight/bootstrap, CI o contrato de configuración.
license: Apache-2.0
metadata:
  author: pablobernardo
  version: "1.0"
---

## Cuándo usar

- Cambios en `scripts/preflight.py`, `scripts/validate-config.py`, `scripts/render-native.*`.
- Cambios en `scripts/bootstrap.sh` o `.github/workflows/ci.yml`.
- Cambios en campos de config que pueden ejecutar procesos (`runtime.required_commands`, `filters.extra_lua_filters`).

## Patrones críticos

1. **Evitar shell con interpolación de config**
   - No usar `bash -c` con valores de `pdf.config.yaml`.
   - Preferir `shutil.which`, `subprocess.run([...])` y validación de formato.

2. **Carga YAML segura**
   - En Ruby, usar `YAML.safe_load`.
   - En Python, `yaml.safe_load`.

3. **Validación explícita de entradas ejecutables**
   - `runtime.required_commands`: patrón seguro de nombre.
   - `extra_lua_filters`: rutas controladas y validadas.

4. **Supply chain controlada**
   - Revisar paquetes instalados en bootstrap/CI.
   - Documentar versiones y política de actualización.

5. **Regresión obligatoria**
   - Cada fix de seguridad debe incluir test de regresión.

## Checklist de revisión

- [ ] No hay `bash -c` con input de configuración sin sanitizar.
- [ ] No hay `YAML.load_file` en rutas de entrada no confiables.
- [ ] Se validan rutas/comandos antes de ejecutar.
- [ ] Se añaden tests que fallen si reaparece el bug.
- [ ] Se actualiza `SECURITY.md` si cambia el modelo de riesgo.

## Comandos

```bash
tests/run.sh
pandoc-pdf doctor -c tests/fixtures/doctor-config-required-cmd.yaml
pandoc-pdf validate-config -c tests/fixtures/valid.config.yaml
```

## Recursos

- Política de seguridad: `../../../.github/SECURITY.md`
- Registro de skills: `../../skill-registry.md`
- Guía de uso: `../../../docs/usage.md`
