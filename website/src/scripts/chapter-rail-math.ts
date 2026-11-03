import type { ChapterStop, StopId } from './chapter-scroll.ts';

export interface RailMapping {
  nodes: { id: StopId; scroll: number; position: number }[];
  maxScroll: number;
  /** Available center-to-center travel, excluding the rail's outer padding. */
  travel: number;
}

const dimension = (value: number) =>
  Number.isFinite(value) ? Math.max(0, value) : 0;
const bounded = (value: number, maximum: number) =>
  Number.isNaN(value) ? 0 : Math.max(0, Math.min(maximum, value));

function measuredStops(stops: readonly ChapterStop[]) {
  const ids = new Set<StopId>();
  return stops
    .map((stop, index) => ({ stop, index }))
    .filter(({ stop }) => {
      if (
        ids.has(stop.id) ||
        !Number.isFinite(stop.readStart) ||
        !Number.isFinite(stop.readEnd) ||
        stop.readEnd < stop.readStart
      )
        return false;
      ids.add(stop.id);
      return true;
    })
    .sort((a, b) => a.stop.readStart - b.stop.readStart);
}

/** Allocate readable node spacing without flattening long document ranges.
 * Coincident scroll anchors share a position: inventing distinct coordinates
 * would make the pointer inverse discontinuous. The view can fall back to its
 * native scrollbar when those measured nodes cannot be independently targeted.
 */
export function createRailMap(
  stops: readonly ChapterStop[],
  travel: number,
  maxScroll: number,
): RailMapping {
  const span = dimension(travel),
    maximum = dimension(maxScroll);
  const nodes = measuredStops(stops).map(({ stop }) => ({
    id: stop.id,
    scroll: bounded(stop.readStart, maximum),
    position: 0,
  }));
  if (!nodes.length || !maximum || !span)
    return { nodes, maxScroll: maximum, travel: span };

  const nodeScrolls = new Set(nodes.map((node) => node.scroll));
  const anchors = [...new Set([0, ...nodeScrolls, maximum])].sort(
    (a, b) => a - b,
  );
  const minimums = anchors
    .slice(1)
    .map((to, index) =>
      nodeScrolls.has(anchors[index]!) && nodeScrolls.has(to) ? 48 : 16,
    );
  const required = minimums.reduce((sum, value) => sum + value, 0);
  const baseScale = Math.min(1, span / required);
  const remaining = Math.max(0, span - required);
  const positions = new Map<number, number>([[0, 0]]);
  let position = 0;
  for (let index = 1; index < anchors.length; index++) {
    const from = anchors[index - 1]!,
      to = anchors[index]!;
    position +=
      minimums[index - 1]! * baseScale + remaining * ((to - from) / maximum);
    positions.set(to, index === anchors.length - 1 ? span : position);
  }
  for (const node of nodes) node.position = positions.get(node.scroll)!;
  return { nodes, maxScroll: maximum, travel: span };
}

function mapValue(map: RailMapping, value: number, inverse: boolean) {
  if (!map.maxScroll || !map.travel) return 0;
  const inputMaximum = inverse ? map.travel : map.maxScroll;
  const outputMaximum = inverse ? map.maxScroll : map.travel;
  const input = bounded(value, inputMaximum);
  if (input === 0) return 0;
  if (input === inputMaximum) return outputMaximum;
  const anchors = [
    { scroll: 0, position: 0 },
    ...map.nodes.filter(
      (node) => node.scroll > 0 && node.scroll < map.maxScroll,
    ),
    { scroll: map.maxScroll, position: map.travel },
  ];
  let previous = anchors[0]!;
  for (const next of anchors.slice(1)) {
    const start = inverse ? previous.position : previous.scroll;
    const end = inverse ? next.position : next.scroll;
    if (input <= end && end > start) {
      const from = inverse ? previous.scroll : previous.position;
      const to = inverse ? next.scroll : next.position;
      return from + ((input - start) / (end - start)) * (to - from);
    }
    previous = next;
  }
  return outputMaximum;
}

export function railPosition(map: RailMapping, y: number): number {
  return mapValue(map, y, false);
}

