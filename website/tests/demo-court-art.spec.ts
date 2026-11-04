import { expect, test, type Page } from '@playwright/test';
import { installContractClock } from './controlled-clock';

const artPath = /\/art\/demo-(?:maple-v2|hoop-v2)\.webp(?:\?|$)/;
const sceneChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;

async function ready(page: Page, path = '/#experience') {
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path, { waitUntil: 'domcontentloaded' });
  await page.evaluate(async () => {
    // WebKit can hold fonts.ready until the document load event. This suite
    // deliberately stalls a court image, so wait for its actual text faces
    // rather than creating a dependency on the image we have not released.
    const text = ['#experience h2', '[data-blue-score]', '.demo-status'];
    await Promise.all(
      text.map((selector) => {
        const element = document.querySelector<HTMLElement>(selector)!;
        const style = getComputedStyle(element);
        return document.fonts.load(
          `${style.fontWeight} ${style.fontSize} ${style.fontFamily}`,
          element.textContent ?? '',
        );
      }),
    );
  });
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
  await expect(page.locator('[data-story-stage="experience"]')).toHaveAttribute(
    'data-scroll-read-end',
    /\d/,
  );
}

async function decodedArt(page: Page) {
  await expect(page.locator('[data-demo-art]')).toHaveCount(2);
  for (const name of ['floor', 'hoop'])
    await expect(page.locator(`[data-demo-art="${name}"]`)).toHaveAttribute(
      'data-art-ready',
      'true',
    );
  await expect(page.locator('[data-demo-court]')).toHaveAttribute(
    'data-hoop-ready',
    'true',
  );
}

async function selectCourt(page: Page, x = 0.4, y = 0.6) {
  const court = page.locator('[data-demo-court]');
  await court.scrollIntoViewIfNeeded();
  const client = await court.evaluate(
    (element, point) => {
      const svg = element as SVGSVGElement;
      const matrix = svg.getScreenCTM();
      if (!matrix) throw new Error('The actual court transform is missing');
      const result = new DOMPoint(
        28 + point.x * 544,
        28 + point.y * 504,
      ).matrixTransform(matrix);
      return { x: result.x, y: result.y };
    },
    { x, y },
  );
  await page.mouse.click(client.x, client.y);
  await expect(page.locator('[data-record]')).toBeEnabled();
  const selection = await page
    .locator('[data-demo-selection]')
    .getAttribute('transform');
  const values = selection!.match(/[-\d.]+/g)!.map(Number);
  // Browser mouse protocols quantize to CSS pixels. At a 288px court one CSS
  // pixel spans about 2.1 SVG units; keep selection within that pixel.
  const tolerance = await court.evaluate(
    (el) => 1.25 / (el as SVGSVGElement).getScreenCTM()!.a,
  );
  expect(Math.abs(values[0] - (28 + x * 544))).toBeLessThanOrEqual(tolerance);
  expect(Math.abs(values[1] - (28 + y * 504))).toBeLessThanOrEqual(tolerance);
}

test.use({ viewport: { width: 390, height: 844 } });

