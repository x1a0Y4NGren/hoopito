import { expect, test, type Page, type TestInfo } from '@playwright/test';

const sceneChunk = /court-scene[^/]*\.(?:js|ts)(?:\?|$)/;
const chapters = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
  'community',
] as const;
type Chapter = (typeof chapters)[number];
const stageSelector = (chapter: Chapter) => `[data-story-stage="${chapter}"]`;

test('@webgl duplicate native scroll notifications do not redraw an unchanged idle scene', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  const available = await page.evaluate(() => {
    const context = document
      .createElement('canvas')
      .getContext('webgl2', { failIfMajorPerformanceCaveat: true });
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!context;
  });
  test.skip(!available, 'Production WebGL2 is unavailable in this browser.');
  await open(page, '/#experience', { css: false });
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20000,
  });
  const canvas = page.locator('#court-canvas');
  await expect(canvas).toHaveAttribute('data-rendering', 'idle');
  // Wait for font/image layout refresh to finish before sending notifications.
  await expect
    .poll(async () => {
      const before = await canvas.getAttribute('data-render-count');
      await page.waitForTimeout(250);
      return (await canvas.getAttribute('data-render-count')) === before;
    })
    .toBe(true);
  const extraDraws = await page.evaluate(async () => {
    const canvas = document.querySelector<HTMLCanvasElement>('#court-canvas')!;
    const before = Number(canvas.dataset.renderCount);
    for (let i = 0; i < 10; i++) {
      window.dispatchEvent(new Event('scroll'));
      await new Promise(requestAnimationFrame);
      await new Promise(requestAnimationFrame);
    }
    return Number(canvas.dataset.renderCount) - before;
  });
  expect(extraDraws).toBe(0);
});

async function readRange(page: Page, chapter: Chapter) {
  const stage = page.locator(stageSelector(chapter));
  await expect(stage).toHaveAttribute('data-scroll-read-start', /\d/);
  return stage.evaluate((element) => ({
    start: Number((element as HTMLElement).dataset.scrollReadStart),
    end: Number((element as HTMLElement).dataset.scrollReadEnd),
  }));
}

async function atReading(page: Page, chapter: Chapter) {
  await expect
    .poll(async () => {
      const range = await readRange(page, chapter);
      return page.evaluate(({ start, end }) => {
        return (
          scrollY >= start - 2 &&
          scrollY <= end + 2 &&
          document.documentElement.dataset.scrollState === 'idle'
        );
      }, range);
    })
    .toBe(true);
  await expect
    .poll(() =>
      page
        .locator(stageSelector(chapter))
        .evaluate((stage) =>
          [...stage.querySelectorAll<HTMLElement>('[data-story-item]')].every(
            (item) => Number(getComputedStyle(item).opacity) >= 0.999,
          ),
        ),
    )
    .toBe(true);
}

async function open(
  page: Page,
  path = '/#hero',
  options: { css?: boolean } = {},
) {
  if (options.css !== false)
    await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('#closing')).toHaveAttribute(
    'data-scroll-read-start',
    /\d/,
  );
}

async function seekReading(
  page: Page,
  chapter: Chapter,
  edge: 'start' | 'end' = 'start',
) {
  await page.mouse.click(8, 450);
  // This is scrollbar-like test preparation, not the transition under test.
  // Fonts/text resizing may invalidate a previously read layout before its RAF.
  await expect
    .poll(async () => {
      const bounds = await readRange(page, chapter);
      await page.evaluate(async (top) => {
        scrollTo({ top, behavior: 'instant' });
        await new Promise(requestAnimationFrame);
        await new Promise(requestAnimationFrame);
      }, bounds[edge]);
      const current = await readRange(page, chapter);
      return page.evaluate(
        (top) => Math.abs(scrollY - top) <= 2,
        current[edge],
      );
    })
    .toBe(true);
  await atReading(page, chapter);
  await page.mouse.move(12, 450);
}

async function evidence(page: Page, testInfo: TestInfo, name: string) {
  await page.screenshot({ path: testInfo.outputPath(name + '.png') });
  await testInfo.attach(name + '-state', {
    body: JSON.stringify(
      await page.evaluate(() => ({
        y: scrollY,
        root: { ...document.documentElement.dataset },
        stages: [
          ...document.querySelectorAll<HTMLElement>('[data-story-stage]'),
        ].map((stage) => ({ ...stage.dataset })),
      })),
      null,
      2,
    ),
    contentType: 'application/json',
  });
}

