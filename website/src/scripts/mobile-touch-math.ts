import type { ChapterStop, StopId } from './chapter-scroll';

export interface TouchPoint {
  x: number;
  y: number;
}
export type MobileTouchMove =
  | { kind: 'pending' | 'ignored'; source?: never; position?: never }
  | { kind: 'native'; source: StopId; position?: never }
  | { kind: 'preview'; source: StopId; position: number };
export type MobileTouchFinish =
  | { kind: 'none' }
  | { kind: 'native'; source: StopId }
  | { kind: 'settle'; target: StopId; position?: number; duration: number };

const edge = 2;
const clamp = (value: number, low: number, high: number) =>
  Math.max(low, Math.min(high, value));
const valid = (stop: ChapterStop) =>
  Number.isFinite(stop.readStart) &&
  Number.isFinite(stop.readEnd) &&
  stop.readEnd >= stop.readStart;
const usable = (stops: readonly ChapterStop[]) => stops.filter(valid);

/** Input policy only. The shared chapter controller owns all page writes. */
export class MobileTouchGesture {
  private session:
    | {
        source: StopId;
        anchor: 'start' | 'end' | 'both' | 'inside';
        outside: boolean;
        mode: 'pending' | 'native' | 'preview' | 'ignored';
        finger: TouchPoint;
        base: number;
        net: number;
        height: number;
        preview: number;
      }
    | undefined;

  get source() {
    return this.session?.source;
  }

  begin(
    stops: readonly ChapterStop[],
    position: number,
    finger: TouchPoint,
    height: number,
  ) {
    this.cancel();
    if (![position, finger.x, finger.y, height].every(Number.isFinite))
      return false;
    let source: ChapterStop | undefined;
    let nearest = Infinity;
    for (const stop of usable(stops)) {
      const distance = Math.abs(
        position - clamp(position, stop.readStart, stop.readEnd),
      );
      if (distance < nearest) {
        source = stop;
        nearest = distance;
      }
    }
    if (!source) return false;
    this.session = {
      source: source.id,
      anchor:
        source.readEnd - source.readStart <= edge * 2
          ? 'both'
          : position <= source.readStart + edge
            ? 'start'
            : position >= source.readEnd - edge
              ? 'end'
              : 'inside',
      outside:
        position < source.readStart - edge || position > source.readEnd + edge,
      mode: 'pending',
      finger: { ...finger },
      base: position,
      net: 0,
      height: Math.max(1, height),
      preview: position,
    };
    return true;
  }

  private boundaries(stops: readonly ChapterStop[]) {
    const current = this.session;
    if (!current) return;
    const ordered = usable(stops);
    const index = ordered.findIndex((stop) => stop.id === current.source);
    if (index < 0) return;
    const source = ordered[index]!;
    const direction = Math.sign(current.net);
    const outward =
      current.anchor === 'both' ||
      (direction > 0 && current.anchor === 'end') ||
      (direction < 0 && current.anchor === 'start');
    const neighbor = outward ? ordered[index + direction] : undefined;
    const home =
      current.anchor === 'end'
        ? source.readEnd
        : current.anchor === 'start' || current.anchor === 'both'
          ? source.readStart
          : clamp(current.base, source.readStart, source.readEnd);
    return { source, neighbor, home, direction, outward };
  }

  private offset(stops: readonly ChapterStop[]) {
    const current = this.session!;
    const boundary = this.boundaries(stops)!;
    if (!boundary.neighbor || !boundary.direction) return current.net;
    const destination =
      boundary.direction > 0
        ? boundary.neighbor.readStart
        : boundary.neighbor.readEnd;
    const limit = Math.min(
      current.height * 0.12,
      Math.abs(destination - boundary.home) * 0.18,
    );
    return boundary.direction * Math.min(Math.abs(current.net), limit);
  }

  move(
    stops: readonly ChapterStop[],
    finger: TouchPoint,
    height: number,
  ): MobileTouchMove {
    const current = this.session;
    if (!current || ![finger.x, finger.y, height].every(Number.isFinite)) {
      this.cancel();
      return { kind: 'ignored' };
    }
    current.net = current.finger.y - finger.y;
    current.height = Math.max(1, height);
    const boundary = this.boundaries(stops);
    if (!boundary) {
      this.cancel();
      return { kind: 'ignored' };
    }
    if (current.mode === 'pending') {
      const horizontal = Math.abs(finger.x - current.finger.x);
      const vertical = Math.abs(current.net);
      if (Math.max(horizontal, vertical) <= 8) return { kind: 'pending' };
      if (vertical < horizontal * 1.25) current.mode = 'ignored';
      else if (current.outside) current.mode = 'preview';
      else if (!boundary.outward) current.mode = 'native';
      else if (boundary.neighbor) current.mode = 'preview';
      else current.mode = 'ignored';
    }
    if (current.mode === 'ignored') return { kind: 'ignored' };
    if (current.mode === 'native')
      return { kind: 'native', source: current.source };
    const position = current.base + this.offset(stops);
    current.preview = boundary.neighbor
      ? position
      : clamp(
          position,
          current.outside
            ? Math.min(current.base, boundary.source.readStart)
            : boundary.source.readStart,
          current.outside
            ? Math.max(current.base, boundary.source.readEnd)
            : boundary.source.readEnd,
        );
    return {
      kind: 'preview',
      source: current.source,
      position: current.preview,
    };
  }

  finish(stops: readonly ChapterStop[]): MobileTouchFinish {
    const current = this.session;
    const boundary = this.boundaries(stops);
    this.session = undefined;
    if (!current || !boundary) return { kind: 'none' };
    if (current.mode === 'native')
      return { kind: 'native', source: current.source };
    if (
      current.mode !== 'preview' &&
      !(current.mode === 'pending' && current.outside)
    )
      return { kind: 'none' };
    if (Math.abs(current.net) >= 24 && boundary.neighbor)
      return { kind: 'settle', target: boundary.neighbor.id, duration: 1.2 };
    return {
      kind: 'settle',
      target: current.source,
      position: clamp(
        current.preview,
        boundary.source.readStart,
        boundary.source.readEnd,
      ),
      duration: 0.28,
    };
  }

  refresh(stops: readonly ChapterStop[], position: number, height: number) {
    const current = this.session;
    if (!current || !Number.isFinite(position) || !this.boundaries(stops))
      return this.cancel();
    current.height = Math.max(1, Number.isFinite(height) ? height : 1);
    if (current.mode === 'preview')
      current.base = position - this.offset(stops);
    else current.base = position;
    current.preview = position;
  }

  cancel() {
    this.session = undefined;
  }
}
