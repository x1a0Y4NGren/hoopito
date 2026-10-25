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

async function expectDesktopPins(page: Page) {
  const expected = await page.evaluate(() => {
    if (
      matchMedia('(prefers-reduced-motion: reduce)').matches ||
      !matchMedia('(min-width:1024px) and (pointer:fine)').matches
    )
      return 0;
    return ['hero', 'experience', 'replay'].filter((chapter) => {
      const stage = document.querySelector<HTMLElement>(
        `[data-story-stage="${chapter}"]`,
      )!;
      return (
        stage.scrollHeight <=
        innerHeight -
          (chapter === 'experience' ? 104 : chapter === 'replay' ? 88 : 50)
      );
    }).length;
  });
  await expect(page.locator('.pin-spacer')).toHaveCount(expected);
}

for (const locale of locales) {
  for (const width of [390, 1440]) {
    test(`${locale.lang}: ${width}px demo invitations explain court and controls without selecting or scoring`, async ({
      page,
    }) => {
      await page.route(threeChunk, (route) => route.abort());
      await page.setViewportSize({ width, height: 1000 });
      await page.goto(locale.path);
      await page.evaluate(() => document.fonts.ready);
      await page.addStyleTag({
        content: 'html{scroll-behavior:auto!important}',
      });
      await page.evaluate(() => {
        const samples: Record<string, number> = {};
        Object.assign(window, { spotlightAlignment: samples });
        for (const [selector, kind] of [
          ['[data-demo-court-host]', 'court'],
          ['.point-presets', 'presets'],
        ]) {
          const target = document.querySelector<HTMLElement>(selector)!;
          new MutationObserver(() => {
            if (target.dataset.demoInvitation !== 'playing') return;
            const layer = document.querySelector<HTMLElement>(
              `.demo-invitation-layer[data-cue-kind="${kind}"]`,
            )!;
            const a = target.getBoundingClientRect(),
              b = layer.getBoundingClientRect();
            samples[kind] = Math.max(
              Math.abs(a.left - b.left),
              Math.abs(a.top - b.top),
              Math.abs(a.width - b.width),
              Math.abs(a.height - b.height),
            );
          }).observe(target, {
            attributes: true,
            attributeFilter: ['data-demo-invitation'],
          });
        }
      });
      await page.locator('#experience').scrollIntoViewIfNeeded();
      const host = page.locator('[data-demo-court-host]');
      const presets = page.locator('.point-presets');
      await host.scrollIntoViewIfNeeded();
      await expect(host).toHaveAttribute('data-demo-invitation', 'done');
      await presets.scrollIntoViewIfNeeded();
      await expect(presets).toHaveAttribute('data-demo-invitation', 'done');
      for (const kind of ['court', 'presets'] as const) {
        // Completed layers are display:none to prevent stale-size overflow.
        // Assert their geometry while the actual spotlight was visible.
        const alignment = await page.evaluate(
          (cueKind) =>
            (
              window as typeof window & {
                spotlightAlignment: Record<string, number>;
              }
            ).spotlightAlignment[cueKind],
          kind,
        );
        expect(
          alignment,
          `${kind} spotlight must stay on its actual target`,
        ).toBeLessThan(0.6);
      }
      await expect(
        page.locator('[data-point-preset][aria-pressed="true"]'),
      ).toHaveCount(0);
      await expect(page.locator('[data-blue-score]')).toHaveText('6');
      await expect(page.locator('[data-record]')).toBeDisabled();
      await page.locator('[data-point-preset="center"]').focus();
      await page.keyboard.press('Enter');
      const record = page.locator('[data-record]');
      await record.scrollIntoViewIfNeeded();
      await expect(record).toHaveAttribute('data-demo-invitation', 'done');
      await expect(record).toBeEnabled();
      await expect(page.locator('[data-blue-score]')).toHaveText('6');
      await record.click();
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      for (const layer of await page.locator('.demo-invitation-layer').all())
        await expect(layer).toHaveCSS('opacity', '0');
      await page.locator('[data-reset]').click();
      await expectReset(page);
      await page.locator('#download').scrollIntoViewIfNeeded();
      await host.scrollIntoViewIfNeeded();
      await expect(host).toHaveAttribute('data-demo-invitation', 'done');
      for (const layer of await page.locator('.demo-invitation-layer').all())
        await expect(layer).toHaveCSS('opacity', '0');
    });
  }
}

test(
  'the desktop demo keeps one background renderer while accepting host clicks and returning to the story',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Actual WebGL input is exercised in Chromium.',
    );
    await allowSoftwareWebGL(page);
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await page.evaluate(() => {
      Reflect.set(
        window,
        'demoContext',
        document
          .querySelector<HTMLCanvasElement>('#court-canvas')!
          .getContext('webgl2'),
      );
    });
    await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
    await page.locator('#experience').scrollIntoViewIfNeeded();
    const host = page.locator('[data-demo-court-host]');
    const canvas = page.locator('#court-canvas');
    const sceneWidth = () =>
      page.evaluate(() => document.documentElement.clientWidth * 0.48);
    await expect(host).toHaveAttribute('data-renderer', '3d');
    await expect(page.locator('.scene-background > #court-canvas')).toHaveCount(
      1,
    );
    await expect(host.locator('canvas')).toHaveCount(0);
    await expect(page.locator('canvas')).toHaveCount(1);
    expect((await canvas.boundingBox())!.width).toBeCloseTo(
      await sceneWidth(),
      0,
    );
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    const range = await page
      .locator('[data-story-stage="experience"]')
      .evaluate((e) => ({
        start: Number((e as HTMLElement).dataset.storyStart),
        end: Number((e as HTMLElement).dataset.storyEnd),
        height: innerHeight,
      }));
    expect(range.end - range.start).toBeCloseTo(range.height * 0.32, 0);
    const bounds = await host.boundingBox();
    await host.click({
      position: { x: bounds!.width * 0.5, y: bounds!.height * 0.63 },
    });
    await expect(page.locator('[data-record]')).toBeEnabled();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await page.locator('[data-reset]').click();
    await expectReset(page);
    await page.locator('#scoring').scrollIntoViewIfNeeded();
    await expect(page.locator('.scene-background canvas')).toHaveCount(1);
    await page.locator('#experience').scrollIntoViewIfNeeded();
    await expect(host).toHaveAttribute('data-renderer', '3d');
    expect(
      await page.evaluate(
        () =>
          document
            .querySelector<HTMLCanvasElement>('#court-canvas')!
            .getContext('webgl2') === Reflect.get(window, 'demoContext'),
      ),
    ).toBe(true);
    await page.setViewportSize({ width: 1440, height: 650 });
    await expect
      .poll(() =>
        page
          .locator('[data-story-stage="experience"]')
          .evaluate((e) => e.parentElement!.classList.contains('pin-spacer')),
      )
      .toBe(false);
    await expect(page.locator('.scene-background > #court-canvas')).toHaveCount(
      1,
    );
    expect((await canvas.boundingBox())!.width).toBeCloseTo(
      await sceneWidth(),
      0,
    );
    await expect(host).toHaveAttribute('data-renderer', '3d');
    await page.setViewportSize({ width: 1440, height: 1000 });
    await expectDesktopPins(page);
    await expect(host).toHaveAttribute('data-renderer', '3d');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect(page.locator('.pin-spacer')).toHaveCount(0);
    await expect(page.locator('.scene-background > #court-canvas')).toHaveCount(
      1,
    );
    await page.setViewportSize({ width: 390, height: 844 });
    await expect(host).toHaveAttribute('data-renderer', '2d');
    await expect(host.locator('canvas')).toHaveCount(0);
    await expect(page.locator('[data-demo-court]')).toBeVisible();
  },
);