async function measuredHeader(page: Page) {
  await expect
    .poll(() =>
      page.evaluate(() => {
        const actual = document
          .querySelector('.site-header')!
          .getBoundingClientRect().height;
        const measured = parseFloat(
          getComputedStyle(document.documentElement).getPropertyValue(
            '--measured-header',
          ),
        );
        return Math.abs(actual - measured);
      }),
    )
    .toBeLessThanOrEqual(1);
}

const readingLayouts = [
  { name: 'compact', width: 1024, height: 768 },
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'annotated', width: 1728, height: 942 },
  { name: 'wide', width: 1920, height: 1080 },
  { name: 'short', width: 1440, height: 600 },
  { name: 'large text', width: 1024, height: 640, textScale: 2 },
] as const;

for (const path of ['/', '/en/']) {
  for (const layout of readingLayouts) {
    test(`${path}: ${layout.name} scoring balance and replay copy remain clear throughout reading`, async ({
      page,
    }, testInfo) => {
      await page.setViewportSize(layout);
      await open(page, `${path}#scoring`);
      if ('textScale' in layout) {
        const beforeScale = await readRange(page, 'scoring');
        await page.evaluate((scale) => {
          document.documentElement.style.fontSize = `${scale * 100}%`;
        }, layout.textScale);
        // Font scaling changes actual layout before the debounced observer has
        // published its new reading coordinates. Do not seek the old range.
        await expect
          .poll(async () => (await readRange(page, 'scoring')).start)
          .not.toBe(beforeScale.start);
        let previousLayout = '';
        let stableSince = 0;
        await expect
          .poll(async () => {
            const current = await page.evaluate(() => {
              const stage = document.querySelector<HTMLElement>(
                '[data-story-stage="scoring"]',
              )!;
              return JSON.stringify({
                start: stage.dataset.storyStart,
                end: stage.dataset.storyEnd,
                readStart: stage.dataset.scrollReadStart,
                readEnd: stage.dataset.scrollReadEnd,
                height: document.documentElement.scrollHeight,
                header: document
                  .querySelector('.site-header')!
                  .getBoundingClientRect().height,
                measuredHeader: getComputedStyle(
                  document.documentElement,
                ).getPropertyValue('--measured-header'),
              });
            });
            if (current !== previousLayout) {
              previousLayout = current;
              stableSince = Date.now();
            }
            // A second refresh may follow the header measurement. Observe a
            // quiet layout interval rather than sleeping or trusting its first
            // intermediate coordinates, then begin geometry assertions.
            return Date.now() - stableSince >= 200;
          })
          .toBe(true);
      }
      await measuredHeader(page);
      const samples = [];
      for (const chapter of ['scoring', 'replay'] as const) {
        for (const fraction of [0, 0.5, 1]) {
          await page.mouse.click(8, 450);
          // Scrollbar-like positioning samples the real reading interval. It
          // does not inject a second animation progress or bypass remeasurement.
          await expect
            .poll(async () => {
              const range = await readRange(page, chapter);
              await page.evaluate(
                async (position) => {
                  scrollTo({ top: position, behavior: 'instant' });
                  await new Promise(requestAnimationFrame);
                  await new Promise(requestAnimationFrame);
                },
                range.start + (range.end - range.start) * fraction,
              );
              const current = await readRange(page, chapter);
              return page.evaluate(
                ({ start, end, fraction }) =>
                  Math.abs(scrollY - (start + (end - start) * fraction)) <= 2 &&
                  document.documentElement.dataset.scrollState === 'idle',
                { ...current, fraction },
              );
            })
            .toBe(true);
          await atReading(page, chapter);

          await expect
            .poll(() =>
              page
                .locator(
                  chapter === 'scoring'
                    ? '.landscape-device img'
                    : '[data-replay-device="summary"] img',
                )
                .evaluate(
                  (image: HTMLImageElement) =>
                    image.complete && image.naturalWidth > 0,
                ),
            )
            .toBe(true);

          const reading = await page
            .locator(stageSelector(chapter))
            .evaluate((stage, chapter) => {
              const rect = (element: Element) => {
                const r = element.getBoundingClientRect();
                return {
                  left: r.left,
                  top: r.top,
                  right: r.right,
                  bottom: r.bottom,
                  width: r.width,
                  height: r.height,
                };
              };
              const intersects = (
                a: ReturnType<typeof rect>,
                b: ReturnType<typeof rect>,
              ) =>
                Math.min(a.right, b.right) - Math.max(a.left, b.left) > 1 &&
                Math.min(a.bottom, b.bottom) - Math.max(a.top, b.top) > 1;
              const introduction = stage.querySelector(
                chapter === 'scoring'
                  ? '.section-intro'
                  : '.replay-introduction',
              )!;
              const surfaces = [
                ...stage.querySelectorAll<HTMLElement>('[data-glass-card]'),
              ];
              const copy = [
                ...introduction.querySelectorAll<HTMLElement>('h2, p'),
              ];
              const collisions = copy.flatMap((text) =>
                surfaces.flatMap((surface) =>
                  intersects(rect(text), rect(surface))
                    ? [
                        {
                          text: text.textContent?.trim(),
                          surface: surface.dataset.glassId,
                        },
                      ]
                    : [],
                ),
              );
              const image = stage.querySelector<HTMLImageElement>(
                chapter === 'scoring'
                  ? '.landscape-device img'
                  : '[data-replay-device="summary"] img',
              )!;
              const imageRect = rect(image);
              const introRect = rect(introduction);
              const controls = stage.querySelector('.scoring-control-slot');
              const buttons = [
                ...stage.querySelectorAll<HTMLButtonElement>(
                  '[data-score-feature]',
                ),
              ];
              return {
                chapter,
                y: scrollY,
                collisions,
                intro: introRect,
                controls: controls ? rect(controls) : null,
                screen: imageRect,
                imageAspect: imageRect.width / imageRect.height,
                naturalAspect: image.naturalWidth / image.naturalHeight,
                buttons: buttons.map(rect),
                headerBottom: document
                  .querySelector('.site-header')!
                  .getBoundingClientRect().bottom,
                viewportHeight: innerHeight,
                overflow: Math.max(
                  0,
                  document.documentElement.scrollWidth - innerWidth,
                ),
                readingStart: Number(
                  (stage as HTMLElement).dataset.scrollReadStart,
                ),
                readingEnd: Number(
                  (stage as HTMLElement).dataset.scrollReadEnd,
                ),
              };
            }, chapter);
          samples.push({ fraction, ...reading });
          await testInfo.attach(`${chapter}-${fraction}-layout`, {
            body: JSON.stringify(reading, null, 2),
            contentType: 'application/json',
          });
          expect(
            reading.collisions,
            `${chapter} at ${fraction}: text hidden by a card`,
          ).toEqual([]);
          expect(
            reading.overflow,
            `${chapter} horizontal overflow`,
          ).toBeLessThanOrEqual(1);
          expect(
            Math.abs(reading.imageAspect - reading.naturalAspect),
          ).toBeLessThan(0.005);
          if (
            chapter === 'scoring' &&
            layout.width >= 1440 &&
            !('textScale' in layout)
          ) {
            expect(reading.controls!.top).toBeGreaterThanOrEqual(
              reading.intro.bottom + 12,
            );
            expect(
              Math.abs(reading.controls!.left - reading.intro.left),
            ).toBeLessThanOrEqual(2);
            expect(reading.controls!.right).toBeLessThanOrEqual(
              reading.screen.left - 12,
            );
            if (layout.height >= 900) {
              for (const button of reading.buttons) {
                expect(button.top).toBeGreaterThanOrEqual(reading.headerBottom);
                expect(button.bottom).toBeLessThanOrEqual(
                  reading.viewportHeight,
                );
              }
            }
          }
        }
      }
      await testInfo.attach('reading-layout-samples', {
        body: JSON.stringify(samples, null, 2),
        contentType: 'application/json',
      });
    });
  }
}

