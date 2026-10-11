import { expect, test, type Page } from '@playwright/test';

const apk =
  'https://github.com/x1a0Y4NGren/hooptrace/releases/download/v2.0.0/HoopTrace-v2.0.0-android.apk';
const origin = 'http://127.0.0.1:4321';
const locales = [
  {
    path: '/',
    lang: 'zh-CN',
    title: '每一球，都有迹可循。',
    other: '/en/',
    privacy: '/privacy/',
  },
  {
    path: '/en/',
    lang: 'en',
    title: 'Every play leaves a trace.',
    other: '/',
    privacy: '/en/privacy/',
  },
] as const;
const threeChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;

async function expectDownload(page: Page) {
  await expect(page.locator('[data-download]').first()).toBeVisible();
  for (const link of await page.locator('[data-download]').all()) {
    await expect(link).toHaveAttribute('href', apk);
  }
}

async function expectNoOverflow(page: Page) {
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth - window.innerWidth,
    ),
  ).toBeLessThanOrEqual(1);
}

async function expectReset(page: Page) {
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(page.locator('[data-red-score]')).toHaveText('6');
  await expect(page.locator('[data-record]')).toBeDisabled();
  await expect(page.locator('[data-demo-marker]')).not.toBeVisible();
  await expect(
    page.locator('[data-point-preset][aria-pressed="true"]'),
  ).toHaveCount(0);
}

