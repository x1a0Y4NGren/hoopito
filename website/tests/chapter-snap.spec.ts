import { expect, test, type Page, type TestInfo } from '@playwright/test';

type StopId =
  | 'hero'
  | 'scoring'
  | 'experience'
  | 'replay'
  | 'download'
  | 'community'
  | 'closing';
type ReadingRange = { start: number; end: number };
type TraceFrame = {
  time: number;
  y: number;
  state: string | undefined;
  stop: string | undefined;
};
const sceneChunk = /court-scene[^/]*\.(?:js|ts)(?:\?|$)/;

const stageSelector = (id: StopId) =>
  id === 'closing' ? '#closing' : `[data-story-stage="${id}"]`;

async function range(page: Page, id: StopId): Promise<ReadingRange> {
  const stage = page.locator(stageSelector(id));
  await expect(stage).toHaveAttribute('data-scroll-read-start', /\d/);
  return stage.evaluate((element) => ({
    start: Number((element as HTMLElement).dataset.scrollReadStart),
    end: Number((element as HTMLElement).dataset.scrollReadEnd),
  }));
}

async function reading(page: Page, id: StopId) {
  const bounds = await range(page, id);
  await expect
    .poll(() =>
      range(page, id).then((current) =>
        page.evaluate(async ({ start, end }) => {
          const before = scrollY;
          await new Promise(requestAnimationFrame);
          await new Promise(requestAnimationFrame);
          return (
            before >= start - 2 &&
            before <= end + 2 &&
            Math.abs(scrollY - before) < 1 &&
            document.documentElement.dataset.scrollState === 'idle'
          );
        }, current),
      ),
    )
    .toBe(true)
    .catch(async (error) => {
      const actual = await page.evaluate(() => ({
        y: scrollY,
        root: { ...document.documentElement.dataset },
        stops: [
          ...document.querySelectorAll<HTMLElement>('[data-scroll-read-start]'),
        ].map((e) => ({
          id: e.id || e.dataset.storyStage,
          start: e.dataset.scrollReadStart,
          end: e.dataset.scrollReadEnd,
        })),
      }));
      throw new Error(
        `${error}\nReading ${id} expected ${JSON.stringify(bounds)}; actual ${JSON.stringify(actual)}`,
      );
    });
  await expect(page.locator('html')).toHaveAttribute('data-scroll-stop', id);
  if (id === 'closing') {
    await expect(page.locator('#closing [data-glass-card]')).toHaveCount(0);
    await expect(page.locator('#closing .faq')).toBeVisible();
    await expect(page.locator('#closing .site-footer')).toBeVisible();
  } else {
    await expect(
      page.locator(stageSelector(id) + ' [data-glass-card]').first(),
    ).toHaveCSS('opacity', '1');
  }
  return range(page, id);
}

async function open(
  page: Page,
  path = '/',
  options: {
    css?: boolean;
    reduced?: boolean;
    width?: number;
    height?: number;
  } = {},
) {
  await page.setViewportSize({
    width: options.width ?? 1440,
    height: options.height ?? 900,
  });
  await page.emulateMedia({
    reducedMotion: options.reduced ? 'reduce' : 'no-preference',
  });
  if (options.css !== false)
    await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('#closing')).toHaveAttribute(
    'data-scroll-read-start',
    /\d/,
  );
  // A scroll gesture belongs to the content area. Moving into the fixed
  // navigation deliberately cancels a gesture so the user can click a link.
  await page.mouse.move(20, 450);
}

async function beginTrace(page: Page) {
  await page.evaluate(() => {
    const frames: TraceFrame[] = [];
    let active = true;
    const sample = () => {
      frames.push({
        time: performance.now(),
        y: scrollY,
        state: document.documentElement.dataset.scrollState,
        stop: document.documentElement.dataset.scrollStop,
      });
      if (active) requestAnimationFrame(sample);
    };
    sample();
    Reflect.set(window, '__stopSnapTrace', () => {
      active = false;
      return frames;
    });
  });
}

async function stationary(page: Page) {
  await expect
    .poll(() =>
      page.evaluate(async () => {
        const before = scrollY;
        await new Promise(requestAnimationFrame);
        await new Promise(requestAnimationFrame);
        return Math.abs(scrollY - before) < 1;
      }),
    )
    .toBe(true);
}

