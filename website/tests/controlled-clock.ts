import type { Page } from '@playwright/test';

// Leave timers running during page initialization, then pause at a fixed time.
// The one-day window exceeds the bounded test timeout, so host scheduling cannot
// turn the target into a past timestamp between two browser protocol calls.
export async function installContractClock(page: Page) {
  await page.clock.install({ time: new Date('2026-01-01T00:00:00Z') });
  return () => page.clock.pauseAt(new Date('2026-01-02T00:00:00Z'));
}
