import { railReading } from './chapter-rail-math.ts';
import type { ChapterStop, StopId } from './chapter-scroll.ts';

const finite = (value: number) => (Number.isFinite(value) ? value : 0);

/** Document reading and chapter identity share the desktop rail's boundaries. */
export function mobileProgressState(
  stops: readonly ChapterStop[],
  scroll: number,
  documentHeight: number,
  viewportHeight: number,
): { id: StopId | undefined; index: number; total: number; progress: number } {
  const measured = stops.filter(
    (stop) =>
      Number.isFinite(stop.readStart) &&
      Number.isFinite(stop.readEnd) &&
      stop.readEnd >= stop.readStart,
  );
  const maximum = Math.max(
    0,
    finite(documentHeight) - Math.max(0, finite(viewportHeight)),
  );
  const y = Math.max(0, Math.min(maximum, finite(scroll)));
  const { index } = railReading(measured, y);
  return {
    id: measured[index]?.id,
    index,
    total: measured.length,
    progress: maximum > 0 ? y / maximum : 0,
  };
}
