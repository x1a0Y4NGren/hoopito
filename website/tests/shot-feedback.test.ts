import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  SHOT_TIMING,
  shotFrame,
  netPoint,
  netPath,
} from '../src/scripts/shot-timing.ts';

test('one shot reaches the rim, records at1.55 and lets net rebound finish at2.13', () => {
  const point = { x: 0.25, y: 0.65 };
  assert.equal(SHOT_TIMING.flight, 1.2);
  assert.equal(SHOT_TIMING.swish, 0.35);
  assert.equal(SHOT_TIMING.rebound, 0.58);
  assert.deepEqual(
    [shotFrame(0, point).x, shotFrame(0, point).y],
    [164, 355.6],
  );
  assert.equal(shotFrame(1.2, point).phase, 'swish');
  assert.equal(shotFrame(1.2, point).x, 300);
  assert.equal(shotFrame(1.2, point).y, 82);
  assert.equal(shotFrame(1.54, point).recorded, false);
  assert.equal(shotFrame(1.55, point).recorded, true);
  assert.equal(shotFrame(1.55, point).phase, 'rebound');
  assert.equal(shotFrame(1.55, point).visible, false);
  assert.equal(shotFrame(2.13, point).phase, 'rest');
  assert.equal(shotFrame(2.13, point).impact, 0);
});

test('overhead woven net keeps its complete attachment circle fixed', () => {
  assert.deepEqual(netPoint(-16, 0, 1), { x: -16, y: 0 });
  assert.deepEqual(netPoint(16, 0, -0.2), { x: 16, y: 0 });
  assert.deepEqual(netPoint(0, -16, 1), { x: 0, y: -16 });
  assert.deepEqual(netPoint(0, 16, 1), { x: 0, y: 16 });
  const lower = netPoint(7.2, 0, 1);
  assert.ok(lower.x < 7.2 && lower.x > 0);
  assert.equal(lower.y, 0);
  assert.deepEqual(netPoint(7.2, 0, 0), { x: 7.2, y: 0 });
  for (const t of [0, 1.2, 1.4, 1.55, 1.7, 2.13]) {
    const pose = shotFrame(t, { x: 0.5, y: 0.65 });
    assert.ok(Number.isFinite(pose.impact));
  }
});

test('overhead mesh stays inside the rim and returns to its resting weave', () => {
  for (const impact of [0, 0.5, 1, -0.2]) {
    const path = netPath(impact);
    const points = [...path.matchAll(/(?:M|L)(-?[\d.]+) (-?[\d.]+)/g)];
    assert.ok(points.length > 100);
    for (const [, x, y] of points)
      assert.ok(Math.hypot(Number(x), Number(y)) <= 16.01);
  }
  assert.notEqual(netPath(1), netPath(0));
  assert.equal(
    netPath(shotFrame(2.13, { x: 0.5, y: 0.65 }).impact),
    netPath(0),
  );
});

test('swish recedes through the centre instead of falling beneath the top-down hoop', () => {
  const point = { x: 0.25, y: 0.65 };
  let lastScale = shotFrame(1.2, point).scale;
  for (const t of [1.25, 1.3, 1.4, 1.54]) {
    const pose = shotFrame(t, point);
    assert.equal(pose.x, 300);
    assert.equal(pose.y, 82);
    assert.ok(pose.scale < lastScale);
    assert.ok(pose.rotation > shotFrame(1.2, point).rotation);
    lastScale = pose.scale;
  }
});