for (const locale of locales) {
  for (const width of [390, 1920]) {
    test(`${locale.lang}: ${width}px aiming halo stays centered while selecting and resetting`, async ({
      page,
    }, testInfo) => {
      await page.setViewportSize({ width, height: width === 390 ? 844 : 1080 });
      // This regression concerns the interactive SVG, shared by both rendering
      // paths; keep the decorative desktop renderer out of its frame sampling.
      await page.route(threeChunk, (route) => route.abort());
      await page.goto(`${locale.path}#experience`);
      const selection = page.locator('[data-demo-selection]');
      const sampleAlignment = async (name: string) => {
        await expect(selection).not.toHaveAttribute('hidden');
        const samples = await selection.evaluate(
          (element) =>
            new Promise<{ delta: number; scale: number }[]>((done) => {
              const halo =
                element.querySelector<SVGCircleElement>('.aim-halo')!;
              const dot =
                element.querySelector<SVGCircleElement>('circle[r="4"]')!;
              const samples: { delta: number; scale: number }[] = [];
              const started = performance.now();
              const sample = () => {
                const haloMatrix = halo.getScreenCTM()!;
                const dotMatrix = dot.getScreenCTM()!;
                const haloCenter = new DOMPoint(
                  halo.cx.baseVal.value,
                  halo.cy.baseVal.value,
                ).matrixTransform(haloMatrix);
                const targetCenter = new DOMPoint(
                  dot.cx.baseVal.value,
                  dot.cy.baseVal.value,
                ).matrixTransform(dotMatrix);
                samples.push({
                  delta: Math.hypot(
                    haloCenter.x - targetCenter.x,
                    haloCenter.y - targetCenter.y,
                  ),
                  scale:
                    Math.hypot(haloMatrix.a, haloMatrix.b) /
                    Math.hypot(dotMatrix.a, dotMatrix.b),
                });
                if (performance.now() - started >= 650) done(samples);
                else requestAnimationFrame(sample);
              };
              requestAnimationFrame(sample);
            }),
        );
        await testInfo.attach(name, {
          body: JSON.stringify(samples),
          contentType: 'application/json',
        });
        expect(
          Math.max(...samples.map((sample) => sample.delta)),
          name,
        ).toBeLessThan(0.5);
        // A busy software-rendered CI clock may still be animating after the
        // sample window. Keep the frame alignment assertion, then observe the
        // actual settled state rather than assuming wall time equals GSAP time.
        await expect
          .poll(() =>
            selection.evaluate((element) => {
              const halo = element
                .querySelector<SVGCircleElement>('.aim-halo')!
                .getScreenCTM()!;
              const dot = element
                .querySelector<SVGCircleElement>('circle[r="4"]')!
                .getScreenCTM()!;
              return Math.hypot(halo.a, halo.b) / Math.hypot(dot.a, dot.b);
            }),
          )
          .toBeCloseTo(1, 2);
      };
      await page.locator('[data-point-preset="center"]').click();
      await sampleAlignment('center preset: animated and settled');
      await page.locator('[data-point-preset="left"]').click();
      await page.locator('[data-point-preset="right"]').click();
      await sampleAlignment('rapid reselection');
      await page.locator('[data-reset]').click();
      await page.locator('[data-point-preset="center"]').focus();
      await page.keyboard.press('Enter');
      await sampleAlignment('keyboard selection after reset');
      await page.screenshot({
        path: testInfo.outputPath(`${locale.lang}-${width}-aim-centered.png`),
      });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await page.locator('[data-point-preset="left"]').click();
      await sampleAlignment('system reduced motion');
    });
  }
}

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

test('replay completes the final fractional scroll pixel on a high density display', async ({
  browser,
}) => {
  const context = await browser.newContext({
    viewport: { width: 1440, height: 1000 },
    deviceScaleFactor: 2,
    reducedMotion: 'no-preference',
  });
  try {
    const page = await context.newPage();
    await page.route(threeChunk, (route) => route.abort());
    await page.goto('/');
    await page.evaluate(() => document.fonts.ready);
    await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
    const stage = page.locator('[data-story-stage="replay"]');
    await stage.evaluate((element) =>
      scrollTo({
        top: Number((element as HTMLElement).dataset.replayEnd) - 0.4,
        behavior: 'instant',
      }),
    );
    await expect(page.locator('[data-replay-red]')).toHaveText('11');
    await expect(stage).toHaveAttribute('data-replay-progress', '1.0000');
    await expect(page.locator('[data-replay-clip]')).toHaveAttribute(
      'width',
      '398',
    );
    for (const card of await page.locator('[data-replay-card]').all()) {
      const m = await card.evaluate((element) => {
        const matrix = new DOMMatrix(getComputedStyle(element).transform);
        return (
          Math.abs(matrix.m13) +
          Math.abs(matrix.m23) +
          Math.abs(matrix.m41) +
          Math.abs(matrix.m42) +
          Math.abs(matrix.m43)
        );
      });
      expect(m).toBeLessThan(0.001);
    }
  } finally {
    await context.close();
  }
});

test('replay refresh preserves the card phase and media changes preserve the visible reading position', async ({
  page,
}, testInfo) => {
  await page.route(threeChunk, (route) => route.abort());
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto('/');
  await page.evaluate(() => document.fonts.ready);
  await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
  const stage = page.locator('[data-story-stage="replay"]');
  const waitForMeasuredRange = async () => {
    await expectDesktopPins(page);
    // A viewport resize returns before the debounced media/layout refresh.
    // Old ranges and old phase can still agree while both are obsolete.
    await expect
      .poll(() =>
        stage.evaluate((element) => {
          const { replayStart, replayEnd } = (element as HTMLElement).dataset;
          const spacer = element.closest('.pin-spacer-story-replay');
          if (!spacer) return false;
          const expectedStart = Math.round(
            scrollY + spacer.getBoundingClientRect().top - innerHeight * 0.5,
          );
          return (
            Math.abs(Number(replayStart) - expectedStart) <= 0.5 &&
            Math.abs(
              Number(replayEnd) - Number(replayStart) - innerHeight * 0.75,
            ) <= 0.5
          );
        }),
      )
      .toBe(true);
  };
  const expectSettledPhase = async (phase: number, restored = false) => {
    let lastMeasurement: unknown;
    try {
      await expect
        .poll(async () => {
          lastMeasurement = await stage.evaluate(
            async (element, target) => {
              const read = () => {
                const { replayStart, replayEnd, replayProgress } = (
                  element as HTMLElement
                ).dataset;
                const start = Number(replayStart),
                  end = Number(replayEnd);
                return {
                  start,
                  end,
                  scroll: scrollY,
                  actual: Math.max(
                    0,
                    Math.min(1, (scrollY - start) / (end - start)),
                  ),
                  rendered: Number(replayProgress),
                };
              };
              const before = read();
              await new Promise(requestAnimationFrame);
              await new Promise(requestAnimationFrame);
              const after = read();
              // A restored fractional playhead can differ from its rounded
              // native scroll position by half a CSS pixel. Preserve the
              // original per-step phase precision: media/resize used two
              // decimals; initial seeks and completed cards used three.
              const nativeTolerance = 0.5 / (after.end - after.start) + 0.0001;
              const tolerance =
                target.phase === 1 || !target.restored ? 0.0005 : 0.005;
              return {
                measurementStable:
                  before.start === after.start && before.end === after.end,
                motionSettled:
                  before.scroll === after.scroll &&
                  Math.abs(before.rendered - after.rendered) < 0.0001,
                nativePhaseMatches:
                  Math.abs(after.actual - after.rendered) < nativeTolerance,
                targetPhaseMatches:
                  Math.abs(after.rendered - target.phase) < tolerance,
                ...after,
                target: target.phase,
                tolerance,
                nativeTolerance,
              };
            },
            { phase, restored },
          );
          return lastMeasurement;
        })
        .toMatchObject({
          measurementStable: true,
          motionSettled: true,
          nativePhaseMatches: true,
          targetPhaseMatches: true,
        });
    } catch (error) {
      await testInfo.attach('replay-layout-state', {
        body: JSON.stringify(lastMeasurement, null, 2),
        contentType: 'application/json',
      });
      throw error;
    }
  };
  await waitForMeasuredRange();
  const midpoint = await stage.evaluate((element) => {
    const e = element as HTMLElement;
    const start = Number(e.dataset.replayStart),
      end = Number(e.dataset.replayEnd);
    scrollTo({
      top: (start + end) / 2,
      behavior: 'instant',
    });
    // Native scroll positions are quantized; retain the actual sought phase.
    return (scrollY - start) / (end - start);
  });
  expect(midpoint).toBeCloseTo(0.5, 2);
  await expectSettledPhase(midpoint);
  const top = (await stage.boundingBox())!.y;
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
  await expect
    .poll(async () => Math.abs((await stage.boundingBox())!.y - top))
    .toBeLessThan(1);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await waitForMeasuredRange();
  await expectSettledPhase(midpoint, true);
  await expect
    .poll(async () => Math.abs((await stage.boundingBox())!.y - top))
    .toBeLessThan(1);
  await page.setViewportSize({ width: 1440, height: 1050 });
  await waitForMeasuredRange();
  await expectSettledPhase(midpoint, true);
  await stage.evaluate((element) =>
    scrollTo({
      top: Number((element as HTMLElement).dataset.replayEnd),
      behavior: 'instant',
    }),
  );
  await expectSettledPhase(1);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await waitForMeasuredRange();
  await expectSettledPhase(1);
  await expect(page.locator('[data-replay-red]')).toHaveText('11');
  // Leaving the fixed approach must stay natural across later refreshes.
  await stage.evaluate((element) =>
    scrollTo({
      top: Number((element as HTMLElement).dataset.replayEnd) + 200,
      behavior: 'instant',
    }),
  );
  await expectSettledPhase(1);
  const leavingTop = (await stage.boundingBox())!.y;
  await page.setViewportSize({ width: 1440, height: 1100 });
  await waitForMeasuredRange();
  await expectSettledPhase(1);
  await expect
    .poll(async () => Math.abs((await stage.boundingBox())!.y - leavingTop))
    .toBeLessThan(1.5);
  await expectNoOverflow(page);
});

