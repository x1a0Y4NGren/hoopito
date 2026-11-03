import * as THREE from 'three';

type Point = readonly [number, number, number];
interface FloorLamp {
  readonly position: Point;
  readonly color: string;
  readonly intensity: number;
  readonly distance: number;
  readonly decay: number;
  readonly target?: Point;
  readonly angle?: number;
  readonly penumbra?: number;
}

/** Scene lights and cached floor irradiance share positions, colors and falloff. */
export const COURT_LIGHTING = {
  hemisphere: { skyColor: '#C8D7E3', groundColor: '#30271F', intensity: 0.32 },
  key: {
    position: [4, 10, 1],
    target: [0, 0, -2],
    color: '#FFF0DD',
    intensity: 135,
    distance: 48,
    decay: 1.8,
    angle: 0.62,
    penumbra: 0.7,
  },
  amber: {
    position: [-5, 7.9, -7],
    target: [0, 2, -3],
    color: '#E6B180',
    intensity: 92,
    distance: 40,
    decay: 1.8,
    angle: 0.8,
    penumbra: 0.85,
  },
  cool: {
    position: [7, 5, 5],
    color: '#B9D3EA',
    intensity: 65,
    distance: 20,
    decay: 2,
  },
  macro: {
    position: [3.5, 0.72, 3.6],
    target: [2.6, 0.13, 4.1],
    color: '#FFE4BE',
    intensity: 2.2,
    distance: 3.6,
    decay: 2,
    angle: 0.72,
    penumbra: 0.7,
  },
  ballRim: {
    position: [2.05, 0.2, 3.76],
    color: '#CE854F',
    intensity: 1.1,
    distance: 2.2,
    decay: 2,
  },
  environmentIntensity: 0.3,
} as const;

const lamps: readonly FloorLamp[] = [
  COURT_LIGHTING.key,
  COURT_LIGHTING.amber,
  COURT_LIGHTING.cool,
  COURT_LIGHTING.macro,
  COURT_LIGHTING.ballRim,
];
const colors = lamps.map((lamp) => new THREE.Color(lamp.color));
const ambient = new THREE.Color(
  COURT_LIGHTING.hemisphere.skyColor,
).multiplyScalar(COURT_LIGHTING.hemisphere.intensity / Math.PI);
export const FLOOR_Y = 0.004;

/** Texture reference stays in world metres even when the surrounding floor grows. */
export const FLOOR_TEXTURE_LAYOUT = {
  width: 28,
  length: 42,
  centerZ: 4,
  repeatX: 20,
  repeatZ: 30,
} as const;

function lampAt(lamp: FloorLamp, x: number, z: number) {
  const dx = lamp.position[0] - x;
  const dy = lamp.position[1] - FLOOR_Y;
  const dz = lamp.position[2] - z;
  const length = Math.hypot(dx, dy, dz);
  const cutoff = Math.max(0, 1 - (length / lamp.distance) ** 4) ** 2;
  let attenuation = cutoff / Math.max(length ** lamp.decay, 0.01);
  if (lamp.target) {
    const axis = lamp.position.map(
      (value, index) => value - lamp.target![index]!,
    ) as unknown as Point;
    const cosine =
      (dx * axis[0] + dy * axis[1] + dz * axis[2]) /
      (length * Math.hypot(...axis));
    const cone = Math.cos(lamp.angle!);
    const penumbra = Math.cos(lamp.angle! * (1 - lamp.penumbra!));
    const along = THREE.MathUtils.clamp(
      (cosine - cone) / (penumbra - cone),
      0,
      1,
    );
    attenuation *= along * along * (3 - 2 * along);
  }
  const radiance = lamp.intensity * attenuation;
  return { diffuse: (radiance * Math.max(0, dy / length)) / Math.PI, radiance };
}

/** Only key and amber vary with the story; fixed local fill remains spatially bounded. */
export function sampleFloorLighting(x: number, z: number, strength = 1) {
  const dynamic: [number, number, number] = [0, 0, 0];
  const fixed: [number, number, number] = [ambient.r, ambient.g, ambient.b];
  const specular: [number, number] = [0, 0];
  lamps.forEach((lamp, index) => {
    const sample = lampAt(lamp, x, z);
    const target = index < 2 ? dynamic : fixed;
    const color = colors[index]!;
    target[0] += sample.diffuse * color.r;
    target[1] += sample.diffuse * color.g;
    target[2] += sample.diffuse * color.b;
    if (index < 2) specular[index] = sample.radiance * strength;
  });
  for (let index = 0; index < 3; index++) dynamic[index] *= strength;
  return { dynamic, fixed, specular };
}

