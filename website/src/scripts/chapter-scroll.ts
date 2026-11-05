import { gsap } from 'gsap';
import type { StoryChapter } from './scene-contract';

export type StopId = StoryChapter | 'closing';
export interface ChapterStop {
  id: StopId;
  readStart: number;
  readEnd: number;
  /** Forward-scroll landmarks where the visible card enters/exits its chapter. */
  entryStart?: number;
  entryEnd?: number;
  exitStart?: number;
  exitEnd?: number;
}
export type ChapterScrollState = 'idle' | 'tracking' | 'settling' | 'draining';
type Action =
  | { kind: 'native' | 'hold' }
  | { kind: 'preview' | 'boundary'; y: number; stop: StopId }
  | { kind: 'settle'; y: number; duration: number; stop: StopId };

const INTENT = 24;
const REST_DELAY = 140;
const QUIET_DELAY = 180;
const INTENT_WINDOW = 80;
const EDGE_EPSILON = 2;
const clamp = (value: number, min: number, max: number) =>
  Math.min(max, Math.max(min, value));

/** Wheel deltaMode is part of the input; a line notch is not a pixel notch. */
export function normalizeWheelDelta(
  delta: number,
  mode: number,
  usableHeight: number,
  lineHeight = 16,
) {
  if (!Number.isFinite(delta)) return 0;
  const unit = mode === 1 ? lineHeight : mode === 2 ? usableHeight : 1;
  return Number.isFinite(unit) && unit > 0 ? delta * unit : 0;
}

function nearestStop(stops: readonly ChapterStop[], position: number) {
  let index = -1;
  let distance = Infinity;
  for (const [candidate, stop] of stops.entries()) {
    if (
      !Number.isFinite(stop.readStart) ||
      !Number.isFinite(stop.readEnd) ||
      stop.readEnd < stop.readStart
    )
      continue;
    const difference = Math.abs(
      position - clamp(position, stop.readStart, stop.readEnd),
    );
    if (difference < distance) {
      index = candidate;
      distance = difference;
    }
  }
  return index;
}

type ChapterPath = ((progress: number) => number) & {
  /** CSS pixels per unit of normalized profile time. */
  velocity(progress: number): number;
};
const profileStage = (progress: number) =>
  Number.isFinite(progress) ? clamp(progress, 0, 1) : 0;

/** Only real scroll moves: the camera and cards derive their phase from this Y. */
export function createChapterPath(
  from: number,
  to: number,
  // Retained for callers that still measure pin geometry; it is not flight time.
  _source?: ChapterStop,
  _target?: ChapterStop,
): ChapterPath {
  const distance = to - from;
  const path = (progress: number) => {
    const p = profileStage(progress);
    return p === 1 ? to : from + (distance * (1 - Math.cos(Math.PI * p))) / 2;
  };
  path.velocity = (progress: number) => {
    const p = profileStage(progress);
    return p === 0 || p === 1
      ? 0
      : ((distance * Math.PI) / 2) * Math.sin(Math.PI * p);
  };
  return path;
}

/** Reflow keeps position and the old tangent when a monotone tail permits it.
 * A collapsed/reversed gap clips that tangent: landing safely takes priority.
 */
function createChapterTail(
  from: number,
  to: number,
  seconds: number,
  incomingVelocity: number,
): ChapterPath {
  const distance = to - from;
  const tangent =
    distance === 0 ? 0 : clamp((incomingVelocity * seconds) / distance, 0, 3);
  const path = (progress: number) => {
    const p = profileStage(progress);
    const amount =
      -2 * p ** 3 + 3 * p ** 2 + tangent * (p ** 3 - 2 * p ** 2 + p);
    return p === 1 ? to : from + distance * clamp(amount, 0, 1);
  };
  path.velocity = (progress: number) => {
    const p = profileStage(progress);
    return (
      distance * (-6 * p ** 2 + 6 * p + tangent * (3 * p ** 2 - 4 * p + 1))
    );
  };
  return path;
}

/** Device-independent gesture policy. Browser writes/timing live in the adapter below. */
export class ChapterGesture {
  state: ChapterScrollState = 'idle';
  stop: StopId | undefined;
  private mode:
    'none' | 'native' | 'tracking' | 'returning' | 'settling' | 'draining' =
    'none';
  private last = -Infinity;
  private source: ChapterStop | undefined;
  private sourceIndex = -1;
  private origin = 0;
  private home = 0;
  private intent = 0;
  private renewed: { delta: number; start: number; count: number } | undefined;
  private energy:
    | { direction: number; start: number; amount: number; recent: number[] }
    | undefined;

