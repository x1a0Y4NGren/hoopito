import { expect, test } from '@playwright/test';

test(
  'desktop refresh at experience uses the actual overhead scene while WebGL loads',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The renderer loading lifecycle runs in Chromium.',
    );
    if (process.env.CI) {
      // Match the existing renderer suite's boundary override for CI SwiftShader.
      await page.addInitScript(() => {
        const original = HTMLCanvasElement.prototype.getContext;
        HTMLCanvasElement.prototype.getContext = function (
          this: HTMLCanvasElement,
          type: string,
          ...args: unknown[]
        ) {
          if (type === 'webgl2')
            args[0] = {
              ...(args[0] as WebGLContextAttributes | undefined),
              failIfMajorPerformanceCaveat: false,
            };
          return Reflect.apply(original, this, [type, ...args]);
        } as typeof original;
      });
    }
    await page.setViewportSize({ width: 1440, height: 1000 });
    let release!: () => void;
    const held = new Promise<void>((resolve) => {
      release = resolve;
    });
    await page.route(/court-scene[^/]*\.js$/, async (route) => {
      await held;
      await route.continue();
    });
    try {
      await page.goto('/#experience', { waitUntil: 'domcontentloaded' });
      // Check the HTML loading state before releasing the module. WebKit can
      // defer FontFaceSet.ready until that outstanding module request completes.
      const poster = page.locator('[data-demo-poster] img');
      await expect(poster).toBeVisible();
      await expect
        .poll(() =>
          poster.evaluate((image: HTMLImageElement) => image.currentSrc),
        )
        .toMatch(/\/art\/scene-poster-demo-standard\.webp$/);
      // The standard capture keeps the 48vw background canvas at its native
      // 1440×900 reference viewport, rather than the old 900px host capture.
      await expect(poster).toHaveJSProperty('naturalWidth', 691);
      await expect(poster).toHaveJSProperty('naturalHeight', 810);
      await expect(page.locator('[data-demo-court]')).toHaveCSS('opacity', '0');
      await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
    } finally {
      release();
    }
  },
);

