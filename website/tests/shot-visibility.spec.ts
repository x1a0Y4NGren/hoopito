import { expect, test, type Page } from '@playwright/test';
import ts from 'typescript';
import sharp from 'sharp';
import { installContractClock } from './controlled-clock';
import { sampleShotPose } from '../src/scripts/shot-motion';
import type { CourtScene } from '../src/scripts/scene-contract';

const sceneChunk = /court-scene[^/]*\.(?:js|ts)(?:\?|$)/;
const point = { x: 0.5, y: 0.45 };

async function observeScene(page: Page, noTimer = false) {
  await page.addInitScript((noTimer) => {
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
    if (noTimer) {
      const extension = WebGL2RenderingContext.prototype.getExtension;
      WebGL2RenderingContext.prototype.getExtension = function (
        this: WebGL2RenderingContext,
        name: string,
      ) {
        return name === 'EXT_disjoint_timer_query_webgl2'
          ? null
          : Reflect.apply(extension, this, [name]);
      } as typeof extension;
    }
  }, noTimer);
  await page.route(sceneChunk, async (route) => {
    const response = await route.fetch();
    let body = await response.text();
    // Observe the existing quality setter inside the real factory. No production
    // globals or alternate renderer are introduced by this network-only wrapper.
    const source = ts.createSourceFile(
      'scene.js',
      body,
      ts.ScriptTarget.Latest,
      true,
      ts.ScriptKind.JS,
    );
    const candidates: ts.FunctionDeclaration[] = [];
    function visit(node: ts.Node) {
      if (
        ts.isFunctionDeclaration(node) &&
        node.name &&
        node.body &&
        /\.dataset\.quality\s*=/.test(node.body.getText(source)) &&
        /\.onQualityChange/.test(node.body.getText(source))
      )
        candidates.push(node);
      ts.forEachChild(node, visit);
    }
    visit(source);
    const setter = candidates.sort(
      (a, b) => a.getWidth(source) - b.getWidth(source),
    )[0];
    if (!setter?.name) throw new Error('Observe the real quality setter');
    const offset = setter.getStart(source);
    body = `${body.slice(0, offset)}Reflect.set(window,"__shotSetQuality",${setter.name.text});\n${body.slice(offset)}`;
    let cameras = 0;
    body = body.replace(
      /new [\w$.]+\(\s*32\s*,\s*1\s*,\s*(?:0)?\.015\s*,\s*100\s*\)/g,
      (constructor) => {
        cameras++;
        return `(Reflect.set(window,"__shotCamera",${constructor}),Reflect.get(window,"__shotCamera"))`;
      },
    );
    if (cameras !== 1) throw new Error('Observe exactly one real camera');
    const exports = body.match(/export\s*\{([^}]*\bcreateCourtScene\b[^}]*)\}/);
    let factory = exports?.[1].match(
      /(?:^|,)\s*([\w$]+)\s+as\s+createCourtScene\b/,
    )?.[1];
    if (exports && factory)
      body = body.replace(
        exports[0],
        exports[0].replace(
          /[\w$]+\s+as\s+createCourtScene\b/,
          '__shotCreate as createCourtScene',
        ),
      );
    else if (/export async function createCourtScene\(/.test(body)) {
      factory = '__shotOriginal';
      body = body.replace(
        /export async function createCourtScene\(/,
        'async function __shotOriginal(',
      );
      body += '\nexport { __shotCreate as createCourtScene };\n';
    } else throw new Error('Observe the real scene factory');
    body += `\nasync function __shotCreate(...args) { const scene=await ${factory}(...args); Reflect.set(window,"__shotScene",scene); return scene; }\n`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
}

async function screenPoint(page: Page, world?: number[]) {
  return page.evaluate(
    ({ point, world }) => {
      if (Reflect.has(window, '__shotScene')) {
        if (!world)
          return Reflect.get(window, '__shotScene').projectPoint(point) as {
            x: number;
            y: number;
          };
        const camera = Reflect.get(window, '__shotCamera');
        const projected = camera.position
          .clone()
          .set(...world)
          .project(camera);
        const canvas = document
          .querySelector('#court-canvas')!
          .getBoundingClientRect();
        return {
          x: canvas.x + ((projected.x + 1) * canvas.width) / 2,
          y: canvas.y + ((1 - projected.y) * canvas.height) / 2,
        };
      }
      const svg = document.querySelector<SVGSVGElement>('[data-demo-court]')!;
      const projected = new DOMPoint(
        28 + point.x * 544,
        28 + point.y * 504,
      ).matrixTransform(svg.getScreenCTM()!);
      return { x: projected.x, y: projected.y };
    },
    { point, world },
  );
}

async function brightPixels(buffer: Buffer) {
  const { data, info } = await sharp(buffer)
    .removeAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  let count = 0;
  for (let pixel = 0; pixel < data.length; pixel += info.channels)
    if (data[pixel] > 220 && data[pixel + 1] > 190 && data[pixel + 2] > 135)
      count++;
  return count;
}

async function crop(
  page: Page,
  center: { x: number; y: number },
  style?: string,
) {
  const size = page.viewportSize()!;
  return page.screenshot({
    scale: 'css',
    style,
    clip: {
      x: Math.max(0, Math.min(size.width - 48, center.x - 24)),
      y: Math.max(0, Math.min(size.height - 48, center.y - 24)),
      width: 48,
      height: 48,
    },
  });
}

async function addedHighlights(before: Buffer, after: Buffer) {
  const [without, withEffect] = await Promise.all(
    [before, after].map((frame) => sharp(frame).removeAlpha().raw().toBuffer()),
  );
  let count = 0;
  for (let i = 0; i < withEffect.length; i += 3) {
    const [red, green, blue] = withEffect.subarray(i, i + 3);
    if (
      red > 220 &&
      green > 190 &&
      blue > 135 &&
      red + green + blue - without[i] - without[i + 1] - without[i + 2] > 28
    )
      count++;
  }
  return count;
}

function luminance(pixels: Buffer, offset: number) {
  const linear = (channel: number) => {
    const srgb = channel / 255;
    return srgb <= 0.04045 ? srgb / 12.92 : ((srgb + 0.055) / 1.055) ** 2.4;
  };
  return (
    0.2126 * linear(pixels[offset]) +
    0.7152 * linear(pixels[offset + 1]) +
    0.0722 * linear(pixels[offset + 2])
  );
}

async function contrastingMarkerPixels(before: Buffer, after: Buffer) {
  const [without, withEffect] = await Promise.all(
    [before, after].map((frame) => sharp(frame).removeAlpha().raw().toBuffer()),
  );
  let count = 0;
  for (let i = 0; i < withEffect.length; i += 3) {
    // Count the amber ring and ticks against the floor at CSS-pixel scale.
    const contrast =
      (luminance(withEffect, i) + 0.05) / (luminance(without, i) + 0.05);
    if (contrast >= 2) count++;
  }
  return count;
}

for (const locale of ['/', '/en/'])
  for (const dpr of [1, 2]) {
    test(`${locale} SVG luminous markers and a moving short trail at DPR ${dpr}`, async ({
      browser,
    }, info) => {
      const context = await browser.newContext({
        viewport: { width: 390, height: 1000 },
        deviceScaleFactor: dpr,
        reducedMotion: 'no-preference',
      });
      const page = await context.newPage();
      try {
        await page.route(sceneChunk, (route) => route.abort());
        const pause = await installContractClock(page);
        await page.goto(`${locale}#experience`);
        await expect(page.locator('[data-demo-points="2"]')).toBeEnabled();
        await page.evaluate(() => document.fonts.ready);
        await pause();
        await page.clock.runFor(1000);
        await page.locator('[data-demo-points="2"]').dispatchEvent('click');
        const position = await screenPoint(page);
        await page
          .locator('[data-point-preset="center"]')
          .dispatchEvent('click');
        await page.clock.runFor(600);
        await expect(page.locator('[data-demo-marker-glow]')).toHaveCount(2);
        const before = await crop(
          page,
          position,
          '[data-demo-selection] { visibility: hidden !important; }',
        );
        const selected = await crop(page, position);
        expect(await addedHighlights(before, selected)).toBeGreaterThanOrEqual(
          4,
        );
        await page.screenshot({ path: info.outputPath('selected-point.png') });
        await page.locator('[data-record]').dispatchEvent('click');
        let elapsed = 0;
        for (const instant of [300, 650, 1234, 1414]) {
          await page.clock.runFor(instant - elapsed);
          elapsed = instant;
          const core = page.locator('[data-demo-trail]');
          const halo = page.locator('[data-demo-trail-halo]');
          // An exactly vertical SVG path has a zero-width geometry box even
          // when its non-scaling stroke paints several pixels on screen.
          await expect(core).not.toHaveAttribute('hidden', '');
          await expect(halo).not.toHaveAttribute('hidden', '');
          await expect(halo).toHaveAttribute(
            'd',
            (await core.getAttribute('d'))!,
          );
          await expect(page.locator('[data-demo-ball-glow]')).toBeVisible();
          const registration = await core.evaluate((el) => {
            const path = el as SVGPathElement;
            const end = path.getPointAtLength(path.getTotalLength());
            const ball = path
              .ownerSVGElement!.querySelector<SVGGElement>('[data-demo-ball]')!
              .transform.baseVal.consolidate()!.matrix;
            return Math.hypot(end.x - ball.e, end.y - ball.f);
          });
          expect(registration).toBeLessThan(0.1);
          await page.screenshot({
            path: info.outputPath(`flight-${instant}.png`),
          });
        }
        await page.locator('[data-reset]').dispatchEvent('click');
        await page.clock.runFor(2400);
        await expect(page.locator('[data-demo-trail-halo]')).toBeHidden();
        await expect(page.locator('[data-demo-ball]')).toBeHidden();
        await expect(page.locator('[data-blue-score]')).toHaveText('6');
        await page.locator('[data-demo-points="1"]').dispatchEvent('click');
        await page.locator('[data-record]').dispatchEvent('click');
        await page.clock.runFor(2200);
        await expect(page.locator('[data-demo-marker]')).toBeVisible();
        await expect(page.locator('[data-blue-score]')).toHaveText('7');
        await page.screenshot({ path: info.outputPath('made-point.png') });
      } finally {
        await context.close();
      }
    });
  }

for (const dpr of [1, 2])
  for (const quality of ['full', 'effects', 'density', 'no-timer'] as const) {
    test(
      `WebGL core glow and trail survive ${quality} at DPR ${dpr}`,
      { tag: '@webgl', lock: 'webgl-renderer' },
      async ({ browser }, info) => {
        test.skip(
          info.project.name !== 'chromium',
          'Real WebGL feedback runs in Chromium',
        );
        // Sampling full-resolution flight frames is costly on CI's software GPU.
        if (process.env.CI && quality === 'full') test.setTimeout(180_000);
        const context = await browser.newContext({
          viewport: { width: 1440, height: 1000 },
          deviceScaleFactor: dpr,
          reducedMotion: 'no-preference',
        });
        const page = await context.newPage();
        try {
          const errors: string[] = [];
          page.on('pageerror', (error) => errors.push(error.message));
          page.on('console', (message) => {
            if (message.type() === 'error') errors.push(message.text());
          });
          await observeScene(page, quality === 'no-timer');
          const pause = await installContractClock(page);
          await page.goto('/#experience');
          await expect(page.locator('html')).toHaveAttribute(
            'data-scene',
            '3d',
          );
          await page.evaluate(() => document.fonts.ready);
          await pause();
          await page.clock.runFor(1000);
          const canvas = page.locator('#court-canvas');
          if (quality !== 'no-timer')
            await page.evaluate(
              (quality) => Reflect.get(window, '__shotSetQuality')(quality),
              quality,
            );
          await expect(canvas).toHaveAttribute(
            'data-quality',
            quality === 'no-timer' ? 'density' : quality,
          );
          await page.locator('[data-demo-points="2"]').dispatchEvent('click');
          await page
            .locator('[data-point-preset="center"]')
            .dispatchEvent('click');
          await page.clock.runFor(600);
          const position = await screenPoint(page);
          // Compare the same settled frame. Selecting a point also stops the
          // region pulse, which changes the floor color underneath the marker.
          const showMark = (visible: boolean) =>
            page.evaluate(
              ({ point, visible }) => {
                const scene = Reflect.get(window, '__shotScene') as CourtScene;
                scene.selectPoint(visible ? point : null);
                scene.presentFrame();
              },
              { point, visible },
            );
          const selected = await crop(page, position);
          await showMark(false);
          const before = await crop(page, position);
          await showMark(true);
          await info.attach('selected-point', {
            body: selected,
            contentType: 'image/png',
          });
          expect(
            await contrastingMarkerPixels(before, selected),
          ).toBeGreaterThanOrEqual(12);
          const selectedDraws = Number(
            await canvas.getAttribute('data-draw-calls'),
          );
          await page.locator('[data-record]').dispatchEvent('click');
          let elapsed = 0;
          for (const instant of [300, 650, 1234, 1414]) {
            await page.clock.runFor(instant - elapsed);
            elapsed = instant;
            await expect(canvas).toHaveAttribute('data-shot-trail', 'visible');
            await expect(canvas).toHaveAttribute(
              'data-shot-core-pixels',
              '2.5',
            );
            const head = Number(await canvas.getAttribute('data-shot-head'));
            const tail = Number(await canvas.getAttribute('data-shot-tail'));
            expect(head - tail).toBeGreaterThan(0);
            expect(head - tail).toBeLessThanOrEqual(0.22 / 1.2 + 0.0001);
            const projected = await screenPoint(
              page,
              sampleShotPose(point, instant / 1000).position,
            );
            const flight = await crop(page, projected);
            expect(await brightPixels(flight)).toBeGreaterThanOrEqual(4);
            await info.attach(`flight-${instant}`, {
              body: flight,
              contentType: 'image/png',
            });
          }
          await info.attach('shot-draws', {
            body: JSON.stringify({
              quality,
              dpr,
              selectedDraws,
              flightDraws: Number(await canvas.getAttribute('data-draw-calls')),
            }),
            contentType: 'application/json',
          });
          await page.emulateMedia({ reducedMotion: 'reduce' });
          await page.clock.runFor(100);
          await expect(canvas).toHaveAttribute('data-shot-trail', 'hidden');
          await expect(page.locator('[data-blue-score]')).toHaveText('8');
          await page.locator('[data-reset]').dispatchEvent('click');
          await page.clock.runFor(2400);
          await expect(canvas).toHaveAttribute('data-shot-trail', 'hidden');
          await expect(page.locator('[data-blue-score]')).toHaveText('6');
          expect(errors).toEqual([]);
        } finally {
          await context.close();
        }
      },
    );
  }