for (const path of ['/', '/en/']) {
  test(`${path}: high contrast poster uses real display weights and compact optical surfaces`, async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await open(page, path);
    const expectedSurfaces = {
      hero: 1,
      scoring: 1,
      experience: 2,
      replay: 1,
      download: 1,
      community: 1,
      closing: 0,
    };
    for (const [id, count] of Object.entries(expectedSurfaces)) {
      await expect(page.locator(`#${id} [data-glass-card]`)).toHaveCount(count);
    }
    const typography = await page.evaluate(() => {
      const titles = [
        ...document.querySelectorAll<HTMLElement>(
          'main h1, main h2, #closing-title',
        ),
      ];
      return {
        titles: titles.map((title) => ({
          family: getComputedStyle(title)
            .fontFamily.split(',')[0]
            .replaceAll('"', '')
            .trim(),
          weight: getComputedStyle(title).fontWeight,
        })),
        body: getComputedStyle(document.querySelector('.hero-lead')!)
          .fontWeight,
      };
    });
    expect(typography.titles).toHaveLength(7);
    expect(typography.titles).toEqual(
      Array.from({ length: 7 }, () => ({
        family: path === '/' ? 'NotoPoster' : 'Barlow',
        weight: path === '/' ? '900' : '700',
      })),
    );
    expect(typography.body).toBe('400');
    await expect(page.locator('#closing [data-glass-card]')).toHaveCount(0);
    await expect(
      page.locator(
        '.community-copy [data-glass-card], .community-artwork[data-glass-card]',
      ),
    ).toHaveCount(0);
    const composition = await page.evaluate(() => {
      const screen = document
        .querySelector('.landscape-device img')!
        .getBoundingClientRect();
      const summary = document
        .querySelector('[data-replay-device="summary"] img')!
        .getBoundingClientRect();
      const history = document
        .querySelector('[data-replay-device="history"] img')!
        .getBoundingClientRect();
      const action = document
        .querySelector('[data-glass-id="hero-actions"]')!
        .getBoundingClientRect();
      return {
        screenFraction: screen.width / innerWidth,
        summaryWidth: summary.width,
        archiveWidth: history.width,
        actionHeight: action.height,
      };
    });
    // A full, undistorted product screen leads this chapter. The archive is
    // visibly secondary, and the hero glass carries actions rather than copy.
    expect(composition.screenFraction).toBeGreaterThanOrEqual(0.58);
    expect(composition.screenFraction).toBeLessThanOrEqual(0.69);
    expect(composition.summaryWidth).toBeGreaterThanOrEqual(260);
    expect(composition.summaryWidth).toBeGreaterThan(
      composition.archiveWidth * 1.4,
    );
    expect(composition.actionHeight).toBeLessThanOrEqual(104);
    await expect(
      page.locator('[data-glass-id="hero-actions"] .hero-lead'),
    ).toHaveCount(0);
    await expect(
      page.locator('[data-glass-id="download-pass"] h2'),
    ).toHaveCount(0);
  });

  test(`${path}: poster chapters separate independent titles, motion items and optical surfaces`, async ({
    page,
  }, testInfo) => {
    await open(page, path);
    await atReading(page, 'hero');
    for (const chapter of chapters) {
      const stage = page.locator(stageSelector(chapter));
      const surfaces = stage.locator('[data-glass-card]');
      expect(await surfaces.count()).toBeGreaterThan(0);
      expect(await surfaces.count()).toBeLessThanOrEqual(3);
      expect(await stage.locator('[data-story-item]').count()).toBeGreaterThan(
        0,
      );
      expect(
        await stage.locator('[data-story-item] [data-story-item]').count(),
      ).toBe(0);
      for (const item of await stage.locator('[data-glass-card]').all()) {
        await expect(item).toHaveAttribute(
          'data-story-item',
          /^(heading|visual|control|detail)$/,
        );
      }
    }
    for (const chapter of [
      'hero',
      'scoring',
      'experience',
      'replay',
      'download',
      'community',
    ] as const) {
      expect(
        await page
          .locator(
            stageSelector(chapter) + ' h1, ' + stageSelector(chapter) + ' h2',
          )
          .first()
          .evaluate((heading) => heading.closest('[data-glass-card]') === null),
      ).toBe(true);
    }
    await expect(page.locator('[data-relay-anchor]')).toHaveCount(3);
    expect(
      await page
        .locator('[data-relay-anchor]')
        .evaluateAll((anchors) =>
          anchors.every(
            (anchor) =>
              !anchor.matches('[data-story-item]') &&
              !anchor.closest('[data-story-item]'),
          ),
        ),
    ).toBe(true);
    await evidence(page, testInfo, 'hero-poster');
  });
}

