import assert from 'node:assert/strict';
import test from 'node:test';
import { relayPose } from '../src/scripts/story-relay.ts';

const stops = [
  { id: 'hero' as const, readStart: 0, readEnd: 0 },
  { id: 'scoring' as const, readStart: 1000, readEnd: 1200 },
  {
    id: 'experience' as const,
    readStart: 2200,
    readEnd: 2400,
    exitStart: 2600,
    exitEnd: 2800,
  },
];
const anchors = {
  hero: { x: 40, y: 600, length: 64 },
  scoring: { x: 200, y: 500, length: 112 },
  experience: { x: 500, y: 150, length: 96 },
};

test('relay lands exactly at each measured reading anchor and holds over long reading ranges', () => {
  for (const stop of stops)
    for (const y of [stop.readStart, stop.readEnd]) {
      const pose = relayPose(y, stops, anchors);
      assert.equal(pose.chapter, stop.id);
      assert.equal(pose.opacity, 1);
      assert.deepEqual(
        { x: pose.x, y: pose.y, length: pose.length },
        anchors[stop.id],
      );
    }
});

test('relay interpolates without a chapter switch reset and exactly reverses', () => {
  const forward = Array.from({ length: 281 }, (_, i) =>
    relayPose(i * 10, stops, anchors),
  );
  const reverse = Array.from({ length: 281 }, (_, i) =>
    relayPose((280 - i) * 10, stops, anchors),
  );
  assert.deepEqual(reverse.toReversed(), forward);
  const middle = relayPose(485, stops, anchors);
  assert.equal(middle.x, 120);
  assert.equal(middle.y, 550);
  for (const boundary of [1000, 1200, 2200]) {
    const a = relayPose(boundary - 0.001, stops, anchors);
    const b = relayPose(boundary + 0.001, stops, anchors);
    assert.ok(Math.abs(a.x - b.x) < 0.001);
    assert.ok(Math.abs(a.y - b.y) < 0.001);
  }
});

test('relay fades after experience and missing or stale geometry cannot produce an invalid line', () => {
  assert.equal(relayPose(2700, stops, anchors).opacity, 0.5);
  assert.equal(relayPose(2800, stops, anchors).opacity, 0);
  assert.equal(relayPose(9000, stops, anchors).chapter, null);
  assert.equal(relayPose(500, stops, {}).opacity, 0);
  assert.equal(relayPose(NaN, stops, anchors).opacity, 0);
  assert.equal(
    relayPose(500, stops, { ...anchors, scoring: { x: NaN, y: 5, length: 64 } })
      .opacity,
    0,
  );
});

test('a layout remeasurement replaces relay coordinates without retaining the old animation state', () => {
  const resized = { ...anchors, scoring: { x: 80, y: 300, length: 72 } };
  assert.deepEqual(relayPose(1100, stops, resized), {
    ...resized.scoring,
    opacity: 1,
    chapter: 'scoring',
  });
});

test('the orange connection continues through replay, download and community on the camera track', () => {
  const allStops = [
    ...stops,
    { id: 'replay' as const, readStart: 3400, readEnd: 3700 },
    { id: 'download' as const, readStart: 4700, readEnd: 4700 },
    {
      id: 'community' as const,
      readStart: 5700,
      readEnd: 6100,
      exitStart: 6100,
      exitEnd: 6400,
    },
  ];
  const allAnchors = {
    ...anchors,
    replay: { x: 220, y: 140, length: 72 },
    download: { x: 680, y: 300, length: 90 },
    community: { x: 80, y: 600, length: 112 },
  };
  for (let index = 1; index < allStops.length; index += 1) {
    const from = allStops[index - 1]!;
    const to = allStops[index]!;
    const scroll = (from.readEnd + to.readStart) / 2;
    const first = allAnchors[from.id];
    const last = allAnchors[to.id];
    for (const [progress, expected] of [
      [0.12, first],
      [0.85, last],
    ] as const) {
      const pose = relayPose(scroll, allStops, allAnchors, {
        from: from.id,
        to: to.id,
        progress,
      });
      assert.equal(pose.x, expected.x);
      assert.equal(pose.y, expected.y);
      assert.equal(pose.length, expected.length);
      assert.equal(pose.opacity, 1);
    }
    const middle = relayPose(scroll, allStops, allAnchors, {
      from: from.id,
      to: to.id,
      progress: 0.485,
    });
    assert.equal(middle.x, (first.x + last.x) / 2);
    assert.equal(middle.y, (first.y + last.y) / 2);
  }
  assert.deepEqual(relayPose(6000, allStops, allAnchors), {
    ...allAnchors.community,
    opacity: 1,
    chapter: 'community',
  });
  assert.equal(relayPose(6250, allStops, allAnchors).opacity, 0.5);
  assert.equal(relayPose(6400, allStops, allAnchors).opacity, 0);
});

test('an incomplete layout hides the connection instead of retaining coordinates from an old measurement', () => {
  assert.equal(relayPose(0, [], {}).opacity, 0);
  assert.equal(relayPose(0, stops.slice(0, 1), anchors).opacity, 0);
  assert.equal(
    relayPose(1500, stops, {
      hero: anchors.hero,
      experience: anchors.experience,
    }).opacity,
    0,
  );
});

test('a strip opens by at most 96 pixels and closes exactly at both ends even between identical anchors', () => {
  const identical = {
    hero: { x: 40, y: 300, length: 112 },
    scoring: { x: 40, y: 300, length: 112 },
    experience: { x: 40, y: 300, length: 112 },
  };
  const sample = (progress: number) =>
    relayPose(500, stops, identical, {
      from: 'hero',
      to: 'scoring',
      progress,
    });
  assert.equal(sample(0.12).length, 112);
  assert.equal(sample(0.85).length, 112);
  assert.equal(sample(0.485).length, 208);
  const positions = Array.from({ length: 1001 }, (_, index) => index / 1000);
  for (const progress of positions) {
    const pose = sample(progress);
    assert.ok(pose.length >= 112 && pose.length <= 208);
    assert.equal(pose.x, 40);
    assert.equal(pose.y, 300);
  }
  assert.deepEqual(
    positions.map(sample),
    positions.toReversed().map(sample).toReversed(),
  );
});