async function endTrace(page: Page, testInfo: TestInfo, name: string) {
  const frames = await page.evaluate(() =>
    (Reflect.get(window, '__stopSnapTrace') as () => TraceFrame[])(),
  );
  await testInfo.attach(name, {
    body: JSON.stringify(frames, null, 2),
    contentType: 'application/json',
  });
  return frames;
}

test('a tiny wheel previews then returns to the same readable chapter', async ({
  page,
}, testInfo) => {
  await open(page);
  await reading(page, 'hero');
  const before = await page.evaluate(() => scrollY);
  await beginTrace(page);
  await page.mouse.wheel(0, 23);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'tracking',
  );
  await reading(page, 'hero');
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - before),
  ).toBeLessThanOrEqual(2);
  const frames = await endTrace(page, testInfo, 'tiny-wheel-return');
  expect(frames.some((frame) => frame.y > before + 1)).toBe(true);
  expect(frames.every((frame) => frame.stop === 'hero')).toBe(true);
});

test('a meaningful wheel completes a continuous adjacent transition and settles all cards', async ({
  page,
}, testInfo) => {
  await open(page);
  await reading(page, 'hero');
  const next = await range(page, 'scoring');
  await beginTrace(page);
  await page.mouse.wheel(0, 24);
  await reading(page, 'scoring');
  const frames = await endTrace(page, testInfo, 'adjacent-transition');
  const moving = frames.filter(
    (frame, index) =>
      index > 0 && Math.abs(frame.y - frames[index - 1].y) > 0.1,
  );
  // Frame throughput is measured by the GPU suite. This checks elapsed motion,
  // intermediate positions and continuity even in a slower software browser.
  expect(moving.length).toBeGreaterThan(3);
  expect(frames.at(-1)!.time - frames[0].time).toBeGreaterThanOrEqual(950);
  // Sampled browser frames prove the direction and intermediate positions;
  // the exact continuous curve is unit-tested, and real GPU cadence has its
  // own unchanged performance gate. Software RAF sampling is not a FPS test.
  for (const [index, frame] of frames.slice(1).entries()) {
    expect(frame.y).toBeGreaterThanOrEqual(frames[index].y - 1);
    expect(frame.y).toBeLessThanOrEqual(next.start + 2);
  }
  await expect(page.locator('#scoring h2')).toBeInViewport();
  expect(await page.evaluate(() => scrollY)).toBeLessThanOrEqual(next.end + 2);
  await page.mouse.wheel(0, -24);
  await reading(page, 'hero');
});

test('a very large wheel cannot skip the intermediate chapter', async ({
  page,
}) => {
  await open(page);
  await reading(page, 'hero');
  await page.mouse.wheel(0, 2000);
  const next = await reading(page, 'scoring');
  expect(await page.evaluate(() => scrollY)).toBeLessThanOrEqual(next.end + 2);
  await expect(page.locator('#scoring [data-glass-card]').first()).toHaveCSS(
    'opacity',
    '1',
  );
});

test('a decaying trackpad tail commits once and a new gesture can reverse', async ({
  page,
}, testInfo) => {
  await open(page);
  await reading(page, 'hero');
  await page.evaluate(() => {
    const events: Record<string, unknown>[] = [];
    Reflect.set(window, '__snapWheelLog', events);
    // Registered after the application so this observes its cancellation and
    // resulting state without changing the event, clock or wheel processing.
    window.addEventListener(
      'wheel',
      (event) => {
        events.push({
          dy: event.deltaY,
          dx: event.deltaX,
          deltaMode: event.deltaMode,
          cancelable: event.cancelable,
          defaultPrevented: event.defaultPrevented,
          y: scrollY,
          time: performance.now(),
          state: document.documentElement.dataset.scrollState,
          stop: document.documentElement.dataset.scrollStop,
        });
      },
      { passive: true },
    );
  });
  try {
    // These are real browser wheel inputs; the short gaps model one continuing gesture.
    await Promise.all(
      [20, 18, 14, 10, 8, 6, 4, 3, 2, 1].map(async (delta, index) => {
        // Schedule against the driver clock; do not add a protocol round trip
        // to every interval, which can turn a burst into separate gestures.
        await new Promise((resolve) => setTimeout(resolve, index * 30));
        await page.mouse.wheel(0, delta);
      }),
    );
    await reading(page, 'scoring');
    await page.mouse.wheel(0, -60);
    await reading(page, 'hero');
    await expect(page.locator('#hero h1')).toBeInViewport();
  } finally {
    await testInfo.attach('trackpad-wheel-diagnostics', {
      body: JSON.stringify(
        await page.evaluate(() => Reflect.get(window, '__snapWheelLog')),
        null,
        2,
      ),
      contentType: 'application/json',
    });
  }
});

