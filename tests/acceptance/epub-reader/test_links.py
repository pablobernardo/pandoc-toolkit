"""Regressions from the actual Calibre documentation-link observations."""
import unittest

from driver import Reader
from evidence import link_matches
from scenarios import scenario_for


class LinkTests(unittest.TestCase):
    def test_observed_handler_href_and_authored_href_match_without_stale_schemes(self):
        scenario = scenario_for('79ce8b2d5923f05ba95d71363ca9fd948df318b4b2de890344afd5c7d73cd6d7')
        for step in scenario['steps'][1:]:
            spec = step['link']
            with self.subTest(text=spec['text']):
                for href in ('javascript:void(0)', spec['href']):
                    anchor = {'text': spec['text'], 'href': href}
                    self.assertTrue(link_matches(anchor, spec))
                    self.assertEqual(anchor, {'text': spec['text'], 'href': href})
                for href in (None, '', 'javascript:void(1)', spec['href'] + '-stale',
                             'clbr://stale.invalid/book/' + spec['href'],
                             'https://example.invalid/' + spec['href'],
                             'ch999.xhtml#wrong-destination'):
                    self.assertFalse(link_matches({'text': spec['text'], 'href': href}, spec))
                self.assertFalse(link_matches({'text': 'unrelated', 'href': 'javascript:void(0)'}, spec))

    def test_handler_activation_still_requires_changed_correct_destination(self):
        before = {'visible_text': 'Usage page with books.md'}
        book = {'visible_text': 'The migration page', 'heading': 'Migrating to 2.1.0',
                'width': 300, 'height': 30, 'body_chars': 200,
                'images_broken': 0, 'is_book': True}
        observation = {'book': book, 'welcome': False}
        self.assertFalse(Reader.arrived(observation, before, True, 'Building a book'))
        book.update(heading='Building a book', visible_text='Book building instructions')
        self.assertTrue(Reader.arrived(observation, before, True, 'Building a book'))
        self.assertFalse(Reader.arrived(observation, before, False, 'Building a book'))
        book['visible_text'] = before['visible_text']
        self.assertFalse(Reader.arrived(observation, before, True, 'Building a book'))


if __name__ == '__main__':
    unittest.main()
