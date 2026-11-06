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
