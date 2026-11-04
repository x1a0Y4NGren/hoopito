import { expect, type Page } from '@playwright/test';

/** Observe a real anchor landing before native input takes navigation ownership. */
export async function expectAnchorReading(page: Page, id: string) {
  await page.evaluate(() => document.fonts.ready);
  await expect
    .poll(() =>
      page.evaluate(async (id) => {
        const stage = document.querySelector<HTMLElement>(
          `[data-story-stage="${id}"]`,
        )!;
        const snapshot = () => {
          const start = Number(stage.dataset.scrollReadStart);
          const end = Number(stage.dataset.scrollReadEnd);
          return {
            y: scrollY,
            start,
            end,
            ready:
              Number.isFinite(start) &&
              Number.isFinite(end) &&
              scrollY >= start - 2 &&
              scrollY <= end + 2 &&
              document.documentElement.dataset.scrollState === 'idle' &&
              document.documentElement.dataset.scrollStop === id &&
              [
                ...stage.querySelectorAll<HTMLElement>('[data-story-item]'),
              ].every(
                (item) =>
                  Number(getComputedStyle(item).opacity) >= 0.999 &&
                  !item.inert,
              ),
          };
        };
        const before = snapshot();
        await new Promise<void>((resolve) =>
          requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
        );
        const after = snapshot();
        return (
          before.ready &&
          after.ready &&
          Math.abs(before.y - after.y) <= 1 &&
          before.start === after.start &&
          before.end === after.end
        );
      }, id),
    )
    .toBe(true);
}
