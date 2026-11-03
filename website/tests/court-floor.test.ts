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

test('floor paint shares cached world lighting and linear surface detail with the wood', async () => {
  const { createCourtFloor } = await import('../src/scripts/court-floor.ts');
  const resources = new Set<{ dispose(): void }>();
  const detail = new THREE.Texture();
  const floor = createCourtFloor({
    own: (resource) => {
      resources.add(resource);
      return resource;
    },
    mapleMap: new THREE.Texture(),
    detailMap: detail,
    rim: new THREE.Vector3(0, 3.05, -5.3),
  });
  try {
    assert.equal(floor.paintUniforms.uFloorDetail.value, detail);
    assert.equal(detail.colorSpace, THREE.NoColorSpace);
    const position = floor.paintGeometry.getAttribute('position');
    const dynamic = floor.paintGeometry.getAttribute('aFloorDynamic');
    const fixed = floor.paintGeometry.getAttribute('aFloorFixed');
    const { sampleFloorLighting } =
      await import('../src/scripts/court-floor.ts');
    for (const index of [
      0,
      64,
      Math.floor(position.count / 2),
      position.count - 1,
    ]) {
      const sample = sampleFloorLighting(
        position.getX(index),
        -position.getY(index),
      );
      assert.ok(Math.abs(dynamic.getX(index) - sample.dynamic[0]) < 1e-6);
      assert.ok(Math.abs(fixed.getZ(index) - sample.fixed[2]) < 1e-6);
    }
    floor.setLight(0.42);
    assert.equal(
      floor.paintUniforms.uFloorLight.value,
      0.42,
      'Paint and wood use the same story light strength',
    );
    assert.equal(floor.paintUniforms.uFloorHasDetail.value, 1);
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

test('one continuous floor covers fitted overhead viewports without a visible border', async () => {
  const { createCourtFloor } = await import('../src/scripts/court-floor.ts');
  const { composeCameraPose } =
    await import('../src/scripts/camera-placement.ts');
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
    floor.mesh.updateMatrixWorld();
    const bounds = new THREE.Box3().setFromObject(floor.mesh);
    const ground = new THREE.Plane(new THREE.Vector3(0, 1, 0), -0.004);
    const raycaster = new THREE.Raycaster();
    for (const [width, height] of [
      [1920, 1080],
      [3840, 2160],
      [5120, 1440],
    ]) {
      const viewport = { left: 0, top: 0, width: width!, height: height! };
      const region = {
        left: width! / 2 - 280,
        top: height! / 2 - 210,
        width: 560,
        height: 420,
      };
      const pose = composeCameraPose(
        { chapter: 'experience', progress: 0.5, active: true },
        viewport,
        { region, blend: 1, inputEnabled: true },
      );
      const camera = new THREE.PerspectiveCamera(
        pose.fov,
        width! / height!,
        0.1,
        300,
      );
      camera.position.fromArray(pose.position);
      camera.up.fromArray(pose.up ?? [0, 0, -1]);
      camera.lookAt(new THREE.Vector3(...pose.target));
      camera.filmOffset = pose.filmOffset ?? 0;
      camera.updateProjectionMatrix();
      camera.updateMatrixWorld();
      for (const [x, y] of [
        [-1, -1],
        [-1, 1],
        [1, -1],
        [1, 1],
      ]) {
        raycaster.setFromCamera(new THREE.Vector2(x, y), camera);
        const hit = raycaster.ray.intersectPlane(ground, new THREE.Vector3());
        assert.ok(hit);
        assert.ok(
          hit.x > bounds.min.x + 1 &&
            hit.x < bounds.max.x - 1 &&
            hit.z > bounds.min.z + 1 &&
            hit.z < bounds.max.z - 1,
          `${width}×${height} overhead corner remains inside the wood floor`,
        );
      }
    }
    assert.equal(floor.mesh.geometry.getAttribute('position').count, 65 * 97);
    assert.equal(floor.mesh.geometry.getIndex()!.count, 64 * 96 * 6);
    assert.equal(
      floor.mesh.children.length,
      1,
      'Extension adds no separate floor planes',
    );
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

test('extended wood and painted detail keep the same 1.4-metre world texture period', async () => {
  const { createCourtFloor } = await import('../src/scripts/court-floor.ts');
  const resources = new Set<{ dispose(): void }>();
  const maple = new THREE.Texture();
  const floor = createCourtFloor({
    own: (resource) => {
      resources.add(resource);
      return resource;
    },
    mapleMap: maple,
    detailMap: new THREE.Texture(),
    rim: new THREE.Vector3(0, 3.05, -5.3),
  });
  try {
    const position = floor.mesh.geometry.getAttribute('position');
    const uv = floor.mesh.geometry.getAttribute('uv');
    const center = 48 * 65 + 32;
    for (const index of [
      0,
      64,
      center - 1,
      center,
      center + 1,
      position.count - 1,
    ]) {
      const x = position.getX(index);
      const worldZ = 4 - position.getY(index);
      const wantU = x / 1.4 + 10;
      const wantV = (25 - worldZ) / 1.4;
      assert.ok(Math.abs(uv.getX(index) * maple.repeat.x - wantU) < 0.00002);
      assert.ok(Math.abs(uv.getY(index) * maple.repeat.y - wantV) < 0.00002);
      const frame = floor.paintUniforms.uFloorTextureFrame.value;
      const detailRepeat = floor.paintUniforms.uFloorDetailRepeat.value;
      const detailU = ((x + frame.x) / frame.z) * detailRepeat.x;
      const detailV = ((frame.y - worldZ) / frame.w) * detailRepeat.y;
      assert.ok(Math.abs(detailU - wantU) < 0.00002);
      assert.ok(Math.abs(detailV - wantV) < 0.00002);
    }
    const adjacentUv = uv.getX(center + 1) - uv.getX(center);
    const period =
      (position.getX(center + 1) - position.getX(center)) /
      (adjacentUv * maple.repeat.x);
    assert.ok(Math.abs(period - 1.4) < 0.000001);
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

test('floor expansion preserves the local lighting grid, paint dimensions and basket shadow location', async () => {
  const { createCourtFloor, sampleFloorLighting } =
    await import('../src/scripts/court-floor.ts');
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
    const position = floor.mesh.geometry.getAttribute('position');
    const center = 48 * 65 + 32;
    assert.equal(position.getX(center), 0);
    assert.ok(Math.abs(position.getY(center)) < 0.000001);
    assert.equal(position.getX(center + 1), 0.4375);
    assert.equal(position.getY(center - 65), 0.4375);
    for (const index of [
      center,
      center + 1,
      center - 65,
      0,
      position.count - 1,
    ]) {
      const sample = sampleFloorLighting(
        position.getX(index),
        4 - position.getY(index),
      );
      const dynamic = floor.mesh.geometry.getAttribute('aFloorDynamic');
      const fixed = floor.mesh.geometry.getAttribute('aFloorFixed');
      assert.ok(Math.abs(dynamic.getX(index) - sample.dynamic[0]) < 0.000001);
      assert.ok(Math.abs(fixed.getY(index) - sample.fixed[1]) < 0.000001);
    }
    assert.equal(floor.paintGeometry.parameters.width, 15);
    assert.equal(floor.paintGeometry.parameters.height, 14);
    assert.equal(floor.mesh.material.color.getHexString(), 'c6bbac');
    floor.mesh.updateMatrixWorld();
    const contact = floor.mesh.getObjectByName('cached-basket-base-shadow')!;
    const shadowPosition = contact.getWorldPosition(new THREE.Vector3());
    assert.ok(Math.abs(shadowPosition.x) < 0.000001);
    assert.ok(Math.abs(shadowPosition.y - 0.009) < 0.000001);
    assert.ok(Math.abs(shadowPosition.z + 7.45) < 0.000001);
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

test('density switches one shared floor and paint shading budget without rebuilding resources', async () => {
  const { createCourtFloor } = await import('../src/scripts/court-floor.ts');
  const resources = new Set<{ dispose(): void }>();
  const floor = createCourtFloor({
    own: (resource) => {
      resources.add(resource);
      return resource;
    },
    mapleMap: new THREE.Texture(),
    detailMap: new THREE.Texture(),
    rim: new THREE.Vector3(0, 3.05, -5.3),
  });
  try {
    const shader = {
      uniforms: {},
      vertexShader: THREE.ShaderLib.basic.vertexShader,
      fragmentShader: THREE.ShaderLib.basic.fragmentShader,
    } as THREE.WebGLProgramParametersWithUniforms;
    floor.mesh.material.onBeforeCompile(shader, {} as THREE.WebGLRenderer);
    const uniforms = floor.paintUniforms;
    const geometry = floor.mesh.geometry;
    const material = floor.mesh.material;
    const position = geometry.getAttribute('position');
    const uv = geometry.getAttribute('uv');
    const lighting = geometry.getAttribute('aFloorDynamic');
    const paint = floor.paintGeometry;
    const allocationCount = resources.size;
    const version = material.version;
    const cacheKey = material.customProgramCacheKey();
    assert.equal(uniforms.uFloorDensity.value, 0);
    assert.equal(shader.uniforms.uFloorDensity, uniforms.uFloorDensity);
    for (const [quality, density] of [
      ['full', 0],
      ['density', 1],
      ['effects', 0],
      ['density', 1],
      ['full', 0],
    ] as const) {
      floor.setQuality(quality);
      assert.equal(uniforms.uFloorDensity.value, density);
      assert.equal(shader.uniforms.uFloorDensity!.value, density);
      assert.equal(floor.mesh.geometry, geometry);
      assert.equal(floor.mesh.material, material);
      assert.equal(geometry.getAttribute('position'), position);
      assert.equal(geometry.getAttribute('uv'), uv);
      assert.equal(geometry.getAttribute('aFloorDynamic'), lighting);
      assert.equal(floor.paintGeometry, paint);
      assert.equal(resources.size, allocationCount);
      assert.equal(
        material.version,
        version,
        'Switching quality does not compile a new program',
      );
      assert.equal(material.customProgramCacheKey(), cacheKey);
      assert.equal(
        floor.paintUniforms.uFloorHasDetail.value,
        1,
        'Detailed tiers keep their texture',
      );
    }
  } finally {
    for (const resource of resources) resource.dispose();
  }
});

test('vertex varnish receives the scene lamps and the actual flat world normal for both surfaces', async () => {
  const { createCourtFloor } = await import('../src/scripts/court-floor.ts');
  const { COURT_LIGHTING } = await import('../src/scripts/court-lighting.ts');
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
    floor.mesh.updateMatrixWorld();
    const normalMatrix = new THREE.Matrix3().getNormalMatrix(
      floor.mesh.matrixWorld,
    );
    const flatNormal = floor.paintUniforms.uFloorFlatNormal.value;
    for (const geometry of [floor.mesh.geometry, floor.paintGeometry]) {
      const normal = geometry.getAttribute('normal');
      for (const index of [0, Math.floor(normal.count / 2), normal.count - 1]) {
        const worldNormal = new THREE.Vector3()
          .fromBufferAttribute(normal, index)
          .applyNormalMatrix(normalMatrix);
        assert.ok(worldNormal.distanceTo(flatNormal) < 0.000001);
      }
    }
    for (const [prefix, lamp] of [
      ['Key', COURT_LIGHTING.key],
      ['Amber', COURT_LIGHTING.amber],
    ] as const) {
      const lampPosition = floor.paintUniforms[`uFloor${prefix}Position`].value;
      const lampColor = floor.paintUniforms[`uFloor${prefix}Color`].value;
      assert.deepEqual(lampPosition.toArray(), [...lamp.position]);
      assert.ok(lampColor.equals(new THREE.Color(lamp.color)));
    }
    floor.setQuality('density');
    floor.setLight(0.3);
    assert.equal(floor.paintUniforms.uFloorLight.value, 0.3);
    floor.setQuality('effects');
    assert.equal(
      floor.paintUniforms.uFloorLight.value,
      0.3,
      'Quality does not change story illumination',
    );
    assert.deepEqual(flatNormal.toArray(), [0, 1, 0]);
  } finally {
    for (const resource of resources) resource.dispose();
  }
});
