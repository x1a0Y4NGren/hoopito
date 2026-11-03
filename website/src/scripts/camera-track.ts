import type {
  SceneRegion,
  StoryChapter,
  StoryFrame,
} from './scene-contract.ts';

interface ReadingStop {
  id: StoryChapter | 'closing';
  readStart: number;
  readEnd: number;
}

const READING_LANDING_TOLERANCE = 2;

/** Static experience ROI for a world-flight endpoint. */
export function transitionReadingRegion(
  startRegion: SceneRegion,
  reading: Pick<ReadingStop, 'readStart' | 'readEnd'>,
  track: StoryFrame['cameraTrack'],
  pinned: boolean,
): SceneRegion {
  const departure = track?.from === 'experience';
  const arrival = track?.to === 'experience';
  // Natural flow remains readable throughout the same native landing tolerance
  // used by the input gate. Join at that accepted interval's actual edges,
  // where the host is two pixels before arrival or after departure.
  const tolerance = pinned ? 0 : READING_LANDING_TOLERANCE;
  return {
    ...startRegion,
    top:
      startRegion.top +
      (arrival ? tolerance : 0) -
      (departure
        ? Math.max(0, reading.readEnd - reading.readStart) + tolerance
        : 0),
  };
}

/** Camera time is scroll distance; reading content never advances a camera. */
export function cameraStateAtScroll(
  position: number,
  stops: readonly ReadingStop[],
  fallback: StoryChapter,
): Pick<StoryFrame, 'chapter' | 'cameraTrack'> {
  if (!Number.isFinite(position)) return { chapter: fallback };
  const valid = stops.filter(
    (stop) =>
      Number.isFinite(stop.readStart) &&
      Number.isFinite(stop.readEnd) &&
      stop.readEnd >= stop.readStart,
  );
  const chapterOf = (stop: ReadingStop): StoryChapter =>
    stop.id === 'closing' ? 'community' : stop.id;
  let nearest: ReadingStop | undefined;
  let distance = Infinity;
  for (const stop of valid) {
    const delta = Math.max(
      stop.readStart - position,
      position - stop.readEnd,
      0,
    );
    // A collapsed/overlapping interval has no flight. Equal distances resolve
    // forward, including native scroll positions shared by two reading stops.
    if (delta <= distance) {
      nearest = stop;
      distance = delta;
    }
  }
  if (!nearest) return { chapter: fallback };
  const chapter = chapterOf(nearest);
  // Native scroll offsets quantize fractional layout at each device density.
  // Match the chapter controller's 2 CSS pixel landing tolerance so reaching
  // a stop cannot leave a microscopic flight active and block court input.
  if (distance <= READING_LANDING_TOLERANCE) return { chapter };
  for (let index = 1; index < valid.length; index += 1) {
    const from = valid[index - 1]!;
    const to = valid[index]!;
    if (
      to.readStart <= from.readEnd ||
      position <= from.readEnd ||
      position >= to.readStart
    )
      continue;
    const fromChapter = chapterOf(from);
    const toChapter = chapterOf(to);
    if (fromChapter === toChapter) return { chapter };
    return {
      chapter,
      cameraTrack: {
        from: fromChapter,
        to: toChapter,
        progress: (position - from.readEnd) / (to.readStart - from.readEnd),
      },
    };
  }
  return { chapter };
}

export function isOverheadReadingFrame(frame: StoryFrame): boolean {
  return frame.active && frame.chapter === 'experience' && !frame.cameraTrack;
}