test('replay arrival settles the page, both card faces and final score together', async ({
  page,
}) => {
  await page.route(threeChunk, (route) => route.abort());
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto('/');
  await page.evaluate(() => document.fonts.ready);
  await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
  const stage = page.locator('[data-story-stage="replay"]');
  await stage.evaluate((element) =>
    scrollTo({
      top: Number((element as HTMLElement).dataset.storyStart) - 100,
      behavior: 'instant',
    }),
  );
  await page.mouse.move(700, 400);
  for (let i = 0; i < 24; i++) {
    await page.mouse.wheel(0, 50);
    await page.waitForTimeout(350);
    if ((await stage.boundingBox())!.y <= 103) break;
  }
  await expect
    .poll(async () => Number(await stage.getAttribute('data-replay-progress')))
    .toBeCloseTo(1, 3);
  expect((await stage.boundingBox())!.y).toBeCloseTo(88, 0);
  await expect(page.locator('[data-replay-blue]')).toHaveText('8');
  await expect(page.locator('[data-replay-red]')).toHaveText('11');
  for (const card of await page.locator('[data-replay-card]').all()) {
    const tilt = await card.evaluate((element) => {
      const m = new DOMMatrix(getComputedStyle(element).transform);
      return (
        Math.abs(m.m13) + Math.abs(m.m23) + Math.abs(m.m41) + Math.abs(m.m43)
      );
    });
    expect(tilt).toBeLessThan(0.001);
  }
});