test('opposite sub-threshold input cancels the net intent rather than changing chapter', async ({
  page,
}) => {
  await open(page);
  await reading(page, 'hero');
  await page.mouse.wheel(0, 12);
  await page.mouse.wheel(0, -12);
  await reading(page, 'hero');
  expect(await page.evaluate(() => scrollY)).toBeLessThanOrEqual(2);
});

test('a pending tiny-wheel return cannot overwrite an external seek', async ({
  page,
}) => {
  await open(page);
  await reading(page, 'hero');
  const replay = await range(page, 'replay');
  await page.mouse.wheel(0, 10);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'tracking',
  );
  await page.evaluate(
    (top) => scrollTo({ top, behavior: 'instant' }),
    replay.start,
  );
  await reading(page, 'replay');
  // Observe longer than both quiet detection and the complete rollback duration.
  await page.waitForTimeout(500);
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - replay.start),
  ).toBeLessThanOrEqual(2);
});

test('a long download reads to its boundary before a new gesture switches chapter', async ({
  page,
}) => {
  await open(page, '/#download', { height: 600 });
  const download = await reading(page, 'download');
  expect(download.end - download.start).toBeGreaterThan(50);
  // Queue both native events together: protocol round trips can exceed the
  // product's 180ms gesture boundary on WebKit, so do not poll between the tail.
  await Promise.all([page.mouse.wheel(0, 4000), page.mouse.wheel(0, 120)]);
  await expect
    .poll(async () =>
      Math.abs((await page.evaluate(() => scrollY)) - download.end),
    )
    .toBeLessThanOrEqual(2);
  expect(await page.evaluate(() => scrollY)).toBeLessThanOrEqual(
    download.end + 2,
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'download',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await page.mouse.wheel(0, 60);
  await reading(page, 'community');
});

test('horizontal, zoom and nested text scrolling do not trigger chapter switching', async ({
  page,
}) => {
  await open(page);
  await reading(page, 'hero');
  await page.mouse.wheel(120, 0);
  await page.keyboard.down('Control');
  await page.mouse.wheel(0, 60);
  await page.keyboard.up('Control');
  await expect(page.locator('html')).not.toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'hero',
  );
  await page.evaluate(() => {
    const input = document.createElement('textarea');
    input.id = 'snap-nested-reader';
    input.style.cssText =
      'position:fixed;top:150px;left:150px;width:200px;height:120px;z-index:99';
    input.value = Array.from(
      { length: 100 },
      (_, i) => `Nested reading line ${i}`,
    ).join('\n');
    document.body.append(input);
  });
  const reader = page.locator('#snap-nested-reader');
  await reader.hover();
  await page.mouse.wheel(0, 120);
  await expect
    .poll(() => reader.evaluate((element) => element.scrollTop))
    .toBeGreaterThan(0);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'hero',
  );
});

test('navigation and modal opening cancel the old scroll owner', async ({
  page,
}) => {
  await open(page);
  await reading(page, 'hero');
  await page.mouse.wheel(0, 60);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await page.locator('.nav-download').click();
  await reading(page, 'download');
  await page.locator('.download-package [data-download]').click();
  await expect(page.locator('[data-download-dialog]')).toBeVisible();
  const top = await page.evaluate(() => scrollY);
  await page.mouse.wheel(0, 120);
  await expect(page.locator('[data-download-dialog]')).toBeVisible();
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - top),
  ).toBeLessThanOrEqual(2);
  await page.keyboard.press('Escape');
  await expect(page.locator('[data-download-dialog]')).not.toBeVisible();
  await reading(page, 'download');
});

