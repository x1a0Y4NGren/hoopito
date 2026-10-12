import * as THREE from 'three';

type Point = readonly [number, number, number];
type Owner = <T extends { dispose(): void }>(resource: T) => T;

interface FloorLamp {
  position: Point;
  color: THREE.Color;
  intensity: number;
  distance: number;
  decay: number;
  target?: Point;
  angle?: number;
  penumbra?: number;
}

const lamps: readonly FloorLamp[] = [
  {
    position: [4, 10, 1],
    target: [0, 0, -2],
    color: new THREE.Color('#FFF0DF'),
    intensity: 130,
    distance: 48,
    decay: 1.8,
    angle: 0.45,
    penumbra: 0.78,
  },
  {
    position: [-5, 7.9, -7],
    target: [0, 2, -3],
    color: new THREE.Color('#DE783F'),
    intensity: 125,
    distance: 40,
    decay: 1.8,
    angle: 0.68,
    penumbra: 0.85,
  },
  {
    position: [7, 5, 5],
    color: new THREE.Color('#A7BBC7'),
    intensity: 38,
    distance: 20,
    decay: 2,
  },
  {
    position: [3.5, 0.72, 3.6],
    target: [2.6, 0.13, 4.1],
    color: new THREE.Color('#FFE4BE'),
    intensity: 1.45,
    distance: 3.6,
    decay: 2,
    angle: 0.72,
    penumbra: 0.7,
  },
  {
    position: [2.05, 0.2, 3.76],
    color: new THREE.Color('#CE692D'),
    intensity: 1.1,
    distance: 2.2,
    decay: 2,
  },
];
const ambient = new THREE.Color('#BDCCD7').multiplyScalar(0.14 / Math.PI);
const floorY = 0.004;

