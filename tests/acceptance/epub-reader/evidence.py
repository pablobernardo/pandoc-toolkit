"""Deterministic identity and evidence rules, independent of a GUI runtime."""
import hashlib
import json
import re
import subprocess


def write_record(path, value):
    path.write_text(json.dumps(value, indent=2))


def clean_title(text):
    return re.sub(r'^\d+(?:\.\d+)*[.\s]+', '', text).strip()


def verify_input(path, expected):
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if digest != expected:
        raise ValueError('SHA256 mismatch')
    return digest


def validate_navigation(state, heading='Introduction'):
    if not (state['clicked'] and clean_title(state['heading']) == heading
            and state['width'] > 0 and state['height'] > 0
            and state['body_chars'] >= 80 and state['images_broken'] == 0
            and state['is_book'] and state['changed'] and not state['welcome_visible']):
        raise ValueError('No readable live destination after actual activation')


def collect_versions():
    packages = subprocess.check_output(
        ['dpkg-query', '-W', '-f=${binary:Package}\t${Version}\t${db:Status-Status}\n',
         'calibre', 'xvfb', 'python3', 'libqt*webengine*',
         'fonts-dejavu-core', 'fonts-noto-color-emoji'], text=True)
    return ''.join(f'{name}\t{version}\n'
                   for name, version, status in (line.split('\t') for line in packages.splitlines())
                   if status == 'installed')


def link_matches(anchor, spec):
    # Calibre's observed live href hides the destination in its click handler.
    # Only actual post-click book content can prove the scenario's destination.
    return anchor['text'] == spec['text'] and anchor.get('href') in (
        spec['href'], 'javascript:void(0)')


def missing_features(pages, step):
    missing = []
    for key in step.get('tables', []):
        tables = [table for page in pages for table in page['tables'] if table['key'] == key]
        required = {token for table in tables for token in table['required']}
        seen = {token for table in tables for token in table['seen']}
        if (not tables or not required or required - seen
                or any(table['empty'] or table['overflow'] for table in tables)):
            missing.append(f'table coverage/empty/overflow: {key}')
    loaded = [image for page in pages for image in page['images']
              if image['complete'] and image['naturalWidth'] > 0 and image['naturalHeight'] > 0]
    images = [image for image in loaded if image['full']]
    for filename in step.get('figures', []):
        end = 0
        slices = [([0, 1] if image['full'] else image.get('slice', []))
                  for image in loaded if image['src'].endswith(filename)]
        for start, stop in sorted(part for part in slices if len(part) == 2):
            if start > end + 0.001:
                break
            end = max(end, stop)
        if end < 0.999:
            missing.append(f'visible loaded figure/continuation: {filename}')
    for context in step.get('emoji_images', []):
        for filename in step.get('emoji_sources', ['']):
            if not any(image['emoji_context'] == context and image['src'].endswith(filename)
                       for image in images):
                missing.append(f'visible SVG emoji: {context} {filename}')
    emoji = step.get('emoji_heading')
    if emoji and not any(emoji in page['emoji_text'] for page in pages):
        missing.append(f'visible heading codepoint: U+{ord(emoji):04X}')
    return missing