for (const locale of ['/', '/en/']) {
  for (const height of [900, 1000]) {
    test(`${locale}: ${height}px navigation aligns the visible chapter heading under the actual header`, async ({
      page,
    }) => {
      await page.setViewportSize({ width: 1440, height });
      await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
        route.abort(),
      );
      await page.goto(locale);
      await page.evaluate(() => document.fonts.ready);
      for (const chapter of [
        'experience',
        'replay',
        'download',
        'experience',
      ]) {
        await page.locator(`.site-header a[href="#${chapter}"]`).click();
        await expect(page).toHaveURL(new RegExp(`#${chapter}$`));
        await expect(
          page.locator('.site-header nav a[aria-current="location"]'),
        ).toHaveCount(1);
        await expect(
          page.locator(`.site-header a[href="#${chapter}"]`),
        ).toHaveAttribute('aria-current', 'location');
        await expect
          .poll(async () =>
            page.locator(`#${chapter} .section-top`).evaluate((element) => {
              const header = document
                .querySelector('.site-header')!
                .getBoundingClientRect();
              return Math.abs(
                element.getBoundingClientRect().top - header.bottom - 20,
              );
            }),
          )
          .toBeLessThan(2);
        if (chapter === 'replay') {
          await expect(page.locator('[data-replay-blue]')).toHaveText('8');
          await expect(page.locator('[data-replay-red]')).toHaveText('11');
        }
      }
    });
  }

  test(`${locale}: mobile direct chapters and browser return stay aligned without desktop resources`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    const requested: string[] = [];
    page.on('request', (request) => requested.push(request.url()));
    await page.goto(`${locale}#experience`);
    const headingGap = async (chapter: string) =>
      page
        .locator(`#${chapter} .section-top`)
        .evaluate((element) =>
          Math.abs(
            element.getBoundingClientRect().top -
              document.querySelector('.site-header')!.getBoundingClientRect()
                .bottom -
              20,
          ),
        );
    await expect.poll(() => headingGap('experience')).toBeLessThan(2);
    await page.locator('.site-header a[href="#download"]').click();
    await expect.poll(() => headingGap('download')).toBeLessThan(2);
    await page.goBack();
    await expect(page).toHaveURL(/#experience$/);
    await expect.poll(() => headingGap('experience')).toBeLessThan(2);
    await page.reload();
    await expect.poll(() => headingGap('experience')).toBeLessThan(2);
    expect(
      requested.some((url) =>
        /court-(?:scene|engine)[^/]*\.js$|scene-poster-demo(?:-(?:compact|standard|wide))?\.webp/.test(
          url,
        ),
      ),
    ).toBe(false);
  });

  test(`${locale}: completed replay absorption does not break gallery or subsequent navigation`, async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.goto(locale);
    await page.evaluate(() => document.fonts.ready);
    const stage = page.locator('[data-story-stage="replay"]');
    await expect(stage).toHaveAttribute('data-replay-start', /\d/);
    // ScrollTrigger intentionally suppresses snaps for 500ms after startup.
    // Font readiness and an initially unrendered tween's opacity are not clocks.
    // A reader cannot traverse the entire page within this initialization window.
    await page.waitForTimeout(600);
    await stage.evaluate((element) => {
      const { replayStart, replayEnd } = (element as HTMLElement).dataset;
      const start = Number(replayStart),
        end = Number(replayEnd);
      scrollTo({ top: start + (end - start) * 0.93, behavior: 'instant' });
    });
    await expect
      .poll(async () =>
        Number(await stage.getAttribute('data-replay-progress')),
      )
      .toBeCloseTo(0.93, 2);
    await page.mouse.wheel(0, 10);
    await expect
      .poll(async () =>
        Number(await stage.getAttribute('data-replay-progress')),
      )
      .toBeCloseTo(1, 3);
    // Let the finite snap reach onComplete, which stores its falsey 0 sentinel.
    await page.waitForTimeout(500);
    await page.locator('[data-replay-device="summary"] .viewer-link').click();
    await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
      'naturalWidth',
      1080,
    );
    await page.keyboard.press('Escape');
    await page.locator('.site-header a[href="#experience"]').click();
    await expect
      .poll(() =>
        page
          .locator('#experience .section-top')
          .evaluate((element) =>
            Math.abs(
              element.getBoundingClientRect().top -
                document.querySelector('.site-header')!.getBoundingClientRect()
                  .bottom -
                20,
            ),
          ),
      )
      .toBeLessThan(2);
    expect(errors).toEqual([]);
  });

  test(`${locale}: the navigation indicator follows manual scroll in both directions instead of the URL hash`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.goto(`${locale}#download`);
    await page.evaluate(() => document.fonts.ready);
    const current = page.locator('.site-header nav a[aria-current="location"]');
    await expect(current).toHaveAttribute('href', '#download');
    await expect
      .poll(() =>
        page
          .locator('#download .section-top')
          .evaluate((element) =>
            Math.abs(
              element.getBoundingClientRect().top -
                document.querySelector('.site-header')!.getBoundingClientRect()
                  .bottom -
                20,
            ),
          ),
      )
      .toBeLessThan(2);
    // Programmatic seeks are not manual input. Cancel the initial fragment
    // intent with a real gesture before seeking the sections being inspected.
    await page.mouse.wheel(0, -1);
    for (const chapter of [
      'hero',
      'scoring',
      'experience',
      'replay',
      'download',
      'replay',
      'experience',
      'hero',
    ]) {
      await page.locator(`#${chapter}`).evaluate((element) =>
        scrollTo({
          top: Math.max(0, scrollY + element.getBoundingClientRect().top - 140),
          behavior: 'instant',
        }),
      );
      if (['hero', 'scoring'].includes(chapter))
        await expect(current).toHaveCount(0);
      else {
        await expect(current).toHaveCount(1);
        await expect(current).toHaveAttribute('href', `#${chapter}`);
        await expect
          .poll(() =>
            current.evaluate(
              (element) => getComputedStyle(element, '::after').opacity,
            ),
          )
          .toBe('1');
      }
      await expect(page).toHaveURL(/#download$/);
    }
    await expect(page.locator('.nav-download')).toHaveCSS(
      'border-bottom-width',
      '0px',
    );
    await expect
      .poll(() =>
        page
          .locator('.nav-download')
          .evaluate((element) => getComputedStyle(element, '::after').opacity),
      )
      .toBe('0');
  });
}
