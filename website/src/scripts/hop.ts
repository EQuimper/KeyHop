import { labelsFor, type Keymap } from '../lib/hints';

// A small web version of Sources/KeyHop/Session.swift, running on this page.
// The status strings match the ones in the app.

type Phase = 'click' | 'start' | 'end' | 'grid';

interface Target {
  el: HTMLElement;
  title: string;
  rect: DOMRect;
}

interface Hint {
  label: string;
  target: number;
}

interface Key {
  key: string;
  shift?: boolean;
}

const layer = document.createElement('div');
layer.className = 'hop-layer';
const pill = document.createElement('div');
pill.className = 'hop-pill';
pill.setAttribute('role', 'status');
pill.hidden = true;
document.body.append(layer, pill);

let keymap: Keymap = 'standard';
let phase: Phase | null = null;
let targets: Target[] = [];
let candidates: number[] = [];
let hints: Hint[] = [];
let filtering = false;
let query = '';
let prefix = '';
let cursor = 0;
let anchor: number | null = null;
let area = new DOMRect();
let messageTimer = 0;
let scriptTimers: number[] = [];

const active = () => phase !== null;
const viewport = () => new DOMRect(0, 0, window.innerWidth, window.innerHeight);

function inView(rect: DOMRect) {
  const x = rect.left + rect.width / 2;
  const y = rect.top + rect.height / 2;
  return rect.width > 2 && rect.height > 2 && x >= 0 && y >= 0 && x <= window.innerWidth && y <= window.innerHeight;
}

function controlName(el: HTMLElement) {
  const name = el.getAttribute('aria-label') ?? el.closest('label')?.innerText ?? el.innerText;
  return name.trim().replace(/\s+/g, ' ');
}

function collectControls(scope: ParentNode): Target[] {
  const selector = 'a[href], button, input';
  return [...scope.querySelectorAll<HTMLElement>(selector)]
    .filter((el) => !el.closest('[hidden], .hop-layer') && el.getClientRects().length > 0)
    .map((el) => ({
      el,
      rect: el.getBoundingClientRect(),
      title: controlName(el),
    }))
    .filter((target) => inView(target.rect));
}

function collectWords(): Target[] {
  return [...document.querySelectorAll<HTMLElement>('.hop-word')]
    .filter((el) => el.getClientRects().length > 0 && !el.closest('[hidden]'))
    .map((el) => ({ el, rect: el.getBoundingClientRect(), title: el.textContent ?? '' }))
    .filter((target) => inView(target.rect));
}

function wrapWords(root: HTMLElement) {
  const walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT);
  const nodes: Text[] = [];
  while (walker.nextNode()) nodes.push(walker.currentNode as Text);
  for (const node of nodes) {
    if (node.parentElement?.closest('kbd')) continue;
    const fragment = document.createDocumentFragment();
    for (const part of (node.textContent ?? '').split(/(\s+)/)) {
      if (!part.trim()) {
        fragment.append(part);
        continue;
      }
      const word = document.createElement('span');
      word.className = 'hop-word';
      word.textContent = part;
      fragment.append(word);
    }
    node.replaceWith(fragment);
  }
}

function clearRange() {
  if ('highlights' in CSS) CSS.highlights.delete('hop-range');
}

function paintRange(from: HTMLElement, to: HTMLElement) {
  if (!('highlights' in CSS)) return;
  const range = rangeBetween(from, to);
  CSS.highlights.set('hop-range', new Highlight(range));
}

function rangeBetween(from: HTMLElement, to: HTMLElement) {
  const forward = from.compareDocumentPosition(to) & Node.DOCUMENT_POSITION_FOLLOWING;
  const range = document.createRange();
  range.setStartBefore(forward ? from : to);
  range.setEndAfter(forward ? to : from);
  return range;
}

function clearScript() {
  scriptTimers.forEach(clearTimeout);
  scriptTimers = [];
}

function stop() {
  clearScript();
  clearTimeout(messageTimer);
  phase = null;
  targets = [];
  hints = [];
  anchor = null;
  layer.replaceChildren();
  pill.hidden = true;
  clearRange();
}

function message(text: string) {
  stop();
  pill.textContent = text;
  pill.hidden = false;
  messageTimer = window.setTimeout(() => {
    pill.hidden = true;
  }, 2600);
}

function refreshMatches() {
  cursor = 0;
  const needle = query.toLocaleLowerCase();
  candidates = targets.flatMap((target, index) =>
    !needle || target.title.toLocaleLowerCase().includes(needle) ? [index] : [],
  );
  const points = candidates.map((index) => {
    const { left, top, width, height } = targets[index].rect;
    return { x: left + width / 2, y: top + height / 2 };
  });
  hints = labelsFor(keymap, points, viewport()).map((label, i) => ({ label, target: candidates[i] }));
  render();
}

