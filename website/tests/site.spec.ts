import { expect, test as base, type Page } from '@playwright/test';
import { storyPose } from '../src/scripts/story-pose';
import type { StoryFrame } from '../src/scripts/scene-contract';

const test = base.extend({
  page: async ({ page }, use, testInfo) => {
    // Shared CI hosts render WebGL in software. Ordinary layout tests need HTML,
    // SVG and GSAP, while the separately tagged lifecycle suite keeps real WebGL.
    if (process.env.CI && !testInfo.tags.includes('@webgl')) {
      await page.addInitScript(() => {
        const original = HTMLCanvasElement.prototype.getContext;
        HTMLCanvasElement.prototype.getContext = function (
          this: HTMLCanvasElement,
          type: string,
          ...args: unknown[]
        ) {
          return type === 'webgl2'
            ? null
            : Reflect.apply(original, this, [type, ...args]);
        } as typeof original;
      });
    }
    await use(page);
  },
});

const apk =
  'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.0.1/Hoopito-v2.0.1-android.apk';
const origin = 'http://127.0.0.1:4321';
const locales = [
  {
    path: '/',
    lang: 'zh-CN',
    brand: '球豆',
    title: '每一球，都有迹可循。',
    other: '/en/',
    privacy: '/privacy/',
  },
  {
    path: '/en/',
    lang: 'en',
    brand: 'Hoopito',
    title: 'Every play leaves a trace.',
    other: '/',
    privacy: '/en/privacy/',
  },
] as const;
const threeChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;

test(
  'large desktop text emits continuous camera poses across unpinned chapter boundaries',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Scene frames are verified against Chromium WebGL.',
    );
    await allowSoftwareWebGL(page);
    await page.setViewportSize({ width: 1440, height: 901 });
    await page.goto('/en/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await page.addStyleTag({
      content: 'html {scroll-behavior:auto !important}',
    });
    await page.evaluate(() => document.fonts.ready);
    await page.evaluate(() => {
      const items = [
        ...document.querySelectorAll<HTMLElement>('body *'),
      ].filter((e) =>
        [...e.childNodes].some(
          (n) => n.nodeType === Node.TEXT_NODE && n.textContent?.trim(),
        ),
      );
      const sizes = items.map(
        (e) => [e, parseFloat(getComputedStyle(e).fontSize)] as const,
      );
      for (const [element, size] of sizes)
        element.style.fontSize = `${size * 2}px`;
      dispatchEvent(new Event('resize'));
    });
    await expect(page.locator('.pin-spacer')).toHaveCount(0);
    for (const chapter of ['scoring', 'experience', 'replay']) {
      const cut = await page
        .locator(`#${chapter}`)
        .evaluate(
          (e) =>
            e.getBoundingClientRect().top +
            scrollY -
            Math.min(innerHeight * 0.3, 260),
        );
      for (const direction of [1, -1]) {
        const samples: StoryFrame[] = [];
        for (const offset of [-2 * direction, 2 * direction]) {
          await page.evaluate((y) => window.scrollTo(0, y), cut + offset);
          const previous = {
            scoring: 'hero',
            experience: 'scoring',
            replay: 'experience',
          };
          const expectedChapter =
            offset < 0 ? previous[chapter as keyof typeof previous] : chapter;
          // Software rendering can delay the scroll RAF beyond a fixed sleep.
          // Wait for the actual chapter boundary, while still requiring the
          // shared endpoint pose rather than accepting a stale camera sample.
          await expect(page.locator('#court-canvas')).toHaveAttribute(
            'data-chapter',
            expectedChapter,
          );
          await expect
            .poll(async () =>
              Number(
                await page
                  .locator('#court-canvas')
                  .getAttribute('data-story-progress'),
              ),
            )
            [offset < 0 ? 'toBeGreaterThan' : 'toBeLessThan'](
              offset < 0 ? 0.99 : 0.01,
            );
          samples.push(
            (await page.locator('#court-canvas').evaluate((e) => ({
              chapter: (e as HTMLElement).dataset.chapter,
              progress: Number((e as HTMLElement).dataset.storyProgress),
              active: true,
            }))) as StoryFrame,
          );
        }
        const from = storyPose(samples[0]),
          to = storyPose(samples[1]);
        const delta = Math.hypot(
          ...from.position.map((v, i) => v - to.position[i]),
        );
        expect(
          delta,
          `${chapter} ${direction}: ${JSON.stringify(samples)}`,
        ).toBeLessThan(0.08);
      }
    }
  },
);

