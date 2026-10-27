---
name: pandoc-toolkit-security-review
description: >
  Skill for reviewing security risk in changes to the pandoc-pdf toolkit,
  focused on configuration input, process execution and supply chain.
  Trigger: when modifying CLI/render/preflight/bootstrap scripts, CI or the configuration contract.
license: MIT
metadata:
  author: pablobernardo
  version: "1.0"
---

## When to use

- Changes in `scripts/preflight.py`, `scripts/validate-config.py`,
  `scripts/render-native.py`.
- Changes in `scripts/bootstrap.sh` or `.github/workflows/ci.yml`.
- Changes in configuration fields that can execute processes
  (`runtime.required_commands`, `filters.extra_lua_filters`).

## Critical patterns

1. **No shell with configuration interpolation**
   - Do not use `bash -c` with values from `pdf.config.yaml`.
   - Prefer `shutil.which`, `subprocess.run([...])` and format validation.

2. **Safe YAML loading**
   - In Ruby, use `YAML.safe_load`.
   - In Python, use `yaml.safe_load`.

3. **Explicit validation of executable input**
   - `runtime.required_commands`: safe name pattern.
   - `filters.extra_lua_filters`: controlled and validated paths.

4. **Controlled supply chain**
   - Review packages installed in bootstrap and CI.
   - Pin versions and document the update policy.

5. **Mandatory regression**
   - Every security fix must include a regression test.

## Review checklist

- [ ] No `bash -c` with unsanitised configuration input.
- [ ] No `YAML.load_file` on untrusted input paths.
- [ ] Paths and commands are validated before execution.
- [ ] Tests were added that fail if the bug reappears.
- [ ] `SECURITY.md` is updated if the risk model changes.

## Commands

```bash
tests/run.sh
pandoc-pdf doctor -c tests/fixtures/doctor-config-required-cmd.yaml
pandoc-pdf validate-config -c tests/fixtures/valid.config.yaml
```

## Resources

- Security policy: `../../../.github/SECURITY.md`
- Agent contract: `../../../AGENTS.md`
- Usage guide: `../../../docs/usage.md`