export function railScroll(map: RailMapping, position: number): number {
  return mapValue(map, position, true);
}

/** Reading has a stable identity; only inter-chapter gaps change the page number.
 * Segment/progress always describe forward document order, so reverse scrolling
 * returns exactly the same pose. In every reading range segment=index and
 * progress=0; consumers do not look up an outgoing target while reading=true.
 */
export function railReading(
  stops: readonly ChapterStop[],
  y: number,
): { index: number; segment: number; progress: number; reading: boolean } {
  const measured = measuredStops(stops);
  if (!measured.length)
    return { index: 0, segment: 0, progress: 0, reading: true };
  const position = Number.isNaN(y) ? 0 : y;
  // Native scroll quantization can acknowledge a fractional reading boundary
  // just below its CSS coordinate, especially in Firefox and WebKit.
  const resting = measured.find(
    ({ stop }) =>
      position >= stop.readStart - 2 && position <= stop.readEnd + 2,
  );
  if (resting)
    return {
      index: resting.index,
      segment: resting.index,
      progress: 0,
      reading: true,
    };
  let current = 0;
  for (let index = 1; index < measured.length; index++)
    if (position >= measured[index]!.stop.readStart) current = index;
  const source = measured[current]!,
    target = measured[current + 1];
  if (!target)
    return {
      index: source.index,
      segment: source.index,
      progress: 0,
      reading: true,
    };
  if (position <= source.stop.readEnd)
    return {
      index: source.index,
      segment: source.index,
      progress: 0,
      reading: true,
    };
  const gap = target.stop.readStart - source.stop.readEnd;
  const progress =
    gap > 0 ? bounded((position - source.stop.readEnd) / gap, 1) : 1;
  return {
    index: progress < 0.5 ? source.index : target.index,
    segment: source.index,
    progress,
    reading: false,
  };
}

/** One local alpha field. The sharp logo and rail are outside this material. */
export const liquidMaterial = Object.freeze({
  radius: 18,
  contactRadius: 7,
  contactRange: 48,
  blur: 3,
  alphaSlope: 19,
  alphaBias: -9,
  viewBox: Object.freeze({ x: -28, y: -80, width: 56, height: 160 }),
});

export interface LiquidRailPose {
  main: { x: number; y: number; radius: number };
  contacts: { node: number; y: number; radius: number }[];
}

const smootherstep = (value: number) => {
  const p = bounded(value, 1);
  return p * p * p * (p * (p * 6 - 15) + 10);
};

/** Absolute rail distance determines the fluid masses, never elapsed time,
 * last input direction or whichever anchor happens to be nearest this frame.
 * The contact grows inside the primary, stays anchored while their alpha
 * fields separate, then shrinks back into the node with zero endpoint slope.
 */
export function liquidRailPose(
  position: number,
  nodes: readonly { position: number }[],
  reduced = false,
): LiquidRailPose {
  const main = { x: 0, y: 0, radius: liquidMaterial.radius };
  if (reduced || !Number.isFinite(position)) return { main, contacts: [] };

  const positions = new Set<number>();
  const anchors = nodes
    .map((node, index) => ({ position: node.position, node: index }))
    .filter((anchor) => {
      if (!Number.isFinite(anchor.position) || positions.has(anchor.position))
        return false;
      positions.add(anchor.position);
      return true;
    })
    .sort((a, b) => a.position - b.position);
  let previous: (typeof anchors)[number] | undefined;
  let next: (typeof anchors)[number] | undefined;
  for (const anchor of anchors) {
    if (anchor.position <= position) previous = anchor;
    else {
      next = anchor;
      break;
    }
  }

  const contacts: LiquidRailPose['contacts'] = [];
  for (const anchor of [previous, next]) {
    if (!anchor) continue;
    const y = anchor.position - position;
    const distance = Math.abs(y);
    if (!(distance > 0 && distance < liquidMaterial.contactRange)) continue;
    const radius =
      liquidMaterial.contactRadius *
      smootherstep(distance / 8) *
      (1 - smootherstep((distance - 32) / 16));
    if (radius > 0) contacts.push({ node: anchor.node, y, radius });
  }
  return { main, contacts };
}