test('all motion roles remain settled throughout actual chapter reading ranges', async ({
  page,
}) => {
  await open(page);
  await atReading(page, 'hero');
  await page.mouse.click(8, 450);
  let sampled = 0;
  for (const chapter of chapters) {
    const stage = page.locator(stageSelector(chapter));
    // The shared camera track owns travel between reading edges. Story timeline
    // fractions no longer define reading; use the controller's actual range.
    for (const fraction of [0, 0.5, 1]) {
      let previousLayout = '';
      let stableSince = 0;
      await expect
        .poll(async () => {
          const before = await readRange(page, chapter);
          await page.evaluate(
            async (top) => {
              scrollTo({ top, behavior: 'instant' });
              await new Promise(requestAnimationFrame);
              await new Promise(requestAnimationFrame);
            },
            before.start + (before.end - before.start) * fraction,
          );
          const current = await readRange(page, chapter);
          const checkpoint = await page.evaluate(
            ({ chapter, start, end, fraction }) => {
              const stage = document.querySelector<HTMLElement>(
                `[data-story-stage="${chapter}"]`,
              )!;
              return {
                key: JSON.stringify({
                  start,
                  end,
                  storyStart: stage.dataset.storyStart,
                  storyEnd: stage.dataset.storyEnd,
                  height: document.documentElement.scrollHeight,
                  header: document
                    .querySelector('.site-header')!
                    .getBoundingClientRect().height,
                }),
                ready:
                  Math.abs(scrollY - (start + (end - start) * fraction)) <= 2 &&
                  document.documentElement.dataset.scrollState === 'idle' &&
                  [
                    ...stage.querySelectorAll<HTMLElement>('[data-story-item]'),
                  ].every(
                    (item) => Number(getComputedStyle(item).opacity) >= 0.999,
                  ),
              };
            },
            { chapter, ...current, fraction },
          );
          if (checkpoint.key !== previousLayout || !checkpoint.ready) {
            previousLayout = checkpoint.key;
            stableSince = Date.now();
          }
          return checkpoint.ready && Date.now() - stableSince >= 200;
        })
        .toBe(true);
      await atReading(page, chapter);
      await expect
        .poll(() =>
          stage.evaluate((element) =>
            [...element.querySelectorAll<HTMLElement>('[data-story-item]')].map(
              (item) => {
                const style = getComputedStyle(item);
                const matrix = new DOMMatrixReadOnly(style.transform);
                return {
                  opacity: Number(style.opacity),
                  x: matrix.m41,
                  y: matrix.m42,
                  scale: matrix.a,
                };
              },
            ),
          ),
        )
        .toEqual(
          Array.from(
            { length: await stage.locator('[data-story-item]').count() },
            () =>
              expect.objectContaining({
                opacity: expect.closeTo(1, 2),
                x: expect.closeTo(0, 1),
                y: expect.closeTo(0, 1),
                scale: expect.closeTo(1, 2),
              }),
          ),
        );
      const moving = await stage.evaluate((element) =>
        [...element.querySelectorAll<HTMLElement>('[data-story-item]')].some(
          (item) => {
            const style = getComputedStyle(item);
            const matrix = new DOMMatrixReadOnly(style.transform);
            return (
              Number(style.opacity) < 0.995 ||
              Math.abs(matrix.m41) > 0.5 ||
              Math.abs(matrix.m42) > 0.5 ||
              Math.abs(matrix.a - 1) > 0.005
            );
          },
        ),
      );
      expect(moving).toBe(false);
      sampled++;
    }
  }
  expect(sampled).toBeGreaterThanOrEqual(chapters.length);
});