for (const locale of locales) {
  for (const dpr of [1, 2]) {
    test(`${locale.lang}: ${dpr}x density and orientation changes retain one shot and complete readable chapters`, async ({
      browser,
    }) => {
      const context = await browser.newContext({
        viewport: { width: 390, height: 844 },
        deviceScaleFactor: dpr,
        hasTouch: true,
      });
      try {
        const page = await context.newPage();
        await page.addInitScript(() => {
          const original = HTMLCanvasElement.prototype.getContext;
          HTMLCanvasElement.prototype.getContext = function (
            this: HTMLCanvasElement,
            type: string,
            ...args: unknown[]
          ) {
            return type === 'webgl2'
              ? null
              : Reflect.apply(original, this, [type, ...args]);
          } as typeof original;
        });
        await page.goto(locale.path);
        await page.locator('[data-point-preset="center"]').click();
        await page.locator('[data-record]').click();
        await page.setViewportSize({ width: 844, height: 390 });
        await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
          'hidden',
        );
        for (const [width, height] of [
          [360, 800],
          [390, 844],
          [768, 1024],
          [1440, 900],
          [1920, 1080],
        ]) {
          await page.setViewportSize({ width, height });
          await expectNoOverflow(page);
          await expect(page.locator('[data-blue-score]')).toHaveText('8');
          for (const id of ['scoring', 'replay', 'download']) {
            await page.locator(`#${id}`).scrollIntoViewIfNeeded();
            await expect(page.locator(`#${id} h2`)).toBeVisible();
          }
        }
        await page.setViewportSize({ width: 390, height: 844 });
        await page.locator('[data-reset]').click();
        await expect(page.locator('[data-blue-score]')).toHaveText('6');
        await expect(page.locator('.pin-spacer')).toHaveCount(0);
      } finally {
        await context.close();
      }
    });
  }
}

test('native stage distances and reverse jumps leave replay upright and downloading usable', async ({
  page,
}) => {
  await page.goto('/');
  await expect(page.locator('.pin-spacer')).toHaveCount(3);
  await page.addStyleTag({ content: 'html {scroll-behavior:auto !important}' });
  for (const [chapter, extra] of [
    ['hero', 0.75],
    ['scoring', 1],
    ['replay', 0.75],
  ] as const) {
    const range = await page
      .locator(`[data-story-stage="${chapter}"]`)
      .evaluate((e) => ({
        start: Number((e as HTMLElement).dataset.storyStart),
        end: Number((e as HTMLElement).dataset.storyEnd),
        height: innerHeight,
      }));
    expect(range.end - range.start).toBeCloseTo(range.height * extra, 0);
  }
  const stage = page.locator('[data-story-stage="replay"]');
  for (const progress of [1, 0.05, 0.9, 0.2, 1]) {
    await stage.evaluate(
      (e, p) =>
        window.scrollTo(
          0,
          Number((e as HTMLElement).dataset.storyStart) +
            (Number((e as HTMLElement).dataset.storyEnd) -
              Number((e as HTMLElement).dataset.storyStart)) *
              p,
        ),
      progress,
    );
    await expect
      .poll(async () => Number(await stage.getAttribute('data-story-progress')))
      .toBeCloseTo(progress, 2);
  }
  for (const device of await page.locator('[data-replay-device]').all()) {
    const rotation = await device.evaluate((e) => {
      const m = new DOMMatrix(getComputedStyle(e).transform);
      return Math.abs(m.b) + Math.abs(m.m13) + Math.abs(m.m23);
    });
    expect(rotation).toBeLessThan(0.001);
    await expect(device.locator('.viewer-link')).toBeInViewport();
  }
  await page.locator('.nav-download').click();
  await expect(page.locator('#download .button')).toBeInViewport();
});

for (const phase of [
  { name: 'flight', delay: 450 },
  { name: 'swish', delay: 1280 },
  { name: 'rebound', delay: 1700 },
]) {
  test(`reset during ${phase.name} cancels every visual and stale completion`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto('/');
    const resting = await page.locator('[data-net-weave]').getAttribute('d');
    await page.locator('[data-point-preset="left"]').click();
    await page.locator('[data-record]').click();
    await page.waitForTimeout(phase.delay);
    await page.evaluate(() =>
      document.querySelector<HTMLButtonElement>('[data-reset]')!.click(),
    );
    await page.waitForTimeout(2300 - phase.delay);
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
      'hidden',
      '',
    );
    await expect(page.locator('[data-demo-ball]')).toHaveAttribute(
      'hidden',
      '',
    );
    await expect(page.locator('[data-demo-trail]')).toHaveAttribute(
      'hidden',
      '',
    );
    await expect(page.locator('[data-net-weave]')).toHaveAttribute(
      'd',
      resting!,
    );
    await page.locator('[data-point-preset="right"]').focus();
    await page.keyboard.press('Enter');
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
      'hidden',
    );
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
  });
}