for (const locale of locales) {
  test(`${locale.lang}: replay slows its arrival without slowing the score clock, and reverse scroll does not snap forward`, async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.route(threeChunk, (route) => route.abort());
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(locale.path);
    await page.evaluate(() => document.fonts.ready);
    await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
    const stage = page.locator('[data-story-stage="replay"]');
    const range = await stage.evaluate((element) => ({
      start: Number((element as HTMLElement).dataset.replayStart),
      end: Number((element as HTMLElement).dataset.replayEnd),
    }));
    const tops: number[] = [];
    for (const progress of [0.15, 0.35, 0.65, 0.85]) {
      await page.evaluate(
        (top) => scrollTo({ top, behavior: 'instant' }),
        range.start + (range.end - range.start) * progress,
      );
      await expect
        .poll(async () =>
          Number(await stage.getAttribute('data-replay-progress')),
        )
        .toBeCloseTo(progress, 2);
      tops.push((await stage.boundingBox())!.y);
    }
    // Identical scroll distances produce progressively smaller page movement,
    // while the graph advances on the unslowed shared scroll clock.
    expect(tops[2] - tops[3]).toBeLessThan((tops[0] - tops[1]) * 0.6);
    await expect(page.locator('[data-replay-blue]')).toHaveText('8');
    await expect(page.locator('[data-replay-red]')).toHaveText('7');
    await page.evaluate(
      (top) => scrollTo({ top, behavior: 'instant' }),
      range.start + (range.end - range.start) * 0.94,
    );
    // The native seek returns before WebKit commits its shared scroll clock.
    // Begin the reverse gesture only once that seek has reached the cards, and
    // hit page content rather than the mouse's default (0, 0) header boundary.
    await expect
      .poll(async () =>
        Number(await stage.getAttribute('data-replay-progress')),
      )
      .toBeCloseTo(0.94, 2);
    await page.mouse.move(700, 400);
    const reverseDelta = -30;
    const reverseGesture = await page.evaluateHandle((delta) => {
      const gesture = {
        seen: false,
        destination: scrollY + delta,
        stop: () => {},
      };
      const onWheel = () => {
        gesture.seen = true;
      };
      window.addEventListener('wheel', onWheel, { once: true, passive: true });
      gesture.stop = () => {
        window.removeEventListener('wheel', onWheel);
      };
      return gesture;
    }, reverseDelta);
    try {
      await page.mouse.wheel(0, reverseDelta);
      // WebKit may deliver the compositor's remaining reverse wheel motion
      // after 900 ms. Some engines expose scrollend but never dispatch it for
      // this input, so require the full pixel delta before checking stability.
      await expect
        .poll(() =>
          reverseGesture.evaluate(async (gesture) => {
            if (!gesture.seen || Math.abs(scrollY - gesture.destination) >= 0.5)
              return false;
            const top = scrollY;
            await new Promise(requestAnimationFrame);
            await new Promise(requestAnimationFrame);
            return scrollY === top;
          }),
        )
        .toBe(true);
    } finally {
      await reverseGesture.evaluate((gesture) => gesture.stop());
      await reverseGesture.dispose();
    }
    const reversed = await page.evaluate(() => scrollY);
    expect(reversed).toBeLessThan(
      range.start + (range.end - range.start) * 0.94,
    );
    expect(reversed).toBeGreaterThan(
      range.start + (range.end - range.start) * 0.84,
    );
    await page.waitForTimeout(450);
    expect(await page.evaluate(() => scrollY)).toBeCloseTo(reversed, 0);
    // A direct navigation skips the approach and exposes readable screenshots.
    await page.locator('a[href="#replay"]').first().click();
    await expect
      .poll(async () =>
        Number(await stage.getAttribute('data-replay-progress')),
      )
      .toBeCloseTo(1, 3);
    await expect
      .poll(async () => (await stage.boundingBox())!.y)
      .toBeCloseTo(85, 0);
    await expect(page.locator('[data-replay-red]')).toHaveText('11');
    // Clicking the fixed header moves the pointer there. Deliver this gesture
    // over content and wait for departure; engines need not scroll its exact delta.
    await page.mouse.move(700, 400);
    const forwardGesture = await page.evaluateHandle(() => {
      const gesture = { seen: false, stop: () => {} };
      const onWheel = () => {
        gesture.seen = true;
      };
      window.addEventListener('wheel', onWheel, { once: true, passive: true });
      gesture.stop = () => window.removeEventListener('wheel', onWheel);
      return gesture;
    });
    try {
      await page.mouse.wheel(0, 1000);
      await expect
        .poll(() =>
          forwardGesture.evaluate(async (gesture, end) => {
            if (!gesture.seen || scrollY <= end + 100) return false;
            const top = scrollY;
            await new Promise(requestAnimationFrame);
            await new Promise(requestAnimationFrame);
            return scrollY === top;
          }, range.end),
        )
        .toBe(true);
    } finally {
      await forwardGesture.evaluate((gesture) => gesture.stop());
      await forwardGesture.dispose();
    }
    // A large forward scroll can leave normally; snapping must not pull back.
    const left = await page.evaluate(() => scrollY);
    expect(left).toBeGreaterThan(range.end + 100);
    await page.waitForTimeout(400);
    expect(await page.evaluate(() => scrollY)).toBeCloseTo(left, 0);
    await expectNoOverflow(page);
    expect(errors).toEqual([]);
  });

  test(`${locale.lang}: direct replay anchor arrives with readable faces and no unfinished score`, async ({
    page,
  }) => {
    const errors: string[] = [];
    page.on('pageerror', (error) => errors.push(error.message));
    await page.route(threeChunk, (route) => route.abort());
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(`${locale.path}#replay`);
    await page.evaluate(() => document.fonts.ready);
    const stage = page.locator('[data-story-stage="replay"]');
    await expect
      .poll(async () =>
        Number(await stage.getAttribute('data-replay-progress')),
      )
      .toBeCloseTo(1, 3);
    await expect
      .poll(async () => (await stage.boundingBox())!.y)
      .toBeCloseTo(85, 0);
    await expect(page.locator('[data-replay-blue]')).toHaveText('8');
    await expect(page.locator('[data-replay-red]')).toHaveText('11');
    const opener = page.locator('[data-replay-device="summary"] .viewer-link');
    // A real click may scroll the caption into view. The gallery must restore
    // that actual opening position, rather than undoing the user's approach.
    const opening = await opener.evaluateHandle((element) => {
      let position: { scroll: number; stageTop: number } | undefined;
      const capture = () => {
        position = {
          scroll: scrollY,
          stageTop: element
            .closest('[data-story-stage="replay"]')!
            .getBoundingClientRect().top,
        };
      };
      element.addEventListener('click', capture, { capture: true, once: true });
      return {
        read: () => position,
        stop: () => element.removeEventListener('click', capture, true),
      };
    });
    try {
      await opener.click();
      const openedAt = await opening.evaluate((value) => value.read());
      expect(openedAt).toBeDefined();
      await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
        'naturalWidth',
        1080,
      );
      await page.keyboard.press('Escape');
      await expect(page.locator('[data-viewer]')).not.toBeVisible();
      await expect
        .poll(() => page.evaluate(() => scrollY))
        .toBeCloseTo(openedAt!.scroll, 0);
      await expect
        .poll(async () => (await stage.boundingBox())!.y)
        .toBeCloseTo(openedAt!.stageTop, 0);
      await expect(opener).toBeFocused();
      await expect(page.locator('[data-replay-blue]')).toHaveText('8');
      await expect(page.locator('[data-replay-red]')).toHaveText('11');
    } finally {
      await opening.evaluate((value) => value.stop());
      await opening.dispose();
    }
    expect(errors).toEqual([]);
  });

  test(`${locale.lang}: replay cards flip continuously from the approach and land with synchronized scores`, async ({
    page,
  }) => {
    await page.route(threeChunk, (route) => route.abort());
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(locale.path);
    await page.evaluate(() => document.fonts.ready);
    await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
    const stage = page.locator('[data-story-stage="replay"]');
    const cards = page.locator('[data-replay-card]');
    await expect(cards).toHaveCount(2);
    const seek = async (progress: number) => {
      await stage.evaluate(
        (element, p) =>
          scrollTo({
            top:
              Number((element as HTMLElement).dataset.replayStart) +
              (Number((element as HTMLElement).dataset.replayEnd) -
                Number((element as HTMLElement).dataset.replayStart)) *
                p,
            behavior: 'instant',
          }),
        progress,
      );
      await expect
        .poll(async () =>
          Number(await stage.getAttribute('data-replay-progress')),
        )
        .toBeCloseTo(progress, 2);
    };
    await seek(0);
    const initialSpin = await cards
      .first()
      .evaluate((element) =>
        Number(
          (element as HTMLElement).style.transform.match(
            /rotateY\(([-\d.]+)deg\)/,
          )?.[1],
        ),
      );
    await expect(page.locator('[data-replay-blue]')).toHaveText('0');
    await expect(page.locator('[data-replay-red]')).toHaveText('0');
    await expect(page.locator('.replay-card-back')).toHaveCount(2);
    for (const card of await cards.all()) {
      const depth = await card.evaluate((element) => {
        const m = new DOMMatrix(getComputedStyle(element).transform);
        return Math.abs(m.m13) + Math.abs(m.m23);
      });
      expect(depth).toBeGreaterThan(0.2);
    }
    await seek(0.45);
    await expect(page.locator('[data-replay-blue]')).toHaveText('6');
    await expect(page.locator('[data-replay-red]')).toHaveText('2');
    await expect(page.locator('[data-replay-moment="lead"]')).toHaveAttribute(
      'data-current',
      'true',
    );
    await seek(0.65);
    await expect(page.locator('[data-replay-blue]')).toHaveText('6');
    await expect(page.locator('[data-replay-red]')).toHaveText('6');
    await expect(page.locator('[data-replay-moment="tie"]')).toHaveAttribute(
      'data-current',
      'true',
    );
    await seek(0.92);
    await expect(page.locator('[data-replay-blue]')).toHaveText('8');
    await expect(page.locator('[data-replay-red]')).toHaveText('9');
    await seek(1);
    await expect(page.locator('[data-replay-blue]')).toHaveText('8');
    await expect(page.locator('[data-replay-red]')).toHaveText('11');
    const finalSpin = await cards
      .first()
      .evaluate((element) =>
        Number(
          (element as HTMLElement).style.transform.match(
            /rotateY\(([-\d.]+)deg\)/,
          )?.[1],
        ),
      );
    expect(
      finalSpin - initialSpin,
      'The main axis must complete one and a half turns.',
    ).toBeCloseTo(540, 1);
    const expectLanded = async () => {
      for (const card of await cards.all()) {
        await expect
          .poll(() =>
            card.evaluate((element) => {
              const m = new DOMMatrix(getComputedStyle(element).transform);
              return Math.max(
                Math.abs(m.m11 - 1),
                Math.abs(m.m22 - 1),
                Math.abs(m.m33 - 1),
                Math.abs(m.m12),
                Math.abs(m.m13),
                Math.abs(m.m23),
                Math.abs(m.m41),
                Math.abs(m.m42),
                Math.abs(m.m43),
              );
            }),
          )
          .toBeLessThan(0.001);
      }
      for (const caption of await page
        .locator('[data-replay-device] figcaption')
        .all())
        await expect(caption).toHaveCSS('opacity', '1');
      for (const sheen of await page.locator('[data-replay-sheen]').all())
        await expect(sheen).toHaveCSS('opacity', '0');
    };
    await expectLanded();
    const link = page.locator('[data-replay-device="summary"] .viewer-link');
    await link.focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
      'naturalWidth',
      1080,
    );
    await page.keyboard.press('Escape');
    await expect(link).toBeFocused();
    // The browser queues the dialog's close event after returning native focus.
    // Let its scroll restoration finish before starting a different navigation.
    await page.evaluate(
      () =>
        new Promise<void>((resolve) =>
          requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
        ),
    );
    for (const progress of [0.05, 0.46, 1, 0.08, 1]) await seek(progress);
    await expectLanded();
    await page.locator('.nav-download').click();
    await expect(page.locator('#download .button')).toBeInViewport();
  });

  test(`${locale.lang}: replay card motion reverts for narrow viewports and reduced motion`, async ({
    page,
  }) => {
    await page.route(threeChunk, (route) => route.abort());
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto(`${locale.path}#replay`);
    await page.evaluate(() => document.fonts.ready);
    await expect(page.locator('[data-replay-card]')).toHaveCount(2);
    for (const width of [360, 390, 768]) {
      await page.setViewportSize({ width, height: 1000 });
      for (const card of await page.locator('[data-replay-card]').all())
        await expect(card).toHaveCSS('transform', 'none');
      for (const sheen of await page.locator('[data-replay-sheen]').all())
        await expect(sheen).toHaveCSS('opacity', '0');
      expect(
        await page
          .locator('[data-replay-scroll-shell]')
          .evaluate((element) => (element as HTMLElement).style.height),
      ).toBe('');
      const offset = await page
        .locator('[data-story-stage="replay"]')
        .evaluate((element) => {
          const m = new DOMMatrix(getComputedStyle(element).transform);
          return Math.abs(m.m41) + Math.abs(m.m42) + Math.abs(m.m43);
        });
      expect(offset).toBeLessThan(0.001);
      await expectNoOverflow(page);
    }
    await page.setViewportSize({ width: 1920, height: 1080 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect(page.locator('.pin-spacer')).toHaveCount(0);
    for (const card of await page.locator('[data-replay-card]').all())
      await expect(card).toHaveCSS('transform', 'none');
    await expect(page.locator('[data-replay-blue]')).toHaveText('8');
    await expect(page.locator('[data-replay-red]')).toHaveText('11');
    await expect(page.locator('[data-replay-clip]')).toHaveAttribute(
      'width',
      '398',
    );
    for (const caption of await page
      .locator('[data-replay-device] figcaption')
      .all())
      await expect(caption).toHaveCSS('opacity', '1');
    await expectNoOverflow(page);
  });
}

test('native stage distances and reverse jumps leave replay upright and downloading usable', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 1000 });
  await page.goto('/');
  await expectDesktopPins(page);
  await expect(page.locator('[data-story-stage="scoring"]')).not.toHaveCSS(
    'position',
    'fixed',
  );
  await page.addStyleTag({ content: 'html {scroll-behavior:auto !important}' });
  for (const [chapter, extra] of [
    ['hero', 0.75],
    ['experience', 0.32],
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
    // Measure one settled layout; swapping fonts between successive boxes
    // otherwise compares positions from different document geometries.
    await page.evaluate(() => document.fonts.ready);
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
    await expect(page.locator('.replay-example-note')).toContainText('8:11');
    await expect(page.locator('.replay-example-note')).toContainText(
      locale.lang === 'zh-CN' ? '虚构' : 'Fictional',
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
  await page.evaluate((resting) => {
    const marker = document.querySelector('[data-demo-marker]')!;
    const weave = document.querySelector('[data-net-weave]')!;
    Reflect.set(window, 'hoopitoRecordedNet', null);
    const observer = new MutationObserver(() => {
      if (
        !marker.hasAttribute('hidden') &&
        weave.getAttribute('d') !== resting
      ) {
        // The recoil crosses its neutral pose at the exact marker threshold.
        // Observe a subsequent moving pose, before a driver round trip can
        // return after the entire recoil has finished.
        Reflect.set(window, 'hoopitoRecordedNet', weave.getAttribute('d'));
        observer.disconnect();
      }
    });
    observer.observe(marker.parentElement!, {
      subtree: true,
      attributes: true,
      attributeFilter: ['hidden', 'd'],
    });
  }, resting);
  await page.locator('[data-point-preset="center"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
    'hidden',
  );
  await expect
    .poll(() => page.evaluate(() => Reflect.get(window, 'hoopitoRecordedNet')))
    .not.toBeNull();
  expect(
    await page.evaluate(() => Reflect.get(window, 'hoopitoRecordedNet')),
  ).not.toBe(resting!);
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

for (const locale of locales) {
  for (const width of [390, 1440]) {
    test(`${locale.lang}: ${width}px scoring starts unselected and invites the first visible button once`, async ({
      page,
    }) => {
      await page.route(threeChunk, (route) => route.abort());
      await page.setViewportSize({ width, height: 900 });
      await page.goto(locale.path);
      const first = page.locator('[data-score-feature="0"]');
      const device = page.locator('[data-story-device]');
      await expect(first).toBeEnabled();
      await expect(device).toHaveAttribute('data-score-focus', 'none');
      await expect(
        page.locator('[data-score-feature][aria-pressed="true"]'),
      ).toHaveCount(0);
      await expect(page.locator('[data-score-step]')).toHaveText('— / 03');
      await expect(first).toHaveAttribute('data-score-invitation', 'idle');
      await expect(page.locator('[data-score-invite-arrow]')).toHaveCSS(
        'opacity',
        '0',
      );
      await page.addStyleTag({
        content: 'html{scroll-behavior:auto!important}',
      });
      await first.evaluate((element) => {
        let peak = 0;
        let dimming = 1;
        let deviceBrightness = 1;
        let deviceOpacity = 1;
        let arrowPeak = 0;
        const display = document.querySelector('.scoring-display')!;
        const observer = new MutationObserver(() => {
          peak = Math.max(
            peak,
            Number(
              (element as HTMLElement).style.getPropertyValue('--score-invite'),
            ),
          );
          dimming = Math.min(
            dimming,
            Number(
              getComputedStyle(
                document.querySelector('[data-score-feature="1"]')!,
              ).opacity,
            ),
          );
          const displayStyle = getComputedStyle(display);
          const brightness = displayStyle.filter.match(/brightness\(([^)]+)\)/);
          deviceBrightness = Math.min(
            deviceBrightness,
            brightness ? Number(brightness[1]) : 1,
          );
          deviceOpacity = Math.min(deviceOpacity, Number(displayStyle.opacity));
          arrowPeak = Math.max(
            arrowPeak,
            Number(
              getComputedStyle(
                element.querySelector('[data-score-invite-arrow]')!,
              ).opacity,
            ),
          );
        });
        observer.observe(element, {
          attributes: true,
          attributeFilter: ['style'],
        });
        Object.assign(window, {
          readScoreInvitation: () => {
            observer.disconnect();
            return {
              peak,
              dimming,
              deviceBrightness,
              deviceOpacity,
              arrowPeak,
            };
          },
        });
      });
      await first.scrollIntoViewIfNeeded();
      await expect(first).toHaveAttribute('data-score-invitation', 'playing');
      await expect(device).toHaveAttribute('data-score-focus', 'none');
      await expect(device).toHaveAttribute('data-score-playing', 'false');
      for (const region of await page.locator('[data-score-region]').all())
        await expect(region).toHaveCSS('opacity', '0');
      await expect(first).toHaveAttribute('data-score-invitation', 'done');
      const invitation = await page.evaluate(() =>
        (
          window as typeof window & {
            readScoreInvitation: () => {
              peak: number;
              dimming: number;
              deviceBrightness: number;
              deviceOpacity: number;
              arrowPeak: number;
            };
          }
        ).readScoreInvitation(),
      );
      expect(invitation.peak).toBeGreaterThan(0.5);
      expect(invitation.dimming).toBeLessThan(0.5);
      expect(invitation.deviceBrightness).toBeLessThan(0.5);
      expect(invitation.deviceOpacity).toBe(1);
      expect(invitation.arrowPeak).toBeGreaterThan(0.8);
      await expect(page.locator('.scoring-display')).toHaveCSS(
        'filter',
        'none',
      );
      await expect(page.locator('[data-score-invite-arrow]')).toHaveCSS(
        'opacity',
        '0',
      );
      for (const button of await page.locator('[data-score-feature]').all())
        await expect(button).toHaveCSS('opacity', '1');
      await page.locator('#download').scrollIntoViewIfNeeded();
      await first.scrollIntoViewIfNeeded();
      await expect(first).toHaveAttribute('data-score-invitation', 'done');
      await first.click();
      await expect(first).toHaveAttribute('aria-pressed', 'true');
      await expect(device).toHaveAttribute('data-score-focus', '0');
      await expect(device).toHaveAttribute('data-score-playing', 'true');
    });
    test(`${locale.lang}: ${width}px scoring buttons play visible, replayable operation feedback`, async ({
      page,
    }) => {
      await page.route(threeChunk, (route) => route.abort());
      await page.setViewportSize({ width, height: 900 });
      await page.goto(`${locale.path}#scoring`);
      const device = page.locator('[data-story-device]');
      const image = device.locator('img');
      const src = await image.getAttribute('src');
      const observeFeedback = (index: number) =>
        device.evaluateHandle((element, selected) => {
          const region = element.querySelector(
            `[data-score-region="${selected}"]`,
          )!;
          const action = element.querySelector(
            `[data-score-action="${selected}"]`,
          )!;
          const shade = region.querySelector('.score-shade')!;
          const observed = {
            playing: false,
            actionPeak: 0,
            shadePeak: 0,
          };
          const sample = () => {
            if (
              element.getAttribute('data-score-playing') !== 'true' ||
              element.getAttribute('data-score-focus') !== String(selected)
            )
              return;
            observed.playing = true;
            observed.actionPeak = Math.max(
              observed.actionPeak,
              Number(getComputedStyle(action).opacity),
            );
            observed.shadePeak = Math.max(
              observed.shadePeak,
              Number(getComputedStyle(shade).opacity),
            );
          };
          const observer = new MutationObserver(sample);
          observer.observe(element, {
            attributes: true,
            subtree: true,
            attributeFilter: [
              'style',
              'data-score-playing',
              'data-score-focus',
            ],
          });
          return {
            read: () => ({ ...observed }),
            stop: () => observer.disconnect(),
          };
        }, index);
      for (const ring of await page.locator('[data-score-pulse]').all())
        await expect(ring).toHaveCSS('opacity', '0');
      for (const index of [0, 1, 2]) {
        const feature = page.locator(`[data-score-feature="${index}"]`);
        const cue = page.locator(`[data-score-action="${index}"]`);
        // Record the real animation before input: sequential protocol polls can
        // miss its full-opacity plateau on a busy runner, even when it played.
        const feedback = await observeFeedback(index);
        try {
          await feature.click();
          await expect
            .poll(() => feedback.evaluate((value) => value.read().playing))
            .toBe(true);
          await expect(
            page.locator(`[data-score-region="${index}"]`),
          ).toHaveCSS('opacity', '1');
          await expect
            .poll(() => feedback.evaluate((value) => value.read().actionPeak))
            .toBe(1);
          await expect
            .poll(() => feedback.evaluate((value) => value.read().shadePeak))
            .toBeGreaterThan(0.2);
          await expect(device).toHaveAttribute('data-score-playing', 'false');
          await expect(cue).toHaveCSS('opacity', '0');
          await expect(image).toHaveAttribute('src', src!);
          await expect(feature).toHaveAttribute('aria-pressed', 'true');
        } finally {
          await feedback.evaluate((value) => value.stop());
          await feedback.dispose();
        }
        const replay = await observeFeedback(index);
        try {
          await feature.focus();
          await page.keyboard.press('Enter');
          await expect
            .poll(() => replay.evaluate((value) => value.read().playing))
            .toBe(true);
        } finally {
          await replay.evaluate((value) => value.stop());
          await replay.dispose();
        }
      }
      // A new selection cancels the old cue, even when the same button is replayed.
      await page.locator('[data-score-feature="0"]').click();
      await page.locator('[data-score-feature="2"]').click();
      await expect(page.locator('[data-score-action="0"]')).toHaveCSS(
        'opacity',
        '0',
      );
      await expect(device).toHaveAttribute('data-score-focus', '2');
      await expect(device).toHaveAttribute('data-score-playing', 'false');
      await expectNoOverflow(page);
    });
    test(`${locale.lang}: ${width}px controlled scoring clock preserves expanding rings and cue cleanup`, async ({
      page,
    }) => {
      // Install before loading GSAP so its ticker uses this clock. Frame-by-frame
      // advancement verifies the animation contract, not host rendering speed.
      await page.clock.install();
      await page.route(threeChunk, (route) => route.abort());
      await page.setViewportSize({ width, height: 900 });
      await page.goto(`${locale.path}#scoring`);
      await expect(page.locator('[data-score-feature="0"]')).toBeEnabled();
      await page.evaluate(() => document.fonts.ready);
      await page.locator('[data-story-device] img').evaluate(async (image) => {
        await (image as HTMLImageElement).decode();
      });
      await page.clock.pauseAt(await page.evaluate(() => Date.now() + 100));
      await page.clock.runFor(2000);
      const device = page.locator('[data-story-device]');
      await expect(device).toHaveAttribute('data-score-focus', 'none');
      for (const index of [0, 1, 2]) {
        const feature = page.locator(`[data-score-feature="${index}"]`);
        const action = page.locator(`[data-score-action="${index}"]`);
        const read = () =>
          action.evaluate((element) => {
            const rings = [
              ...element.querySelectorAll<SVGCircleElement>(
                '[data-score-pulse]',
              ),
            ].map((ring) => {
              const x = Number(ring.getAttribute('cx'));
              const y = Number(ring.getAttribute('cy'));
              const center = new DOMPoint(x, y).matrixTransform(
                ring.getScreenCTM()!,
              );
              return {
                radius: Number(ring.getAttribute('r')),
                opacity: Number(getComputedStyle(ring).opacity),
                x,
                y,
                screenX: center.x,
                screenY: center.y,
              };
            });
            const opacity = (selector: string) => {
              const target = element.querySelector(selector);
              return target ? Number(getComputedStyle(target).opacity) : 0;
            };
            const region = document.querySelector(
              `[data-score-region="${element.getAttribute('data-score-action')}"]`,
            )!;
            return {
              rings,
              action: Number(getComputedStyle(element).opacity),
              cursor: opacity('[data-score-cursor]'),
              head: opacity('.score-operation-head'),
              path: opacity('.score-operation-path'),
              shade: Number(
                getComputedStyle(region.querySelector('.score-shade')!).opacity,
              ),
              traces: [...region.querySelectorAll('.score-region-trace')].map(
                (trace) => ({
                  opacity: Number(getComputedStyle(trace).opacity),
                  offset: parseFloat(
                    (trace as SVGElement).style.strokeDashoffset,
                  ),
                }),
              ),
            };
          });
        const initial = await read();
        expect(initial.rings).toHaveLength(index === 0 ? 2 : 1);
        expect(initial.traces).toHaveLength(index === 0 ? 2 : 1);
        for (const ring of initial.rings) {
          expect(ring.radius).toBe(22);
          expect(ring.opacity).toBe(0);
        }
        // Real mouse/keyboard activation is covered separately. Dispatching here
        // leaves the virtual clock paused while the production handler runs.
        await feature.dispatchEvent('click');
        await expect(device).toHaveAttribute('data-score-playing', 'true');
        const samples = [initial];
        for (let elapsed = 0; elapsed < 2000; elapsed += 40) {
          await page.clock.runFor(40);
          samples.push(await read());
        }
        for (const [order, origin] of initial.rings.entries()) {
          const rings = samples.map((sample) => sample.rings[order]);
          const radii = rings.map((ring) => ring.radius);
          expect(radii.at(-1)).toBeCloseTo(112, 3);
          expect(
            new Set(radii.filter((radius) => radius > 22 && radius < 112)).size,
          ).toBeGreaterThanOrEqual(6);
          for (let frame = 1; frame < rings.length; frame++) {
            expect(radii[frame]).toBeGreaterThanOrEqual(radii[frame - 1]);
            expect(radii[frame] - radii[frame - 1]).toBeLessThan(30);
          }
          for (const ring of rings) {
            expect(ring.x).toBe(origin.x);
            expect(ring.y).toBe(origin.y);
            expect(Math.abs(ring.screenX - origin.screenX)).toBeLessThan(0.1);
            expect(Math.abs(ring.screenY - origin.screenY)).toBeLessThan(0.1);
          }
          expect(
            Math.max(...rings.map((ring) => ring.opacity)),
          ).toBeGreaterThan(0.5);
        }
        expect(Math.max(...samples.map((sample) => sample.action))).toBe(1);
        expect(Math.max(...samples.map((sample) => sample.cursor))).toBe(1);
        expect(Math.max(...samples.map((sample) => sample.shade))).toBeCloseTo(
          0.58,
          2,
        );
        expect(
          samples.some((sample) =>
            sample.traces.every(
              (trace) => trace.opacity === 1 && trace.offset === 0,
            ),
          ),
        ).toBe(true);
        if (index > 0) {
          expect(Math.max(...samples.map((sample) => sample.head))).toBe(1);
          expect(Math.max(...samples.map((sample) => sample.path))).toBe(1);
        }
        const final = samples.at(-1)!;
        expect(final.action).toBe(0);
        expect(final.cursor).toBe(0);
        expect(final.head).toBe(0);
        expect(final.path).toBe(0);
        expect(final.shade).toBe(0);
        for (const ring of final.rings) expect(ring.opacity).toBe(0);
        for (const trace of final.traces) expect(trace.opacity).toBe(0);
        await expect(device).toHaveAttribute('data-score-playing', 'false');
        await expect(feature).toHaveAttribute('aria-pressed', 'true');
      }
    });
  }
  test(`${locale.lang}: reduced motion keeps scoring explanation visible without playing an animation`, async ({
    page,
  }) => {
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(`${locale.path}#scoring`);
    await page.locator('[data-score-feature="1"]').click();
    await expect(page.locator('[data-story-device]')).toHaveAttribute(
      'data-score-playing',
      'false',
    );
    await expect(page.locator('[data-score-note]')).toHaveText(
      locale.lang === 'zh-CN'
        ? '在中央球场点选，留下出手的位置。'
        : 'Tap the court to keep a trace of your shot.',
    );
    await expect(page.locator('[data-score-region="1"]')).toHaveCSS(
      'opacity',
      '1',
    );
    await expect(page.locator('[data-score-action="1"]')).toHaveCSS(
      'opacity',
      '0',
    );
  });
}

test('scoring feedback pauses until both gallery and hidden-page reasons are released', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/#scoring');
  await page.locator('[data-score-feature="0"]').click();
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    document.dispatchEvent(new Event('visibilitychange'));
    document.querySelector<HTMLAnchorElement>('#scoring .viewer-link')!.click();
  });
  const device = page.locator('[data-story-device]');
  await page.waitForTimeout(2200);
  await expect(device).toHaveAttribute('data-score-playing', 'true');
  await page.locator('[data-viewer-close]').click();
  await page.waitForTimeout(400);
  await expect(device).toHaveAttribute('data-score-playing', 'true');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(device).toHaveAttribute('data-score-playing', 'false');
  await page.locator('[data-score-feature="2"]').click();
  await expect(device).toHaveAttribute('data-score-playing', 'true');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(device).toHaveAttribute('data-score-playing', 'false');
  await expect(page.locator('[data-score-region="2"]')).toHaveCSS(
    'opacity',
    '1',
  );
});

