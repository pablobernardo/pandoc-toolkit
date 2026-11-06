"""Instrument the actual Calibre Qt UI; never replace its navigation handler."""
import importlib
import json
import sys
from pathlib import Path

# calibre-debug executes this file; explicitly resolve its sibling helper module.
sys.path.insert(0, str(Path(__file__).resolve().parent))
evidence = importlib.import_module('evidence')
clean_title, write_record = evidence.clean_title, evidence.write_record

# calibre-debug supplies Calibre's normal Python environment and Qt bindings.
sys.argv = ['ebook-viewer', sys.argv[-1]]
ui = importlib.import_module('calibre.gui2.viewer.ui')
main = importlib.import_module('calibre.gui2.viewer.main').main
QTimer = importlib.import_module('qt.core').QTimer

window_type = next(cls for cls in vars(ui).values()
                   if isinstance(cls, type) and 'toc_clicked' in cls.__dict__)
original_init = window_type.__init__


def instrument(window, *args, **kwargs):
    original_init(window, *args, **kwargs)
    state = {}

    def publish(**updates):
        state.update(updates)
        rect = window.frameGeometry()
        state.update(window_id=str(int(window.winId())), window_title=window.windowTitle(),
                     capture_rect=[rect.x(), rect.y(), rect.width(), rect.height()])
        write_record(Path('/evidence/native.json'), state)

    def clicked(index):
        item = window.toc_model.itemFromIndex(index)
        publish(status='activated', clicked_title=item.title, node_id=item.node_id, href=item.href)

    def poll():
        try:
            if not window.isVisible() or not getattr(window, 'toc_model', None):
                return
            if not state:
                window.resize(1280, 900)
                window.move(0, 0)
                window.force_focus_on_web_view()
                window.toc.clicked.connect(clicked)
                publish(status='loaded')
            request_path = Path.home() / 'toc-request.json'
            try:
                request = json.loads(request_path.read_text()) if request_path.exists() else None
            except json.JSONDecodeError:
                return  # The controller may be completing its small request write.
            if request and request['sequence'] != state.get('sequence'):
                # ui.py creates this native dock and TOCView; no Web DOM TOC exists.
                window.toc_dock.setVisible(True)
                window.toc.expandAll()
                publish(status='showing-toc', sequence=request['sequence'], target=request['target'])
            elif state['status'] == 'showing-toc':
                matches = [item for item in window.toc_model.all_items
                           if clean_title(item.title) == state['target']]
                if len(matches) != 1:
                    raise RuntimeError(f"Expected one native TOC item: {state['target']}")
                item = matches[0]
                index = window.toc_model.indexFromItem(item)
                window.toc.scrollTo(index)
                rect = window.toc.visualRect(index)
                if not window.toc.isVisible() or not rect.isValid():
                    return
                if not window.toc.viewport().rect().contains(rect.center()):
                    return
                point = window.toc.viewport().mapToGlobal(rect.center())
                publish(status='toc-ready', target_title=item.title, href=item.href,
                        node_id=item.node_id, click=[point.x(), point.y()])
        except Exception as exc:
            publish(status='failed', error=str(exc))
            window._acceptance_timer.stop()

    window._acceptance_timer = QTimer(window)
    window._acceptance_timer.timeout.connect(poll)
    window._acceptance_timer.start(250)


window_type.__init__ = instrument
main()