test('a native chapter transition reveals its visual before title and controls without clipping glass', async ({
  page,
}, testInfo) => {
  await open(page);
  await seekReading(page, 'hero', 'end');
  await page.evaluate(() => {
    const samples: {
      at: number;
      roles: {
        role: string;
        opacity: number;
        reveal: number;
        inert: boolean;
      }[];
      opticalErrors: string[];
    }[] = [];
    Reflect.set(window, '__posterRoleSamples', samples);
    let active = true;
    Reflect.set(window, '__stopPosterRoleSamples', () => {
      active = false;
    });
    const frame = () => {
      const stage = document.querySelector('[data-story-stage="scoring"]')!;
      const roles = [
        ...stage.querySelectorAll<HTMLElement>('[data-story-item]'),
      ].map((item) => ({
        role: item.dataset.storyItem!,
        opacity: Number(getComputedStyle(item).opacity),
        reveal: Number(
          item
            .querySelector<HTMLElement>('[data-story-reveal]')
            ?.style.getPropertyValue('--story-reveal') || 1,
        ),
        inert: item.inert,
      }));
      const opticalErrors = [
        ...document.querySelectorAll<HTMLElement>('[data-glass-card]'),
      ].flatMap((glass) => {
        const style = getComputedStyle(glass);
        const transform = new DOMMatrixReadOnly(style.transform);
        const bad =
          style.clipPath !== 'none' ||
          Math.abs(transform.a - transform.d) > 0.001 ||
          Math.abs(transform.b) > 0.001 ||
          Math.abs(transform.c) > 0.001;
        return bad ? [glass.dataset.glassId!] : [];
      });
      samples.push({ at: performance.now(), roles, opticalErrors });
      if (active) requestAnimationFrame(frame);
    };
    requestAnimationFrame(frame);
  });
  await page.mouse.wheel(0, 24);
  await atReading(page, 'scoring');
  const samples = await page.evaluate(() => {
    Reflect.get(window, '__stopPosterRoleSamples')();
    return Reflect.get(window, '__posterRoleSamples') as {
      at: number;
      roles: {
        role: string;
        opacity: number;
        reveal: number;
        inert: boolean;
      }[];
      opticalErrors: string[];
    }[];
  });
  await testInfo.attach('poster-role-frames', {
    body: JSON.stringify(samples),
    contentType: 'application/json',
  });
  const first = (role: string) =>
    samples.find((sample) =>
      sample.roles.some((item) => item.role === role && item.opacity > 0.02),
    )?.at;
  expect(first('visual')).toBeDefined();
  expect(first('heading')).toBeDefined();
  expect(first('control')).toBeDefined();
  expect(first('visual')!).toBeLessThan(first('heading')!);
  expect(first('heading')!).toBeLessThan(first('control')!);
  for (const role of ['visual', 'heading', 'control'])
    expect(
      samples.some((sample) =>
        sample.roles.some(
          (item) =>
            item.role === role && item.opacity > 0.05 && item.opacity < 0.95,
        ),
      ),
    ).toBe(true);
  expect(samples.flatMap((sample) => sample.opticalErrors)).toEqual([]);
  const final = samples.at(-1)!;
  expect(final.roles.every((item) => item.opacity > 0.999 && !item.inert)).toBe(
    true,
  );
});

