import { floorSurfaceGLSL, floorVarnishVertexGLSL } from '../court-lighting.ts';
import {
  COURT,
  CORNER_JOIN_Y,
  FREE_THROW_HIGHLIGHT_HALF_DEPTH,
} from '../court-geometry.ts';

const scalar = (value: number) => value.toFixed(12);
/** Generated constants keep shader paint, hint masks and CPU validation aligned. */
const geometryGLSL = /* glsl */ `
  const float courtWidth = ${scalar(COURT.width)};
  const float courtDepth = ${scalar(COURT.depth)};
  const float basketZ = ${scalar(COURT.basketY - COURT.depth / 2)};
  const float arcRadius = ${scalar(COURT.threePointRadius)};
  const float cornerX = ${scalar(COURT.width / 2 - COURT.cornerOffset)};
  const float cornerJoinZ = ${scalar(CORNER_JOIN_Y - COURT.depth / 2)};
  const float freeThrowZ = ${scalar(COURT.freeThrowLineY - COURT.depth / 2)};
  const float freeThrowHalfWidth = ${scalar(COURT.freeThrowLineWidth / 2)};
  vec2 courtWorld(vec2 uv) {
    return vec2((uv.x - 0.5) * courtWidth, (0.5 - uv.y) * courtDepth);
  }
  bool outsideArc(vec2 point) {
    if (point.y <= cornerJoinZ) return abs(point.x) > cornerX + 0.000000001;
    vec2 delta = point - vec2(0.0, basketZ);
    return dot(delta, delta) > arcRadius * arcRadius + 0.000000001;
  }
`;

/** Generic plane vertex shader also used by the contact shadow. */
export const courtVertex = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

