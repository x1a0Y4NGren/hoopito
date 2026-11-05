import * as THREE from 'three';
import type { SceneQuality } from './scene-contract';

import {
  COURT_LIGHTING,
  FLOOR_TEXTURE_LAYOUT,
  FLOOR_Y,
  floorSurfaceGLSL,
  floorVarnishVertexGLSL,
  sampleFloorLighting,
} from './court-lighting.ts';
export { sampleFloorLighting } from './court-lighting.ts';

type Owner = <T extends { dispose(): void }>(resource: T) => T;

/** One mesh: retain the fine court grid and extend only its outermost border. */
function createFloorGeometry() {
  const extent = 256;
  const columns = 64;
  const rows = 96;
  const reference = FLOOR_TEXTURE_LAYOUT;
  const geometry = new THREE.PlaneGeometry(extent, extent, columns, rows);
  const position = geometry.getAttribute('position');
  const uv = geometry.getAttribute('uv');
  for (let vertex = 0; vertex < position.count; vertex++) {
    const column = vertex % (columns + 1);
    const row = Math.floor(vertex / (columns + 1));
    const x =
      column === 0
        ? -extent / 2
        : column === columns
          ? extent / 2
          : (column * reference.width) / columns - reference.width / 2;
    const y =
      row === 0
        ? extent / 2
        : row === rows
          ? -extent / 2
          : reference.length / 2 - (row * reference.length) / rows;
    position.setXY(vertex, x, y);
    // Albedo and painted surface detail share the original reference and phase.
    // UVs intentionally extend beyond 0–1; RepeatWrapping preserves board width.
    uv.setXY(
      vertex,
      (x + reference.width / 2) / reference.width,
      (y + reference.length / 2) / reference.length,
    );
  }
  return geometry;
}

/** One-time irradiance attributes are used by both surface materials. */
function cacheLighting(geometry: THREE.PlaneGeometry, centerZ: number) {
  const position = geometry.getAttribute('position');
  const dynamic = new Float32Array(position.count * 3);
  const fixed = new Float32Array(position.count * 3);
  const specular = new Float32Array(position.count * 2);
  for (let vertex = 0; vertex < position.count; vertex++) {
    const light = sampleFloorLighting(
      position.getX(vertex),
      centerZ - position.getY(vertex),
    );
    dynamic.set(light.dynamic, vertex * 3);
    fixed.set(light.fixed, vertex * 3);
    specular.set(light.specular, vertex * 2);
  }
  geometry.setAttribute('aFloorDynamic', new THREE.BufferAttribute(dynamic, 3));
  geometry.setAttribute('aFloorFixed', new THREE.BufferAttribute(fixed, 3));
  geometry.setAttribute(
    'aFloorSpecular',
    new THREE.BufferAttribute(specular, 2),
  );
}

