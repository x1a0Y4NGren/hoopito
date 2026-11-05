import assert from 'node:assert/strict';
import test from 'node:test';
import {
  createRailMap,
  liquidMaterial,
  liquidRailPose,
  railPosition,
  railReading,
  railScroll,
} from '../src/scripts/chapter-rail-math.ts';
import type { ChapterStop } from '../src/scripts/chapter-scroll.ts';

const stops: ChapterStop[] = [
  { id: 'hero', readStart: 0, readEnd: 0 },
  { id: 'scoring', readStart: 1981.25, readEnd: 1981.25 },
  { id: 'experience', readStart: 3821.5, readEnd: 3821.5 },
  { id: 'replay', readStart: 5267.75, readEnd: 5630.25 },
  { id: 'download', readStart: 6812.125, readEnd: 7432.625 },
  { id: 'community', readStart: 8579.75, readEnd: 8802.25 },
  { id: 'closing', readStart: 10178.5, readEnd: 11318.5 },
];
const close = (actual: number, expected: number, tolerance = 1e-8) =>
  assert.ok(
    Math.abs(actual - expected) <= tolerance,
    `${actual} differs from ${expected}`,
  );

test('all seven reading anchors retain48px node spacing and the full footer has drag travel', () => {
  const map = createRailMap(stops, 352, 11318.5);
  assert.equal(map.nodes.length, 7);
  assert.equal(map.nodes[0]!.position, 0);
  assert.equal(map.maxScroll, 11318.5);
  for (let i = 0; i < map.nodes.length; i++) {
    const node = map.nodes[i]!;
    assert.equal(node.id, stops[i]!.id);
    assert.equal(node.scroll, stops[i]!.readStart);
    close(railPosition(map, node.scroll), node.position);
    close(railScroll(map, node.position), node.scroll);
    if (i) assert.ok(node.position - map.nodes[i - 1]!.position >= 48);
  }
  assert.ok(map.travel - map.nodes.at(-1)!.position >= 16);
  close(railPosition(map, 11318.5), 352);
  close(railScroll(map, 352), 11318.5);
});

test('mapping is monotone and exactly invertible over fractional scroll and pointer samples', () => {
  for (const travel of [352, 383.25, 432]) {
    const map = createRailMap(stops, travel, 11318.5);
    let lastPosition = -1;
    for (let index = 0; index <= 1536; index++) {
      const y = (map.maxScroll * index) / 1536;
      const position = railPosition(map, y);
      assert.ok(position >= lastPosition);
      close(railScroll(map, position), y);
      lastPosition = position;
      const pointer = (travel * index) / 1536;
      close(railPosition(map, railScroll(map, pointer)), pointer);
    }
  }
});

test('long reading ranges keep fine continuous travel rather than collapsing to a chapter node', () => {
  const map = createRailMap(stops, 384, 11318.5);
  for (const stop of stops.filter((stop) => stop.readEnd > stop.readStart)) {
    const values = [0, 0.25, 0.5, 0.75, 1].map(
      (p) => stop.readStart + (stop.readEnd - stop.readStart) * p,
    );
    let previous = -1;
    for (const y of values) {
      const position = railPosition(map, y);
      assert.ok(position > previous);
      close(railScroll(map, position), y);
      previous = position;
    }
  }
});

test('layout changes replace both sides of the mapping and preserve new anchor endpoints', () => {
  const before = createRailMap(stops, 352, 11318.5);
  const expanded = stops.map((stop, index) => ({
    ...stop,
    readStart: stop.readStart + (index > 4 ? 1800 : 0),
    readEnd: stop.readEnd + (index >= 4 ? 1800 : 0),
  }));
  const after = createRailMap(expanded, 432, 13118.5);
  assert.notEqual(after.nodes[4]!.position, before.nodes[4]!.position);
  for (const node of after.nodes) {
    close(railPosition(after, node.scroll), node.position);
    close(railScroll(after, node.position), node.scroll);
  }
  close(railScroll(after, 432), 13118.5);
  assert.deepEqual(stops[4], {
    id: 'download',
    readStart: 6812.125,
    readEnd: 7432.625,
  });
});