for (const path of ['/', '/en/'])
  for (const width of [320, 390, 430])
    test(`${path}: ${width}px generated art retains exact court geometry and accessible controls`, async ({
      page,
    }, info) => {
      await page.setViewportSize({ width, height: 844 });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await ready(page, `${path}#experience`);
      await decodedArt(page);
      const court = page.locator('[data-demo-court]');
      await expect(court).toHaveAttribute('viewBox', '0 0 600 560');
      const geometry = await court.evaluate((element) => {
        const svg = element as SVGSVGElement;
        const host = element.closest('[data-demo-court-host]')!;
        const net = element.querySelector<SVGGElement>('[data-demo-net]')!;
        const transform = net.transform.baseVal.consolidate()!.matrix;
        const root = document.documentElement;
        return {
          host: host.getBoundingClientRect().toJSON(),
          court: svg.getBoundingClientRect().toJSON(),
          net: {
            x: transform.e,
            y: transform.f,
            scaleX: transform.a,
            scaleY: transform.d,
          },
          playable: [...svg.querySelectorAll('rect')].some(
            (rect) =>
              rect.x.baseVal.value === 28 &&
              rect.y.baseVal.value === 28 &&
              rect.width.baseVal.value === 544 &&
              rect.height.baseVal.value === 504,
          ),
          overflow: root.scrollWidth - innerWidth,
          art: [
            ...svg.querySelectorAll<SVGImageElement>('[data-demo-art]'),
          ].map((image) => ({
            id: image.dataset.demoArt,
            href: image.getAttribute('href'),
            opacity: getComputedStyle(image).opacity,
            rim:
              image.dataset.demoArt === 'hoop'
                ? {
                    x: Number(image.dataset.rimCx),
                    y: Number(image.dataset.rimCy),
                    radius: Number(image.dataset.rimR),
                  }
                : null,
          })),
          rim: {
            circles: [
              ...svg.querySelectorAll<SVGCircleElement>(
                '[data-hoop-fallback] circle[fill="none"]',
              ),
            ].map((ring) => ({
              x: ring.cx.baseVal.value,
              y: ring.cy.baseVal.value,
              radius: ring.r.baseVal.value,
            })),
            ellipses: svg.querySelectorAll('[data-hoop-fallback] ellipse')
              .length,
          },
        };
      });
      expect(geometry.playable).toBe(true);
      expect(geometry.net).toEqual({
        x: 300,
        y: 82,
        scaleX: 1.25,
        scaleY: 1.25,
      });
      expect(geometry.host.width).toBeLessThanOrEqual(288.1);
      expect(geometry.host.width / geometry.host.height).toBeCloseTo(
        15 / 14,
        2,
      );
      expect(geometry.overflow).toBeLessThanOrEqual(1);
      expect(
        geometry.art.map(
          (art) => new URL(art.href!, 'http://127.0.0.1:4321').pathname,
        ),
      ).toEqual(['/art/demo-maple-v2.webp', '/art/demo-hoop-v2.webp']);
      for (const art of geometry.art) expect(Number(art.opacity)).toBe(1);
      expect(geometry.art[1].rim).toEqual({ x: 300, y: 82, radius: 20 });
      expect(geometry.rim.circles).toEqual([
        { x: 300, y: 82, radius: 20 },
        { x: 300, y: 82, radius: 20 },
      ]);
      expect(geometry.rim.ellipses).toBe(0);
      await expect(page.locator('[data-hoop-fallback]')).not.toBeVisible();
      await selectCourt(page);
      await page.locator('[data-record]').click();
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await expect(page.locator('[data-demo-marker]')).toBeVisible();
      await page.locator('[data-reset]').click();
      await expect(page.locator('[data-blue-score]')).toHaveText('6');
      await info.attach('art-geometry', {
        body: JSON.stringify(geometry, null, 2),
        contentType: 'application/json',
      });
    });

test('the hero stays light and both generated court assets load together near experience', async ({
  page,
}) => {
  const requested: string[] = [];
  page.on('request', (request) => {
    if (artPath.test(request.url()))
      requested.push(new URL(request.url()).pathname);
  });
  await ready(page, '/');
  await expect(page.locator('[data-mobile-page]')).toHaveText('01 / 07');
  expect(requested).toEqual([]);
  for (const image of await page.locator('[data-demo-art]').all())
    expect(await image.getAttribute('href')).toBeNull();
  await page.locator('[data-mobile-menu-toggle]').click();
  await page.locator('[data-mobile-menu-link="experience"]').click();
  await decodedArt(page);
  expect(new Set(requested)).toEqual(
    new Set(['/art/demo-maple-v2.webp', '/art/demo-hoop-v2.webp']),
  );
});

for (const failed of ['floor', 'hoop', 'both'])
  test(`${failed} image failure preserves the complete SVG fallback and a usable shot`, async ({
    page,
  }) => {
    await page.route(artPath, (route) =>
      failed === 'both' ||
      (failed === 'floor'
        ? route.request().url().includes('maple')
        : route.request().url().includes('hoop'))
        ? route.abort()
        : route.continue(),
    );
    await ready(page);
    const court = page.locator('[data-demo-court]');
    for (const name of ['floor', 'hoop']) {
      const image = page.locator(`[data-demo-art="${name}"]`);
      if (failed === 'both' || failed === name) {
        await expect(image).not.toHaveAttribute('data-art-ready', 'true');
        await expect(image).toHaveCSS('opacity', '0');
      } else await expect(image).toHaveAttribute('data-art-ready', 'true');
    }
    await expect(page.locator('[data-hoop-fallback]')).toBeVisible({
      visible: failed !== 'floor',
    });
    if (failed !== 'floor')
      await expect(court).not.toHaveAttribute('data-hoop-ready', 'true');
    await selectCourt(page, 0.7, 0.55);
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
    await expect(page.locator('[data-demo]')).toHaveAttribute(
      'data-demo-phase',
      'scored',
    );
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
  });

