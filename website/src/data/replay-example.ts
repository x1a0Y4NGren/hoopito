export interface ReplayScorePoint {
  readonly progress: number;
  readonly leftScore: number;
  readonly rightScore: number;
}

export type ReplayKeyMomentId = 'lead' | 'tie' | 'turnaround' | 'final';
export type ReplayStageId = 'opening' | ReplayKeyMomentId;

export interface ReplayKeyMoment extends ReplayScorePoint {
  readonly id: ReplayKeyMomentId;
  readonly pointIndex: number;
}

export interface ReplayPlotBounds {
  readonly xMin: number;
  readonly xMax: number;
  readonly yMin: number;
  readonly yMax: number;
  readonly maxScore: number;
}

export interface ReplayState extends ReplayScorePoint {
  readonly pointIndex: number;
  /** The last reached key moment; opening lasts until the 6:2 lead. */
  readonly stage: ReplayStageId;
  readonly keyMoment: ReplayKeyMoment | null;
  readonly leftPath: string;
  readonly rightPath: string;
}

// This is an independent fictional sequence, not a reconstruction of the
// screenshot or a continuation of the preceding 6:6 → 8:6 scoring demo.
const points: readonly ReplayScorePoint[] = [
  { progress: 0, leftScore: 0, rightScore: 0 },
  { progress: 0.1, leftScore: 2, rightScore: 0 },
  { progress: 0.2, leftScore: 2, rightScore: 2 },
  { progress: 0.3, leftScore: 4, rightScore: 2 },
  { progress: 0.4, leftScore: 6, rightScore: 2 },
  { progress: 0.5, leftScore: 6, rightScore: 4 },
  { progress: 0.6, leftScore: 6, rightScore: 6 },
  { progress: 0.7, leftScore: 6, rightScore: 7 },
  { progress: 0.8, leftScore: 8, rightScore: 7 },
  { progress: 0.9, leftScore: 8, rightScore: 9 },
  { progress: 1, leftScore: 8, rightScore: 11 },
];

const keyMomentDefinitions = [
  { id: 'lead', pointIndex: 4 },
  { id: 'tie', pointIndex: 6 },
  { id: 'turnaround', pointIndex: 9 },
  { id: 'final', pointIndex: 10 },
] as const;

const keyMoments: readonly ReplayKeyMoment[] = keyMomentDefinitions.map(
  ({ id, pointIndex }) => ({
    id,
    pointIndex,
    ...points[pointIndex],
  }),
);

export const replayExample = {
  kind: 'fictional',
  label: {
    zh: '虚构比分走势示例',
    en: 'Fictional score-flow example',
  },
  points,
  keyMoments,
} as const;

export const replayPlotBounds: ReplayPlotBounds = {
  xMin: 34,
  xMax: 426,
  yMin: 28,
  yMax: 166,
  maxScore: 12,
};

function normalizeProgress(progress: number): number {
  return Number.isFinite(progress) ? Math.min(1, Math.max(0, progress)) : 0;
}

function coordinate(value: number): number {
  return Number(value.toFixed(3));
}

export function getReplayPlotPoint(
  point: ReplayScorePoint,
  bounds: ReplayPlotBounds = replayPlotBounds,
): { x: number; leftY: number; rightY: number } {
  const scoreHeight = (bounds.yMax - bounds.yMin) / bounds.maxScore;
  return {
    x: coordinate(bounds.xMin + (bounds.xMax - bounds.xMin) * point.progress),
    leftY: coordinate(bounds.yMax - point.leftScore * scoreHeight),
    rightY: coordinate(bounds.yMax - point.rightScore * scoreHeight),
  };
}

/** Scores jump at each event; the current plateau extends to playback progress. */
export function getReplayPaths(
  progress = 1,
  bounds: ReplayPlotBounds = replayPlotBounds,
): { left: string; right: string } {
  const normalizedProgress = normalizeProgress(progress);
  let lastPoint = points[0];
  const firstPlot = getReplayPlotPoint(lastPoint, bounds);
  let left = `M${firstPlot.x} ${firstPlot.leftY}`;
  let right = `M${firstPlot.x} ${firstPlot.rightY}`;

  for (let index = 1; index < points.length; index += 1) {
    const point = points[index];
    if (point.progress > normalizedProgress) break;
    const plot = getReplayPlotPoint(point, bounds);
    left += ` H${plot.x}`;
    right += ` H${plot.x}`;
    if (point.leftScore !== lastPoint.leftScore) left += ` V${plot.leftY}`;
    if (point.rightScore !== lastPoint.rightScore) right += ` V${plot.rightY}`;
    lastPoint = point;
  }

  if (normalizedProgress > lastPoint.progress) {
    const x = coordinate(
      bounds.xMin + (bounds.xMax - bounds.xMin) * normalizedProgress,
    );
    left += ` H${x}`;
    right += ` H${x}`;
  }
  return { left, right };
}

export function getReplayState(progress: number): ReplayState {
  const normalizedProgress = normalizeProgress(progress);
  let pointIndex = 0;
  for (let index = 1; index < points.length; index += 1) {
    if (points[index].progress > normalizedProgress) break;
    pointIndex = index;
  }
  let keyMoment: ReplayKeyMoment | null = null;
  for (const moment of keyMoments) {
    if (moment.progress > normalizedProgress) break;
    keyMoment = moment;
  }
  const paths = getReplayPaths(normalizedProgress);
  return {
    ...points[pointIndex],
    progress: normalizedProgress,
    pointIndex,
    stage: keyMoment?.id ?? 'opening',
    keyMoment,
    leftPath: paths.left,
    rightPath: paths.right,
  };
}