test('reduced motion keeps independent headings and every optical item readable without pinning', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await open(page, '/#replay');
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
  const moving = await page.locator('[data-story-item]').evaluateAll(
    (items) =>
      items.filter((item) => {
        const style = getComputedStyle(item);
        const matrix = new DOMMatrixReadOnly(style.transform);
        return (
          Number(style.opacity) < 0.999 ||
          Math.abs(matrix.m41) > 0.1 ||
          Math.abs(matrix.m42) > 0.1 ||
          Math.abs(matrix.a - 1) > 0.001
        );
      }).length,
  );
  expect(moving).toBe(0);
  const relay = page.locator('svg.story-relay');
  if (await relay.count()) await expect(relay).toHaveCSS('opacity', '0');
  await expect(page.locator('#replay h2')).toBeVisible();
});

test('a focused shot control survives a light return but leaves focus and the scene when the next chapter commits', async ({
  page,
  browserName,
}, testInfo) => {
  await open(page, '/#experience');
  await seekReading(page, 'experience', 'end');
  await page.locator('[data-point-preset="center"]').click();
  const reset = page.locator('[data-reset]');
  await reset.click();
  // WebKit's platform default does not focus buttons after pointer activation.
  // Establish the same focused-control precondition there; the subsequent
  // light return and committed wheel both use native input with a fixed pointer.
  if (browserName === 'webkit') await reset.focus();
  await expect(reset).toBeFocused();
  const controls = page.locator('[data-glass-id="experience-controls"]');
  await expect(controls).toHaveCSS('opacity', '1');

  // Keep the pointer on the same control. A subthreshold gesture returns to
  // this reading stop and must preserve its usable keyboard focus.
  await page.mouse.wheel(0, 12);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'tracking',
  );
  await atReading(page, 'experience');
  await expect(reset).toBeFocused();
  await expect(controls).toHaveCSS('opacity', '1');

  // Committing another chapter relinquishes the old control's focus before
  // focus protection can leave its entire optical panel hovering over replay.
  await page.mouse.wheel(0, 24);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await expect
    .poll(() =>
      page
        .locator('#experience')
        .evaluate((stage) => stage.contains(document.activeElement)),
    )
    .toBe(false);
  await atReading(page, 'replay');
  await expect(controls).toHaveCSS('opacity', '0');
  await expect(controls).toHaveJSProperty('inert', true);
  await expect(page.locator('[data-replay-device="summary"]')).toHaveCSS(
    'opacity',
    '1',
  );
  await evidence(page, testInfo, 'focused-control-chapter-exit');
});

test('without JavaScript the poster title, real screenshot links and download remain available', async ({
  browser,
  baseURL,
}) => {
  const context = await browser.newContext({
    javaScriptEnabled: false,
    baseURL,
  });
  try {
    for (const path of ['/', '/en/']) {
      const page = await context.newPage();
      await page.goto(path);
      await expect(page.locator('#hero h1')).toBeVisible();
      await expect(page.locator('#hero [data-download]')).toHaveAttribute(
        'href',
        /Hoopito-v[\d.]+-android\.apk$/,
      );
      expect(await page.locator('[data-image-viewer]').count()).toBeGreaterThan(
        2,
      );
      const invisible = await page
        .locator('[data-story-item]')
        .evaluateAll((items) =>
          items.some((item) => Number(getComputedStyle(item).opacity) < 0.999),
        );
      expect(invisible).toBe(false);
      await page.close();
    }
  } finally {
    await context.close();
  }
});

