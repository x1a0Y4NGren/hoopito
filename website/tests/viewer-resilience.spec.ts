import { expect, test, type Page } from '@playwright/test';

async function openPage(page: Page, path = '/#scoring') {
  await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
    route.abort(),
  );
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
}

for (const path of ['/', '/en/']) {
  test(`${path}: gallery reports a failed image and retries without leaving the reader trapped`, async ({
    page,
  }) => {
    await openPage(page, `${path}#scoring`);
    const link = page.locator('#scoring .viewer-link');
    const source = (await link.getAttribute('href'))!;
    await link.evaluate(
      (element, href) => element.setAttribute('href', `${href}?audit=retry`),
      source,
    );
    let attempts = 0;
    await page.route('**/*?audit=retry', (route) => {
      attempts++;
      return attempts === 1 ? route.abort() : route.continue();
    });
    await link.click();
    await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
      'data-image-state',
      'error',
    );
    await expect(page.locator('[data-viewer-status]')).toBeVisible();
    await expect(page.locator('[data-viewer-status]')).not.toHaveText('');
    await expect(page.locator('[data-viewer-in]')).toBeDisabled();
    await expect(page.locator('[data-viewer-out]')).toBeDisabled();
    await page.locator('[data-viewer-retry]').click();
    await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
      'data-image-state',
      'ready',
    );
    await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
      'naturalWidth',
      1818,
    );
    await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
    await expect(page.locator('[data-viewer-in]')).toBeEnabled();
    await page.keyboard.press('Escape');
    await expect(link).toBeFocused();
  });
}

test('gallery resets stale zoom while a replacement image loads and ignores a late closed request', async ({
  page,
}) => {
  await openPage(page);
  const scoring = page.locator('#scoring .viewer-link');
  await scoring.click();
  await page.locator('[data-viewer-in]').click();
  await page.locator('[data-viewer-in]').click();
  await expect(page.locator('[data-viewer-scale]')).toHaveText('200%');
  await page.keyboard.press('Escape');
  await scoring.evaluate((element) =>
    element.setAttribute('href', `${element.getAttribute('href')}?audit=late`),
  );
  let release!: () => void;
  const held = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.route('**/*?audit=late', async (route) => {
    await held;
    await route.continue();
  });
  try {
    await scoring.click();
    await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
    await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
      'data-image-state',
      'loading',
    );
    await expect(page.locator('[data-viewer-in]')).toBeDisabled();
    await page.keyboard.press('Escape');
    await page.locator('[data-replay-device="summary"] .viewer-link').click();
    await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
      'naturalWidth',
      1080,
    );
    await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
      'data-image-state',
      'ready',
    );
    release();
    await expect(page.locator('[data-viewer-title]')).toHaveText('赛果与复盘');
    await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
      'naturalWidth',
      1080,
    );
    await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
  } finally {
    release();
  }
});

test('gallery preserves magnification through a viewport resize until fit is requested', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await openPage(page);
  await page.locator('#scoring .viewer-link').click();
  await page.locator('[data-viewer-in]').click();
  await page.locator('[data-viewer-in]').click();
  await expect(page.locator('[data-viewer-scale]')).toHaveText('200%');
  await page.setViewportSize({ width: 1280, height: 900 });
  await page.evaluate(
    () =>
      new Promise<void>((resolve) =>
        requestAnimationFrame(() =>
          requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
        ),
      ),
  );
  await expect(page.locator('[data-viewer-scale]')).toHaveText('200%');
  await page.locator('[data-viewer-fit]').click();
  await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
});

