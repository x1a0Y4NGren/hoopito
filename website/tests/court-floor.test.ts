import assert from 'node:assert/strict';
import { test } from 'node:test';

test('baked floor illumination retains localized night pools without invalid or negative radiance', async () => {
  const { sampleFloorLighting } = await import('../src/scripts/court-floor.ts');
  const lit = sampleFloorLighting(0, -2);
  const distant = sampleFloorLighting(13, 23);
  assert.ok(lit.dynamic[0] > distant.dynamic[0] * 4);
  assert.ok(lit.dynamic[1] > distant.dynamic[1] * 4);
  for (let x = -14; x <= 14; x += 2) {
    for (let z = -17; z <= 25; z += 2) {
      const sample = sampleFloorLighting(x, z);
      for (const value of [
        ...sample.dynamic,
        ...sample.fixed,
        ...sample.specular,
      ]) {
        assert.ok(Number.isFinite(value) && value >= 0);
      }
    }
  }
});

test('small warm macro lamps still illuminate the floor around the hero basketball', async () => {
  const { sampleFloorLighting } = await import('../src/scripts/court-floor.ts');
  const nearby = sampleFloorLighting(2.6, 4.1).fixed;
  const beyond = sampleFloorLighting(2.6, 8).fixed;
  assert.ok(nearby[0] > nearby[2], 'The localized macro wash stays warm');
  assert.ok(
    nearby[0] > beyond[0],
    'A small ball lamp cannot light the whole arena',
  );
});