test('coincident endpoints invalid geometry and undersized travel remain finite and bounded', () => {
  const cases = [
    createRailMap([], 352, 0),
    createRailMap(stops, 0, 11318.5),
    createRailMap(stops, NaN, Infinity),
    createRailMap(stops, 12, 7000),
    createRailMap(
      [
        { id: 'hero', readStart: 0, readEnd: 0 },
        { id: 'download', readStart: 800, readEnd: 800 },
        { id: 'community', readStart: 800, readEnd: 900 },
        { id: 'closing', readStart: NaN, readEnd: Infinity },
      ],
      352,
      900,
    ),
  ];
  for (const map of cases) {
    for (const y of [-Infinity, NaN, -100, 0, 800, 100000, Infinity]) {
      const position = railPosition(map, y);
      assert.ok(Number.isFinite(position));
      assert.ok(position >= 0 && position <= map.travel);
      const scroll = railScroll(map, y);
      assert.ok(Number.isFinite(scroll));
      assert.ok(scroll >= 0 && scroll <= map.maxScroll);
    }
  }
  const prefix = createRailMap([stops[1]!], 352, 8000);
  close(railPosition(prefix, 0), 0);
  close(railScroll(prefix, 0), 0);
  close(railPosition(prefix, 8000), 352);
  close(railScroll(prefix, 352), 8000);
});

test('page identity changes at each transition midpoint and never inside long reading ranges', () => {
  for (const [index, stop] of stops.entries()) {
    for (const y of [
      stop.readStart,
      (stop.readStart + stop.readEnd) / 2,
      stop.readEnd,
    ]) {
      const state = railReading(stops, y);
      assert.equal(state.index, index);
      assert.equal(state.segment, index);
      assert.equal(state.progress, 0);
      assert.equal(state.reading, true);
    }
    const next = stops[index + 1];
    if (!next) continue;
    const gap = next.readStart - stop.readEnd;
    for (const p of [0.1, 0.499999, 0.5, 0.9]) {
      const state = railReading(stops, stop.readEnd + gap * p);
      assert.equal(state.index, p < 0.5 ? index : index + 1);
      assert.equal(state.segment, index);
      close(state.progress, p);
      assert.equal(state.reading, false);
    }
  }
});

test('progress is exactly reversible and handles scroll extents without a phantom eighth page', () => {
  const forward = Array.from({ length: 1025 }, (_, i) =>
    railReading(stops, i * 12.5),
  );
  const reverse = Array.from({ length: 1025 }, (_, i) =>
    railReading(stops, (1024 - i) * 12.5),
  );
  assert.deepEqual(reverse.toReversed(), forward);
  assert.equal(railReading(stops, -800).index, 0);
  assert.equal(railReading(stops, 20000).index, 6);
  assert.equal(railReading(stops, 20000).reading, true);
  assert.equal(railReading([], NaN).index, 0);
});

test('fractional native reading receipts still allow long-content keyboard reading', () => {
  for (const [index, stop] of stops.entries()) {
    for (const y of [stop.readStart - 0.5, stop.readEnd + 0.5]) {
      const state = railReading(stops, y);
      assert.equal(state.index, index);
      assert.equal(state.reading, true);
      assert.equal(state.progress, 0);
    }
  }
});

test('liquid uses a round primary and calibrated local SVG material without stretching the logo', () => {
  assert.equal(liquidMaterial.radius, 18);
  assert.equal(liquidMaterial.contactRadius, 7);
  assert.equal(liquidMaterial.contactRange, 48);
  assert.equal(liquidMaterial.blur, 3);
  assert.equal(liquidMaterial.alphaSlope, 19);
  assert.equal(liquidMaterial.alphaBias, -9);
  assert.deepEqual(liquidMaterial.viewBox, {
    x: -28,
    y: -80,
    width: 56,
    height: 160,
  });
  for (const y of [-100, 0, 18, 32, 48, 63, 96, 1000])
    assert.deepEqual(
      liquidRailPose(y, [{ position: 0 }, { position: 96 }]).main,
      {
        x: 0,
        y: 0,
        radius: 18,
      },
    );
});

function contactRadius(position: number) {
  return liquidRailPose(position, [{ position: 0 }]).contacts[0]?.radius ?? 0;
}

test('contact fluid grows inside the main drop before separating and returns smoothly to its node', () => {
  assert.equal(contactRadius(0), 0);
  let previous = 0;
  for (const d of [0.5, 1, 2, 4, 6, 8]) {
    const contact = liquidRailPose(d, [{ position: 0 }]).contacts[0]!;
    assert.ok(contact.radius > previous);
    assert.ok(d + contact.radius < liquidMaterial.radius);
    assert.equal(contact.y, -d);
    assert.equal(contact.node, 0);
    previous = contact.radius;
  }
  for (const d of [8, 14, 20, 26, 32]) assert.equal(contactRadius(d), 7);
  for (const d of [32.5, 34, 38, 42, 46, 47.5]) {
    const radius = contactRadius(d);
    assert.ok(radius < previous && radius > 0);
    previous = radius;
  }
  assert.equal(contactRadius(48), 0);
  assert.equal(contactRadius(64), 0);
  assert.equal(contactRadius(10000), 0);
});

