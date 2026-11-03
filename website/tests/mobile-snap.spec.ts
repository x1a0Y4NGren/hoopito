import { expect, test, type Page } from '@playwright/test';

test.use({ viewport: { width: 390, height: 844 }, hasTouch: true });
async function ready(page: Page, path = '/') {
  await page.route(/court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/, (r) =>
    r.abort(),
  );
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute(
    'data-mobile-progress-state',
    'ready',
  );
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
  await expect
    .poll(() =>
      page.evaluate(() => document.documentElement.dataset.scrollState),
    )
    .toBe('idle');
  await page.waitForTimeout(180);
}
async function ranges(page: Page) {
  return page.locator('[data-story-stage],#closing').evaluateAll((nodes) =>
    nodes.map((node) => ({
      id: (node as HTMLElement).dataset.storyStage ?? node.id,
      start: Number((node as HTMLElement).dataset.scrollReadStart),
      end: Number((node as HTMLElement).dataset.scrollReadEnd),
    })),
  );
}
async function seek(page: Page, id: string, edge: 'start' | 'end' = 'start') {
  const range = (await ranges(page)).find((range) => range.id === id)!;
  await page.evaluate(
    (y) => scrollTo({ top: y, behavior: 'instant' }),
    range[edge],
  );
  await page.waitForTimeout(170);
  return range;
}
async function sequence(
  page: Page,
  delta: number,
  target = '.hero-actions-panel',
  options: { dx?: number; cancel?: boolean } = {},
) {
  // Standard DOM touch events exercise cancellation/ownership in every engine;
  // the separate Chromium case below verifies actual compositor touch panning.
  await page.locator(target).evaluate(
    (element, { delta, dx, cancel }) => {
      const point = (x: number, y: number) => ({
        identifier: 9,
        clientX: x,
        clientY: y,
        pageX: x,
        pageY: y + scrollY,
        target: element,
      });
      const emit = (type: string, points: ReturnType<typeof point>[]) => {
        const e = new Event(type, { bubbles: true, cancelable: true });
        Object.defineProperties(e, {
          touches: { value: points },
          targetTouches: { value: points },
          changedTouches: {
            value: points.length
              ? points
              : [point(150 + (dx ?? 0), 400 - delta)],
          },
        });
        element.dispatchEvent(e);
      };
      emit('touchstart', [point(150, 400)]);
      emit('touchmove', [point(150 + (dx ?? 0), 400 - delta)]);
      emit(cancel ? 'touchcancel' : 'touchend', []);
    },
    { delta, ...options },
  );
}
async function landed(page: Page, id: string) {
  await expect(page.locator('html')).toHaveAttribute('data-scroll-stop', id);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect
    .poll(async () => {
      const r = (await ranges(page)).find((r) => r.id === id)!;
      const y = await page.evaluate(() => scrollY);
      return Math.max(r.start - y, y - r.end, 0);
    })
    .toBeLessThanOrEqual(2);
}

for (const locale of ['/', '/en/']) {
  test(`${locale}: 23px returns and24px settles one adjacent chapter with continuous progress`, async ({
    page,
  }) => {
    await ready(page, locale);
    await sequence(page, 23);
    await landed(page, 'hero');
    expect(await page.evaluate(() => scrollY)).toBeLessThanOrEqual(2);
    await sequence(page, 24);
    await landed(page, 'scoring');
    await expect(page.locator('[data-mobile-page]')).toHaveText('02 / 07');
    const progress = Number(
      await page
        .locator('[data-mobile-progress]')
        .getAttribute('aria-valuenow'),
    );
    expect(progress).toBeGreaterThan(0);
    expect(progress).toBeLessThan(100);
    await seek(page, 'scoring');
    await sequence(page, -60, '.score-controls');
    await landed(page, 'hero');
  });
}

test('a long reading gesture stops at its boundary and needs a fresh outward gesture', async ({
  page,
}) => {
  await ready(page, '/#replay');
  const r = await seek(page, 'replay');
  expect(r.end - r.start).toBeGreaterThan(200);
  await page.evaluate(
    (y) => scrollTo({ top: y, behavior: 'instant' }),
    r.start + 70,
  );
  await page.waitForTimeout(100);
  await page.locator('.replay-analysis').evaluate((el) => {
    const e = new Event('touchstart', { bubbles: true, cancelable: true });
    Object.defineProperty(e, 'touches', {
      value: [{ identifier: 1, clientX: 180, clientY: 450 }],
    });
    el.dispatchEvent(e);
    const move = new Event('touchmove', { bubbles: true, cancelable: true });
    Object.defineProperty(move, 'touches', {
      value: [{ identifier: 1, clientX: 180, clientY: 350 }],
    });
    el.dispatchEvent(move);
  });
  await page.evaluate(
    (y) => scrollTo({ top: y, behavior: 'instant' }),
    r.end + 500,
  );
  await expect
    .poll(() => page.evaluate(() => scrollY))
    .toBeLessThanOrEqual(r.end + 2);
  await page.locator('.replay-analysis').evaluate((el) => {
    const e = new Event('touchend', { bubbles: true, cancelable: true });
    Object.defineProperty(e, 'touches', { value: [] });
    el.dispatchEvent(e);
  });
  await landed(page, 'replay');
  await page.waitForTimeout(220);
  await sequence(page, 70, '.replay-analysis');
  await landed(page, 'download');
});

