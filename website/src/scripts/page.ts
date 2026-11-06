import { labelsFor, type Keymap } from '../lib/hints';
import { intro, setKeymap } from './hop';

// Inbox window

const inbox = document.querySelector<HTMLElement>('[data-inbox]');

if (inbox) {
  const rows = [...inbox.querySelectorAll<HTMLButtonElement>('[data-row]')];
  const articles = [...inbox.querySelectorAll<HTMLElement>('[data-article]')];
  const folders = [...inbox.querySelectorAll<HTMLButtonElement>('[data-folder]')];
  const empty = inbox.querySelector<HTMLElement>('[data-empty]')!;
  const reply = inbox.querySelector<HTMLInputElement>('[data-reply]')!;
  let folder = 'inbox';
  let open: string | null = rows[0]?.dataset.row ?? null;

  const visible = (row: HTMLButtonElement) =>
    folder === 'flagged'
      ? row.dataset.flagged === 'true'
      : (row.dataset.location ?? 'inbox') === folder;

  const update = () => {
    const shown = rows.filter(visible);
    if (!shown.some((row) => row.dataset.row === open)) open = shown[0]?.dataset.row ?? null;
    rows.forEach((row) => {
      row.hidden = !visible(row);
      row.setAttribute('aria-current', String(row.dataset.row === open));
    });
    articles.forEach((article) => {
      article.hidden = article.dataset.article !== open;
    });
    folders.forEach((button) => {
      const name = button.dataset.folder;
      button.setAttribute('aria-current', String(name === folder));
      const count = button.querySelector('[data-count]');
      if (count) count.textContent = String(rows.filter((row) => (row.dataset.location ?? 'inbox') === name).length);
    });
    empty.hidden = open !== null;
    reply.hidden = open === null;
  };

  const current = () => rows.find((row) => row.dataset.row === open);

  rows.forEach((row) =>
    row.addEventListener('click', () => {
      open = row.dataset.row ?? null;
      update();
    }),
  );
  folders.forEach((button) =>
    button.addEventListener('click', () => {
      folder = button.dataset.folder ?? 'inbox';
      update();
    }),
  );
  inbox.querySelector('[data-action="flag"]')?.addEventListener('click', () => {
    const row = current();
    if (row) row.dataset.flagged = String(row.dataset.flagged !== 'true');
    update();
  });
  inbox.querySelector('[data-action="archive"]')?.addEventListener('click', () => {
    const row = current();
    if (row) row.dataset.location = row.dataset.location === 'archive' ? 'inbox' : 'archive';
    update();
  });
  inbox.querySelector('[data-action="reply"]')?.addEventListener('click', () => reply.focus());

  update();
  if (rows[1]) intro(inbox, rows[1]);
}

// Copy buttons

document.querySelectorAll<HTMLButtonElement>('[data-copy]').forEach((button) => {
  const idle = button.textContent;
  button.addEventListener('click', async () => {
    try {
      await navigator.clipboard.writeText(button.dataset.copy ?? '');
      button.textContent = 'Copied';
      window.setTimeout(() => {
        button.textContent = idle;
      }, 1600);
    } catch {
      const command = button.parentElement?.querySelector('code');
      if (command) window.getSelection()?.selectAllChildren(command);
      button.textContent = 'Press ⌘C';
    }
  });
});

// Keymap picker

const board = document.querySelector<HTMLElement>('[data-keymap-board]');

if (board) {
  const spots = [...board.querySelectorAll<HTMLElement>('[data-spot]')];
  const notes = [...document.querySelectorAll<HTMLElement>('[data-keymap-note]')];
  const points = spots.map((spot) => ({ x: Number(spot.dataset.x), y: Number(spot.dataset.y) }));
  const bounds = { x: 0, y: 0, width: 100, height: 100 };

  const apply = (next: Keymap) => {
    setKeymap(next);
    const text = labelsFor(next, points, bounds);
    spots.forEach((spot, i) => {
      spot.textContent = text[i];
    });
    notes.forEach((note) => {
      note.hidden = note.dataset.keymapNote !== next;
    });
  };

  document.querySelectorAll<HTMLInputElement>('input[name="keymap"]').forEach((input) => {
    input.addEventListener('change', () => apply(input.value as Keymap));
  });
  apply('standard');
}
