# Observe prepared EPUBs in the real Calibre viewer

This opt-in probe uses Calibre's actual viewer, native Qt TOC, X11 input and Xvfb
screenshots. It neither substitutes a browser nor invokes `ebook-convert`.
It is separate from `make test` and CI. **`scenario-observed` is not visual
acceptance**: the executing agent must analyze the captures for readability,
correct figures, glyphs, table continuations and clipping. Human review is optional.

## Build and stage

Use the existing local Docker Engine (`desktop-linux` in the prepared environment).
No macOS installation or desktop access is needed. Run Docker builds/runs through
the orchestrator's background facility and collect actual exit codes and logs.

```bash
docker --context desktop-linux build --progress=plain \
  -t skelepress-epub-reader:bookworm tests/acceptance/epub-reader
```

Create a fresh dedicated public-only input directory and evidence root under
`.git/epub-reader-acceptance/calibre`. Choose unused names; never reuse previous
proof directories. The original manifest/EPUBs remain unchanged. Its historical
Apple Books metadata does not describe these Calibre runs.

```bash
INPUT="$PWD/.git/epub-reader-acceptance/calibre/input-scenarios"
EVIDENCE="$PWD/.git/epub-reader-acceptance/calibre/scenario-proof"
mkdir "$INPUT" && mkdir "$EVIDENCE" || exit 1
export INPUT EVIDENCE
python3 - <<'PY'
import hashlib
import json
import os
from pathlib import Path
import shutil
manifest = json.loads(Path('.git/epub-reader-acceptance/run.BMUanX/manifest.json').read_text())
assert manifest['release_commit'] == '95ee3d8fa3ae564a14d80a62f24789a1815d9816'
for book in manifest['publications']:
    source = Path(book['path'])
    assert hashlib.sha256(source.read_bytes()).hexdigest() == book['sha256']
    target = Path(os.environ['INPUT']) / book['name']
    shutil.copyfile(source, target)
    target.chmod(0o644)
PY
chmod 755 "$INPUT"
```

## Run one scenario per container

The helper below creates a **new** output directory per book and preserves its
Docker exit code. Mount only the dedicated public-only input/output directories,
never the checkout or `.git` root. Do not expose ports, home, Docker socket,
desktop or host X sockets. CDP listens on container loopback with networking off.

```bash
run_reader() {
  local scenario=$1 file=$2 digest=$3
  local output="$EVIDENCE/$scenario"
  mkdir "$output" || return 1
  chmod 777 "$output"  # Writable by container's unprivileged UID; public evidence only.
  docker --context desktop-linux image inspect skelepress-epub-reader:bookworm \
    --format '{{.Id}}' > "$output/image-id.txt" || return
  docker --context desktop-linux run --rm --network none \
    --cap-drop ALL --security-opt no-new-privileges:true \
    --read-only --tmpfs /tmp:rw,nosuid,nodev,size=512m --shm-size=256m \
    --memory=2g --cpus=2 --pids-limit=256 \
    --mount "type=bind,src=$INPUT,dst=/input,readonly" \
    --mount "type=bind,src=$output,dst=/evidence" \
    skelepress-epub-reader:bookworm "/input/$file" "$digest" --scenario "$scenario" \
    > "$output/container.log" 2>&1
}
run_reader documentation toolkit-documentation-20261106.epub \
  79ce8b2d5923f05ba95d71363ca9fd948df318b4b2de890344afd5c7d73cd6d7
run_reader manual honest-machine-manual-20261106.epub \
  f116c2a04529edc3a5058f1930aef49ab0879665c9b08631a96f1095494caad1
run_reader ohmyfake oh-my-fake-latest.epub \
  2fece4a76365aab53df1d56b0277163de3caf7487ddabe6a4183e6869f1190fd
# Optional preservation rerun; historical native-toc-proof already establishes T1.
run_reader technical project-technical-documentation-20261106.epub \
  b67eb24ea2ae8b6a251ed54831e11497ce8107219220b039cf356446f1a10e70
```

Launch each invocation as its own background job; do not infer success from the
last invocation alone. The positional EPUB/hash interface is retained; `--scenario`
is optional because the exact hash selects the fixture. Unknown hashes or explicit
scenario mismatches fail before viewer launch. Runtime limits are 25 seconds per
wait, 60 PageDown captures per step, 240 seconds per scenario, and a 260-second
process limit plus five-second termination grace. Build/startup is separate.

## Fixed checks and evidence

| Scenario | Actual native TOC targets and features |
| --- | --- |
| technical | Introduction/body; tables, figures and authored cross-references N/A |
| documentation | Usage tables (both), Usage `books.md` link to Building a book, Architecture `migration` link to Migrating to 2.1.0 |
| manual | Requirements table; Audit figure; Error codes table including long cells and subsequent figure; Glossary table |
| ohmyfake | A Visible Compatibility Check 🔍 heading, paragraph/list/table SVG emoji and table, its Mermaid figure; What Counts as a Fake figure |

