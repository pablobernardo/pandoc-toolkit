"""Opt-in real Calibre fixture scenarios; observations are not visual acceptance."""
import argparse
import importlib
import json
import os
import subprocess
import time
import urllib.request
from pathlib import Path

from evidence import (
    clean_title,
    collect_versions,
    link_matches,
    missing_features,
    validate_navigation,
    verify_input,
    write_record,
)
from scenarios import scenario_for

DOM = Path(__file__).with_name('observe.js').read_text()


class CDP:
    def __init__(self, url):
        websocket = importlib.import_module('websocket')  # Debian python3-websocket.
        self.ws = websocket.create_connection(url, timeout=3, suppress_origin=True)
        self.serial = 0

    def call(self, method, **params):
        self.serial += 1
        self.ws.send(json.dumps({'id': self.serial, 'method': method, 'params': params}))
        while True:
            reply = json.loads(self.ws.recv())
            if reply.get('id') == self.serial:
                if 'error' in reply:
                    raise RuntimeError(str(reply['error']))
                return reply.get('result', {})

    def contexts(self):
        tree = self.call('Page.getFrameTree')['frameTree']
        def walk(node):
            yield self.call('Page.createIsolatedWorld', frameId=node['frame']['id'],
                            worldName='acceptance')['executionContextId']
            for child in node.get('childFrames', []):
                yield from walk(child)
        return list(walk(tree))

    def evaluate(self, expression, context, *, await_promise=False):
        reply = self.call('Runtime.evaluate', expression=expression, contextId=context,
                          returnByValue=True, awaitPromise=await_promise)
        if 'exceptionDetails' in reply:
            raise RuntimeError(str(reply['exceptionDetails']))
        return reply['result'].get('value')


def capture_window(output, name, native, book_title):
    title = subprocess.check_output(
        ['xdotool', 'getwindowname', native['window_id']], text=True).strip()
    if not book_title or book_title not in title or title != native['window_title']:
        raise RuntimeError('Capture window does not match the identified book viewer')
    region = ','.join(map(str, native['capture_rect']))
    subprocess.run(['scrot', '--overwrite', f'--autoselect={region}', str(output / name)], check=True)


