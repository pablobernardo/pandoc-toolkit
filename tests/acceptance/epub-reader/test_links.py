"""Regressions from the actual Calibre documentation-link observations."""
import unittest

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



if __name__ == '__main__':
    unittest.main()
