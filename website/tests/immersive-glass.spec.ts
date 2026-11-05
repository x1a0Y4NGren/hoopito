import { expect, test, type Page } from '@playwright/test';

async function requireWebGL(page: Page) {
  const available = await page.evaluate(() => {
    const context = document.createElement('canvas').getContext('webgl2', {
      failIfMajorPerformanceCaveat: true,
    });
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!context;
  });
  test.skip(
    !available,
    'This browser cannot expose the production WebGL2 path; CSS fallback is checked separately.',
  );
}

test('expanding the final FAQ refreshes its reading range without moving community', async ({
  page,
}) => {
  await page.route(/court-scene[^/]*\.js$/, (route) => route.abort());
  await page.goto('/#closing');
  await page.evaluate(() => document.fonts.ready);
  const community = page.locator('[data-story-stage="community"]');
  await expect(community).toHaveAttribute('data-story-start', /\d/);
  const before = Number(await community.getAttribute('data-story-start'));
  const closing = page.locator('#closing');
  await expect(closing).toHaveAttribute('data-scroll-read-start', /\d/);
  const end = Number(await closing.getAttribute('data-scroll-read-end'));
  for (const summary of await page.locator('#closing .faq summary').all())
    await summary.click();
  await expect
    .poll(async () =>
      Number(await closing.getAttribute('data-scroll-read-end')),
    )
    .toBeGreaterThan(end + 20);
  expect(Number(await community.getAttribute('data-story-start'))).toBeCloseTo(
    before,
    0,
  );
});

test('native disclosures refresh reading bounds even when resize delivery is delayed', async ({
  page,
}) => {
  await page.addInitScript(() => {
    const Original = ResizeObserver;
    window.ResizeObserver = class extends Original {
      constructor(callback: ResizeObserverCallback) {
        super((entries, observer) => {
          if (!Reflect.get(window, '__holdResizeDelivery'))
            callback(entries, observer);
        });
      }
    };
  });
  await page.route(/court-scene[^/]*\.js$/, (route) => route.abort());
  await page.goto('/en/#closing');
  await page.evaluate(() => document.fonts.ready);
  const closing = page.locator('#closing');
  await expect(closing).toHaveAttribute('data-scroll-read-end', /\d/);
  await page.evaluate(async () => {
    await new Promise<void>((resolve) =>
      requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
    );
    Reflect.set(window, '__holdResizeDelivery', true);
  });
  const initial = Number(await closing.getAttribute('data-scroll-read-end'));
  try {
    for (const summary of await closing.locator('.faq summary').all()) {
      await summary.focus();
      await page.keyboard.press('Enter');
      await expect(summary.locator('..')).toHaveAttribute('open', '');
    }
    await expect
      .poll(async () =>
        Number(await closing.getAttribute('data-scroll-read-end')),
      )
      .toBeGreaterThan(initial + 20);
    await expect
      .poll(() =>
        closing.evaluate((element) =>
          Math.abs(
            Number((element as HTMLElement).dataset.scrollReadEnd) -
              (document.documentElement.scrollHeight - innerHeight),
          ),
        ),
      )
      .toBeLessThanOrEqual(2);
  } finally {
    await page.evaluate(() =>
      Reflect.set(window, '__holdResizeDelivery', false),
    );
  }
});
test('@webgl interactive court accepts a pointer after its glass controls settle', async ({
  page,
}, testInfo) => {
  await requireWebGL(page);
  await page.goto('/#experience');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20000,
  });
  await expect(page.locator('html')).toHaveAttribute(
    'data-interactive',
    'true',
  );
  const court = page.locator('[data-demo-court-host]');
  const bounds = await court.boundingBox();
  await page.mouse.click(
    bounds!.x + bounds!.width * 0.5,
    bounds!.y + bounds!.height * 0.5,
  );
  await expect(page.locator('[data-record]')).toBeEnabled();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await page.locator('[data-reset]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await page.screenshot({ path: testInfo.outputPath('experience.png') });
});

