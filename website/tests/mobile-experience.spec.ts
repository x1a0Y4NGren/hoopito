import { expect, test, type Locator, type Page } from '@playwright/test';

const chapters = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
  'community',
  'closing',
];
const sceneChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;

async function ready(page: Page, path = '/') {
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute(
    'data-mobile-presentation',
    'ready',
  );
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
}

async function bounds(target: Locator) {
  return target.evaluate((el) => {
    const r = el.getBoundingClientRect();
    return {
      top: r.top + scrollY,
      bottom: r.bottom + scrollY,
      width: r.width,
      height: r.height,
    };
  });
}

test.use({ viewport: { width: 390, height: 844 } });

for (const path of ['/', '/en/']) {
  for (const width of [320, 390, 430]) {
    test(`${path}: ${width}px phone keeps reading and touch targets in natural flow`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 844 });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await ready(page, path);
      const layout = await page.evaluate(() => {
        const header = document.querySelector('.site-header')!;
        const court = document.querySelector('[data-demo-court-host]')!;
        const scoreboard = document.querySelector('.demo-scoreboard')!;
        return {
          overflow: document.documentElement.scrollWidth - innerWidth,
          header: header.getBoundingClientRect().height,
          court: {
            width: court.getBoundingClientRect().width,
            height: court.getBoundingClientRect().height,
          },
          scoreboard: scoreboard.getBoundingClientRect().height,
          pinSpacers: document.querySelectorAll('.pin-spacer').length,
          targets: [
            ...document.querySelectorAll<HTMLElement>(
              '.site-header button:not([hidden]), .site-header nav > a:not(.nav-story-link), [data-point-preset], [data-record], [data-reset], [data-score-feature]',
            ),
          ]
            .filter((el) => el.getClientRects().length)
            .map((el) => ({
              text: el.textContent?.trim(),
              width: el.getBoundingClientRect().width,
              height: el.getBoundingClientRect().height,
            })),
        };
      });
      expect(layout.overflow).toBeLessThanOrEqual(1);
      expect(layout.header).toBeGreaterThanOrEqual(64);
      expect(layout.court.width).toBeLessThanOrEqual(288.1);
      expect(layout.court.width / layout.court.height).toBeCloseTo(15 / 14, 2);
      expect(layout.scoreboard).toBeLessThanOrEqual(width < 360 ? 128 : 110);
      expect(layout.pinSpacers).toBe(0);
      for (const target of layout.targets) {
        expect(target.width, target.text).toBeGreaterThanOrEqual(48);
        expect(target.height, target.text).toBeGreaterThanOrEqual(48);
      }
      await expect(page.locator('[data-mobile-menu-toggle]')).toBeVisible();
      await expect(
        page.locator('[data-mobile-disclosure="history"]'),
      ).not.toHaveAttribute('open', '');
      await expect(
        page.locator('[data-mobile-disclosure="qr"]'),
      ).not.toHaveAttribute('open', '');
      const ids = await page
        .locator('[id]')
        .evaluateAll((elements) => elements.map((el) => el.id));
      expect(new Set(ids).size).toBe(ids.length);
      const scoringImage = await bounds(page.locator('.landscape-device'));
      const tabs = await bounds(page.locator('.scoring-control-slot'));
      const feedback = await bounds(page.locator('.score-preview'));
      const metadata = await bounds(page.locator('.score-caption-meta'));
      expect(tabs.top).toBeGreaterThanOrEqual(scoringImage.bottom - 1);
      expect(tabs.top - scoringImage.bottom).toBeLessThanOrEqual(24);
      expect(feedback.top).toBeGreaterThanOrEqual(tabs.bottom - 1);
      expect(metadata.top).toBeGreaterThanOrEqual(feedback.bottom - 1);
      const heading = await bounds(page.locator('.replay-introduction'));
      const summary = await bounds(page.locator('.summary-device'));
      const plot = await bounds(page.locator('.replay-analysis'));
      const history = await bounds(
        page.locator('[data-mobile-disclosure="history"]'),
      );
      expect(summary.top).toBeGreaterThan(heading.bottom);
      expect(plot.top).toBeGreaterThan(summary.bottom);
      expect(history.top).toBeGreaterThan(plot.bottom);
    });
  }

  test(`${path}: chapter menu has seven real anchors, focus containment and cancellable navigation`, async ({
    page,
  }) => {
    await ready(page, path);
    const menu = page.locator('[data-mobile-menu]');
    const opener = page.locator('[data-mobile-menu-toggle]');
    await opener.click();
    await expect(menu).toBeVisible();
    await expect(page.locator('dialog[open]')).toHaveCount(1);
    await expect(opener).toHaveAttribute('aria-expanded', 'true');
    await expect(page.locator('[data-mobile-menu-close]')).toBeFocused();
    expect(
      await menu
        .locator('a')
        .evaluateAll((elements) =>
          elements.map((el) => el.getAttribute('href')),
        ),
    ).toEqual(chapters.map((id) => `#${id}`));
    await page.keyboard.press('Shift+Tab');
    await expect(menu.locator('a').last()).toBeFocused();
    await page.keyboard.press('Tab');
    await expect(page.locator('[data-mobile-menu-close]')).toBeFocused();
    await page.keyboard.press('Escape');
    await expect(menu).not.toBeVisible();
    await expect(opener).toBeFocused();
    await opener.click();
    await page.locator('[data-mobile-menu-link="experience"]').click();
    await expect(menu).not.toBeVisible();
    await expect(page).toHaveURL(/#experience$/);
    await expect(page.locator('html')).toHaveAttribute(
      'data-scroll-stop',
      'experience',
    );
    const header = await page.locator('.site-header').boundingBox();
    await expect
      .poll(async () => (await page.locator('#experience').boundingBox())!.y)
      .toBeLessThan((header?.height ?? 64) + 30);
    await expect(opener).toHaveAttribute('aria-expanded', 'false');
  });

  test(`${path}: selection, immediate score, reset and shared screenshot dialog stay usable`, async ({
    page,
  }) => {
    await ready(page, `${path}#experience`);
    const record = page.locator('[data-record]');
    await expect(record).toBeDisabled();
    await page.locator('[data-point-preset="center"]').click();
    await expect(record).toBeEnabled();
    await expect(page.locator('[data-point-preset="center"]')).toHaveAttribute(
      'aria-pressed',
      'true',
    );
    await record.click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-red-score]')).toHaveText('6');
    await expect(page.locator('[data-demo]')).toHaveAttribute(
      'data-demo-phase',
      'shooting',
    );
    await page.locator('[data-reset]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await expect(record).toBeDisabled();
    const court = page.locator('[data-demo-court]');
    await court.click({ position: { x: 100, y: 130 } });
    await expect(record).toBeEnabled();
    await record.click();
    await expect(page.locator('[data-demo]')).toHaveAttribute(
      'data-demo-phase',
      'scored',
    );
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
    const viewer = page.locator('[data-viewer]');
    const open = page.locator('#scoring .viewer-link');
    await open.click();
    await expect(viewer).toBeVisible();
    await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
      'data-image-state',
      'ready',
    );
    await page.locator('[data-viewer-in]').click();
    await expect(page.locator('[data-viewer-scale]')).toHaveText('150%');
    await page.keyboard.press('Escape');
    await expect(open).toBeFocused();
  });
}

