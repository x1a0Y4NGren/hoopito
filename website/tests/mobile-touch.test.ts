import assert from 'node:assert/strict';
import test from 'node:test';
import { MobileTouchGesture } from '../src/scripts/mobile-touch-math.ts';

const stops = [
  { id: 'hero' as const, readStart: 0, readEnd: 0 },
  { id: 'scoring' as const, readStart: 700, readEnd: 1000 },
  { id: 'experience' as const, readStart: 1600, readEnd: 1900 },
  { id: 'replay' as const, readStart: 2400, readEnd: 3000 },
  { id: 'download' as const, readStart: 3500, readEnd: 3900 },
  { id: 'community' as const, readStart: 4400, readEnd: 4800 },
  { id: 'closing' as const, readStart: 5300, readEnd: 6000 },
];
function gesture(position = 0) {
  const result = new MobileTouchGesture();
  assert.equal(result.begin(stops, position, { x: 100, y: 300 }, 800), true);
  return result;
}

test('23px returns to the current reading boundary while24px commits exactly one chapter', () => {
  const light = gesture();
  assert.equal(light.move(stops, { x: 100, y: 277 }, 800).kind, 'preview');
  assert.deepEqual(light.finish(stops), {
    kind: 'settle',
    target: 'hero',
    position: 0,
    duration: 0.28,
  });
  const intentional = gesture();
  intentional.move(stops, { x: 100, y: 276 }, 800);
  assert.deepEqual(intentional.finish(stops), {
    kind: 'settle',
    target: 'scoring',
    duration: 1.2,
  });
  assert.deepEqual(intentional.finish(stops), { kind: 'none' });
});

test('tap slop and horizontal gestures never claim chapter navigation', () => {
  const tap = gesture();
  assert.equal(tap.move(stops, { x: 100, y: 292 }, 800).kind, 'pending');
  assert.deepEqual(tap.finish(stops), { kind: 'none' });
  const horizontal = gesture();
  assert.equal(horizontal.move(stops, { x: 125, y: 280 }, 800).kind, 'ignored');
  assert.equal(horizontal.move(stops, { x: 125, y: 200 }, 800).kind, 'ignored');
  assert.deepEqual(horizontal.finish(stops), { kind: 'none' });
  const vertical = gesture();
  assert.equal(vertical.move(stops, { x: 120, y: 275 }, 800).kind, 'preview');
});

test('a very large swipe previews only96px and settles no farther than the adjacent chapter', () => {
  const sample = gesture();
  const preview = sample.move(stops, { x: 100, y: -5000 }, 800);
  assert.deepEqual(preview, { kind: 'preview', source: 'hero', position: 96 });
  assert.deepEqual(sample.finish(stops), {
    kind: 'settle',
    target: 'scoring',
    duration: 1.2,
  });
  const smallGap = stops.map((stop) =>
    stop.id === 'scoring' ? { ...stop, readStart: 100 } : stop,
  );
  const small = gesture();
  assert.equal(small.move(smallGap, { x: 100, y: 100 }, 800).position, 18);
});

test('inside long content the complete gesture stays native even if it reaches a boundary', () => {
  const sample = gesture(800);
  assert.deepEqual(sample.move(stops, { x: 100, y: 260 }, 800), {
    kind: 'native',
    source: 'scoring',
  });
  assert.deepEqual(sample.move(stops, { x: 100, y: -3000 }, 800), {
    kind: 'native',
    source: 'scoring',
  });
  assert.deepEqual(sample.finish(stops), { kind: 'native', source: 'scoring' });
  const nextGesture = gesture(1000);
  nextGesture.move(stops, { x: 100, y: 276 }, 800);
  assert.deepEqual(nextGesture.finish(stops), {
    kind: 'settle',
    target: 'experience',
    duration: 1.2,
  });
});

