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
  return {
    phase,
    recorded: t >= SHOT_TIMING.mark,
    visible: t < SHOT_TIMING.mark,
    x: q * q * startX + 2 * q * p * ((startX + 300) / 2) + p * p * 300,
    y:
      phase === 'flight'
        ? q * q * startY + 2 * q * p * 15 + p * p * 82
        : 82 + fall * fall * fall * 48,
    scale: 1 - p * 0.3,
    rotation: p * 612 + fall * 150,
    impact: netResponse(t),
    trailOpacity:
      phase === 'flight' ? 0.75 : phase === 'swish' ? 0.75 * (1 - fall) : 0,
    arcProgress: p,
  };
}
export function netPoint(x: number, y: number, impact: number) {
  const depth = clamp(y / 40),
    weight = depth * depth * (3 - 2 * depth);
  return {
    x: x * (1 + impact * 0.32 * weight) + impact * 1.2 * weight,
    y: y + impact * 8 * weight,
  };
}
export function netPath(impact: number) {
  const rows = [0, 7, 15, 23, 31, 40],
    widths = [16, 15, 13.8, 12, 10.5, 9];
  const nodes = rows.map((y, r) =>
    Array.from({ length: 9 }, (_, i) =>
      netPoint(-widths[r] + (i * widths[r]) / 4, y, impact),
    ),
  );
  const paths: string[] = [];
  const p = (point: { x: number; y: number }) =>
    `${point.x.toFixed(2)} ${point.y.toFixed(2)}`;
  for (let row = 0; row < rows.length - 1; row++)
    for (let i = row % 2; i < 9; i += 2)
      for (const next of [i - 1, i + 1]) {
        if (next >= 0 && next < 9)
          paths.push(`M${p(nodes[row][i])}L${p(nodes[row + 1][next])}`);
      }
  paths.push(`M${p(nodes[5][0])}L${p(nodes[5][8])}`);
  return paths.join('');
}
