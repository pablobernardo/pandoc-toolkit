"""Fixed-fixture selection and observable page-coverage requirements."""
import unittest

from evidence import clean_title, missing_features, validate_navigation
from scenarios import scenario_for


class ScenarioTests(unittest.TestCase):
    def test_exact_fixture_selection_and_explicit_mismatch(self):
        for name, digest, title, targets in [
            ('technical', 'b67eb24ea2ae8b6a251ed54831e11497ce8107219220b039cf356446f1a10e70',
             'Project Technical Documentation', ['Introduction']),
            ('documentation', '79ce8b2d5923f05ba95d71363ca9fd948df318b4b2de890344afd5c7d73cd6d7',
             'Skelepress', ['Usage — Skelepress', 'Usage — Skelepress',
                            'Architecture — Multi-Repository PDF Generator (Pandoc)']),
            ('manual', 'f116c2a04529edc3a5058f1930aef49ab0879665c9b08631a96f1095494caad1',
             'The Honest Machine', ['Requirements', 'Audit', 'Error codes', 'Glossary']),
            ('ohmyfake', '2fece4a76365aab53df1d56b0277163de3caf7487ddabe6a4183e6869f1190fd',
             'Oh My Fake', ['A Visible Compatibility Check 🔍', 'What Counts as a Fake']),
        ]:
            with self.subTest(name=name):
                scenario = scenario_for(digest, name)
                self.assertEqual(scenario_for(digest), scenario)
                self.assertEqual(scenario['title'], title)
                self.assertEqual([s['target'] for s in scenario['steps']], targets)
                with self.assertRaises(ValueError):
                    scenario_for(digest, 'not-a-scenario')
        with self.assertRaises(ValueError):
            scenario_for('0' * 64)
        with self.assertRaises(ValueError):
            scenario_for('b67eb24ea2ae8b6a251ed54831e11497ce8107219220b039cf356446f1a10e70', 'manual')

    def test_numbered_subheading_navigation_preserves_introduction(self):
        self.assertEqual(clean_title('3.1.3 Audit'), 'Audit')
        state = {'clicked': True, 'heading': '3.1.3 Audit', 'width': 100, 'height': 30,
                 'body_chars': 100, 'images_broken': 0, 'is_book': True, 'changed': True,
                 'welcome_visible': False}
        validate_navigation(state, 'Audit')
        with self.assertRaises(ValueError):
            validate_navigation(state, 'Requirements')

    def test_tables_require_every_word_across_captured_continuations(self):
        step = {'tables': ['Code | Meaning']}
        table = {'key': 'Code | Meaning', 'required': ['0:0', '1:0'],
                 'seen': ['0:0'], 'empty': [], 'overflow': []}
        first = {'tables': [table], 'images': [], 'emoji_text': []}
        self.assertTrue(missing_features([first], step))
        last = dict(first, tables=[dict(table, seen=['1:0'])])
        self.assertEqual(missing_features([first, last], step), [])
        for key in ('empty', 'overflow'):
            with self.subTest(key=key):
                bad = dict(first, tables=[dict(table, seen=table['required'], **{key: ['1']})])
                self.assertTrue(missing_features([bad], step))

    def test_figures_and_emoji_need_loaded_fully_visible_images_and_text(self):
        step = {'figures': ['file9.png'], 'emoji_images': ['paragraph', 'list', 'table'],
                'emoji_heading': '🔍', 'emoji_sources': ['file7.svg', 'file8.svg']}
        image = {'src': 'clbr://book/media/file9.png', 'full': True,
                 'naturalWidth': 400, 'naturalHeight': 300, 'complete': True,
                 'emoji_context': ''}
        page = {'tables': [], 'images': [image], 'emoji_text': []}
        self.assertTrue(missing_features([page], step))
        page['images'] += [dict(image, src=source, emoji_context=context)
                           for context in step['emoji_images'] for source in step['emoji_sources']]
        page['emoji_text'] = ['🔍']
        self.assertEqual(missing_features([page], step), [])
        self.assertTrue(missing_features([dict(page, images=page['images'][:-1])], step))
        for key, value in [('full', False), ('naturalWidth', 0), ('naturalHeight', 0),
                           ('complete', False)]:
            with self.subTest(key=key):
                broken = dict(page, images=[dict(i, **{key: value}) for i in page['images']])
                self.assertTrue(missing_features([broken], step))

    def test_tall_figure_requires_complete_captured_continuations(self):
        step = {'figures': ['tall.png']}
        image = {'src': 'tall.png', 'full': False, 'complete': True,
                 'naturalWidth': 488, 'naturalHeight': 1030, 'emoji_context': '',
                 'slice': [0, 0.6]}
        page = {'tables': [], 'images': [image], 'emoji_text': []}
        self.assertTrue(missing_features([page], step))
        last = dict(page, images=[dict(image, slice=[0.55, 1])])
        self.assertEqual(missing_features([page, last], step), [])
        gap = dict(page, images=[dict(image, slice=[0.7, 1])])
        self.assertTrue(missing_features([page, gap], step))


if __name__ == '__main__':
    unittest.main()
