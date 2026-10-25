import type { SceneQuality, StoryChapter } from './scene-contract';

const tiers: readonly SceneQuality[] = ['full', 'effects', 'density'];

export interface ActiveSample {
  quality: SceneQuality;
  changed: boolean;
  average: number;
  p95: number;
}

/** Wall-clock idle gaps never become evidence for reducing active animation quality. */
export class ActiveFrameMonitor {
  quality: SceneQuality = 'full';
  qualityCeiling: SceneQuality = 'full';
  private previous: number | null = null;
  private idleSince: number | null = null;
  private activeElapsed = 0;
  private window = 0;
  private samples: number[] = [];
  private slow = 0;
  private fast = 0;
  private changedAt = -Infinity;
  private pendingLongInterval = 0;

  reset() {
    this.previous = null;
    this.idleSince = null;
    this.activeElapsed = 0;
    this.window = 0;
    this.samples.length = 0;
    this.slow = 0;
    this.fast = 0;
    this.pendingLongInterval = 0;
  }

  observe(now: number, active: boolean): ActiveSample | null {
    if (!Number.isFinite(now)) {
      this.reset();
      return null;
    }
    if (!active) {
      // Reading is not a new GPU session. Keep the evidence from a short intro
      // or shot, but never measure the wall-clock pause between active segments.
      this.previous = null;
      this.pendingLongInterval = 0;
      this.idleSince ??= now;
      if (now - this.idleSince > 8000) {
        this.reset();
        this.idleSince = now;
      }
      return null;
    }
    if (this.idleSince !== null) {
      if (now - this.idleSince > 8000) this.reset();
      this.idleSince = null;
    }
    const interval = this.previous === null ? 0 : now - this.previous;
    this.previous = now;
    if (interval === 0) return null;
    if (interval < 0) {
      this.reset();
      this.previous = now;
      return null;
    }
    // One isolated long frame can be a foreground scheduling interruption. Consecutive
    // long active frames are genuine overload; resetting the window for each would hide it.
    if (interval > 250) {
      if (!this.pendingLongInterval) {
        this.pendingLongInterval = interval;
        return null;
      }
      this.collect(this.pendingLongInterval);
    }
    this.pendingLongInterval = 0;
    this.collect(interval);
    if (this.window < 1400 || this.samples.length < 4) return null;
    const average =
      this.samples.reduce((sum, value) => sum + value, 0) / this.samples.length;
    const sorted = [...this.samples].sort((a, b) => a - b);
    const p95 =
      sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * 0.95))]!;
    this.window = 0;
    this.samples.length = 0;
    this.slow = average > 1000 / 58 || p95 > 20 ? this.slow + 1 : 0;
    this.fast = average <= 16.9 && p95 <= 18.5 ? this.fast + 1 : 0;
    let index = tiers.indexOf(this.quality);
    let changed = false;
    if (
      (this.slow >= 2 || (index === 0 && average > 28)) &&
      index < tiers.length - 1 &&
      now - this.changedAt >= 6000
    ) {
      index += 1;
      changed = true;
    } else if (
      this.fast >= 4 &&
      index > tiers.indexOf(this.qualityCeiling) &&
      now - this.changedAt >= 15_000
    ) {
      index -= 1;
      changed = true;
    }
    if (changed) {
      this.quality = tiers[index]!;
      this.changedAt = now;
      this.slow = this.fast = 0;
    }
    return { quality: this.quality, changed, average, p95 };
  }

  private collect(interval: number) {
    this.activeElapsed += interval;
    this.window += interval;
    // First paint, shader compilation and explicit resets get a settling period.
    // The clock advances only for accepted active intervals, including across idle.
    if (this.activeElapsed >= 500) this.samples.push(interval);
  }
}

/** A Retina canvas retains at least 1.5 physical pixels per CSS pixel at every tier. */
export function renderDensity(
  deviceRatio: number,
  quality: SceneQuality,
  width: number,
  height: number,
) {
  const device = Number.isFinite(deviceRatio) ? Math.max(1, deviceRatio) : 1;
  const floor = device >= 1.5 ? 1.5 : 1;
  const desired = quality === 'density' ? floor : Math.min(2, device);
  return Math.min(
    desired,
    Math.max(floor, Math.sqrt(5_000_000 / Math.max(1, width * height))),
  );
}

/** Lower tiers skip HDR postprocessing only when the canvas itself smooths edges. */
export function sceneRenderRoute(quality: SceneQuality, nativeSamples: number) {
  return quality !== 'full' &&
    Number.isFinite(nativeSamples) &&
    nativeSamples > 0
    ? 'direct'
    : 'hdr';
}

export function shouldRenderContinuously(state: {
  active: boolean;
  chapter: StoryChapter;
  paused: boolean;
  motionEnabled: boolean;
  moving: boolean;
}) {
  return (
    state.active &&
    state.chapter !== 'download' &&
    !state.paused &&
    state.motionEnabled &&
    state.moving
  );
}
