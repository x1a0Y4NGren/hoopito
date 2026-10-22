import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  SHOT_TIMING,
  shotFrame,
  netPoint,
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

test('woven net anchors never move while the lower cords expand and drop', () => {
  assert.deepEqual(netPoint(-16, 0, 1), { x: -16, y: 0 });
  assert.deepEqual(netPoint(16, 0, -0.2), { x: 16, y: 0 });
  const lower = netPoint(9, 40, 1);
  assert.ok(lower.x > 9 && lower.y > 40);
  assert.deepEqual(netPoint(9, 40, 0), { x: 9, y: 40 });
  for (const t of [0, 1.2, 1.4, 1.55, 1.7, 2.13]) {
    const pose = shotFrame(t, { x: 0.5, y: 0.65 });
    assert.ok(Number.isFinite(pose.impact));
  }
});