test('the decorative relay is stable at reading stops and returns exactly with reverse scrolling', async ({
  page,
}) => {
  await open(page);
  await atReading(page, 'hero');
  const relay = page.locator('svg.story-relay');
  await expect(relay).toHaveCount(1);
  await expect(relay).toHaveAttribute('aria-hidden', 'true');
  await expect(relay).toHaveCSS('pointer-events', 'none');
  const relayState = () =>
    relay.evaluate((element) => ({
      markup: element.innerHTML,
      transform: (element as SVGElement).style.transform,
      width: element.getBoundingClientRect().width,
    }));
  const box = await relay.boundingBox();
  expect(box!.width).toBeLessThanOrEqual(128);
  expect(box!.height).toBeLessThanOrEqual(8);
  const initial = await relayState();
  await page.waitForTimeout(220);
  expect(await relayState()).toEqual(initial);
  await seekReading(page, 'hero', 'end');
  await page.mouse.wheel(0, 24);
  await atReading(page, 'scoring');
  const scoring = await relayState();
  expect(scoring).not.toEqual(initial);
  await page.waitForTimeout(220);
  expect(await relayState()).toEqual(scoring);
  await seekReading(page, 'scoring', 'start');
  await page.mouse.wheel(0, -24);
  await atReading(page, 'hero');
  expect(await relayState()).toEqual(initial);
  for (const chapter of ['replay', 'download', 'community'] as const) {
    await page.goto('/#' + chapter);
    await atReading(page, chapter);
    await expect(relay).toHaveCSS('opacity', '1');
    await expect(page.locator('html')).toHaveAttribute(
      'data-relay-chapter',
      chapter,
    );
    const settled = await relayState();
    await page.waitForTimeout(120);
    expect(await relayState()).toEqual(settled);
  }
  await page.goto('/#closing');
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'closing',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect(relay).toHaveCSS('opacity', '0');
});

test('a non-glass title growing during a committed transition preserves the chosen chapter', async ({
  page,
}) => {
  await open(page);
  await atReading(page, 'hero');
  const heading = page.locator('#hero h1');
  expect(
    await heading.evaluate((item) => !item.closest('[data-glass-card]')),
  ).toBe(true);
  await seekReading(page, 'hero', 'end');
  const before = await readRange(page, 'scoring');
  await page.mouse.wheel(0, 24);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await heading.evaluate((item) => {
    (item as HTMLElement).style.paddingBottom = '500px';
  });
  await expect
    .poll(async () =>
      Math.abs((await readRange(page, 'scoring')).start - before.start),
    )
    .toBeGreaterThan(1);
  await atReading(page, 'scoring');
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'scoring',
  );
});

test('a growing navigation header remeasures its actual height and keeps the committed destination', async ({
  page,
}) => {
  await open(page);
  await atReading(page, 'hero');
  await measuredHeader(page);
  await seekReading(page, 'hero', 'end');
  await page.mouse.wheel(0, 24);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await page.locator('.site-header').evaluate((header) => {
    const item = header as HTMLElement;
    item.style.minHeight = `${item.getBoundingClientRect().height + 48}px`;
    item.style.paddingBottom = '48px';
  });
  await measuredHeader(page);
  await atReading(page, 'scoring');
  const clearance = await page.evaluate(() => {
    const header = document
      .querySelector('.site-header')!
      .getBoundingClientRect();
    const title = document
      .querySelector('#scoring h2')!
      .getBoundingClientRect();
    return title.top - header.bottom;
  });
  expect(clearance).toBeGreaterThanOrEqual(0);
});

for (const path of ['/', '/en/']) {
  test(`${path}: mobile poster flow has no horizontal overflow and preserves complete reading ranges`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await open(page, path);
    await measuredHeader(page);
    await expect(page.locator('.pin-spacer')).toHaveCount(0);
    for (const chapter of chapters) {
      await seekReading(page, chapter, 'start');
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth + 1,
        ),
      ).toBe(true);
      await seekReading(page, chapter, 'end');
    }
    await seekReading(page, 'experience');
    await evidence(page, testInfo, 'mobile-experience');
  });

  test(`${path}: short desktop and 200 percent text extend the reading range without clipping content`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize({ width: 1024, height: 640 });
    await open(page, path);
    await page.evaluate(() => {
      document.documentElement.style.fontSize = '200%';
    });
    await measuredHeader(page);
    for (const chapter of chapters) {
      await seekReading(page, chapter, 'start');
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth <= innerWidth + 1,
        ),
      ).toBe(true);
      await seekReading(page, chapter, 'end');
      const stage = page.locator(stageSelector(chapter));
      const clipping = await stage.evaluate((element) =>
        [...element.querySelectorAll<HTMLElement>('p, h1, h2, button, summary')]
          .filter((item) => getComputedStyle(item).display !== 'none')
          .filter((item) => item.clientWidth > 0)
          .filter((item) => item.scrollWidth > item.clientWidth + 2)
          .map((item) => ({
            tag: item.tagName,
            class: item.className,
            text: item.textContent?.trim().slice(0, 100),
            width: item.clientWidth,
            scroll: item.scrollWidth,
          })),
      );
      expect(clipping, chapter + ': overflowing text').toEqual([]);
    }
    await evidence(page, testInfo, 'short-large-text');
  });
}