test('clicking during the button invitation restores the page and only selects the clicked feature', async ({
  page,
}) => {
  // The invitation lasts 1.45 seconds. Hold its clock before entering the
  // section so navigation and locator checks cannot consume the playing phase.
  await page.clock.install();
  await page.setViewportSize({ width: 390, height: 900 });
  await page.goto('/');
  const first = page.locator('[data-score-feature="0"]');
  await expect(first).toBeEnabled();
  await page.evaluate(() => document.fonts.ready);
  await page.clock.pauseAt(await page.evaluate(() => Date.now() + 100));
  await expect(first).toHaveAttribute('data-score-invitation', 'idle');
  await first.evaluate((element) =>
    element.scrollIntoView({ behavior: 'instant', block: 'center' }),
  );
  await page.clock.runFor(300);
  await expect(first).toHaveAttribute('data-score-invitation', 'playing');
  await page.locator('[data-score-feature="1"]').click();
  await expect(first).toHaveAttribute('data-score-invitation', 'done');
  await expect(first).toHaveAttribute('aria-pressed', 'false');
  await expect(page.locator('[data-score-invite-arrow]')).toHaveCSS(
    'opacity',
    '0',
  );
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-focus',
    '1',
  );
  await expect(page.locator('.scoring-display')).toHaveCSS('opacity', '1');
  await expect(page.locator('.scoring-display')).toHaveCSS('filter', 'none');
  for (const button of await page.locator('[data-score-feature]').all())
    await expect(button).toHaveCSS('opacity', '1');
});

