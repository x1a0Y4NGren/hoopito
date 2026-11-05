import type { CourtPoint } from './scene-contract';
export const SHOT_TIMING = {
  flight: 1.2,
  swish: 0.35,
  rebound: 0.58,
  mark: 1.55,
  total: 2.13,
} as const;
const clamp = (value: number) => Math.max(0, Math.min(1, value));
export function netResponse(time: number) {
  if (time < SHOT_TIMING.flight || time >= SHOT_TIMING.total) return 0;
  if (time < SHOT_TIMING.mark) {
    const p = clamp((time - SHOT_TIMING.flight) / SHOT_TIMING.swish);
    return Math.sin(p * p * p * Math.PI);
  }
  const p = clamp((time - SHOT_TIMING.mark) / SHOT_TIMING.rebound);
  return Math.sin(p * Math.PI * 3) * Math.exp(-p * 4) * 0.3;
}
export function shotFrame(time: number, point: CourtPoint) {
  const t = Math.max(0, time),
    p = clamp(t / SHOT_TIMING.flight),
    q = 1 - p;
  const startX = 28 + point.x * 544,
    startY = 28 + point.y * 504;
  const phase =
    t < SHOT_TIMING.flight
      ? 'flight'
      : t < SHOT_TIMING.mark
        ? 'swish'
        : t < SHOT_TIMING.total
          ? 'rebound'
          : 'rest';
  const fall = clamp((t - SHOT_TIMING.flight) / SHOT_TIMING.swish);
  const depth = fall * fall * (3 - 2 * fall);
  return {
    phase,
    recorded: t >= SHOT_TIMING.mark,
    visible: t < SHOT_TIMING.mark,
    x: q * q * startX + 2 * q * p * ((startX + 300) / 2) + p * p * 300,
    y: phase === 'flight' ? q * q * startY + 2 * q * p * 15 + p * p * 82 : 82,
    // In the overhead view the ball recedes through the circular opening.
    // Screen-space downward movement would incorrectly turn it into a side view.
    scale: (1 - p * 0.3) * (1 - depth * 0.72),
    rotation: p * 612 + fall * 150,
    impact: netResponse(t),
    trailOpacity:
      phase === 'flight' ? 0.75 : phase === 'swish' ? 0.75 * (1 - fall) : 0,
    arcProgress: p,
  };
}
export function netPoint(x: number, y: number, impact: number) {
  const depth = 1 - clamp(Math.hypot(x, y) / 16),
    weight = depth * depth * (3 - 2 * depth);
  // From directly overhead, lower courses recede toward the circle's centre.
  // The rim's complete attachment circle stays fixed while the inside flexes.
  const tension = 1 - impact * 0.36 * weight;
  return {
    x: x * tension,
    y: y * tension,
  };
}
export function netPath(impact: number) {
  const radii = [16, 13.3, 10.2, 7.2],
    strands = 16;
  const nodes = radii.map((radius, row) =>
    Array.from({ length: strands }, (_, index) => {
      const angle = ((index + (row % 2) / 2) / strands) * Math.PI * 2;
      return netPoint(
        Math.cos(angle) * radius,
        Math.sin(angle) * radius,
        impact,
      );
    }),
  );
  const paths: string[] = [];
  const p = (point: { x: number; y: number }) =>
    `${point.x.toFixed(2)} ${point.y.toFixed(2)}`;
  for (let row = 0; row < radii.length - 1; row++)
    for (let i = 0; i < strands; i++)
      for (const next of [i, i + (row % 2 ? 1 : -1)])
        paths.push(
          `M${p(nodes[row][i])}L${p(nodes[row + 1][(next + strands) % strands])}`,
        );
  const mouth = nodes.at(-1)!;
  paths.push(`M${mouth.map(p).join('L')}Z`);
  return paths.join('');
}