test('touch gallery pinches and pans within bounds then returns focus', async ({
  page,
  browserName,
}) => {
  test.skip(
    browserName !== 'chromium',
    'Native multi-touch injection uses Chromium CDP; shared viewer buttons are tested in all engines.',
  );
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/#replay');
  const link = page.locator('[data-replay-device="summary"] .viewer-link');
  await link.click();
  await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
  const bounds = await page.locator('[data-viewer-viewport]').boundingBox();
  const client = await page.context().newCDPSession(page);
  const y = bounds!.y + bounds!.height / 2;
  await client.send('Input.dispatchTouchEvent', {
    type: 'touchStart',
    touchPoints: [
      { x: 165, y, id: 1 },
      { x: 225, y, id: 2 },
    ],
  });
  await client.send('Input.dispatchTouchEvent', {
    type: 'touchMove',
    touchPoints: [
      { x: 90, y, id: 1 },
      { x: 300, y, id: 2 },
    ],
  });
  await client.send('Input.dispatchTouchEvent', {
    type: 'touchEnd',
    touchPoints: [],
  });
  await expect
    .poll(async () =>
      parseInt((await page.locator('[data-viewer-scale]').textContent())!),
    )
    .toBeGreaterThan(200);
  const image = page.locator('[data-viewer-image]');
  const before = await image.boundingBox();
  await page.mouse.move(195, y);
  await page.mouse.down();
  await page.mouse.move(340, y + 100, { steps: 10 });
  await page.mouse.up();
  const after = await image.boundingBox();
  expect(after!.x).toBeGreaterThan(before!.x);
  expect(after!.x).toBeLessThanOrEqual(bounds!.x);
  expect(after!.x + after!.width).toBeGreaterThanOrEqual(
    bounds!.x + bounds!.width,
  );
  await page.locator('[data-viewer-close]').click();
  await expect(link).toBeFocused();
});

for (const locale of locales) {
  test(`${locale.lang}: mobile replay reads introduction, result, insight, then history with distinct examples`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(`${locale.path}#replay`);
    const sequence = [
      '.replay-introduction',
      '[data-replay-device="summary"]',
      '.replay-insight',
      '[data-replay-device="history"]',
    ];
    let bottom = 0;
    for (const selector of sequence) {
      const box = await page.locator(selector).boundingBox();
      expect(box).not.toBeNull();
      expect(box!.y).toBeGreaterThanOrEqual(bottom - 1);
      bottom = box!.y + box!.height;
    }
    await expect(
      page.locator('[data-replay-device="summary"] figcaption'),
    ).toContainText('8:11');
    await expect(page.locator('.replay-example-note')).toContainText(
      '6:6 → 8:6',
    );
    for (const type of ['summary', 'history']) {
      const link = page.locator(`[data-replay-device="${type}"] .viewer-link`);
      await link.click();
      await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
        'naturalHeight',
        1783,
      );
      await page.keyboard.press('Escape');
      await expect(link).toBeFocused();
    }
  });
}

test('hidden-page and gallery suspension freeze a shot until all reasons are released', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.locator('[data-point-preset="center"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    document.dispatchEvent(new Event('visibilitychange'));
    document.querySelector<HTMLAnchorElement>('#scoring .viewer-link')!.click();
  });
  await page.waitForTimeout(1800);
  await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
    'hidden',
    '',
  );
  await page.locator('[data-viewer-close]').click();
  await page.waitForTimeout(400);
  await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
    'hidden',
    '',
  );
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
    'hidden',
  );
  await page.locator('[data-reset]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
    'hidden',
    '',
  );
});

test('net rebound continues after a recorded marker and reset restores its anchored rest pose', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  const weave = page.locator('[data-net-weave]');
  const resting = await weave.getAttribute('d');
  await page.locator('[data-point-preset="center"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
    'hidden',
  );
  await expect(weave).not.toHaveAttribute('d', resting!);
  await page.locator('[data-reset]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(weave).toHaveAttribute('d', resting!);
  await page.waitForTimeout(700);
  await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
    'hidden',
    '',
  );
  await expect(page.locator('[data-demo-ball]')).toHaveAttribute('hidden', '');
});