test('reduced motion keeps the initial scoring state unselected and skips the button spotlight', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 900 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/#scoring');
  const first = page.locator('[data-score-feature="0"]');
  await first.scrollIntoViewIfNeeded();
  await expect(first).toHaveAttribute('data-score-invitation', 'done');
  await expect(first).toHaveAttribute('aria-pressed', 'false');
  await expect(page.locator('[data-score-invite-arrow]')).toHaveCSS(
    'opacity',
    '0',
  );
  await expect(page.locator('[data-story-device]')).toHaveAttribute(
    'data-score-focus',
    'none',
  );
  await expect(page.locator('.scoring-display')).toHaveCSS('opacity', '1');
  await expect(page.locator('.scoring-display')).toHaveCSS('filter', 'none');
  await expect
    .poll(async () =>
      Number(
        await first.evaluate((e) =>
          getComputedStyle(e).getPropertyValue('--score-invite'),
        ),
      ),
    )
    .toBe(0);
});

for (const width of [390, 1440]) {
  for (const index of [1, 2]) {
    test(`${width}px operation arrows ${index} stay connected and face the drawing direction throughout reveal`, async ({
      page,
    }) => {
      // Geometry needs every reveal phase, independent of host load. This
      // controlled browser clock is not a measurement of display frame rate.
      await page.clock.install();
      await page.route(threeChunk, (route) => route.abort());
      await page.setViewportSize({ width, height: 900 });
      await page.goto('/#scoring');
      await expect(page.locator('[data-score-feature="0"]')).toBeEnabled();
      await page.evaluate(() => document.fonts.ready);
      // install() still lets the fake clock follow wall time. Pause it after
      // loading so locator checks cannot advance beyond the sampled phase.
      await page.clock.pauseAt(await page.evaluate(() => Date.now() + 100));
      await page.clock.runFor(2000);
      const action = page.locator(`[data-score-action="${index}"]`);
      await expect(action.locator('.score-operation-head')).toHaveCount(1);
      await action.evaluate((element) => {
        const path = element.querySelector<SVGPathElement>(
          '.score-operation-path',
        )!;
        const head = element.querySelector<SVGPathElement>(
          '.score-operation-head',
        )!;
        const length = path.getTotalLength();
        const samples: { distance: number; gap: number; alignment: number }[] =
          [];
        const observer = new MutationObserver(() => {
          const distance = length - parseFloat(path.style.strokeDashoffset);
          if (!(distance > 0) || getComputedStyle(head).opacity === '0') return;
          const numbers = head
            .getAttribute('d')
            ?.match(/-?\d+(?:\.\d+)?(?:e[+-]?\d+)?/g)
            ?.map(Number);
          if (!numbers || numbers.length !== 6) return;
          const [ax, ay, ex, ey, bx, by] = numbers;
          const tip = path.getPointAtLength(distance);
          const before = path.getPointAtLength(Math.max(0, distance - 0.5));
          const after = path.getPointAtLength(Math.min(length, distance + 0.5));
          const tx = after.x - before.x,
            ty = after.y - before.y;
          const hx = ex - (ax + bx) / 2,
            hy = ey - (ay + by) / 2;
          samples.push({
            distance,
            gap: Math.hypot(ex - tip.x, ey - tip.y),
            alignment:
              (tx * hx + ty * hy) / (Math.hypot(tx, ty) * Math.hypot(hx, hy)),
          });
        });
        observer.observe(head, { attributes: true, attributeFilter: ['d'] });
        Object.assign(window, {
          readArrowReveal: () => {
            observer.disconnect();
            return { length, samples };
          },
        });
      });
      await page.locator(`[data-score-feature="${index}"]`).click();
      await page.clock.runFor(600);
      await expect(action.locator('[data-score-cursor]')).toHaveCSS(
        'opacity',
        '0',
      );
      await expect(action.locator('.score-operation-head')).toHaveCSS(
        'opacity',
        '1',
      );
      await page.clock.runFor(800);
      // The pointer takes over after the directional cue, keeping the head readable.
      await expect(action.locator('.score-operation-head')).toHaveCSS(
        'opacity',
        '0',
      );
      await expect(action.locator('[data-score-cursor]')).toHaveCSS(
        'opacity',
        '1',
      );
      await page.clock.runFor(600);
      await expect(page.locator('[data-story-device]')).toHaveAttribute(
        'data-score-playing',
        'false',
      );
      const result = await page.evaluate(() =>
        (
          window as typeof window & {
            readArrowReveal: () => {
              length: number;
              samples: { distance: number; gap: number; alignment: number }[];
            };
          }
        ).readArrowReveal(),
      );
      expect(result.samples.length).toBeGreaterThan(8);
      expect(Math.max(...result.samples.map((s) => s.gap))).toBeLessThan(0.02);
      expect(
        Math.min(...result.samples.map((s) => s.alignment)),
      ).toBeGreaterThan(0.99);
      expect(result.samples.at(-1)!.distance).toBeCloseTo(result.length, 2);
    });
  }
}

