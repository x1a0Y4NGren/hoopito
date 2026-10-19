import { expect, test, type Page } from '@playwright/test';
import type { CourtPoint, CourtScene } from '../src/scripts/scene-contract';

const sceneChunk = /court-scene[^/]*\.(?:js|ts)(?:\?|$)/;
const webgl = { tag: '@webgl', lock: 'webgl-renderer' };
type CourtProbe = {
  scene: CourtScene;
  creations: number;
  canvas: HTMLCanvasElement;
  context: WebGL2RenderingContext;
  removals: number;
};

async function allowSoftwareWebGL(page: Page) {
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

// Wrap the real dynamic-module factory at the network boundary. No scene,
// camera, input handler or renderer is replaced, and production has no globals.
async function exposeSceneInTest(page: Page) {
  await allowSoftwareWebGL(page);
  await page.route(sceneChunk, async (route) => {
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
          '__courtTestCreate as createCourtScene',
        ),
      );
    } else if (/export async function createCourtScene\(/.test(body)) {
      factory = '__courtTestOriginal';
      body = body.replace(
        /export async function createCourtScene\(/,
        'async function __courtTestOriginal(',
      );
      body += '\nexport { __courtTestCreate as createCourtScene };\n';
    } else {
      throw new Error('The page must export the real createCourtScene factory');
    }
    body += `\nasync function __courtTestCreate(...args) {
      const scene = await ${factory}(...args);
      const previous = Reflect.get(window, '__courtTest');
      const canvas = args[0];
      const probe = {
        scene, canvas, context: canvas.getContext('webgl2'),
        creations: (previous?.creations ?? 0) + 1, removals: 0,
      };
      new MutationObserver((records) => {
        for (const record of records) for (const node of record.removedNodes)
          if (node === canvas || (node instanceof Element && node.contains(canvas)))
            probe.removals += 1;
      }).observe(document, { childList: true, subtree: true });
      Reflect.set(window, '__courtTest', probe);
      return scene;
    }\n`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
}

async function observeCourtDraws(page: Page) {
  await page.addInitScript(() => {
    Reflect.set(window, '__courtDrawCalls', 0);
    for (const method of [
      'drawElements',
      'drawArrays',
      'drawElementsInstanced',
      'drawArraysInstanced',
    ] as const) {
      const original = WebGL2RenderingContext.prototype[method];
      Reflect.set(
        WebGL2RenderingContext.prototype,
        method,
        function (this: WebGL2RenderingContext, ...args: unknown[]) {
          Reflect.set(
            window,
            '__courtDrawCalls',
            Number(Reflect.get(window, '__courtDrawCalls')) + 1,
          );
          return Reflect.apply(original, this, args);
        },
      );
    }
  });
  return () =>
    page.evaluate(() => Number(Reflect.get(window, '__courtDrawCalls')));
}

async function readyExperience(page: Page, path = '/#experience') {
  await page.goto(path);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
  await page.evaluate(() => document.fonts.ready);
  await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
  await expect(page.locator('html')).toHaveAttribute(
    'data-interactive',
    'true',
  );
  await expect(page.locator('#court-canvas')).toHaveAttribute(
    'data-placement-blend',
    '1.0000',
  );
}

async function project(page: Page, point: CourtPoint) {
  const client = await page.evaluate(
    (value) =>
      (Reflect.get(window, '__courtTest') as CourtProbe).scene.projectPoint(
        value,
      ),
    point,
  );
  expect(
    client,
    'the real scene must project a finite CSS client point',
  ).not.toBeNull();
  return client!;
}

async function scrollToPosition(page: Page, top: number) {
  await page.evaluate(
    (value) =>
      new Promise<void>((resolve) => {
        scrollTo({ top: value, behavior: 'instant' });
        requestAnimationFrame(() => requestAnimationFrame(() => resolve()));
      }),
    top,
  );
}

async function enterNativeExperience(page: Page) {
  const top = await page
    .locator('[data-story-stage="experience"]')
    .evaluate((element) => {
      const stage = element as HTMLElement;
      return stage.parentElement!.classList.contains('pin-spacer')
        ? Number(stage.dataset.storyStart)
        : scrollY + stage.getBoundingClientRect().top - 88;
    });
  await scrollToPosition(page, top);
  await expect(page.locator('html')).toHaveAttribute(
    'data-interactive',
    'true',
  );
}

async function assertBackgroundIdentity(page: Page) {
  await expect(page.locator('.scene-background > #court-canvas')).toHaveCount(
    1,
  );
  await expect(page.locator('[data-demo-court-host] canvas')).toHaveCount(0);
  await expect(page.locator('canvas')).toHaveCount(1);
  const state = await page.evaluate(() => {
    const probe = Reflect.get(window, '__courtTest') as CourtProbe;
    const canvas = document.querySelector<HTMLCanvasElement>('#court-canvas')!;
    const bounds = canvas.getBoundingClientRect();
    return {
      sameCanvas: canvas === probe.canvas,
      sameContext: canvas.getContext('webgl2') === probe.context,
      creations: probe.creations,
      removals: probe.removals,
      widthError: Math.abs(bounds.width - innerWidth * 0.48),
    };
  });
  expect(state).toMatchObject({
    sameCanvas: true,
    sameContext: true,
    creations: 1,
    removals: 0,
  });
  expect(state.widthError).toBeLessThan(1);
}

async function doubleTextSize(page: Page) {
  await page.evaluate(() => {
    const nodes = [...document.querySelectorAll<HTMLElement>('body *')].filter(
      (element) =>
        [...element.childNodes].some(
          (node) =>
            node.nodeType === Node.TEXT_NODE && node.textContent?.trim(),
        ),
    );
    const sizes = nodes.map(
      (element) =>
        [element, parseFloat(getComputedStyle(element).fontSize)] as const,
    );
    for (const [element, size] of sizes)
      element.style.fontSize = `${size * 2}px`;
    dispatchEvent(new Event('resize'));
  });
  await expect(page.locator('.pin-spacer')).toHaveCount(0);
}

for (const viewport of [
  { width: 1440, height: 900 },
  { width: 1440, height: 1000 },
  { width: 1920, height: 1080 },
]) {
  test(
    `dense overhead arrival at ${viewport.width} by ${viewport.height} keeps each scroll pixel within 2px and half a degree in both directions`,
    webgl,
    async ({ page }, testInfo) => {
      test.skip(
        testInfo.project.name !== 'chromium',
        'Real WebGL projection runs in Chromium.',
      );
      await page.setViewportSize(viewport);
      await exposeSceneInTest(page);
      await readyExperience(page, '/en/#experience');
      // Cancel the initial anchor intent before seeking the native timeline.
      await page.mouse.wheel(0, -1);
      const stage = page.locator('[data-story-stage="experience"]');
      await expect
        .poll(() =>
          stage.evaluate((element) =>
            element.parentElement!.classList.contains('pin-spacer'),
          ),
        )
        .toBe(true);
      const samples = await page.evaluate(async () => {
        const { scene } = Reflect.get(window, '__courtTest') as CourtProbe;
        const stage = document.querySelector<HTMLElement>(
          '[data-story-stage="experience"]',
        )!;
        const host = document.querySelector('[data-demo-court-host]')!;
        const rest = Number(stage.dataset.storyStart);
        const floorPoints = [
          { x: 0, y: 0 },
          { x: 1, y: 0 },
          { x: 0, y: 1 },
          { x: 1, y: 1 },
          { x: 0.2, y: 0.8 },
        ];
        const read = () => {
          const bounds = host.getBoundingClientRect();
          const lineStart = scene.projectPoint({ x: 0.25, y: 0.5 })!;
          const lineEnd = scene.projectPoint({ x: 0.75, y: 0.5 })!;
          const arrival = Math.max(
            0,
            Math.min(
              1,
              (innerHeight * 0.85 - stage.getBoundingClientRect().top) /
                (innerHeight * 0.85 - 88),
            ),
          );
          return {
            scroll: scrollY,
            host: { x: bounds.left, y: bounds.top },
            points: floorPoints.map((point) => scene.projectPoint(point)!),
            roll: Math.atan2(lineEnd.y - lineStart.y, lineEnd.x - lineStart.x),
            lineLength: Math.hypot(
              lineEnd.x - lineStart.x,
              lineEnd.y - lineStart.y,
            ),
            rawBlend: arrival * arrival * (3 - 2 * arrival),
            blend:
              document.querySelector<HTMLElement>('#court-canvas')!.dataset
                .placementBlend,
            chapter: document.documentElement.dataset.chapter,
          };
        };
        const seek = async (offset: number) => {
          scrollTo({ top: rest + offset, behavior: 'instant' });
          await new Promise<void>((resolve) =>
            requestAnimationFrame(() => requestAnimationFrame(() => resolve())),
          );
          return { offset, ...read() };
        };
        const forward = [];
        for (let offset = -60; offset <= 2; offset += 1)
          forward.push(await seek(offset));
        const reverse = [];
        for (let offset = 2; offset >= -60; offset -= 1)
          reverse.push(await seek(offset));
        return { forward, reverse };
      });
      await testInfo.attach('dense-overhead-arrival', {
        body: JSON.stringify(samples),
        contentType: 'application/json',
      });
      for (const direction of ['forward', 'reverse'] as const) {
        const values = samples[direction];
        for (const sample of values) {
          expect(sample.chapter).toBe('experience');
          expect(sample.lineLength).toBeGreaterThan(100);
          for (const point of sample.points) {
            expect(point).not.toBeNull();
            expect(Number.isFinite(point.x) && Number.isFinite(point.y)).toBe(
              true,
            );
          }
        }
        for (let index = 1; index < values.length; index += 1) {
          const previous = values[index - 1],
            current = values[index];
          const angle = current.roll - previous.roll;
          const rollDelta = Math.abs(
            (Math.atan2(Math.sin(angle), Math.cos(angle)) * 180) / Math.PI,
          );
          const label = `${direction} offsets ${previous.offset} → ${current.offset}`;
          expect(rollDelta, `${label}: screen rotation`).toBeLessThan(0.5);
          for (
            let pointIndex = 0;
            pointIndex < current.points.length;
            pointIndex += 1
          ) {
            const from = previous.points[pointIndex],
              to = current.points[pointIndex];
            // Remove only measured host travel. The pin stops that travel at
            // 88px, so subtracting scrollY itself would hide an endpoint jump.
            const dx = to.x - from.x - (current.host.x - previous.host.x);
            const dy = to.y - from.y - (current.host.y - previous.host.y);
            expect(
              Math.hypot(dx, dy),
              `${label}: floor point ${pointIndex}`,
            ).toBeLessThanOrEqual(2);
          }
        }
      }
      const clampCrossing = samples.forward.findIndex(
        (sample, index, values) =>
          index > 0 &&
          values[index - 1].rawBlend < 0.99999 &&
          sample.rawBlend >= 0.99999,
      );
      expect(
        clampCrossing,
        'native samples must straddle both sides of the endpoint clamp',
      ).toBeGreaterThan(0);
      for (const offset of [-2, -1, 0, 1, 2]) {
        const forward = samples.forward.find(
          (sample) => sample.offset === offset,
        )!;
        const reverse = samples.reverse.find(
          (sample) => sample.offset === offset,
        )!;
        for (let index = 0; index < forward.points.length; index += 1) {
          const a = forward.points[index],
            b = reverse.points[index];
          expect(
            Math.hypot(a.x - b.x, a.y - b.y),
            `same native position at offset ${offset}`,
          ).toBeLessThanOrEqual(2);
        }
      }
      await assertBackgroundIdentity(page);
    },
  );
}

for (const path of ['/', '/en/']) {
  test(
    `${path}: 200 percent desktop text keeps the aligned experience anchor ready for real court input`,
    webgl,
    async ({ page }, testInfo) => {
      test.skip(
        testInfo.project.name !== 'chromium',
        'Real WebGL input runs in Chromium.',
      );
      await page.setViewportSize({ width: 1440, height: 900 });
      await exposeSceneInTest(page);
      await page.goto(path);
      await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
      await page.evaluate(() => document.fonts.ready);
      await doubleTextSize(page);
      await page.locator('.site-header a[href="#experience"]').click();
      await expect
        .poll(() =>
          page
            .locator('#experience .section-top')
            .evaluate((heading) =>
              Math.abs(
                heading.getBoundingClientRect().top -
                  document
                    .querySelector('.site-header')!
                    .getBoundingClientRect().bottom -
                  20,
              ),
            ),
        )
        .toBeLessThan(2);
      await expect(page.locator('html')).toHaveAttribute(
        'data-interactive',
        'true',
      );
      await expect(page.locator('#court-canvas')).toHaveAttribute(
        'data-placement-blend',
        '1.0000',
      );
      const point = { x: 0.37, y: 0.35 };
      const client = await project(page, point);
      expect(client.y).toBeLessThan(900);
      const recovered = await page.evaluate((position) => {
        const { scene } = Reflect.get(window, '__courtTest') as CourtProbe;
        const point = scene.pointFromClient(position.x, position.y);
        return point && { point, client: scene.projectPoint(point) };
      }, client);
      expect(recovered).not.toBeNull();
      expect(
        Math.hypot(
          recovered!.client!.x - client.x,
          recovered!.client!.y - client.y,
        ),
      ).toBeLessThanOrEqual(2);
      await page.mouse.click(client.x, client.y);
      await expect(page.locator('[data-record]')).toBeEnabled();
      await expect(page.locator('[data-blue-score]')).toHaveText('6');
      const selection = await page
        .locator('[data-demo-selection]')
        .evaluate((element) => {
          const matrix = (
            element as SVGGElement
          ).transform.baseVal.consolidate()!.matrix;
          return { x: (matrix.e - 28) / 544, y: (matrix.f - 28) / 504 };
        });
      expect(selection.x).toBeCloseTo(point.x, 3);
      expect(selection.y).toBeCloseTo(point.y, 3);
      await assertBackgroundIdentity(page);
    },
  );
}

for (const textScale of [1, 2]) {
  test(
    `actual experience to replay projection survives its boundary and rapid reversal at ${textScale}x text`,
    webgl,
    async ({ page }, testInfo) => {
      test.skip(
        testInfo.project.name !== 'chromium',
        'Real WebGL projection runs in Chromium.',
      );
      await page.setViewportSize({ width: 1440, height: 1000 });
      await exposeSceneInTest(page);
      await readyExperience(page, '/en/#experience');
      if (textScale === 2) await doubleTextSize(page);
      await page.mouse.wheel(0, -1);
      const targets = await page.evaluate(() => {
        const stage = document.querySelector<HTMLElement>(
          '[data-story-stage="experience"]',
        )!;
        const stageBounds = stage.getBoundingClientRect();
        const heading = document
          .querySelector('#experience .section-top')!
          .getBoundingClientRect();
        const arrivalEnd =
          document.querySelector('.site-header')!.getBoundingClientRect()
            .bottom +
          20 -
          (heading.top - stageBounds.top);
        return {
          rest: stage.parentElement!.classList.contains('pin-spacer')
            ? Number(stage.dataset.storyStart) + innerHeight * 0.16
            : scrollY + stageBounds.top - arrivalEnd,
          boundary:
            scrollY +
            document.querySelector('#replay')!.getBoundingClientRect().top -
            Math.min(innerHeight * 0.3, 260),
          after: innerHeight * 0.2,
        };
      });
      const snapshot = async () =>
        page.evaluate(() => {
          const { scene } = Reflect.get(window, '__courtTest') as CourtProbe;
          return {
            points: [
              { x: 0.3, y: 0.4 },
              { x: 0.7, y: 0.7 },
            ].map((point) => scene.projectPoint(point)!),
            y: scrollY,
            camera: {
              ...document.querySelector<HTMLElement>('#court-canvas')!.dataset,
            },
            replay: {
              ...document.querySelector<HTMLElement>(
                '[data-story-stage="replay"]',
              )!.dataset,
            },
          };
        });
      for (const direction of [1, -1]) {
        const pair = [];
        for (const offset of [-2 * direction, 2 * direction]) {
          await scrollToPosition(page, targets.boundary + offset);
          await expect(page.locator('#court-canvas')).toHaveAttribute(
            'data-chapter',
            offset < 0 ? 'experience' : 'replay',
          );
          pair.push(await snapshot());
        }
        await testInfo.attach(`boundary-${direction}`, {
          body: JSON.stringify(pair),
          contentType: 'application/json',
        });
        for (let index = 0; index < pair[0].points.length; index += 1) {
          const a = pair[0].points[index],
            b = pair[1].points[index];
          // Remove the known four CSS pixels of native page travel; the camera
          // composition itself must join within the same 2px projection budget.
          expect(
            Math.hypot(a.x - b.x, a.y + pair[0].y - b.y - pair[1].y),
          ).toBeLessThanOrEqual(2);
        }
      }
      const references = new Map<
        number,
        Awaited<ReturnType<typeof snapshot>>
      >();
      for (const top of [
        targets.rest,
        targets.boundary + targets.after,
        targets.rest,
        targets.boundary - 2,
        targets.boundary + targets.after,
        targets.boundary - 2,
        targets.rest,
      ]) {
        await scrollToPosition(page, top);
        const current = await snapshot();
        const previous = references.get(top);
        if (previous)
          for (let index = 0; index < previous.points.length; index += 1) {
            const a = previous.points[index],
              b = current.points[index];
            expect(Math.hypot(a.x - b.x, a.y - b.y)).toBeLessThanOrEqual(2);
          }
        else references.set(top, current);
        await assertBackgroundIdentity(page);
      }
    },
  );
}

test(
  'native chapter travel keeps the background canvas and context inside an unframed interaction region',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Real WebGL lifecycle runs in Chromium.',
    );
    await page.setViewportSize({ width: 1440, height: 1000 });
    await exposeSceneInTest(page);
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await page.addStyleTag({ content: 'html{scroll-behavior:auto!important}' });
    for (const id of [
      'hero',
      'scoring',
      'experience',
      'replay',
      'experience',
      'scoring',
      'hero',
    ]) {
      await page
        .locator(`#${id}`)
        .evaluate((element) =>
          element.scrollIntoView({ behavior: 'instant', block: 'start' }),
        );
      await expect(page.locator('html')).toHaveAttribute('data-chapter', id);
      await assertBackgroundIdentity(page);
    }
    // A native scroll reaches the resting stage; section.scrollIntoView stops
    // at the section's reading offset, before the camera finishes its arrival.
    await enterNativeExperience(page);
    for (const selector of ['.demo-map', '[data-demo-court-host]']) {
      const frame = page.locator(selector);
      await expect(frame).toHaveCSS('background-color', 'rgba(0, 0, 0, 0)');
      await expect(frame).toHaveCSS('box-shadow', 'none');
      await expect(frame).toHaveCSS('border-top-width', '0px');
      await expect(frame).toHaveCSS('border-right-width', '0px');
      await expect(frame).toHaveCSS('border-bottom-width', '0px');
      await expect(frame).toHaveCSS('border-left-width', '0px');
    }
    await expect(page.locator('.demo-map')).not.toContainText(
      /THE SHOT LAB|LIVE COURT|COURT VIEW/,
    );
    await assertBackgroundIdentity(page);
  },
);

