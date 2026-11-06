"""Exact v3.0.0 public fixtures; expectations grounded in prepared Markdown/EPUB."""
from typing import Any

SCENARIOS: dict[str, dict[str, Any]] = {
    'technical': {
        'sha256': 'b67eb24ea2ae8b6a251ed54831e11497ce8107219220b039cf356446f1a10e70',
        'title': 'Project Technical Documentation',
        'not_applicable': ['tables', 'figures', 'authored cross-references'],
        'steps': [{'target': 'Introduction'}],
    },
    'documentation': {
        'sha256': '79ce8b2d5923f05ba95d71363ca9fd948df318b4b2de890344afd5c7d73cd6d7',
        'title': 'Skelepress',
        'not_applicable': ['image cover'],
        'steps': [
            {'target': 'Usage — Skelepress',
             'tables': ['Example | What it shows', 'Setting | Default | Matters when']},
            {'target': 'Usage — Skelepress',
             'link': {'text': 'books.md', 'href': 'ch003.xhtml#ch-books',
                      'destination': 'Building a book'}},
            {'target': 'Architecture — Multi-Repository PDF Generator (Pandoc)',
             'link': {'text': 'migration', 'href': 'ch004.xhtml#ch-migration',
                      'destination': 'Migrating to 2.1.0'}},
        ],
    },
    'manual': {
        'sha256': 'f116c2a04529edc3a5058f1930aef49ab0879665c9b08631a96f1095494caad1',
        'title': 'The Honest Machine',
        'not_applicable': ['authored live cross-references', 'image cover'],
        'steps': [
            {'target': 'Requirements', 'tables': ['Item | Requirement | Why']},
            {'target': 'Audit', 'figures': ['file0.png']},
            {'target': 'Error codes', 'tables': ['Code | Meaning | First response'],
             'figures': ['file1.png']},
            {'target': 'Glossary', 'tables': ['Term | Meaning in this manual']},
        ],
    },
    'ohmyfake': {
        'sha256': '2fece4a76365aab53df1d56b0277163de3caf7487ddabe6a4183e6869f1190fd',
        'title': 'Oh My Fake',
        'not_applicable': ['authored live cross-references', 'image cover',
                           'body/list/table textual emoji: prepared EPUB uses SVG images instead'],
        'steps': [
            {'target': 'A Visible Compatibility Check 🔍',
             'tables': ['Check | Signal | What to inspect'], 'figures': ['file9.png'],
             'emoji_heading': '🔍', 'emoji_images': ['paragraph', 'list', 'table'],
             'emoji_sources': ['file7.svg', 'file8.svg']},
            {'target': 'What Counts as a Fake', 'figures': ['file0.png']},
        ],
    },
}


def scenario_for(digest, name=None):
    for key, scenario in SCENARIOS.items():
        if scenario['sha256'] == digest and name in (None, key):
            return dict(scenario, name=key)
    raise ValueError('Unknown fixture or scenario/hash mismatch')
