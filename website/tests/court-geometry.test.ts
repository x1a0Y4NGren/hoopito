import assert from 'node:assert/strict';
import { test } from 'node:test';

async function geometry() {
  const module = await import('../src/scripts/court-geometry.ts').catch(
    () => null,
  );
  assert.ok(
    module,
    'The court must expose the App geometry as a shared module',
  );
  return module;
}

const near = (actual: number, expected: number, tolerance = 1e-9) =>
  assert.ok(
    Math.abs(actual - expected) < tolerance,
    `${actual} differs from ${expected}`,
  );

test('normalized locations have one full-court SVG and world mapping', async () => {
  const {
    COURT,
    SVG_COURT,
    courtToSvg,
    courtToWorld,
    RIM_WORLD,
    FREE_THROW_POINT,
  } = await geometry();
  assert.deepEqual(COURT, {
    width: 15,
    depth: 14,
    basketY: 1.575,
    threePointRadius: 6.75,
    cornerOffset: 0.9,
    freeThrowLineY: 5.8,
    freeThrowLineWidth: 3.6,
  });
  assert.deepEqual(SVG_COURT, { left: 28, top: 28, width: 544, height: 504 });
  assert.deepEqual(courtToSvg({ x: 0, y: 0 }), { x: 28, y: 28 });
  assert.deepEqual(courtToSvg({ x: 1, y: 1 }), { x: 572, y: 532 });
  assert.deepEqual(courtToWorld({ x: 0, y: 1 }), [-7.5, 0, 7]);
  assert.deepEqual(courtToWorld({ x: 1, y: 0 }), [7.5, 0, -7]);
  assert.deepEqual(RIM_WORLD, [0, 3.05, -5.425]);
  near(FREE_THROW_POINT.x, 0.5);
  near(FREE_THROW_POINT.y * 14, 5.8);
  near(courtToSvg({ x: 0.5, y: 1.575 / 14 }).y, 84.7);
});

test('the three-point boundary keeps its corners and arc on the inside', async () => {
  const { isOutsideArc, CORNER_JOIN_Y } = await geometry();
  const point = (x: number, y: number) => ({ x: x / 15, y: y / 14 });
  near(CORNER_JOIN_Y, 1.575 + Math.sqrt(6.75 ** 2 - 6.6 ** 2));
  for (const x of [0.9, 14.1]) {
    for (const y of [0, 1.575, CORNER_JOIN_Y]) {
      assert.equal(isOutsideArc(point(x, y)), false);
      assert.equal(isOutsideArc(point(x + (x < 7.5 ? -1e-6 : 1e-6), y)), true);
    }
  }
  assert.equal(isOutsideArc(point(7.5, 1.575 + 6.75)), false);
  assert.equal(isOutsideArc(point(7.5, 1.575 + 6.75 + 1e-6)), true);
  assert.equal(isOutsideArc(point(7.5, 0)), false);
  assert.equal(isOutsideArc(point(0, 14)), true);
  // The upper arc starts at the exact join, rather than a semicircle plus disconnected corners.
  for (const angle of [0.3, 0.6, Math.PI / 2, Math.PI - 0.6, Math.PI - 0.3]) {
    const x = 7.5 + Math.cos(angle) * 6.75;
    const y = 1.575 + Math.sin(angle) * 6.75;
    if (y < CORNER_JOIN_Y) continue;
    assert.equal(isOutsideArc(point(x, y)), false);
    assert.equal(
      isOutsideArc(
        point(
          7.5 + Math.cos(angle) * 6.750001,
          1.575 + Math.sin(angle) * 6.750001,
        ),
      ),
      true,
    );
  }
});

test('only finite points on the complete normalized court are accepted', async () => {
  const { containsCourtPoint } = await geometry();
  for (const point of [
    { x: 0, y: 0 },
    { x: 1, y: 1 },
    { x: 0.001, y: 0.999 },
  ])
    assert.equal(containsCourtPoint(point), true);
  for (const point of [
    { x: -1e-7, y: 0.5 },
    { x: 0.5, y: 1.0000001 },
    { x: NaN, y: 0.5 },
    { x: 0.5, y: Infinity },
  ])
    assert.equal(containsCourtPoint(point), false);
});

test('region light breathes every 1.6 seconds only during active experience reading', async () => {
  const module = await geometry();
  assert.equal(
    typeof module.regionHintPresentation,
    'function',
    'Region motion must respect reading, motion and pause state',
  );
  const hint = module.regionHintPresentation;
  const state = {
    region: 'insideArc' as const,
    pulse: true,
    motionEnabled: true,
    paused: false,
    reading: true,
  };
  near(hint({ ...state, elapsed: 0 }).lightOpacity, 0.08);
  near(hint({ ...state, elapsed: 0.4 }).lightOpacity, 0.12);
  near(hint({ ...state, elapsed: 1.2 }).lightOpacity, 0.04);
  near(hint({ ...state, elapsed: 1.6 }).lightOpacity, 0.08);
  assert.equal(hint({ ...state, elapsed: 0.4 }).pulsing, true);
  for (const changed of [
    { pulse: false },
    { motionEnabled: false },
    { paused: true },
  ]) {
    const staticHint = hint({ ...state, ...changed, elapsed: 0.4 });
    assert.equal(staticHint.pulsing, false);
    near(staticHint.lightOpacity, 0.08);
    assert.equal(staticHint.regionId, 1);
  }
  for (const changed of [{ reading: false }, { region: null }]) {
    const hiddenHint = hint({ ...state, ...changed, elapsed: 0.4 });
    assert.equal(hiddenHint.regionId, 0);
    assert.equal(hiddenHint.pulsing, false);
  }
});