test('horizontal movement, cancelled touch and a plain tap never flip a chapter', async ({
  page,
}) => {
  await ready(page);
  await sequence(page, 40, '.hero-actions-panel', { dx: 80 });
  await landed(page, 'hero');
  await sequence(page, 90, '.hero-actions-panel', { cancel: true });
  await landed(page, 'hero');
  await sequence(page, 4);
  await landed(page, 'hero');
  await page.locator('.hero-actions [data-download]').click();
  await expect(page.locator('[data-download-dialog]')).toBeVisible();
  await page.keyboard.press('Escape');
  await landed(page, 'hero');
});

test('menu navigation supersedes a swipe and expanded content remains reachable', async ({
  page,
}) => {
  await ready(page);
  await sequence(page, 60);
  await page.waitForTimeout(240);
  await page.locator('[data-mobile-menu-toggle]').click();
  await page.locator('[data-mobile-menu-link="download"]').click();
  await landed(page, 'download');
  const before = (await ranges(page)).find((r) => r.id === 'download')!;
  await page.locator('.upgrade summary').click();
  await expect
    .poll(
      async () => (await ranges(page)).find((r) => r.id === 'download')!.end,
    )
    .toBeGreaterThan(before.end + 20);
  await seek(page, 'download', 'end');
  const foot = await page.locator('.upgrade p').boundingBox();
  expect(foot!.y + foot!.height).toBeLessThanOrEqual(844);
  await sequence(page, 60, '.download-pass');
  await landed(page, 'community');
});

test('reflow during the committed transition retains the selected target', async ({
  page,
}) => {
  await ready(page);
  await sequence(page, 70);
  await page.waitForTimeout(350);
  await page.setViewportSize({ width: 360, height: 740 });
  await landed(page, 'scoring');
  await expect(page.locator('[data-mobile-page]')).toHaveText('02 / 07');
});

test('a fresh tap during a flight recovers to a reading stop and a following swipe still works', async ({
  page,
}) => {
  await ready(page);
  await sequence(page, 70);
  await page.waitForTimeout(180);
  await sequence(page, 0);
  await landed(page, 'hero');
  await sequence(page, 70);
  await landed(page, 'scoring');
  await expect(page.locator('html')).toHaveAttribute(
    'data-mobile-touch',
    'ready',
  );
});

test('a second finger cancels the preview and internal readers retain native scroll ownership', async ({
  page,
}) => {
  await ready(page);
  await page.locator('.hero-actions-panel').evaluate((el) => {
    const emit = (type: string, touches: unknown[]) => {
      const event = new Event(type, { bubbles: true, cancelable: true });
      Object.defineProperty(event, 'touches', { value: touches });
      el.dispatchEvent(event);
    };
    const first = { identifier: 1, clientX: 150, clientY: 500 };
    emit('touchstart', [first]);
    emit('touchmove', [{ ...first, clientY: 470 }]);
    emit('touchstart', [
      { ...first, clientY: 470 },
      { identifier: 2, clientX: 220, clientY: 430 },
    ]);
    emit('touchend', []);
  });
  await landed(page, 'hero');
  await page.evaluate(() => {
    const reader = document.createElement('div');
    reader.id = 'nested-test-reader';
    reader.style.cssText =
      'position:fixed;left:40px;top:200px;width:240px;height:100px;overflow-y:auto;z-index:5';
    const content = document.createElement('p');
    content.style.height = '500px';
    content.textContent = 'Scrollable notes';
    reader.append(content);
    document.body.append(reader);
  });
  await sequence(page, 80, '#nested-test-reader');
  await landed(page, 'hero');
  await page.locator('#nested-test-reader').evaluate((el) => el.remove());
  await sequence(page, 70);
  await landed(page, 'scoring');
});

test('closing the menu after interrupting a flight recovers without requiring another swipe', async ({
  page,
}) => {
  await ready(page);
  await sequence(page, 70);
  await page.waitForTimeout(250);
  await page.locator('[data-mobile-menu-toggle]').click();
  await expect(page.locator('[data-mobile-menu]')).toBeVisible();
  await page.keyboard.press('Escape');
  await expect(page.locator('[data-mobile-menu]')).not.toBeVisible();
  await expect
    .poll(async () => {
      const all = await ranges(page),
        y = await page.evaluate(() => scrollY);
      return Math.min(...all.map((r) => Math.max(r.start - y, y - r.end, 0)));
    })
    .toBeLessThanOrEqual(2);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
});