test('a delayed hoop never hides its vector fallback before the image is ready', async ({
  page,
}) => {
  let release!: () => void;
  const waiting = new Promise<void>((resolve) => {
    release = resolve;
  });
  await page.route('**/art/demo-hoop-v2.webp', async (route) => {
    await waiting;
    await route.continue();
  });
  try {
    await ready(page);
    await expect(page.locator('[data-demo-art="floor"]')).toHaveAttribute(
      'data-art-ready',
      'true',
    );
    await expect(page.locator('[data-hoop-fallback]')).toBeVisible();
    await expect(page.locator('[data-demo-art="hoop"]')).toHaveCSS(
      'opacity',
      '0',
    );
    release();
    await decodedArt(page);
    await expect(page.locator('[data-hoop-fallback]')).not.toBeVisible();
  } finally {
    release();
  }
});

test('the shared flight reaches the unchanged rim, deforms the recessed net and resets stale feedback', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await ready(page);
  await decodedArt(page);
  await pause();
  await page.clock.runFor(1500);
  await page.locator('[data-point-preset="center"]').dispatchEvent('click');
  const original = await page.locator('[data-net-weave]').getAttribute('d');
  await page.locator('[data-record]').dispatchEvent('click');
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  // The pure timing contract checks the exact 1.20s boundary. The browser
  // samples the first rendered frame after it, allowing two 60Hz RAF ticks.
  await page.clock.runFor(1234);
  const pose = await page.locator('[data-demo-ball]').evaluate((el) => {
    const matrix = (el as SVGGElement).transform.baseVal.consolidate()!.matrix;
    return { x: matrix.e, y: matrix.f, visible: !el.hasAttribute('hidden') };
  });
  expect(pose.x).toBeCloseTo(300, 0);
  expect(pose.y).toBeCloseTo(82, 0);
  expect(pose.visible).toBe(true);
  await page.clock.runFor(180);
  const swishPose = await page.locator('[data-demo-ball]').evaluate((el) => {
    const matrix = (el as SVGGElement).transform.baseVal.consolidate()!.matrix;
    return {
      x: matrix.e,
      y: matrix.f,
      scale: Math.hypot(matrix.a, matrix.b),
    };
  });
  expect(swishPose.x).toBeCloseTo(300, 0);
  expect(swishPose.y).toBeCloseTo(82, 0);
  expect(swishPose.scale).toBeLessThan(0.7);
  const deformed = await page.locator('[data-net-weave]').getAttribute('d');
  expect(deformed).not.toBe(original);
  const anchors = (path: string) =>
    [...path.matchAll(/M(-?[\d.]+) (-?[\d.]+)/g)]
      .map((match) => [Number(match[1]), Number(match[2])])
      .filter(([x, y]) => Math.abs(Math.hypot(x, y) - 16) < 0.02);
  const originalAnchors = anchors(original!);
  expect(originalAnchors.length).toBeGreaterThanOrEqual(8);
  expect(anchors(deformed!)).toEqual(originalAnchors);
  const meshCoordinates = deformed!.match(/-?[\d.]+/g)!.map(Number);
  for (let index = 0; index < meshCoordinates.length; index += 2)
    expect(
      Math.hypot(meshCoordinates[index], meshCoordinates[index + 1]),
    ).toBeLessThanOrEqual(16.05);
  const netBounds = await page.locator('[data-net-weave]').evaluate((el) => {
    const box = (el as SVGPathElement).getBBox();
    return {
      left: box.x,
      top: box.y,
      right: box.x + box.width,
      bottom: box.y + box.height,
    };
  });
  for (const coordinate of Object.values(netBounds))
    expect(Math.abs(coordinate)).toBeLessThanOrEqual(16.05);
  await page.locator('[data-reset]').dispatchEvent('click');
  await page.clock.runFor(2500);
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(page.locator('[data-demo-ball]')).toHaveAttribute('hidden', '');
  await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
    'hidden',
    '',
  );
  await expect(page.locator('[data-net-weave]')).toHaveAttribute(
    'd',
    original!,
  );
});

test('desktop WebGL fallback uses the same art without introducing another scene or duplicated controls', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await ready(page);
  await decodedArt(page);
  await expect(page.locator('[data-demo-court-host]')).toHaveAttribute(
    'data-renderer',
    '2d',
  );
  await expect(page.locator('[data-demo-court]')).toHaveCount(1);
  await expect(page.locator('[data-record]')).toHaveCount(1);
  await expect(page.locator('#court-canvas')).toHaveCount(1);
  await selectCourt(page);
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-demo]')).toHaveAttribute(
    'data-demo-phase',
    'scored',
  );
});

