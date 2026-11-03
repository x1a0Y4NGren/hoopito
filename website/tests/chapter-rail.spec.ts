import { expect, test, type Page } from '@playwright/test';

const ids = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
  'community',
  'closing',
];
const railSelector = 'aside[data-chapter-rail]';
async function stableLayout(page: Page) {
  let last = '',
    since = Date.now();
  await expect
    .poll(async () => {
      const key = await page.evaluate(() =>
        JSON.stringify([
          document.documentElement.scrollHeight,
          ...[
            ...document.querySelectorAll<HTMLElement>(
              '[data-story-stage], #closing',
            ),
          ].map((el) => [el.dataset.scrollReadStart, el.dataset.scrollReadEnd]),
        ]),
      );
      if (key !== last) since = Date.now();
      last = key;
      return Date.now() - since;
    })
    .toBeGreaterThanOrEqual(250);
}
async function ready(page: Page, path = '/') {
  await page.route(/court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/, (route) =>
    route.abort(),
  );
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter-rail',
    'ready',
  );
  await stableLayout(page);
}
async function expectRailProportions(page: Page) {
  const geometry = await page.locator(railSelector).evaluate((rail) => {
    const bounds = (el: Element) => el.getBoundingClientRect();
    const track = bounds(rail.querySelector('[data-rail-track]')!);
    const line = rail.querySelector('.chapter-rail-line')!;
    const fill = rail.querySelector('[data-rail-fill]')!;
    const counter = bounds(rail.querySelector('.chapter-rail-counter')!);
    const header = bounds(document.querySelector('.site-header')!);
    const box = bounds(rail);
    return {
      headerBottom: header.bottom,
      viewportHeight: innerHeight,
      trackHeight: track.height,
      trackCenter: track.x + track.width / 2,
      railTop: box.top,
      railBottom: box.bottom,
      trackBottom: track.bottom,
      counterTop: counter.top,
      counterCenter: counter.x + counter.width / 2,
      symbolWidth: bounds(rail.querySelector('.chapter-rail-symbol')!).width,
      strokes: [line, fill].map((el) => ({
        width: bounds(el).width,
        center: bounds(el).x + bounds(el).width / 2,
        height: parseFloat(getComputedStyle(el).height),
        radius: parseFloat(getComputedStyle(el).borderTopLeftRadius),
      })),
      nodes: [...rail.querySelectorAll('[data-rail-node]')].map((el) => ({
        center: bounds(el).x + bounds(el).width / 2,
        width: bounds(el).width,
        height: bounds(el).height,
        dotWidth: parseFloat(getComputedStyle(el, '::before').width),
        dotHeight: parseFloat(getComputedStyle(el, '::before').height),
      })),
    };
  });
  const usable = geometry.viewportHeight - geometry.headerBottom;
  const expectedHeight = Math.min(usable - 80, Math.max(400, usable * 0.75));
  expect(Math.abs(geometry.trackHeight - expectedHeight)).toBeLessThanOrEqual(
    1,
  );
  expect(geometry.symbolWidth).toBe(32);
  const topGap = geometry.railTop - geometry.headerBottom;
  const bottomGap = geometry.viewportHeight - geometry.railBottom;
  expect(topGap).toBeGreaterThanOrEqual(23.99);
  expect(bottomGap).toBeGreaterThanOrEqual(23.99);
  expect(Math.abs(topGap - bottomGap)).toBeLessThanOrEqual(1);
  expect(
    Math.abs(geometry.counterTop - geometry.trackBottom),
  ).toBeLessThanOrEqual(1);
  expect(
    Math.abs(geometry.counterCenter - geometry.trackCenter),
  ).toBeLessThanOrEqual(0.1);
  for (const stroke of geometry.strokes) {
    expect(stroke.width).toBe(2);
    expect(stroke.radius).toBe(1);
    expect(Math.abs(stroke.center - geometry.trackCenter)).toBeLessThanOrEqual(
      0.1,
    );
    expect(
      Math.abs(stroke.height - (geometry.trackHeight - 48)),
    ).toBeLessThanOrEqual(1);
  }
  for (const node of geometry.nodes) {
    expect(node.dotWidth).toBe(7);
    expect(node.dotHeight).toBe(7);
    expect(node.width).toBeGreaterThanOrEqual(48);
    expect(node.height).toBeGreaterThanOrEqual(48);
    expect(Math.abs(node.center - geometry.trackCenter)).toBeLessThanOrEqual(
      0.1,
    );
  }
}
async function settled(page: Page, id: string) {
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect(page.locator(`[data-rail-node="${id}"]`)).toHaveAttribute(
    'aria-current',
    'location',
  );
  await expect
    .poll(() =>
      page.evaluate((id) => {
        const el = document.querySelector<HTMLElement>(
          id === 'closing' ? '#closing' : `[data-story-stage="${id}"]`,
        )!;
        const start = Number(el.dataset.scrollReadStart),
          end = Number(el.dataset.scrollReadEnd);
        return scrollY >= start - 2 && scrollY <= end + 2;
      }, id),
    )
    .toBe(true);
}
async function jump(page: Page, id: string) {
  // Active chapter's draggable thumb intentionally occupies its current node.
  if (
    !(await page
      .locator(`[data-rail-node="${id}"]`)
      .getAttribute('aria-current'))
  )
    await page.locator(`[data-rail-node="${id}"]`).click();
  await settled(page, id);
}
async function drag(page: Page, fraction: number, release = true) {
  const thumb = await page.locator('[data-rail-thumb]').boundingBox();
  const track = await page.locator('[data-rail-track]').boundingBox();
  expect(thumb).not.toBeNull();
  expect(track).not.toBeNull();
  await page.mouse.move(thumb!.x + 24, thumb!.y + 24);
  await page.mouse.down();
  await page.mouse.move(
    track!.x + 28,
    track!.y + 24 + (track!.height - 48) * fraction,
    { steps: 15 },
  );
  if (release) await page.mouse.up();
}