test(
  'the camera blends through native entry, holds overhead for 0.32 viewport and reverses continuously',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Real camera projection runs in Chromium.',
    );
    await page.setViewportSize({ width: 1440, height: 1000 });
    await exposeSceneInTest(page);
    await readyExperience(page);
    const range = await page
      .locator('[data-story-stage="experience"]')
      .evaluate((element) => {
        const stage = element as HTMLElement;
        return {
          start: Number(stage.dataset.storyStart),
          end: Number(stage.dataset.storyEnd),
          height: innerHeight,
        };
      });
    expect(range.end - range.start).toBeCloseTo(range.height * 0.32, 0);
    const entryStart = range.start + 88 - range.height * 0.85;
    const samples: { blend: number; client: { x: number; y: number } }[] = [];
    for (const progress of [0, 0.25, 0.5, 0.75, 1]) {
      await scrollToPosition(
        page,
        entryStart + (range.start - entryStart) * progress,
      );
      const blend = Number(
        await page
          .locator('#court-canvas')
          .getAttribute('data-placement-blend'),
      );
      if (progress === 0 || progress === 1)
        expect(blend).toBeCloseTo(progress, 2);
      else {
        expect(blend).toBeGreaterThan(samples.at(-1)!.blend);
        expect(blend).toBeLessThan(1);
      }
      await expect(page.locator('html')).toHaveAttribute(
        'data-interactive',
        String(progress === 1),
      );
      if (progress > 0 && progress < 1) {
        const hit = await page.evaluate(() => {
          const { scene } = Reflect.get(window, '__courtTest') as CourtProbe;
          const client = scene.projectPoint({ x: 0.5, y: 0.65 })!;
          return scene.pointFromClient(client.x, client.y);
        });
        expect(hit, 'moving camera must reject model selection').toBeNull();
        await expect(page.locator('[data-record]')).toBeDisabled();
      }
      samples.push({
        blend,
        client: await project(page, { x: 0.4, y: 0.65 }),
      });
    }
    expect(
      Math.hypot(
        samples[0].client.x - samples[4].client.x,
        samples[0].client.y - samples[4].client.y,
      ),
    ).toBeGreaterThan(30);
    const held = await project(page, { x: 0.4, y: 0.65 });
    await scrollToPosition(page, (range.start + range.end) / 2);
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    const still = await project(page, { x: 0.4, y: 0.65 });
    expect(Math.hypot(held.x - still.x, held.y - still.y)).toBeLessThanOrEqual(
      2,
    );
    for (const direction of [1, -1]) {
      const boundary = range.start;
      const clients = [];
      for (const offset of [-2 * direction, 2 * direction]) {
        await scrollToPosition(page, boundary + offset);
        await expect
          .poll(async () =>
            Number(
              await page
                .locator('#court-canvas')
                .getAttribute('data-placement-blend'),
            ),
          )
          .toBeGreaterThan(0.99);
        clients.push(await project(page, { x: 0.4, y: 0.65 }));
      }
      expect(
        Math.hypot(clients[0].x - clients[1].x, clients[0].y - clients[1].y),
      ).toBeLessThanOrEqual(5);
    }
    await scrollToPosition(page, entryStart);
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-placement-blend',
      '0.0000',
    );
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'false',
    );
    const reversed = await project(page, { x: 0.4, y: 0.65 });
    expect(
      Math.hypot(
        reversed.x - samples[0].client.x,
        reversed.y - samples[0].client.y,
      ),
    ).toBeLessThanOrEqual(2);
    await assertBackgroundIdentity(page);
  },
);