for (const locale of locales) {
  test(`${locale.lang}: gallery uses clean images, bounds zoom and restores focus and position`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(locale.path);
    const link = page.locator('#scoring .viewer-link');
    await link.scrollIntoViewIfNeeded();
    await expect(link).toHaveAttribute(
      'href',
      /\/screenshots\/(zh|en)\/scoring\.webp$/,
    );
    const y = await page.evaluate(() => scrollY);
    await link.click();
    await expect(page.locator('[data-viewer]')).toBeVisible();
    await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
      'naturalWidth',
      1818,
    );
    for (let i = 0; i < 6; i++) await page.locator('[data-viewer-in]').click();
    await expect(page.locator('[data-viewer-scale]')).toHaveText('400%');
    await expect(page.locator('[data-viewer-in]')).toBeDisabled();
    await page.locator('[data-viewer-fit]').click();
    await expect(page.locator('[data-viewer-scale]')).toHaveText('100%');
    await page.keyboard.press('Escape');
    await expect(page.locator('[data-viewer]')).not.toBeVisible();
    await expect(link).toBeFocused();
    expect(Math.abs((await page.evaluate(() => scrollY)) - y)).toBeLessThan(3);
    await page.locator('[data-score-feature="1"]').click();
    await expect(page.locator('[data-story-device]')).toHaveAttribute(
      'data-score-focus',
      '1',
    );
  });
}

test('scoring feature emphasis follows scroll and retains manual focus only until chapter exit', async ({
  page,
}) => {
  await page.goto('/');
  await expect(page.locator('[data-score-feature="0"]')).toBeEnabled();
  await page.addStyleTag({ content: 'html {scroll-behavior:auto !important}' });
  const seek = async (progress: number) => {
    await page.evaluate((progress) => {
      const stage = document.querySelector<HTMLElement>(
        '[data-story-stage="scoring"]',
      )!;
      window.scrollTo(
        0,
        Number(stage.dataset.storyStart) +
          (Number(stage.dataset.storyEnd) - Number(stage.dataset.storyStart)) *
            progress,
      );
    }, progress);
  };
  await seek(0.3);
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-focus',
    '0',
  );
  await page.locator('[data-score-feature="2"]').click();
  await seek(0.5);
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-focus',
    '2',
  );
  await page.locator('#download').scrollIntoViewIfNeeded();
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-focus',
    'none',
  );
  await seek(0.5);
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-focus',
    '1',
  );
});

for (const locale of locales) {
  test(`${locale.lang}: presentation screenshots preserve app-only dimensions and display proportions`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(locale.path);
    for (const [selector, width, height] of [
      ['[data-story-device] img', 1818, 954],
      ['[data-replay-device="summary"] img', 1080, 1783],
      ['[data-replay-device="history"] img', 1080, 1783],
    ] as const) {
      const screenshot = page.locator(selector);
      await screenshot.scrollIntoViewIfNeeded();
      await expect(screenshot).toHaveJSProperty('naturalWidth', width);
      await expect(screenshot).toHaveJSProperty('naturalHeight', height);
      await expect(screenshot).toHaveAttribute('width', String(width));
      await expect(screenshot).toHaveAttribute('height', String(height));
      const box = await screenshot.boundingBox();
      expect(box).not.toBeNull();
      expect(box!.width / box!.height).toBeCloseTo(width / height, 2);
    }
  });
}

