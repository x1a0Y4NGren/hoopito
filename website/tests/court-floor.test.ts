import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as THREE from 'three';

test('the rear stand contact shadow fades with its support and restores without altering the floor', async () => {
  const { createCourtFloor } = await import('../src/scripts/court-floor.ts');
  const resources = new Set<{ dispose(): void }>();
  const floor = createCourtFloor({
    own: (resource) => {
      resources.add(resource);
      return resource;
    },
    mapleMap: new THREE.Texture(),
    rim: new THREE.Vector3(0, 3.05, -5.3),
  });
  try {
    assert.equal(typeof floor.setViewCutaway, 'function');
    const contact = floor.mesh.getObjectByName(
      'cached-basket-base-shadow',
    ) as THREE.Mesh<THREE.PlaneGeometry, THREE.ShaderMaterial>;
    const surface = floor.mesh.material;
    for (const amount of [0, 0.5, 1, 0.5, 0]) {
      floor.setViewCutaway(amount);
      assert.equal(contact.material.uniforms.uBaseShadow!.value, 1 - amount);
      assert.equal(contact.visible, amount < 1);
      assert.equal(floor.mesh.visible, true);
      assert.equal(floor.mesh.material, surface);
    }
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

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