for (const path of ['/', '/en/']) {
  test(`${path} rail has seven spaced targets clear logo and local hover titles`, async ({
    page,
  }) => {
    await ready(page, path);
    await expect(page.locator('[data-rail-node]')).toHaveCount(7);
    expect(
      await page
        .locator('[data-rail-node]')
        .evaluateAll((nodes) => nodes.map((node) => node.getAttribute('href'))),
    ).toEqual(ids.map((id) => `#${id}`));
    const geometry = await page.locator(railSelector).evaluate((rail) => {
      const nodes = [...rail.querySelectorAll('[data-rail-node]')].map((el) =>
        el.getBoundingClientRect(),
      );
      const symbol = rail
        .querySelector('.chapter-rail-symbol')!
        .getBoundingClientRect();
      return {
        nodes: nodes.map((r) => ({
          x: r.x,
          y: r.y,
          width: r.width,
          height: r.height,
        })),
        symbol: symbol.width,
        overflow: document.documentElement.scrollWidth - innerWidth,
        scrollbar: getComputedStyle(document.documentElement).scrollbarWidth,
      };
    });
    expect(geometry.symbol).toBe(32);
    expect(geometry.overflow).toBeLessThanOrEqual(1);
    expect(geometry.scrollbar).toBe('none');
    await expectRailProportions(page);
    for (const [i, node] of geometry.nodes.entries()) {
      expect(node.width).toBeGreaterThanOrEqual(48);
      expect(node.height).toBeGreaterThanOrEqual(48);
      if (i)
        expect(node.y - geometry.nodes[i - 1].y).toBeGreaterThanOrEqual(47.99);
    }
    const target = page.locator('[data-rail-node="download"]');
    await target.hover();
    await expect(target.locator('.chapter-rail-tooltip')).toHaveCSS(
      'opacity',
      '1',
    );
    await page.keyboard.press('Escape');
    await expect(target.locator('.chapter-rail-tooltip')).toHaveCSS(
      'opacity',
      '0',
    );
    await target.focus();
    await expect(target).toBeFocused();
    await expect(target.locator('.chapter-rail-tooltip')).toHaveCSS(
      'opacity',
      '1',
    );
    await expect(page.locator('[data-rail-counter]')).toHaveText('01');
  });
  test(`${path} chapter clicks travel on real scroll reverse and retain hash history`, async ({
    page,
  }) => {
    await ready(page, path);
    await jump(page, 'scoring');
    await jump(page, 'download');
    await expect(page).toHaveURL(/#download$/);
    await jump(page, 'community');
    await jump(page, 'closing');
    await jump(page, 'replay');
    await page.goBack();
    await settled(page, 'closing');
    const language = await page.locator('[data-language]').getAttribute('href');
    expect(language).toContain('#closing');
    await jump(page, 'hero');
    await expect(page.locator('[data-rail-counter]')).toHaveText('01');
  });
}

test('drags follow the captured pointer then snap and Escape never strands a transition', async ({
  page,
}) => {
  await ready(page);
  await drag(page, 0.47, false);
  await expect(page.locator(railSelector)).toHaveAttribute(
    'data-state',
    'dragging',
  );
  const y = await page.evaluate(() => scrollY);
  expect(y).toBeGreaterThan(100);
  await page.keyboard.press('Escape');
  await page.mouse.up();
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect(page.locator(railSelector)).toHaveAttribute(
    'data-state',
    'idle',
  );
  const current = await page
    .locator('[data-rail-node][aria-current]')
    .getAttribute('data-rail-node');
  await settled(page, current!);
  await drag(page, 0.76);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  const second = await page
    .locator('[data-rail-node][aria-current]')
    .getAttribute('data-rail-node');
  await settled(page, second!);
});

test('long content keeps its reading position and keyboard reaches all chapters', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1024, height: 768 });
  await ready(page, '/#download');
  await page.locator('.upgrade summary').click();
  await page.locator('.checksum summary').click();
  await page.waitForTimeout(350);
  const range = await page
    .locator('[data-story-stage="download"]')
    .evaluate((el) => ({
      start: Number((el as HTMLElement).dataset.scrollReadStart),
      end: Number((el as HTMLElement).dataset.scrollReadEnd),
    }));
  expect(range.end).toBeGreaterThan(range.start);
  const thumb = page.locator('[data-rail-thumb]');
  await thumb.focus();
  await page.keyboard.press('ArrowDown');
  await expect
    .poll(() => page.evaluate(() => scrollY))
    .toBeGreaterThan(range.start + 2);
  const y = await page.evaluate(() => scrollY);
  expect(y).toBeGreaterThan(range.start);
  expect(y).toBeLessThanOrEqual(range.end + 2);
  await page.keyboard.press('Home');
  await settled(page, 'hero');
  await page.keyboard.press('ArrowDown');
  await settled(page, 'scoring');
  await page.keyboard.press('End');
  await settled(page, 'closing');
});