for (const dpr of [1, 2]) {
  test(
    `the real camera fits a 15 by 14 court and round trips CSS client points within 2px at DPR ${dpr}`,
    webgl,
    async ({ browser }, testInfo) => {
      test.skip(
        testInfo.project.name !== 'chromium',
        'Real WebGL projection runs in Chromium.',
      );
      const context = await browser.newContext({
        viewport: { width: 1440, height: 1000 },
        deviceScaleFactor: dpr,
      });
      try {
        const page = await context.newPage();
        await exposeSceneInTest(page);
        await readyExperience(page, '/en/#experience');
        for (const [width, height] of [
          [1440, 1000],
          [1920, 1080],
          [1440, 650],
        ]) {
          await page.setViewportSize({ width, height });
          await enterNativeExperience(page);
          const result = await page.evaluate(() => {
            const { scene } = Reflect.get(window, '__courtTest') as CourtProbe;
            const host = document
              .querySelector('[data-demo-court-host]')!
              .getBoundingClientRect();
            const points = [
              { x: 0, y: 0 },
              { x: 1, y: 0 },
              { x: 0, y: 1 },
              { x: 1, y: 1 },
              { x: 0.23, y: 0.67 },
              { x: 0.76, y: 0.43 },
            ];
            return {
              host: {
                left: host.left,
                top: host.top,
                right: host.right,
                bottom: host.bottom,
              },
              samples: points.map((point) => {
                const client = scene.projectPoint(point);
                const hit = client && scene.pointFromClient(client.x, client.y);
                const again = hit && scene.projectPoint(hit);
                return { point, client, hit, again };
              }),
            };
          });
          for (const sample of result.samples) {
            expect(sample.client).not.toBeNull();
            expect(sample.client!.x).toBeGreaterThanOrEqual(
              result.host.left + 23,
            );
            expect(sample.client!.x).toBeLessThanOrEqual(
              result.host.right - 23,
            );
            expect(sample.client!.y).toBeGreaterThanOrEqual(
              result.host.top + 23,
            );
            expect(sample.client!.y).toBeLessThanOrEqual(
              result.host.bottom - 23,
            );
            // The painted sidelines fit too, while input intentionally excludes
            // the thin boundary strip. Interior points exercise the true inverse.
            if (sample.point.x === 0 || sample.point.x === 1) continue;
            expect(sample.hit).not.toBeNull();
            expect(sample.again).not.toBeNull();
            expect(
              Math.hypot(
                sample.again!.x - sample.client!.x,
                sample.again!.y - sample.client!.y,
              ),
            ).toBeLessThanOrEqual(2);
            expect(sample.hit!.x).toBeCloseTo(sample.point.x, 3);
            expect(sample.hit!.y).toBeCloseTo(sample.point.y, 3);
          }
          const [a, b, c] = result.samples.map((sample) => sample.client!);
          const courtWidth = Math.hypot(a.x - b.x, a.y - b.y);
          const courtLength = Math.hypot(a.x - c.x, a.y - c.y);
          expect(courtWidth / courtLength).toBeCloseTo(15 / 14, 2);
          await assertBackgroundIdentity(page);
        }
      } finally {
        await context.close();
      }
    },
  );
}