test('gallery keyboard magnifies and pans the picture without scrolling the page', async ({
  page,
}) => {
  await openPage(page);
  // fonts.ready does not finish native fragment navigation or the delayed
  // ScrollTrigger refresh. Establish its actual target before opening a modal
  // whose keyboard input must leave the underlying page at that position.
  await expect
    .poll(() =>
      page.locator('#scoring .section-top').evaluate(async (heading) => {
        const read = () => ({
          scroll: scrollY,
          top: heading.getBoundingClientRect().top,
          target:
            document.querySelector('.site-header')!.getBoundingClientRect()
              .bottom + 20,
        });
        const before = read();
        await new Promise(requestAnimationFrame);
        await new Promise(requestAnimationFrame);
        const after = read();
        return (
          Math.abs(after.top - after.target) < 1 &&
          before.scroll === after.scroll &&
          Math.abs(before.top - after.top) < 0.5
        );
      }),
    )
    .toBe(true);
  await page.locator('#scoring .viewer-link').click();
  await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
    'data-image-state',
    'ready',
  );
  const scroll = await page.evaluate(() => scrollY);
  await page.keyboard.press('+');
  await page.keyboard.press('+');
  await expect(page.locator('[data-viewer-scale]')).toHaveText('200%');
  const before = await page.locator('[data-viewer-image]').boundingBox();
  await page.keyboard.press('ArrowRight');
  const after = await page.locator('[data-viewer-image]').boundingBox();
  expect(after!.x).toBeLessThan(before!.x);
  expect(await page.evaluate(() => scrollY)).toBe(scroll);
  await page.keyboard.press('0');
  await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
  await page.keyboard.press('-');
  await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
});

test('gallery close icon stays inside its touch target at 200 percent text on mobile', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await openPage(page);
  await page.evaluate(() => {
    const sizes = [...document.querySelectorAll<HTMLElement>('body *')].map(
      (element) =>
        [element, parseFloat(getComputedStyle(element).fontSize)] as const,
    );
    for (const [element, size] of sizes)
      element.style.fontSize = `${size * 2}px`;
  });
  await page.locator('#scoring .viewer-link').click();
  const button = page.locator('[data-viewer-close]');
  const icon = button.locator('svg');
  await expect(icon).toBeVisible();
  const box = await button.boundingBox();
  const glyph = await icon.boundingBox();
  expect(box!.width).toBeGreaterThanOrEqual(48);
  expect(box!.height).toBeGreaterThanOrEqual(48);
  expect(glyph!.width).toBeLessThanOrEqual(box!.width);
  expect(glyph!.height).toBeLessThanOrEqual(box!.height);
  expect(glyph!.x).toBeGreaterThanOrEqual(box!.x);
  expect(glyph!.y).toBeGreaterThanOrEqual(box!.y);
  expect(glyph!.x + glyph!.width).toBeLessThanOrEqual(box!.x + box!.width);
  expect(glyph!.y + glyph!.height).toBeLessThanOrEqual(box!.y + box!.height);
  await button.click();
  await expect(page.locator('[data-viewer]')).not.toBeVisible();
});

test('short landscape gallery keeps a usable image area at 200 percent text', async ({
  page,
}) => {
  await page.setViewportSize({ width: 640, height: 360 });
  await openPage(page, '/en/#replay');
  await page.evaluate(() => {
    const sizes = [...document.querySelectorAll<HTMLElement>('body *')].map(
      (el) => [el, parseFloat(getComputedStyle(el).fontSize)] as const,
    );
    for (const [el, size] of sizes) el.style.fontSize = `${size * 2}px`;
  });
  await page.locator('[data-replay-device="summary"] .viewer-link').click();
  await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
    'data-image-state',
    'ready',
  );
  const viewport = await page.locator('[data-viewer-viewport]').boundingBox();
  expect(viewport!.height).toBeGreaterThan(120);
  const image = await page.locator('[data-viewer-image]').boundingBox();
  expect(image!.height).toBeGreaterThan(80);
  const footer = await page.locator('.viewer-footer').boundingBox();
  expect(footer!.y + footer!.height).toBeLessThanOrEqual(361);
  await page.locator('[data-viewer-in]').click();
  await expect(page.locator('[data-viewer-scale]')).toHaveText('150%');
  await page.locator('[data-viewer-close]').click();
  await expect(page.locator('[data-viewer]')).not.toBeVisible();
});