test('fresh wheel intent on a fixed card pointer still reverses and tiny input returns', async ({
  page,
}) => {
  await ready(page);
  await jump(page, 'community');
  await page.mouse.move(420, 420);
  for (const id of ['download', 'replay', 'experience']) {
    const current = await page
      .locator('[data-rail-node][aria-current]')
      .getAttribute('data-rail-node');
    const reading = await page
      .locator(`[data-story-stage="${current}"]`)
      .evaluate((el) => ({
        start: Number((el as HTMLElement).dataset.scrollReadStart),
        end: Number((el as HTMLElement).dataset.scrollReadEnd),
      }));
    const position = await page.evaluate(() => scrollY);
    if (position > reading.start + 2) {
      // Reverse arrival can land at readEnd. Finish reading before a fresh
      // gesture asks to depart; do not skip naturally scrollable content.
      await page.mouse.wheel(0, -(position - reading.start + 12));
      await expect
        .poll(() => page.evaluate(() => scrollY))
        .toBeLessThanOrEqual(reading.start + 2);
      await page.waitForTimeout(220);
    }
    await page.mouse.wheel(0, -24);
    await settled(page, id);
    await page.waitForTimeout(200);
  }
  // Experience can also have a long natural reading range. A sub-threshold
  // wheel within that range is valid reading, so reach its start first.
  const experienceStart = await page
    .locator('[data-story-stage="experience"]')
    .evaluate((el) => Number((el as HTMLElement).dataset.scrollReadStart));
  const beforePreview = await page.evaluate(() => scrollY);
  if (beforePreview > experienceStart + 2) {
    await page.mouse.wheel(0, -(beforePreview - experienceStart + 12));
    await expect
      .poll(() => page.evaluate(() => scrollY))
      .toBeLessThanOrEqual(experienceStart + 2);
    await page.waitForTimeout(220);
  }
  const y = await page.evaluate(() => scrollY);
  await page.mouse.wheel(0, -23);
  await page.waitForTimeout(500);
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - y),
  ).toBeLessThanOrEqual(2);
});

test('resize during navigation retains the target and modal cancels pointer ownership', async ({
  page,
}) => {
  await ready(page);
  await page.locator('[data-rail-node="download"]').click();
  await page.waitForTimeout(300);
  await page.setViewportSize({ width: 1413, height: 871 });
  await settled(page, 'download');
  await page.locator('#download [data-download]').click();
  await expect(page.locator('#download-dialog')).toBeVisible();
  await expect(page.locator(railSelector)).toHaveJSProperty('inert', true);
  await page.keyboard.press('Escape');
  await expect(page.locator('#download-dialog')).not.toBeVisible();
  await expect(page.locator(railSelector)).toHaveJSProperty('inert', false);
  await jump(page, 'community');
});