test('both neighboring contact identities survive a midpoint crossing without nearest-node switching', () => {
  const anchors = [{ position: 0 }, { position: 64 }];
  const left = liquidRailPose(32 - 0.0001, anchors);
  const right = liquidRailPose(32 + 0.0001, anchors);
  assert.deepEqual(
    left.contacts.map((contact) => contact.node),
    [0, 1],
  );
  assert.deepEqual(
    right.contacts.map((contact) => contact.node),
    [0, 1],
  );
  for (const [index, before] of left.contacts.entries()) {
    const after = right.contacts[index]!;
    close(before.radius, after.radius, 1e-6);
    close(before.y, after.y, 0.001);
    assert.equal(Math.sign(before.y), Math.sign(after.y));
  }
});

test('liquid field samples reverse exactly and stay inside the local filter with at most three bodies', () => {
  const anchors = [0, 48, 96, 144].map((position) => ({ position }));
  const positions = Array.from({ length: 1281 }, (_, i) => -8 + i / 8);
  const forward = positions.map((position) =>
    liquidRailPose(position, anchors),
  );
  const reverse = positions
    .toReversed()
    .map((position) => liquidRailPose(position, anchors));
  assert.deepEqual(reverse.toReversed(), forward);
  for (const state of forward) {
    assert.ok(state.contacts.length <= 2);
    assert.equal(
      new Set(state.contacts.map(({ node }) => node)).size,
      state.contacts.length,
    );
    for (const contact of state.contacts) {
      assert.ok(Number.isFinite(contact.y) && Number.isFinite(contact.radius));
      assert.ok(
        contact.radius > 0 && contact.radius <= liquidMaterial.contactRadius,
      );
      assert.ok(Math.abs(contact.y) < liquidMaterial.contactRange);
      assert.ok(
        Math.abs(contact.y) + contact.radius + 3 * liquidMaterial.blur < 80,
      );
    }
  }
});

test('liquid contact has no radius jump or abrupt slope at grow and retract boundaries', () => {
  const epsilon = 0.001;
  for (const knot of [0, 8, 32, 48]) {
    const at = contactRadius(knot);
    const left = contactRadius(knot - epsilon);
    const right = contactRadius(knot + epsilon);
    assert.ok(Math.abs(at - left) < 1e-7);
    assert.ok(Math.abs(at - right) < 1e-7);
    assert.ok(Math.abs((right - left) / (2 * epsilon)) < 1e-4);
  }
});

test('contact pose does not acquire velocity or a new animation when long content is read', () => {
  const map = createRailMap(stops, 570, 11318.5);
  const reading = stops[4]!;
  const ys = [0, 0.25, 0.5, 0.75, 1].map(
    (p) => reading.readStart + p * (reading.readEnd - reading.readStart),
  );
  for (const y of ys) {
    const position = railPosition(map, y);
    const pose = liquidRailPose(position, map.nodes);
    assert.deepEqual(
      pose,
      liquidRailPose(railPosition(map, railScroll(map, position)), map.nodes),
    );
    assert.equal(railReading(stops, y).index, 4);
  }
  const stationary = liquidRailPose(
    railPosition(map, reading.readStart),
    map.nodes,
  );
  for (let i = 0; i < 100; i++)
    assert.deepEqual(
      liquidRailPose(railPosition(map, reading.readStart), map.nodes),
      stationary,
    );
});

test('invalid and duplicate anchors cannot create non-finite contacts or repeat liquid masses', () => {
  const nodes = [
    { position: NaN },
    { position: 0 },
    { position: 0 },
    { position: Infinity },
    { position: 64 },
    { position: -Infinity },
  ];
  assert.deepEqual(
    liquidRailPose(24, nodes).contacts.map(({ node }) => node),
    [1, 4],
  );
  for (const position of [NaN, Infinity, -Infinity])
    assert.deepEqual(liquidRailPose(position, nodes).contacts, []);
  assert.deepEqual(liquidRailPose(24, []).contacts, []);
  assert.deepEqual(liquidRailPose(24, nodes, true).contacts, []);
  const packed = liquidRailPose(10, [
    { position: 7 },
    { position: 11 },
    { position: 9 },
    { position: 12 },
    { position: 8 },
  ]);
  assert.deepEqual(
    packed.contacts.map(({ node }) => node),
    [2, 1],
  );
  assert.ok(packed.contacts.length <= 2);
  const moved = [{ position: 96 }, { position: 0 }];
  const before = structuredClone(moved);
  liquidRailPose(24, moved);
  assert.deepEqual(moved, before);
});