test('cinematic stages unpin cleanly when the viewport or system motion changes', async ({
  page,
}) => {
  await page.addInitScript(() => {
    const original = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (
      this: HTMLCanvasElement,
      type: string,
      ...args: unknown[]
    ) {
      return type === 'webgl2'
        ? null
        : Reflect.apply(original, this, [type, ...args]);
    } as typeof original;
  });
  await page.goto('/');
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
  await expect(page.locator('.pin-spacer')).toHaveCount(3);
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
  await expectNoOverflow(page);
  await page.setViewportSize({ width: 1440, height: 900 });
  await expect(page.locator('.pin-spacer')).toHaveCount(3);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
  await expect(page.locator('h1')).toBeVisible();
  await expectDownload(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expect(page.locator('.pin-spacer')).toHaveCount(3);
  await page.locator('.nav-download').click();
  await expect(page).toHaveURL(/#download$/);
  await expect(page.locator('.download-package')).toBeInViewport();
});

test('rapid system motion changes restore cinematic stages even within one clock tick', async ({
  page,
}) => {
  await page.addInitScript(() => {
    const original = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (
      this: HTMLCanvasElement,
      type: string,
      ...args: unknown[]
    ) {
      return type === 'webgl2'
        ? null
        : Reflect.apply(original, this, [type, ...args]);
    } as typeof original;
  });
  const errors: string[] = [];
  page.on('pageerror', (error) => errors.push(error.message));
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('.pin-spacer')).toHaveCount(3);

  // Coarse browser clocks can give successive media events the same timestamp.
  // Keep real RAF/timers running; only make GSAP's media-event clock coincide.
  await page.evaluate(() => {
    const original = Date.now;
    const tick = original() + 10;
    Date.now = () => tick;
    Object.assign(window, {
      restoreMotionClock: () => {
        Date.now = original;
      },
    });
  });
  try {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect(page.locator('.pin-spacer')).toHaveCount(0);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
  } finally {
    await page.evaluate(() => {
      (
        window as typeof window & { restoreMotionClock: () => void }
      ).restoreMotionClock();
    });
  }
  await page.evaluate(
    () =>
      new Promise<void>((resolve) => requestAnimationFrame(() => resolve())),
  );
  await expect(page.locator('.pin-spacer')).toHaveCount(3, { timeout: 5_000 });
  await expect(page.locator('[data-hero-line]').first()).toHaveCSS(
    'opacity',
    '1',
  );
  await page.locator('.nav-download').click();
  await expect(page.locator('.download-package')).toBeInViewport();
  expect(errors).toEqual([]);
});

test('a pending desktop resize keeps native download navigation on target', async ({
  page,
}) => {
  await page.addInitScript(() => {
    const original = HTMLCanvasElement.prototype.getContext;
    HTMLCanvasElement.prototype.getContext = function (
      this: HTMLCanvasElement,
      type: string,
      ...args: unknown[]
    ) {
      return type === 'webgl2'
        ? null
        : Reflect.apply(original, this, [type, ...args]);
    } as typeof original;
  });
  await page.goto('/');
  await page.waitForLoadState('networkidle');
  await expect(page.locator('.pin-spacer')).toHaveCount(3);
  await page.evaluate(() => {
    window.addEventListener(
      'resize',
      () => {
        // Start before the queued 200ms refresh and keep its navigation pending.
        setTimeout(() => {
          const until = performance.now() + 2_500;
          while (performance.now() < until) {}
        }, 190);
      },
      { once: true },
    );
  });
  await page.setViewportSize({ width: 1439, height: 900 });
  await page.locator('.nav-download').evaluate((link: HTMLAnchorElement) => {
    link.click();
  });
  await expect(page).toHaveURL(/#download$/);
  await expect(page.locator('.download-package')).toBeInViewport({
    timeout: 5_000,
  });
  await expect(page.locator('.pin-spacer')).toHaveCount(3);
});

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
    await expect(page).toHaveTitle(`${locale.brand} — ${locale.title}`);
    await expect(page.locator('meta[property="og:site_name"]')).toHaveAttribute(
      'content',
      'Hoopito · 球豆',
    );
    await expect(page.locator('.wordmark')).toHaveText('HOOPITO.');
    await expect(page.locator('.wordmark')).toHaveAttribute(
      'aria-label',
      'Hoopito · 球豆',
    );
    await expect(page.locator('.hero-lead')).toContainText(locale.brand);
    await expect(page.locator('.install-note')).toContainText('v2.0.1');
    await expect(page.locator('link[rel="canonical"]')).toHaveCount(0);
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
    await expect(page).toHaveTitle(new RegExp(locale.brand));
    await expect(page.locator('.wordmark')).toHaveText('HOOPITO.');
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
    await page.setViewportSize({ width: 390, height: 844 });
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
    await expect(page.locator('#download')).toContainText('2.0.1');
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
    requested.some((url) => new URL(url).pathname.startsWith('/textures/')),
  ).toBe(false);
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

test('a system motion change during a mobile shot completes once and still permits reset', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  const requested: string[] = [];
  page.on('request', (request) => requested.push(request.url()));
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  expect(requested.some((url) => threeChunk.test(url))).toBe(false);
  await page.locator('#experience').scrollIntoViewIfNeeded();
  await page.locator('[data-point-preset="right"]').click();
  await page.locator('[data-record]').click();
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('[data-demo-marker]')).toBeVisible();
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.locator('[data-reset]').click();
  await expectReset(page);
  await page.waitForTimeout(1800);
  await expectReset(page);
  await expectDownload(page);
});

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

test(
  'a failed 3D module never hides the download or blocks the demo',
  { tag: '@webgl' },
  async ({ page }, testInfo) => {
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
  },
);

test(
  'a missing court texture keeps the introduction, download and scoring usable',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Desktop material lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    const errors: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    let requested = false;
    await page.route('**/textures/maple-albedo-v2.webp', async (route) => {
      requested = true;
      await route.abort('failed');
    });
    await page.goto('/');
    await expect.poll(() => requested).toBe(true);
    await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
    await expect(page.locator('#court-canvas')).not.toHaveAttribute(
      'data-scene-ready',
      'true',
    );
    await expectDownload(page);
    await page.locator('#experience').scrollIntoViewIfNeeded();
    await page.locator('[data-point-preset="center"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await page.locator('[data-reset]').click();
    await expectReset(page);
    expect(errors).toEqual([]);
  },
);