test('mobile short space forced colors and privacy retain native scrolling', async ({
  page,
}) => {
  await ready(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator(railSelector)).toBeHidden();
  await expect(page.locator('html')).not.toHaveAttribute(
    'data-chapter-rail',
    'ready',
  );
  await page.setViewportSize({ width: 1440, height: 480 });
  await expect(page.locator(railSelector)).toBeHidden();
  await page.setViewportSize({ width: 1440, height: 900 });
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter-rail',
    'ready',
  );
  await page.emulateMedia({ forcedColors: 'active' });
  await expect(page.locator(railSelector)).toBeHidden();
  await page.goto('/privacy/');
  await expect(page.locator(railSelector)).toHaveCount(0);
});

test('reduced motion clicks and drags instantly without rolling or shape animation', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await ready(page);
  await jump(page, 'download');
  expect(
    await page
      .locator('[data-rail-logo]')
      .evaluate((el) => getComputedStyle(el).transform),
  ).toBe('none');
  await drag(page, 0.8);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  const current = await page
    .locator('[data-rail-node][aria-current]')
    .getAttribute('data-rail-node');
  await settled(page, current!);
});

for (const layout of [
  { name: 'compact desktop', width: 1024, height: 768, dpr: 1, large: false },
  { name: 'wide desktop', width: 1920, height: 1080, dpr: 1, large: false },
  { name: 'fractional DPR', width: 1413, height: 871, dpr: 1.5, large: false },
  { name: '200 percent text', width: 1024, height: 640, dpr: 1, large: true },
]) {
  test.describe(`rail ${layout.name}`, () => {
    test.use({
      viewport: { width: layout.width, height: layout.height },
      deviceScaleFactor: layout.dpr,
    });
    test('remains reachable without overlapping chapter content', async ({
      page,
    }, info) => {
      await ready(page, '/en/#download');
      if (layout.large) {
        await page.addStyleTag({ content: 'html {font-size:200%!important}' });
        await stableLayout(page);
      }
      const geometry = await page.evaluate(() => {
        const rail = document.querySelector<HTMLElement>(
          'aside[data-chapter-rail]',
        )!;
        const nodes = [
          ...rail.querySelectorAll<HTMLElement>('[data-rail-node]'),
        ];
        const bounds = (element: Element) =>
          element.getBoundingClientRect().toJSON();
        return {
          ready: document.documentElement.dataset.chapterRail,
          dpr: devicePixelRatio,
          overflow: document.documentElement.scrollWidth - innerWidth,
          rail: bounds(rail),
          nodes: nodes.map(bounds),
          viewport: [innerWidth, innerHeight],
          header: bounds(document.querySelector('.site-header')!),
          hidden: rail.hidden,
          rightPadding: parseFloat(
            getComputedStyle(
              document.querySelector('#download .content-width')!,
            ).paddingRight,
          ),
        };
      });
      await info.attach('rail-layout', {
        body: JSON.stringify(geometry, null, 2),
        contentType: 'application/json',
      });
      expect(geometry.dpr).toBe(layout.dpr);
      expect(geometry.overflow).toBeLessThanOrEqual(1);
      if (geometry.ready === 'ready') {
        await expectRailProportions(page);
        expect(geometry.hidden).toBe(false);
        expect(geometry.rightPadding).toBeGreaterThanOrEqual(56);
        expect(geometry.rail.top).toBeGreaterThanOrEqual(
          geometry.header.bottom + 23,
        );
        expect(geometry.rail.bottom).toBeLessThanOrEqual(layout.height - 23);
        geometry.nodes.forEach((node, i) => {
          expect(node.width).toBeGreaterThanOrEqual(48);
          expect(node.height).toBeGreaterThanOrEqual(48);
          if (i)
            expect(node.y - geometry.nodes[i - 1].y).toBeGreaterThanOrEqual(
              47.99,
            );
        });
        await jump(page, 'community');
        await jump(page, 'download');
      } else {
        // Large text can consume header space. The approved fallback restores
        // the native scrollbar rather than shrinking seven hit targets.
        expect(layout.large).toBe(true);
        expect(geometry.hidden).toBe(true);
        expect(
          await page
            .locator('html')
            .evaluate((el) => getComputedStyle(el).scrollbarWidth),
        ).not.toBe('none');
      }
    });
  });
}

