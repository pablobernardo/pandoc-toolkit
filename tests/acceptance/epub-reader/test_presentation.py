"""B1: DOM readiness must precede paint synchronization, not replace it."""
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from driver import Reader


def observation(marker):
    return {'native': {'window_id': '42', 'window_title': 'Skelepress [EPUB]',
                       'capture_rect': [0, 0, 1280, 900]},
            'book': {'heading': 'Building a book', 'visible_text': 'Book building instructions',
                     'is_book': True, 'images_broken': 0, 'width': 300, 'height': 30,
                     'url': 'clbr://internal.sandbox/book/__index__'},
            'welcome': False, 'marker': marker}


class PresentationTests(unittest.TestCase):
    def test_shared_capture_waits_before_screenshot_and_records_post_paint_state(self):
        reader = Reader(Path('/evidence'), {'title': 'Skelepress'}, {'captures': []})
        before, after = observation('DOM-ready'), observation('post-paint')
        after['native']['capture_rect'] = [1, 1, 1279, 899]
        order = []
        reader.wait_for_paint = Mock(side_effect=lambda *args: order.append('paint') or after)
        with (
            patch('driver.capture_window', side_effect=lambda *args: order.append('screenshot')) as shot,
            patch('driver.write_record') as record,
        ):
            actual = reader.capture('destination', before)
        self.assertEqual(order, ['paint', 'screenshot'])
        reader.wait_for_paint.assert_called_once_with(before, 'Building a book')
        shot.assert_called_once_with(reader.output, 'destination.png', after['native'], 'Skelepress')
        self.assertIs(record.call_args_list[0].args[1], after)
        self.assertIs(actual, after)

    def test_paint_opportunity_then_two_stable_reobservations(self):
        reader = Reader(Path('/evidence'), {}, {})
        before, first, second = [observation(label) for label in ('DOM-ready', 'paint-1', 'paint-2')]
        order = []
        reader.book_client = Mock()
        reader.book_client.evaluate.side_effect = lambda *args, **kwargs: order.append('frames') or 123
        reader.book_context = 7
        reader.observe = Mock(side_effect=lambda heading: order.append('observe') or
                              (first if order.count('observe') == 1 else second))
        with patch('driver.time.sleep', side_effect=lambda duration: order.append('settle')):
            actual = reader.wait_for_paint(before, 'Building a book')
        self.assertEqual(order, ['frames', 'settle', 'observe', 'settle', 'observe'])
        self.assertTrue(reader.book_client.evaluate.call_args.kwargs['await_promise'])
        self.assertIs(actual, second)

    def test_changed_post_paint_destination_prevents_screenshot(self):
        reader = Reader(Path('/evidence'), {'title': 'Skelepress'}, {'captures': []})
        before, first, stale = observation('DOM-ready'), observation('paint-1'), observation('stale')
        stale['book']['heading'] = 'Architecture'
        reader.book_client, reader.book_context = Mock(), 7
        reader.observe = Mock(side_effect=[first, stale])
        with (
            patch('driver.time.sleep'), patch('driver.capture_window') as shot,
            patch('driver.write_record'),
            self.assertRaisesRegex(ValueError, 'post-paint'),
        ):
            reader.capture('destination', before)
        shot.assert_not_called()
        self.assertEqual(reader.result['captures'], [])


if __name__ == '__main__':
    unittest.main()