test('a viewport change remeasures and completes the original chapter transition', async ({
  page,
}) => {
  await open(page);
  await reading(page, 'hero');
  await page.mouse.wheel(0, 60);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await page.setViewportSize({ width: 1280, height: 720 });
  await expect(page.locator('#closing')).toHaveAttribute(
    'data-scroll-read-start',
    /\d/,
  );
  await reading(page, 'scoring');
});

for (const locale of ['/', '/en/']) {
  test(`${locale}: closing FAQ and footer stay readable after expansion and preserve language/navigation`, async ({
    page,
  }, testInfo) => {
    await open(page, locale + '#closing');
    await reading(page, 'closing');
    await expect(page.locator('#download .faq')).toHaveCount(0);
    await expect(page.locator('#closing .faq')).toHaveCount(1);
    await expect(page.locator('#closing .site-footer')).toHaveCount(1);
    await expect(page.locator('#closing')).not.toHaveAttribute(
      'data-story-stage',
    );
    await expect(page.locator('[data-language]')).toHaveAttribute(
      'href',
      locale === '/' ? '/en/#closing' : '/#closing',
    );
    await page.screenshot({ path: testInfo.outputPath('closing.png') });
    const collapsed = await range(page, 'closing');
    for (const summary of await page.locator('#closing .faq summary').all()) {
      await summary.click();
    }
    await expect
      .poll(async () => (await range(page, 'closing')).end)
      .toBeGreaterThan(collapsed.end + 20);
    await expect
      .poll(async () => {
        const end = (await range(page, 'closing')).end;
        return page.evaluate(
          (value) =>
            Math.abs(
              value - (document.documentElement.scrollHeight - innerHeight),
            ),
          end,
        );
      })
      .toBeLessThanOrEqual(2);
    const expanded = await range(page, 'closing');
    await page.mouse.move(20, 400);
    await page.mouse.wheel(0, 4000);
    await expect
      .poll(async () =>
        Math.abs((await page.evaluate(() => scrollY)) - expanded.end),
      )
      .toBeLessThanOrEqual(2);
    await expect(page.locator('.footer-bottom small')).toBeInViewport();
    for (const link of await page.locator('.footer-bottom a').all()) {
      await expect(link).toBeVisible();
      const box = (await link.boundingBox())!;
      expect(box.height).toBeGreaterThanOrEqual(47.9);
    }
    await page.screenshot({
      path: testInfo.outputPath('closing-expanded-footer.png'),
    });
    await page.locator('.site-footer a[href="#hero"]').click();
    await reading(page, 'hero');
  });
}

test('mobile retains natural scrolling instead of chapter capture', async ({
  page,
}) => {
  await open(page, '/', { width: 390, height: 844 });
  await page.mouse.wheel(0, 60);
  await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(0);
  await expect(page.locator('html')).not.toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await stationary(page);
  const top = await page.evaluate(() => scrollY);
  await page.waitForTimeout(550);
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - top),
  ).toBeLessThanOrEqual(2);
});

test('reduced motion retains native scrolling without automatic chapter motion', async ({
  page,
}) => {
  await open(page, '/', { reduced: true });
  await page.mouse.wheel(0, 60);
  await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(0);
  await expect(page.locator('html')).not.toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await stationary(page);
  const top = await page.evaluate(() => scrollY);
  await page.waitForTimeout(550);
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - top),
  ).toBeLessThanOrEqual(2);
});

