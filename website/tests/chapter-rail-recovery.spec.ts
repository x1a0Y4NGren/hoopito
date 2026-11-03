import { expect, test } from '@playwright/test';

test('a held rail pointer releases on background suspension and restores a readable landing', async ({
  page,
}) => {
  await page.route(/court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/, (r) =>
    r.abort(),
  );
  await page.goto('/');
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter-rail',
    'ready',
  );
  await page.waitForTimeout(300);
  const thumb = await page.locator('[data-rail-thumb]').boundingBox();
  const track = await page.locator('[data-rail-track]').boundingBox();
  await page.mouse.move(thumb!.x + 24, thumb!.y + 24);
  await page.mouse.down();
  await page.mouse.move(
    track!.x + 28,
    track!.y + 24 + (track!.height - 48) * 0.43,
    { steps: 10 },
  );
  await expect(page.locator('aside[data-chapter-rail]')).toHaveAttribute(
    'data-state',
    'dragging',
  );
  // Deterministic lifecycle injection checks suspension ownership separately
  // from actual OS/background presentation, which this test does not claim.
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.mouse.up();
  await expect(page.locator('aside[data-chapter-rail]')).toHaveJSProperty(
    'inert',
    true,
  );
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect
    .poll(() =>
      page.evaluate(() => {
        const stops = [
          ...document.querySelectorAll<HTMLElement>(
            '[data-story-stage], #closing',
          ),
        ];
        return stops.some(
          (el) =>
            scrollY >= Number(el.dataset.scrollReadStart) - 2 &&
            scrollY <= Number(el.dataset.scrollReadEnd) + 2,
        );
      }),
    )
    .toBe(true);
  await expect(page.locator('aside[data-chapter-rail]')).toHaveJSProperty(
    'inert',
    false,
  );
  await page.locator('[data-rail-node="download"]').focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('[data-rail-node="download"]')).toHaveAttribute(
    'aria-current',
    'location',
  );
});
