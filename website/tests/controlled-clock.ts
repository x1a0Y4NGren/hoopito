import type { Page } from '@playwright/test';

// Leave timers running during page initialization, then pause at a fixed time.
// The one-day window exceeds the bounded test timeout, so host scheduling cannot
// turn the target into a past timestamp between two browser protocol calls.
export async function installContractClock(page: Page) {
  await page.clock.install({ time: new Date('2026-01-01T00:00:00Z') });
  return () => page.clock.pauseAt(new Date('2026-01-02T00:00:00Z'));
}

// Geometry checks need multiple actual draws even when software rendering takes
// longer than the animation. Fast-forward delivers one RAF at each sampled time;
// unlike runFor it does not draw every skipped 16ms frame. This verifies poses
// and contours, and provides no wall-clock cadence or performance evidence.
export async function sampleRenderedFlight(page: Page) {
  for (let elapsed = 0; elapsed < 1600; elapsed += 50)
    await page.clock.fastForward(50);
}