async function allowSoftwareWebGL(page: Page) {
  // CI's SwiftShader is real WebGL2, but intentionally fails the site's conservative hardware probe.
  // Relax only that browser boundary in renderer lifecycle tests; the real Three.js/shaders still run.
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

for (const locale of locales) {
  test(`${locale.lang}: localized content, downloads and privacy are available`, async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    const failures: string[] = [];
    page.on('pageerror', (error) => failures.push(error.message));
    const response = await page.goto(locale.path);
    expect(response?.ok()).toBe(true);
    await expect(page.locator('html')).toHaveAttribute('lang', locale.lang);
    await expect(page.locator('h1')).toHaveText(locale.title);
    await expectDownload(page);
    for (const id of ['hero', 'scoring', 'experience', 'replay', 'download']) {
      await expect(page.locator(`main #${id}`)).toHaveCount(1);
    }
    expect(
      (
        await page.locator('meta[name="description"]').getAttribute('content')
      )?.trim().length,
    ).toBeGreaterThan(30);
    await expect(page.locator('meta[name="robots"]')).toHaveAttribute(
      'content',
      /noindex/,
    );
    const robots = await page.request.get('/robots.txt');
    expect(robots.ok()).toBe(true);
    expect(await robots.text()).toMatch(/Disallow:\s*\//);
    const sitemap = await page.request.get('/sitemap.xml');
    expect(sitemap.ok()).toBe(true);
    const sitemapState = await page.evaluate(
      (xml) => {
        const parsed = new DOMParser().parseFromString(xml, 'application/xml');
        return {
          errors: parsed.querySelectorAll('parsererror').length,
          urls: parsed.getElementsByTagName('url').length,
          namespace: parsed.documentElement.namespaceURI,
        };
      },
      await sitemap.text(),
    );
    expect(sitemapState).toEqual({
      errors: 0,
      urls: 0,
      namespace: 'http://www.sitemaps.org/schemas/sitemap/0.9',
    });
    await expect(
      page.locator('link[rel="alternate"][hreflang="zh-CN"]'),
    ).toHaveCount(1);
    await expect(
      page.locator('link[rel="alternate"][hreflang="en"]'),
    ).toHaveCount(1);
    expect(
      await page
        .locator('img')
        .evaluateAll((images) =>
          images.every((image) => image.hasAttribute('alt')),
        ),
    ).toBe(true);
    await page.goto(locale.privacy);
    await expect(page.locator('html')).toHaveAttribute('lang', locale.lang);
    await expect(page.locator('main')).toContainText(/Vercel/);
    expect(failures).toEqual([]);
  });

  test(`${locale.lang}: language switch preserves the current chapter`, async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(`${locale.path}#replay`);
    await page.locator('[data-language]').click();
    await expect(page).toHaveURL(`${origin}${locale.other}#replay`);
  });

  test(`${locale.lang}: a recorded shot scores once and creates one location`, async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(`${locale.path}#experience`);
    await expectReset(page);
    const preset = page.locator('[data-point-preset="left"]');
    await preset.focus();
    await page.keyboard.press('Enter');
    await expect(preset).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('[data-record]')).toBeEnabled();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-red-score]')).toHaveText('6');
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
    await expect(page.locator('[data-record]')).toBeDisabled();
    await page
      .locator('[data-record]')
      .evaluate((button: HTMLButtonElement) => {
        button.dispatchEvent(new MouseEvent('click', { bubbles: true }));
      });
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-demo-status]')).toHaveAttribute(
      'aria-live',
      'polite',
    );
    await expect(page.locator('[data-demo-status]')).not.toBeEmpty();
    await page.locator('[data-reset]').click();
    await expectReset(page);
  });

  test(`${locale.lang}: the two-dimensional court supports a pointer-selected location`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(`${locale.path}#experience`);
    await page
      .locator('[data-demo-court]')
      .click({ position: { x: 80, y: 100 } });
    await expect(page.locator('[data-record]')).toBeEnabled();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
  });

  test(`${locale.lang}: resetting during a shot cancels its stale completion`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await page.goto(`${locale.path}#experience`);
    await page.locator('[data-point-preset="center"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await page.locator('[data-reset]').click();
    await expectReset(page);
    // Wait past the real flight duration; no timer from the old generation may commit a marker.
    await page.waitForTimeout(1800);
    await expectReset(page);
  });

  test(`${locale.lang}: download and product information survive disabled JavaScript`, async ({
    browser,
  }) => {
    const context = await browser.newContext({
      javaScriptEnabled: false,
      viewport: { width: 390, height: 844 },
    });
    const page = await context.newPage();
    await page.goto(`${origin}${locale.path}`);
    await expect(page.locator('h1')).toHaveText(locale.title);
    await expectDownload(page);
    await expect(page.locator('#download')).toContainText('2.0.0');
    await expect(page.locator('#download')).toContainText('JSON');
    await expect(page.locator('[data-record]')).toBeDisabled();
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
    await context.close();
  });

  for (const width of [360, 390, 768, 1440, 1920]) {
    test(`${locale.lang}: ${width}px layout remains readable without horizontal overflow`, async ({
      page,
    }, testInfo) => {
      await page.setViewportSize({ width, height: width < 1024 ? 844 : 1000 });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      const requested: string[] = [];
      page.on('request', (request) => requested.push(request.url()));
      await page.goto(locale.path);
      await expectDownload(page);
      await expectNoOverflow(page);
      if (width < 1024)
        expect(requested.some((url) => threeChunk.test(url))).toBe(false);
      await page.locator('#experience').scrollIntoViewIfNeeded();
      for (const selector of [
        '[data-point-preset]',
        '[data-record]',
        '[data-reset]',
      ]) {
        for (const control of await page.locator(selector).all()) {
          const box = await control.boundingBox();
          expect(box?.height).toBeGreaterThanOrEqual(48);
          expect(box?.width).toBeGreaterThanOrEqual(48);
        }
      }
      if ([390, 1440].includes(width) && testInfo.project.name === 'chromium') {
        for (const id of ['scoring', 'experience', 'replay', 'download'])
          await page.locator(`#${id}`).scrollIntoViewIfNeeded();
        await page.waitForFunction(() =>
          [...document.images].every(
            (image) =>
              !image.getClientRects().length ||
              (image.complete && image.naturalWidth > 0),
          ),
        );
        await page.locator('#hero').scrollIntoViewIfNeeded();
        await page.screenshot({
          path: testInfo.outputPath(`${locale.lang}-${width}-reduced.png`),
          fullPage: true,
        });
      }
    });
  }
}

test('mobile loads only local resources and never imports the 3D renderer', async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  const requested: string[] = [];
  page.on('request', (request) => requested.push(request.url()));
  await page.goto('/');
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
  await page.locator('#download').scrollIntoViewIfNeeded();
  await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  expect(requested.some((url) => threeChunk.test(url))).toBe(false);
  expect(
    requested
      .filter((url) => /^https?:/.test(url))
      .every((url) => new URL(url).origin === origin),
  ).toBe(true);
  if (testInfo.project.name === 'chromium') {
    await page.screenshot({
      path: testInfo.outputPath('zh-CN-390-full-2d-download.png'),
    });
  }
});