test('no JavaScript and coarse pointers retain the native scroll path', async ({
  browser,
}, info) => {
  const disabled = await browser.newContext({
    baseURL: 'http://127.0.0.1:4321',
    javaScriptEnabled: false,
    viewport: { width: 1440, height: 900 },
  });
  try {
    const page = await disabled.newPage();
    // Headless Firefox reports scrollbar-width:none even on a bare native
    // document. Compare its actual baseline instead of treating that engine
    // preference as an author CSS hiding rule.
    await page.setContent(
      '<!doctype html><html><body style="height:5000px">Native scroll baseline</body></html>',
    );
    const baseline = await page
      .locator('html')
      .evaluate((el) => getComputedStyle(el).scrollbarWidth);
    await page.goto('/');
    await expect(page.locator(railSelector)).toBeHidden();
    await expect(page.locator('html')).not.toHaveAttribute(
      'data-chapter-rail',
      'ready',
    );
    const computed = await page
      .locator('html')
      .evaluate((el) => getComputedStyle(el).scrollbarWidth);
    expect(computed).toBe(baseline);
    await page.mouse.wheel(0, 160);
    await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(0);
    expect(
      await page
        .locator('html')
        .evaluate((el) => el.matches('html[data-chapter-rail="ready"]')),
    ).toBe(false);
    await info.attach('no-script-native-baseline', {
      body: JSON.stringify({
        baseline,
        computed,
        y: await page.evaluate(() => scrollY),
      }),
      contentType: 'application/json',
    });
  } finally {
    await disabled.close();
  }
  const touch = await browser.newContext({
    baseURL: 'http://127.0.0.1:4321',
    hasTouch: true,
    viewport: { width: 1440, height: 900 },
  });
  try {
    const page = await touch.newPage();
    await page.goto('/');
    await page.evaluate(() => document.fonts.ready);
    const coarse = await page.evaluate(
      () => matchMedia('(pointer: coarse)').matches,
    );
    await info.attach('coarse-pointer-capability', {
      body: JSON.stringify({ coarse }),
      contentType: 'application/json',
    });
    expect(coarse).toBe(true);
    await expect(page.locator(railSelector)).toBeHidden();
    await expect(page.locator('html')).not.toHaveAttribute(
      'data-chapter-rail',
      'ready',
    );
  } finally {
    await touch.close();
  }
});

test('drag reflow keeps pointer capture and rapid reverse navigation supersedes stale targets', async ({
  page,
}) => {
  await ready(page);
  const originalTrack = await page.locator('[data-rail-track]').boundingBox();
  const stationaryPointerY =
    originalTrack!.y + 24 + (originalTrack!.height - 48) * 0.45;
  await drag(page, 0.45, false);
  await page.setViewportSize({ width: 1413, height: 871 });
  await stableLayout(page);
  await expect(page.locator(railSelector)).toHaveAttribute(
    'data-state',
    'dragging',
  );
  await expect
    .poll(async () => {
      const box = await page.locator('[data-rail-thumb]').boundingBox();
      return Math.abs(box!.y + 24 - stationaryPointerY);
    })
    .toBeLessThanOrEqual(2);
  const track = await page.locator('[data-rail-track]').boundingBox();
  await page.mouse.move(
    track!.x + 28,
    track!.y + 24 + (track!.height - 48) * 0.8,
    { steps: 10 },
  );
  await page.mouse.up();
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  const current = await page
    .locator('[data-rail-node][aria-current]')
    .getAttribute('data-rail-node');
  await settled(page, current!);
  // No queued arrival at closing may override the newly selected scoring stop.
  await page.locator('[data-rail-node="closing"]').click();
  await page.waitForTimeout(200);
  await page.locator('[data-rail-node="scoring"]').click();
  await settled(page, 'scoring');
  await page.waitForTimeout(400);
  await settled(page, 'scoring');
});