/** Court paint carries the same world-space irradiance and finish as maple. */
export const courtPaintVertex = /* glsl */ `
  attribute vec3 aFloorDynamic;
  attribute vec3 aFloorFixed;
  attribute vec2 aFloorSpecular;
  varying vec2 vUv;
  varying vec3 vFloorDynamic;
  varying vec3 vFloorFixed;
  varying vec2 vFloorSpecular;
  varying vec3 vFloorPosition;
  ${floorVarnishVertexGLSL}
  void main() {
    vUv = uv;
    vFloorDynamic = aFloorDynamic;
    vFloorFixed = aFloorFixed;
    vFloorSpecular = aFloorSpecular;
    vFloorPosition = (modelMatrix * vec4(position, 1.0)).xyz;
    vFloorVertexVarnish = floorVertexVarnish(vFloorPosition, aFloorSpecular);
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

export const courtFragment = /* glsl */ `
  uniform float uReveal;
  varying vec2 vUv;
  ${floorSurfaceGLSL}
  ${geometryGLSL}

  float segmentDistance(vec2 point, vec2 start, vec2 end) {
    vec2 direction = end - start;
    float along = clamp(dot(point - start, direction) / dot(direction, direction), 0.0, 1.0);
    return length(point - start - direction * along);
  }

  float boxDistance(vec2 point, vec2 halfSize) {
    vec2 offset = abs(point) - halfSize;
    return length(max(offset, 0.0)) + min(max(offset.x, offset.y), 0.0);
  }

  float lineCoverage(float distance) {
    float footprint = max(fwidth(distance), 0.0001);
    float edge = abs(distance);
    float halfWidth = 0.025;
    // Integrate both edges over the pixel footprint. A subpixel stroke
    // retains its coverage instead of growing into a flickering 1px line.
    float outer = clamp((halfWidth - edge) / footprint + 0.5, 0.0, 1.0);
    float inner = clamp((-halfWidth - edge) / footprint + 0.5, 0.0, 1.0);
    return outer - inner;
  }

  float semicircleCoverage(vec2 point, float radius) {
    // The positive second axis contains the arc; below it the nearest
    // points are its endpoints. Evaluate both derivatives before selecting
    // coverage so a sign change at an endpoint cannot widen the AA filter.
    float arc = lineCoverage(length(point) - radius);
    float caps = lineCoverage(length(vec2(abs(point.x) - radius, point.y)));
    return point.y >= 0.0 ? arc : caps;
  }

  vec3 srgbToLinear(vec3 color) {
    return mix(
      color / 12.92,
      pow((color + 0.055) / 1.055, vec3(2.4)),
      step(vec3(0.04045), color)
    );
  }

  void main() {
    vec2 point = courtWorld(vUv);

    float white = lineCoverage(boxDistance(point, vec2(courtWidth, courtDepth) * 0.5));
    white = max(white, lineCoverage(boxDistance(point - vec2(0.0, (freeThrowZ - courtDepth * 0.5) * 0.5), vec2(2.45, ${scalar(COURT.freeThrowLineY / 2)}))));
    white = max(white, lineCoverage(segmentDistance(point, vec2(-freeThrowHalfWidth, freeThrowZ), vec2(freeThrowHalfWidth, freeThrowZ))));
    white = max(white, lineCoverage(length(point - vec2(0.0, freeThrowZ)) - 1.8));
    vec2 arcPoint = vec2(abs(point.x), point.y - basketZ);
    float minAngle = atan(cornerJoinZ - basketZ, cornerX);
    float angle = clamp(atan(arcPoint.y, arcPoint.x), minAngle, 1.57079632679);
    white = max(white, lineCoverage(length(arcPoint - arcRadius * vec2(cos(angle), sin(angle)))));
    white = max(white, lineCoverage(segmentDistance(point, vec2(-cornerX, -courtDepth * 0.5), vec2(-cornerX, cornerJoinZ))));
    white = max(white, lineCoverage(segmentDistance(point, vec2(cornerX, -courtDepth * 0.5), vec2(cornerX, cornerJoinZ))));
    white = max(white, semicircleCoverage(vec2(point.x, 7.0 - point.y), 1.8));

    float orange = semicircleCoverage(point - vec2(0.0, basketZ), 1.25);
    float coverage = max(white, orange);
    // Most of the floor contains no paint. Avoid blending transparent pixels
    // into the HDR/MSAA buffer; derivatives above must run before this discard.
    if (coverage <= 0.0) discard;
    vec3 ivory = srgbToLinear(vec3(244.0, 243.0, 239.0) / 255.0);
    vec3 amber = srgbToLinear(vec3(1.0, 90.0 / 255.0, 31.0 / 255.0));
    vec3 color = mix(ivory, amber, orange / max(white + orange, 0.0001));

    float leadingEdge = 1.0 - smoothstep(uReveal - 0.05, uReveal + 0.05, 1.0 - vUv.y);
    vec3 surface = floorSurface(color);
    gl_FragColor = vec4(surface, coverage * leadingEdge);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

/** One floor overlay shades the complement without changing recorded locations. */
export const courtRegionFragment = /* glsl */ `
  uniform float uRegion;
  uniform float uLightOpacity;
  varying vec2 vUv;
  ${geometryGLSL}
  void main() {
    if (uRegion < 0.5) discard;
    vec2 point = courtWorld(vUv);
    bool outside = outsideArc(point);
    bool valid = uRegion < 1.5 ? !outside : uRegion < 2.5 ? outside :
      abs(point.y - freeThrowZ) <= ${scalar(FREE_THROW_HIGHLIGHT_HALF_DEPTH)} && abs(point.x) <= freeThrowHalfWidth;
    vec3 warm = vec3(1.0, 0.4735, 0.147);
    float alpha = valid ? uLightOpacity : 0.48;
    if (uRegion > 2.5) {
      // Fixed free-throw location: marker size is measured on the floor and never pulses.
      float centerDistance = length(point - vec2(0.0, freeThrowZ));
      float center = 1.0 - smoothstep(0.065, 0.083, centerDistance);
      float ring = 1.0 - smoothstep(0.012, 0.028, abs(centerDistance - 0.248));
      float disk = 1.0 - smoothstep(0.23, 0.25, centerDistance);
      float marker = max(center * 0.95, max(ring * 0.9, disk * 0.35));
      if (marker > 0.0) {
        valid = true;
        alpha = max(alpha, marker);
      }
    }
    gl_FragColor = vec4(valid ? warm : vec3(0.0), alpha);
    #include <tonemapping_fragment>
    #include <colorspace_fragment>
  }
`;

/** A narrow ribbon expands in CSS pixels after projection, independent of DPR. */
export const trailVertex = /* glsl */ `
  uniform vec2 uViewport;
  uniform float uWidthPixels;
  attribute vec3 tangent;
  varying vec2 vUv;
  void main() {
    vUv = uv;
    vec4 center = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
    vec4 next = projectionMatrix * modelViewMatrix * vec4(position + tangent, 1.0);
    vec2 direction = (next.xy / next.w - center.xy / center.w) * uViewport;
    vec2 normal = normalize(vec2(-direction.y, direction.x) + vec2(0.000001));
    center.xy += normal * (uv.y * 2.0 - 1.0) * uWidthPixels / uViewport * center.w;
    gl_Position = center;
  }
`;

export const trailFragment = /* glsl */ `
  uniform float uHead;
  uniform float uTail;
  uniform float uOpacity;
  uniform float uHalo;
  varying vec2 vUv;
  void main() {
    if (vUv.x < uTail || vUv.x > uHead || uHead <= uTail) discard;
    float tail = smoothstep(uTail, mix(uTail, uHead, 0.6), vUv.x);
    float distance = abs(vUv.y * 2.0 - 1.0);
    float crossSection = mix(1.0, exp(-distance * distance * 5.0) * (1.0 - smoothstep(0.75, 1.0, distance)), uHalo);
    vec3 amber = mix(vec3(1.0, 0.3, 0.07), vec3(1.0, 0.84, 0.51), 1.0 - uHalo);
    gl_FragColor = vec4(amber, tail * crossSection * uOpacity);
    #include <colorspace_fragment>
  }
`;
