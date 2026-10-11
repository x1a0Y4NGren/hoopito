/** Court paint reveals from the far baseline; never controls DOM visibility. */
export const courtVertex = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

export const courtFragment = /* glsl */ `
  uniform float uReveal;
  varying vec2 vUv;

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
    vec2 point = vec2((vUv.x - 0.5) * 15.0, (0.5 - vUv.y) * 14.0);

    float white = lineCoverage(boxDistance(point, vec2(7.44, 6.94)));
    white = max(white, lineCoverage(boxDistance(point - vec2(0.0, -4.07), vec2(2.45, 2.87))));
    white = max(white, lineCoverage(length(point - vec2(0.0, -1.2)) - 1.8));
    white = max(white, semicircleCoverage(point - vec2(0.0, -5.3), 6.65));
    white = max(white, lineCoverage(segmentDistance(point, vec2(-6.65, -6.94), vec2(-6.65, -5.3))));
    white = max(white, lineCoverage(segmentDistance(point, vec2(6.65, -6.94), vec2(6.65, -5.3))));
    white = max(white, semicircleCoverage(vec2(point.x, 7.0 - point.y), 1.8));

    float orange = semicircleCoverage(point - vec2(0.0, -5.3), 1.25);
    float coverage = max(white, orange);
    // Most of the floor contains no paint. Avoid blending transparent pixels
    // into the HDR/MSAA buffer; derivatives above must run before this discard.
    if (coverage <= 0.0) discard;
    vec3 ivory = srgbToLinear(vec3(244.0, 243.0, 239.0) / 255.0);
    vec3 amber = srgbToLinear(vec3(1.0, 90.0 / 255.0, 31.0 / 255.0));
    vec3 color = mix(ivory, amber, orange / max(white + orange, 0.0001));

    float leadingEdge = 1.0 - smoothstep(uReveal - 0.05, uReveal + 0.05, 1.0 - vUv.y);
    float trace = 1.0 - smoothstep(0.0, 0.028, abs(1.0 - vUv.y - uReveal));
    gl_FragColor = vec4(color * (1.0 + trace * 1.8), coverage * leadingEdge);
  }
`;

/** One immutable arc mesh; its illuminated window follows the ball. */
export const trailVertex = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

export const trailFragment = /* glsl */ `
  uniform float uHead;
  uniform float uOpacity;
  varying vec2 vUv;
  void main() {
    float tail = smoothstep(uHead - 0.26, uHead - 0.01, vUv.x);
    float head = 1.0 - smoothstep(uHead, uHead + 0.018, vUv.x);
    float circumference = 0.5 + 0.5 * sin(vUv.y * 6.2831853);
    vec3 amber = mix(vec3(1.0, 0.16, 0.025), vec3(1.0, 0.72, 0.27), tail);
    gl_FragColor = vec4(amber * 2.7, tail * head * circumference * uOpacity);
  }
`;
