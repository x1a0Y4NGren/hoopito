import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as THREE from 'three';
import { createCourtHardware } from '../src/scripts/court-hardware.ts';

test('the real hardware cuts away perimeter and rear support while preserving the complete basket and independent ceiling', () => {
  const resources = new Set<{ dispose(): void }>();
  const metalMap = new THREE.Texture();
  const glassMap = new THREE.Texture();
  let externalTextureDisposals = 0;
  metalMap.addEventListener('dispose', () => externalTextureDisposals++);
  glassMap.addEventListener('dispose', () => externalTextureDisposals++);
  const hardware = createCourtHardware({
    own(resource) {
      assert.ok(
        !resources.has(resource),
        'Each owned geometry/material is registered once',
      );
      resources.add(resource);
      return resource;
    },
    metalMap,
    glassMap,
    rim: new THREE.Vector3(0, 3.05, -5.3),
  });
  try {
    assert.equal(typeof hardware.setViewCutaway, 'function');
    const meshes = hardware.group.children as THREE.Mesh<
      THREE.BufferGeometry,
      THREE.Material
    >[];
    const byName = (name: string) => {
      const mesh = meshes.find((value) => value.name === name);
      assert.ok(mesh, `The real ${name} geometry exists`);
      assert.ok(mesh.geometry.getAttribute('position').count > 0);
      return mesh;
    };
    for (const name of [
      'arena-structure',
      'acoustic-panels',
      'arena-guidance-light',
    ])
      assert.equal(byName(name).userData.viewRole, 'perimeter');
    for (const name of [
      'rear-painted-steel',
      'rear-brushed-fasteners',
      'padded-protection',
    ])
      assert.equal(byName(name).userData.viewRole, 'rear-support');
    for (const name of [
      'painted-steel',
      'brushed-fasteners',
      'glass-panel',
      'glass-edge',
      'backboard-target',
      'orange-rim',
      'nylon-net',
    ])
      assert.equal(byName(name).userData.viewRole, 'basket');
    assert.notEqual(
      byName('painted-steel').material,
      byName('rear-painted-steel').material,
    );
    assert.notEqual(
      byName('brushed-fasteners').material,
      byName('rear-brushed-fasteners').material,
    );
    assert.equal(
      (byName('rear-painted-steel').material as THREE.MeshStandardMaterial).map,
      metalMap,
    );
    assert.equal(
      (byName('painted-steel').material as THREE.MeshStandardMaterial).map,
      metalMap,
    );
    const state = (mesh: (typeof meshes)[number]) => ({
      geometry: mesh.geometry,
      material: mesh.material,
      opacity: mesh.material.opacity,
      transparent: mesh.material.transparent,
      depthWrite: mesh.material.depthWrite,
      visible: mesh.visible,
      castShadow: mesh.castShadow,
      receiveShadow: mesh.receiveShadow,
    });
    const initial = new Map(meshes.map((mesh) => [mesh, state(mesh)]));
    const cutaway = meshes.filter((mesh) =>
      ['perimeter', 'rear-support'].includes(mesh.userData.viewRole),
    );
    const basket = meshes.filter((mesh) => mesh.userData.viewRole === 'basket');
    const ceiling = meshes.filter(
      (mesh) => mesh.userData.viewRole === 'ceiling',
    );
    assert.equal(cutaway.length, 6);
    assert.ok(ceiling.length >= 3);
    hardware.setCeilingVisibility(0.25);
    for (const value of [0, 0.25, 0.75, 1, 0.75, 0.25, 0]) {
      hardware.setViewCutaway(value);
      hardware.setNetImpact(value);
      for (const mesh of cutaway) {
        const before = initial.get(mesh)!;
        assert.equal(mesh.material.opacity, before.opacity * (1 - value));
        assert.equal(mesh.visible, value < 1);
        assert.equal(
          mesh.material.transparent,
          value > 0 || before.transparent,
        );
        assert.equal(
          mesh.material.depthWrite,
          value === 0 && before.depthWrite,
        );
        assert.equal(mesh.castShadow, value === 0 && before.castShadow);
        assert.equal(
          mesh.geometry,
          before.geometry,
          'No model rebuild during a cutaway',
        );
      }
      for (const mesh of basket)
        assert.deepEqual(state(mesh), initial.get(mesh));
      for (const mesh of ceiling) {
        assert.equal(mesh.material.opacity, 0.25);
        assert.equal(mesh.visible, true);
      }
    }
    for (const value of [NaN, -1, Infinity]) {
      hardware.setViewCutaway(1);
      hardware.setViewCutaway(value);
      for (const mesh of cutaway)
        assert.deepEqual(state(mesh), initial.get(mesh));
    }
    hardware.setViewCutaway(2);
    for (const mesh of cutaway) assert.equal(mesh.visible, false);
    hardware.setViewCutaway(0);
    hardware.setCeilingVisibility(0);
    for (const mesh of ceiling) assert.equal(mesh.visible, false);
    for (const mesh of basket) assert.deepEqual(state(mesh), initial.get(mesh));
    hardware.setCeilingVisibility(1);
    for (const mesh of meshes) assert.deepEqual(state(mesh), initial.get(mesh));
  } finally {
    for (const resource of resources) resource.dispose();
  }
  assert.equal(
    externalTextureDisposals,
    0,
    'Hardware does not own the shared material textures',
  );
});
