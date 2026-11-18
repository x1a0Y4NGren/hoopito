import * as THREE from 'three';
import { RoundedBoxGeometry } from 'three/addons/geometries/RoundedBoxGeometry.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';
import { REAR_ACCESS_PORTALS } from './court-arena.ts';
import type { SceneQuality } from './scene-contract.ts';

type ResourceOwner = <T extends { dispose(): void }>(resource: T) => T;
type ViewRole = 'basket' | 'ceiling' | 'perimeter' | 'rear-support';

interface CourtHardwareOptions {
  own: ResourceOwner;
  metalMap: THREE.Texture;
  glassMap: THREE.Texture;
  rim: THREE.Vector3;
}

interface GeometryBatch {
  material: THREE.Material;
  parts: THREE.BufferGeometry[];
  farParts: THREE.BufferGeometry[];
  castShadow: boolean;
  viewRole: ViewRole;
}

/** Model-space hardware, with one merged draw per finish and one animated net. */
export function createCourtHardware({
  own,
  metalMap,
  glassMap,
  rim,
}: CourtHardwareOptions): {
  group: THREE.Group;
  setDetailForCamera(
    camera: THREE.PerspectiveCamera,
    viewportCSSHeight: number,
    quality?: SceneQuality,
  ): boolean;
  setNetImpact(value: number): void;
  setCeilingVisibility(value: number): void;
  setViewCutaway(value: number): void;
} {
  const group = new THREE.Group();
  group.name = 'court-hardware';
  const batches = new Map<string, GeometryBatch>();
  const impact = { value: 0 };
  const ceilingMeshes: THREE.Mesh<THREE.BufferGeometry, THREE.Material>[] = [];
  const cutawayMeshes: {
    mesh: THREE.Mesh<THREE.BufferGeometry, THREE.Material>;
    opacity: number;
    transparent: boolean;
    depthWrite: boolean;
    castShadow: boolean;
  }[] = [];
  const netLength = 0.53;
  const netTop = rim.y - 0.033;
  const netAnchor = new THREE.Vector3(rim.x, netTop, rim.z);
  const up = new THREE.Vector3(0, 1, 0);

  const finish = (
    name: string,
    parameters: THREE.MeshStandardMaterialParameters,
    castShadow = true,
    viewRole: ViewRole = 'basket',
  ) => {
    batches.set(name, {
      material: own(new THREE.MeshStandardMaterial(parameters)),
      parts: [],
      farParts: [],
      castShadow,
      viewRole,
    });
    return name;
  };
  const steel = finish('painted-steel', {
    color: '#64737B',
    map: metalMap,
    bumpMap: metalMap,
    bumpScale: 0.0014,
    roughness: 0.55,
    metalness: 0.22,
  });
  const brushed = finish('brushed-fasteners', {
    color: '#C3CBCB',
    map: metalMap,
    bumpMap: metalMap,
    bumpScale: 0.0008,
    roughness: 0.34,
    metalness: 0.87,
  });
  const padding = finish(
    'padded-protection',
    {
      color: '#394750',
      emissive: '#324653',
      emissiveIntensity: 0.12,
      bumpMap: metalMap,
      bumpScale: 0.0012,
      roughness: 0.94,
      metalness: 0,
    },
    true,
    'rear-support',
  );
  const orange = finish('orange-rim', {
    color: '#EF652C',
    bumpMap: metalMap,
    bumpScale: 0.0007,
    roughness: 0.31,
    metalness: 0.35,
  });
  const lens = finish(
    'ceiling-optics',
    {
      color: '#F3E0C8',
      roughness: 0.38,
      metalness: 0,
      emissive: '#FFE2BB',
      emissiveIntensity: 0.57,
      bumpMap: glassMap,
      bumpScale: 0.0003,
      transparent: true,
    },
    false,
    'ceiling',
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
    farParts: [],
    castShadow: false,
    viewRole: 'basket',
  });
  const glassEdge = finish(
    'glass-edge',
    {
      color: '#91BDB8',
      emissive: '#3C686B',
      emissiveIntensity: 0.18,
      roughness: 0.22,
      metalness: 0.08,
      transparent: true,
      opacity: 0.72,
      depthWrite: false,
    },
    false,
  );
  // The front board frame shares the original finishes; only the stand owns
  // these clones. Their texture references remain owned by the scene caller.
  function rearFinish(
    name: string,
    source: string,
    parameters: THREE.MeshStandardMaterialParameters,
  ) {
    const original = batches.get(source)!;
    const material = (original.material as THREE.MeshStandardMaterial).clone();
    material.setValues(parameters);
    batches.set(name, {
      material: own(material),
      parts: [],
      farParts: [],
      castShadow: original.castShadow,
      viewRole: 'rear-support',
    });
    return name;
  }
  const rearSteel = rearFinish('rear-painted-steel', steel, {
    color: '#5B6D78',
    emissive: '#4A5963',
    emissiveIntensity: 0.14,
    roughness: 0.49,
  });
  const rearBrushed = rearFinish('rear-brushed-fasteners', brushed, {
    color: '#9BAAB0',
    roughness: 0.41,
  });

  // Construction parts never reach the renderer. Dispose these local staging
  // geometries after merging; only the final geometry belongs to the scene owner.
  type GeometryPair =
    THREE.BufferGeometry | [THREE.BufferGeometry, THREE.BufferGeometry];
  const hasCloseDetail = (batch: string) =>
    ['basket', 'rear-support'].includes(batches.get(batch)!.viewRole);
  function place(
    geometry: GeometryPair,
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
    const [near, far] = Array.isArray(geometry)
      ? geometry
      : [geometry, geometry.clone()];
    batches.get(batch)!.parts.push(near.applyMatrix4(matrix));
    batches.get(batch)!.farParts.push(far.applyMatrix4(matrix));
  }
  function block(
    size: [number, number, number],
    position: [number, number, number],
    batch: string,
    radius = 0.018,
    parent?: THREE.Matrix4,
  ) {
    const rounded = (segments: number) =>
      new RoundedBoxGeometry(
        ...size,
        segments,
        Math.min(radius, Math.min(...size) * 0.45),
      );
    place(
      hasCloseDetail(batch)
        ? [rounded(2), rounded(1)]
        : new THREE.BoxGeometry(...size),
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
    segments = 20,
  ) {
    const nearSegments = hasCloseDetail(batch)
      ? segments
      : Math.min(segments, 6);
    const near = new THREE.CylinderGeometry(top, bottom, height, nearSegments);
    const far = new THREE.CylinderGeometry(
      top,
      bottom,
      height,
      Math.min(nearSegments, 8),
    );
    place([near, far], batch, new THREE.Vector3(...position), rotation);
  }
  function beam(
    start: THREE.Vector3,
    end: THREE.Vector3,
    radius: number,
    batch: string,
  ) {
    const direction = end.clone().sub(start);
    const length = direction.length();
    const rotation = new THREE.Euler().setFromQuaternion(
      new THREE.Quaternion().setFromUnitVectors(up, direction.normalize()),
    );
    cylinder(
      radius,
      radius,
      length,
      start.clone().add(end).multiplyScalar(0.5).toArray() as [
        number,
        number,
        number,
      ],
      batch,
      rotation,
      hasCloseDetail(batch) ? 16 : 6,
    );
  }
  function pipe(
    points: THREE.Vector3[],
    radius: number,
    batch: string,
    segments = Math.max(16, points.length * 4),
    radialSegments = 8,
  ) {
    const curve = new THREE.CatmullRomCurve3(points);
    place(
      [
        new THREE.TubeGeometry(curve, segments, radius, radialSegments, false),
        new THREE.TubeGeometry(
          curve,
          Math.max(8, Math.floor(segments / 2)),
          radius,
          5,
          false,
        ),
      ],
      batch,
      new THREE.Vector3(),
    );
  }

  // Large architectural pieces share finishes and use the same geometry
  // at both detail levels. Save the close-detail geometry for the basket.
  const architecture = finish(
    'arena-structure',
    {
      color: '#58616B',
      emissive: '#505964',
      emissiveIntensity: 0.23,
      roughness: 0.76,
      metalness: 0.18,
    },
    false,
    'perimeter',
  );
  const ceilingStructure = finish(
    'ceiling-structure',
    {
      color: '#383F46',
      emissive: '#505761',
      emissiveIntensity: 0.19,
      roughness: 0.64,
      metalness: 0.31,
      transparent: true,
    },
    false,
    'ceiling',
  );
  const ceilingMetal = finish(
    'ceiling-metal',
    {
      color: '#A8A094',
      map: metalMap,
      emissive: '#786553',
      emissiveIntensity: 0.16,
      roughness: 0.48,
      metalness: 0.65,
      transparent: true,
    },
    false,
    'ceiling',
  );
  const acoustic = finish(
    'acoustic-panels',
    {
      color: '#303E49',
      emissive: '#475C6A',
      emissiveIntensity: 0.14,
      roughness: 0.98,
      metalness: 0,
    },
    false,
    'perimeter',
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
    'perimeter',
  );
  // A continuous cross-section wraps each chamfer without overlapping joints.
  // Profiles start on the outer face and run down, inward and back up.
  function crownRing(
    profile: readonly [inset: number, y: number][],
    batch: string,
  ) {
    const loops = profile.map(([inset, y]) => {
      const x = 11.3 - inset;
      const rear = -11.3 + inset;
      const front = 9.3 - inset;
      const chamfer = 2.1 - (2 - Math.SQRT2) * inset;
      return [
        [-x + chamfer, y, rear],
        [x - chamfer, y, rear],
        [x, y, rear + chamfer],
        [x, y, front - chamfer],
        [x - chamfer, y, front],
        [-x + chamfer, y, front],
        [-x, y, front - chamfer],
        [-x, y, rear + chamfer],
      ];
    });
    const positions: number[] = [];
    const uvs: number[] = [];
    loops.forEach((loop, band) => {
      const next = loops[(band + 1) % loops.length]!;
      loop.forEach((start, edge) => {
        const end = (edge + 1) % loop.length;
        positions.push(...start, ...loop[end]!, ...next[end]!);
        positions.push(...start, ...next[end]!, ...next[edge]!);
        const u0 = edge / loop.length;
        const u1 = (edge + 1) / loop.length;
        const v0 = band / loops.length;
        const v1 = (band + 1) / loops.length;
        uvs.push(u0, v0, u1, v0, u1, v1, u0, v0, u1, v1, u0, v1);
      });
    });
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute(
      'position',
      new THREE.Float32BufferAttribute(positions, 3),
    );
    geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
    geometry.computeVertexNormals();
    place(geometry, batch, new THREE.Vector3());
  }
  crownRing(
    [
      [0.08, 8.58],
      [0, 8.5],
      [0, 8.22],
      [0.055, 8.15],
      [0.53, 8.15],
      [0.69, 8.3],
      [0.69, 8.51],
      [0.6, 8.58],
    ],
    ceilingStructure,
  );
  crownRing(
    [
      [0.43, 8.16],
      [0.43, 8.142],
      [0.46, 8.125],
      [0.64, 8.125],
      [0.74, 8.19],
      [0.74, 8.3],
      [0.69, 8.3],
      [0.6, 8.16],
    ],
    lens,
  );
  crownRing(
    [
      [0.65, 8.403],
      [0.65, 8.377],
      [0.703, 8.377],
      [0.703, 8.403],
    ],
    ceilingMetal,
  );

  // The crown hangs below a separate roof deck with transverse girders
  // and secondary purlins. Leave open air between the crown and the roof.
  block([27, 0.18, 33.5], [0, 9.42, 3.25], ceilingStructure);
  for (const z of [-11.55, -6.1, -0.35, 5.4, 11.15, 16.5]) {
    block([26.86, 0.31, 0.36], [0, 9.18, z], ceilingStructure);
    block([26.86, 0.038, 0.39], [0, 9.03, z], ceilingMetal);
  }
  for (const x of [-10.96, -5.7, 0, 5.7, 10.96])
    block([0.19, 0.21, 32.8], [x, 8.98, 3.15], ceilingStructure);
  for (const x of [-11.03, 11.03])
    for (const z of [-6.1, -0.35, 5.4]) {
      block([0.12, 0.47, 0.16], [x, 8.79, z], ceilingMetal);
      block([0.31, 0.043, 0.31], [x, 8.58, z], ceilingStructure);
    }
  for (const x of [-5.7, 5.7])
    for (const z of [-11.03, 9.03]) {
      block([0.13, 0.45, 0.13], [x, 8.78, z], ceilingMetal);
      block([0.29, 0.042, 0.29], [x, 8.58, z], ceilingStructure);
    }

  // A deeper column line frames upper acoustic fields and lower impact panels.
  const {
    centers,
    width: portalWidth,
    height: portalHeight,
    wallFaceZ,
  } = REAR_ACCESS_PORTALS;
  for (const x of [-12.64, -6.52, -2.08, 2.08, 6.52, 12.64]) {
    block([0.48, 9.29, 0.52], [x, 4.645, wallFaceZ + 0.13], architecture);
    block([0.55, 0.58, 0.57], [x, 0.29, wallFaceZ + 0.14], acoustic);
  }
  for (const [x, width] of [
    [-11.23, 2.25],
    [-8.59, 2.86],
    [-4.32, 3.78],
    [0, 3.54],
    [4.32, 3.78],
    [8.59, 2.86],
    [11.23, 2.25],
  ] as const) {
    block([width, 2.83, 0.15], [x, 6.06, wallFaceZ + 0.06], acoustic);
    block([width, 1.35, 0.22], [x, 3.858, wallFaceZ + 0.06], acoustic);
    block([width, 0.048, 0.24], [x, 4.577, wallFaceZ + 0.065], architecture);
  }
  for (const [x, width] of [
    [-11.13, 2.08],
    [-4.1, 3.81],
    [0, 3.57],
    [4.1, 3.81],
    [11.13, 2.08],
  ] as const) {
    block([width, 1.64, 0.26], [x, 1.33, wallFaceZ + 0.065], acoustic);
    block([width, 0.23, 0.24], [x, 0.117, wallFaceZ + 0.05], architecture);
  }
  for (const x of centers) {
    const jambX = portalWidth / 2;
    const leafZ = wallFaceZ - 0.62;
    for (const side of [-1, 1]) {
      block(
        [0.17, portalHeight, 0.22],
        [x + side * jambX, portalHeight / 2, wallFaceZ + 0.105],
        architecture,
      );
      block(
        [0.14, portalHeight, 0.69],
        [x + side * (jambX - 0.038), portalHeight / 2, wallFaceZ - 0.275],
        acoustic,
      );
      block([1.018, 2.39, 0.078], [x + side * 0.523, 1.235, leafZ], acoustic);
      block(
        [0.39, 0.057, 0.056],
        [x + side * 0.32, 1.04, leafZ + 0.065],
        architecture,
      );
      block(
        [1.012, 0.215, 0.036],
        [x + side * 0.523, 0.179, leafZ + 0.05],
        architecture,
      );
    }
    block([2.45, 0.2, 0.32], [x, 2.76, wallFaceZ + 0.12], architecture);
    block([2.2, 0.17, 0.7], [x, 2.64, wallFaceZ - 0.253], acoustic);
    block([2.084, 0.165, 0.08], [x, 2.52, leafZ], architecture);
    block([2.1, 0.055, 0.66], [x, 0.029, wallFaceZ - 0.25], architecture);
    block([1.7, 0.036, 0.025], [x, 2.647, wallFaceZ + 0.265], warmStrip);
  }

  const banks = [
    [-12.54, -8.26],
    [-7.12, -2.62],
    [-1.48, 3.09],
    [4.23, 8.8],
  ] as const;
  const firstTread = 10.34;
  const tread = 0.68;
  const riser = 0.35;
  for (const side of [-1, 1]) {
    for (const z of [-12.9, -8.1, -2.47, 3.24, 9.15, 14.4]) {
      block([0.61, 9.29, 0.46], [side * 13.14, 4.645, z], architecture);
      block([0.67, 0.53, 0.53], [side * 13.1, 0.265, z], acoustic);
    }
    for (const [rear, front] of banks) {
      const z = (rear + front) / 2;
      const span = front - rear;
      block([0.2, 3.85, span], [side * 13.32, 5.37, z], acoustic);
      block([0.24, 0.046, span], [side * 13.3, 4.28, z], architecture);
      block(
        [0.06, 0.016, span - 0.16],
        [side * (firstTread - 0.29), 0.022, z],
        warmStrip,
      );
      for (let row = 0; row < 4; row++) {
        const x = firstTread + row * tread;
        const height = (row + 1) * riser;
        block(
          [tread, height, span],
          [side * (x + tread / 2), height / 2, z],
          architecture,
        );
        block(
          [0.12, 0.047, span],
          [side * (x + 0.058), height - 0.028, z],
          acoustic,
        );
        block(
          [0.113, 0.045, span - 0.28],
          [side * (x + 0.475), height + 0.186, z],
          architecture,
        );
        for (const offset of [-0.27, 0.27])
          block(
            [0.11, 0.18, 0.185],
            [side * (x + 0.475), height + 0.09, z + span * offset],
            architecture,
          );
        for (let seat = 0; seat < 8; seat++) {
          const seatZ = rear + (span * (seat + 0.5)) / 8;
          block(
            [0.37, 0.065, 0.445],
            [side * (x + 0.403), height + 0.229, seatZ],
            acoustic,
          );
          place(
            new THREE.BoxGeometry(0.077, 0.3, 0.435),
            acoustic,
            new THREE.Vector3(side * (x + 0.588), height + 0.369, seatZ),
            new THREE.Euler(0, 0, -side * 0.16),
          );
        }
      }
    }
    for (const z of [-7.69, -2.05, 3.66]) {
      for (let step = 0; step < 8; step++) {
        const x = firstTread + ((step + 0.5) * tread) / 2;
        const height = ((step + 1) * riser) / 2;
        block([tread / 2, height, 1.12], [side * x, height / 2, z], acoustic);
        block(
          [0.052, 0.034, 1.12],
          [side * (x - 0.147), height - 0.018, z],
          architecture,
        );
      }
      const railX = firstTread + tread / 4;
      const railY = riser / 2 + 0.82;
      beam(
        new THREE.Vector3(side * railX, railY, z),
        new THREE.Vector3(side * (railX + 3.5 * tread), railY + 3.5 * riser, z),
        0.032,
        architecture,
      );
      for (const step of [0, 3, 7])
        block(
          [0.045, 0.82, 0.045],
          [
            side * (railX + (step * tread) / 2),
            (riser * (step + 1)) / 2 + 0.41,
            z,
          ],
          architecture,
        );
    }
  }

  const backZ = rim.z - 2.15;
  const boardZ = rim.z - 0.47;
  const boardY = rim.y + 0.525;
  block([1.46, 0.074, 1.35], [rim.x, 0.037, backZ], rearSteel, 0.026);
  block([1.4, 0.047, 1.29], [rim.x, 0.089, backZ], rearBrushed, 0.012);
  block([1.33, 0.141, 1.225], [rim.x, 0.167, backZ], rearSteel, 0.029);
  block([1.212, 0.304, 1.076], [rim.x, 0.343, backZ + 0.063], padding, 0.073);
  block([1.035, 0.168, 0.028], [rim.x, 0.34, backZ + 0.604], padding, 0.012);
  for (const dx of [-0.628, 0.628]) {
    for (const dz of [-0.496, 0.496]) {
      cylinder(
        0.017,
        0.017,
        0.012,
        [rim.x + dx, 0.235, backZ + dz],
        rearBrushed,
        undefined,
        6,
      );
    }
  }

  // Extrude the side profile across the stand, narrowing it into the board shoe.
  const profile = new THREE.Shape();
  profile.moveTo(0.39, 0.39);
  profile.lineTo(0.39, 0.56);
  profile.lineTo(0.05, rim.y + 0.18);
  profile.lineTo(-0.56, rim.y + 0.94);
  profile.lineTo(-0.72, rim.y + 0.965);
  profile.lineTo(-1.59, boardY + 0.085);
  profile.lineTo(-1.59, boardY - 0.145);
  profile.lineTo(-0.64, rim.y + 0.613);
  profile.lineTo(-0.52, rim.y + 0.545);
  profile.lineTo(-0.27, rim.y + 0.134);
  profile.lineTo(0.04, 0.42);
  profile.closePath();
  const standWidth = 0.34;
  const cantilever = (bevelSegments: number) => {
    const geometry = new THREE.ExtrudeGeometry(profile, {
      depth: standWidth,
      bevelThickness: 0.023,
      bevelSize: 0.019,
      bevelSegments,
    });
    const vertices = geometry.getAttribute('position');
    for (let index = 0; index < vertices.count; index++) {
      const alongArm = THREE.MathUtils.smoothstep(
        -vertices.getX(index),
        0.4,
        1.59,
      );
      const upMast = THREE.MathUtils.smoothstep(
        vertices.getY(index),
        0.5,
        boardY - 0.175,
      );
      const sectionWidth = 1 - 0.32 * alongArm - 0.07 * upMast;
      vertices.setZ(
        index,
        (vertices.getZ(index) - standWidth / 2) * sectionWidth,
      );
    }
    geometry.computeVertexNormals();
    return geometry.rotateY(Math.PI / 2);
  };
  place(
    [cantilever(2), cantilever(1)],
    rearSteel,
    new THREE.Vector3(rim.x, 0, backZ),
  );

  // The removable upright pad and its bindings follow the slope of the steel.
  const padMount = new THREE.Matrix4()
    .makeRotationX(0.115)
    .setPosition(rim.x, 1.165, backZ - 0.157);
  block([0.493, 1.46, 0.485], [0, 0, 0], padding, 0.065, padMount);
  block([0.419, 1.35, 0.063], [0, 0, 0.23], padding, 0.028, padMount);
  for (const side of [-1, 1]) {
    block(
      [0.014, 1.248, 0.022],
      [side * 0.219, 0, 0.235],
      rearSteel,
      0.005,
      padMount,
    );
  }
  for (const y of [-0.515, 0.515]) {
    block([0.074, 0.032, 0.018], [0.184, y, 0.264], rearSteel, 0.006, padMount);
    block([0.034, 0.041, 0.02], [0.18, y, 0.272], rearBrushed, 0.007, padMount);
  }

  for (const dx of [-0.118, 0.118]) {
    beam(
      new THREE.Vector3(rim.x + dx, rim.y - 0.43, backZ + 0.08),
      new THREE.Vector3(rim.x + dx, boardY + 0.12, backZ + 0.86),
      0.022,
      rearBrushed,
    );
  }
  block([0.65, 0.58, 0.065], [rim.x, boardY, boardZ - 0.057], rearSteel, 0.018);
  block(
    [0.472, 0.404, 0.045],
    [rim.x, boardY, boardZ - 0.106],
    rearBrushed,
    0.013,
  );
  for (const dx of [-0.199, 0.199]) {
    for (const dy of [-0.151, 0.151]) {
      cylinder(
        0.017,
        0.017,
        0.018,
        [rim.x + dx, boardY + dy, boardZ - 0.133],
        rearBrushed,
        new THREE.Euler(Math.PI / 2, 0, 0),
        6,
      );
    }
  }
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
  block(
    [1.8, 0.047, 0.058],
    [rim.x, boardY - 0.574, boardZ + 0.005],
    steel,
    0.011,
  );
  for (const dx of [-0.845, 0.845]) {
    for (const dy of [-0.464, 0.464]) {
      block(
        [0.082, 0.078, 0.048],
        [rim.x + dx, boardY + dy, boardZ],
        brushed,
        0.011,
      );
      cylinder(
        0.022,
        0.022,
        0.009,
        [rim.x + dx, boardY + dy, boardZ + 0.027],
        steel,
        new THREE.Euler(Math.PI / 2, 0, 0),
        12,
      );
      cylinder(
        0.014,
        0.014,
        0.02,
        [rim.x + dx, boardY + dy, boardZ + 0.037],
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

  // A through-bolted load plate connects the breakaway mechanism to the board;
  // the lower gussets carry the overhang into the ring instead of floating below it.
  block(
    [0.19, 0.245, 0.024],
    [rim.x, rim.y + 0.12, boardZ + 0.036],
    steel,
    0.008,
  );
  for (const dx of [-0.063, 0.063]) {
    for (const dy of [0.045, 0.2]) {
      cylinder(
        0.017,
        0.017,
        0.018,
        [rim.x + dx, rim.y + dy, boardZ + 0.058],
        brushed,
        new THREE.Euler(Math.PI / 2, 0, 0),
        6,
      );
      cylinder(
        0.022,
        0.022,
        0.019,
        [rim.x + dx, rim.y + dy, boardZ + 0.018],
        brushed,
        new THREE.Euler(Math.PI / 2, 0, 0),
        12,
      );
    }
    const shape = new THREE.Shape();
    shape.moveTo(0, 0);
    shape.lineTo(0.19, 0.075);
    shape.lineTo(0, 0.075);
    shape.closePath();
    place(
      new THREE.ExtrudeGeometry(shape, { depth: 0.012, bevelEnabled: false }),
      orange,
      new THREE.Vector3(rim.x + dx, rim.y - 0.105, boardZ + 0.1),
      new THREE.Euler(0, -Math.PI / 2, 0),
    );
  }
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
    [
      new THREE.TorusGeometry(0.243, 0.018, 12, 72),
      new THREE.TorusGeometry(0.243, 0.018, 8, 40),
    ],
    orange,
    rim.clone(),
    new THREE.Euler(Math.PI / 2, 0, 0),
  );
  for (let hook = 0; hook < 12; hook += 1) {
    const angle = (hook / 12) * Math.PI * 2;
    place(
      [
        new THREE.TorusGeometry(0.012, 0.0037, 6, 12),
        new THREE.TorusGeometry(0.012, 0.0037, 4, 8),
      ],
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
      color: '#EEE6D6',
      roughness: 0.88,
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
  batches.set('nylon-net', {
    material: nylon,
    parts: [],
    farParts: [],
    castShadow: false,
    viewRole: 'basket',
  });
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
    const curve = new THREE.QuadraticBezierCurve3(start, middle, end);
    place(
      [
        new THREE.TubeGeometry(curve, 3, 0.0032, 6, false),
        new THREE.TubeGeometry(curve, 2, 0.0032, 4, false),
      ],
      'nylon-net',
      new THREE.Vector3(),
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
      const outward = new THREE.Vector3(
        knot.x - rim.x,
        0,
        knot.z - rim.z,
      ).normalize();
      const tangent = new THREE.Vector3(outward.z, 0, -outward.x);
      const wrap = new THREE.CatmullRomCurve3(
        Array.from({ length: 9 }, (_, point) => {
          const along = point / 8;
          const turn = along * Math.PI * 2;
          return new THREE.Vector3(0, (along - 0.5) * 0.01, 0)
            .addScaledVector(outward, Math.cos(turn) * 0.0035)
            .addScaledVector(tangent, Math.sin(turn) * 0.0035);
        }),
      );
      place(
        [
          new THREE.TubeGeometry(wrap, 8, 0.0022, 5, false),
          new THREE.OctahedronGeometry(0.0052).scale(0.93, 1.46, 0.93),
        ],
        'nylon-net',
        knot,
      );
    }
  }
  const lowerLoop = new THREE.CatmullRomCurve3(nodes.at(-1)!, true);
  const hemTurns = 18;
  const hemSegments = hemTurns * 6;
  const netBatch = batches.get('nylon-net')!;
  for (const phase of [0, Math.PI]) {
    const cord = new THREE.CatmullRomCurve3(
      Array.from({ length: hemSegments }, (_, point) => {
        const along = point / hemSegments;
        const turn = along * hemTurns * Math.PI * 2 + phase;
        const center = lowerLoop.getPoint(along);
        const outward = new THREE.Vector3(
          center.x - rim.x,
          0,
          center.z - rim.z,
        ).normalize();
        center.y += Math.sin(turn) * 0.0019;
        return center.addScaledVector(outward, Math.cos(turn) * 0.0019);
      }),
      true,
    );
    netBatch.parts.push(
      new THREE.TubeGeometry(cord, hemSegments, 0.00235, 5, true),
    );
  }
  netBatch.farParts.push(
    new THREE.TubeGeometry(lowerLoop, 30, 0.0032, 4, true),
  );

  const levels: {
    mesh: THREE.Mesh<THREE.BufferGeometry, THREE.Material>;
    near: THREE.BufferGeometry;
    far: THREE.BufferGeometry;
  }[] = [];
  function mergeParts(parts: THREE.BufferGeometry[], name: string) {
    const allIndexed = parts.every((geometry) => geometry.index !== null);
    const normalized = allIndexed
      ? parts
      : parts.map((geometry) =>
          geometry.index ? geometry.toNonIndexed() : geometry,
        );
    const geometry = mergeGeometries(normalized, false);
    for (const part of new Set([...parts, ...normalized])) part.dispose();
    parts.length = 0;
    if (!geometry)
      throw new Error(`Court hardware geometry failed to merge: ${name}`);
    geometry.computeBoundingSphere();
    if (name === 'nylon-net' && geometry.boundingSphere)
      geometry.boundingSphere.radius += 0.15;
    return own(geometry);
  }
  for (const [name, batch] of batches) {
    if (!batch.parts.length) continue;
    const near = mergeParts(batch.parts, name);
    const closeDetail = hasCloseDetail(name);
    let far = near;
    if (closeDetail) far = mergeParts(batch.farParts, name);
    else {
      for (const part of batch.farParts) part.dispose();
      batch.farParts.length = 0;
    }
    const mesh = new THREE.Mesh(near, batch.material);
    mesh.name = name;
    mesh.userData.viewRole = batch.viewRole;
    mesh.castShadow = batch.castShadow;
    mesh.receiveShadow = !name.startsWith('ceiling-') && name !== 'glass-panel';
    group.add(mesh);
    if (closeDetail) levels.push({ mesh, near, far });
    if (batch.viewRole === 'ceiling') ceilingMeshes.push(mesh);
    if (batch.viewRole === 'perimeter' || batch.viewRole === 'rear-support')
      cutawayMeshes.push({
        mesh,
        opacity: batch.material.opacity,
        transparent: batch.material.transparent,
        depthWrite: batch.material.depthWrite,
        castShadow: batch.castShadow,
      });
  }
  let detail: 'near' | 'far' = 'near';
  const cameraSpaceRim = new THREE.Vector3();

  return {
    group,
    setDetailForCamera(camera, viewportCSSHeight, quality = 'full') {
      if (!Number.isFinite(viewportCSSHeight) || viewportCSSHeight <= 0)
        return false;
      cameraSpaceRim.copy(rim).applyMatrix4(camera.matrixWorldInverse);
      const depth = Math.max(0.1, -cameraSpaceRim.z);
      const pixels =
        (0.486 * viewportCSSHeight * camera.projectionMatrix.elements[5]!) /
        (2 * depth);
      const bias =
        quality === 'density' ? 1.35 : quality === 'effects' ? 1.12 : 1;
      const next =
        detail === 'near'
          ? pixels < 52 * bias
            ? 'far'
            : 'near'
          : pixels > 82 * bias
            ? 'near'
            : 'far';
      if (next === detail) return false;
      detail = next;
      for (const level of levels) level.mesh.geometry = level[next];
      return true;
    },
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
        mesh.material.depthWrite = opacity === 1;
      }
    },
    setViewCutaway(value) {
      const cutaway = Number.isFinite(value)
        ? THREE.MathUtils.clamp(value, 0, 1)
        : 0;
      for (const original of cutawayMeshes) {
        const { mesh } = original;
        const transparent = cutaway > 0 || original.transparent;
        if (mesh.material.transparent !== transparent) {
          mesh.material.transparent = transparent;
          mesh.material.needsUpdate = true;
        }
        mesh.material.opacity = original.opacity * (1 - cutaway);
        mesh.material.depthWrite = cutaway === 0 && original.depthWrite;
        mesh.visible = cutaway < 1;
        // An alpha-blended stand must not leave an opaque shadow behind it.
        // The caller refreshes its cached shadow map when this state changes.
        mesh.castShadow = cutaway === 0 && original.castShadow;
      }
    },
  };
}
