import { expect, test, type Page } from '@playwright/test';

const sceneChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;
const score = (page: Page, points: number) =>
  page.locator(`[data-demo-points="${points}"]`);

async function ready(page: Page, path: string, width = 390) {
  await page.setViewportSize({ width, height: 1000 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto(`${path}#experience`);
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
  await page.evaluate(() => document.fonts.ready);
}

async function courtClick(page: Page, x: number, y: number) {
  const court = page.locator('[data-demo-court]');
  await court.scrollIntoViewIfNeeded();
  const client = await court.evaluate(
    (element, point) => {
      const matrix = (element as SVGSVGElement).getScreenCTM()!;
      const projected = new DOMPoint(
        28 + point.x * 544,
        28 + point.y * 504,
      ).matrixTransform(matrix);
      return { x: projected.x, y: projected.y };
    },
    { x, y },
  );
  await page.mouse.click(client.x, client.y);
}

async function exposeRealScene(page: Page) {
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
          '__regionCreate as createCourtScene',
        ),
      );
    } else if (/export async function createCourtScene\(/.test(body)) {
      factory = '__regionOriginal';
      body = body.replace(
        /export async function createCourtScene\(/,
        'async function __regionOriginal(',
      );
      body += '\nexport { __regionCreate as createCourtScene };\n';
    } else throw new Error('Observe the real scene factory');
    body += `\nasync function __regionCreate(...args) { const scene = await ${factory}(...args); Reflect.set(window, '__regionScene', scene); return scene; }\n`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
}

async function worldClick(page: Page, x: number, y: number) {
  await expect(page.locator('html')).toHaveAttribute(
    'data-interactive',
    'true',
  );
  const client = await page.evaluate(
    (point) => {
      const scene = Reflect.get(window, '__regionScene');
      return scene.projectPoint(point) as { x: number; y: number };
    },
    { x, y },
  );
  await page.mouse.click(client.x, client.y);
}

for (const path of ['/', '/en/']) {
  for (const width of [390, 1440]) {
    test(`${path}: ${width}px score-first rejects the wrong region and records the chosen value`, async ({
      page,
    }) => {
      await ready(page, path, width);
      for (const points of [2, 3]) {
        await score(page, points).click();
        await expect(page.locator('[data-demo-court-host]')).toHaveAttribute(
          'data-scoring-region',
          points === 2 ? 'insideArc' : 'outsideArc',
        );
        await courtClick(page, 0.5, points === 2 ? 0.85 : 0.35);
        await expect(page.locator('[data-record]')).toBeDisabled();
        await expect(page.locator('[data-demo-selection]')).toBeHidden();
        await expect(page.locator('[data-blue-score]')).toHaveText('6');
        await courtClick(page, 0.5, points === 2 ? 0.35 : 0.85);
        await expect(page.locator('[data-record]')).toBeEnabled();
        const selection = await page
          .locator('[data-demo-selection]')
          .getAttribute('transform');
        await courtClick(page, 0.5, points === 2 ? 0.85 : 0.35);
        await expect(page.locator('[data-demo-selection]')).toHaveAttribute(
          'transform',
          selection!,
        );
        await page.locator('[data-record]').click();
        await expect(page.locator('[data-blue-score]')).toHaveText(
          String(6 + points),
        );
        await expect(page.locator('[data-demo-marker]')).toBeVisible();
        await page.locator('[data-reset]').click();
      }
    });
  }

  test(`${path}: location-first restricts score choices and identifies a free throw explicitly`, async ({
    page,
  }) => {
    await ready(page, path);
    await courtClick(page, 0.5, 0.85);
    await expect(score(page, 1)).toBeDisabled();
    await expect(score(page, 2)).toBeDisabled();
    await expect(score(page, 3)).toBeEnabled();
    await expect(page.locator('[data-record]')).toBeDisabled();
    await courtClick(page, 0.5, 0.25);
    await expect(score(page, 1)).toBeDisabled();
    await expect(score(page, 2)).toBeEnabled();
    await expect(score(page, 3)).toBeDisabled();
    await courtClick(page, 0.5, 5.8 / 14);
    await expect(score(page, 1)).toBeEnabled();
    await expect(score(page, 2)).toBeEnabled();
    await score(page, 1).click();
    const selection = page.locator('[data-demo-selection]');
    const fixedTransform = await selection.getAttribute('transform');
    const fixed = fixedTransform!.match(/[-\d.]+/g)!.map(Number);
    expect(fixed[0]).toBeCloseTo(300, 8);
    expect(fixed[1]).toBeCloseTo(236.8, 8);
    await courtClick(page, 0.65, 0.2);
    await expect(selection).toHaveAttribute('transform', fixedTransform!);
    for (const button of await page.locator('[data-point-preset]').all())
      await expect(button).toBeDisabled();
    await page.locator('[data-record]').focus();
    await page.keyboard.press('Enter');
    await expect(page.locator('[data-blue-score]')).toHaveText('7');
    await expect(page.locator('[data-demo-status]')).toContainText(
      path === '/' ? '罚球' : 'free throw',
    );
  });

  test(`${path}: all keyboard presets stay in the selected scoring region`, async ({
    page,
  }) => {
    await ready(page, path);
    for (const points of [2, 3]) {
      await score(page, points).click();
      for (const name of ['left', 'center', 'right']) {
        const preset = page.locator(`[data-point-preset="${name}"]`);
        await preset.focus();
        await page.keyboard.press('Enter');
        await expect(page.locator('[data-record]')).toBeEnabled();
        await expect(score(page, points)).toBeEnabled();
        await expect(score(page, points === 2 ? 3 : 2)).toBeDisabled();
      }
      await page.locator('[data-reset]').click();
    }
  });

  test(`${path}: region light follows motion, background and chapter lifecycle`, async ({
    page,
  }, info) => {
    await ready(page, path);
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await score(page, 2).click();
    const host = page.locator('[data-demo-court-host]');
    await host.scrollIntoViewIfNeeded();
    await expect(host).toHaveAttribute('data-region-pulse', 'true');
    const light = page.locator(
      '[data-demo-region-light][data-region="insideArc"]',
    );
    const opacity = Number(
      await light.evaluate((el) => getComputedStyle(el).opacity),
    );
    await expect
      .poll(async () =>
        Math.abs(
          Number(await light.evaluate((el) => getComputedStyle(el).opacity)) -
            opacity,
        ),
      )
      .toBeGreaterThan(0.015);
    await page.evaluate(() => {
      Object.defineProperty(document, 'hidden', {
        configurable: true,
        get: () => true,
      });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await expect(host).toHaveAttribute('data-region-pulse', 'false');
    await page.evaluate(() => {
      delete (document as unknown as { hidden?: boolean }).hidden;
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await expect(host).toHaveAttribute('data-region-pulse', 'true');
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await expect(host).toHaveAttribute('data-region-pulse', 'false');
    await expect(light).toHaveCSS('opacity', '0.08');
    await page.screenshot({ path: info.outputPath('two-point-region.png') });
    await page.emulateMedia({ reducedMotion: 'no-preference' });
    await expect(host).toHaveAttribute('data-region-pulse', 'true');
    await page.evaluate(() => {
      const stage = document.querySelector<HTMLElement>(
        '[data-story-stage="experience"]',
      )!;
      scrollTo({
        top: Number(stage.dataset.scrollReadEnd) + 20,
        behavior: 'instant',
      });
    });
    await expect(host).toHaveAttribute('data-region-pulse', 'false');
    await expect(light).toBeHidden();
  });

  test(
    `${path}: WebGL applies the same score regions and retains them after fallback`,
    { tag: '@webgl', lock: 'webgl-renderer' },
    async ({ page }, info) => {
      test.skip(
        info.project.name !== 'chromium',
        'Real WebGL is exercised in Chromium',
      );
      await page.setViewportSize({ width: 1440, height: 1000 });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await exposeRealScene(page);
      const errors: string[] = [];
      page.on('console', (message) => {
        if (message.type() === 'error') errors.push(message.text());
      });
      page.on('pageerror', (error) => errors.push(error.message));
      await page.goto(`${path}#experience`);
      await expect(page.locator('html'))
        .toHaveAttribute('data-scene', '3d')
        .catch((error) => {
          throw new Error(
            `${error.message}\nBrowser errors:\n${errors.join('\n')}`,
          );
        });
      const canvas = page.locator('#court-canvas');
      for (const points of [1, 2, 3]) {
        await score(page, points).click();
        if (points !== 1) {
          await worldClick(page, 0.5, points === 2 ? 0.85 : 0.3);
          await expect(page.locator('[data-record]')).toBeDisabled();
          await worldClick(page, 0.5, points === 2 ? 0.3 : 0.85);
        }
        await expect(canvas).toHaveAttribute(
          'data-scoring-region',
          points === 1
            ? 'freeThrowLine'
            : points === 2
              ? 'insideArc'
              : 'outsideArc',
        );
        if (points === 3)
          await page.screenshot({
            path: info.outputPath('three-point-region.png'),
          });
        await page.locator('[data-record]').click();
        await expect(page.locator('[data-blue-score]')).toHaveText(
          String(6 + points),
        );
        await expect(canvas).toHaveAttribute('data-scoring-region', 'none');
        await page.locator('[data-reset]').click();
      }
      await score(page, 3).click();
      await canvas.evaluate((el) =>
        (el as HTMLCanvasElement)
          .getContext('webgl2')!
          .getExtension('WEBGL_lose_context')!
          .loseContext(),
      );
      await expect(page.locator('[data-demo-court-host]')).toHaveAttribute(
        'data-renderer',
        '2d',
      );
      await courtClick(page, 0.5, 0.3);
      await expect(page.locator('[data-record]')).toBeDisabled();
      await courtClick(page, 0.5, 0.85);
      await page.locator('[data-record]').click();
      await expect(page.locator('[data-blue-score]')).toHaveText('9');
    },
  );
}
