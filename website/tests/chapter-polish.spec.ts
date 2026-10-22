import { expect, test, type CDPSession } from '@playwright/test';

test('scrolling within a chapter does not repeatedly invalidate unchanged page-wide presentation attributes', async ({
  page,
}) => {
  await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
    route.abort(),
  );
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto('/#replay');
  await expect(page.locator('[data-replay-red]')).toHaveText('11');
  const result = await page.evaluate(async () => {
    const root = document.documentElement;
    const stage = document.querySelector<HTMLElement>(
      '[data-story-stage="replay"]',
    )!;
    const start = Number(stage.dataset.storyStart);
    const end = Number(stage.dataset.storyEnd);
    scrollTo({ top: start + (end - start) * 0.4, behavior: 'instant' });
    await new Promise((resolve) => setTimeout(resolve, 500));
    const attributes = [
      'data-chapter',
      'data-court-view',
      'data-interactive',
      'style',
    ];
    let redundant = 0;
    const observer = new MutationObserver((records) => {
      for (const record of records)
        if (
          record.attributeName === 'style' ||
          record.oldValue === root.getAttribute(record.attributeName!)
        )
          redundant++;
    });
    observer.observe(root, {
      attributes: true,
      attributeOldValue: true,
      attributeFilter: attributes,
    });
    for (let step = 0; step < 24; step++) {
      scrollTo({
        top: start + (end - start) * (0.4 + step * 0.006),
        behavior: 'instant',
      });
      await new Promise(requestAnimationFrame);
    }
    await new Promise((resolve) => setTimeout(resolve, 400));
    observer.disconnect();
    return { redundant, chapter: root.dataset.chapter };
  });
  expect(result.chapter).toBe('replay');
  expect(result.redundant).toBe(0);
});

for (const locale of ['/', '/en/']) {
  test(`${locale}: replay reading light follows the card playhead and reverses without residual masking`, async ({
    page,
  }) => {
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(locale);
    await page.evaluate(() => document.fonts.ready);
    await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
    const stage = page.locator('[data-story-stage="replay"]');
    const range = await stage.evaluate((element) => ({
      start: Number((element as HTMLElement).dataset.storyStart),
      end: Number((element as HTMLElement).dataset.storyEnd),
    }));
    const seek = async (progress: number) => {
      const targetProgress = await page.evaluate(
        ({ start, end, progress }) => {
          scrollTo({
            top: start + (end - start) * progress,
            behavior: 'instant',
          });
          return Math.max(0, Math.min(1, (scrollY - start) / (end - start)));
        },
        { ...range, progress },
      );
      // Wait for the scrub to reach the actual pixel-quantized target. A loose
      // phase tolerance reads opposite sides of the easing curve on reversal;
      // the reading light amplifies that transient difference by up to 2.5x.
      await expect
        .poll(async () =>
          Math.abs(
            Number(await stage.getAttribute('data-replay-progress')) -
              targetProgress,
          ),
        )
        .toBeLessThan(0.0001);
      return page
        .locator('.scene-background')
        .evaluate((element) =>
          Number(
            (element as HTMLElement).style.getPropertyValue('--replay-focus'),
          ),
        );
    };
    expect(await seek(0)).toBe(0);
    const middle = await seek(0.48);
    expect(middle).toBeGreaterThan(0.45);
    expect(middle).toBeLessThan(0.55);
    expect(await seek(1)).toBe(1);
    await expect(page.locator('[data-replay-red]')).toHaveText('11');
    await expect
      .poll(() =>
        page
          .locator('.scene-background')
          .evaluate((element) => getComputedStyle(element, '::before').opacity),
      )
      .toBe('1');
    expect(await seek(0.48)).toBeCloseTo(middle, 2);
    expect(await seek(0)).toBe(0);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.locator('.site-header a[href="#replay"]').click();
    await expect
      .poll(() =>
        page
          .locator('.scene-background')
          .evaluate((element) =>
            (element as HTMLElement).style.getPropertyValue('--replay-focus'),
          ),
      )
      .toBe('1.0000');
    await page.locator('.wordmark').click();
    await expect
      .poll(() =>
        page
          .locator('.scene-background')
          .evaluate((element) =>
            (element as HTMLElement).style.getPropertyValue('--replay-focus'),
          ),
      )
      .toBe('0.0000');
  });
}

