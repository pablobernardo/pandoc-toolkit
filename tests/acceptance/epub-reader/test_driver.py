"""Deterministic evidence checks; no GUI simulation or visual acceptance."""
import hashlib
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import evidence


class EvidenceTests(unittest.TestCase):
    def test_versions_discover_installed_webengine_without_qt_major_assumption(self):
        for package in ('libqt6webenginecore6:arm64', 'libqt5webenginecore5:amd64'):
            with self.subTest(package=package):
                def query(command, *, text, package=package):
                    if 'libqt5webenginecore5' in command:
                        raise evidence.subprocess.CalledProcessError(1, command)
                    self.assertIn('libqt*webengine*', command)
                    self.assertIn('-f=${binary:Package}\t${Version}\t${db:Status-Status}\n', command)
                    self.assertTrue(text)
                    return (f'calibre\t6.13.0\tinstalled\n{package}\t6.4.2\tinstalled\n'
                            'libqt-unused\t\tconfig-files\n')
                with patch.object(evidence.subprocess, 'check_output', side_effect=query):
                    self.assertEqual(evidence.collect_versions(),
                                     f'calibre\t6.13.0\n{package}\t6.4.2\n')

    def test_input_identity_and_rejection_without_mutation(self):
        with tempfile.TemporaryDirectory() as directory:
            book = Path(directory) / 'public.epub'
            book.write_bytes(b'public fixture')
            digest = hashlib.sha256(book.read_bytes()).hexdigest()
            self.assertEqual(evidence.verify_input(book, digest), digest)
            with self.assertRaisesRegex(ValueError, 'SHA256 mismatch'):
                evidence.verify_input(book, '0' * 64)
            self.assertEqual(book.read_bytes(), b'public fixture')

    def test_navigation_requires_activation_and_readable_live_heading(self):
        valid = {'clicked': True, 'heading': 'Introduction', 'width': 500,
                 'height': 32, 'body_chars': 200, 'images_broken': 0,
                 'welcome_visible': False, 'is_book': True, 'changed': True}
        evidence.validate_navigation(valid)
        for key, value in [('clicked', False), ('heading', 'Contents'),
                           ('width', 0), ('height', 0), ('body_chars', 0),
                           ('images_broken', 1)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                evidence.validate_navigation(dict(valid, **{key: value}))

    def test_navigation_rejects_welcome_nonbook_and_unchanged_content(self):
        valid = {'clicked': True, 'heading': 'Introduction', 'width': 500,
                 'height': 32, 'body_chars': 200, 'images_broken': 0,
                 'welcome_visible': False, 'is_book': True, 'changed': True}
        for key, value in [('welcome_visible', True), ('is_book', False), ('changed', False)]:
            with self.subTest(key=key), self.assertRaises(ValueError):
                evidence.validate_navigation(dict(valid, **{key: value}))


if __name__ == '__main__':
    unittest.main()