test('scoring flows naturally and changes its explanation only on button activation', async ({
  page,
}) => {
  await page.route(threeChunk, (route) => route.abort());
  await page.goto('/#scoring');
  await expect(page.locator('[data-score-feature="0"]')).toBeEnabled();
  await page.addStyleTag({ content: 'html {scroll-behavior:auto !important}' });
  const stage = page.locator('[data-story-stage="scoring"]');
  const device = page.locator('[data-story-device]');
  await expect(page.locator('[data-score-controls]')).toHaveAttribute(
    'data-guide-mode',
    'click',
  );
  await expect(page.locator('[data-score-resume]')).toHaveCount(0);
  expect(
    await stage.evaluate((e) =>
      e.parentElement!.classList.contains('pin-spacer'),
    ),
  ).toBe(false);
  await expect(device).toHaveAttribute('data-score-focus', 'none');
  await page.evaluate(() => document.fonts.ready);
  // End the initial anchor intent as a user would before testing free scroll.
  // Otherwise a pending navigation refresh can move between protocol reads.
  await page.keyboard.press('Shift');
  const flow = await stage.evaluate(async (element) => {
    const frame = () =>
      new Promise<void>((resolve) => requestAnimationFrame(() => resolve()));
    await frame();
    await frame();
    window.scrollTo({
      top: scrollY + element.getBoundingClientRect().top - 110,
      behavior: 'instant',
    });
    await frame();
    await frame();
    const read = () => ({
      y: element.getBoundingClientRect().y,
      scroll: scrollY,
    });
    // Read both coordinate systems in one task; do not attribute unrelated
    // scrolling between Playwright calls to the stage's own positioning.
    const before = read();
    window.scrollBy({ top: 200, behavior: 'instant' });
    const after = read();
    await frame();
    await frame();
    return { before, after, settled: read() };
  });
  expect(flow.after.scroll - flow.before.scroll).toBeCloseTo(200, 0);
  for (const sample of [flow.after, flow.settled]) {
    expect(flow.before.y - sample.y).toBeCloseTo(
      sample.scroll - flow.before.scroll,
      0,
    );
    expect(sample.y + sample.scroll).toBeCloseTo(
      flow.before.y + flow.before.scroll,
      0,
    );
  }
  await expect(device).toHaveAttribute('data-score-focus', 'none');
  await page.locator('[data-score-feature="2"]').click();
  await expect(device).toHaveAttribute('data-score-focus', '2');
  await expect(page.locator('[data-score-step]')).toHaveText('03 / 03');
  await page.locator('#download').scrollIntoViewIfNeeded();
  await stage.scrollIntoViewIfNeeded();
  await expect(device).toHaveAttribute('data-score-focus', '2');
  const feature = page.locator('[data-score-feature="1"]');
  await feature.focus();
  await expect(device).toHaveAttribute('data-score-focus', '2');
  await page.keyboard.press('Enter');
  await expect(device).toHaveAttribute('data-score-focus', '1');
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(device).toHaveAttribute('data-score-focus', '1');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(device).toHaveAttribute('data-score-focus', '1');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await page.setViewportSize({ width: 1440, height: 900 });
  await stage.scrollIntoViewIfNeeded();
  await expect(device).toHaveAttribute('data-score-focus', '1');
  expect(await device.evaluate((e) => getComputedStyle(e).transform)).toBe(
    'none',
  );
});