test(
  'overhead cutaway clears the arena architecture and restores it on reverse travel without moving the camera endpoint',
  { tag: '@webgl' },
  async ({ page, browser }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Actual scene runs in Chromium.',
    );
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.goto('/#experience');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    const canvas = page.locator('#court-canvas');
    await expect(canvas).toHaveAttribute('data-cutaway-prepared', 'true');
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    await expect(canvas).toHaveAttribute('data-view-cutaway', '1.0000');
    if (process.env.CI) {
      const actual = await canvas.evaluate((element) => {
        const canvas = element as HTMLCanvasElement;
        // Read the context already owned by the ready Three.js renderer.
        const gl = canvas.getContext('webgl2')!;
        const debug = gl.getExtension('WEBGL_debug_renderer_info');
        const bounds = canvas.getBoundingClientRect();
        return {
          canvasCount: document.querySelectorAll('canvas').length,
          buffer: { width: canvas.width, height: canvas.height },
          css: {
            x: bounds.x,
            y: bounds.y,
            width: bounds.width,
            height: bounds.height,
          },
          data: { ...canvas.dataset },
          context: {
            version: gl.getParameter(gl.VERSION),
            renderer: gl.getParameter(gl.RENDERER),
            unmaskedRenderer:
              debug && gl.getParameter(debug.UNMASKED_RENDERER_WEBGL),
            attributes: gl.getContextAttributes(),
            lost: gl.isContextLost(),
          },
          viewport: {
            width: innerWidth,
            height: innerHeight,
            layoutWidth: document.documentElement.clientWidth,
            scrollbarWidth: innerWidth - document.documentElement.clientWidth,
            dpr: devicePixelRatio,
          },
          screen: {
            width: screen.width,
            height: screen.height,
            depth: screen.colorDepth,
          },
          hidden: document.hidden,
          visibility: document.visibilityState,
          focus: document.hasFocus(),
        };
      });
      const systemInfo: {
        value?: unknown;
        reason?: string;
        detachReason?: string;
      } = {};
      let session: CDPSession | undefined;
      try {
        session = await browser.newBrowserCDPSession();
        systemInfo.value = await session.send('SystemInfo.getInfo');
      } catch (error) {
        systemInfo.reason = String(error);
      } finally {
        try {
          await session?.detach();
        } catch (error) {
          systemInfo.detachReason = String(error);
        }
      }
      await testInfo.attach('software-webgl-environment', {
        body: JSON.stringify(
          {
            browserVersion: browser.version(),
            display: process.env.DISPLAY ?? null,
            ci: process.env.CI,
            configuredHeadless: testInfo.project.use.headless ?? null,
            configuredLaunchArguments:
              testInfo.project.use.launchOptions?.args ?? [],
            actual,
            systemInfo,
            note: 'Environment metadata only; software rendering is not display FPS evidence.',
          },
          null,
          2,
        ),
        contentType: 'application/json',
      });
    }
    await canvas.evaluate((element) =>
      Reflect.set(
        window,
        '__polishContext',
        (element as HTMLCanvasElement).getContext('webgl2'),
      ),
    );
    await page.locator('[data-point-preset="center"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await page.locator('[data-reset]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await page
      .locator('.hero-actions a[href="#scoring"]')
      .evaluate((element) => (element as HTMLAnchorElement).click());
    await expect(page.locator('html')).toHaveAttribute(
      'data-chapter',
      'scoring',
    );
    await expect(canvas).toHaveAttribute('data-view-cutaway', '0.0000');
    await page.locator('.site-header a[href="#experience"]').click();
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    await expect(canvas).toHaveAttribute('data-view-cutaway', '1.0000');
    expect(
      await canvas.evaluate(
        (element) =>
          (element as HTMLCanvasElement).getContext('webgl2') ===
          Reflect.get(window, '__polishContext'),
      ),
    ).toBe(true);
    await expect(page.locator('.scene-background > #court-canvas')).toHaveCount(
      1,
    );
  },
);