test(
  'host pointer release selects the raycast location while drags and court margins leave selection unchanged',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Real WebGL pointer input runs in Chromium.',
    );
    await page.setViewportSize({ width: 1440, height: 1000 });
    await exposeSceneInTest(page);
    await readyExperience(page);
    const point = { x: 0.37, y: 0.64 };
    const client = await project(page, point);
    await page.mouse.click(client.x, client.y);
    await expect(page.locator('[data-record]')).toBeEnabled();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    const location = async () =>
      page.locator('[data-demo-selection]').evaluate((element) => {
        const matrix = (element as SVGGElement).transform.baseVal.consolidate()!
          .matrix;
        return { x: (matrix.e - 28) / 544, y: (matrix.f - 28) / 504 };
      });
    await expect.poll(location).toEqual({
      x: expect.closeTo(point.x, 3),
      y: expect.closeTo(point.y, 3),
    });
    const before = await location();
    const other = await project(page, { x: 0.67, y: 0.75 });
    await page.mouse.move(client.x, client.y);
    await page.mouse.down();
    await page.mouse.move(other.x, other.y, { steps: 8 });
    await page.mouse.up();
    expect(await location()).toEqual(before);
    // Returning to the press location does not turn a completed drag into a
    // click. Start away from the selected point so a false selection is visible.
    await page.mouse.move(other.x, other.y);
    await page.mouse.down();
    await page.mouse.move(client.x, client.y, { steps: 8 });
    await page.mouse.move(other.x, other.y, { steps: 8 });
    await page.mouse.up();
    expect(await location()).toEqual(before);
    const host = (await page.locator('[data-demo-court-host]').boundingBox())!;
    await page.mouse.click(host.x + 4, host.y + 4);
    expect(await location()).toEqual(before);
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-red-score]')).toHaveText('6');
    await expect(page.locator('[data-record]')).toBeDisabled();
    await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
      'hidden',
    );
    await page.locator('[data-reset]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await expect(page.locator('[data-record]')).toBeDisabled();
    await expect(page.locator('[data-demo-marker]')).toHaveAttribute('hidden');
    await assertBackgroundIdentity(page);
  },
);