/** Cached diffuse lighting plus two bounded view-dependent varnish highlights. */
export function createCourtFloor({
  own,
  mapleMap,
  detailMap,
  rim,
}: {
  own: Owner;
  mapleMap: THREE.Texture;
  detailMap?: THREE.Texture;
  rim: THREE.Vector3;
}) {
  const textureLayout = FLOOR_TEXTURE_LAYOUT;
  mapleMap.wrapS = mapleMap.wrapT = THREE.RepeatWrapping;
  mapleMap.repeat.set(textureLayout.repeatX, textureLayout.repeatZ);
  if (detailMap) {
    detailMap.colorSpace = THREE.NoColorSpace;
    detailMap.wrapS = detailMap.wrapT = THREE.RepeatWrapping;
    detailMap.repeat.copy(mapleMap.repeat);
  }
  const geometry = own(createFloorGeometry());
  cacheLighting(geometry, textureLayout.centerZ);
  const paintGeometry = own(new THREE.PlaneGeometry(15, 14, 36, 34));
  cacheLighting(paintGeometry, 0);
  const strength = { value: 1 };
  const density = { value: 0 };
  const paintUniforms = {
    uFloorDensity: density,
    uFloorLight: strength,
    uFloorFlatNormal: { value: new THREE.Vector3(0, 1, 0) },
    uFloorDetail: { value: detailMap ?? mapleMap },
    uFloorHasDetail: { value: detailMap ? 1 : 0 },
    uFloorDetailRepeat: { value: mapleMap.repeat },
    uFloorTextureFrame: {
      value: new THREE.Vector4(
        textureLayout.width / 2,
        textureLayout.centerZ + textureLayout.length / 2,
        textureLayout.width,
        textureLayout.length,
      ),
    },
    uFloorKeyPosition: {
      value: new THREE.Vector3(...COURT_LIGHTING.key.position),
    },
    uFloorAmberPosition: {
      value: new THREE.Vector3(...COURT_LIGHTING.amber.position),
    },
    uFloorKeyColor: { value: new THREE.Color(COURT_LIGHTING.key.color) },
    uFloorAmberColor: { value: new THREE.Color(COURT_LIGHTING.amber.color) },
  };
  const surface = own(
    new THREE.MeshBasicMaterial({
      color: '#C6BBAC',
      map: mapleMap,
      toneMapped: true,
    }),
  );
  surface.customProgramCacheKey = () => 'hoopito-cached-maple-light-v4';
  surface.onBeforeCompile = (shader) => {
    Object.assign(shader.uniforms, paintUniforms);
    shader.vertexShader = shader.vertexShader
      .replace(
        '#include <common>',
        `#include <common>
        attribute vec3 aFloorDynamic;
        attribute vec3 aFloorFixed;
        attribute vec2 aFloorSpecular;
        varying vec3 vFloorDynamic;
        varying vec3 vFloorFixed;
        varying vec2 vFloorSpecular;
        varying vec3 vFloorPosition;
${floorVarnishVertexGLSL}`,
      )
      .replace(
        '#include <worldpos_vertex>',
        `#include <worldpos_vertex>
        vFloorDynamic = aFloorDynamic;
        vFloorFixed = aFloorFixed;
        vFloorSpecular = aFloorSpecular;
        vFloorPosition = (modelMatrix * vec4(transformed, 1.0)).xyz;
        vFloorVertexVarnish = floorVertexVarnish(vFloorPosition, aFloorSpecular);`,
      );
    shader.fragmentShader = shader.fragmentShader
      .replace(
        '#include <common>',
        `#include <common>
${floorSurfaceGLSL}`,
      )
      .replace(
        '#include <opaque_fragment>',
        `
        outgoingLight = floorSurface(diffuseColor.rgb);
        #include <opaque_fragment>`,
      );
  };
  const mesh = new THREE.Mesh(geometry, surface);
  mesh.name = 'cached-maple-floor';
  mesh.rotation.x = -Math.PI / 2;
  mesh.position.set(0, FLOOR_Y, textureLayout.centerZ);
  mesh.receiveShadow = false;

  const shadow = own(
    new THREE.ShaderMaterial({
      uniforms: { uBaseShadow: { value: 1 } },
      vertexShader: `varying vec2 vUv;
      void main() {
        vUv = uv;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
      }`,
      fragmentShader: `varying vec2 vUv;
      uniform float uBaseShadow;
      void main() {
        vec2 edge = max(abs((vUv - 0.5) * 3.6) - vec2(0.68, 0.59), 0.0);
        float contact = exp(-dot(edge, edge) * 5.2);
        float bounds = 1.0 - smoothstep(0.46, 0.5, max(abs(vUv.x - 0.5), abs(vUv.y - 0.5)));
        gl_FragColor = vec4(0.002, 0.002, 0.002, contact * bounds * 0.5 * uBaseShadow);
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
  contact.position.set(rim.x, textureLayout.centerZ - (rim.z - 2.15), 0.005);
  mesh.add(contact);

  return {
    mesh,
    paintGeometry,
    paintUniforms,
    setQuality(quality: SceneQuality) {
      density.value = quality === 'density' ? 1 : 0;
    },
    setViewCutaway(value: number) {
      const amount = Number.isFinite(value)
        ? THREE.MathUtils.clamp(value, 0, 1)
        : 0;
      shadow.uniforms.uBaseShadow!.value = 1 - amount;
      contact.visible = amount < 1;
    },
    setLight(value: number) {
      strength.value = Number.isFinite(value)
        ? THREE.MathUtils.clamp(value, 0, 1.5)
        : 1;
    },
  };
}