test('phone scoring tabs keep the real screenshot in place through selection and replay', async ({
  page,
}) => {
  await ready(page, '/#scoring');
  const screen = page.locator('.score-screen > img');
  const dimensions = await screen.evaluate((el) => ({
    width: el.getAttribute('width'),
    height: el.getAttribute('height'),
    src: el.getAttribute('src'),
  }));
  for (const index of [0, 1, 2, 1]) {
    await page.locator(`[data-score-feature="${index}"]`).click();
    await expect(
      page.locator(`[data-score-feature="${index}"]`),
    ).toHaveAttribute('aria-pressed', 'true');
    await expect(page.locator('[data-story-device]')).toHaveAttribute(
      'data-score-focus',
      String(index),
    );
    await expect(page.locator('[data-score-note]')).not.toHaveText('');
    expect(
      await screen.evaluate((el) => ({
        width: el.getAttribute('width'),
        height: el.getAttribute('height'),
        src: el.getAttribute('src'),
      })),
    ).toEqual(dimensions);
  }
  await page.locator('[data-score-feature="1"]').click();
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-playing',
    'true',
  );
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-playing',
    'false',
  );
});

test('history and QR expand in natural flow and survive phone-wide-phone layout changes', async ({
  page,
}) => {
  await ready(page, '/#replay');
  const history = page.locator('[data-mobile-disclosure="history"]');
  const qr = page.locator('[data-mobile-disclosure="qr"]');
  await history.locator('summary').click();
  await expect(history).toHaveAttribute('open', '');
  await expect(history.locator('img')).toBeVisible();
  await history.locator('summary').click();
  await expect(history).not.toHaveAttribute('open', '');
  await qr.locator('summary').click();
  await expect(qr).toHaveAttribute('open', '');
  await expect(qr.locator('img')).toBeVisible();
  await page.setViewportSize({ width: 900, height: 600 });
  await expect(history).toHaveAttribute('open', '');
  await expect(qr).toHaveAttribute('open', '');
  await expect(history.locator('summary')).not.toBeVisible();
  await expect(page.locator('[data-mobile-menu-toggle]')).not.toBeVisible();
  // Release focus before shrinking; a focused expanded disclosure must remain
  // visible instead of unexpectedly hiding the reader's keyboard location.
  await page.locator('.wordmark').focus();
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(history).not.toHaveAttribute('open', '');
  await expect(qr).toHaveAttribute('open', '');
});

