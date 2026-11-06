// Executed only in the actual Calibre Qt WebEngine frames, never a replacement browser.
(expected => {
  const all = [];
  function scan(root) {
    for (const e of root.querySelectorAll('*')) {
      all.push(e);
      if (e.shadowRoot) scan(e.shadowRoot);
    }
  }
  scan(document);
  const clean = s => s.trim().replace(/^\d+(?:\.\d+)*[.\s]+/, '');
  const box = r => ({x:r.x, y:r.y, width:r.width, height:r.height});
  const intersects = r => r.width > 0 && r.height > 0 && r.right > 0 &&
    r.bottom > 0 && r.left < innerWidth && r.top < innerHeight;
  const full = r => intersects(r) && r.left >= -1 && r.top >= -1 &&
    r.right <= innerWidth + 1 && r.bottom <= innerHeight + 1;
  const shown = e => getComputedStyle(e).visibility !== 'hidden' &&
    getComputedStyle(e).display !== 'none';
  const rects = e => Array.from(e.getClientRects()).filter(intersects);
  const visible = e => shown(e) && rects(e).length > 0;
  function words(element, prefix) {
    const required = [], seen = [], text = [];
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
    let node, n = 0;
    while ((node = walker.nextNode())) {
      if (!shown(node.parentElement) || /^(SCRIPT|STYLE)$/.test(node.parentElement.tagName)) continue;
      const index = n++;
      for (const match of node.textContent.matchAll(/\S+/gu)) {
        const range = document.createRange();
        range.setStart(node, match.index); range.setEnd(node, match.index + match[0].length);
        Array.from(range.getClientRects()).filter(r => r.width > 0 && r.height > 0).forEach((r, fragment) => {
          const id = `${prefix}:${index}:${match.index}:${fragment}`;
          required.push(id);
          if (full(r)) { seen.push(id); text.push(match[0]); }
        });
      }
    }
    return {required, seen, text};
  }
  const images = all.filter(e => e.tagName === 'IMG').map(e => {
    const r = e.getBoundingClientRect();
    const context = e.closest('td,th') ? 'table' : e.closest('li') ? 'list' : 'paragraph';
    return {src:e.getAttribute('src') || '', complete:e.complete,
      naturalWidth:e.naturalWidth, naturalHeight:e.naturalHeight,
      rect:box(r), full:shown(e) && full(r), visible:visible(e),
      slice:visible(e) && r.left>=-1 && r.right<=innerWidth+1 ?
        [Math.max(0,-r.top)/r.height,Math.min(r.height,innerHeight-r.top)/r.height] : [],
      emoji_context:e.classList.contains('emoji') ? context : ''};
  });
  const tables = all.filter(e => e.tagName === 'TABLE').map(table => {
    const required = [], seen = [], empty = [], overflow = [], cells = [];
    Array.from(table.querySelectorAll('th,td')).forEach((cell, index) => {
      const tokens = words(cell, String(index));
      required.push(...tokens.required); seen.push(...tokens.seen);
      if (!cell.textContent.trim() && !cell.querySelector('img')) empty.push(index);
      const style = getComputedStyle(cell);
      if (visible(cell) && (cell.scrollWidth > cell.clientWidth + 2 ||
          (/hidden|clip/.test(style.overflowY) && cell.scrollHeight > cell.clientHeight + 2))) overflow.push(index);
      cell.querySelectorAll('img').forEach((image, i) => {
        const id = `${index}:image:${i}`; required.push(id);
        if (full(image.getBoundingClientRect()) && image.complete && image.naturalWidth > 0) seen.push(id);
      });
      cells.push({index, text:cell.textContent.trim(), rects:rects(cell).map(box)});
    });
    return {key:Array.from(table.rows[0]?.cells || []).map(e => e.textContent.trim()).join(' | '),
      required, seen, empty, overflow, cells, rects:rects(table).map(box)};
  });
  const headings = all.filter(e => /^H[1-6]$/.test(e.tagName) && visible(e));
  const heading = headings.find(e => clean(e.textContent) === expected);
  const r = heading ? heading.getBoundingClientRect() : {width:0,height:0};
  const text = document.body?.innerText || '';
  const style = getComputedStyle(document.body || document.documentElement);
  return {url:location.href, title:document.title,
    is_book:location.href.startsWith('clbr://internal.sandbox/book/'),
    welcome_visible:text.includes('Press any key to continue'),
    heading:heading ? clean(heading.textContent) : '', width:r.width, height:r.height,
    headings:headings.map(e => ({text:e.textContent.trim(), rect:box(e.getBoundingClientRect())})),
    body_chars:text.length, excerpt:text.slice(0,12000),
    visible_text:document.body ? words(document.body, 'body').text.join(' ') : '',
    emoji_text:headings.filter(e => full(e.getBoundingClientRect())).flatMap(e =>
      Array.from(e.textContent).filter(c => c === '🔍' || c === '🧪')),
    tables, images, images_broken:images.filter(e => e.visible &&
      (!e.complete || !e.naturalWidth || !e.naturalHeight)).length,
    anchors:all.filter(e => e.tagName === 'A' && shown(e) && full(e.getBoundingClientRect()))
      .map(e => ({text:e.textContent.trim(), href:e.getAttribute('href'), rect:box(e.getBoundingClientRect())})),
    viewport:{width:innerWidth,height:innerHeight},
    typography:{font:style.fontFamily,size:style.fontSize,color:style.color,background:style.backgroundColor}};
})