test(
  'system reduced motion and the user toggle retain a working two-dimensional demo',
  { lock: 'webgl-renderer' },
  async ({ page }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    const requested: string[] = [];
    page.on('request', (request) => requested.push(request.url()));
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute(
      'data-motion',
      'reduced',
    );
    await expect(page.locator('[data-motion-toggle]')).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
    expect(requested.some((url) => threeChunk.test(url))).toBe(false);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await expect(page.locator('html')).toHaveAttribute('data-motion', 'full');
    await page.locator('[data-motion-toggle]').click();
    await expect(page.locator('html')).toHaveAttribute(
      'data-motion',
      'reduced',
    );
    await page.locator('[data-motion-toggle]').click();
    await expect(page.locator('html')).toHaveAttribute('data-motion', 'full');
    await page.locator('[data-motion-toggle]').click();
    await expect(page.locator('html')).toHaveAttribute(
      'data-motion',
      'reduced',
    );
    await page.locator('#experience').scrollIntoViewIfNeeded();
    await page.locator('[data-point-preset="right"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
    await expectDownload(page);
  },
);

for (const locale of locales) {
  test(`${locale.lang}: 200 percent text remains usable on a narrow viewport`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(locale.path);
    await page.evaluate(() => {
      // Capture sizes before mutation so inherited sizes are doubled once, including px/clamp typography.
      const textElements = [
        ...document.querySelectorAll<HTMLElement>('body *'),
      ].filter((element) =>
        [...element.childNodes].some(
          (node) =>
            node.nodeType === Node.TEXT_NODE && node.textContent?.trim(),
        ),
      );
      const sizes = textElements.map(
        (element) =>
          [
            element,
            Number.parseFloat(getComputedStyle(element).fontSize),
          ] as const,
      );
      for (const [element, size] of sizes)
        element.style.fontSize = `${size * 2}px`;
    });
    await expectNoOverflow(page);
    await expectDownload(page);
    await page.locator('#experience').scrollIntoViewIfNeeded();
    await page.locator('[data-point-preset="center"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    if (testInfo.project.name === 'chromium') {
      await page.screenshot({
        path: testInfo.outputPath(`${locale.lang}-390-text-200-percent.png`),
      });
    }
  });
}

test('missing WebGL2 keeps the static introduction and interactive demo', async ({
  page,
}) => {
  await page.addInitScript(() => {
    const original = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (
      this: HTMLCanvasElement,
      type: string,
      ...args: unknown[]
    ) {
      if (type === 'webgl2') return null;
      return Reflect.apply(original, this, [type, ...args]);
    } as typeof original;
  });
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  await expectDownload(page);
  await page.locator('#experience').scrollIntoViewIfNeeded();
  await page.locator('[data-point-preset="center"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-demo-marker]')).toBeVisible();
});

test('a failed 3D module never hides the download or blocks the demo', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium',
    'The deterministic WebGL fault scenarios run in Chromium.',
  );
  await allowSoftwareWebGL(page);
  await page.route(threeChunk, (route) => route.abort('failed'));
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  await expectDownload(page);
  await page.locator('#experience').scrollIntoViewIfNeeded();
  await page.locator('[data-point-preset="left"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
});

test('slow 3D initialization gives up after eight seconds and does not activate late', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium',
    'The deterministic WebGL fault scenarios run in Chromium.',
  );
  await allowSoftwareWebGL(page);
  let blocked = false;
  let release: () => void = () => {};
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.route(threeChunk, async (route) => {
    blocked = true;
    await gate;
    await route.continue().catch(() => {});
  });
  try {
    await page.goto('/', { waitUntil: 'domcontentloaded' });
    await expect.poll(() => blocked).toBe(true);
    await expectDownload(page);
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d', {
      timeout: 11_000,
    });
    release();
    await page.waitForLoadState('networkidle');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  } finally {
    release();
  }
});