test('short screens and 200 percent text retain all final content', async ({
  page,
}, testInfo) => {
  await open(page, '/en/#closing', { width: 1024, height: 600 });
  await page.evaluate(() => {
    const nodes = [
      ...document.querySelectorAll<HTMLElement>('#closing *'),
    ].filter((element) =>
      [...element.childNodes].some(
        (node) => node.nodeType === Node.TEXT_NODE && node.textContent?.trim(),
      ),
    );
    const sizes = nodes.map(
      (node) => [node, parseFloat(getComputedStyle(node).fontSize)] as const,
    );
    for (const [node, size] of sizes) node.style.fontSize = `${size * 2}px`;
    dispatchEvent(new Event('resize'));
  });
  await expect
    .poll(async () => {
      const bounds = await range(page, 'closing');
      return bounds.end - bounds.start;
    })
    .toBeGreaterThan(200);
  for (const summary of await page.locator('#closing .faq summary').all()) {
    await summary.click();
    await expect(summary.locator('..').locator('p')).toBeVisible();
  }
  await expect
    .poll(async () => {
      const end = (await range(page, 'closing')).end;
      return page.evaluate(
        (value) =>
          Math.abs(
            value - (document.documentElement.scrollHeight - innerHeight),
          ),
        end,
      );
    })
    .toBeLessThanOrEqual(2);
  const bounds = await range(page, 'closing');
  await page.evaluate(
    (top) => scrollTo({ top, behavior: 'instant' }),
    bounds.end,
  );
  await expect(page.locator('.footer-bottom small')).toBeInViewport();
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth - innerWidth,
    ),
  ).toBeLessThanOrEqual(1);
  const clipped = await page.locator('#closing .faq').evaluate((element) => {
    const bounds = element.getBoundingClientRect();
    const walker = document.createTreeWalker(element, NodeFilter.SHOW_TEXT);
    let maximum = 0;
    for (let node = walker.nextNode(); node; node = walker.nextNode()) {
      if (!node.textContent?.trim()) continue;
      const range = document.createRange();
      range.selectNodeContents(node);
      for (const rect of range.getClientRects())
        maximum = Math.max(
          maximum,
          bounds.left - rect.left,
          rect.right - bounds.right,
        );
    }
    // The accepted FAQ scrim feathers 72px beyond its box. Measure real text
    // rather than counting that intentional decorative overflow as clipping.
    return maximum;
  });
  expect(clipped).toBeLessThanOrEqual(1);
  await page.screenshot({
    path: testInfo.outputPath('closing-200percent.png'),
  });
});

test('transition review video uses the production renderer and ordinary motion @webgl', async ({
  browser,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium',
    'A single Chromium recording provides the transition review artifact.',
  );
  const context = await browser.newContext({
    baseURL: 'http://127.0.0.1:4321',
    viewport: { width: 1440, height: 900 },
    reducedMotion: 'no-preference',
    recordVideo: {
      dir: testInfo.outputPath('video'),
      size: { width: 1440, height: 900 },
    },
  });
  const page = await context.newPage();
  try {
    const available = await page.evaluate(() => {
      const gl = document
        .createElement('canvas')
        .getContext('webgl2', { failIfMajorPerformanceCaveat: true });
      gl?.getExtension('WEBGL_lose_context')?.loseContext();
      return !!gl;
    });
    test.skip(
      !available,
      'Production WebGL2 is unavailable; CSS behavior is verified independently.',
    );
    await open(page, '/', { css: false });
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
      timeout: 20000,
    });
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-rendering',
      'ambient',
    );
    await reading(page, 'hero');
    await beginTrace(page);
    await page.mouse.wheel(0, 60);
    await reading(page, 'scoring');
    await page.mouse.wheel(0, 60);
    await reading(page, 'experience');
    await page.mouse.wheel(0, -60);
    await reading(page, 'scoring');
    await endTrace(page, testInfo, 'production-transition-frames');
    await page.goto('/#download');
    await reading(page, 'download');
    await page.screenshot({ path: testInfo.outputPath('download.png') });
    await page.goto('/#closing');
    await reading(page, 'closing');
    await page.screenshot({ path: testInfo.outputPath('closing.png') });
    await testInfo.attach('production-runtime', {
      body: JSON.stringify(
        await page.evaluate(() => ({
          root: { ...document.documentElement.dataset },
          canvas: {
            ...(document.querySelector('#court-canvas') as HTMLElement).dataset,
          },
        })),
        null,
        2,
      ),
      contentType: 'application/json',
    });
  } finally {
    const video = page.video();
    await context.close();
    if (video)
      await testInfo.attach('chapter-transition-video', {
        path: await video.path(),
        contentType: 'video/webm',
      });
  }
});
