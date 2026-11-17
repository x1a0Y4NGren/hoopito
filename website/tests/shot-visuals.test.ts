import assert from 'node:assert/strict';
import { test } from 'node:test';

async function visuals() {
  const module = await import('../src/scripts/shot-visuals.ts').catch(
    () => null,
  );
  assert.ok(
    module,
    'Scoring feedback must define an independent visibility policy',
  );
  return module;
}

test('the illuminated trail is a moving 220ms window, including its last segment at the rim', async () => {
  const { trailWindow } = await visuals();
  for (const time of [0.1, 0.3, 0.65, 1.2, 1.4]) {
    const window = trailWindow(time, 1.2);
    const end = Math.min(time, 1.2);
    assert.ok(Math.abs(window.head * 1.2 - end) < 1e-10);
    assert.ok(Math.abs(window.tail * 1.2 - Math.max(0, end - 0.22)) < 1e-10);
    assert.ok(window.head >= window.tail);
  }
  assert.deepEqual(trailWindow(-1, 1.2), { head: 0, tail: 0 });
  assert.deepEqual(trailWindow(NaN, 1.2), { head: 0, tail: 0 });
});

test('feedback widths use CSS pixels independently of distance and device pixel ratio', async () => {
  const { worldUnitsPerPixel, SHOT_VISUALS } = await visuals();
  const near = worldUnitsPerPixel(10, 32, 900);
  const far = worldUnitsPerPixel(20, 32, 900);
  assert.ok(Math.abs(far - near * 2) < 1e-10);
  assert.ok(Math.abs(worldUnitsPerPixel(10, 32, 1800) - near / 2) < 1e-10);
  assert.equal(SHOT_VISUALS.trailCorePixels, 2.5);
  assert.equal(SHOT_VISUALS.trailHaloPixels, 12);
  assert.equal(SHOT_VISUALS.markerStrokePixels, 2);
  for (const inputs of [
    [0, 32, 900],
    [NaN, 32, 0],
    [20, Infinity, 900],
  ])
    assert.ok(
      Number.isFinite(
        worldUnitsPerPixel(...(inputs as [number, number, number])),
      ),
    );
});