test('background suspension freezes the same net and ball clock and resumes one completed shot', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await ready(page);
  await decodedArt(page);
  await pause();
  await page.clock.runFor(1000);
  await page.locator('[data-point-preset="left"]').dispatchEvent('click');
  await page.locator('[data-record]').dispatchEvent('click');
  await page.clock.runFor(400);
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  const ball = await page.locator('[data-demo-ball]').getAttribute('transform');
  const net = await page.locator('[data-net-weave]').getAttribute('d');
  await page.clock.runFor(2000);
  await expect(page.locator('[data-demo-ball]')).toHaveAttribute(
    'transform',
    ball!,
  );
  await expect(page.locator('[data-net-weave]')).toHaveAttribute('d', net!);
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
  await page.clock.runFor(2200);
  await expect(page.locator('[data-demo]')).toHaveAttribute(
    'data-demo-phase',
    'scored',
  );
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await expect(page.locator('[data-demo-marker]')).toBeVisible();
});

test('without JavaScript the full vector court remains visible instead of empty image placeholders', async ({
  browser,
}) => {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    javaScriptEnabled: false,
  });
  const page = await context.newPage();
  const requested: string[] = [];
  page.on('request', (r) => {
    if (artPath.test(r.url())) requested.push(r.url());
  });
  try {
    await page.goto('http://127.0.0.1:4321/#experience');
    await expect(page.locator('[data-demo-court]')).toBeVisible();
    await expect(page.locator('[data-hoop-fallback]')).toBeVisible();
    expect(requested).toEqual([]);
    for (const image of await page.locator('[data-demo-art]').all())
      expect(await image.getAttribute('href')).toBeNull();
  } finally {
    await context.close();
  }
});

test('high-DPR rendering preserves art registration and complete selectable dimensions', async ({
  browser,
}) => {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 2,
    reducedMotion: 'reduce',
  });
  const page = await context.newPage();
  try {
    await ready(page, 'http://127.0.0.1:4321/#experience');
    await decodedArt(page);
    await selectCourt(page, 0.25, 0.65);
    const host = await page.locator('[data-demo-court-host]').boundingBox();
    expect(host!.width).toBeLessThanOrEqual(288.1);
    expect(host!.width / host!.height).toBeCloseTo(15 / 14, 2);
    await page.locator('[data-record]').click();
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
    await expect(page.locator('[data-blue-score]')).toHaveText('8');
  } finally {
    await context.close();
  }
});

test('@webgl normal desktop 3D does not request or display the generated SVG art', async ({
  page,
}, info) => {
  test.skip(
    info.project.name !== 'chromium',
    'Actual WebGL lifecycle evidence runs in Chromium; three-engine SVG fallback is checked separately.',
  );
  await page.setViewportSize({ width: 1440, height: 900 });
  // The dedicated CI lifecycle job uses SwiftShader, whose capability flag
  // differs from hardware. Match the existing test-only context preparation.
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
  const requested: string[] = [];
  page.on('request', (request) => {
    if (artPath.test(request.url())) requested.push(request.url());
  });
  await page.goto('/#experience');
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
  await expect(page.locator('[data-demo-court-host]')).toHaveAttribute(
    'data-renderer',
    '3d',
  );
  expect(requested).toEqual([]);
  await expect(page.locator('[data-demo-court]')).toHaveCSS('opacity', '0');
});

test('native touch still selects the generated court and completes the unchanged scoring feedback', async ({
  browser,
  browserName,
}) => {
  test.skip(
    browserName !== 'chromium',
    'Native compositor touch injection uses CDP; the same SVG and inputs run in all engines above.',
  );
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    hasTouch: true,
    isMobile: true,
  });
  const page = await context.newPage();
  try {
    await ready(page, 'http://127.0.0.1:4321/#experience');
    await decodedArt(page);
    const court = page.locator('[data-demo-court]');
    await court.scrollIntoViewIfNeeded();
    const point = await court.evaluate((el) =>
      new DOMPoint(28 + 0.35 * 544, 28 + 0.62 * 504)
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
    await expect(page.locator('[data-demo-marker]')).toBeVisible();
    await page.locator('[data-reset]').tap();
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await expect(page.locator('[data-mobile-progress]')).toBeVisible();
    await page.locator('[data-mobile-menu-toggle]').tap();
    await expect(page.locator('[data-mobile-menu]')).toBeVisible();
    await page.locator('[data-mobile-menu-close]').tap();
  } finally {
    await context.close();
  }
});
