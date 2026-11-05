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

test('hardware prebuilds two bounded detail levels and switches only across projected-size hysteresis', () => {
  const resources = new Set<{ dispose(): void }>();
  const hardware = createCourtHardware({
    own: (resource) => {
      resources.add(resource);
      return resource;
    },
    metalMap: new THREE.Texture(),
    glassMap: new THREE.Texture(),
    rim: new THREE.Vector3(0, 3.05, -5.3),
  });
  try {
    const meshes = hardware.group.children as THREE.Mesh<
      THREE.BufferGeometry,
      THREE.MeshStandardMaterial
    >[];
    const triangles = () =>
      meshes.reduce(
        (sum, mesh) =>
          sum +
          (mesh.geometry.index?.count ??
            mesh.geometry.getAttribute('position').count) /
            3,
        0,
      );
    const camera = new THREE.PerspectiveCamera(45, 1.5, 0.1, 100);
    const moveTo = (distance: number) => {
      camera.position.set(0, 3.05, -5.3 + distance);
      camera.lookAt(0, 3.05, -5.3);
      camera.updateMatrixWorld();
    };
    moveTo(3);
    hardware.setDetailForCamera(camera, 900, 'full');
    const near = meshes.map((mesh) => mesh.geometry);
    const nearTriangles = triangles();
    assert.ok(
      nearTriangles < 45_000,
      `Near basket should spend fewer than 45k triangles, got ${nearTriangles}`,
    );
    assert.equal(meshes.length, 16, 'Detail levels keep one draw per finish');
    const ceiling = meshes.filter(
      (mesh) => mesh.userData.viewRole === 'ceiling',
    );
    const ceilingTriangles = ceiling.reduce(
      (sum, mesh) =>
        sum +
        (mesh.geometry.index?.count ??
          mesh.geometry.getAttribute('position').count) /
          3,
      0,
    );
    assert.ok(
      ceilingTriangles < 3500,
      `Remote ceiling should remain inexpensive, got ${ceilingTriangles}`,
    );
    moveTo(40);
    assert.equal(hardware.setDetailForCamera(camera, 900, 'full'), true);
    const far = meshes.map((mesh) => mesh.geometry);
    assert.ok(
      triangles() < nearTriangles * 0.7,
      'Far detail reduces the basket triangle cost',
    );
    const allocationCount = resources.size;
    moveTo(8);
    // The ~66 CSS pixel hoop stays in its existing level within the hysteresis band.
    assert.equal(hardware.setDetailForCamera(camera, 900, 'full'), false);
    assert.deepEqual(
      meshes.map((mesh) => mesh.geometry),
      far,
    );
    moveTo(3);
    assert.equal(hardware.setDetailForCamera(camera, 900, 'full'), true);
    assert.deepEqual(
      meshes.map((mesh) => mesh.geometry),
      near,
    );
    moveTo(8);
    assert.equal(hardware.setDetailForCamera(camera, 900, 'full'), false);
    assert.deepEqual(
      meshes.map((mesh) => mesh.geometry),
      near,
    );
    for (let index = 0; index < 8; index++) {
      moveTo(index % 2 ? 3 : 40);
      hardware.setDetailForCamera(camera, 900, 'full');
    }
    assert.equal(
      resources.size,
      allocationCount,
      'No geometry allocations while moving the camera',
    );
    for (const mesh of meshes) {
      const index = meshes.indexOf(mesh);
      near[index]!.computeBoundingBox();
      far[index]!.computeBoundingBox();
      assert.ok(
        near[index]!.boundingBox!.min.distanceTo(far[index]!.boundingBox!.min) <
          0.018,
      );
      assert.ok(
        near[index]!.boundingBox!.max.distanceTo(far[index]!.boundingBox!.max) <
          0.018,
      );
    }
    const net = meshes.find((mesh) => mesh.name === 'nylon-net')!;
    assert.equal(net.visible, true);
    hardware.setViewCutaway(1);
    hardware.setNetImpact(1);
    assert.equal(
      net.visible,
      true,
      'Cutaway never detaches or removes the animated net',
    );
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

test('powder coat, brushed fittings and pads use visibly different physical finishes', () => {
  const resources: { dispose(): void }[] = [];
  const hardware = createCourtHardware({
    own: (resource) => {
      resources.push(resource);
      return resource;
    },
    metalMap: new THREE.Texture(),
    glassMap: new THREE.Texture(),
    rim: new THREE.Vector3(0, 3.05, -5.3),
  });
  try {
    const material = (name: string) =>
      (
        hardware.group.getObjectByName(name) as THREE.Mesh<
          THREE.BufferGeometry,
          THREE.MeshStandardMaterial
        >
      ).material;
    assert.ok(
      material('painted-steel').metalness < 0.4,
      'Powder coat is dielectric paint over steel',
    );
    assert.ok(material('brushed-fasteners').metalness > 0.8);
    assert.ok(material('padded-protection').roughness > 0.85);
    assert.ok(
      material('painted-steel').roughness >
        material('brushed-fasteners').roughness,
    );
    assert.ok(
      material('arena-structure').isMeshStandardMaterial,
      'Arena structure responds to the shared lights',
    );
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

test('the breakaway rim mounts to the glass with a load plate and four visible fasteners', () => {
  const resources: { dispose(): void }[] = [];
  const rim = new THREE.Vector3(0, 3.05, -5.3);
  const hardware = createCourtHardware({
    own: (resource) => {
      resources.push(resource);
      return resource;
    },
    metalMap: new THREE.Texture(),
    glassMap: new THREE.Texture(),
    rim,
  });
  try {
    const fittings = (
      hardware.group.getObjectByName('brushed-fasteners') as THREE.Mesh
    ).geometry.getAttribute('position');
    for (const dx of [-0.063, 0.063]) {
      for (const dy of [0.045, 0.2]) {
        let found = false;
        for (let vertex = 0; vertex < fittings.count; vertex++) {
          if (
            Math.abs(fittings.getX(vertex) - dx) < 0.02 &&
            Math.abs(fittings.getY(vertex) - (rim.y + dy)) < 0.02 &&
            Math.abs(fittings.getZ(vertex) - (rim.z - 0.47 + 0.058)) < 0.02
          ) {
            found = true;
            break;
          }
        }
        assert.ok(found, `Mount fastener exists at ${dx}, ${dy}`);
      }
    }
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

test('both net detail levels share a fixed top attachment and shader-driven bounded deformation', () => {
  const resources: { dispose(): void }[] = [];
  const rim = new THREE.Vector3(0, 3.05, -5.3);
  const hardware = createCourtHardware({
    own: (resource) => {
      resources.push(resource);
      return resource;
    },
    metalMap: new THREE.Texture(),
    glassMap: new THREE.Texture(),
    rim,
  });
  try {
    const net = hardware.group.getObjectByName('nylon-net') as THREE.Mesh<
      THREE.BufferGeometry,
      THREE.MeshStandardMaterial
    >;
    const shader = {
      uniforms: {},
      vertexShader: THREE.ShaderLib.standard.vertexShader,
      fragmentShader: THREE.ShaderLib.standard.fragmentShader,
    } as THREE.WebGLProgramParametersWithUniforms;
    net.material.onBeforeCompile(shader, {} as THREE.WebGLRenderer);
    const anchor = shader.uniforms.uNetAnchor!.value as THREE.Vector3;
    const uniforms = shader.uniforms;
    assert.equal(anchor.y, rim.y - 0.033);
    assert.match(
      shader.vertexShader,
      /depth \* depth \* \(3\.0 - 2\.0 \* depth\)/,
    );
    assert.match(shader.vertexShader, /objectNormal = netNormal/);
    const geometries = new Set<THREE.BufferGeometry>();
    const camera = new THREE.PerspectiveCamera(45, 1.5, 0.1, 100);
    for (const distance of [3, 40]) {
      camera.position.set(0, rim.y, rim.z + distance);
      camera.lookAt(rim);
      camera.updateMatrixWorld();
      hardware.setDetailForCamera(camera, 900, 'full');
      geometries.add(net.geometry);
      const positions = net.geometry.getAttribute('position');
      for (const impact of [-0.2, 0, 0.5, 1]) {
        hardware.setNetImpact(impact);
        assert.equal(uniforms.uNetImpact!.value, impact);
        for (let vertex = 0; vertex < positions.count; vertex++) {
          const original = new THREE.Vector3().fromBufferAttribute(
            positions,
            vertex,
          );
          const depth = THREE.MathUtils.clamp(
            (anchor.y - original.y) / 0.53,
            0,
            1,
          );
          const weight = depth * depth * (3 - 2 * depth);
          const deformed = original.clone();
          deformed.x +=
            impact * weight * ((original.x - anchor.x) * 0.42 + 0.03);
          deformed.z +=
            impact * weight * ((original.z - anchor.z) * 0.42 - 0.018);
          deformed.y -= impact * weight * 0.075;
          if (original.y >= anchor.y)
            assert.deepEqual(deformed, original, 'Rim attachment stays fixed');
          assert.ok(
            net.geometry.boundingSphere!.containsPoint(deformed),
            'Animated mesh remains inside its culling bounds',
          );
        }
      }
    }
    assert.equal(geometries.size, 2);
  } finally {
    for (const resource of resources) resource.dispose();
  }
});