test(
  'settled full-motion reading and download stop actual WebGL draws until chapter navigation resumes them',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Real WebGL draw submissions run in Chromium.',
    );
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await exposeSceneInTest(page);
    const draws = await observeCourtDraws(page);
    await page.goto('/');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await page.evaluate(() => document.fonts.ready);
    const canvas = page.locator('#court-canvas');
    await expect.poll(draws).toBeGreaterThan(0);
    await expect(canvas).toHaveAttribute('data-rendering', 'idle');
    // Font measurements and the final introduction frame may still settle.
    // A real quiet interval must follow them while full motion remains enabled.
    await expect
      .poll(
        async () => {
          const before = await draws();
          await page.waitForTimeout(500);
          return {
            draws: (await draws()) - before,
            rendering: await canvas.getAttribute('data-rendering'),
          };
        },
        { timeout: 5000, intervals: [100] },
      )
      .toEqual({ draws: 0, rendering: 'idle' });
    await page.locator('.nav-download').click();
    await expect(page.locator('#download .button')).toBeInViewport();
    await expect(page.locator('html')).toHaveAttribute(
      'data-chapter',
      'download',
    );
    await expect(canvas).toHaveAttribute('data-rendering', 'off');
    const download = await draws();
    await page.waitForTimeout(700);
    expect(await draws()).toBe(download);
    await expect(canvas).toHaveAttribute('data-rendering', 'off');
    await page.locator('.site-header a[href="#experience"]').click();
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    await expect.poll(draws).toBeGreaterThan(download);
    const point = await project(page, { x: 0.37, y: 0.64 });
    await page.mouse.click(point.x, point.y);
    await expect(page.locator('[data-record]')).toBeEnabled();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await assertBackgroundIdentity(page);
  },
);