function begin(next: 'click' | 'start', scope: ParentNode = document) {
  stop();
  targets = next === 'click' ? collectControls(scope) : collectWords();
  if (targets.length === 0) {
    message(next === 'click' ? 'No controls found' : 'No visible words found');
    return;
  }
  phase = next;
  filtering = next === 'start';
  query = '';
  prefix = '';
  refreshMatches();
}

function placeTags(tags: { el: HTMLElement; rect: DOMRect }[]) {
  const reserved = pill.getBoundingClientRect();
  const occupied = [reserved];
  const hits = (x: number, y: number, w: number, h: number) =>
    occupied.some((box) => x < box.right && x + w > box.left && y < box.bottom && y + h > box.top);

  for (const { el, rect } of tags) {
    const { width: w, height: h } = el.getBoundingClientRect();
    const originX = Math.max(4, Math.min(rect.left, window.innerWidth - w - 4));
    const originY = Math.max(4, Math.min(rect.top - 12, window.innerHeight - h - 4));
    let x = originX;
    let y = originY;
    search: for (let radius = 1; radius < 8 && hits(x, y, w, h); radius += 1) {
      for (const [dx, dy] of [[radius, 0], [-radius, 0], [0, radius], [0, -radius]]) {
        const nextX = originX + dx * (w + 4);
        const nextY = originY + dy * (h + 4);
        if (nextX >= 4 && nextY >= 4 && !hits(nextX, nextY, w, h)) {
          x = nextX;
          y = nextY;
          break search;
        }
      }
    }
    el.style.transform = `translate(${x}px, ${y}px)`;
    occupied.push(new DOMRect(x - 3, y - 3, w + 6, h + 6));
  }
}

function renderGrid() {
  layer.replaceChildren();
  const box = document.createElement('div');
  box.className = 'hop-grid';
  box.style.cssText = `left:${area.left}px;top:${area.top}px;width:${area.width}px;height:${area.height}px`;
  for (let n = 1; n <= 9; n += 1) {
    const cell = document.createElement('span');
    cell.textContent = String(n);
    box.append(cell);
  }
  layer.append(box);
  status('Point · 1–9 zoom · ↵ click · ⇧↵ right-click');
}

function status(text: string) {
  pill.textContent = text;
  pill.hidden = false;
}

function render() {
  if (phase === 'grid') {
    renderGrid();
    return;
  }
  if (!phase) return;
  layer.replaceChildren();
  clearRange();

  const name = phase === 'click' ? 'Click' : phase === 'start' ? 'Start' : 'End';
  const detail = filtering
    ? `${query || 'Type to find'} · ${candidates.length} · Tab labels · ↵`
    : `${prefix ? 'Type the remaining letters' : 'Type a label'} · / find${phase === 'click' ? ' · Space grid' : ''}`;
  status(`${name} · ${detail}${phase === 'click' ? ' · ⇧ right-click' : ''}`);

  if (candidates.length > 0 && (filtering || phase === 'end')) {
    const current = candidates[cursor];
    if (anchor !== null && phase === 'end') {
      paintRange(targets[anchor].el, targets[current].el);
    } else if (phase === 'click') {
      const { left, top, width, height } = targets[current].rect;
      const ring = document.createElement('div');
      ring.className = 'hop-ring';
      ring.style.cssText = `left:${left - 3}px;top:${top - 3}px;width:${width + 6}px;height:${height + 6}px`;
      layer.append(ring);
    } else {
      paintRange(targets[current].el, targets[current].el);
    }
  }

  if (filtering) return;
  const tags = hints
    .filter((hint) => hint.label.startsWith(prefix))
    .map((hint) => {
      const el = document.createElement('button');
      el.type = 'button';
      el.tabIndex = -1;
      el.className = 'hop-tag';
      el.textContent = hint.label.slice(prefix.length);
      el.addEventListener('click', () => choose(hint.target, false));
      layer.append(el);
      return { el, rect: targets[hint.target].rect };
    });
  placeTags(tags);
}

function press(target: Target, right: boolean) {
  stop();
  if (right) {
    message(`Right-click · ${target.title}`);
    return;
  }
  target.el.focus({ preventScroll: true });
  target.el.click();
}

function choose(index: number, right: boolean) {
  const target = targets[index];
  if (phase === 'click') {
    press(target, right);
  } else if (phase === 'start') {
    anchor = index;
    phase = 'end';
    filtering = true;
    query = '';
    prefix = '';
    refreshMatches();
    cursor = candidates.indexOf(index);
    render();
  } else if (phase === 'end' && anchor !== null) {
    const range = rangeBetween(targets[anchor].el, target.el);
    const selection = window.getSelection();
    selection?.removeAllRanges();
    selection?.addRange(range);
    const text = range.toString();
    stop();
    const copied = navigator.clipboard?.writeText(text) ?? Promise.reject();
    copied.then(
      () => message('Copied · Paste with ⌘V'),
      () => message('Selected · Press ⌘C to copy'),
    );
  }
}