test('a multi-finger interruption of a committed flight releases to a reading boundary', async ({
  page,
}) => {
  await ready(page);
  await sequence(page, 70);
  await page.waitForTimeout(200);
  await page.locator('.hero-actions-panel').evaluate((el) => {
    for (const [type, touches] of [
      [
        'touchstart',
        [
          { identifier: 1, clientX: 160, clientY: 400 },
          { identifier: 2, clientX: 210, clientY: 420 },
        ],
      ],
      ['touchend', []],
    ] as const) {
      const event = new Event(type, { bubbles: true, cancelable: true });
      Object.defineProperty(event, 'touches', { value: touches });
      el.dispatchEvent(event);
    }
  });
  await expect
    .poll(async () => {
      const all = await ranges(page),
        y = await page.evaluate(() => scrollY);
      return Math.min(...all.map((r) => Math.max(r.start - y, y - r.end, 0)));
    })
    .toBeLessThanOrEqual(2);
  await expect(page.locator('html')).toHaveAttribute(
    'data-mobile-touch',
    'ready',
  );
});

test('320px large text and reduced motion retain navigation, readable content and full progress endpoints', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.setViewportSize({ width: 320, height: 568 });
  await ready(page, '/en/');
  await page.addStyleTag({ content: 'html{font-size:200%!important}' });
  await page.waitForTimeout(300);
  await sequence(page, 80);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'hero',
  );
  await page.locator('[data-mobile-menu-toggle]').click();
  await page.locator('[data-mobile-menu-link="closing"]').click();
  await landed(page, 'closing');
  await page.evaluate(() =>
    scrollTo({
      top: document.documentElement.scrollHeight,
      behavior: 'instant',
    }),
  );
  await expect(page.locator('[data-mobile-progress]')).toHaveAttribute(
    'aria-valuenow',
    '100',
  );
  const last = (await ranges(page)).find((r) => r.id === 'closing')!;
  const maximum = await page.evaluate(
    () => document.documentElement.scrollHeight - innerHeight,
  );
  expect(Math.abs(last.end - maximum)).toBeLessThanOrEqual(1);
  await expect(page.locator('[data-mobile-page]')).toHaveText('07 / 07');
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth - innerWidth,
    ),
  ).toBeLessThanOrEqual(1);
});

test('native finger swipes flip once, read long content and leave court taps usable', async ({
  browser,
  browserName,
}, info) => {
  test.skip(
    browserName !== 'chromium',
    'Real compositor touch injection uses CDP; other engines use DOM ownership regressions.',
  );
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    hasTouch: true,
    isMobile: true,
  });
  const page = await context.newPage();
  const cdp = await context.newCDPSession(page);
  async function swipe(delta: number, x = 170, start = 520) {
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: [{ x, y: start, id: 1 }],
    });
    for (let i = 1; i <= 10; i++) {
      await cdp.send('Input.dispatchTouchEvent', {
        type: 'touchMove',
        touchPoints: [{ x, y: start - (delta * i) / 10, id: 1 }],
      });
      await page.waitForTimeout(22);
    }
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchEnd',
      touchPoints: [],
    });
  }
  try {
    await ready(page, 'http://127.0.0.1:4321/');
    await swipe(70);
    await landed(page, 'scoring');
    const r = (await ranges(page)).find((r) => r.id === 'scoring')!;
    if (r.end - r.start > 2) {
      await swipe(350, 180, 650);
      await landed(page, 'scoring');
    }
    await swipe(70);
    await landed(page, 'experience');
    await page.locator('[data-demo-court]').scrollIntoViewIfNeeded();
    const point = await page
      .locator('[data-demo-court]')
      .evaluate((el) =>
        new DOMPoint(28 + 0.4 * 544, 28 + 0.55 * 504)
          .matrixTransform((el as SVGSVGElement).getScreenCTM()!)
          .toJSON(),
      );
    await page.touchscreen.tap(point.x, point.y);
    await expect(page.locator('[data-record]')).toBeEnabled();
    await page.locator('[data-record]').tap();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-demo]')).toHaveAttribute(
      'data-demo-phase',
      'scored',
    );
    await page.locator('[data-reset]').tap();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await page.locator('[data-mobile-menu-toggle]').tap();
    await page.locator('[data-mobile-menu-link="closing"]').tap();
    await landed(page, 'closing');
    for (let i = 0; i < 5; i++) {
      const last = (await ranges(page)).find((r) => r.id === 'closing')!;
      const y = await page.evaluate(() => scrollY);
      if (last.end - y <= 2) break;
      await swipe(Math.min(350, last.end - y + 25), 170, 650);
      await expect(page.locator('html')).toHaveAttribute(
        'data-scroll-state',
        'idle',
      );
    }
    await expect(page.locator('[data-mobile-progress]')).toHaveAttribute(
      'aria-valuenow',
      '100',
    );
    await info.attach('native-touch-state', {
      body: JSON.stringify(await ranges(page)),
      contentType: 'application/json',
    });
  } finally {
    await context.close();
  }
});