test(
  'overlapping gallery and hidden-page pauses freeze desktop shot draws until both reasons are released',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'Real WebGL shot suspension runs in Chromium.',
    );
    await page.setViewportSize({ width: 1440, height: 1000 });
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await exposeSceneInTest(page);
    const draws = await observeCourtDraws(page);
    await readyExperience(page);
    const point = { x: 0.37, y: 0.64 };
    const client = await project(page, point);
    await page.mouse.click(client.x, client.y);
    await expect(page.locator('[data-record]')).toBeEnabled();
    // Begin and suspend within one browser task so a slow driver cannot consume
    // the shot before the viewer and visibility events reach the real handlers.
    await page.locator('[data-record]').evaluate((element) => {
      (element as HTMLButtonElement).click();
      document
        .querySelector<HTMLAnchorElement>('#scoring .viewer-link')!
        .click();
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
    const canvas = page.locator('#court-canvas');
    const demo = page.locator('[data-demo]');
    const marker = page.locator('[data-demo-marker]');
    const ball = page.locator('[data-demo-ball]');
    const net = page.locator('[data-net-weave]');
    await expect(page.locator('[data-viewer]')).toBeVisible();
    await expect(canvas).toHaveAttribute('data-rendering', 'paused');
    await expect(demo).toHaveAttribute('data-demo-phase', 'shooting');
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(marker).toHaveAttribute('hidden');
    const suspendedDraws = await draws();
    const suspendedBall = await ball.getAttribute('transform');
    const suspendedNet = await net.getAttribute('d');
    await page.waitForTimeout(2300);
    expect(await draws()).toBe(suspendedDraws);
    await expect(ball).toHaveAttribute('transform', suspendedBall!);
    await expect(net).toHaveAttribute('d', suspendedNet!);
    await expect(demo).toHaveAttribute('data-demo-phase', 'shooting');
    await expect(marker).toHaveAttribute('hidden');
    await page.locator('[data-viewer-close]').click();
    await expect(page.locator('[data-viewer]')).not.toBeVisible();
    await page.waitForTimeout(700);
    expect(await draws()).toBe(suspendedDraws);
    await expect(canvas).toHaveAttribute('data-rendering', 'paused');
    await expect(ball).toHaveAttribute('transform', suspendedBall!);
    await expect(net).toHaveAttribute('d', suspendedNet!);
    await expect(demo).toHaveAttribute('data-demo-phase', 'shooting');
    await expect(marker).toHaveAttribute('hidden');
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
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
    await expect.poll(draws).toBeGreaterThan(suspendedDraws);
    await expect(demo).toHaveAttribute('data-demo-phase', 'scored');
    await expect(marker).not.toHaveAttribute('hidden');
    await expect(marker).toHaveCount(1);
    const location = await marker.evaluate((element) => {
      const matrix = (element as SVGGElement).transform.baseVal.consolidate()!
        .matrix;
      return { x: (matrix.e - 28) / 544, y: (matrix.f - 28) / 504 };
    });
    expect(location.x).toBeCloseTo(point.x, 3);
    expect(location.y).toBeCloseTo(point.y, 3);
    await expect(canvas).toHaveAttribute('data-rendering', 'idle');
    await page.waitForTimeout(2300);
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-red-score]')).toHaveText('6');
    await expect(demo).toHaveAttribute('data-demo-phase', 'scored');
    await expect(marker).not.toHaveAttribute('hidden');
    await expect(page.locator('[data-record]')).toBeDisabled();
    await assertBackgroundIdentity(page);
  },
);

