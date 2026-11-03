import type { StoryChapter, StoryFrame } from './scene-contract.ts';

export type RelayChapter = StoryChapter;
export interface RelayAnchor {
  x: number;
  y: number;
  length: number;
}
export interface RelayStop {
  id: RelayChapter;
  readStart: number;
  readEnd: number;
  exitStart?: number;
  exitEnd?: number;
}
export interface RelayPose extends RelayAnchor {
  opacity: number;
  chapter: RelayChapter | null;
}
const hidden: RelayPose = { x: 0, y: 0, length: 0, opacity: 0, chapter: null };
const smooth = (p: number) => {
  const value = Math.max(0, Math.min(1, p));
  return value * value * (3 - 2 * value);
};

/** A single screen-space accent follows real reading stops, not chapter selection. */
export function relayPose(
  scroll: number,
  stops: readonly RelayStop[],
  anchors: Partial<Record<RelayChapter, RelayAnchor>>,
  track?: StoryFrame['cameraTrack'],
): RelayPose {
  if (!Number.isFinite(scroll) || stops.length < 2) return { ...hidden };
  if (
    stops.some(
      (stop) =>
        !anchors[stop.id] ||
        !Object.values(anchors[stop.id]!).every(Number.isFinite),
    )
  )
    return { ...hidden };
  for (const [index, stop] of stops.entries()) {
    const anchor = anchors[stop.id]!;
    if (scroll <= stop.readEnd) {
      const previous = stops[index - 1];
      if (!previous || scroll >= stop.readStart)
        return { ...anchor, opacity: 1, chapter: stop.id };
      const from = anchors[previous.id]!;
      const raw =
        track?.from === previous.id && track.to === stop.id
          ? track.progress
          : (scroll - previous.readEnd) /
            Math.max(1, stop.readStart - previous.readEnd);
      const p = smooth((raw - 0.12) / (0.85 - 0.12));
      // A restrained strip opens in flight and closes at either measured anchor.
      // The bounded polynomial has zero slope at both ends and reverses exactly.
      const extension = 96 * (4 * p * (1 - p)) ** 2;
      return {
        x: from.x + (anchor.x - from.x) * p,
        y: from.y + (anchor.y - from.y) * p,
        length: from.length + (anchor.length - from.length) * p + extension,
        opacity: 1,
        chapter: p < 0.5 ? previous.id : stop.id,
      };
    }
  }
  const final = stops.at(-1)!;
  if (track?.from === final.id && !stops.some((stop) => stop.id === track.to)) {
    const opacity = 1 - smooth((track.progress - 0.12) / (0.85 - 0.12));
    return opacity > 0
      ? { ...anchors[final.id]!, opacity, chapter: final.id }
      : { ...hidden };
  }
  const fadeStart = final.exitStart ?? final.readEnd;
  const fadeEnd = final.exitEnd ?? fadeStart + 1;
  const opacity =
    1 - smooth((scroll - fadeStart) / Math.max(1, fadeEnd - fadeStart));
  return opacity > 0
    ? { ...anchors[final.id]!, opacity, chapter: final.id }
    : { ...hidden };
}
