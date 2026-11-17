import type { CourtPoint } from './scene-contract.ts';

export type CourtScoringRegion = 'insideArc' | 'outsideArc' | 'freeThrowLine';

/** Metres, matching the App's CourtGeometry; normalized points include the lines. */
export const COURT = {
  width: 15,
  depth: 14,
  basketY: 1.575,
  threePointRadius: 6.75,
  cornerOffset: 0.9,
  freeThrowLineY: 5.8,
  freeThrowLineWidth: 3.6,
} as const;
export const SVG_COURT = {
  left: 28,
  top: 28,
  width: 544,
  height: 504,
} as const;
export const FREE_THROW_POINT: CourtPoint = {
  x: 0.5,
  y: COURT.freeThrowLineY / COURT.depth,
};
export const BASKET_POINT: CourtPoint = {
  x: 0.5,
  y: COURT.basketY / COURT.depth,
};
export const RIM_WORLD: [number, number, number] = [
  0,
  3.05,
  COURT.basketY - COURT.depth / 2,
];
export const CORNER_JOIN_Y =
  COURT.basketY +
  Math.sqrt(
    COURT.threePointRadius ** 2 - (COURT.width / 2 - COURT.cornerOffset) ** 2,
  );
/** Presentation band only: free throws always use the fixed centre point. */
export const FREE_THROW_HIGHLIGHT_HALF_DEPTH = 0.16;

export function courtToSvg(point: CourtPoint) {
  return {
    x: SVG_COURT.left + point.x * SVG_COURT.width,
    y: SVG_COURT.top + point.y * SVG_COURT.height,
  };
}

export function courtToWorld(point: CourtPoint): [number, number, number] {
  return [(point.x - 0.5) * COURT.width, 0, (point.y - 0.5) * COURT.depth];
}

export function containsCourtPoint(point: CourtPoint) {
  return (
    Number.isFinite(point.x) &&
    Number.isFinite(point.y) &&
    point.x >= 0 &&
    point.x <= 1 &&
    point.y >= 0 &&
    point.y <= 1
  );
}

/** Caller validates the court first; floating point error on a line stays inside. */
export function isOutsideArc(point: CourtPoint) {
  const x = point.x * COURT.width;
  const y = point.y * COURT.depth;
  const epsilon = 1e-9;
  if (y <= CORNER_JOIN_Y)
    return (
      x < COURT.cornerOffset - epsilon ||
      x > COURT.width - COURT.cornerOffset + epsilon
    );
  return (
    (x - COURT.width / 2) ** 2 + (y - COURT.basketY) ** 2 >
    COURT.threePointRadius ** 2 + epsilon
  );
}

/** Rendering policy is shared by the WebGL scheduler and deterministic tests. */
export function regionHintPresentation({
  region,
  pulse,
  motionEnabled,
  paused,
  reading,
  elapsed,
}: {
  region: CourtScoringRegion | null;
  pulse: boolean;
  motionEnabled: boolean;
  paused: boolean;
  reading: boolean;
  elapsed: number;
}) {
  const regionId =
    !reading || !region
      ? 0
      : region === 'insideArc'
        ? 1
        : region === 'outsideArc'
          ? 2
          : 3;
  const pulsing = regionId > 0 && pulse && motionEnabled && !paused;
  return {
    regionId,
    pulsing,
    lightOpacity: pulsing
      ? 0.08 +
        0.04 *
          Math.sin(
            ((Number.isFinite(elapsed) ? elapsed : 0) * Math.PI * 2) / 1.6,
          )
      : 0.08,
  };
}

const svgMeters = (x: number, y: number) =>
  courtToSvg({ x: x / COURT.width, y: y / COURT.depth });
const xy = (point: { x: number; y: number }) => `${point.x} ${point.y}`;
const left = svgMeters(COURT.cornerOffset, CORNER_JOIN_Y);
const right = svgMeters(COURT.width - COURT.cornerOffset, CORNER_JOIN_Y);
const arcRadii = `${(COURT.threePointRadius / COURT.width) * SVG_COURT.width} ${(COURT.threePointRadius / COURT.depth) * SVG_COURT.height}`;
const arc = `M${left.x} ${SVG_COURT.top}V${left.y}A${arcRadii} 0 0 0 ${xy(right)}V${SVG_COURT.top}`;
const boundary = `M28 28H572V532H28Z`;
const insideArc = `${arc}Z`;
const ftLeft = svgMeters(
  (COURT.width - COURT.freeThrowLineWidth) / 2,
  COURT.freeThrowLineY,
);
const ftRight = svgMeters(
  (COURT.width + COURT.freeThrowLineWidth) / 2,
  COURT.freeThrowLineY,
);
const ftHalfHeight =
  (FREE_THROW_HIGHLIGHT_HALF_DEPTH / COURT.depth) * SVG_COURT.height;
const freeThrowLine = `M${ftLeft.x} ${ftLeft.y - ftHalfHeight}H${ftRight.x}V${ftRight.y + ftHalfHeight}H${ftLeft.x}Z`;
const ftRx = (1.8 / COURT.width) * SVG_COURT.width;
const ftRy = (1.8 / COURT.depth) * SVG_COURT.height;
const laneLeft = svgMeters((COURT.width - 4.9) / 2, 0);
const laneRight = svgMeters((COURT.width + 4.9) / 2, COURT.freeThrowLineY);
const basket = courtToSvg(BASKET_POINT);
const restrictedRx = (1.25 / COURT.width) * SVG_COURT.width;
const restrictedRy = (1.25 / COURT.depth) * SVG_COURT.height;

/** Drawing and region masks derive from the same metre measurements as hit testing. */
export const COURT_SVG = {
  boundary,
  lane: `M${xy(laneLeft)}V${laneRight.y}H${laneRight.x}V${SVG_COURT.top}`,
  freeThrowLine: `M${xy(ftLeft)}H${ftRight.x}`,
  freeThrowArc: `M${xy(ftLeft)}A${ftRx} ${ftRy} 0 0 0 ${xy(ftRight)}`,
  freeThrowReturn: `M${xy(ftLeft)}A${ftRx} ${ftRy} 0 0 1 ${xy(ftRight)}`,
  threePoint: arc,
  restrictedArc: `M${basket.x - restrictedRx} ${basket.y}A${restrictedRx} ${restrictedRy} 0 0 0 ${basket.x + restrictedRx} ${basket.y}`,
  centerArc: `M${SVG_COURT.left + SVG_COURT.width / 2 - ftRx} 532A${ftRx} ${ftRy} 0 0 1 ${SVG_COURT.left + SVG_COURT.width / 2 + ftRx} 532`,
  regions: { insideArc, outsideArc: `${boundary}${insideArc}`, freeThrowLine },
} as const;