class Reader:
    """The proven native viewer plus bounded, recorded user-input operations."""
    def __init__(self, output, scenario, result):
        self.output, self.scenario, self.result = output, scenario, result
        self.clients = {}
        self.sequence = 0
        self.deadline = time.monotonic() + 240
        self.book_client = self.book_context = None

    def observe(self, heading):
        frames = []
        with urllib.request.urlopen('http://127.0.0.1:9222/json', timeout=2) as response:
            targets = json.load(response)
        for target in targets:
            if target.get('type') != 'page':
                continue
            if target['id'] not in self.clients:
                self.clients[target['id']] = CDP(target['webSocketDebuggerUrl'])
            client = self.clients[target['id']]
            for context in client.contexts():
                state = client.evaluate(f'({DOM})({json.dumps(heading)})', context)
                frames.append(state)
                if state['is_book']:
                    self.book_client, self.book_context = client, context
        write_record(self.output / 'live-frames.json', frames)
        native_path = self.output / 'native.json'
        native = json.loads(native_path.read_text()) if native_path.exists() else {}
        if native.get('status') == 'failed':
            raise ValueError(native['error'])
        return {'native': native, 'frames': frames,
                'book': next((f for f in frames if f['is_book']), None),
                'welcome': any(f['welcome_visible'] for f in frames)}

    def wait(self, heading, predicate):
        deadline = min(self.deadline, time.monotonic() + 25)
        while time.monotonic() < deadline:
            try:
                observation = self.observe(heading)
                if observation['native'] and observation['book'] and predicate(observation):
                    return observation
            except (OSError, RuntimeError, json.JSONDecodeError) as exc:
                self.result['last_probe_error'] = str(exc)
            time.sleep(0.3)
        raise RuntimeError(f'Timed out observing live viewer: {heading}')

    def wait_for_paint(self, observation, heading):
        if self.book_client is None or self.book_context is None:
            raise ValueError('No live book frame for post-paint synchronization')
        # RAF callbacks precede presentation: yield twice, then let Qt/X11 consume it.
        self.book_client.evaluate("""new Promise((resolve, reject) => {
          const timer=setTimeout(() => reject(new Error('Paint opportunity timed out')), 2000);
          requestAnimationFrame(() => requestAnimationFrame(() => {
            document.documentElement.getBoundingClientRect();
            clearTimeout(timer); resolve(true);
          }));
        })""", self.book_context, await_promise=True)
        time.sleep(0.6)
        first = self.observe(heading)
        time.sleep(0.15)
        fresh = self.observe(heading)
        for current in (first, fresh):
            book = current['book']
            if (not book or current['welcome'] or not book['is_book'] or book['images_broken']
                    or book['heading'] != heading
                    or book.get('excerpt') != observation['book'].get('excerpt')
                    or current['native'].get('window_id') != observation['native']['window_id']):
                raise ValueError('Expected live content did not remain ready post-paint')
        if (first['book'] != fresh['book']
                or first['native']['capture_rect'] != fresh['native']['capture_rect']):
            raise ValueError('Live content or geometry is unstable post-paint')
        fresh['presentation'] = {'animation_frames': 2, 'qt_x11_settle_seconds': 0.6,
                                 'stable_reobservations': 2, 'stability_interval_seconds': 0.15}
        return fresh

    def capture(self, name, observation):
        observation = self.wait_for_paint(observation, observation['book']['heading'])
        capture_window(self.output, name + '.png', observation['native'], self.scenario['title'])
        write_record(self.output / (name + '.json'), observation)
        self.result['captures'].append(name)
        write_record(self.output / 'result.json', self.result)
        return observation

    def key(self, observation, key):
        subprocess.run(['xdotool', 'windowfocus', '--sync', observation['native']['window_id'],
                        'key', '--clearmodifiers', key], check=True)
        time.sleep(0.4)

    @staticmethod
    def arrived(observation, before, clicked, heading):
        state = dict(observation['book'], clicked=clicked, welcome_visible=observation['welcome'],
                     changed=observation['book']['visible_text'] != before['visible_text'])
        try:
            validate_navigation(state, heading)
            return True
        except ValueError:
            return False

    def toc(self, target, label):
        self.sequence += 1
        write_record(Path.home() / 'toc-request.json', {'sequence': self.sequence, 'target': target})
        ready = self.wait(target, lambda o: o['native'].get('sequence') == self.sequence
                          and o['native']['status'] == 'toc-ready' and not o['welcome'])
        ready = self.capture(label + '-toc', ready)
        x, y = map(str, ready['native']['click'])
        subprocess.run(['xdotool', 'windowfocus', '--sync', ready['native']['window_id'],
                        'mousemove', '--sync', x, y, 'click', '1'], check=True)
        arrived = self.wait(target, lambda o: o['native'].get('sequence') == self.sequence
                            and o['native']['status'] == 'activated'
                            and clean_title(o['native']['clicked_title']) == target
                            and self.arrived(o, ready['book'], True, target))
        self.result['activations'].append({'method': 'native-X11-click', 'target': target,
                                           'native': arrived['native']})
        return arrived

    def link(self, spec, observation, label):
        matches = [a for a in observation['book']['anchors'] if link_matches(a, spec)]
        if len(matches) != 1:
            raise ValueError('Expected one fully visible matching live anchor')
        actual = matches[0]
        expression = """(actual => {
          const matches = Array.from(document.querySelectorAll('a')).filter(e => {
            const r=e.getBoundingClientRect(), style=getComputedStyle(e);
            return e.textContent.trim() === actual.text && e.getAttribute('href') === actual.href &&
              style.visibility !== 'hidden' && style.display !== 'none' &&
              r.width>0 && r.height>0 && r.left>=0 && r.top>=0 &&
              r.right<=innerWidth+1 && r.bottom<=innerHeight+1;
          });
          if(matches.length !== 1) return null;
          const anchor=matches[0];
          const event={text:anchor.textContent.trim(),href:anchor.getAttribute('href'),
                       method:'live-anchor.click'};
          anchor.click(); return event;
        })"""
        assert self.book_client is not None and self.book_context is not None
        event = self.book_client.evaluate(f'({expression})({json.dumps(actual)})', self.book_context)
        if not event:
            raise ValueError('Expected visible rewritten live anchor was not activated')
        event.update(expected_authored_href=spec['href'], expected_destination=spec['destination'])
        self.result['activations'].append(event)
        arrived = self.wait(spec['destination'], lambda o:
                            self.arrived(o, observation['book'], True, spec['destination']))
        arrived = self.capture(label + '-link-destination', arrived)
        event['destination'] = arrived['book']

    def scan(self, step, label):
        observation = self.toc(step['target'], label)
        pages = []
        for page in range(60):
            if time.monotonic() >= self.deadline:
                raise RuntimeError('Scenario execution deadline exceeded')
            if observation['welcome'] or observation['book']['images_broken']:
                raise ValueError('Welcome overlay or unloaded visible image obscures the book')
            observation = self.capture(f'{label}-page-{page:02}', observation)
            pages.append(observation['book'])
            missing = missing_features(pages, step)
            self.result['progress'] = {'step': label, 'missing': missing, 'pages': len(pages)}
            spec = step.get('link')
            if not missing and (not spec or any(link_matches(a, spec)
                                               for a in observation['book']['anchors'])):
                if spec:
                    self.link(spec, observation, label)
                return
            self.key(observation, 'Next')  # X11 keysym for actual PageDown.
            observation = self.wait('', lambda o: not o['welcome'] and not o['book']['images_broken'])
        raise ValueError(f'Incomplete feature coverage after 60 pages: {step}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('epub', type=Path)
    parser.add_argument('sha256')
    parser.add_argument('--scenario', choices=['technical', 'documentation', 'manual', 'ohmyfake'])
    args = parser.parse_args()
    output = Path('/evidence')
    result = {'status': 'failed', 'visual_acceptance': 'pending screenshot analysis',
              'captures': [], 'activations': []}
    viewer = reader = None
    try:
        result['sha256'] = verify_input(args.epub, args.sha256)
        scenario = scenario_for(args.sha256, args.scenario)
        result['scenario'] = scenario
        result['versions'] = collect_versions()
        env = dict(os.environ, QTWEBENGINE_REMOTE_DEBUGGING='127.0.0.1:9222')
        viewer = subprocess.Popen(
            ['calibre-debug', '-e', '/opt/reader/native.py', '--', str(args.epub)], env=env)
        reader = Reader(output, scenario, result)
        def ready_title(observation):
            if observation['welcome'] and not result.get('welcome_key_sent'):
                reader.key(observation, 'space')
                result['welcome_key_sent'] = True
            return not observation['welcome'] and scenario['title'] in observation['book']['excerpt']
        title = reader.wait('', ready_title)
        reader.capture('title-page', title)  # Always before any TOC request.
        for index, step in enumerate(scenario['steps']):
            reader.scan(step, f'step-{index:02}')
        result['status'] = 'scenario-observed'
    except Exception as exc:
        result['error'] = str(exc)
        raise
    finally:
        capture = subprocess.run(['scrot', '--overwrite', str(output / 'reader.png')], check=False)
        result['screenshot_exit'] = capture.returncode
        if capture.returncode:
            result['status'] = 'failed'
        write_record(output / 'result.json', result)
        if reader is not None:
            for client in reader.clients.values():
                client.ws.close()
        if viewer is not None:
            viewer.terminate()
        if result['status'] != 'scenario-observed':
            raise RuntimeError('Reader scenario incomplete; inspect evidence output')


if __name__ == '__main__':
    main()