  get sourceStop() {
    return this.source;
  }
  get returning() {
    return this.mode === 'returning';
  }
  /** Explicit navigation shares the same committed-motion and inertia policy. */
  beginNavigation(stop: StopId, now: number) {
    this.cancel();
    this.mode = 'settling';
    this.state = 'settling';
    this.stop = stop;
    this.last = now;
  }
  keepAlive(now: number) {
    this.last = now;
    this.renewed = undefined;
    this.energy = undefined;
  }
  /** Integrate CSS distance, so high-resolution packets cannot starve intent.
   * Three complete windows separate sustained pressure from short plateaus.
   * A small energy tolerance absorbs packet-boundary noise; consecutive falls
   * still describe decay. This observes only input received after landing.
   */
  private integratesIntent(delta: number, now: number) {
    const direction = Math.sign(delta);
    let run = this.energy;
    if (!run || run.direction !== direction)
      this.energy = run = { direction, start: now, amount: 0, recent: [] };
    const elapsed = Math.floor((now - run.start) / INTENT_WINDOW);
    if (elapsed > 0) {
      run.recent = elapsed === 1 ? [...run.recent, run.amount].slice(-3) : [];
      run.start += elapsed * INTENT_WINDOW;
      run.amount = 0;
    }
    run.amount += Math.abs(delta);
    const [first, middle, last] = run.recent;
    return (
      run.recent.length === 3 &&
      run.recent.every((amount) => amount >= INTENT) &&
      last >= first * 0.9 &&
      !(middle < first && last < middle)
    );
  }
  /** A stable run after landing can express fresh intent without a wheel pause.
   * Decay, fine momentum and brief quantized plateaus keep the inertia lock.
   * This recognizes intent, not a particular mouse or touchpad device.
   */
  private renewsIntent(delta: number, now: number) {
    const integrated = this.integratesIntent(delta, now);
    const previous = this.renewed;
    if (Math.abs(delta) < INTENT) {
      this.renewed = undefined;
      return integrated;
    }
    if (
      !previous ||
      Math.sign(delta) !== Math.sign(previous.delta) ||
      Math.abs(delta) < Math.abs(previous.delta)
    ) {
      this.renewed = { delta, start: now, count: 1 };
      return integrated;
    }
    this.renewed = { ...previous, delta, count: previous.count + 1 };
    return (
      integrated ||
      (this.renewed.count >= 3 && now - previous.start >= QUIET_DELAY)
    );
  }
  /** Reflow changes coordinates, never the already chosen chapter or wheel intent. */
  remeasure(stops: readonly ChapterStop[], position: number) {
    this.renewed = undefined;
    this.energy = undefined;
    if (!this.source) return true;
    const index = stops.findIndex((stop) => stop.id === this.source!.id);
    const source = stops[index];
    if (!source) return false;
    this.source = source;
    this.sourceIndex = index;
    this.home = clamp(this.home, source.readStart, source.readEnd);
    this.origin = clamp(
      position - this.intent,
      source.readStart,
      source.readEnd,
    );
    return true;
  }

