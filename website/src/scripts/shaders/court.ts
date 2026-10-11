/** Court paint reveals from the far baseline; never controls DOM visibility. */
export const courtVertex = /* glsl */ `
  varying vec2 vUv;
  void main() {
    vUv = uv;
    gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0);
  }
`;

export const courtFragment = /* glsl */ `
  uniform sampler2D uPaint;
  uniform float uReveal;
  varying vec2 vUv;
  void main() {
    vec4 paint = texture2D(uPaint, vUv);
    float leadingEdge = 1.0 - smoothstep(uReveal - 0.05, uReveal + 0.05, 1.0 - vUv.y);
    float trace = 1.0 - smoothstep(0.0, 0.028, abs(1.0 - vUv.y - uReveal));
    gl_FragColor = vec4(paint.rgb * (1.0 + trace * 1.8), paint.a * leadingEdge);
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
