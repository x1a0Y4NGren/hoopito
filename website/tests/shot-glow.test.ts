import assert from 'node:assert/strict';
import test from 'node:test';
import * as THREE from 'three';
import {
  createShotTrail,
  createShotMarker,
  createFlightBallGlow,
} from '../src/scripts/shot-glow.ts';
import { SHOT_VISUALS, trailWindow } from '../src/scripts/shot-visuals.ts';
import { shotFlightPoint } from '../src/scripts/shot-motion.ts';

const camera = new THREE.PerspectiveCamera(32, 1.5, 0.015, 100);
camera.position.set(0, 18, 15);
camera.lookAt(0, 0, 0);
camera.updateMatrixWorld();

test('all quality tiers retain a time-bounded trail and CSS-pixel core at every render density', () => {
  const point = { x: 0.72, y: 0.65 };
  const trail = createShotTrail(point);
  try {
    for (const quality of ['full', 'effects', 'density'] as const) {
      trail.setQuality(quality);
      for (const pixelRatio of [0.75, 1, 2]) {
        trail.updateView(camera, 1200, 800, pixelRatio);
        trail.setTime(0.6, 0.8);
        assert.equal(trail.visible, true);
        assert.equal(trail.core.visible, true);
        assert.equal(
          trail.core.material.uniforms.uWidthPixels!.value,
          SHOT_VISUALS.trailCorePixels,
        );
        assert.deepEqual(
          trail.core.material.uniforms.uViewport!.value.toArray(),
          [1200, 800],
        );
        const window = trailWindow(0.6, 1.2);
        assert.equal(trail.core.material.uniforms.uTail!.value, window.tail);
        assert.equal(trail.core.material.uniforms.uHead!.value, window.head);
        const positions = trail.core.geometry.getAttribute('position');
        const progress = trail.core.geometry.getAttribute('uv');
        for (const index of [0, positions.count - 1]) {
          const expected = shotFlightPoint(point, progress.getX(index));
          for (let axis = 0; axis < 3; axis++)
            assert.ok(
              Math.abs(positions.getComponent(index, axis) - expected[axis]!) <
                0.00001,
            );
        }
      }
    }
    trail.setTime(1.4, 0.3);
    assert.equal(trail.core.material.uniforms.uHead!.value, 1);
    assert.ok(trail.core.material.uniforms.uTail!.value > 0.8);
    trail.setTime(1.55, 0);
    assert.equal(trail.visible, false);
  } finally {
    trail.dispose();
  }
});

test('marker contrast and flight outline survive low quality and dispose their private resources once', () => {
  const marker = createShotMarker('#FF5A1F');
  const body = new THREE.Mesh(
    new THREE.SphereGeometry(0.12),
    new THREE.MeshStandardMaterial(),
  );
  const glow = createFlightBallGlow(body);
  const counts = new Map<THREE.Material | THREE.BufferGeometry, number>();
  for (const group of [marker, glow]) {
    group.traverse((object) => {
      if (!(object instanceof THREE.Mesh)) return;
      for (const resource of [object.geometry, object.material]) {
        if (resource === body.geometry || counts.has(resource)) continue;
        counts.set(resource, 0);
        resource.addEventListener('dispose', () =>
          counts.set(resource, counts.get(resource)! + 1),
        );
      }
    });
  }
  try {
    for (const quality of ['full', 'effects', 'density'] as const) {
      marker.setQuality(quality);
      glow.setQuality(quality);
      marker.updateView(camera, 1200, 800, 0.75);
      glow.updateView(camera, 1200, 800, 0.75);
      assert.equal(marker.core.material.toneMapped, false);
      assert.equal(marker.core.material.uniforms.uStrokePixels!.value, 2);
      assert.equal(marker.core.material.uniforms.uPixelRatio!.value, 0.75);
      assert.equal(glow.outline.visible, true);
      assert.equal(glow.outline.material.toneMapped, false);
      assert.ok(marker.core.material.uniforms.uHaloOpacity!.value > 0);
    }
    marker.dispose();
    marker.dispose();
    glow.dispose();
    glow.dispose();
    assert.ok([...counts.values()].every((count) => count === 1));
  } finally {
    marker.dispose();
    glow.dispose();
    body.geometry.dispose();
    body.material.dispose();
  }
});

test('quality changes and cancellation release every trail geometry once', () => {
  const trail = createShotTrail({ x: 0.72, y: 0.65 });
  const counts = new Map<THREE.BufferGeometry | THREE.Material, number>();
  const track = (resource: THREE.BufferGeometry | THREE.Material) => {
    if (counts.has(resource)) return;
    counts.set(resource, 0);
    resource.addEventListener('dispose', () =>
      counts.set(resource, counts.get(resource)! + 1),
    );
  };
  track(trail.core.material);
  track(trail.halo.material);
  for (const quality of ['full', 'effects', 'density', 'full'] as const) {
    track(trail.core.geometry);
    trail.setQuality(quality);
    trail.setTime(0.6, 0.8);
  }
  track(trail.core.geometry);
  trail.dispose();
  trail.dispose();
  assert.ok([...counts.values()].every((count) => count === 1));
  assert.equal(trail.parent, null);
});
