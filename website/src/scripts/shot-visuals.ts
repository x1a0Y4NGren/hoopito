import type { SceneQuality } from './scene-contract.ts';

/** Core feedback uses CSS pixels and survives every renderer quality tier. */
export const SHOT_VISUALS = {
  trailSeconds: 0.22,
  trailCorePixels: 2.5,
  trailHaloPixels: 12,
  markerStrokePixels: 2,
  markerHaloPixels: 36,
  ballHaloPixels: 26,
} as const;

export function shotVisualQuality(quality: SceneQuality) {
  return {
    haloOpacity:
      quality === 'full' ? 0.35 : quality === 'effects' ? 0.24 : 0.16,
    trailSegments: quality === 'full' ? 64 : quality === 'effects' ? 48 : 32,
  };
}

export function trailWindow(time: number, flightSeconds: number) {
  const end = Math.max(
    0,
    Math.min(flightSeconds, Number.isFinite(time) ? time : 0),
  );
  return {
    head: end / flightSeconds,
    tail: Math.max(0, end - SHOT_VISUALS.trailSeconds) / flightSeconds,
  };
}

/** Positive camera-space depth, vertical field of view and CSS viewport height. */
export function worldUnitsPerPixel(
  depth: number,
  verticalFov: number,
  viewportHeight: number,
) {
  const distance = Number.isFinite(depth) ? Math.max(0.015, depth) : 0.015;
  const fov = Number.isFinite(verticalFov)
    ? Math.max(1, Math.min(179, verticalFov))
    : 32;
  const height = Number.isFinite(viewportHeight)
    ? Math.max(1, viewportHeight)
    : 1;
  return (2 * distance * Math.tan((fov * Math.PI) / 360)) / height;
}
