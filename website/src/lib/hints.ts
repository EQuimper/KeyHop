// Ported from Sources/KeyHop/Targets.swift and SpatialKeymap.swift.
// The site's demo should label things the way the app does.

export interface Point {
  x: number;
  y: number;
}

export interface Bounds extends Point {
  width: number;
  height: number;
}

export const keymaps = {
  qwerty: 'qwertyuiopasdfghjklzxcvbnm',
  standard: 'fjdkalsghrueiwopqtyzxcvbnm',
  homeRow: 'asdfghjkl',
  custom: 'asdfjkl',
} as const;

export type Keymap = keyof typeof keymaps;

const rows = ['qwertyuiop', 'asdfghjkl', 'zxcvbnm'];

export function labels(count: number, alphabet: string = keymaps.standard): string[] {
  if (count <= 0) return [];
  let width = 1;
  let capacity = alphabet.length;
  while (capacity < count) {
    width += 1;
    capacity *= alphabet.length;
  }
  return Array.from({ length: count }, (_, index) => {
    let value = index;
    let label = '';
    for (let i = 0; i < width; i += 1) {
      label = alphabet[value % alphabet.length] + label;
      value = Math.floor(value / alphabet.length);
    }
    return label;
  });
}

export function spatialLabels(points: Point[], bounds: Bounds): string[] {
  if (bounds.width <= 0 || bounds.height <= 0) return labels(points.length);
  const clamp = (value: number) => Math.min(0.999999, Math.max(0, value));
  const cell = (point: Point) => {
    const row = rows[Math.floor(clamp((point.y - bounds.y) / bounds.height) * 3)];
    return row[Math.floor(clamp((point.x - bounds.x) / bounds.width) * row.length)];
  };

  const buckets = new Map<string, number[]>();
  points.forEach((point, index) => {
    const key = cell(point);
    buckets.set(key, [...(buckets.get(key) ?? []), index]);
  });

  const result: string[] = new Array(points.length).fill('');
  for (const [key, bucket] of buckets) {
    if (bucket.length === 1) {
      result[bucket[0]] = key;
      continue;
    }
    const sorted = [...bucket].sort(
      (a, b) => points[a].y - points[b].y || points[a].x - points[b].x || a - b,
    );
    const suffixes = labels(sorted.length, keymaps.qwerty);
    sorted.forEach((index, i) => {
      result[index] = key + suffixes[i];
    });
  }
  return result;
}

export function labelsFor(keymap: Keymap, points: Point[], bounds: Bounds): string[] {
  return keymap === 'qwerty' ? spatialLabels(points, bounds) : labels(points.length, keymaps[keymap]);
}