for (const path of ['/', '/en/']) {
  test(
    path +
      ': continuous court fills the viewport and CSS glass survives unavailable WebGL',
    async ({ page }) => {
      await page.route(/court-scene[^/]*\.js$/, (route) => route.abort());
      await page.goto(path);
      const canvas = page.locator('#court-canvas');
      const size = await canvas.boundingBox();
      expect(size!.x).toBe(0);
      expect(size!.width).toBeGreaterThanOrEqual(1440 - 20);
      expect(size!.width).toBeLessThanOrEqual(1440);
      await expect(page.locator('[data-glass-card]').first()).toBeVisible();
      await page.goto(path + '#community');
      await expect(page.locator('#community')).toBeInViewport();
      await expect(
        page.locator('#community [data-glass-card]').first(),
      ).toBeVisible();
      await expect(page.locator('html')).toHaveAttribute('data-glass', 'css');
    },
  );
}
test('@webgl court and refracting surfaces stay alive through download and community', async ({
  page,
}, testInfo) => {
  await requireWebGL(page);
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20000,
  });
  await expect(page.locator('html')).toHaveAttribute('data-glass', /webgl|css/);
  await expect(page.locator('#court-canvas')).toHaveAttribute(
    'data-rendering',
    'ambient',
  );
  await page.screenshot({ path: testInfo.outputPath('hero.png') });
  for (const chapter of ['download', 'community']) {
    await page.goto('/#' + chapter);
    await expect(page.locator('html')).toHaveAttribute('data-chapter', chapter);
    await expect(page.locator('#court-canvas')).not.toHaveAttribute(
      'data-rendering',
      'off',
    );
    await expect(
      page.locator('#' + chapter + ' [data-glass-card]').first(),
    ).toBeVisible();
    await expect(
      page.locator('#' + chapter + ' [data-glass-card]').first(),
    ).toHaveCSS('opacity', '1');
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-rendering',
      'ambient',
    );
    await page.screenshot({ path: testInfo.outputPath(chapter + '.png') });
  }
  await testInfo.attach('runtime', {
    body: JSON.stringify(
      await page.evaluate(() => ({
        root: { ...document.documentElement.dataset },
        canvas: {
          ...(document.querySelector('#court-canvas') as HTMLCanvasElement)
            .dataset,
        },
      })),
      null,
      2,
    ),
    contentType: 'application/json',
  });
  await page.goto('/en/');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20000,
  });
  await expect(page.locator('#court-canvas')).toHaveAttribute(
    'data-rendering',
    'ambient',
  );
  await page.screenshot({ path: testInfo.outputPath('hero-en.png') });
});