test(
  'slow court textures time out without late 3D activation',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Desktop material lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    let requested = false;
    let release: () => void = () => {};
    const gate = new Promise<void>((resolve) => {
      release = resolve;
    });
    const errors: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.route('**/textures/maple-albedo-v2.webp', async (route) => {
      requested = true;
      await gate;
      await route.continue().catch(() => {});
    });
    try {
      await page.goto('/', { waitUntil: 'domcontentloaded' });
      await expect.poll(() => requested).toBe(true);
      await expectDownload(page);
      await expect(page.locator('html')).toHaveAttribute('data-scene', '2d', {
        timeout: 11_000,
      });
      release();
      await page.waitForLoadState('networkidle');
      await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
      await expect(page.locator('#court-canvas')).not.toHaveAttribute(
        'data-scene-ready',
        'true',
      );
      expect(errors).toEqual([]);
    } finally {
      release();
    }
  },
);

test(
  'slow 3D initialization gives up after eight seconds and does not activate late',
  { tag: '@webgl' },
  async ({ page }, testInfo) => {
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
  },
);

test(
  'a desktop scene cleans up on context loss and remains usable after resizing',
  { tag: '@webgl', lock: 'webgl-renderer' },
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
  'a shot recorded while 3D loads survives scene initialization and system motion changes',
  { tag: '@webgl', lock: 'webgl-renderer' },
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
      // Release once a shot exists during loading. Artificially withholding the
      // module for the entire flight leaves insufficient shader-compile time
      // on CI; the real eight-second fallback deadline must stay unchanged.
      release();
      await expect(page.locator('[data-demo-marker]')).toBeVisible();
      await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await expect(page.locator('[data-record]')).toBeDisabled();
      await page.screenshot({
        path: testInfo.outputPath('zh-CN-1440-startup-completed-shot-3d.png'),
      });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await page.emulateMedia({ reducedMotion: 'no-preference' });
      await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
      await page.setViewportSize({ width: 390, height: 844 });
      await expect(page.locator('[data-demo-marker]')).toBeVisible();
    } finally {
      release();
    }
  },
);

test(
  'court remains antialiased and interactive without HDR multisampling',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ browser }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'GPU pipeline runs in Chromium.',
    );
    const context = await browser.newContext({
      viewport: { width: 1440, height: 900 },
      deviceScaleFactor: 2,
      reducedMotion: 'reduce',
    });
    try {
      const page = await context.newPage();
      await allowSoftwareWebGL(page);
      await page.addInitScript(() => {
        const original =
          WebGL2RenderingContext.prototype.getInternalformatParameter;
        WebGL2RenderingContext.prototype.getInternalformatParameter = function (
          target,
          format,
          name,
        ) {
          // Simulate the capability boundary, retaining real WebGL rendering and shaders.
          if (format === this.RGBA16F && name === this.SAMPLES)
            return new Int32Array();
          return original.call(this, target, format, name);
        };
      });
      const errors: string[] = [];
      page.on('pageerror', (error) => errors.push(error.message));
      page.on('console', (message) => {
        if (message.type() === 'error') errors.push(message.text());
      });
      await page.goto(`${origin}/`);
      await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
      await expect(page.locator('#court-canvas')).toHaveAttribute(
        'data-antialias',
        'fxaa',
      );
      await page.setViewportSize({ width: 1280, height: 800 });
      await expect
        .poll(() =>
          page
            .locator('#court-canvas')
            .evaluate(
              (canvas: HTMLCanvasElement) =>
                canvas.width === canvas.clientWidth * 2 &&
                canvas.height === canvas.clientHeight * 2,
            ),
        )
        .toBe(true);
      await page
        .locator('#experience')
        .evaluate((section) =>
          section.scrollIntoView({ behavior: 'instant', block: 'start' }),
        );
      await page.locator('[data-point-preset="center"]').focus();
      await page.keyboard.press('Enter');
      await page.locator('[data-record]').focus();
      await page.keyboard.press('Enter');
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await expect(page.locator('[data-demo-marker]')).toBeVisible();
      await page.screenshot({
        path: testInfo.outputPath('court-fxaa-resized.png'),
      });
      await page.locator('[data-reset]').click();
      await expectReset(page);
      expect(errors).toEqual([]);
    } finally {
      await context.close();
    }
  },
);

test(
  'initial GPU budget covers story views and restores the opening pose',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'GPU pipeline runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    const canvas = page.locator('#court-canvas');
    const costs = JSON.parse(
      (await canvas.getAttribute('data-calibration')) ?? '[]',
    );
    if (costs.length) {
      for (const cost of costs) {
        expect(
          cost.views.map((view: { chapter: string }) => view.chapter),
        ).toEqual(['hero', 'scoring', 'experience', 'replay']);
        expect(cost.milliseconds).toBe(
          Math.max(
            ...cost.views.map(
              (view: { milliseconds: number }) => view.milliseconds,
            ),
          ),
        );
      }
    }
    await expect(canvas).toHaveAttribute('data-chapter', 'hero');
    await expect(canvas).toHaveAttribute('data-story-progress', '0.0000');
    await expect(page.locator('a[href="#download"]').first()).toBeVisible();
  },
);

