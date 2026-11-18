import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as THREE from 'three';
import { createCourtHardware } from '../src/scripts/court-hardware.ts';

const rim = new THREE.Vector3(0, 3.05, -5.425);

function useHardware(t: { after(callback: () => void): void }) {
  const metalMap = new THREE.Texture();
  const glassMap = new THREE.Texture();
  const resources = [metalMap, glassMap] as { dispose(): void }[];
  t.after(() => resources.forEach((resource) => resource.dispose()));
  return createCourtHardware({
    rim,
    metalMap,
    glassMap,
    own(resource) {
      resources.push(resource);
      return resource;
    },
  });
}

test('the stand leans toward the board above the protective pad', (t) => {
  const { group } = useHardware(t);
  const steel = group.getObjectByName('rear-painted-steel')!;
  const ray = new THREE.Raycaster();
  const frontAt = (y: number) => {
    ray.set(new THREE.Vector3(0, y, rim.z), new THREE.Vector3(0, 0, -1));
    const hit = ray.intersectObject(steel, false)[0];
    assert.ok(hit, `The cantilever is continuous at y=${y}`);
    return hit.point.z;
  };

  assert.ok(frontAt(2.9) - frontAt(1.98) > 0.08);
  assert.ok(frontAt(rim.y + 0.525) < rim.z - 0.49);
});

test('the plinth steps inward inside its original floor contact footprint', (t) => {
  const { group } = useHardware(t);
  const surfaces = ['rear-painted-steel', 'rear-brushed-fasteners'].map(
    (name) => group.getObjectByName(name)!,
  );
  const ray = new THREE.Raycaster();
  const frontAt = (y: number) => {
    ray.set(new THREE.Vector3(0.35, y, rim.z), new THREE.Vector3(0, 0, -1));
    const hit = ray.intersectObjects(surfaces, false)[0];
    assert.ok(hit, `The plinth has a front face at y=${y}`);
    return hit.point.z;
  };

  const floorEdge = frontAt(0.035);
  const trimEdge = frontAt(0.085);
  const shoulderEdge = frontAt(0.16);
  assert.ok(Math.abs(floorEdge - (rim.z - 1.475)) < 0.005);
  assert.ok(floorEdge - trimEdge > 0.02);
  assert.ok(trimEdge - shoulderEdge > 0.02);
});

test('the near net has two continuous cords around its hem', (t) => {
  const { group } = useHardware(t);
  const net = group.getObjectByName(
    'nylon-net',
  ) as THREE.Mesh<THREE.BufferGeometry>;
  const { geometry } = net;
  const index = geometry.index;
  assert.ok(index);
  const positions = geometry.getAttribute('position');
  const point = new THREE.Vector3();
  const bounds = new THREE.Box3();
  const hemY = rim.y - 0.033 - 0.53;
  const isHem = () =>
    bounds.max.x - bounds.min.x > 0.25 &&
    bounds.max.z - bounds.min.z > 0.25 &&
    bounds.min.y > hemY - 0.008 &&
    bounds.max.y < hemY + 0.008;
  let rings = 0;
  let highest = -1;
  // Each merged indexed construction part starts with a new vertex range.
  for (let face = 0; face < index.count; face += 3) {
    const vertices = [
      index.getX(face),
      index.getX(face + 1),
      index.getX(face + 2),
    ];
    if (Math.min(...vertices) > highest && face !== 0) {
      if (isHem()) rings++;
      bounds.makeEmpty();
    }
    for (const vertex of vertices) {
      highest = Math.max(highest, vertex);
      bounds.expandByPoint(point.fromBufferAttribute(positions, vertex));
    }
  }
  if (isHem()) rings++;
  assert.equal(rings, 2);
});
