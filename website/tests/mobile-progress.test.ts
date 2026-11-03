import assert from 'node:assert/strict';
import test from 'node:test';
import { mobileProgressState } from '../src/scripts/mobile-progress-math.ts';
import type { ChapterStop } from '../src/scripts/chapter-scroll.ts';

const stops: ChapterStop[] = [
  { id: 'hero', readStart: 0, readEnd: 0 },
  { id: 'scoring', readStart: 800, readEnd: 1100 },
  { id: 'experience', readStart: 1900, readEnd: 2200 },
  { id: 'replay', readStart: 3000, readEnd: 4000 },
  { id: 'download', readStart: 4800, readEnd: 5100 },
  { id: 'community', readStart: 5900, readEnd: 6200 },
  { id: 'closing', readStart: 7000, readEnd: 7500 },
];

test('phone progress covers the entire document while chapter identity holds through long reading', () => {
  assert.equal(mobileProgressState(stops, 0, 8300, 800).progress, 0);
  assert.equal(mobileProgressState(stops, 7500, 8300, 800).progress, 1);
  for (const y of [3000, 3200, 3700, 4000]) {
    const state = mobileProgressState(stops, y, 8300, 800);
    assert.equal(state.id, 'replay');
    assert.equal(state.index, 3);
    assert.equal(state.total, 7);
    assert.equal(state.progress, y / 7500);
  }
});

test('page number changes at the midpoint between adjacent reading ranges and reverses exactly', () => {
  assert.equal(mobileProgressState(stops, 1499, 8300, 800).id, 'scoring');
  assert.equal(mobileProgressState(stops, 1500, 8300, 800).id, 'experience');
  const positions = Array.from({ length: 251 }, (_, i) => i * 30);
  assert.deepEqual(
    positions.map((y) => mobileProgressState(stops, y, 8300, 800)),
    positions
      .toReversed()
      .map((y) => mobileProgressState(stops, y, 8300, 800))
      .toReversed(),
  );
});

test('progress clamps browser overscroll and remains finite for an unscrollable or invalid viewport', () => {
  assert.equal(mobileProgressState(stops, -100, 8300, 800).progress, 0);
  assert.equal(mobileProgressState(stops, 10000, 8300, 800).progress, 1);
  for (const values of [
    [0, 800, 800],
    [20, 500, 800],
    [NaN, NaN, NaN],
    [Infinity, Infinity, 0],
  ]) {
    const state = mobileProgressState(stops, values[0], values[1], values[2]);
    assert.ok(Number.isFinite(state.progress));
    assert.ok(state.progress >= 0 && state.progress <= 1);
  }
});

test('layout changes recalculate the true fraction without inventing another animation clock', () => {
  const before = mobileProgressState(stops, 3750, 8300, 800);
  const after = mobileProgressState(stops, 3750, 9300, 800);
  assert.equal(before.id, after.id);
  assert.equal(before.progress, 0.5);
  assert.equal(after.progress, 3750 / 8500);
  assert.equal(mobileProgressState([], 100, 800, 800).id, undefined);
});
