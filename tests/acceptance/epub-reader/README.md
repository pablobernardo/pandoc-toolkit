# EPUB reader evidence contracts

These opt-in test helpers describe the four prepared v3.0.0 publications and
reject insufficient evidence. They do not render books or certify GUI appearance.

- `evidence.py` checks input identity, destination observations, complete table
  text fragments, loaded figure coverage and visible emoji representations.
- `scenarios.py` selects source-grounded expectations by exact EPUB SHA256.
- The tests reject mismatched inputs, unobserved navigation, incomplete resources
  and incorrect link destinations without changing the original EPUBs.

## Check the contracts

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s tests/acceptance/epub-reader -p 'test_*.py'
```

The real-reader observation and isolated Docker integration are subsequent
dependent work units. A passing contract test is not a publication acceptance.

## Observe the actual reader

`native.py` runs Calibre's normal viewer entry point with native Qt observation.
It exposes the real TOC model item coordinates and observes its clicked signal;
it never replaces the normal navigation handler or synthesizes that signal.

`observe.js` inspects only live Qt WebEngine frames in that viewer. It records
visible text, table fragments, loaded images, emoji and layout geometry.
These observations are necessary evidence, not a replacement HTML renderer.

The controller sends sequence-numbered requests through the disposable profile.
X11 clicks activate the native TOC; subsequent observations must prove the
changed destination. Version-sensitive native APIs fail rather than silently
fall back to static markup. The dependent Docker integration supplies the
bounded controller, virtual display, presentation synchronization and captures.