test(
  'an ordinary production page exposes no CourtScene instance on window',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The production WebGL instance runs in Chromium.',
    );
    await allowSoftwareWebGL(page);
    await page.goto('/#experience');
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    const exposed = await page.evaluate(() => {
      const found: string[] = [];
      const inspect = (object: object, prefix: string, depth: number) => {
        for (const [key, descriptor] of Object.entries(
          Object.getOwnPropertyDescriptors(object),
        )) {
          const value = descriptor.value;
          if (
            !value ||
            typeof value !== 'object' ||
            value === window ||
            value === document
          )
            continue;
          if (
            typeof value.setStoryFrame === 'function' &&
            typeof value.selectPoint === 'function' &&
            typeof value.presentFrame === 'function'
          )
            found.push(`${prefix}${key}`);
          else if (depth && Object.getPrototypeOf(value) === Object.prototype)
            inspect(value, `${prefix}${key}.`, depth - 1);
        }
      };
      inspect(window, '', 1);
      return found;
    });
    expect(exposed).toEqual([]);
  },
);

test(
  'unchanged projection and raycast queries do not rewrite the camera presentation',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The production WebGL camera runs in Chromium.',
    );
    await exposeSceneInTest(page);
    await readyExperience(page);
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-rendering',
      'idle',
    );
    const result = await page.evaluate(() => {
      const { scene, canvas } = Reflect.get(
        window,
        '__courtTest',
      ) as CourtProbe;
      const point = { x: 0.4, y: 0.65 };
      const client = scene.projectPoint(point)!;
      const observer = new MutationObserver(() => {});
      observer.observe(canvas, {
        attributes: true,
        attributeOldValue: true,
        attributeFilter: [
          'data-camera-view',
          'data-placement-blend',
          'data-input-enabled',
          'data-view-cutaway',
        ],
      });
      let maximumError = 0;
      for (let index = 0; index < 20; index++) {
        const projected = scene.projectPoint(point)!;
        const hit = scene.pointFromClient(projected.x, projected.y)!;
        const again = scene.projectPoint(hit)!;
        maximumError = Math.max(
          maximumError,
          Math.hypot(client.x - again.x, client.y - again.y),
        );
      }
      const mutations = observer.takeRecords();
      observer.disconnect();
      return {
        maximumError,
        repeatedWrites: mutations.filter(
          (mutation) =>
            canvas.getAttribute(mutation.attributeName!) === mutation.oldValue,
        ).length,
      };
    });
    expect(result.maximumError).toBeLessThanOrEqual(2);
    expect(result.repeatedWrites).toBe(0);
  },
);