test('phone backgrounds load by distance, crossfade reversibly and keep a decoded image on failure', async ({
  page,
}) => {
  const requested: string[] = [];
  page.on('request', (request) => {
    if (/scene-mobile-(?:hero|court|hoop)\.webp/.test(request.url()))
      requested.push(new URL(request.url()).pathname);
  });
  await ready(page);
  await expect(page.locator('html')).toHaveAttribute(
    'data-mobile-background',
    'ready',
  );
  expect(new Set(requested)).toEqual(new Set(['/art/scene-mobile-hero.webp']));
  const courtTitle = await bounds(page.locator('#scoring h2'));
  await page.mouse.wheel(0, 2);
  await expect
    .poll(() => requested.includes('/art/scene-mobile-court.webp'))
    .toBe(true);
  const midway = courtTitle.top - 844 * 0.5;
  await page.evaluate((top) => scrollTo({ top, behavior: 'instant' }), midway);
  const pose = () =>
    page.locator('[data-mobile-scene]').evaluateAll((els) =>
      els.map((el) => ({
        id: el.getAttribute('data-mobile-scene'),
        opacity: getComputedStyle(el).opacity,
        transform: getComputedStyle(el).transform,
      })),
    );
  await expect
    .poll(async () => Number((await pose())[1].opacity))
    .toBeGreaterThan(0.1);
  const forward = await pose();
  await page.evaluate(
    (top) => scrollTo({ top, behavior: 'instant' }),
    midway + 100,
  );
  await expect
    .poll(async () => Number((await pose())[1].opacity))
    .toBeGreaterThan(Number(forward[1].opacity));
  await page.evaluate((top) => scrollTo({ top, behavior: 'instant' }), midway);
  await expect.poll(pose).toEqual(forward);
  await page.route('**/art/scene-mobile-hoop.webp', (route) => route.abort());
  await page.locator('[data-mobile-menu-toggle]').click();
  await page.locator('[data-mobile-menu-link="download"]').click();
  await expect(page).toHaveURL(/#download$/);
  await expect(page.locator('[data-mobile-scene="court"]')).toHaveCSS(
    'opacity',
    '1',
  );
  await expect(page.locator('[data-mobile-scene="hoop"]')).toHaveJSProperty(
    'naturalWidth',
    0,
  );
});

test('deep phone anchor loads its matching plate and reduced motion removes parallax and entries', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await ready(page, '/en/#download');
  await expect(page.locator('[data-mobile-scene="hoop"]')).toHaveJSProperty(
    'naturalWidth',
    720,
  );
  await expect(page.locator('[data-mobile-scene="hoop"]')).toHaveCSS(
    'opacity',
    '1',
  );
  const transforms = await page
    .locator('[data-mobile-scene]')
    .evaluateAll((els) =>
      els.map((el) => new DOMMatrix(getComputedStyle(el).transform).m42),
    );
  expect(transforms).toEqual([0, 0, 0]);
  await expect(page.locator('.download-pass')).toHaveCSS('opacity', '1');
  expect(
    await page.locator('.download-pass').evaluate((el) => {
      const matrix = new DOMMatrix(getComputedStyle(el).transform);
      return [matrix.m11, matrix.m22, matrix.m41, matrix.m42];
    }),
  ).toEqual([1, 1, 0, 0]);
  await page.locator('#download [data-download]').click();
  await expect(page.locator('[data-download-dialog]')).toBeVisible();
  await expect(page.locator('dialog[open]')).toHaveCount(1);
  await expect(page.locator('[data-download-password] code')).toHaveText(
    'ayj6',
  );
  await page.keyboard.press('Escape');
  await expect(page.locator('#download [data-download]')).toBeFocused();
});

