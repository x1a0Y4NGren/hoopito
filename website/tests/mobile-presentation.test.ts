import assert from 'node:assert/strict';
import test from 'node:test';
import {
  mobileBackdropPose,
  mobileItemPose,
  mobileLayerOpacity,
  mobileSceneForChapter,
  mobileScenesToLoad,
} from '../src/scripts/mobile-presentation-math.ts';

const anchors = { court: 900, hoop: 4800, end: 7300 };
const rest = { x: 0, y: 0, scale: 1, opacity: 1, reveal: 1 };

test('stacked backgrounds keep full coverage and the requested mixture throughout crossfades', () => {
  for (let step = 0; step <= 100; step++) {
    const p = step / 100;
    for (const weights of [
      { hero: 1 - p, court: p, hoop: 0 },
      { hero: 0, court: 1 - p, hoop: p },
    ]) {
      const layers = mobileLayerOpacity(weights);
      let remaining = 1;
      for (const id of ['hoop', 'court', 'hero'] as const) {
        assert.ok(Math.abs(layers[id] * remaining - weights[id]) < 1e-10);
        remaining *= 1 - layers[id];
      }
      assert.ok(
        remaining < 1e-10,
        'the transition must not reveal the dark backing',
      );
    }
  }
});

test('the seven chapters share exactly three ordered mobile scenes', () => {
  assert.deepEqual(
    [
      'hero',
      'scoring',
      'experience',
      'replay',
      'download',
      'community',
      'closing',
    ].map(mobileSceneForChapter),
    ['hero', 'court', 'court', 'court', 'hoop', 'hoop', 'hoop'],
  );
  assert.equal(mobileSceneForChapter('missing'), 'hero');
});

test('background transitions use the heading between70and30percent and reverse identically', () => {
  const at = (scroll: number) => mobileBackdropPose(scroll, 1000, anchors);
  assert.deepEqual(at(200).opacity, { hero: 1, court: 0, hoop: 0 });
  assert.deepEqual(at(600).opacity, { hero: 0, court: 1, hoop: 0 });
  assert.equal(at(400).opacity.court, 0.5);
  assert.equal(at(4300).opacity.hoop, 0.5);
  const positions = Array.from({ length: 300 }, (_, i) => i * 30);
  assert.deepEqual(
    positions.map(at),
    positions.toReversed().map(at).toReversed(),
  );
  for (const state of positions.map(at)) {
    assert.ok(
      Object.values(state.opacity).filter((value) => value > 0).length <= 2,
    );
    assert.ok(
      Math.abs(Object.values(state.opacity).reduce((a, b) => a + b, 0) - 1) <
        1e-10,
    );
    for (const y of Object.values(state.y)) assert.ok(Math.abs(y) <= 6);
  }
});

test('reduced motion chooses one finished background without parallax', () => {
  const state = mobileBackdropPose(4300, 1000, anchors, true);
  assert.deepEqual(state.opacity, { hero: 0, court: 0, hoop: 1 });
  assert.deepEqual(state.y, { hero: 0, court: 0, hoop: 0 });
});

test('initial hero loads alone; manual scrolling and direct anchors unlock only needed scenes', () => {
  const start = {
    phone: true,
    scroll: 0,
    height: 900,
    anchors,
    scrolled: false,
  };
  assert.deepEqual(mobileScenesToLoad(start), ['hero']);
  assert.deepEqual(
    mobileScenesToLoad({ ...start, phone: false, hash: '#download' }),
    [],
  );
  assert.deepEqual(mobileScenesToLoad({ ...start, scrolled: true }), [
    'hero',
    'court',
  ]);
  assert.deepEqual(
    mobileScenesToLoad({ ...start, scroll: 3100, scrolled: true }),
    ['hero', 'court', 'hoop'],
  );
  assert.deepEqual(mobileScenesToLoad({ ...start, hash: '#experience' }), [
    'hero',
    'court',
  ]);
  assert.deepEqual(mobileScenesToLoad({ ...start, hash: '#closing' }), [
    'hero',
    'hoop',
  ]);
});

test('individual component entries settle before reading and never fade again above their window', () => {
  const hidden = mobileItemPose(1000, 1000, 'visual');
  assert.equal(hidden.y, 20);
  assert.equal(hidden.scale, 0.99);
  assert.equal(hidden.opacity, 0.45);
  assert.deepEqual(mobileItemPose(680, 1000, 'visual'), rest);
  assert.deepEqual(mobileItemPose(-2000, 1000, 'visual'), rest);
  assert.equal(mobileItemPose(1000, 1000, 'heading').y, 12);
  assert.equal(mobileItemPose(1000, 1000, 'control').y, 12);
  assert.deepEqual(
    mobileItemPose(1000, 1000, 'visual', { reduced: true }),
    rest,
  );
  assert.deepEqual(
    mobileItemPose(1000, 1000, 'visual', { focused: true }),
    rest,
  );
  assert.deepEqual(
    mobileItemPose(1000, 1000, 'visual', { stationary: true }),
    rest,
  );
  assert.deepEqual(
    mobileItemPose(1000, 1000, 'visual', { phone: false }),
    rest,
  );
});

test('invalid layout inputs never yield nonfinite opacity or movement', () => {
  for (const top of [NaN, Infinity, -Infinity]) {
    const pose = mobileItemPose(top, 0, 'detail');
    assert.ok(Object.values(pose).every(Number.isFinite));
  }
  const background = mobileBackdropPose(NaN, 0, {
    court: NaN,
    hoop: Infinity,
    end: -1,
  });
  assert.ok(Object.values(background.opacity).every(Number.isFinite));
  assert.ok(Object.values(background.y).every(Number.isFinite));
});