Expectations in `scenarios.py` come from the prepared v3.0.0 Markdown and exact
EPUB XHTML, not current renderer output. No image-cover fixture exists. The
manual/Oh My Fake sources declare no authored live cross-reference: that feature
is N/A, not a fabricated pass. The technical title page is observed, not treated
as a PDF-style `titlepage:false` failure.

The prepared Oh My Fake EPUB preserves U+1F50D in the heading as a character,
but the filter converts body/list/table U+1F9EA/U+1F50D to SVG images. Textual emoji
in those contexts is therefore **N/A**; both actual SVG resources are checked in
each context. Do not claim those body codepoints survived, or infer glyph quality
from geometry. The executing agent judges the actual screenshot representations.

| Artifact | Evidence |
| --- | --- |
| `title-page.png/.json` | Identified viewer title page captured before any navigation |
| `step-NN-toc.png/.json` | Actual native TOC with requested item before its X11 click |
| `step-NN-page-NN.png/.json` | Every inspected page, live text, fonts/colors, viewport, image dimensions and table-cell geometry/token coverage |
| `step-NN-link-destination.png/.json` | Real live-anchor activation destination |
| `result.json` | Identity, package versions, scenario/N/A rules, native and link activation records, capture index and progress/error |
| `native.json`, `live-frames.json` | Last actual native Qt and live WebEngine observations |
| `reader.png`, `viewer.log`, `xvfb.log`, `container.log`, `exit-code.txt` | Final display and failure/startup diagnostics |
| `image-id.txt` | Exact image identity for the run |

Every native navigation requires the real Qt clicked signal and changed visible
book content with the expected heading. A sequence-numbered request selects each
native model item; instrumentation never calls navigation methods or synthesizes
the signal. Documentation links use a fully visible live anchor's `click()` event,
not an internal reader goto; records distinguish this from native X11 clicks and
include text, the actual live href, expected authored href and observed destination.
Calibre 6.13 was observed replacing both documentation hrefs with
`javascript:void(0)` and retaining navigation in a click handler. Selection accepts
that exact observed representation or the exact authored href, never an arbitrary
scheme/suffix match. The anchor must be unique and still fully visible with the
same text/href when clicked. The handler href itself cannot identify a destination:
changed live content and the expected destination heading remain mandatory.

All named captures share a bounded presentation barrier: await two animation-frame
opportunities in the actual live WebEngine book frame, allow 600 ms for Qt/X11
presentation, then re-observe twice 150 ms apart. Expected content/heading must
remain present and the two observations must agree on book content/geometry.
Screenshots, JSON and coverage checks use the fresh post-barrier state, not the
initial DOM-ready snapshot. A changed/unstable state fails rather than retrying a
capture. These presentation opportunities do not themselves prove that pixels are
correct: the executing agent must still inspect the actual fresh X-server captures.

PageDown is actual X11 input. Table coverage accumulates every text-range fragment
and embedded image across captured pages, rejects empty cells and visible horizontal
overflow, and retains continuation geometry. A required figure must be loaded with positive
natural width/height and either fully captured or have complete, gap-free measured
vertical continuations across captures (with its full width visible). The prepared
Error codes and What Counts as a Fake PNGs are 1030 and 1257 pixels tall, respectively;
partial visibility alone is not enough. These checks remain necessary but not
sufficient for visual acceptance.

## Safety, limitations and fast checks

Use only the fresh profile's default light appearance; the executing agent must
confirm the recorded colors/screenshots are light. No dark-mode, Apple Books or
section-fragment compatibility is claimed. All four prepared publications have
accepted, agent-analyzed captures. Documentation's initial DOM-ready screenshots
were blank/stale; the corrected presentation barrier produced visible **Building
a book** and **Migrating to 2.1.0** destinations, independently rechecked against
the fresh Xvfb screenshots. Earlier failed evidence is retained, not counted as a
pass. Runtime reports and screenshot hashes are recorded in issue #94; captures
remain local under `.git/epub-reader-acceptance/calibre/`.
Native APIs, frame schemes and fragment geometry remain version-sensitive and fail
rather than fall back to static rendering.

The scripts run nonroot and add no sandbox-disabling flags. Qt initialization was
observed to include `disable-setuid-sandbox` among its own defaults; this harness
does not certify Qt/Chromium sandbox internals. If prerequisites fail,
stop: never add privileged mode, SYS_ADMIN, unconfined seccomp, `--no-sandbox` or
`QTWEBENGINE_DISABLE_SANDBOX`. The bookworm distribution tag is not a package/digest
lock; preserve image identity, build logs and installed package versions. Qt version
collection is major-independent. Keep evidence directories until their owner removes them.

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/acceptance/epub-reader -p 'test_*.py'
python3 -c "from pathlib import Path; [compile(p.read_text(), str(p), 'exec') for p in Path('tests/acceptance/epub-reader').glob('*.py')]"
bash -n tests/acceptance/epub-reader/entrypoint.sh
git diff --check
```

These deterministic checks do not prove GUI appearance. No synthetic visual RED
or unexecuted four-book acceptance is claimed.
