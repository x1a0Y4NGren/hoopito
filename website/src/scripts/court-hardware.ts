import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

type ResourceOwner = <T extends { dispose(): void }>(resource: T) => T;

interface CourtHardwareOptions {
  own: ResourceOwner;
  metalMap: THREE.Texture;
  glassMap: THREE.Texture;
  rim: THREE.Vector3;
}

interface GeometryBatch {
  material: THREE.Material;
  parts: THREE.BufferGeometry[];
  castShadow: boolean;
}

/** Model-space hardware, with one merged draw per finish and one animated net. */
export function createCourtHardware({
  own,
  metalMap,
  glassMap,
  rim,
}: CourtHardwareOptions): {
  group: THREE.Group;
  setNetImpact(value: number): void;
  setCeilingVisibility(value: number): void;
} {
  const group = new THREE.Group();
  group.name = 'court-hardware';
  const batches = new Map<string, GeometryBatch>();
  const impact = { value: 0 };
  const ceilingMeshes: THREE.Mesh<THREE.BufferGeometry, THREE.Material>[] = [];
  const netLength = 0.53;
  const netTop = rim.y - 0.033;
  const netAnchor = new THREE.Vector3(rim.x, netTop, rim.z);
  const up = new THREE.Vector3(0, 1, 0);

  const finish = (
    name: string,
    parameters: THREE.MeshStandardMaterialParameters,
    castShadow = true,
  ) => {
    batches.set(name, {
      material: own(new THREE.MeshStandardMaterial(parameters)),
      parts: [],
      castShadow,
    });
    return name;
  };
  const steel = finish('painted-steel', {
    color: '#85929A',
    map: metalMap,
    bumpMap: metalMap,
    bumpScale: 0.0014,
    roughness: 0.48,
    metalness: 0.8,
  });
  const brushed = finish('brushed-fasteners', {
    color: '#B4BDC0',
    map: metalMap,
    bumpMap: metalMap,
    bumpScale: 0.0008,
    roughness: 0.31,
    metalness: 0.92,
  });
  const padding = finish('padded-protection', {
    color: '#15191C',
    bumpMap: metalMap,
    bumpScale: 0.004,
    roughness: 0.91,
    metalness: 0,
  });
  const orange = finish('orange-rim', {
    color: '#EF652C',
    bumpMap: metalMap,
    bumpScale: 0.0007,
    roughness: 0.31,
    metalness: 0.35,
    emissive: '#A6360F',
    emissiveIntensity: 0.08,
  });
  const lens = finish(
    'ceiling-optics',
    {
      color: '#FFF7E7',
      roughness: 0.17,
      metalness: 0,
      emissive: '#FFF1D7',
      emissiveIntensity: 1.8,
      bumpMap: glassMap,
      bumpScale: 0.0003,
      transparent: true,
      depthWrite: false,
    },
    false,
  );
  const marking = finish(
    'backboard-target',
    { color: '#F3F0E8', roughness: 0.65, metalness: 0 },
    false,
  );
  batches.set('glass-panel', {
    material: own(
      new THREE.MeshPhysicalMaterial({
        color: '#CDDFE4',
        bumpMap: glassMap,
        bumpScale: 0.00045,
        roughness: 0.085,
        metalness: 0.03,
        clearcoat: 1,
        clearcoatRoughness: 0.09,
        transparent: true,
        opacity: 0.17,
        depthWrite: false,
      }),
    ),
    parts: [],
    castShadow: false,
  });
  const glassEdge = finish(
    'glass-edge',
    {
      color: '#9ABDC6',
      roughness: 0.18,
      metalness: 0.08,
      transparent: true,
      opacity: 0.48,
      depthWrite: false,
    },
    false,
  );

  // Construction parts never reach the renderer. Dispose these local staging
  // geometries after merging; only the final geometry belongs to the scene owner.
  function place(
    geometry: THREE.BufferGeometry,
    batch: string,
    position: THREE.Vector3,
    rotation = new THREE.Euler(),
    scale = new THREE.Vector3(1, 1, 1),
    parent?: THREE.Matrix4,
  ) {
    const matrix = new THREE.Matrix4().compose(
      position,
      new THREE.Quaternion().setFromEuler(rotation),
      scale,
    );
    if (parent) matrix.premultiply(parent);
    geometry.applyMatrix4(matrix);
    batches.get(batch)!.parts.push(geometry);
  }
  function block(
    size: [number, number, number],
    position: [number, number, number],
    batch: string,
    radius = 0.018,
    parent?: THREE.Matrix4,
  ) {
    place(
      new RoundedBoxGeometry(
        ...size,
        2,
        Math.min(radius, Math.min(...size) * 0.45),
      ),
      batch,
      new THREE.Vector3(...position),
      undefined,
      undefined,
      parent,
    );
  }
  function cylinder(
    top: number,
    bottom: number,
    height: number,
    position: [number, number, number],
    batch: string,
    rotation = new THREE.Euler(),
    segments = 24,
  ) {
    place(
      new THREE.CylinderGeometry(top, bottom, height, segments),
      batch,
      new THREE.Vector3(...position),
      rotation,
    );
  }
  function beam(
    start: THREE.Vector3,
    end: THREE.Vector3,
    radius: number,
    batch: string,
  ) {
    const direction = end.clone().sub(start);
    const geometry = new THREE.CylinderGeometry(
      radius,
      radius,
      direction.length(),
      24,
    );
    geometry.applyQuaternion(
      new THREE.Quaternion().setFromUnitVectors(up, direction.normalize()),
    );
    geometry.translate(...start.clone().add(end).multiplyScalar(0.5).toArray());
    batches.get(batch)!.parts.push(geometry);
  }
  function pipe(
    points: THREE.Vector3[],
    radius: number,
    batch: string,
    segments = Math.max(24, points.length * 8),
    radialSegments = 12,
  ) {
    const geometry = new THREE.TubeGeometry(
      new THREE.CatmullRomCurve3(points),
      segments,
      radius,
      radialSegments,
      false,
    );
    batches.get(batch)!.parts.push(geometry);
  }

  // Suspended indoor luminaires and acoustic architecture, rather than streetlight poles.
  // The ceiling details use simple boxes: the near basket keeps the fine hardware budget.
  // Remote dark trusses carry a fixed ambient graphite finish. Their geometry
  // supplies the silhouette; per-pixel physical lighting adds no useful close-up detail.
  const architecture = 'arena-structure';
  batches.set(architecture, {
    material: own(new THREE.MeshBasicMaterial({ color: '#0B1318' })),
    parts: [],
    castShadow: false,
  });
  const ceilingStructure = 'ceiling-structure';
  batches.set(ceilingStructure, {
    material: own(
      new THREE.MeshBasicMaterial({
        color: '#0B1318',
        transparent: true,
        depthWrite: false,
      }),
    ),
    parts: [],
    castShadow: false,
  });
  const ceilingMetal = finish(
    'ceiling-metal',
    {
      color: '#B4BDC0',
      map: metalMap,
      roughness: 0.31,
      metalness: 0.92,
      transparent: true,
      depthWrite: false,
    },
    false,
  );
  const acoustic = finish(
    'acoustic-panels',
    {
      color: '#20282B',
      roughness: 0.98,
      metalness: 0,
    },
    false,
  );
  const warmStrip = finish(
    'arena-guidance-light',
    {
      color: '#B88550',
      emissive: '#BC7234',
      emissiveIntensity: 0.72,
      roughness: 0.65,
      metalness: 0.04,
    },
    false,
  );
  for (const z of [-10, -3, 5]) {
    block([26.7, 0.19, 0.17], [0, 8.85, z], ceilingStructure, 0.012);
    block([26.7, 0.095, 0.095], [0, 8.25, z], ceilingStructure, 0.009);
    for (let bay = -12; bay <= 12; bay += 3) {
      beam(
        new THREE.Vector3(bay, 8.25, z),
        new THREE.Vector3(bay + 1.5, 8.85, z),
        0.027,
        ceilingStructure,
      );
      beam(
        new THREE.Vector3(bay + 1.5, 8.85, z),
        new THREE.Vector3(bay + 3, 8.25, z),
        0.027,
        ceilingStructure,
      );
    }
    for (const x of [-6.4, 0, 6.4]) {
      // Shallow graphite housing, satin bezel, segmented opal diffuser, and hanger rods.
      block([2.15, 0.13, 0.48], [x, 7.85, z], ceilingStructure, 0.025);
      block([2.02, 0.03, 0.43], [x, 7.776, z], ceilingMetal, 0.012);
      block([1.94, 0.012, 0.365], [x, 7.754, z], lens, 0.008);
      for (const direction of [-1, 1]) {
        cylinder(
          0.012,
          0.012,
          0.84,
          [x + direction * 0.8, 8.29, z],
          ceilingStructure,
          undefined,
          8,
        );
        block(
          [0.008, 0.018, 0.43],
          [x + direction * 1.01, 7.755, z],
          ceilingStructure,
          0.002,
        );
      }
      for (let segment = -4; segment <= 4; segment += 1)
        block(
          [0.012, 0.014, 0.37],
          [x + segment * 0.193, 7.744, z],
          ceilingStructure,
          0.002,
        );
    }
  }
  // Rear wall ribs and copper guidance lights remain readable behind the hero ball.
  for (let x = -12; x <= 12; x += 1.5) {
    block([0.64, 5.7, 0.085], [x, 3.85, -13.29], acoustic, 0.004);
    block([0.045, 7.2, 0.14], [x + 0.68, 3.9, -13.19], architecture, 0.006);
  }
  for (const x of [-11.3, 11.3]) {
    block([0.12, 0.018, 17], [x, 0.028, -0.5], warmStrip, 0.003);
    // Retracted courtside seating: low silhouettes, without high-cost remote detail.
    for (let row = 0; row < 3; row += 1) {
      block(
        [0.64, 0.09, 11.8],
        [x + Math.sign(x) * row * 0.56, 0.26 + row * 0.22, -1.9],
        architecture,
        0.015,
      );
      block(
        [0.095, 0.24, 11.8],
        [x + Math.sign(x) * (row * 0.56 + 0.27), 0.42 + row * 0.22, -1.9],
        acoustic,
        0.018,
      );
    }
  }

  const backZ = rim.z - 2.15;
  const boardZ = rim.z - 0.47;
  const boardY = rim.y + 0.525;
  block([1.46, 0.14, 1.35], [rim.x, 0.045, backZ], steel, 0.04);
  block([1.23, 0.38, 1.08], [rim.x, 0.3, backZ + 0.07], padding, 0.09);
  block([0.3, 3.88, 0.3], [rim.x, 2.03, backZ - 0.2], steel, 0.037);
  block([0.45, 1.57, 0.43], [rim.x, 1.03, backZ - 0.17], padding, 0.063);
  for (const y of [0.57, 1.47]) {
    block([0.454, 0.047, 0.022], [rim.x, y, backZ + 0.054], steel, 0.005);
    block(
      [0.054, 0.057, 0.03],
      [rim.x + 0.15, y, backZ + 0.071],
      brushed,
      0.009,
    );
  }
  for (const dx of [-0.55, 0.55]) {
    for (const dz of [-0.49, 0.49])
      cylinder(
        0.026,
        0.026,
        0.029,
        [rim.x + dx, 0.13, backZ + dz],
        brushed,
        undefined,
        6,
      );
  }
  for (const dx of [-0.19, 0.19]) {
    pipe(
      [
        new THREE.Vector3(rim.x + dx, 3.53, backZ - 0.2),
        new THREE.Vector3(rim.x + dx, 3.96, backZ + 0.36),
        new THREE.Vector3(rim.x + dx, 3.97, boardZ - 0.63),
        new THREE.Vector3(rim.x + dx, boardY, boardZ - 0.095),
      ],
      0.076,
      steel,
    );
    beam(
      new THREE.Vector3(rim.x + dx, 2.75, backZ - 0.15),
      new THREE.Vector3(rim.x + dx, 3.91, boardZ - 0.74),
      0.029,
      brushed,
    );
    cylinder(0.088, 0.088, 0.08, [rim.x + dx, 3.55, backZ - 0.2], brushed);
  }
  block([0.63, 0.58, 0.065], [rim.x, boardY, boardZ - 0.057], steel, 0.022);
  block([1.8, 1.05, 0.023], [rim.x, boardY, boardZ], 'glass-panel', 0.009);
  for (const dx of [-0.917, 0.917]) {
    block([0.031, 1.109, 0.053], [rim.x + dx, boardY, boardZ], steel, 0.009);
    block(
      [0.012, 1.029, 0.029],
      [rim.x + dx * 0.969, boardY, boardZ],
      glassEdge,
      0.004,
    );
  }
  for (const dy of [-0.538, 0.538]) {
    block([1.867, 0.029, 0.053], [rim.x, boardY + dy, boardZ], steel, 0.008);
    block(
      [1.785, 0.009, 0.029],
      [rim.x, boardY + dy * 0.968, boardZ],
      glassEdge,
      0.003,
    );
  }
  for (const dx of [-0.845, 0.845]) {
    for (const dy of [-0.464, 0.464]) {
      block(
        [0.082, 0.078, 0.048],
        [rim.x + dx, boardY + dy, boardZ],
        brushed,
        0.011,
      );
      cylinder(
        0.014,
        0.014,
        0.02,
        [rim.x + dx, boardY + dy, boardZ + 0.033],
        steel,
        new THREE.Euler(Math.PI / 2, 0, 0),
        6,
      );
    }
  }
  const targetY = rim.y + 0.225;
  for (const dx of [-0.284, 0.284])
    block(
      [0.022, 0.45, 0.005],
      [rim.x + dx, targetY, boardZ + 0.015],
      marking,
      0.002,
    );
  for (const dy of [-0.214, 0.214])
    block(
      [0.59, 0.022, 0.005],
      [rim.x, targetY + dy, boardZ + 0.015],
      marking,
      0.002,
    );

  block(
    [0.158, 0.148, 0.18],
    [rim.x, rim.y - 0.026, boardZ + 0.13],
    orange,
    0.021,
  );
  beam(
    new THREE.Vector3(rim.x, rim.y - 0.026, boardZ + 0.14),
    new THREE.Vector3(rim.x, rim.y - 0.026, rim.z - 0.24),
    0.027,
    steel,
  );
  cylinder(
    0.034,
    0.034,
    0.145,
    [rim.x, rim.y - 0.066, rim.z - 0.31],
    brushed,
    new THREE.Euler(0, 0, Math.PI / 2),
  );
  const spring: THREE.Vector3[] = [];
  for (let point = 0; point <= 64; point += 1) {
    const along = point / 64;
    const angle = along * Math.PI * 12;
    spring.push(
      new THREE.Vector3(
        rim.x + Math.cos(angle) * 0.022,
        rim.y - 0.085 + Math.sin(angle) * 0.022,
        rim.z - 0.405 + along * 0.12,
      ),
    );
  }
  pipe(spring, 0.004, brushed, 96, 8);
  place(
    new THREE.TorusGeometry(0.243, 0.018, 16, 96),
    orange,
    rim.clone(),
    new THREE.Euler(Math.PI / 2, 0, 0),
  );
  for (let hook = 0; hook < 12; hook += 1) {
    const angle = (hook / 12) * Math.PI * 2;
    place(
      new THREE.TorusGeometry(0.012, 0.0037, 8, 20),
      orange,
      new THREE.Vector3(
        rim.x + Math.sin(angle) * 0.232,
        rim.y - 0.026,
        rim.z + Math.cos(angle) * 0.232,
      ),
      new THREE.Euler(0, angle, 0),
    );
  }

  const nylon = own(
    new THREE.MeshStandardMaterial({
      color: '#F0E7D4',
      roughness: 0.86,
      metalness: 0,
    }),
  );
  nylon.customProgramCacheKey = () => 'hoopito-anchored-nylon-net-v2';
  nylon.onBeforeCompile = (shader) => {
    shader.uniforms.uNetImpact = impact;
    shader.uniforms.uNetAnchor = { value: netAnchor };
    shader.vertexShader = shader.vertexShader
      .replace(
        '#include <common>',
        /* glsl */ `#include <common>
        uniform float uNetImpact;
        uniform vec3 uNetAnchor;
        float netDepth(vec3 point) {
          return clamp((uNetAnchor.y - point.y) / ${netLength.toFixed(2)}, 0.0, 1.0);
        }
        vec3 netPosition(vec3 point) {
          float depth = netDepth(point);
          float weight = depth * depth * (3.0 - 2.0 * depth);
          vec2 radial = point.xz - uNetAnchor.xz;
          point.xz += uNetImpact * weight * (radial * 0.42 + vec2(0.030, -0.018));
          point.y -= uNetImpact * weight * 0.075;
          return point;
        }
        vec3 netNormal(vec3 point, vec3 normal) {
          float depth = netDepth(point);
          float weight = depth * depth * (3.0 - 2.0 * depth);
          float slope = -6.0 * depth * (1.0 - depth) / ${netLength.toFixed(2)};
          float expansion = 1.0 + uNetImpact * weight * 0.42;
          vec2 radial = point.xz - uNetAnchor.xz;
          vec2 shear = uNetImpact * slope * (radial * 0.42 + vec2(0.030, -0.018));
          vec2 sides = normal.xz / expansion;
          float vertical = (normal.y - dot(shear, sides)) / (1.0 - uNetImpact * slope * 0.075);
          return normalize(vec3(sides.x, vertical, sides.y));
        }
      `,
      )
      .replace(
        '#include <beginnormal_vertex>',
        '#include <beginnormal_vertex>\nobjectNormal = netNormal(position, objectNormal);',
      )
      .replace(
        '#include <begin_vertex>',
        '#include <begin_vertex>\ntransformed = netPosition(transformed);',
      );
  };
  batches.set('nylon-net', { material: nylon, parts: [], castShadow: false });
  const netRows = [0, 0.065, 0.16, 0.265, 0.37, 0.465, netLength];
  const radii = [0.232, 0.225, 0.207, 0.182, 0.159, 0.137, 0.139];
  const nodes = netRows.map((drop, row) =>
    Array.from({ length: 12 }, (_, index) => {
      const angle = ((index + (row % 2) * 0.5) / 12) * Math.PI * 2;
      return new THREE.Vector3(
        rim.x + Math.sin(angle) * radii[row]!,
        netTop - drop,
        rim.z + Math.cos(angle) * radii[row]!,
      );
    }),
  );
  function rope(start: THREE.Vector3, end: THREE.Vector3) {
    const middle = start.clone().lerp(end, 0.5);
    const radial = new THREE.Vector3(
      middle.x - rim.x,
      0,
      middle.z - rim.z,
    ).normalize();
    middle.addScaledVector(radial, 0.003);
    middle.y -= 0.002;
    batches
      .get('nylon-net')!
      .parts.push(
        new THREE.TubeGeometry(
          new THREE.QuadraticBezierCurve3(start, middle, end),
          5,
          0.0032,
          8,
          false,
        ),
      );
  }
  for (let index = 0; index < 12; index += 1) {
    const start = nodes[0]![index]!.clone();
    start.y = rim.y - 0.016;
    rope(start, nodes[0]![index]!);
  }
  for (let row = 1; row < nodes.length; row += 1) {
    for (let index = 0; index < 12; index += 1) {
      const knot = nodes[row]![index]!;
      const adjacent = (index + (row % 2 ? 1 : -1) + 12) % 12;
      rope(nodes[row - 1]![index]!, knot);
      rope(nodes[row - 1]![adjacent]!, knot);
      place(new THREE.SphereGeometry(0.0052, 10, 6), 'nylon-net', knot);
    }
  }
  const lowerLoop = new THREE.CatmullRomCurve3(nodes.at(-1)!, true);
  batches
    .get('nylon-net')!
    .parts.push(new THREE.TubeGeometry(lowerLoop, 96, 0.0032, 8, true));

  for (const [name, batch] of batches) {
    if (!batch.parts.length) continue;
    const allIndexed = batch.parts.every((geometry) => geometry.index !== null);
    const parts = allIndexed
      ? batch.parts
      : batch.parts.map((geometry) =>
          geometry.index ? geometry.toNonIndexed() : geometry,
        );
    const geometry = mergeGeometries(parts, false);
    for (const part of new Set([...batch.parts, ...parts])) part.dispose();
    batch.parts.length = 0;
    if (!geometry)
      throw new Error(`Court hardware geometry failed to merge: ${name}`);
    geometry.computeBoundingSphere();
    if (name === 'nylon-net' && geometry.boundingSphere)
      geometry.boundingSphere.radius += 0.09;
    const mesh = new THREE.Mesh(own(geometry), batch.material);
    mesh.name = name;
    mesh.castShadow = batch.castShadow;
    mesh.receiveShadow = !name.startsWith('ceiling-') && name !== 'glass-panel';
    group.add(mesh);
    if (name.startsWith('ceiling-')) ceilingMeshes.push(mesh);
  }

  return {
    group,
    setNetImpact(value) {
      impact.value = Number.isFinite(value)
        ? THREE.MathUtils.clamp(value, -0.2, 1)
        : 0;
    },
    setCeilingVisibility(value) {
      const opacity = Number.isFinite(value)
        ? THREE.MathUtils.clamp(value, 0, 1)
        : 0;
      for (const mesh of ceilingMeshes) {
        mesh.visible = opacity > 0.001;
        mesh.material.opacity = opacity;
      }
    },
  };
}
