# Security policy

## Supported versions

Security fixes are developed on `main` and published in a new release for users
of the latest stable release. Older releases are not maintained separately;
upgrade to the latest stable release to receive fixes.

## How to report a vulnerability

If you find a vulnerability:

1. **Do not** open a public issue with exploitable details.
2. Contact the maintainer:
   - Pablo Bernardo — https://github.com/pablobernardo
3. Include in the report:
   - a description of the impact,
   - reproduction steps,
   - the affected version or commit,
   - a possible mitigation if you know one.

The problem will be confirmed and answered with a mitigation plan as soon as
possible.

## Trust model

This toolkit assumes `pdf.config.yaml` is trusted by the consuming repository.

Recommendations:

- Do not run `pandoc-pdf render` or `pandoc-pdf doctor -c` with untrusted
  configurations.
- Review `filters.extra_lua_filters` and `runtime.required_commands` in
  particular.
- In CI, restrict execution to versioned and reviewed configurations.

## Hardening in place

- Strict schema validation (`schemas/pdf-config.schema.json`), including `enum`
  values, with a test that fails if the schema starts using a keyword the
  validator does not implement.
- Functional validation of critical paths in `validate-config`.
- Safe command-name validation for `runtime.required_commands` in preflight.
- Safe YAML loading (`YAML.safe_load`) on the Ruby path.
- Security CI running Semgrep and Gitleaks from pinned container images, so the
  scanners do not depend on the runner's toolchain.

## Good practice for contributors

- Avoid shell invocations interpolating untrusted input.
- Prefer shell-free APIs (`subprocess.run([...])`, `shutil.which`, and so on).
- Load YAML safely with `yaml.safe_load` (Python) or `YAML.safe_load` (Ruby).
- Validate command names and filter paths before executing configuration input.
- Review bootstrap and CI dependencies against `docs/dependency-policy.md`.
- Add a security regression test whenever a vulnerability is fixed.