  input(
    delta: number,
    now: number,
    position: number,
    stops: readonly ChapterStop[],
    viewportHeight: number,
  ): Action {
    if (!delta || !Number.isFinite(delta) || !Number.isFinite(position))
      return { kind: 'native' };
    // Completion alone never releases a long touchpad inertia tail.
    this.release(now);
    // A slow touchpad may deliver its next event after the provisional return
    // started. Only a committed chapter is locked against further wheel input.
    if (this.mode === 'returning') {
      if (now - this.last >= QUIET_DELAY) this.cancel();
      else {
        this.mode = 'tracking';
        this.state = 'tracking';
      }
    }
    if (
      this.mode === 'settling' ||
      (this.mode === 'draining' && !this.renewsIntent(delta, now))
    ) {
      this.last = now;
      return { kind: 'hold' };
    }
    // Never queue animation-time input. Only this fresh post-landing sample
    // can start another adjacent transition from the current reading position.
    const renewed = this.mode === 'draining';
    if (renewed) this.cancel();
    if (now - this.last >= QUIET_DELAY) this.cancel();
    this.last = now;
    if (!this.source) {
      this.sourceIndex = nearestStop(stops, position);
      this.source = stops[this.sourceIndex];
      if (!this.source) return { kind: 'native' };
      this.stop = this.source.id;
      this.origin = position;
      this.home = clamp(position, this.source.readStart, this.source.readEnd);
    }
    const source = this.source;
    const hasReadingRange = source.readEnd - source.readStart > EDGE_EPSILON;
    if (hasReadingRange) {
      const canRead =
        delta > 0
          ? position < source.readEnd - EDGE_EPSILON
          : position > source.readStart + EDGE_EPSILON;
      if (canRead) {
        this.mode = 'native';
        this.state = 'idle';
        this.intent = 0;
        const boundary = delta > 0 ? source.readEnd : source.readStart;
        if (
          delta > 0
            ? position + delta >= boundary
            : position + delta <= boundary
        ) {
          this.state = 'draining';
          return { kind: 'boundary', y: boundary, stop: source.id };
        }
        return { kind: 'native' };
      }
      // This gesture was spent reading. Its remaining momentum cannot skip ahead.
      if (this.mode === 'native') {
        this.state = 'draining';
        return { kind: 'hold' };
      }
    }
    this.intent += delta;
    // A confirmed window has already supplied at least24px of intent. Consume
    // it now even if this particular packet is8px and no further packet comes.
    if (renewed)
      this.intent = Math.sign(delta) * Math.max(INTENT, Math.abs(this.intent));
    const direction = Math.sign(this.intent);
    const target = stops[this.sourceIndex + direction];
    if (
      !direction ||
      !target ||
      !Number.isFinite(target.readStart) ||
      !Number.isFinite(target.readEnd)
    ) {
      if (this.mode === 'tracking' && !direction)
        return { kind: 'preview', y: this.origin, stop: source.id };
      this.cancel();
      return { kind: 'native' };
    }
    const destination = direction > 0 ? target.readStart : target.readEnd;
    if (Math.abs(this.intent) >= INTENT) {
      this.mode = 'settling';
      this.state = 'settling';
      this.stop = target.id;
      return {
        kind: 'settle',
        y: destination,
        duration: 1.2,
        stop: target.id,
      };
    }
    this.mode = 'tracking';
    this.state = 'tracking';
    const limit = Math.max(
      0,
      Math.min(viewportHeight * 0.12, Math.abs(destination - this.home) * 0.18),
    );
    return {
      kind: 'preview',
      y: this.origin + clamp(this.intent, -limit, limit),
      stop: source.id,
    };
  }

  rest(now: number): Extract<Action, { kind: 'settle' }> | undefined {
    if (this.mode !== 'tracking' || now - this.last < REST_DELAY) return;
    this.mode = 'returning';
    this.state = 'settling';
    return {
      kind: 'settle',
      y: this.home,
      duration: 0.28,
      stop: this.source!.id,
    };
  }

  complete(now: number) {
    if (this.mode !== 'settling' && this.mode !== 'returning') return;
    this.mode = 'draining';
    this.state = 'draining';
    this.renewed = undefined;
    this.energy = undefined;
    this.release(now);
  }

  release(now: number) {
    if (
      (this.mode === 'draining' ||
        (this.mode === 'native' && this.state === 'draining')) &&
      now - this.last >= QUIET_DELAY
    )
      this.cancel();
  }

  cancel() {
    this.mode = 'none';
    this.state = 'idle';
    this.source = undefined;
    this.sourceIndex = -1;
    this.stop = undefined;
    this.intent = 0;
    this.last = -Infinity;
    this.renewed = undefined;
    this.energy = undefined;
  }
}

interface ChapterScrollOptions {
  getStops(): readonly ChapterStop[];
  enabled(): boolean;
  /** Explicit navigation may remain available when reduced motion disables snap. */
  canNavigate?(): boolean;
  /** Write instant native scroll and update the existing shared visual frame. */
  write(y: number): void;
  onState?(state: ChapterScrollState, stop?: StopId): void;
}

interface TouchSettlement {
  target?: StopId;
  position?: number;
  duration?: number;
  instant?: boolean;
}

