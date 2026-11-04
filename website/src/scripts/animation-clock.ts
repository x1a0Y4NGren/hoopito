import { gsap } from 'gsap';

/** Keep foreground durations real; animation owners explicitly pause hidden time. */
export function createAnimationClock(
  initialSuspension: readonly string[] = [],
) {
  // Compressing every >500ms display frame to 33ms can turn a 1.2s chapter
  // transition into tens of seconds on software rendering. All visual owners
  // already pause/cancel through the page's shared suspension boundary.
  gsap.ticker.lagSmoothing(0);
  const reasons = new Set(initialSuspension);
  return {
    suspension: reasons as ReadonlySet<string>,
    setSuspended(reason: string, paused: boolean) {
      const wasSuspended = reasons.size > 0;
      if (paused) reasons.add(reason);
      else reasons.delete(reason);
      // RAF can stop entirely in a hidden document. Catch the ticker up while
      // its scene/shot/feedback owners are still paused, before they resume.
      // A second open overlay retains that pause until the final owner leaves.
      if (wasSuspended && !reasons.size) gsap.ticker.tick();
    },
  };
}