test('waterdrop and page indicator follow actual shared scroll and finish upright', async ({
  page,
}, info) => {
  await ready(page);
  await page.evaluate(() => {
    const frames: unknown[] = [];
    const sample = () => {
      const root = document.documentElement,
        rail = document.querySelector<HTMLElement>('aside[data-chapter-rail]')!;
      frames.push({
        at: performance.now(),
        y: scrollY,
        state: root.dataset.scrollState,
        page: rail.dataset.current,
        liquid: JSON.stringify(
          [...rail.querySelectorAll('[data-rail-liquid] circle')].map(
            (circle) => [
              circle.getAttribute('cx'),
              circle.getAttribute('cy'),
              circle.getAttribute('r'),
            ],
          ),
        ),
        rotation: getComputedStyle(rail.querySelector('[data-rail-logo]')!)
          .transform,
        thumb: rail.querySelector('[data-rail-thumb]')!.getBoundingClientRect()
          .y,
      });
      if (!(window as unknown as { stopRailSample?: boolean }).stopRailSample)
        requestAnimationFrame(sample);
    };
    Object.assign(window, { railSample: frames, stopRailSample: false });
    requestAnimationFrame(sample);
  });
  await jump(page, 'scoring');
  const result = await page.evaluate(() => {
    Object.assign(window, { stopRailSample: true });
    const frames = (
      window as unknown as {
        railSample: {
          at: number;
          y: number;
          state: string;
          page: string;
          liquid: string;
          rotation: string;
          thumb: number;
        }[];
      }
    ).railSample;
    const el = document.querySelector<HTMLElement>(
      '[data-story-stage="scoring"]',
    )!;
    const stop = Number(el.dataset.scrollReadStart);
    const anchors = [...document.querySelectorAll('[data-rail-node]')].map(
      (el) => el.getBoundingClientRect().top,
    );
    return {
      frames,
      stop,
      anchors,
      rotation: getComputedStyle(document.querySelector('[data-rail-logo]')!)
        .transform,
    };
  });
  await info.attach('scroll-waterdrop-submission-samples', {
    body: JSON.stringify(result, null, 2),
    contentType: 'application/json',
  });
  const moving = result.frames.filter(
    (row) => row.y > 2 && row.y < result.stop - 2,
  );
  expect(moving.length).toBeGreaterThan(5);
  const silhouettes = new Set(moving.map((row) => row.liquid));
  expect(silhouettes.size).toBeGreaterThan(3);
  for (const row of moving) {
    const progress = row.y / result.stop;
    expect(row.rotation).toBe('none');
    // The counter is driven by scroll, never by an independent timer.
    if (progress < 0.49) expect(row.page).toBe('1');
    else if (progress > 0.51) expect(row.page).toBe('2');
    const expected =
      result.anchors[0] + (result.anchors[1] - result.anchors[0]) * progress;
    expect(Math.abs(row.thumb - expected)).toBeLessThanOrEqual(2);
  }
  expect(result.rotation).toBe('none');
});

async function nearestReadingStop(page: Page) {
  return page.evaluate(() => {
    const ranges = [
      ...document.querySelectorAll<HTMLElement>('[data-story-stage], #closing'),
    ].map((el) => ({
      id: el.dataset.storyStage ?? el.id,
      start: Number(el.dataset.scrollReadStart),
      end: Number(el.dataset.scrollReadEnd),
    }));
    return ranges
      .map((range) => ({
        ...range,
        distance: Math.abs(
          scrollY - Math.min(range.end, Math.max(range.start, scrollY)),
        ),
      }))
      .sort((a, b) => a.distance - b.distance)[0].id;
  });
}

test('Escape cancels an owned chapter flight into the nearest complete reading range', async ({
  page,
}) => {
  await ready(page);
  await page.locator('[data-rail-node="closing"]').click();
  await page.waitForTimeout(270);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  // A focused node is not required: Escape also ends a flight from the body.
  await page.locator('body').evaluate((el) => {
    (document.activeElement as HTMLElement)?.blur();
    el.focus();
  });
  const target = await nearestReadingStop(page);
  await page.keyboard.press('Escape');
  await settled(page, target);
  await page.waitForTimeout(450);
  await settled(page, target);
});

test('a thumb press below drag slop settles an interrupted flight without leaving pointer capture', async ({
  page,
}) => {
  await ready(page);
  await page.locator('[data-rail-node="closing"]').click();
  await page.waitForTimeout(230);
  // Press without waiting for a moving thumb's actionability/stability.
  const thumb = await page.locator('[data-rail-thumb]').boundingBox();
  await page.mouse.move(thumb!.x + 24, thumb!.y + 24);
  await page.mouse.down();
  const target = await nearestReadingStop(page);
  await page.mouse.up();
  await settled(page, target);
  expect(
    await page
      .locator('[data-rail-thumb]')
      .evaluate((el) => el.hasPointerCapture(1)),
  ).toBe(false);
  await expect(page.locator(railSelector)).toHaveAttribute(
    'data-state',
    'idle',
  );
});