test('the active phone court keeps its oblique arena behind the SVG instead of a desktop loading overlay', async ({
  page,
}) => {
  await ready(page, '/#experience');
  await expect(page.locator('html')).toHaveAttribute(
    'data-mobile-background',
    'ready',
  );
  await page.locator('[data-demo-court]').scrollIntoViewIfNeeded();
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter',
    'experience',
  );
  await expect(page.locator('[data-mobile-scene="court"]')).toHaveJSProperty(
    'naturalWidth',
    720,
  );
  await expect(page.locator('[data-mobile-scene="court"]')).toHaveCSS(
    'opacity',
    '1',
  );
  await expect(page.locator('[data-demo-poster]')).toHaveCSS('display', 'none');
  await expect(page.locator('[data-demo-court]')).toBeVisible();
});

test('a failed phone hero retains the legacy poster instead of revealing an empty scene', async ({
  page,
}) => {
  await page.route('**/art/scene-mobile-hero.webp', (route) => route.abort());
  await ready(page);
  await expect
    .poll(() =>
      page
        .locator('.scene-poster img')
        .evaluate((image: HTMLImageElement) => image.currentSrc),
    )
    .toMatch(/\/art\/scene-mobile\.webp$/);
  await expect(page.locator('.scene-poster img')).toHaveJSProperty(
    'naturalWidth',
    506,
  );
  await expect(page.locator('.scene-poster')).toHaveCSS(
    'visibility',
    'visible',
  );
  await expect(page.locator('.hero-actions [data-download]')).toBeEnabled();
  await page.locator('[data-mobile-menu-toggle]').click();
  await expect(page.locator('[data-mobile-menu]')).toBeVisible();
});

test('phone menu history and language changes preserve real chapter anchors', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await ready(page, '/#scoring');
  await page.locator('[data-mobile-menu-toggle]').click();
  await page.locator('[data-mobile-menu-link="replay"]').click();
  await expect(page).toHaveURL(/#replay$/);
  await page.goBack();
  await expect(page).toHaveURL(/#scoring$/);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'scoring',
  );
  await page.goForward();
  await expect(page).toHaveURL(/#replay$/);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'replay',
  );
  const language = page.locator('[data-language]');
  await expect(language).toHaveAttribute('href', '/en/#replay');
  await language.click();
  await expect(page).toHaveURL(/\/en\/#replay$/);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'replay',
  );
  await expect(page.locator('[data-mobile-menu-toggle]')).toContainText('Menu');
});

