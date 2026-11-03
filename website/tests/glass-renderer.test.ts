import assert from 'node:assert/strict';
import { test } from 'node:test';

test('optics report availability only after drawing and disable themselves on draw failure', async () => {
  const { LiquidGlassPass } =
    await import('../src/scripts/liquid-glass-pass.ts');
  let successful = 0;
  const pass = new LiquidGlassPass(() => successful++);
  const renderer = { setRenderTarget() {}, render() {} };
  const buffer = { texture: {} };
  assert.equal(successful, 0);
  pass.render(renderer as never, buffer as never, buffer as never, 0, false);
  assert.equal(successful, 1);
  renderer.render = () => {
    throw new Error('optical draw rejected');
  };
  assert.throws(
    () =>
      pass.render(
        renderer as never,
        buffer as never,
        buffer as never,
        0,
        false,
      ),
    /optical draw rejected/,
  );
  assert.equal(successful, 1);
  assert.equal(pass.failed, true);
  assert.equal(pass.enabled, false);
  assert.equal(pass.rendering, false);
  pass.dispose();
});

test('optical uniforms stay in CSS pixels across DPR and preserve partially clipped card geometry', async () => {
  const { LiquidGlassPass } =
    await import('../src/scripts/liquid-glass-pass.ts');
  const pass = new LiquidGlassPass(() => {});
  const count = pass.setSurfaces(
    [
      {
        id: 'card',
        region: { left: 80, top: 40, width: 200, height: 140 },
        radius: 24,
        opacity: 0.7,
      },
    ],
    { left: 100, top: 50, width: 800, height: 600 },
  );
  assert.equal(count, 1);
  assert.deepEqual(
    pass.uniforms.uRect.value[0].toArray(),
    [-20, -10, 200, 140],
  );
  assert.deepEqual(pass.uniforms.uFinish.value[0].toArray(), [24, 0.7]);
  pass.setSize(1600, 1200);
  assert.deepEqual(pass.uniforms.uSize.value.toArray(), [800, 600]);
  assert.equal(pass.material.toneMapped, false);
  pass.setSurfaces([], { left: 0, top: 0, width: 800, height: 600 });
  assert.equal(pass.uniforms.uCount.value, 0);
  let disposed = false;
  pass.material.addEventListener('dispose', () => {
    disposed = true;
  });
  pass.dispose();
  assert.equal(disposed, true);
});

test('optical surfaces clip CSS viewport coordinates and reject unsafe input', async () => {
  const { normalizeGlassSurfaces } =
    await import('../src/scripts/glass-surfaces.ts');
  const surface = (id: string, left = 0) => ({
    id,
    region: { left, top: 10, width: 100, height: 80 },
    radius: 100,
    opacity: 2,
  });
  const result = normalizeGlassSurfaces(
    [
      surface('clipped', -40),
      surface('clipped'),
      surface('outside', 400),
      { ...surface('invalid'), radius: NaN },
      {
        ...surface('negative'),
        region: { left: 0, top: 0, width: -5, height: 10 },
      },
      { ...surface('infinite'), opacity: Infinity },
      ...Array.from({ length: 9 }, (_, i) => surface(`card-${i}`)),
    ],
    { left: 0, top: 0, width: 200, height: 100 },
  );
  assert.equal(result.length, 6);
  assert.deepEqual(result[0], {
    id: 'clipped',
    region: { left: 0, top: 10, width: 60, height: 80 },
    radius: 30,
    opacity: 1,
  });
  assert.deepEqual(
    result.slice(1).map((s) => s.id),
    ['card-0', 'card-1', 'card-2', 'card-3', 'card-4'],
  );
  assert.deepEqual(
    normalizeGlassSurfaces([surface('x')], {
      left: 0,
      top: 0,
      width: NaN,
      height: 10,
    }),
    [],
  );
  assert.deepEqual(
    normalizeGlassSurfaces(
      [
        {
          ...surface('huge'),
          region: { left: 0, top: 0, width: 1e100, height: 80 },
        },
      ],
      { left: 0, top: 0, width: 200, height: 100 },
    ),
    [],
  );
});

test('late story chapters continue to render', async () => {
  const { shouldRenderContinuously } =
    await import('../src/scripts/scene-performance.ts');
  for (const chapter of ['download', 'community'] as const) {
    assert.equal(
      shouldRenderContinuously({
        active: true,
        chapter,
        paused: false,
        motionEnabled: true,
        moving: true,
      }),
      true,
    );
  }
});

test('ambient drift stays bounded, retains its phase after suspension and excludes interaction', async () => {
  const { AmbientDrift, shouldAnimateAmbient } =
    await import('../src/scripts/scene-performance.ts');
  const state = {
    active: true,
    chapter: 'replay' as const,
    paused: false,
    motionEnabled: true,
  };
  assert.equal(shouldAnimateAmbient(state), true);
  for (const override of [
    { chapter: 'experience' as const },
    { paused: true },
    { motionEnabled: false },
    { active: false },
  ]) {
    assert.equal(shouldAnimateAmbient({ ...state, ...override }), false);
  }
  const drift = new AmbientDrift();
  let offset = { x: 0, y: 0 };
  for (let now = 0; now <= 3000; now += 40) offset = drift.sample(now, true);
  assert.ok(Math.abs(offset.x) > 1);
  assert.ok(Math.hypot(offset.x, offset.y) <= 2.01);
  drift.sample(3040, false);
  assert.deepEqual(drift.sample(60_000, true), offset);
  for (let now = 60_040; now <= 72_000; now += 40) {
    const next = drift.sample(now, true);
    assert.ok(Math.hypot(next.x, next.y) <= 2.01);
    assert.ok(Math.abs(next.x - offset.x) < 0.1);
    offset = next;
  }
});
