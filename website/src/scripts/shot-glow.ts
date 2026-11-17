import * as THREE from 'three';
import type { CourtPoint, SceneQuality } from './scene-contract.ts';
import { shotFlightPoint } from './shot-motion.ts';
import { SHOT_TIMING } from './shot-timing.ts';
import {
  SHOT_VISUALS,
  shotVisualQuality,
  trailWindow,
  worldUnitsPerPixel,
} from './shot-visuals.ts';
import { trailVertex, trailFragment } from './shaders/court.ts';

type EffectMesh = THREE.Mesh<THREE.BufferGeometry, THREE.ShaderMaterial>;
const viewPoint = new THREE.Vector3();
const size = (
  object: THREE.Object3D,
  camera: THREE.PerspectiveCamera,
  height: number,
) => {
  object.getWorldPosition(viewPoint).applyMatrix4(camera.matrixWorldInverse);
  return worldUnitsPerPixel(-viewPoint.z, camera.fov, height);
};

function trailGeometry(point: CourtPoint, segments: number) {
  const positions: number[] = [],
    tangents: number[] = [],
    uvs: number[] = [],
    indices: number[] = [];
  for (let index = 0; index <= segments; index++) {
    const progress = index / segments;
    const center = shotFlightPoint(point, progress);
    const before = shotFlightPoint(point, Math.max(0, progress - 0.001));
    const after = shotFlightPoint(point, Math.min(1, progress + 0.001));
    const tangent = new THREE.Vector3(...after)
      .sub(new THREE.Vector3(...before))
      .normalize();
    for (let side = 0; side < 2; side++) {
      positions.push(...center);
      tangents.push(...tangent.toArray());
      uvs.push(progress, side);
    }
    if (index < segments) {
      const start = index * 2;
      indices.push(
        start,
        start + 1,
        start + 2,
        start + 1,
        start + 3,
        start + 2,
      );
    }
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute(
    'position',
    new THREE.Float32BufferAttribute(positions, 3),
  );
  geometry.setAttribute(
    'tangent',
    new THREE.Float32BufferAttribute(tangents, 3),
  );
  geometry.setAttribute('uv', new THREE.Float32BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  return geometry;
}

function ribbonMaterial(halo: boolean) {
  return new THREE.ShaderMaterial({
    uniforms: {
      uHead: { value: 0 },
      uTail: { value: 0 },
      uOpacity: { value: 0 },
      uViewport: { value: new THREE.Vector2(1, 1) },
      uWidthPixels: {
        value: halo
          ? SHOT_VISUALS.trailHaloPixels
          : SHOT_VISUALS.trailCorePixels,
      },
      uHalo: { value: halo ? 1 : 0 },
    },
    vertexShader: trailVertex,
    fragmentShader: trailFragment,
    transparent: true,
    depthWrite: false,
    side: THREE.DoubleSide,
    toneMapped: false,
  });
}

/** Two local draws share one arc; the shader reveals only the last 220ms. */
export function createShotTrail(point: CourtPoint) {
  let geometry = trailGeometry(point, 64);
  const group = new THREE.Group();
  group.name = 'shot-trail';
  const halo: EffectMesh = new THREE.Mesh(geometry, ribbonMaterial(true));
  const core: EffectMesh = new THREE.Mesh(geometry, ribbonMaterial(false));
  halo.name = 'shot-trail-halo';
  core.name = 'shot-trail-core';
  halo.frustumCulled = core.frustumCulled = false;
  halo.renderOrder = 8;
  core.renderOrder = 9;
  group.add(halo, core);
  let opacity = 0,
    haloOpacity = 0.35,
    segments = 64,
    disposed = false;
  return Object.assign(group, {
    core,
    halo,
    setQuality(quality: SceneQuality) {
      const settings = shotVisualQuality(quality);
      haloOpacity = settings.haloOpacity;
      halo.material.uniforms.uOpacity!.value = opacity * haloOpacity;
      if (settings.trailSegments !== segments) {
        geometry.dispose();
        segments = settings.trailSegments;
        geometry = trailGeometry(point, segments);
        core.geometry = halo.geometry = geometry;
      }
    },
    setTime(time: number, nextOpacity: number) {
      const window = trailWindow(time, SHOT_TIMING.flight);
      opacity = nextOpacity;
      group.visible = nextOpacity > 0 && window.head > window.tail;
      for (const mesh of [core, halo]) {
        mesh.material.uniforms.uHead!.value = window.head;
        mesh.material.uniforms.uTail!.value = window.tail;
        mesh.material.uniforms.uOpacity!.value =
          nextOpacity * (mesh === halo ? haloOpacity : 1);
      }
    },
    updateView(
      _camera: THREE.PerspectiveCamera,
      width: number,
      height: number,
      _pixelRatio: number,
    ) {
      for (const mesh of [core, halo])
        mesh.material.uniforms.uViewport!.value.set(width, height);
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      group.removeFromParent();
      geometry.dispose();
      core.material.dispose();
      halo.material.dispose();
    },
  });
}

const markerFragment = /* glsl */ `
  uniform vec3 uColor;
  uniform float uExtent;
  uniform float uStrokePixels;
  uniform float uHaloPixels;
  uniform float uHaloOpacity;
  uniform float uPixelRatio;
  varying vec2 vUv;
  void main() {
    vec2 point = (vUv * 2.0 - 1.0) * uExtent;
    float radial = length(point);
    float ringDistance = abs(radial - 0.34);
    float ringPixel = max(length(vec2(dFdx(radial), dFdy(radial))) * uPixelRatio, 0.00001);
    float ring = 1.0 - smoothstep(uStrokePixels * 0.5 - 0.5, uStrokePixels * 0.5 + 0.5, ringDistance / ringPixel);
    vec2 tickPoint = vec2(min(abs(point.x), abs(point.y)), max(abs(point.x), abs(point.y)) - 0.47);
    vec2 tickDelta = abs(tickPoint) - vec2(0.025, 0.08);
    float tickDistance = length(max(tickDelta, 0.0)) + min(max(tickDelta.x, tickDelta.y), 0.0);
    float tick = 1.0 - smoothstep(-ringPixel * 0.5, ringPixel * 0.5, tickDistance);
    float dot = 1.0 - smoothstep(0.065 - ringPixel * 0.5, 0.065 + ringPixel * 0.5, radial);
    float core = max(ring, max(tick, dot));
    float glowDistance = min(ringDistance, max(0.0, radial - 0.065)) / ringPixel;
    float haloRadius = max(uHaloPixels * 0.5, 0.36 / ringPixel + 1.0);
    float glow = exp(-glowDistance * glowDistance / max(1.0, uHaloPixels * uHaloPixels * 0.025)) * uHaloOpacity;
    glow *= 1.0 - smoothstep(haloRadius * 0.82, haloRadius, radial / ringPixel);
    float alpha = max(core, glow);
    if (alpha < 0.002) discard;
    vec3 color = mix(uColor, mix(uColor, vec3(1.0), 0.3), core);
    color = mix(color, mix(uColor, vec3(1.0), 0.8), dot);
    gl_FragColor = vec4(color, alpha);
    #include <colorspace_fragment>
  }
`;

/** Floor-aligned marker: the unlit core and derivative-sized stroke never pulse. */
export function createShotMarker(color: string) {
  const group = new THREE.Group();
  const geometry = new THREE.PlaneGeometry(2, 2);
  const surface = new THREE.ShaderMaterial({
    uniforms: {
      uColor: { value: new THREE.Color(color) },
      uExtent: { value: 1 },
      uStrokePixels: { value: SHOT_VISUALS.markerStrokePixels },
      uHaloPixels: { value: SHOT_VISUALS.markerHaloPixels },
      uHaloOpacity: { value: 0.35 },
      uPixelRatio: { value: 1 },
    },
    vertexShader:
      'varying vec2 vUv; void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
    fragmentShader: markerFragment,
    transparent: true,
    depthWrite: false,
    toneMapped: false,
  });
  const core: EffectMesh = new THREE.Mesh(geometry, surface);
  core.name = 'shot-marker-core';
  core.rotation.x = -Math.PI / 2;
  core.renderOrder = 10;
  core.frustumCulled = false;
  group.add(core);
  let disposed = false;
  return Object.assign(group, {
    core,
    setQuality(quality: SceneQuality) {
      surface.uniforms.uHaloOpacity!.value =
        shotVisualQuality(quality).haloOpacity;
    },
    updateView(
      camera: THREE.PerspectiveCamera,
      _width: number,
      height: number,
      pixelRatio: number,
    ) {
      const extent = Math.max(
        0.57,
        size(group, camera, height) * SHOT_VISUALS.markerHaloPixels * 0.5,
      );
      core.scale.set(extent, extent, 1);
      surface.uniforms.uExtent!.value = extent;
      surface.uniforms.uPixelRatio!.value = pixelRatio;
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      group.removeFromParent();
      geometry.dispose();
      surface.dispose();
    },
  });
}

/** A dedicated silhouette and billboard halo leave the leather body intact. */
export function createFlightBallGlow(
  body: THREE.Mesh<THREE.SphereGeometry, THREE.MeshStandardMaterial>,
) {
  const group = new THREE.Group();
  const outlineSurface = new THREE.ShaderMaterial({
    uniforms: {
      uViewport: { value: new THREE.Vector2(1, 1) },
      uWidthPixels: { value: 1.5 },
    },
    vertexShader: /* glsl */ `
      uniform vec2 uViewport; uniform float uWidthPixels;
      void main() {
        vec4 center = modelViewMatrix * vec4(position, 1.0);
        vec3 direction = normalize(normalMatrix * normal);
        gl_Position = projectionMatrix * center;
        gl_Position.xy += normalize(direction.xy + vec2(0.000001)) * uWidthPixels * 2.0 / uViewport * gl_Position.w;
      }`,
    fragmentShader: /* glsl */ `void main() {
      gl_FragColor = vec4(1.0, 0.76, 0.4, 0.95);
      #include <colorspace_fragment>
    }`,
    side: THREE.BackSide,
    transparent: true,
    depthWrite: false,
    toneMapped: false,
  });
  const outline: EffectMesh = new THREE.Mesh(body.geometry, outlineSurface);
  outline.name = 'shot-ball-outline';
  outline.frustumCulled = false;
  const haloGeometry = new THREE.PlaneGeometry(2, 2);
  const haloSurface = new THREE.ShaderMaterial({
    uniforms: {
      uViewport: { value: new THREE.Vector2(1, 1) },
      uExtentPixels: { value: 20 },
      uRadiusPixels: { value: 2 },
      uHaloOpacity: { value: 0.35 },
      uHaloPixels: { value: SHOT_VISUALS.ballHaloPixels },
    },
    vertexShader: /* glsl */ `uniform vec2 uViewport; uniform float uExtentPixels; varying vec2 vPoint;
      void main() { vPoint = position.xy * uExtentPixels;
        gl_Position = projectionMatrix * modelViewMatrix * vec4(0.0, 0.0, 0.0, 1.0);
        gl_Position.xy += position.xy * uExtentPixels * 2.0 / uViewport * gl_Position.w;
      }`,
    fragmentShader: /* glsl */ `uniform float uRadiusPixels; uniform float uHaloPixels; uniform float uHaloOpacity; varying vec2 vPoint;
      void main() { float radius = length(vPoint);
        float extent = max(uRadiusPixels + 2.0, uHaloPixels * 0.5);
        float distance = max(0.0, radius - uRadiusPixels);
        float halo = exp(-3.0 * distance * distance / max(1.0, (extent - uRadiusPixels) * (extent - uRadiusPixels)));
        halo *= 1.0 - smoothstep(extent * 0.88, extent, radius);
        gl_FragColor = vec4(1.0, 0.36, 0.08, halo * uHaloOpacity);
        #include <colorspace_fragment>
      }`,
    transparent: true,
    depthWrite: false,
    toneMapped: false,
  });
  const halo: EffectMesh = new THREE.Mesh(haloGeometry, haloSurface);
  halo.name = 'shot-ball-halo';
  halo.frustumCulled = false;
  halo.renderOrder = 7;
  group.add(halo, outline);
  let disposed = false;
  return Object.assign(group, {
    outline,
    halo,
    setQuality(quality: SceneQuality) {
      haloSurface.uniforms.uHaloOpacity!.value =
        shotVisualQuality(quality).haloOpacity;
    },
    updateView(
      camera: THREE.PerspectiveCamera,
      width: number,
      height: number,
      _pixelRatio: number,
    ) {
      outline.geometry = body.geometry;
      outline.rotation.copy(body.rotation);
      outlineSurface.uniforms.uViewport!.value.set(width, height);
      haloSurface.uniforms.uViewport!.value.set(width, height);
      const radiusPixels = 0.12 / size(group, camera, height);
      haloSurface.uniforms.uRadiusPixels!.value = radiusPixels;
      haloSurface.uniforms.uExtentPixels!.value = Math.max(
        radiusPixels + 2,
        SHOT_VISUALS.ballHaloPixels * 0.5,
      );
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      group.removeFromParent();
      outlineSurface.dispose();
      haloSurface.dispose();
      haloGeometry.dispose();
    },
  });
}