test('large phone text and landscape keep content available without an internal scrolling stage', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await ready(page, '/en/#experience');
  await page.addStyleTag({ content: 'html{font-size:200%!important}' });
  for (const viewport of [
    { width: 320, height: 568 },
    { width: 667, height: 375 },
  ]) {
    await page.setViewportSize(viewport);
    await expect
      .poll(() =>
        page.evaluate(() => document.documentElement.scrollWidth - innerWidth),
      )
      .toBeLessThanOrEqual(1);
    const groupNumber = await page
      .locator('[data-community-number]')
      .boundingBox();
    expect(groupNumber).not.toBeNull();
    expect(groupNumber!.x).toBeGreaterThanOrEqual(15);
    expect(groupNumber!.x + groupNumber!.width).toBeLessThanOrEqual(
      viewport.width - 15,
    );
    await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
    await page.locator('[data-point-preset="center"]').click();
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await page.locator('[data-reset]').click();
    const clipping = await page
      .locator('[data-story-stage]')
      .evaluateAll((els) =>
        els
          .map((el) => {
            const s = getComputedStyle(el);
            return {
              overflow: s.overflowY,
              hidden: el.scrollHeight > el.clientHeight + 2,
            };
          })
          .filter(
            (el) => el.hidden && /hidden|clip|auto|scroll/.test(el.overflow),
          ),
      );
    expect(clipping).toEqual([]);
  }
});

test('desktop never requests phone plates and keeps disclosures and chapter rail on the existing path', async ({
  page,
}) => {
  const requests: string[] = [];
  page.on('request', (request) => {
    if (/scene-mobile-(?:hero|court|hoop)\.webp/.test(request.url()))
      requests.push(request.url());
  });
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto('/#replay');
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
  await expect(page.locator('[data-mobile-menu-toggle]')).not.toBeVisible();
  for (const kind of ['history', 'qr']) {
    const detail = page.locator(`[data-mobile-disclosure="${kind}"]`);
    await expect(detail).toHaveAttribute('open', '');
    await expect(detail.locator('summary')).not.toBeVisible();
    await expect(detail).toHaveCSS('display', 'contents');
  }
  expect(requests).toEqual([]);
  await expect(page.locator('[data-mobile-scene][src]')).toHaveCount(0);
});