for (const locale of locales) {
  test(`${locale.lang}: scoring guide names the marked operation and keeps mobile selection readable`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(`${locale.path}#scoring`);
    const controls = page.locator('[data-score-controls]');
    await expect(controls).toHaveAttribute('data-guide-mode', 'click');
    for (const index of [0, 1, 2]) {
      const feature = page.locator(`[data-score-feature="${index}"]`);
      await feature.focus();
      await page.keyboard.press(index === 2 ? 'Space' : 'Enter');
      await expect(feature).toHaveAttribute('aria-pressed', 'true');
      await expect(page.locator('[data-score-current]')).toHaveText(
        (await feature.locator('strong').textContent())!,
      );
      await expect(page.locator('[data-score-step]')).toHaveText(
        `0${index + 1} / 03`,
      );
      await expect(page.locator(`[data-score-region="${index}"]`)).toHaveCSS(
        'opacity',
        '1',
      );
      await expect(page.locator('[data-score-resume]')).toHaveCount(0);
    }
    await expectNoOverflow(page);
  });
  test(`${locale.lang}: scoring buttons remain readable in natural flow`, async ({
    page,
  }) => {
    await page.route(threeChunk, (route) => route.abort());
    await page.goto(`${locale.path}#scoring`);
    await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
    await page.locator('[data-score-feature="2"]').click();
    const controls = page.locator('[data-score-controls]');
    await expect(controls).toHaveAttribute('data-guide-mode', 'click');
    await controls.scrollIntoViewIfNeeded();
    await expect(controls).toBeInViewport({ ratio: 1 });
    for (const button of await page.locator('[data-score-feature]').all())
      await expect(button).toBeInViewport({ ratio: 1 });
  });
}

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
  await expectDesktopPins(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
  await expectNoOverflow(page);
  await page.setViewportSize({ width: 1440, height: 900 });
  await expectDesktopPins(page);
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
  await expect(page.locator('h1')).toBeVisible();
  await expectDownload(page);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await expectDesktopPins(page);
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
  await expectDesktopPins(page);

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
  await expectDesktopPins(page);
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
  await expectDesktopPins(page);
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
  await expectDesktopPins(page);
});

async function expectDownload(page: Page) {
  await expect(page.locator('[data-download]').first()).toBeVisible();
  for (const link of await page.locator('[data-download]').all()) {
    await expect(link).toHaveAttribute('href', apk);
    await expect(link).toHaveAttribute('aria-haspopup', 'dialog');
    await expect(link).toHaveAttribute('aria-controls', 'download-dialog');
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
      .every((url) => new URL(url).origin === new URL(page.url()).origin),
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

// Delay adoption after the real renderer is prepared, so the DOM shot can be
// held at a deterministic flight or rebound instant without faking Three.
async function delayCourtAdoption(page: Page) {
  await allowSoftwareWebGL(page);
  // Only the scene entry exports this factory; production also splits a
  // court-engine dependency chunk that must pass through untouched.
  await page.route(/court-scene[^/]*\.(?:js|ts)(?:\?|$)/, async (route) => {
    const response = await route.fetch();
    let body = await response.text();
    const exports = body.match(/export\s*\{([^}]*\bcreateCourtScene\b[^}]*)\}/);
    let factory = exports?.[1].match(
      /(?:^|,)\s*([\w$]+)\s+as\s+createCourtScene\b/,
    )?.[1];
    if (exports && factory) {
      body = body.replace(
        exports[0],
        exports[0].replace(
          /[\w$]+\s+as\s+createCourtScene\b/,
          '__lateCourtCreate as createCourtScene',
        ),
      );
    } else if (/export async function createCourtScene\(/.test(body)) {
      factory = '__lateCourtOriginal';
      body = body.replace(
        /export async function createCourtScene\(/,
        'async function __lateCourtOriginal(',
      );
      body += '\nexport { __lateCourtCreate as createCourtScene };\n';
    } else throw new Error('The real scene factory must be wrapped');
    const gsapName = body.match(/([\w$]+)\.timeline\(\)/)?.[1];
    if (!gsapName) throw new Error('The real shot timeline must be observable');
    body += `\nasync function __lateCourtCreate(...args) {
      const scene = await ${factory}(...args);
      // The test owns this prepared scene until adoption. Do not animate an
      // unadopted hero behind the loading poster while the factory is gated.
      scene.setPaused(true);
      let adopt;
      const gate = new Promise(resolve => { adopt = resolve; });
      let shot;
      const shoot = scene.shoot.bind(scene);
      scene.shoot = (point, elapsed) => {
        const before = new Set(${gsapName}.globalTimeline.getChildren(false));
        shoot(point, elapsed);
        const timeline = ${gsapName}.globalTimeline.getChildren(false)
          .find(candidate => !before.has(candidate));
        shot = { elapsed, timeline };
      };
      Reflect.set(window, '__lateCourt', {
        adopt,
        adoptAt(time) {
          Object.defineProperty(document, 'hidden', { configurable: true, value: true });
          document.dispatchEvent(new Event('visibilitychange'));
          const domShot = ${gsapName}.globalTimeline.getChildren(false)
            .find(candidate => candidate.vars.time === 2.13 && candidate.vars.duration === 2.13);
          if (!domShot) throw new Error('The real DOM shot clock must be active');
          domShot.time(time, false);
          adopt();
        },
        read: () => shot ? {
          elapsed: shot.elapsed, time: shot.timeline?.time(),
          duration: shot.timeline?.duration(), paused: shot.timeline?.paused(),
        } : null,
      });
      await gate;
      return scene;
    }\n`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
}

test(
  'the desktop loading poster does not consume the court invitation before input is ready',
  { tag: '@webgl', lock: 'webgl-renderer' },
  async ({ page }, testInfo) => {
    test.skip(testInfo.project.name !== 'chromium', 'Real renderer lifecycle');
    await delayCourtAdoption(page);
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.goto('/#experience', { waitUntil: 'domcontentloaded' });
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-scene-ready',
      'true',
    );
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-rendering',
      'paused',
    );
    const preparedCount = await page
      .locator('#court-canvas')
      .getAttribute('data-render-count');
    const host = page.locator('[data-demo-court-host]');
    await host.scrollIntoViewIfNeeded();
    await page.waitForTimeout(1750);
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-render-count',
      preparedCount!,
    );
    await expect(page.locator('html')).toHaveAttribute('data-scene', 'loading');
    await expect(host).toHaveAttribute('data-demo-invitation', 'idle');
    await page.evaluate(() => Reflect.get(window, '__lateCourt').adopt());
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    await expect(host).toHaveAttribute('data-demo-invitation', 'playing');
    await expect(host).toHaveAttribute('data-demo-invitation', 'done');
  },
);

for (const elapsed of [0.46, 1.7]) {
  test(
    `late 3D adoption resumes the suspended shot at ${elapsed}s without restarting its flight or rebound`,
    { tag: '@webgl', lock: 'webgl-renderer' },
    async ({ page }, testInfo) => {
      test.skip(
        testInfo.project.name !== 'chromium',
        'Real renderer lifecycle',
      );
      await delayCourtAdoption(page);
      await page.setViewportSize({ width: 1440, height: 1000 });
      await page.goto('/#experience', { waitUntil: 'domcontentloaded' });
      await expect(page.locator('#court-canvas')).toHaveAttribute(
        'data-scene-ready',
        'true',
      );
      await page.locator('[data-point-preset="center"]').click();
      // Advance the real DOM shot clock while suspended. GPU scheduling and
      // GSAP lag smoothing make wall-clock sleeps unsuitable for exact phases.
      await page.locator('[data-record]').evaluate((element, seconds) => {
        (element as HTMLButtonElement).click();
        Reflect.get(window, '__lateCourt').adoptAt(seconds);
      }, elapsed);
      await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
      const read = () =>
        page.evaluate(() =>
          Reflect.get(window, '__lateCourt').read(),
        ) as Promise<{
          elapsed: number;
          time: number;
          duration: number;
          paused: boolean;
        }>;
      const adopted = await read();
      expect(adopted).not.toBeNull();
      expect(adopted.elapsed).toBeCloseTo(elapsed, 5);
      expect(adopted.time).toBeCloseTo(adopted.elapsed, 5);
      expect(adopted.duration).toBeCloseTo(2.13, 5);
      expect(adopted.paused).toBe(true);
      await page.waitForTimeout(300);
      expect((await read()).time).toBe(adopted.time);
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
      await expect.poll(async () => (await read()).time).toBeCloseTo(2.13, 5);
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await page.locator('[data-reset]').click();
      await expectReset(page);
    },
  );
}

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
      await expect(
        page.locator('.scene-background > #court-canvas'),
      ).toHaveAttribute('data-presented-chapter', 'experience');
      await expect(page.locator('#court-canvas')).toHaveAttribute(
        'data-camera-view',
        'overhead',
      );
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
              // The native API converts positive GLsizei arguments to integers;
              // CDP density can leave tiny fractions in Three.js's JS values.
              buffers.push({
                samples,
                width: Math.trunc(width),
                height: Math.trunc(height),
              });
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
          .toBeCloseTo(nextScale, 6);
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
    const resumed = await count();
    await page.emulateMedia({ reducedMotion: 'no-preference' });
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
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    // The transparent host forwards a real pointer release to the background court.
    const host = page.locator('[data-demo-court-host]');
    const bounds = (await host.boundingBox())!;
    await host.click({
      position: { x: bounds.width * 0.5, y: bounds.height * 0.63 },
    });
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