test('desktop replay prepares screenshot decoding before its flip enters the viewport', async ({
  page,
}) => {
  await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
    route.abort(),
  );
  await page.addInitScript(() => {
    const calls: { src: string; top: number; viewport: number }[] = [];
    Reflect.set(window, '__replayDecodeCalls', calls);
    const decode = HTMLImageElement.prototype.decode;
    HTMLImageElement.prototype.decode = function () {
      if (this.closest('[data-replay-device]')) {
        const stage = this.closest('[data-story-stage="replay"]')!;
        calls.push({
          src: this.currentSrc || this.src,
          top: stage.getBoundingClientRect().top,
          viewport: innerHeight,
        });
      }
      return decode.call(this);
    };
  });
  await page.goto('/en/');
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  const initial = await page.evaluate(
    () => Reflect.get(window, '__replayDecodeCalls').length,
  );
  expect(initial).toBe(0);
  await page.locator('[data-story-stage="replay"]').evaluate((stage) => {
    scrollTo({
      top: scrollY + stage.getBoundingClientRect().top - innerHeight * 1.6,
      behavior: 'instant',
    });
  });
  await expect
    .poll(() =>
      page.evaluate(() => Reflect.get(window, '__replayDecodeCalls').length),
    )
    .toBe(2);
  const calls = await page.evaluate(() =>
    Reflect.get(window, '__replayDecodeCalls'),
  );
  expect(calls.map((call: { src: string }) => call.src).sort()).toEqual([
    expect.stringMatching(/history\.webp$/),
    expect.stringMatching(/summary\.webp$/),
  ]);
  for (const call of calls)
    expect(call.top).toBeGreaterThan(call.viewport * 0.85);
});

test(
  'a stationary overhead camera synchronizes input eligibility when paused and resumed',
  webgl,
  async ({ page }, testInfo) => {
    test.skip(
      testInfo.project.name !== 'chromium',
      'The production WebGL camera runs in Chromium.',
    );
    await exposeSceneInTest(page);
    await readyExperience(page);
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-rendering',
      'idle',
    );
    const states = await page.evaluate(() => {
      const { scene, canvas } = Reflect.get(
        window,
        '__courtTest',
      ) as CourtProbe;
      const client = scene.projectPoint({ x: 0.4, y: 0.65 })!;
      const snapshot = () => ({
        enabled: canvas.dataset.inputEnabled,
        hit: scene.pointFromClient(client.x, client.y),
      });
      const initial = snapshot();
      scene.setPaused(true);
      const paused = snapshot();
      scene.setPaused(false);
      const resumed = snapshot();
      return { initial, paused, resumed };
    });
    expect(states.initial.enabled).toBe('true');
    expect(states.initial.hit).not.toBeNull();
    expect(states.paused.enabled).toBe('false');
    expect(states.paused.hit).toBeNull();
    expect(states.resumed.enabled).toBe('true');
    expect(states.resumed.hit).not.toBeNull();
  },
);