test('@webgl scroll synchronizes optical contours and omits them for CSS quality', async ({
  page,
}, testInfo) => {
  await requireWebGL(page);
  await page.route(/court-scene[^/]*\.js$/, async (route) => {
    const response = await route.fetch();
    let body = await response.text();
    const exports = body.match(/export\s*\{([^}]*\bcreateCourtScene\b[^}]*)\}/);
    const factory = exports?.[1].match(
      /(?:^|,)\s*([\w$]+)\s+as\s+createCourtScene\b/,
    )?.[1];
    if (!exports || !factory)
      throw new Error('Observe the real scene factory.');
    body = body.replace(
      exports[0],
      exports[0].replace(
        /[\w$]+\s+as\s+createCourtScene\b/,
        '__glassFrameCreate as createCourtScene',
      ),
    );
    body += `\nasync function __glassFrameCreate(...args) {
      const scene = await ${factory}(...args);
      let surfaces = [];
      const frames = [];
      Reflect.set(window, '__glassFrames', frames);
      const set = scene.setGlassSurfaces.bind(scene);
      scene.setGlassSurfaces = (value) => { surfaces = structuredClone(value); set(value); };
      const flush = scene.flushFrame.bind(scene);
      scene.flushFrame = () => {
        const before = Number(args[0].dataset.renderCount);
        flush();
        frames.push({
          drew: Number(args[0].dataset.renderCount) > before,
          quality: args[0].dataset.quality,
          glass: args[0].dataset.glass,
          surfaces: surfaces.map(surface => {
            const element = [...document.querySelectorAll('[data-glass-id]')].find(card => card.dataset.glassId === surface.id);
            const bounds = element.getBoundingClientRect();
            return { id: surface.id, error: Math.max(...['left','top','width','height'].map(key => Math.abs(bounds[key] - surface.region[key]))) };
          }),
        });
      };
      return scene;
    }`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
  await page.goto('/#experience');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20000,
  });
  await expect(page.locator('html')).toHaveAttribute(
    'data-interactive',
    'true',
    { timeout: 20000 },
  );
  await page.evaluate(() => document.fonts.ready);
  await page.keyboard.press('Escape');
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  // A long reading range consumes its first gesture without changing chapters.
  // Begin this optical transition check at the measured outward boundary.
  await page.locator('[data-story-stage="experience"]').evaluate((stage) =>
    window.scrollTo({
      top: Number((stage as HTMLElement).dataset.scrollReadEnd),
      behavior: 'instant',
    }),
  );
  await expect
    .poll(() =>
      page
        .locator('[data-story-stage="experience"]')
        .evaluate((stage) =>
          Math.abs(
            scrollY - Number((stage as HTMLElement).dataset.scrollReadEnd),
          ),
        ),
    )
    .toBeLessThan(2);
  await page.mouse.move(12, 450);
  // Animation-time input is deliberately drained, so finish each owned flight
  // before asking the real wheel sequence to reverse its optical motion.
  await page.mouse.wheel(0, 240);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'replay',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await page.mouse.wheel(0, -180);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'experience',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect
    .poll(() =>
      page.evaluate(() => {
        const frames = Reflect.get(window, '__glassFrames') as
          { drew: boolean; surfaces: { error: number }[] }[] | undefined;
        return frames?.filter((frame) => frame.drew).length ?? 0;
      }),
    )
    .toBeGreaterThan(2);
  const frames = await page.evaluate(() =>
    (
      Reflect.get(window, '__glassFrames') as {
        drew: boolean;
        quality: string;
        glass: string;
        surfaces: { error: number }[];
      }[]
    ).filter((frame) => frame.drew),
  );
  const optical = frames.filter(
    (frame) => frame.quality === 'full' && frame.glass === 'webgl',
  );
  for (const frame of frames)
    expect(frame.surfaces.length).toBeLessThanOrEqual(6);
  await testInfo.attach('optical-quality-frames', {
    body: JSON.stringify(frames),
    contentType: 'application/json',
  });
  if (optical.length) {
    expect(
      optical.filter((frame) => frame.surfaces.length).length,
    ).toBeGreaterThan(2);
    const errors = optical.flatMap((frame) =>
      frame.surfaces.map((surface) => surface.error),
    );
    expect(Math.max(...errors)).toBeLessThan(0.1);
  } else {
    testInfo.annotations.push({
      type: 'capability',
      description:
        'The court rendered with CSS optics; this run does not establish full WebGL optical contour coverage.',
    });
  }
  for (const frame of frames.filter((frame) => frame.quality !== 'full'))
    expect(frame.surfaces).toHaveLength(0);
});

test('mobile scoreboard and action dock retain independently measurable glass surfaces', async ({
  page,
}, testInfo) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/#experience');
  const panel = page.locator('[data-glass-id="experience-controls"]');
  const bounds = await panel.boundingBox();
  expect(bounds!.width).toBeGreaterThan(300);
  expect(bounds!.height).toBeGreaterThan(100);
  const scoreboard = page.locator('[data-glass-id="experience-scoreboard"]');
  const scoreboardBounds = await scoreboard.boundingBox();
  expect(scoreboardBounds!.width).toBeGreaterThan(300);
  // The approved phone layout compacts the scoreboard to about 80px while
  // retaining a separate full-width optical region above the court.
  expect(scoreboardBounds!.height).toBeGreaterThanOrEqual(80);
  expect(scoreboardBounds!.height).toBeLessThanOrEqual(100);
  expect(
    await panel.evaluate((item) => item.scrollHeight <= item.clientHeight + 1),
  ).toBe(true);
  const layout = await panel.evaluate((item) => {
    const presets = item
      .querySelector('.point-presets')!
      .getBoundingClientRect();
    const actions = item
      .querySelector('.demo-actions')!
      .getBoundingClientRect();
    const notes = item
      .querySelector('.demo-control-notes')!
      .getBoundingClientRect();
    return {
      presetsBottom: presets.bottom,
      actionsTop: actions.top,
      actionsBottom: actions.bottom,
      notesTop: notes.top,
    };
  });
  expect(layout.actionsTop).toBeGreaterThanOrEqual(layout.presetsBottom);
  expect(layout.notesTop).toBeGreaterThanOrEqual(layout.actionsBottom);
  await page.locator('[data-point-preset="center"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await page.screenshot({
    path: testInfo.outputPath('mobile-experience.png'),
    fullPage: false,
  });
});