function clickPoint(right: boolean) {
  const x = area.left + area.width / 2;
  const y = area.top + area.height / 2;
  stop();
  const el = document.elementFromPoint(x, y)?.closest<HTMLElement>('a[href], button, input');
  const dot = document.createElement('div');
  dot.className = 'hop-dot';
  dot.style.cssText = `left:${x}px;top:${y}px`;
  layer.append(dot);
  window.setTimeout(() => dot.remove(), 500);
  if (el) press({ el, rect: el.getBoundingClientRect(), title: controlName(el) }, right);
  else message(right ? 'Right-click · Nothing here' : 'Click · Nothing here');
}

function handleGrid({ key, shift }: Key) {
  if (key === 'Enter') {
    clickPoint(Boolean(shift));
    return;
  }
  const number = Number(key);
  if (!Number.isInteger(number) || number < 1 || number > 9 || area.width <= 3 || area.height <= 3) return;
  const index = number - 1;
  const width = area.width / 3;
  const height = area.height / 3;
  area = new DOMRect(area.left + (index % 3) * width, area.top + Math.floor(index / 3) * height, width, height);
  render();
}

function handleFilter({ key, shift }: Key) {
  if (key === 'Enter') {
    if (candidates.length > 0) choose(candidates[cursor], Boolean(shift));
  } else if (key === 'ArrowDown' || key === 'ArrowUp') {
    if (candidates.length === 0) return;
    cursor = (cursor + (key === 'ArrowDown' ? 1 : candidates.length - 1)) % candidates.length;
    render();
  } else if (key === 'Backspace') {
    query = query.slice(0, -1);
    refreshMatches();
  } else if (key.length === 1) {
    query += key;
    refreshMatches();
  }
}

function handle(input: Key) {
  const { key, shift } = input;
  if (key === 'Escape') {
    stop();
    return;
  }
  if (phase === 'grid') {
    handleGrid(input);
    return;
  }
  if (key === 'Tab') {
    filtering = !filtering;
    prefix = '';
    render();
    return;
  }
  if (filtering) {
    handleFilter(input);
    return;
  }
  if (key === '/') {
    filtering = true;
    prefix = '';
    render();
  } else if (key === ' ' && phase === 'click') {
    phase = 'grid';
    area = viewport();
    render();
  } else if (key === 'Backspace') {
    prefix = prefix.slice(0, -1);
    render();
  } else if (key.length === 1) {
    const typed = prefix + key.toLowerCase();
    const match = hints.find((hint) => hint.label === typed);
    if (match) {
      choose(match.target, Boolean(shift));
      return;
    }
    prefix = hints.some((hint) => hint.label.startsWith(typed)) ? typed : '';
    render();
  }
}

function schedule(delay: number, run: () => void) {
  scriptTimers.push(window.setTimeout(run, delay));
}

const caps = document.querySelectorAll<HTMLElement>('[data-hop-cap]');
const pressCaps = (down: boolean) => caps.forEach((cap) => cap.classList.toggle('is-down', down));

const interrupt = () => {
  if (active() || scriptTimers.length > 0) stop();
};

addEventListener(
  'keydown',
  (event) => {
    // Real input always ends the intro, so its letters never mix with what someone types.
    if (scriptTimers.length > 0) stop();
    if (event.ctrlKey && !event.metaKey && !event.altKey && event.code === 'KeyJ') {
      event.preventDefault();
      if (!event.repeat) {
        pressCaps(true);
        begin(event.shiftKey ? 'start' : 'click');
      }
      return;
    }
    if (!active() || event.key === 'Shift') return;
    if (event.metaKey || event.ctrlKey || event.altKey) {
      stop();
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    handle({ key: event.key, shift: event.shiftKey });
  },
  true,
);

addEventListener('keyup', () => pressCaps(false));
addEventListener('scroll', interrupt, { passive: true });
addEventListener('resize', interrupt);
addEventListener('blur', interrupt);
addEventListener(
  'pointerdown',
  (event) => {
    if ((event.target as Element).closest('.hop-tag, [data-hop-start]')) clearScript();
    else interrupt();
  },
  true,
);

document.querySelectorAll<HTMLElement>('[data-hop-text]').forEach(wrapWords);
document.querySelectorAll<HTMLElement>('[data-hop-start]').forEach((button) => {
  button.addEventListener('click', () => {
    if (active()) stop();
    else begin('click');
  });
});

export function setKeymap(next: Keymap) {
  keymap = next;
}

// Plays once on load so people see the idea before they try it.
export function intro(scope: HTMLElement, row: HTMLElement) {
  if (matchMedia('(prefers-reduced-motion: reduce)').matches) return;
  schedule(900, () => {
    begin('click', scope);
    const hint = hints.find((item) => targets[item.target]?.el === row);
    if (!hint) {
      stop();
      return;
    }
    [...hint.label].forEach((letter, i) => schedule(1500 + i * 450, () => handle({ key: letter })));
  });
}