for (const scale of [1, 2]) {
  test(
    `court rendering at ${scale}x density antialiases its actual scene buffer`,
    { tag: '@webgl', lock: 'webgl-renderer' },
    async ({ browser }, testInfo) => {
      test.skip(
        testInfo.project.name !== 'chromium',
        'GPU pipeline runs in Chromium.',
      );
      const context = await browser.newContext({
        viewport: { width: 1440, height: 900 },
        deviceScaleFactor: scale,
        reducedMotion: 'reduce',
      });
      try {
        const page = await context.newPage();
        await allowSoftwareWebGL(page);
        await page.addInitScript(() => {
          const buffers: { samples: number; width: number; height: number }[] =
            [];
          Reflect.set(window, 'hoopitoRenderbuffers', buffers);
          const original =
            WebGL2RenderingContext.prototype.renderbufferStorageMultisample;
          WebGL2RenderingContext.prototype.renderbufferStorageMultisample =
            function (target, samples, format, width, height) {
              buffers.push({ samples, width, height });
              return original.call(
                this,
                target,
                samples,
                format,
                width,
                height,
              );
            };
        });
        const errors: string[] = [];
        page.on('pageerror', (error) => errors.push(error.message));
        page.on('console', (message) => {
          if (
            message.type() === 'error' &&
            /shader|WebGL|GL_INVALID|framebuffer/i.test(message.text())
          )
            errors.push(message.text());
        });
        await page.goto(`${origin}/`);
        await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
        const pixels = await page
          .locator('#court-canvas')
          .evaluate((canvas: HTMLCanvasElement) => ({
            width: canvas.width,
            height: canvas.height,
            cssWidth: canvas.clientWidth,
            cssHeight: canvas.clientHeight,
            antialias: canvas.dataset.antialias,
            buffers: Reflect.get(window, 'hoopitoRenderbuffers') as {
              samples: number;
              width: number;
              height: number;
            }[],
          }));
        // Native density reaches the actual visible scene region without a full-screen buffer.
        expect(pixels.width).toBe(Math.round(pixels.cssWidth * scale));
        expect(pixels.height).toBe(Math.round(pixels.cssHeight * scale));
        expect(pixels.cssWidth).toBeLessThan(1440);
        expect(pixels.antialias).toMatch(/^(msaa-[24]|fxaa)$/);
        if (pixels.antialias !== 'fxaa')
          expect(
            pixels.buffers.some(
              (buffer) =>
                buffer.samples >= 2 &&
                buffer.width === pixels.width &&
                buffer.height === pixels.height,
            ),
          ).toBe(true);
        await page.screenshot({
          path: testInfo.outputPath(`court-${scale}x-hero.png`),
        });
        await page
          .locator('#experience')
          .evaluate((section) =>
            section.scrollIntoView({ behavior: 'instant', block: 'start' }),
          );
        await page.locator('[data-point-preset="center"]').click();
        await page.locator('[data-record]').click();
        await expect(page.locator('[data-blue-score]')).toHaveText('8');
        await page.screenshot({
          path: testInfo.outputPath(`court-${scale}x-demo.png`),
        });
        // CDP updates DPR silently; a real viewport change emits the browser resize notification.
        // Exercise the same renderer while changing both density and window dimensions.
        const nextScale = scale === 1 ? 2 : 1;
        const nextWidth = 1441;
        const session = await context.newCDPSession(page);
        await session.send('Emulation.setDeviceMetricsOverride', {
          width: nextWidth,
          height: 900,
          deviceScaleFactor: nextScale,
          mobile: false,
        });
        await expect
          .poll(() => page.evaluate(() => window.devicePixelRatio))
          .toBe(nextScale);
        await expect
          .poll(() =>
            page
              .locator('#court-canvas')
              .evaluate(
                (canvas: HTMLCanvasElement) =>
                  canvas.width ===
                    Math.round(canvas.clientWidth * window.devicePixelRatio) &&
                  canvas.height ===
                    Math.round(canvas.clientHeight * window.devicePixelRatio),
              ),
          )
          .toBe(true);
        await expect
          .poll(() =>
            page
              .locator('#court-canvas')
              .evaluate((canvas: HTMLCanvasElement) => {
                const gl = canvas.getContext('webgl2')!;
                const color = Array.from(
                  gl.getInternalformatParameter(
                    gl.RENDERBUFFER,
                    gl.RGBA16F,
                    gl.SAMPLES,
                  ) as Int32Array,
                );
                const depth = Array.from(
                  gl.getInternalformatParameter(
                    gl.RENDERBUFFER,
                    gl.DEPTH_COMPONENT24,
                    gl.SAMPLES,
                  ) as Int32Array,
                );
                const wanted = Math.max(
                  0,
                  ...color.filter(
                    (value) =>
                      value >= 2 &&
                      value <= (window.devicePixelRatio >= 1.5 ? 2 : 4) &&
                      depth.includes(value),
                  ),
                );
                const buffers = Reflect.get(window, 'hoopitoRenderbuffers') as {
                  samples: number;
                  width: number;
                  height: number;
                }[];
                return wanted
                  ? canvas.dataset.antialias === `msaa-${wanted}` &&
                      buffers.some(
                        (buffer) =>
                          buffer.samples === wanted &&
                          buffer.width === canvas.width &&
                          buffer.height === canvas.height,
                      )
                  : canvas.dataset.antialias === 'fxaa';
              }),
          )
          .toBe(true);
        await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
        await expect(page.locator('[data-blue-score]')).toHaveText('8');
        await session.detach();
        expect(errors).toEqual([]);
      } finally {
        await context.close();
      }
    },
  );
}

