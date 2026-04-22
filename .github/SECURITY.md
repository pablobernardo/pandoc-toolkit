# Política de seguridad

## Versiones soportadas

Mientras el proyecto no tenga releases públicas estables, se da soporte de seguridad a la rama principal (`main`/`master`) y al estado más reciente del código.

## Cómo reportar vulnerabilidades

Si detectas una vulnerabilidad:

1. **No** abras una issue pública con detalles explotables.
2. Contacta con el mantenedor:
   - Pablo Bernardo — https://github.com/pablobernardo
3. Incluye en el reporte:
   - descripción del impacto,
   - pasos de reproducción,
   - versión/commit afectado,
   - posible mitigación si la conoces.

Se intentará confirmar el problema y responder con un plan de mitigación lo antes posible.

## Modelo de confianza

Este toolkit asume que el archivo `pdf.config.yaml` es de confianza del repositorio consumidor.

Recomendaciones:

- No ejecutes `pandoc-pdf render` ni `pandoc-pdf doctor -c` con configuraciones no confiables.
- Revisa especialmente `filters.extra_lua_filters` y `runtime.required_commands`.
- En CI, limita la ejecución a configuraciones versionadas y revisadas.

## Hardening aplicado

- Validación estricta por esquema (`schemas/pdf-config.schema.json`).
- Validación funcional de rutas críticas en `validate-config`.
- Validación de nombre seguro para `runtime.required_commands` en preflight.
- Carga YAML segura en rutas Ruby (`YAML.safe_load`).

## Buenas prácticas para contribuidores

- Evitar invocaciones shell con interpolación de entradas no confiables.
- Preferir APIs sin shell (`subprocess.run([...])`, `shutil.which`, etc.).
- Añadir tests de regresión de seguridad cuando se corrija una vulnerabilidad.