/** Density spends the broad flat-floor varnish response once per existing vertex. */
export const floorVarnishVertexGLSL = /* glsl */ `
  uniform float uFloorDensity;
  uniform float uFloorLight;
  uniform vec3 uFloorFlatNormal;
  uniform vec3 uFloorKeyPosition;
  uniform vec3 uFloorAmberPosition;
  uniform vec3 uFloorKeyColor;
  uniform vec3 uFloorAmberColor;
  varying vec3 vFloorVertexVarnish;
  vec3 floorVertexVarnish(vec3 worldPosition, vec2 specular) {
    if (uFloorDensity < 0.5) return vec3(0.0);
    vec3 viewDirection = normalize(cameraPosition - worldPosition);
    vec3 keyHalf = normalize(normalize(uFloorKeyPosition - worldPosition) + viewDirection);
    vec3 amberHalf = normalize(normalize(uFloorAmberPosition - worldPosition) + viewDirection);
    float key = pow(max(dot(uFloorFlatNormal, keyHalf), 0.0), 18.0) * specular.x;
    float amber = pow(max(dot(uFloorFlatNormal, amberHalf), 0.0), 18.0) * specular.y;
    float fresnel = pow(1.0 - max(dot(uFloorFlatNormal, viewDirection), 0.0), 5.0);
    return min((uFloorKeyColor * key + uFloorAmberColor * amber) * (0.035 + 0.06 * fresnel), vec3(0.24)) * uFloorLight;
  }
`;

/** World coordinates keep the varnish and grain aligned between floor and paint. */
export const floorSurfaceGLSL = /* glsl */ `
  uniform float uFloorDensity;
  uniform float uFloorLight;
  uniform sampler2D uFloorDetail;
  uniform float uFloorHasDetail;
  uniform vec2 uFloorDetailRepeat;
  uniform vec4 uFloorTextureFrame;
  uniform vec3 uFloorKeyPosition;
  uniform vec3 uFloorAmberPosition;
  uniform vec3 uFloorKeyColor;
  uniform vec3 uFloorAmberColor;
  varying vec3 vFloorDynamic;
  varying vec3 vFloorFixed;
  varying vec2 vFloorSpecular;
  varying vec3 vFloorPosition;
  varying vec3 vFloorVertexVarnish;
  vec3 floorDetail() {
    vec2 uv = (vec2(vFloorPosition.x, -vFloorPosition.z) + uFloorTextureFrame.xy) / uFloorTextureFrame.zw;
    if (uFloorHasDetail < 0.5) return vec3(0.5, 0.5, 0.58);
    return texture2D(uFloorDetail, uv * uFloorDetailRepeat).rgb;
  }
  vec3 floorNormal(vec3 detail) {
    vec2 slope = (detail.rg * 2.0 - 1.0) * 0.17;
    return normalize(vec3(slope.x, 1.0, -slope.y));
  }
  vec3 floorIrradiance(vec3 normal) {
    return (vFloorDynamic * uFloorLight + vFloorFixed) * clamp(normal.y + normal.x * 0.1 + normal.z * 0.08, 0.94, 1.06);
  }
  float floorLobe(vec3 lamp, vec3 normal, vec3 viewDirection, float roughness) {
    vec3 halfDirection = normalize(normalize(lamp - vFloorPosition) + viewDirection);
    return pow(max(dot(normal, halfDirection), 0.0), mix(58.0, 18.0, roughness));
  }
  vec3 floorVarnish(vec3 normal, float roughness) {
    vec3 viewDirection = normalize(cameraPosition - vFloorPosition);
    float fresnel = pow(1.0 - max(dot(normal, viewDirection), 0.0), 5.0);
    float key = floorLobe(uFloorKeyPosition, normal, viewDirection, roughness) * vFloorSpecular.x;
    float amber = floorLobe(uFloorAmberPosition, normal, viewDirection, roughness) * vFloorSpecular.y;
    return min((uFloorKeyColor * key + uFloorAmberColor * amber) * (0.035 + 0.06 * fresnel), vec3(0.24)) * uFloorLight;
  }
  vec3 floorSurface(vec3 albedo) {
    // Uniform quality branching skips the data texture, normal reconstruction
    // and view-dependent powers for every density fragment. Albedo stays sharp.
    if (uFloorDensity > 0.5) {
      return albedo * (vFloorDynamic * uFloorLight + vFloorFixed) + vFloorVertexVarnish;
    }
    vec3 detail = floorDetail();
    vec3 normal = floorNormal(detail);
    return albedo * floorIrradiance(normal) + floorVarnish(normal, detail.b);
  }
`;
