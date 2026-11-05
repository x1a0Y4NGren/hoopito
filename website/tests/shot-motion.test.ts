import assert from 'node:assert/strict';
import { test } from 'node:test';

const points = [
  { x: 0.06, y: 0.08 },
  { x: 0.5, y: 0.42 },
  { x: 0.94, y: 0.92 },
];

function near(actual: number, expected: number, tolerance = 0.0001) {
  assert.ok(
    Math.abs(actual - expected) < tolerance,
    `Expected ${actual} to be within ${tolerance} of ${expected}`,
  );
}

test('shots launch at the selected world location and reach the rim on a high arc', async () => {
  const { sampleShotPose } = await import('../src/scripts/shot-motion.ts');
  const launch = sampleShotPose({ x: 0, y: 1 }, 0);
  assert.deepEqual(launch.position, [-7.5, 1.2, 7]);
  for (const point of points) {
    const rim = sampleShotPose(point, 1.2);
    assert.deepEqual(rim.position, [0, 3.05, -5.3]);
    const heights = Array.from(
      { length: 120 },
      (_, i) => sampleShotPose(point, i / 100).position[1],
    );
    assert.ok(
      Math.max(...heights) > 4.5,
      'The ball clears the rim on a high arc',
    );
    assert.ok(rim.velocity[1] < -3, 'The shot descends through the hoop');
    assert.ok(
      Math.hypot(rim.velocity[0], rim.velocity[2]) <
        Math.abs(rim.velocity[1]) * 0.1,
      'The rim tangent is near vertical',
    );
  }
});

test('flight and swish share position and velocity without a pause at the rim', async () => {
  const { sampleShotPose } = await import('../src/scripts/shot-motion.ts');
  const epsilon = 0.00001;
  for (const point of points) {
    for (const boundary of [1.2, 1.55]) {
      const before = sampleShotPose(point, boundary - epsilon);
      const at = sampleShotPose(point, boundary);
      const after = sampleShotPose(point, boundary + epsilon);
      for (let axis = 0; axis < 3; axis++) {
        near(before.velocity[axis]!, after.velocity[axis]!, 0.002);
        near(
          (at.position[axis]! - before.position[axis]!) / epsilon,
          at.velocity[axis]!,
          0.002,
        );
        near(
          (after.position[axis]! - at.position[axis]!) / epsilon,
          at.velocity[axis]!,
          0.002,
        );
      }
    }
  }
});

test('the swish keeps moving down inside the basket diameter and keeps spinning', async () => {
  const { sampleShotPose } = await import('../src/scripts/shot-motion.ts');
  for (const point of points) {
    let previous = sampleShotPose(point, 1.2);
    for (let i = 1; i <= 35; i++) {
      const pose = sampleShotPose(point, 1.2 + i / 100);
      assert.ok(pose.position[1] < previous.position[1]);
      assert.ok(Math.hypot(pose.position[0], pose.position[2] + 5.3) < 0.11);
      assert.ok(pose.rotation[0] > previous.rotation[0]);
      previous = pose;
    }
    near(previous.position[1], 2.1);
    const before = sampleShotPose(point, 1.19);
    const rim = sampleShotPose(point, 1.2);
    const after = sampleShotPose(point, 1.21);
    for (let axis = 0; axis < 3; axis++) {
      near(
        rim.rotation[axis]! - before.rotation[axis]!,
        after.rotation[axis]! - rim.rotation[axis]!,
      );
    }
  }
});

test('one elapsed sample owns visibility, recording, trail and net response', async () => {
  const { sampleShotPose } = await import('../src/scripts/shot-motion.ts');
  const point = points[1]!;
  const flight = sampleShotPose(point, 0.6);
  assert.equal(flight.phase, 'flight');
  assert.equal(flight.visible, true);
  assert.equal(flight.recorded, false);
  near(flight.trailProgress, 0.5);
  assert.ok(flight.trailOpacity > 0);
  assert.equal(flight.netImpact, 0);
  const swish = sampleShotPose(point, 1.4);
  assert.equal(swish.phase, 'swish');
  assert.equal(swish.visible, true);
  assert.equal(swish.recorded, false);
  assert.ok(swish.trailOpacity < flight.trailOpacity);
  assert.ok(swish.netImpact > 0);
  const recorded = sampleShotPose(point, 1.55);
  assert.equal(recorded.phase, 'rebound');
  assert.equal(recorded.recorded, true);
  assert.equal(recorded.visible, false);
  assert.equal(recorded.trailOpacity, 0);
  assert.equal(sampleShotPose(point, 2.13).phase, 'rest');
  assert.equal(sampleShotPose(point, 2.13).netImpact, 0);
});

test('the static flight sampler follows the same path as the live ball', async () => {
  const { sampleShotPose, shotFlightPoint } =
    await import('../src/scripts/shot-motion.ts');
  for (const point of points) {
    for (const progress of [0, 0.1, 0.5, 0.8, 1]) {
      const live = sampleShotPose(point, progress * 1.2);
      const trail = shotFlightPoint(point, progress);
      for (let axis = 0; axis < 3; axis++)
        near(trail[axis]!, live.position[axis]!);
    }
  }
});

test('the analytic ground shadow follows the ball and softens as its height increases', async () => {
  const { sampleShotPose } = await import('../src/scripts/shot-motion.ts');
  const low = sampleShotPose(points[1]!, 0);
  const high = sampleShotPose(points[1]!, 0.6);
  for (const pose of [low, high, sampleShotPose(points[1]!, 1.4)]) {
    assert.deepEqual(pose.shadow.center, [
      pose.position[0],
      0.018,
      pose.position[2],
    ]);
    assert.ok(pose.shadow.opacity >= 0 && pose.shadow.opacity <= 1);
  }
  assert.ok(high.shadow.scale[0] > low.shadow.scale[0]);
  assert.ok(high.shadow.scale[1] > low.shadow.scale[1]);
  assert.ok(high.shadow.opacity < low.shadow.opacity);
  assert.equal(sampleShotPose(points[1]!, 1.55).shadow.opacity, 0);
});

test('invalid input cannot poison shot geometry and elapsed values stay in the timeline', async () => {
  const { sampleShotPose, shotFlightPoint } =
    await import('../src/scripts/shot-motion.ts');
  const point = points[1]!;
  for (const elapsed of [NaN, Infinity, -Infinity, -2]) {
    assert.deepEqual(sampleShotPose(point, elapsed), sampleShotPose(point, 0));
  }
  assert.deepEqual(sampleShotPose(point, 100), sampleShotPose(point, 2.13));
  assert.deepEqual(
    sampleShotPose({ x: -10, y: 10 }, 0),
    sampleShotPose({ x: 0, y: 1 }, 0),
  );
  assert.deepEqual(
    sampleShotPose({ x: NaN, y: Infinity }, 0),
    sampleShotPose({ x: 0.5, y: 0.5 }, 0),
  );
  assert.deepEqual(shotFlightPoint(point, -1), shotFlightPoint(point, 0));
  assert.deepEqual(shotFlightPoint(point, 2), shotFlightPoint(point, 1));
  assert.deepEqual(shotFlightPoint(point, NaN), shotFlightPoint(point, 0));
});