test('without JavaScript the phone retains its poster, native directory and all real content', async ({
  browser,
}) => {
  const context = await browser.newContext({
    baseURL: 'http://127.0.0.1:4321',
    javaScriptEnabled: false,
    viewport: { width: 390, height: 844 },
    reducedMotion: 'reduce',
  });
  try {
    const page = await context.newPage();
    const poster = page.waitForResponse('**/art/scene-mobile-hero.webp');
    await page.goto('/');
    expect((await poster).ok()).toBe(true);
    await expect(page.locator('.scene-poster')).toBeVisible();
    const fallback = page.locator('.mobile-menu-fallback');
    await expect(fallback.locator('summary')).toBeVisible();
    await fallback.locator('summary').click();
    await expect(fallback.locator('a')).toHaveCount(7);
    await fallback.locator('a[href="#replay"]').click();
    await expect(page).toHaveURL(/#replay$/);
    await expect(
      page.locator('[data-mobile-disclosure="history"]'),
    ).toHaveAttribute('open', '');
    await expect(page.locator('[data-mobile-disclosure="qr"]')).toHaveAttribute(
      'open',
      '',
    );
    await expect(page.locator('.summary-device img')).toBeVisible();
    await expect(page.locator('.history-device img')).toBeVisible();
    await expect(page.locator('#download [data-download]')).toHaveAttribute(
      'href',
      /^https:\/\/github\.com\//,
    );
  } finally {
    await context.close();
  }
});

test('native phone touch selects the SVG court before and after a real touch scroll', async ({
  browser,
  browserName,
}, info) => {
  test.skip(
    browserName !== 'chromium',
    'Native touch-scroll injection uses Chromium CDP; shared phone controls run in all three engines.',
  );
  const context = await browser.newContext({
    baseURL: 'http://127.0.0.1:4321',
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 1,
    isMobile: true,
    hasTouch: true,
    reducedMotion: 'no-preference',
  });
  try {
    const page = await context.newPage();
    await ready(page, '/#experience');
    const session = await context.newCDPSession(page);
    const court = page.locator('[data-demo-court]');
    const record = page.locator('[data-record]');
    const reset = page.locator('[data-reset]');
    const samples: unknown[] = [];
    async function selectAt(x: number, y: number) {
      await court.scrollIntoViewIfNeeded();
      const point = await court.evaluate(
        (element, value) => {
          const svg = element as SVGSVGElement;
          const matrix = svg.getScreenCTM();
          if (!matrix)
            throw new Error('The visible court has no screen transform');
          const client = new DOMPoint(
            28 + value.x * 544,
            28 + value.y * 504,
          ).matrixTransform(matrix);
          const under = document.elementFromPoint(client.x, client.y);
          return {
            x: client.x,
            y: client.y,
            hit: !!under?.closest('[data-demo-court]'),
            header: document
              .querySelector('.site-header')!
              .getBoundingClientRect().bottom,
            viewport: innerHeight,
            scroll: scrollY,
          };
        },
        { x, y },
      );
      samples.push({ requested: { x, y }, ...point });
      expect(point.y).toBeGreaterThan(point.header + 1);
      expect(point.y).toBeLessThan(point.viewport - 1);
      expect(
        point.hit,
        'The tap must reach the real court rather than an offscreen or occluded coordinate',
      ).toBe(true);
      await page.touchscreen.tap(point.x, point.y);
      await expect(record).toBeEnabled();
      await expect(page.locator('[data-demo-selection]')).toBeVisible();
      const selection = await page
        .locator('[data-demo-selection]')
        .getAttribute('transform');
      const values = selection!.match(/[-\d.]+/g)!.map(Number);
      expect(values[0]).toBeCloseTo(28 + x * 544, -1);
      expect(values[1]).toBeCloseTo(28 + y * 504, -1);
    }
    await selectAt(0.35, 0.62);
    await record.tap();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-demo]')).toHaveAttribute(
      'data-demo-phase',
      'scored',
    );
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
    await reset.tap();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await expect(record).toBeDisabled();
    const beforeScroll = await page.evaluate(() => scrollY);
    const nativeEvents = await page.evaluateHandle(() => {
      const seen = {
        touchstart: 0,
        touchmove: 0,
        touchend: 0,
        scroll: 0,
        trusted: true,
      };
      for (const type of [
        'touchstart',
        'touchmove',
        'touchend',
        'scroll',
      ] as const) {
        window.addEventListener(
          type,
          (event) => {
            seen[type]++;
            seen.trusted &&= event.isTrusted;
          },
          { passive: true },
        );
      }
      return seen;
    });
    await session.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: [{ x: 20, y: 700, id: 1 }],
    });
    for (let step = 1; step <= 12; step++) {
      // Decelerate before lifting. A constant-speed swipe leaves compositor
      // inertia that consumes the next tap without dispatching a click, even
      // when the chapter controller already reports idle.
      const distance = 180 * (1 - (1 - step / 12) ** 3);
      await session.send('Input.dispatchTouchEvent', {
        type: 'touchMove',
        touchPoints: [{ x: 20, y: 700 - distance, id: 1 }],
      });
      await page.waitForTimeout(16);
    }
    await session.send('Input.dispatchTouchEvent', {
      type: 'touchEnd',
      touchPoints: [],
    });
    await expect
      .poll(() => page.evaluate(() => scrollY))
      .toBeGreaterThan(beforeScroll + 30);
    const afterScroll = await page.evaluate(() => scrollY);
    const events = await nativeEvents.jsonValue();
    await nativeEvents.dispose();
    expect(events.touchstart).toBe(1);
    expect(events.touchmove).toBeGreaterThan(0);
    expect(events.touchend).toBe(1);
    expect(events.scroll).toBeGreaterThan(0);
    expect(events.trusted).toBe(true);
    samples.push({
      nativeScroll: { before: beforeScroll, after: afterScroll, events },
    });
    await selectAt(0.65, 0.55);
    await record.tap();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-demo]')).toHaveAttribute(
      'data-demo-phase',
      'scored',
    );
    await reset.tap();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await info.attach('native-phone-touch-coordinates', {
      body: JSON.stringify(samples),
      contentType: 'application/json',
    });
  } finally {
    await context.close();
  }
});