test(
  'system motion preferences keep the same court, stop idle drawing and resume animation',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Renderer lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    await page.addInitScript(() => {
      const state = window as unknown as { hoopitoDrawCalls: number };
      state.hoopitoDrawCalls = 0;
      for (const method of ['drawElements', 'drawArrays'] as const) {
        const original = WebGL2RenderingContext.prototype[method];
        Reflect.set(
          WebGL2RenderingContext.prototype,
          method,
          function (this: WebGL2RenderingContext, ...args: unknown[]) {
            state.hoopitoDrawCalls += 1;
            return Reflect.apply(original, this, args);
          },
        );
      }
    });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    // Keep the actual renderer context: preference changes must not dispose/recreate the scene.
    await page.evaluate(() => {
      const canvas =
        document.querySelector<HTMLCanvasElement>('#court-canvas')!;
      Reflect.set(window, 'hoopitoContext', canvas.getContext('webgl2'));
    });
    const count = () =>
      page.evaluate(() => Reflect.get(window, 'hoopitoDrawCalls') as number);
    const idleDrawCount = async () => {
      // Pin removal and canvas resizing can request a final frame after the
      // media event. Software rendering may delay it past a fixed 250ms pause.
      // Require an actual quiet interval; continuous drawing still fails.
      await expect
        .poll(
          async () => {
            const before = await count();
            await page.waitForTimeout(350);
            return {
              quiet: (await count()) === before,
              state: await page
                .locator('#court-canvas')
                .getAttribute('data-rendering'),
            };
          },
          { timeout: 5_000, intervals: [100] },
        )
        .toEqual({ quiet: true, state: 'idle' });
      return count();
    };
    const idle = await idleDrawCount();
    await page
      .locator('#experience')
      .evaluate((section) =>
        section.scrollIntoView({ behavior: 'instant', block: 'start' }),
      );
    await expect.poll(count).toBeGreaterThan(idle);
    await page.locator('[data-point-preset="center"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-record]')).toBeDisabled();
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    const resumed = await count();
    await expect.poll(count).toBeGreaterThan(resumed);
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    expect(
      await page.evaluate(
        () =>
          document
            .querySelector<HTMLCanvasElement>('#court-canvas')!
            .getContext('webgl2') === Reflect.get(window, 'hoopitoContext'),
      ),
    ).toBe(true);
    await page.emulateMedia({ reducedMotion: 'reduce' });
    const quiet = await idleDrawCount();
    await page.locator('[data-reset]').click();
    await expectReset(page);
    await expect.poll(count).toBeGreaterThan(quiet);
  },
);

test(
  'resetting a desktop shot clears its score and its animated location',
  { tag: '@webgl', lock: 'webgl-renderer' },
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
    // The shared SVG court provides the same pointer interaction on desktop and mobile.
    await page
      .locator('[data-demo-court]')
      .click({ position: { x: 180, y: 250 } });
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
  { tag: '@webgl', lock: 'webgl-renderer' },
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
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The desktop renderer lifecycle runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    // Count real GPU draw submissions at the browser boundary; production code has no test hooks.
    await page.addInitScript(() => {
      const state = window as unknown as { hoopitoDrawCalls: number };
      state.hoopitoDrawCalls = 0;
      for (const method of ['drawElements', 'drawArrays'] as const) {
        const original = WebGL2RenderingContext.prototype[method];
        const wrapped = function (
          this: WebGL2RenderingContext,
          ...args: unknown[]
        ) {
          state.hoopitoDrawCalls += 1;
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
          (window as unknown as { hoopitoDrawCalls: number }).hoopitoDrawCalls,
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