test('@webgl the central court remains selectable after the scoreboard and action dock settle', async ({
  page,
}, testInfo) => {
  const available = await page.evaluate(() => {
    const context = document.createElement('canvas').getContext('webgl2', {
      failIfMajorPerformanceCaveat: true,
    });
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!context;
  });
  test.skip(!available, 'Production WebGL2 is unavailable in this browser.');
  await open(page, '/#experience', { css: false });
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20000,
  });
  await atReading(page, 'experience');
  await expect(page.locator('.scene-background > .scene-poster')).toHaveCSS(
    'opacity',
    '0',
  );
  const board = page.locator('[data-glass-id="experience-scoreboard"]');
  const controls = page.locator('[data-glass-id="experience-controls"]');
  await expect(board).toBeVisible();
  await expect(controls).toBeVisible();
  const court = page.locator('[data-demo-court-host]');
  const bounds = await court.boundingBox();
  expect(bounds).not.toBeNull();
  const center = await page.evaluate(
    () => document.documentElement.clientWidth / 2,
  );
  // The poster heading can sit beside the court; do not require pixel centering.
  expect(Math.abs(bounds!.x + bounds!.width / 2 - center)).toBeLessThan(
    center * 0.2,
  );
  await page.mouse.click(
    bounds!.x + bounds!.width * 0.5,
    bounds!.y + bounds!.height * 0.5,
  );
  await expect(page.locator('[data-record]')).toBeEnabled();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await page.locator('[data-reset]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await evidence(page, testInfo, 'central-court');
});

test('a title reflow at the end of a committed transition preserves its destination', async ({
  page,
}, testInfo) => {
  await open(page);
  await seekReading(page, 'hero', 'end');
  await page.evaluate(() => {
    window.addEventListener(
      'wheel',
      () => {
        setTimeout(() => {
          document.documentElement.dataset.testLateState =
            document.documentElement.dataset.scrollState;
          (
            document.querySelector('.hero-copy') as HTMLElement
          ).style.paddingBottom = '500px';
        }, 940);
      },
      { once: true },
    );
  });
  await page.mouse.wheel(0, 24);
  await expect(page.locator('html')).toHaveAttribute(
    'data-test-late-state',
    'settling',
  );
  try {
    await atReading(page, 'scoring');
  } finally {
    await evidence(page, testInfo, 'late-reflow');
  }
});

test('navigation touch surfaces retain 48px targets on landing and privacy pages', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  for (const path of ['/', '/en/', '/privacy/', '/en/privacy/']) {
    await page.goto(path);
    await page.evaluate(() => document.fonts.ready);
    for (const link of await page.locator('.site-header a').all()) {
      if (!(await link.isVisible())) continue;
      const box = await link.boundingBox();
      expect(
        box!.width,
        path + ': ' + (await link.textContent()),
      ).toBeGreaterThanOrEqual(48);
      expect(box!.height).toBeGreaterThanOrEqual(48);
    }
  }
});

test('@webgl pending wide court poster fills its viewport without a duplicate SVG', async ({
  page,
  browserName,
}) => {
  test.skip(
    browserName !== 'chromium',
    'Representative production WebGL loading evidence.',
  );
  await page.setViewportSize({ width: 1920, height: 1080 });
  let release!: () => void;
  const gate = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.route(sceneChunk, async (route) => {
    await gate;
    await route.continue().catch(() => {});
  });
  try {
    await page.goto('/#experience', { waitUntil: 'domcontentloaded' });
    await expect(page.locator('html')).toHaveAttribute(
      'data-chapter',
      'experience',
    );
    const poster = page.locator('.demo-scene-poster');
    await expect(poster).toHaveCSS('display', 'block');
    const geometry = await page.evaluate(() => {
      const rect = (selector: string) => {
        const r = document.querySelector(selector)!.getBoundingClientRect();
        return { x: r.x, y: r.y, width: r.width, height: r.height };
      };
      return {
        poster: rect('.demo-scene-poster img'),
        canvas: rect('#court-canvas'),
      };
    });
    expect(
      Math.abs(geometry.poster.width - geometry.canvas.width),
    ).toBeLessThanOrEqual(2);
    expect(
      Math.abs(geometry.poster.height - geometry.canvas.height),
    ).toBeLessThanOrEqual(2);
    await expect(page.locator('[data-demo-court]')).toHaveCSS('opacity', '0');
    release();
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
      timeout: 20000,
    });
    await expect(poster).toHaveCSS('display', 'none');
  } finally {
    release();
  }
});
