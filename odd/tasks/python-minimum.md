# Declare and enforce the Python the renderer needs
Branch: `fix/python-minimum`; delivery: one code PR closing #156.
Scope: the renderer's use of a 3.10-only construct, the preflight's Python check, the catalogs and the documentation. The render pipeline's output does not change.

## Specs

- S1: The toolkit runs on Python 3.9.6, the interpreter macOS ships, or the audit proves it cannot and says exactly which construct blocks it. #156 records the defect: `render-native.py:579` calls `zip(..., strict=True)`, which needs 3.10, so a stock macOS gives `TypeError: zip() takes no keyword arguments` mid-render.
- S2: The guarantee `strict=True` provided is kept, not dropped: unequal chapter and text counts must still fail loudly rather than truncate silently.
- S3: The supported minimum is declared where a consumer reads it, and the preflight enforces it. `preflight.py:25` lists `python3` in `DEFAULT_REQUIRED` and checks only that it exists.
- S4: The refusal names the version found and the version required, through the catalogs, in `en`, `es`, `gl` and `pt`, like every other message.
- S5: The check reflects the interpreter the renderer will actually run, not an unrelated one, and it does not run a network or package operation.
- S6: Behaviour is otherwise unchanged: `doctor`, `validate-config` and `render` on a supported interpreter keep their current output, exit codes and plans.
- S7: Tests pin both directions: an interpreter below the minimum is refused with that message, and the supported interpreter passes. Register every new test in `tests/run.sh`.

## Tasks

- T1 [S1–S7] done; route: delegated worker, verified by the parent. The audit found no other 3.10+ construct; `render-native.py` now compares lengths and dies with `render.error.chapter_count_mismatch` before indexing, so the guarantee survives without `strict=`. `preflight.py` probes the `python3` resolved from `PATH` with `--version` only and refuses anything below 3.9 through `doctor.error.python_version`, not waivable by `runtime.strict=false`. Both keys exist in the four catalogs. Parent verification: the construct raises `TypeError: zip() takes no keyword arguments` under `/usr/bin/python3` 3.9.6, the example renders under that interpreter (exit 0, PDF and EPUB produced), and `doctor` refuses a faked 3.8 in Spanish and in English. Gate 569/0, 179 catalog keys, 76 documentation files, 4 conforming plans.

## Log

- L1 — Maintainer chose the third option among three: accept 3.9 so the toolkit works with the interpreter macOS ships, and at the same time declare the minimum and preflight it, so nobody raises the bar silently again.
- L2 — Parent audit before delegating: every module under `scripts/runtime/` carries `from __future__ import annotations`, so `str | None` annotations are not a 3.9 blocker; `zip(..., strict=True)` at `render-native.py:579` is the only 3.10-only construct found by grep. The worker must confirm that with its own audit rather than trust this line.
- L3 — T1 implemented on `fix/python-minimum`. Worker audit confirmed L2: `zip(..., strict=True)` at `render-native.py:579` is the only 3.10+ construct across `scripts/runtime/*.py` and `scripts/tools/bookkit/*.py`; all modules carry `from __future__ import annotations` and no `match`, merge `|`, runtime union, `removeprefix`/`removesuffix`, `functools.cache` or `asyncio.timeout` usage exists. Replacement keeps the loud-failure guarantee with an explicit count check (`render.error.chapter_count_mismatch`) plus index access, because the linter rejects any `zip()` without `strict=`. Preflight now probes the `python3` resolved from `PATH` (the interpreter `bin/pandoc-pdf` starts the renderer with) via `--version` only and refuses below `(3, 9)` with `doctor.error.python_version`, not waivable by `runtime.strict=false`; an unreadable version is skipped since the missing-command check already covers a python3 that does not run. Minimum documented in `docs/dependency-policy.md` (new section + pinned list) and `docs/install.md`. Tests: `run_doctor_python_minimum_test` (refusal + acceptance) and `run_render_python39_test` (render through `/usr/bin/python3`, skipped off-macOS), both registered in `tests/run.sh`.