test('reading back from the bottom stays native and reversing a preview never skips unread content', () => {
  const inward = gesture(1000);
  assert.deepEqual(inward.move(stops, { x: 100, y: 330 }, 800), {
    kind: 'native',
    source: 'scoring',
  });
  const reversed = gesture(1000);
  reversed.move(stops, { x: 100, y: 250 }, 800);
  assert.deepEqual(reversed.move(stops, { x: 100, y: 360 }, 800), {
    kind: 'preview',
    source: 'scoring',
    position: 940,
  });
  assert.deepEqual(reversed.finish(stops), {
    kind: 'settle',
    target: 'scoring',
    position: 940,
    duration: 0.28,
  });
});

test('the same net input restores the same preview independent of reversals', () => {
  const sample = gesture(1600);
  const original = sample.move(stops, { x: 100, y: 340 }, 800);
  sample.move(stops, { x: 100, y: 360 }, 800);
  assert.deepEqual(sample.move(stops, { x: 100, y: 340 }, 800), original);
  assert.deepEqual(sample.finish(stops), {
    kind: 'settle',
    target: 'scoring',
    duration: 1.2,
  });
});

test('layout refresh preserves the held preview and resolves the current destination boundary', () => {
  const sample = gesture(1000);
  sample.move(stops, { x: 100, y: 270 }, 800);
  const resized = stops.map((stop) => ({
    ...stop,
    readStart: stop.readStart + 100,
    readEnd: stop.readEnd + 100,
  }));
  sample.refresh(resized, 1130, 800);
  assert.deepEqual(sample.move(resized, { x: 100, y: 270 }, 800), {
    kind: 'preview',
    source: 'scoring',
    position: 1130,
  });
  assert.deepEqual(sample.finish(resized), {
    kind: 'settle',
    target: 'experience',
    duration: 1.2,
  });
});

test('cancelled touches and browser edge directions never choose a missing chapter', () => {
  const cancelled = gesture();
  cancelled.move(stops, { x: 100, y: 100 }, 800);
  cancelled.cancel();
  assert.deepEqual(cancelled.finish(stops), { kind: 'none' });
  const top = gesture();
  assert.equal(top.move(stops, { x: 100, y: 350 }, 800).kind, 'ignored');
  assert.deepEqual(top.finish(stops), { kind: 'none' });
  const end = gesture(6000);
  assert.equal(end.move(stops, { x: 100, y: 200 }, 800).kind, 'ignored');
});

test('an interrupted transition starts from its actual position and returns to a valid range', () => {
  const sample = gesture(1100);
  const first = sample.move(stops, { x: 100, y: 280 }, 800);
  assert.deepEqual(first, {
    kind: 'preview',
    source: 'scoring',
    position: 1120,
  });
  assert.deepEqual(sample.finish(stops), {
    kind: 'settle',
    target: 'scoring',
    position: 1000,
    duration: 0.28,
  });
  const returning = gesture(1100);
  assert.deepEqual(returning.move(stops, { x: 100, y: 320 }, 800), {
    kind: 'preview',
    source: 'scoring',
    position: 1080,
  });
  assert.deepEqual(returning.finish(stops), {
    kind: 'settle',
    target: 'scoring',
    position: 1000,
    duration: 0.28,
  });
  assert.deepEqual(gesture(1100).finish(stops), {
    kind: 'settle',
    target: 'scoring',
    position: 1000,
    duration: 0.28,
  });
});

test('invalid bounds fail closed instead of producing nonfinite page positions', () => {
  const sample = new MobileTouchGesture();
  assert.equal(sample.begin([], 0, { x: 100, y: 300 }, 800), false);
  assert.equal(sample.begin(stops, NaN, { x: 100, y: 300 }, 800), false);
  assert.deepEqual(sample.move(stops, { x: 0, y: 0 }, 800), {
    kind: 'ignored',
  });
  const live = gesture();
  assert.equal(live.move(stops, { x: Infinity, y: 0 }, 800).kind, 'ignored');
  assert.deepEqual(live.finish(stops), { kind: 'none' });
});
