import {
  Color,
  Vector2,
  Vector4,
  type WebGLRenderer,
  type WebGLRenderTarget,
} from 'three';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import type { GlassSurface, SceneRegion } from './scene-contract';
import {
  MAX_GLASS_SURFACES,
  normalizeGlassSurfaces,
} from './glass-surfaces.ts';
import { glassMaterial } from '../data/glass-material.ts';

/** Samples only the composer's current linear HDR court; OutputPass owns ACES/sRGB. */
export class LiquidGlassPass extends ShaderPass {
  rendering = false;
  failed = false;
  private readonly onRendered: () => void;

  constructor(onRendered: () => void) {
    super({
      name: 'HoopitoLiquidGlass',
      uniforms: {
        tDiffuse: { value: null },
        uSize: { value: new Vector2(1, 1) },
        uCount: { value: 0 },
        uTint: { value: new Color(glassMaterial.tintSrgb) },
        uTintOpacity: { value: glassMaterial.opacity },
        uSaturation: { value: glassMaterial.saturation },
        uOptics: {
          value: new Vector4(
            glassMaterial.bevelWidthPx,
            glassMaterial.refractionPx,
            glassMaterial.dispersionPx,
            glassMaterial.edgeEnergyLinear,
          ),
        },
        uDiffusion: { value: glassMaterial.diffusionSamplePx },
        uRect: {
          value: Array.from(
            { length: MAX_GLASS_SURFACES },
            () => new Vector4(),
          ),
        },
        uFinish: {
          value: Array.from(
            { length: MAX_GLASS_SURFACES },
            () => new Vector2(),
          ),
        },
      },
      vertexShader: `varying vec2 vUv;
        void main() { vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }`,
      fragmentShader: `uniform sampler2D tDiffuse;
        uniform vec2 uSize;
        uniform int uCount;
        uniform vec4 uRect[6];
        uniform vec2 uFinish[6];
        uniform vec3 uTint;
        uniform float uTintOpacity;
        uniform float uSaturation;
        uniform vec4 uOptics;
        uniform float uDiffusion;
        varying vec2 vUv;
        void main() {
          vec3 color = texture2D(tDiffuse, vUv).rgb;
          vec2 pixel = vec2(vUv.x, 1.0 - vUv.y) * uSize;
          for (int i = 0; i < 6; i++) {
            if (i >= uCount) break;
            vec4 rect = uRect[i];
            // Most pixels never touch a card. Reject against its cheap rectangle
            // before rounded-distance, normal, exponential and texture work.
            if (pixel.x < rect.x - 1.0 || pixel.y < rect.y - 1.0 ||
                pixel.x > rect.x + rect.z + 1.0 || pixel.y > rect.y + rect.w + 1.0) continue;
            vec2 halfSize = rect.zw * 0.5;
            vec2 local = pixel - rect.xy - halfSize;
            float radius = uFinish[i].x;
            vec2 q = abs(local) - halfSize + radius;
            float distanceToEdge = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
            float mask = 1.0 - smoothstep(-0.8, 0.8, distanceToEdge);
            if (mask <= 0.0) continue;
            vec2 corner = max(q, vec2(0.0));
            float cornerLength = length(corner);
            vec2 normal = cornerLength > 0.0001
              ? corner / cornerLength
              : (q.x > q.y ? vec2(1.0, 0.0) : vec2(0.0, 1.0));
            normal *= sign(local);
            // Compact edge support leaves the center entirely undisplaced.
            float inset = max(0.0, -distanceToEdge);
            float bevel = 1.0 - smoothstep(0.0, uOptics.x, inset);
            vec2 bend = normal * bevel * uOptics.y;
            bend.y *= -1.0;
            vec2 uv = clamp(vUv - bend / uSize, vec2(0.001), vec2(0.999));
            vec2 blur = vec2(uDiffusion) / uSize;
            vec3 glass = texture2D(tDiffuse, uv).rgb * 0.4;
            glass += texture2D(tDiffuse, clamp(uv + vec2(blur.x, 0.0), 0.001, 0.999)).rgb * 0.15;
            glass += texture2D(tDiffuse, clamp(uv - vec2(blur.x, 0.0), 0.001, 0.999)).rgb * 0.15;
            glass += texture2D(tDiffuse, clamp(uv + vec2(0.0, blur.y), 0.001, 0.999)).rgb * 0.15;
            glass += texture2D(tDiffuse, clamp(uv - vec2(0.0, blur.y), 0.001, 0.999)).rgb * 0.15;
            // Dispersion remains confined to the bevel; center content stays calm.
            if (uOptics.z > 0.0 && bevel > 0.0) {
              vec2 fringe = normal * bevel * uOptics.z / uSize;
              glass.r = mix(glass.r, texture2D(tDiffuse, clamp(uv + fringe, 0.001, 0.999)).r, bevel * 0.3);
              glass.b = mix(glass.b, texture2D(tDiffuse, clamp(uv - fringe, 0.001, 0.999)).b, bevel * 0.3);
            }
            float luminance = dot(glass, vec3(0.2126, 0.7152, 0.0722));
            glass = mix(vec3(luminance), glass, uSaturation);
            glass = mix(glass, uTint, uTintOpacity);
            float rim = 1.0 - smoothstep(0.0, 1.0, abs(distanceToEdge));
            float light = max(0.0, dot(normal, normalize(vec2(-0.55, -0.8))));
            glass += vec3(uOptics.w) * rim * (0.2 + 0.8 * light);
            color = mix(color, glass, mask * uFinish[i].y);
          }
          gl_FragColor = vec4(color, 1.0);
        }`,
    });
    this.material.toneMapped = false;
    this.onRendered = onRendered;
  }

  setSurfaces(surfaces: readonly GlassSurface[], viewport: SceneRegion) {
    const valid = normalizeGlassSurfaces(surfaces, viewport);
    this.uniforms.uSize.value.set(
      Math.max(1, viewport.width),
      Math.max(1, viewport.height),
    );
    this.uniforms.uCount.value = valid.length;
    valid.forEach((surface, index) => {
      // Cull with the intersection; shade the original rounded card across viewport edges.
      const source = surfaces.find(
        (candidate) =>
          candidate.id === surface.id &&
          normalizeGlassSurfaces([candidate], viewport).length,
      )!;
      const { left, top, width, height } = source.region;
      this.uniforms.uRect.value[index].set(
        left - viewport.left,
        top - viewport.top,
        width,
        height,
      );
      this.uniforms.uFinish.value[index].set(
        Math.max(0, Math.min(source.radius, width / 2, height / 2)),
        surface.opacity,
      );
    });
    return valid.length;
  }

  override render(
    renderer: WebGLRenderer,
    write: WebGLRenderTarget,
    read: WebGLRenderTarget,
    delta: number,
    mask: boolean,
  ) {
    this.rendering = true;
    try {
      super.render(renderer, write, read, delta, mask);
      this.onRendered();
    } catch (error) {
      this.failed = true;
      this.enabled = false;
      throw error;
    } finally {
      this.rendering = false;
    }
  }
}