test(
  'a desktop scene cleans up on context loss and remains usable after resizing',
  { lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The deterministic WebGL fault scenarios run in Chromium.',
    );
    await allowSoftwareWebGL(page);
    const shaderErrors: string[] = [];
    page.on('console', (message) => {
      if (
        message.type() === 'error' &&
        /shader|WebGLProgram|VALIDATE_STATUS|GL_INVALID/i.test(message.text())
      )
        shaderErrors.push(message.text());
    });
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-scene-ready',
      'true',
    );
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-renderer',
      /\S+/,
    );
    expect(shaderErrors).toEqual([]);
    await page.screenshot({
      path: testInfo.outputPath('zh-CN-1440-full-3d.png'),
    });
    await page
      .locator('#court-canvas')
      .evaluate((canvas: HTMLCanvasElement) => {
        canvas.dispatchEvent(
          new Event('webglcontextlost', { cancelable: true }),
        );
      });
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
    await expectDownload(page);
    await page.setViewportSize({ width: 390, height: 844 });
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
    await page.locator('#experience').scrollIntoViewIfNeeded();
    await page.locator('[data-point-preset="center"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
  },
);

test(
  'a shot recorded while 3D loads survives scene initialization and motion fallback',
  { lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The desktop renderer lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    let blocked = false;
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    await page.route(threeChunk, async (route) => {
      blocked = true;
      await gate;
      await route.continue().catch(() => {});
    });
    try {
      await page.goto('/#experience', { waitUntil: 'domcontentloaded' });
      await expect.poll(() => blocked).toBe(true);
      await page.locator('[data-point-preset="left"]').click();
      await page.locator('[data-record]').click();
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await expect(page.locator('[data-demo-marker]')).toBeVisible();
      release();
      await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await expect(page.locator('[data-record]')).toBeDisabled();
      await page.screenshot({
        path: testInfo.outputPath('zh-CN-1440-startup-completed-shot-3d.png'),
      });
      await page.locator('[data-motion-toggle]').click();
      await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
      await expect(page.locator('[data-demo-marker]')).toBeVisible();
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
    } finally {
      release();
    }
  },
);

test(
  'resetting a desktop shot clears its score and its animated location',
  { lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The desktop renderer lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.goto('/#experience');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await page
      .locator('#experience')
      .evaluate((section) =>
        section.scrollIntoView({ behavior: 'instant', block: 'start' }),
      );
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    // This visible court point is on the canvas, away from the DOM scoring controls.
    await page.mouse.click(1030, 520);
    await expect(page.locator('[data-record]')).toBeEnabled();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await page.locator('[data-reset]').click();
    await expectReset(page);
    await page.waitForTimeout(1800);
    await expectReset(page);
  },
);

test(
  'a desktop scene is removed when the layout becomes mobile',
  { lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The desktop renderer lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    await page.goto('/en/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await page.locator('#experience').scrollIntoViewIfNeeded();
    await page.screenshot({
      path: testInfo.outputPath('en-1440-full-3d-experience.png'),
    });
    await page.setViewportSize({ width: 390, height: 844 });
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
    await page.setViewportSize({ width: 1440, height: 900 });
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await expectDownload(page);
  },
);

test(
  'a hidden desktop page stops rendering and resumes when visible',
  { lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The desktop renderer lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    // Count real GPU draw submissions at the browser boundary; production code has no test hooks.
    await page.addInitScript(() => {
      const state = window as unknown as { hooptraceDrawCalls: number };
      state.hooptraceDrawCalls = 0;
      for (const method of ['drawElements', 'drawArrays'] as const) {
        const original = WebGL2RenderingContext.prototype[method];
        const wrapped = function (
          this: WebGL2RenderingContext,
          ...args: unknown[]
        ) {
          state.hooptraceDrawCalls += 1;
          return Reflect.apply(original, this, args);
        };
        Reflect.set(WebGL2RenderingContext.prototype, method, wrapped);
      }
    });
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    const count = () =>
      page.evaluate(
        () =>
          (window as unknown as { hooptraceDrawCalls: number })
            .hooptraceDrawCalls,
      );
    await expect.poll(count).toBeGreaterThan(0);
    await page.evaluate(() => {
      Object.defineProperty(document, 'hidden', {
        configurable: true,
        value: true,
      });
      Object.defineProperty(document, 'visibilityState', {
        configurable: true,
        value: 'hidden',
      });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    const paused = await count();
    await page.waitForTimeout(250);
    expect(await count()).toBe(paused);
    await page.evaluate(() => {
      Object.defineProperty(document, 'hidden', {
        configurable: true,
        value: false,
      });
      Object.defineProperty(document, 'visibilityState', {
        configurable: true,
        value: 'visible',
      });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await expect.poll(count).toBeGreaterThan(paused);
  },
);