/** One task owns wheel, chapter navigation or rail drag; native scroll stays true. */
export function createChapterScroll(options: ChapterScrollOptions) {
  const gesture = new ChapterGesture();
  let disposed = false;
  let epoch = 0;
  let tween: gsap.core.Tween | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  let expected: number | undefined;
  let writeReceipt: number | undefined;
  let lastWheel = -Infinity;
  let previewFrame = 0;
  let pendingPreview = 0;
  let pendingDrag: number | undefined;
  let pendingTouch: number | undefined;
  let pendingTouchEnd: TouchSettlement | undefined;
  let touchTimer: ReturnType<typeof setTimeout> | undefined;
  let touchSession:
    { id: StopId; native: boolean; released: boolean } | undefined;
  let previousState = '';
  let refreshing = false;
  let refreshFrame = 0;
  let landingFrame = 0;
  let landing: number | undefined;
  let owner: 'wheel' | 'navigation' | 'drag' | 'touch' | undefined;
  let motion:
    | {
        target: StopId;
        origin: number;
        position?: number;
        committed: boolean;
        direction: number;
        home: number;
        remaining: number;
        destination: number;
        path: ChapterPath;
        pathDuration: number;
        stage: number;
        startStage: number;
      }
    | undefined;
  // Some platforms send uncancelable inertia events. Associate only their
  // same-direction, bounded native displacement, never arbitrary external seeks.
  let nativeTail: { remaining: number; expires: number } | undefined;

  const canNavigate = () => options.canNavigate?.() ?? options.enabled();
  const canOwn = () =>
    owner === 'navigation' || owner === 'drag' || owner === 'touch'
      ? canNavigate()
      : options.enabled();
  function notify() {
    const phase =
      owner === 'touch' && touchSession
        ? touchSession.released
          ? 'draining'
          : 'tracking'
        : owner === 'drag'
          ? 'tracking'
          : gesture.state;
    const stop = owner === 'touch' ? touchSession?.id : gesture.stop;
    if (phase === 'idle') {
      landing = undefined;
      owner = undefined;
    }
    const key = `${phase}:${stop ?? ''}`;
    if (key === previousState) return;
    previousState = key;
    options.onState?.(phase, stop);
  }
  function cancel() {
    epoch++;
    tween?.kill();
    tween = undefined;
    clearTimeout(timer);
    clearTimeout(touchTimer);
    cancelAnimationFrame(previewFrame);
    cancelAnimationFrame(refreshFrame);
    cancelAnimationFrame(landingFrame);
    previewFrame = 0;
    refreshFrame = 0;
    landingFrame = 0;
    landing = undefined;
    refreshing = false;
    motion = undefined;
    nativeTail = undefined;
    expected = undefined;
    writeReceipt = undefined;
    lastWheel = -Infinity;
    owner = undefined;
    pendingDrag = undefined;
    pendingTouch = undefined;
    pendingTouchEnd = undefined;
    touchSession = undefined;
    gesture.cancel();
    notify();
  }
  function write(y: number) {
    writeReceipt = undefined;
    expected = clamp(
      y,
      0,
      Math.max(0, document.documentElement.scrollHeight - innerHeight),
    );
    options.write(expected);
    if (tween && Math.abs(scrollY - expected) <= EDGE_EPSILON) {
      // Native scrolling can quantize the requested CSS position.
      expected = scrollY;
      writeReceipt = scrollY;
    }
  }
  function armQuiet() {
    clearTimeout(timer);
    if (
      refreshing ||
      disposed ||
      owner === 'drag' ||
      owner === 'touch' ||
      gesture.state === 'idle'
    )
      return;
    const quiet = gesture.state === 'tracking' ? REST_DELAY : QUIET_DELAY;
    timer = setTimeout(
      () => {
        if (disposed) return;
        if (!canOwn()) return cancel();
        const now = performance.now();
        const rollback = gesture.rest(now);
        if (rollback) animate(rollback);
        else {
          gesture.release(now);
          notify();
          // Timers may wake a fraction early; do not strand a tiny preview.
          if (gesture.state === 'tracking' || gesture.state === 'draining')
            armQuiet();
        }
      },
      Math.max(1, quiet - (performance.now() - lastWheel)),
    );
  }
  function animate(
    action: Extract<Action, { kind: 'settle' }>,
    resume = false,
  ) {
    cancelAnimationFrame(previewFrame);
    previewFrame = 0;
    tween?.kill();
    landing = undefined;
    owner ??= 'wheel';
    if (!resume)
      motion = {
        target: action.stop,
        origin: scrollY,
        committed: !gesture.returning,
        direction: Math.sign(action.y - scrollY),
        home: action.y,
        remaining: action.duration,
        destination: action.y,
        path: createChapterPath(scrollY, action.y),
        pathDuration: action.duration,
        stage: 0,
        startStage: 0,
      };
    const active = motion;
    if (!active) return;
    if (
      resume &&
      (action.y !== active.destination ||
        Math.abs(scrollY - active.path(active.stage)) > EDGE_EPSILON)
    ) {
      const velocity = active.path.velocity(active.stage) / active.pathDuration;
      active.path = createChapterTail(
        scrollY,
        action.y,
        active.remaining,
        velocity,
      );
      active.pathDuration = active.remaining;
      active.stage = 0;
      active.destination = action.y;
    }
    active.startStage = active.stage;
    const generation = ++epoch;
    const value = { progress: 0 };
    tween = gsap.to(value, {
      progress: 1,
      duration: action.duration,
      ease: 'none',
      onUpdate() {
        if (generation !== epoch || disposed) return;
        if (!canOwn()) return cancel();
        active.stage =
          active.startStage + (1 - active.startStage) * value.progress;
        write(active.path(active.stage));
      },
      onComplete() {
        if (generation !== epoch || disposed) return;
        completeMotion(action.y);
      },
    });
    notify();
  }
  function completeMotion(y: number) {
    tween = undefined;
    writeReceipt = undefined;
    landing = y;
    motion = undefined;
    gesture.complete(performance.now());
    notify();
    armQuiet();
  }
  function prepareRefresh() {
    if (disposed || refreshing) return;
    refreshing = true;
    if (motion && tween) {
      motion.stage =
        motion.startStage + (1 - motion.startStage) * tween.progress();
      motion.remaining = motion.pathDuration * (1 - motion.stage);
    }
    epoch++;
    tween?.kill();
    tween = undefined;
    clearTimeout(timer);
    clearTimeout(touchTimer);
    cancelAnimationFrame(previewFrame);
    previewFrame = 0;
    expected = undefined;
    writeReceipt = undefined;
    nativeTail = undefined;
    cancelAnimationFrame(landingFrame);
    landingFrame = 0;
    landing = undefined;
  }
  function refresh() {
    if (disposed) return;
    if (!canOwn()) return cancel();
    if (!refreshing) prepareRefresh();
    cancelAnimationFrame(refreshFrame);
    const generation = epoch;
    refreshFrame = requestAnimationFrame(() => {
      refreshFrame = 0;
      if (disposed || generation !== epoch) return;
      if (!canOwn()) return cancel();
      const stops = options.getStops();
      if (!gesture.remeasure(stops, scrollY)) return cancel();
      refreshing = false;
      if (owner === 'touch' && touchSession) {
        if (!touchStop()) return cancel();
        expected = scrollY;
        const latest = pendingTouch;
        pendingTouch = undefined;
        if (touchSession.native) containTouchReading();
        else if (latest !== undefined) write(latest);
        const settlement = pendingTouchEnd;
        pendingTouchEnd = undefined;
        if (settlement) endTouch(settlement);
        else armTouchQuiet();
        return;
      }
      if (owner === 'drag') {
        expected = scrollY;
        const latest = pendingDrag;
        pendingDrag = undefined;
        if (latest !== undefined) write(latest);
        return;
      }
      if (motion) {
        const target = stops.find((stop) => stop.id === motion!.target);
        if (
          !target ||
          !Number.isFinite(target.readStart) ||
          !Number.isFinite(target.readEnd) ||
          target.readEnd < target.readStart
        )
          return cancel();
        if (
          motion.committed &&
          scrollY >= target.readStart - EDGE_EPSILON &&
          scrollY <= target.readEnd + EDGE_EPSILON
        ) {
          completeMotion(scrollY);
          return;
        }
        const y =
          motion.position !== undefined
            ? clamp(motion.position, target.readStart, target.readEnd)
            : motion.committed
              ? motion.direction >= 0
                ? target.readStart
                : target.readEnd
              : clamp(motion.home, target.readStart, target.readEnd);
        animate(
          { kind: 'settle', y, duration: motion.remaining, stop: target.id },
          true,
        );
      }
      armQuiet();
    });
  }
  function navigateTo(
    id: StopId,
    navigation: {
      instant?: boolean;
      duration?: number;
      position?: number;
    } = {},
  ): boolean {
    if (disposed || !canNavigate() || !Number.isFinite(scrollY)) return false;
    const stops = options.getStops();
    const index = stops.findIndex((stop) => stop.id === id);
    const target = stops[index];
    if (
      !target ||
      !Number.isFinite(target.readStart) ||
      !Number.isFinite(target.readEnd) ||
      target.readEnd < target.readStart ||
      (navigation.position !== undefined &&
        !Number.isFinite(navigation.position)) ||
      (navigation.duration !== undefined &&
        (!Number.isFinite(navigation.duration) || navigation.duration < 0))
    )
      return false;
    const from = scrollY;
    const hops = Math.max(1, Math.abs(index - nearestStop(stops, from)));
    const duration =
      navigation.duration ?? Math.min(1.8, 1.2 + 0.12 * (hops - 1));
    const destination =
      navigation.position !== undefined
        ? clamp(navigation.position, target.readStart, target.readEnd)
        : from < target.readStart
          ? target.readStart
          : target.readEnd;
    cancel();
    // Clicking the current chapter preserves its natural long-content position.
    if (
      navigation.position === undefined &&
      from >= target.readStart - EDGE_EPSILON &&
      from <= target.readEnd + EDGE_EPSILON
    )
      return true;
    if (Math.abs(destination - from) <= EDGE_EPSILON) return true;
    if (navigation.instant || duration === 0) {
      write(destination);
      return true;
    }
    owner = 'navigation';
    lastWheel = performance.now();
    gesture.beginNavigation(id, lastWheel);
    animate({ kind: 'settle', y: destination, duration, stop: id });
    if (motion && navigation.position !== undefined)
      motion.position = navigation.position;
    return true;
  }
  function beginDrag() {
    if (disposed || !canNavigate()) return;
    cancel();
    owner = 'drag';
    expected = scrollY;
    notify();
  }

  function touchStop() {
    const stop = options
      .getStops()
      .find((candidate) => candidate.id === touchSession?.id);
    return stop &&
      Number.isFinite(stop.readStart) &&
      Number.isFinite(stop.readEnd) &&
      stop.readEnd >= stop.readStart
      ? stop
      : undefined;
  }

  function containTouchReading() {
    const stop = touchStop();
    if (!stop || !canNavigate()) return cancel();
    const bounded = clamp(scrollY, stop.readStart, stop.readEnd);
    expected = scrollY;
    // Native pan stays native while it can read. Only the chapter boundary
    // stops its remaining displacement, including momentum after finger-up.
    if (Math.abs(bounded - scrollY) > EDGE_EPSILON) write(bounded);
  }

  function armTouchQuiet() {
    clearTimeout(touchTimer);
    if (
      disposed ||
      refreshing ||
      owner !== 'touch' ||
      !touchSession?.native ||
      !touchSession.released
    )
      return;
    touchTimer = setTimeout(() => {
      if (owner === 'touch' && touchSession?.native && touchSession.released)
        cancel();
    }, 120);
  }

  /** Claim one phone finger sequence; desktop wheel capture remains separate. */
  function beginTouch(id: StopId, config: { native?: boolean } = {}) {
    if (disposed || !canNavigate() || !Number.isFinite(scrollY)) return false;
    const stop = options.getStops().find((candidate) => candidate.id === id);
    if (
      !stop ||
      !Number.isFinite(stop.readStart) ||
      !Number.isFinite(stop.readEnd) ||
      stop.readEnd < stop.readStart ||
      (config.native &&
        Math.abs(scrollY - clamp(scrollY, stop.readStart, stop.readEnd)) >
          EDGE_EPSILON)
    )
      return false;
    cancel();
    owner = 'touch';
    touchSession = { id, native: config.native ?? false, released: false };
    expected = scrollY;
    notify();
    return true;
  }

  function moveTouch(y: number) {
    if (disposed || owner !== 'touch' || !touchSession || !Number.isFinite(y))
      return;
    if (!canNavigate()) return cancel();
    if (touchSession.native) return;
    if (refreshing) pendingTouch = y;
    else write(y);
  }

  function endTouch(settlement?: TouchSettlement) {
    if (disposed || owner !== 'touch' || !touchSession) return;
    if (!canNavigate()) return cancel();
    const stop = touchStop();
    if (!stop) return cancel();
    touchSession.released = true;
    if (settlement || !touchSession.native) {
      const request = settlement ?? {
        target: stop.id,
        position: clamp(scrollY, stop.readStart, stop.readEnd),
        duration: 0.28,
      };
      if (refreshing) pendingTouchEnd = request;
      else if (
        !navigateTo(request.target ?? stop.id, {
          position: request.position,
          duration: request.duration,
          instant: request.instant,
        })
      )
        cancel();
    } else {
      if (!refreshing) containTouchReading();
      notify();
      armTouchQuiet();
    }
  }

  function touchScrollEnd() {
    if (
      owner === 'touch' &&
      touchSession?.native &&
      touchSession.released &&
      !refreshing
    )
      cancel();
  }
  function dragTo(y: number) {
    if (disposed || owner !== 'drag' || !Number.isFinite(y)) return;
    if (!canNavigate()) return cancel();
    if (refreshing) pendingDrag = y;
    else write(y);
  }
  function endDrag(direction: number, instant = false) {
    if (disposed || owner !== 'drag') return;
    if (!canNavigate()) return cancel();
    let target: ChapterStop | undefined;
    let distance = Infinity;
    for (const stop of options.getStops()) {
      if (
        !Number.isFinite(stop.readStart) ||
        !Number.isFinite(stop.readEnd) ||
        stop.readEnd < stop.readStart
      )
        continue;
      const difference = Math.abs(
        scrollY - clamp(scrollY, stop.readStart, stop.readEnd),
      );
      if (difference < distance || (difference === distance && direction > 0)) {
        target = stop;
        distance = difference;
      }
    }
    cancel();
    if (target)
      navigateTo(target.id, {
        instant,
        duration: 0.42,
        position: clamp(scrollY, target.readStart, target.readEnd),
      });
  }
  function nestedScroll(target: EventTarget | null, delta: number) {
    for (
      let node = target instanceof Element ? target : null;
      node && node !== document.body && node !== document.documentElement;
      node = node.parentElement
    ) {
      if (
        node.matches(
          'input, textarea, select, [contenteditable]:not([contenteditable="false"])',
        )
      )
        return true;
      if (node.scrollHeight <= node.clientHeight + 1) continue;
      const overflow = getComputedStyle(node).overflowY;
      if (
        /^(auto|scroll|overlay)$/.test(overflow) &&
        (delta > 0
          ? node.scrollTop + node.clientHeight < node.scrollHeight - 1
          : node.scrollTop > 1)
      )
        return true;
    }
    return false;
  }
  function allowNativeDisplacement(delta: number, now: number) {
    const carried =
      nativeTail &&
      now <= nativeTail.expires &&
      Math.sign(nativeTail.remaining) === Math.sign(delta)
        ? nativeTail.remaining
        : 0;
    // Native compositor writes can arrive after the 80ms intent bucket on
    // WebKit. Retain their signed, bounded receipt through the gesture's quiet
    // window; explicit pointer, keyboard and navigation takeover still clears it.
    nativeTail = { remaining: carried + delta, expires: now + QUIET_DELAY };
  }
  function wheel(event: WheelEvent) {
    if (disposed) return;
    const height = Math.max(1, innerHeight);
    const delta = normalizeWheelDelta(event.deltaY, event.deltaMode, height);
    if (event.ctrlKey || event.metaKey) return cancel();
    if (owner === 'touch') cancel();
    if (owner === 'drag') {
      if (!canNavigate()) return cancel();
      if (delta && event.cancelable) event.preventDefault();
      return;
    }
    if (!options.enabled()) return cancel();
    if (event.defaultPrevented || !delta || nestedScroll(event.target, delta))
      return;
    const now = performance.now();
    if (Math.abs(event.deltaX) >= Math.abs(event.deltaY)) {
      if (gesture.state === 'idle') return;
      allowNativeDisplacement(delta, now);
      gesture.keepAlive(now);
      lastWheel = now;
      armQuiet();
      return;
    }
    if (refreshing) {
      if (gesture.state === 'idle') return;
      if (event.cancelable) event.preventDefault();
      gesture.keepAlive(now);
      lastWheel = now;
      return;
    }
    const wasReturning = gesture.returning;
    const action = gesture.input(
      delta,
      now,
      scrollY,
      options.getStops(),
      height,
    );
    if (action.kind !== 'hold') owner = 'wheel';
    if (wasReturning && action.kind !== 'hold') {
      // Invalidate the old rollback, retaining the resumed gesture's home/intent.
      epoch++;
      tween?.kill();
      tween = undefined;
      motion = undefined;
    }
    lastWheel = now;
    if (action.kind === 'native') {
      expected = undefined;
      clearTimeout(timer);
      notify();
      return;
    }
    if (event.cancelable) event.preventDefault();
    else {
      // Some wheel sequences only allow cancelling their first sample. Later
      // vertical samples still express intent; track their bounded browser
      // displacement rather than dropping them or waiting for mouse movement.
      expected ??= scrollY;
      allowNativeDisplacement(delta, now);
    }
    if (action.kind === 'preview') {
      pendingPreview = action.y;
      if (!previewFrame) {
        const origin = scrollY;
        previewFrame = requestAnimationFrame(() => {
          previewFrame = 0;
          if (disposed || gesture.state !== 'tracking') return;
          // External seeks may precede the first owned write and scroll event.
          if (Math.abs(scrollY - (expected ?? origin)) > EDGE_EPSILON)
            return cancel();
          write(pendingPreview);
        });
      }
    } else if (action.kind === 'boundary') {
      landing = action.y;
      write(action.y);
    } else if (action.kind === 'settle') animate(action);
    notify();
    armQuiet();
  }
  function scroll() {
    if (refreshing) return;
    if (owner === 'touch' && touchSession?.native) {
      containTouchReading();
      armTouchQuiet();
      return;
    }
    // A scrollbar drag, anchor, focus reveal or external seek owns the new position.
    if (expected !== undefined && Math.abs(scrollY - expected) > EDGE_EPSILON) {
      const difference = scrollY - expected;
      if (
        nativeTail &&
        performance.now() <= nativeTail.expires &&
        Math.sign(difference) === Math.sign(nativeTail.remaining) &&
        Math.abs(difference) <= Math.abs(nativeTail.remaining) + EDGE_EPSILON
      ) {
        // A known native tail owns this displacement, consuming the self-write
        // receipt too. It must never leave a second allowance at an older point.
        writeReceipt = undefined;
        nativeTail.remaining -= difference;
        expected = scrollY;
        if (Math.abs(nativeTail.remaining) <= EDGE_EPSILON)
          nativeTail = undefined;
        if (
          !tween &&
          landing !== undefined &&
          gesture.state === 'draining' &&
          !landingFrame
        ) {
          const generation = epoch;
          landingFrame = requestAnimationFrame(() => {
            landingFrame = 0;
            if (
              generation !== epoch ||
              disposed ||
              refreshing ||
              tween ||
              landing === undefined ||
              gesture.state !== 'draining'
            )
              return;
            if (
              !options.enabled() ||
              expected === undefined ||
              Math.abs(scrollY - expected) > EDGE_EPSILON
            )
              return cancel();
            // Only the bounded native wheel displacement accepted above can
            // trigger this confirmation. Unknown manual seeks still cancel.
            write(landing);
          });
        }
      } else if (
        tween &&
        writeReceipt !== undefined &&
        Math.abs(difference) <= 3 &&
        Math.abs(scrollY - writeReceipt) <= 3
      ) {
        // WebKit may revise an acknowledged self-write by another 3 CSS px.
        // Consume only this write's receipt; explicit input still cancels, and
        // previews, final landings and larger unknown seeks retain the old bound.
        expected = scrollY;
        writeReceipt = undefined;
      } else cancel();
    }
  }
  function visibility() {
    if (document.hidden) cancel();
  }
  function keyCancel(event?: KeyboardEvent) {
    if (event?.key === 'Escape' && owner === 'navigation') {
      const direction = motion?.direction ?? 0;
      beginDrag();
      endDrag(direction);
    } else cancel();
  }
  window.addEventListener('wheel', wheel, { passive: false });
  window.addEventListener('scroll', scroll, { passive: true });
  // Capture relinquishes an old task before the rail's bubbling handler claims it.
  window.addEventListener('pointerdown', cancel, {
    passive: true,
    capture: true,
  });
  window.addEventListener('touchstart', cancel, { passive: true });
  window.addEventListener('keydown', keyCancel, true);
  document.addEventListener('visibilitychange', visibility);
  document.addEventListener('scrollend', touchScrollEnd);
  notify();
  return {
    cancel,
    prepareRefresh,
    refresh,
    navigateTo,
    beginDrag,
    dragTo,
    endDrag,
    beginTouch,
    moveTouch,
    endTouch,
    isDragging: () => owner === 'drag',
    getMotion: () =>
      motion
        ? { from: motion.origin, to: motion.destination, target: motion.target }
        : undefined,
    dispose() {
      if (disposed) return;
      disposed = true;
      cancel();
      window.removeEventListener('wheel', wheel);
      window.removeEventListener('scroll', scroll);
      window.removeEventListener('pointerdown', cancel, true);
      window.removeEventListener('touchstart', cancel);
      window.removeEventListener('keydown', keyCancel, true);
      document.removeEventListener('visibilitychange', visibility);
      document.removeEventListener('scrollend', touchScrollEnd);
    },
  };
}