function lampAt(lamp: FloorLamp, x: number, z: number) {
  const dx = lamp.position[0] - x;
  const dy = lamp.position[1] - floorY;
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

/** Static luminaires are sampled once; only the two story lights vary at runtime. */
export function sampleFloorLighting(x: number, z: number) {
  const dynamic: [number, number, number] = [0, 0, 0];
  const fixed: [number, number, number] = [ambient.r, ambient.g, ambient.b];
  const specular: [number, number] = [0, 0];
  lamps.forEach((lamp, index) => {
    const sample = lampAt(lamp, x, z);
    const target = index < 2 ? dynamic : fixed;
    target[0] += sample.diffuse * lamp.color.r;
    target[1] += sample.diffuse * lamp.color.g;
    target[2] += sample.diffuse * lamp.color.b;
    if (index < 2) specular[index] = sample.radiance;
  });
  return { dynamic, fixed, specular };
}

/** Cached diffuse lighting plus two bounded view-dependent varnish highlights. */
export function createCourtFloor({
  own,
  mapleMap,
  rim,
}: {
  own: Owner;
  mapleMap: THREE.Texture;
  rim: THREE.Vector3;
}) {
  mapleMap.repeat.set(28 / 2.8, 42 / 2.8);
  const geometry = own(new THREE.PlaneGeometry(28, 42, 64, 96));
  const position = geometry.getAttribute('position');
  const colors = new Float32Array(position.count * 3);
  const fixed = new Float32Array(position.count * 3);
  const specular = new Float32Array(position.count * 2);
  for (let vertex = 0; vertex < position.count; vertex += 1) {
    const light = sampleFloorLighting(
      position.getX(vertex),
      4 - position.getY(vertex),
    );
    colors.set(light.dynamic, vertex * 3);
    fixed.set(light.fixed, vertex * 3);
    specular.set(light.specular, vertex * 2);
  }
  geometry.setAttribute('color', new THREE.BufferAttribute(colors, 3));
  geometry.setAttribute('aFloorFixed', new THREE.BufferAttribute(fixed, 3));
  geometry.setAttribute(
    'aFloorSpecular',
    new THREE.BufferAttribute(specular, 2),
  );
  const strength = { value: 1 };
  const surface = own(
    new THREE.MeshBasicMaterial({
      color: '#756B62',
      map: mapleMap,
      vertexColors: true,
      toneMapped: true,
    }),
  );
  surface.customProgramCacheKey = () => 'hoopito-cached-maple-light-v1';
  surface.onBeforeCompile = (shader) => {
    shader.uniforms.uFloorLight = strength;
    shader.vertexShader = shader.vertexShader
      .replace(
        '#include <common>',
        `#include <common>
        attribute vec3 aFloorFixed;
        attribute vec2 aFloorSpecular;
        varying vec3 vFloorFixed;
        varying vec2 vFloorSpecular;
        varying vec3 vFloorPosition;`,
      )
      .replace(
        '#include <worldpos_vertex>',
        `#include <worldpos_vertex>
        vFloorFixed = aFloorFixed;
        vFloorSpecular = aFloorSpecular;
        vFloorPosition = (modelMatrix * vec4(transformed, 1.0)).xyz;`,
      );
    shader.fragmentShader = shader.fragmentShader
      .replace(
        '#include <common>',
        `#include <common>
        uniform float uFloorLight;
        varying vec3 vFloorFixed;
        varying vec2 vFloorSpecular;
        varying vec3 vFloorPosition;
        float varnish(vec3 lamp, vec3 viewDirection) {
          vec3 halfDirection = normalize(normalize(lamp - vFloorPosition) + viewDirection);
          return pow(max(halfDirection.y, 0.0), 26.0);
        }`,
      )
      .replace(
        '#include <color_fragment>',
        'diffuseColor.rgb *= vColor.rgb * uFloorLight + vFloorFixed;',
      )
      .replace(
        '#include <opaque_fragment>',
        `
        vec3 floorView = normalize(cameraPosition - vFloorPosition);
        float keySheen = varnish(vec3(4.0, 10.0, 1.0), floorView) * vFloorSpecular.x;
        float amberSheen = varnish(vec3(-5.0, 7.9, -7.0), floorView) * vFloorSpecular.y;
        vec3 sheen = vec3(0.085, 0.072, 0.060) * keySheen
          + vec3(0.095, 0.032, 0.012) * amberSheen;
        // Fine albedo variation also breaks up varnish without another texture fetch.
        float grain = 0.92 + 0.08 * sampledDiffuseColor.r;
        outgoingLight += min(sheen, vec3(0.32)) * grain * uFloorLight;
        #include <opaque_fragment>`,
      );
  };
  const mesh = new THREE.Mesh(geometry, surface);
  mesh.name = 'cached-maple-floor';
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(0, floorY, 4);
  mesh.receiveShadow = false;

  const shadow = own(
    new THREE.ShaderMaterial({
      vertexShader: `varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }`,
      fragmentShader: `varying vec2 vUv;
      void main() {
        vec2 edge = max(abs((vUv - 0.5) * 3.6) - vec2(0.68, 0.59), 0.0);
        float contact = exp(-dot(edge, edge) * 5.2);
        float bounds = 1.0 - smoothstep(0.46, 0.5, max(abs(vUv.x - 0.5), abs(vUv.y - 0.5)));
        gl_FragColor = vec4(0.002, 0.002, 0.002, contact * bounds * 0.5);
        #include <tonemapping_fragment>
        #include <colorspace_fragment>
      }`,
      transparent: true,
      depthWrite: false,
      toneMapped: true,
    }),
  );
  const contact = new THREE.Mesh(
    own(new THREE.PlaneGeometry(3.6, 3.6)),
    shadow,
  );
  contact.name = 'cached-basket-base-shadow';
  // Child coordinates share the plane axes; the floor rotation places it at y=.009.
  contact.position.set(rim.x, 4 - (rim.z - 2.15), 0.005);
  mesh.add(contact);

  return {
    mesh,
    setLight(value: number) {
      strength.value = Number.isFinite(value)
        ? THREE.MathUtils.clamp(value, 0, 1.5)
        : 1;
    },
  };
}
