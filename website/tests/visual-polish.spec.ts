import { expect, test, type Page, type TestInfo } from '@playwright/test';
import sharp from 'sharp';

const sceneChunk = /court-scene[^/]*\.(?:js|ts)(?:\?|$)/;
const stops = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
  'community',
  'closing',
] as const;
type Stop = (typeof stops)[number];
type Range = { start: number; end: number };
type Pose = {
  role: string;
  opacity: number;
  x: number;
  y: number;
  scale: number;
  inert: boolean;
};
type MotionFrame = {
  time: number;
  sampleCost: number;
  y: number;
  state?: string;
  stop?: string;
  roles: Pose[];
  opticalErrors: string[];
};
const stage = (id: Stop) =>
  id === 'closing' ? '#closing' : `[data-story-stage="${id}"]`;

async function range(page: Page, id: Stop): Promise<Range> {
  return page.locator(stage(id)).evaluate((element: HTMLElement) => ({
    start: Number(element.dataset.scrollReadStart),
    end: Number(element.dataset.scrollReadEnd),
  }));
}

async function layoutStable(page: Page) {
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('#closing')).toHaveAttribute(
    'data-scroll-read-end',
    /\d/,
  );
  // The observer can publish more than one refresh after fonts or header
  // reflow. Observe actual geometry AND published bounds for a quiet interval
  // before reading coordinates; never seek an obsolete range until it passes.
  let previous = '';
  let stableSince = 0;
  await expect
    .poll(async () => {
      const checkpoint = await page.evaluate(() => {
        const header = document.querySelector('.site-header')!;
        const measured = parseFloat(
          getComputedStyle(document.documentElement).getPropertyValue(
            '--measured-header',
          ),
        );
        const geometry = [
          ...document.querySelectorAll<HTMLElement>(
            '[data-story-stage], #closing',
          ),
        ].map((element) => ({
          start: element.dataset.scrollReadStart,
          end: element.dataset.scrollReadEnd,
          storyStart: element.dataset.storyStart,
          storyEnd: element.dataset.storyEnd,
          width: element.getBoundingClientRect().width,
          height: element.getBoundingClientRect().height,
          contentHeight: element.scrollHeight,
        }));
        return {
          key: JSON.stringify({
            geometry,
            height: document.documentElement.scrollHeight,
            header: header.getBoundingClientRect().height,
            measured,
          }),
          ready:
            document.fonts.status === 'loaded' &&
            geometry.every(
              ({ start, end }) =>
                start !== undefined &&
                end !== undefined &&
                Number.isFinite(Number(start)) &&
                Number(end) >= Number(start),
            ) &&
            Math.abs(header.getBoundingClientRect().height - measured) <= 1 &&
            document.documentElement.dataset.scrollState === 'idle',
        };
      });
      if (checkpoint.key !== previous || !checkpoint.ready) {
        previous = checkpoint.key;
        stableSince = Date.now();
      }
      return checkpoint.ready && Date.now() - stableSince >= 300;
    })
    .toBe(true);
}

async function open(
  page: Page,
  path: string,
  options: { css?: boolean; reduced?: boolean } = {},
) {
  if (options.css !== false)
    await page.route(sceneChunk, (route) => route.abort());
  await page.emulateMedia({
    reducedMotion: options.reduced ? 'reduce' : 'no-preference',
  });
  await page.goto(path);
  await layoutStable(page);
}

async function reading(page: Page, id: Stop) {
  await expect
    .poll(async () => {
      const bounds = await range(page, id);
      return page.locator(stage(id)).evaluate((element, bounds) => {
        return (
          scrollY >= bounds.start - 2 &&
          scrollY <= bounds.end + 2 &&
          document.documentElement.dataset.scrollState === 'idle' &&
          [...element.querySelectorAll<HTMLElement>('[data-story-item]')].every(
            (item) => Number(getComputedStyle(item).opacity) >= 0.999,
          )
        );
      }, bounds);
    })
    .toBe(true);
  await expect(page.locator('html')).toHaveAttribute('data-scroll-stop', id);
}

async function seekEdge(page: Page, id: Stop, edge: keyof Range) {
  await layoutStable(page);
  // Scrollbar-style preparation, performed once using the stable current map.
  await page.mouse.click(8, 450);
  const before = await range(page, id);
  await page.evaluate(
    (top) => scrollTo({ top, behavior: 'instant' }),
    before[edge],
  );
  await reading(page, id);
  expect(await range(page, id)).toEqual(before);
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - before[edge]),
  ).toBeLessThanOrEqual(2);
}

async function attach(testInfo: TestInfo, name: string, value: unknown) {
  await testInfo.attach(name, {
    body: JSON.stringify(value, null, 2),
    contentType: 'application/json',
  });
}

async function beginMotionTrace(page: Page) {
  await page.evaluate(() => {
    const frames: MotionFrame[] = [];
    let active = true;
    let wheelAt: number | undefined;
    const wheel = () => (wheelAt ??= performance.now());
    window.addEventListener('wheel', wheel, { capture: true });
    const sample = () => {
      const samplingStarted = performance.now();
      const roles = [
        ...document.querySelectorAll<HTMLElement>('#scoring [data-story-item]'),
      ].map((item) => {
        const style = getComputedStyle(item);
        const matrix = new DOMMatrixReadOnly(style.transform);
        return {
          role: item.dataset.storyItem!,
          opacity: Number(style.opacity),
          x: matrix.m41,
          y: matrix.m42,
          scale: matrix.a,
          inert: item.inert,
        };
      });
      const opticalErrors = [
        ...document.querySelectorAll<HTMLElement>('[data-glass-card]'),
      ].flatMap((card) => {
        const style = getComputedStyle(card);
        const matrix = new DOMMatrixReadOnly(style.transform);
        return style.clipPath !== 'none' ||
          Math.abs(matrix.a - matrix.d) > 0.001 ||
          Math.abs(matrix.b) > 0.001 ||
          Math.abs(matrix.c) > 0.001
          ? [card.dataset.glassId!]
          : [];
      });
      frames.push({
        time: performance.now(),
        sampleCost: performance.now() - samplingStarted,
        y: scrollY,
        state: document.documentElement.dataset.scrollState,
        stop: document.documentElement.dataset.scrollStop,
        roles,
        opticalErrors,
      });
      if (active) requestAnimationFrame(sample);
    };
    requestAnimationFrame(sample);
    Reflect.set(window, '__finishPolishMotionTrace', () => {
      active = false;
      window.removeEventListener('wheel', wheel, { capture: true });
      sample();
      return { wheelAt, frames };
    });
  });
}

async function finishMotionTrace(page: Page) {
  return page.evaluate(() =>
    (
      Reflect.get(window, '__finishPolishMotionTrace') as () => {
        wheelAt: number;
        frames: MotionFrame[];
      }
    )(),
  );
}

for (const path of ['/', '/en/']) {
  for (const layout of [
    { name: '390px mobile', width: 390, height: 844, dpr: 1, scale: 1 },
    { name: '1024px compact', width: 1024, height: 768, dpr: 1, scale: 1 },
    { name: '1440px DPR1.5', width: 1440, height: 871, dpr: 1.5, scale: 1 },
    { name: '1920px desktop', width: 1920, height: 1080, dpr: 1, scale: 1 },
    { name: 'short desktop', width: 1440, height: 600, dpr: 1, scale: 1 },
    { name: '200 percent', width: 1024, height: 640, dpr: 1, scale: 2 },
  ]) {
    test(`${path}: ${layout.name} hero reading scrims leave the orange download action unobscured`, async ({
      browser,
      baseURL,
    }, testInfo) => {
      const context = await browser.newContext({
        baseURL,
        viewport: { width: layout.width, height: layout.height },
        deviceScaleFactor: layout.dpr,
      });
      try {
        const page = await context.newPage();
        await open(page, `${path}#hero`, { reduced: true });
        if (layout.scale !== 1) {
          await page.evaluate((scale) => {
            document.documentElement.style.fontSize = `${scale * 100}%`;
          }, layout.scale);
          await layoutStable(page);
        }
        // Long first chapters retain their natural reading range. Its end puts
        // the complete action and the lower hint on screen without reflowing it.
        await seekEdge(page, 'hero', 'end');
        await page.mouse.move(8, 100);
        const button = page.locator('.hero-actions [data-download]');
        await expect(button).toBeInViewport({ ratio: 1 });
        const expected = await button.evaluate((element) =>
          getComputedStyle(element)
            .backgroundColor.match(/\d+/g)!
            .slice(0, 3)
            .map(Number),
        );
        const screenshot = await button.screenshot({ scale: 'css' });
        const { data, info } = await sharp(screenshot)
          .ensureAlpha()
          .raw()
          .toBuffer({ resolveWithObject: true });
        // The text starts after22px left padding. Sample a3px patch inside
        // that empty lane, away from the8px rounded edge, text and the icon.
        const samples = [9, Math.floor(info.height / 2), info.height - 10].map(
          (y) => {
            const pixels = [];
            for (let dy = 0; dy < 3; dy++)
              for (let x = 11; x < 14; x++) {
                const offset = ((y + dy) * info.width + x) * 4;
                pixels.push([...data.subarray(offset, offset + 3)]);
              }
            return { y, pixels };
          },
        );
        await testInfo.attach('hero-action-painted-pixels', {
          body: screenshot,
          contentType: 'image/png',
        });
        await attach(testInfo, 'hero-action-color-samples', {
          layout,
          expected,
          width: info.width,
          height: info.height,
          samples,
        });
        for (const { y, pixels } of samples)
          for (const pixel of pixels)
            pixel.forEach((channel, index) =>
              expect(
                Math.abs(channel - expected[index]),
                `The painted button at y=${y} must retain its own orange fill`,
              ).toBeLessThanOrEqual(4),
            );
      } finally {
        await context.close();
      }
    });
  }

  test(`${path}: real scroll preserves the full ordered reveal in both directions`, async ({
    page,
  }, testInfo) => {
    await open(page, path);
    for (const [source, edge, delta, label] of [
      ['hero', 'end', 24, 'forward'],
      ['experience', 'start', -24, 'reverse'],
    ] as const) {
      await seekEdge(page, source, edge);
      await page.mouse.move(20, 450);
      const from = await page.evaluate(() => scrollY);
      const target = (await range(page, 'scoring'))[
        delta > 0 ? 'start' : 'end'
      ];
      await beginMotionTrace(page);
      let trace: Awaited<ReturnType<typeof finishMotionTrace>>;
      try {
        await page.mouse.wheel(0, delta);
        await reading(page, 'scoring');
      } finally {
        trace = await finishMotionTrace(page);
        await attach(testInfo, `${label}-all-native-frames`, trace);
      }
      const frames = trace.frames.filter(
        (frame) => frame.time >= trace.wheelAt,
      );
      const arrived = frames.find(
        (frame) =>
          frame.state === 'idle' &&
          Math.abs(frame.y - target) <= 2 &&
          frame.roles.every((pose) => pose.opacity >= 0.999),
      )!;
      expect(arrived, `${label}: no fully rendered arrival`).toBeDefined();
      const duration = arrived.time - trace.wheelAt;
      const flight = frames.filter((frame) => frame.time <= arrived.time);
      const maxGap = Math.max(
        ...flight.slice(1).map((frame, i) => frame.time - flight[i].time),
      );
      const onset = Object.fromEntries(
        ['visual', 'heading', 'control'].map((role) => [
          role,
          flight.find((frame) =>
            frame.roles.some(
              (pose) => pose.role === role && pose.opacity > 0.02,
            ),
          )!.time - trace.wheelAt,
        ]),
      );
      await attach(testInfo, `${label}-timing-summary`, {
        duration,
        maxGap,
        maxSampleCost: Math.max(...flight.map((frame) => frame.sampleCost)),
        onset,
        // Design ideals are separate from observed browser onset timestamps.
        idealOnsetMs: { visual: 497, heading: 628, control: 779 },
        from,
        target,
      });
      // Keep a failed direction failed while still collecting the reverse run.
      // Both directions' raw traces are needed to diagnose a browser stall.
      expect.soft(duration).toBeGreaterThanOrEqual(1150);
      expect.soft(duration).toBeLessThanOrEqual(2500);
      // Missing a large interval cannot establish reveal order. Preserve such
      // a run as a failure, independently of the separate GPU cadence gate.
      expect.soft(maxGap).toBeLessThan(180);
      expect.soft(onset.visual).toBeGreaterThan(400);
      expect.soft(onset.visual).toBeLessThan(650);
      expect.soft(onset.heading - onset.visual).toBeGreaterThan(40);
      expect.soft(onset.control - onset.heading).toBeGreaterThan(40);
      expect.soft(onset.control).toBeGreaterThan(680);
      expect.soft(onset.control).toBeLessThan(1000);
      for (const role of ['visual', 'heading', 'control']) {
        const partial = flight.filter((frame) =>
          frame.roles.some(
            (pose) =>
              pose.role === role && pose.opacity > 0.05 && pose.opacity < 0.95,
          ),
        );
        expect
          .soft(partial.length, `${label} ${role}: intermediate poses`)
          .toBeGreaterThan(2);
        if (partial.length)
          expect
            .soft(partial.at(-1)!.time - partial[0].time)
            .toBeGreaterThan(100);
      }
      for (const fraction of [0.25, 0.5, 0.75]) {
        const expectedAt = trace.wheelAt + 1200 * fraction;
        const nearest = flight.reduce((best, frame) =>
          Math.abs(frame.time - expectedAt) < Math.abs(best.time - expectedAt)
            ? frame
            : best,
        );
        expect.soft(Math.abs(nearest.time - expectedAt)).toBeLessThan(90);
        const elapsed = (nearest.time - trace.wheelAt) / 1200;
        const ideal = (1 - Math.cos(Math.PI * elapsed)) / 2;
        expect
          .soft(Math.abs((nearest.y - from) / (target - from) - ideal))
          .toBeLessThan(0.065);
      }
      for (const [index, frame] of flight.slice(1).entries()) {
        expect
          .soft((frame.y - flight[index].y) * Math.sign(delta))
          .toBeGreaterThanOrEqual(-2);
      }
      expect.soft(flight.flatMap((frame) => frame.opticalErrors)).toEqual([]);
      expect.soft(arrived.roles.every((pose) => !pose.inert)).toBe(true);
    }
  });

  test(`${path}: hover and press leave optical and button bounds stationary`, async ({
    page,
  }, testInfo) => {
    await open(page, `${path}#hero`);
    await reading(page, 'hero');
    const button = page.locator('.hero-actions [data-download]');
    const card = page.locator('[data-glass-id="hero-actions"]');
    const geometry = () =>
      button.evaluate((element) => {
        const box = (value: Element) => {
          const rect = value.getBoundingClientRect();
          return {
            x: rect.x,
            y: rect.y,
            width: rect.width,
            height: rect.height,
          };
        };
        const content = element.querySelector('.control-content')!;
        const icon = element.querySelector('[data-ui-icon]')!;
        const contentMatrix = new DOMMatrixReadOnly(
          getComputedStyle(content).transform,
        );
        const iconMatrix = new DOMMatrixReadOnly(
          getComputedStyle(icon).transform,
        );
        return {
          button: box(element),
          card: box(element.closest('[data-glass-card]')!),
          innerScale: contentMatrix.a,
          iconX: iconMatrix.m41,
        };
      });
    await page.mouse.move(10, 450);
    const initial = await geometry();
    await button.hover();
    await expect.poll(async () => (await geometry()).iconX).toBeCloseTo(2, 1);
    const hovered = await geometry();
    expect(hovered.button).toEqual(initial.button);
    expect(hovered.card).toEqual(initial.card);
    await page.mouse.down();
    try {
      await expect
        .poll(async () => (await geometry()).innerScale)
        .toBeCloseTo(0.985, 3);
      const pressed = await geometry();
      expect(pressed.button).toEqual(initial.button);
      expect(pressed.card).toEqual(initial.card);
      await attach(testInfo, 'stationary-optical-states', {
        initial,
        hovered,
        pressed,
      });
    } finally {
      await page.mouse.move(10, 450);
      await page.mouse.up();
    }
    await expect(card).toHaveCSS('opacity', '1');
    await expect(page.locator('[data-download-dialog]')).not.toBeVisible();
    // WebKit's platform default skips links in sequential tab navigation.
    // Enter keyboard modality, then establish the same focused-link condition.
    await page.keyboard.press('Tab');
    await button.focus();
    await expect(button).toBeFocused();
    await expect(button).toHaveCSS('outline-style', 'solid');
  });

  for (const layout of [
    { name: 'mobile', width: 390, height: 844, scale: 1 },
    { name: 'short', width: 1440, height: 600, scale: 1 },
    { name: '200 percent', width: 1024, height: 640, scale: 2 },
  ]) {
    test(`${path}: ${layout.name} metadata and FAQ retain readable natural layout`, async ({
      page,
    }, testInfo) => {
      await page.setViewportSize(layout);
      const reduced = layout.name !== 'short';
      await open(page, `${path}#closing`, { reduced });
      if (layout.scale !== 1) {
        await page.evaluate((scale) => {
          document.documentElement.style.fontSize = `${scale * 100}%`;
        }, layout.scale);
        await layoutStable(page);
      }
      const before = await range(page, 'closing');
      // The actual keyboard disclosure preserves native details semantics.
      for (const summary of await page.locator('.faq summary').all()) {
        await summary.focus();
        await page.keyboard.press('Enter');
        await expect(summary.locator('..')).toHaveAttribute('open', '');
      }
      await layoutStable(page);
      const expanded = await range(page, 'closing');
      expect(expanded.end).toBeGreaterThan(before.end + 20);
      const report = await page.evaluate(() => {
        const visible = (element: HTMLElement) =>
          getComputedStyle(element).display !== 'none' &&
          element.getClientRects().length > 0;
        const tooSmall = (selector: string, minimum: number) =>
          [...document.querySelectorAll<HTMLElement>(selector)]
            .filter(
              (element) =>
                visible(element) &&
                parseFloat(getComputedStyle(element).fontSize) < minimum,
            )
            .map((element) => element.className || element.tagName);
        const faq = [
          ...document.querySelectorAll<HTMLElement>('.faq-answer'),
        ].map((answer) => {
          const copy = answer.querySelector('p')!;
          const box = answer.getBoundingClientRect();
          const text = copy.getBoundingClientRect();
          return {
            clipped:
              text.top < box.top - 1 ||
              text.bottom > box.bottom + 1 ||
              copy.scrollWidth > copy.clientWidth + 1,
            height: box.height,
            transition: getComputedStyle(answer).transitionProperty,
            transitionDuration: getComputedStyle(answer).transitionDuration,
          };
        });
        return {
          smallMetadata: tooSmall(
            '.capture-note, .capture-note > span, .site-header nav > a, .fine-print, .community-note',
            14,
          ),
          smallBody: tooSmall(
            '.hero-lead, .section-lead, .community-copy > p:not(.community-note), .faq-answer p',
            16,
          ),
          clippedTitles: [
            ...document.querySelectorAll<HTMLElement>(
              'main h1, main h2, main h3',
            ),
          ]
            .filter((element) => element.scrollWidth > element.clientWidth + 1)
            .map((element) => element.textContent),
          horizontalOverflow: document.documentElement.scrollWidth - innerWidth,
          footerEnd: document.documentElement.scrollHeight - innerHeight,
          faq,
        };
      });
      await attach(testInfo, 'expanded-reading-layout', {
        before,
        expanded,
        report,
      });
      expect(report.smallMetadata).toEqual([]);
      expect(report.smallBody).toEqual([]);
      expect(report.clippedTitles).toEqual([]);
      expect(report.horizontalOverflow).toBeLessThanOrEqual(1);
      expect(
        report.faq.every((answer) => !answer.clipped && answer.height > 0),
      ).toBe(true);
      expect(
        report.faq.every((answer) => {
          const durations = answer.transitionDuration
            .split(',')
            .map(parseFloat);
          return answer.transition
            .split(',')
            .every(
              (property, index) =>
                !/^(?:(?:max-)?height|all)$/.test(property.trim()) ||
                durations[index % durations.length] === 0,
            );
        }),
      ).toBe(true);
      expect(Math.abs(expanded.end - report.footerEnd)).toBeLessThanOrEqual(2);
      await page.evaluate(
        (top) => scrollTo({ top, behavior: 'instant' }),
        expanded.end,
      );
      await expect(page.locator('.footer-bottom small')).toBeInViewport();
      await page.screenshot({
        path: testInfo.outputPath('expanded-faq-footer.png'),
      });
      if (reduced) await expect(page.locator('.pin-spacer')).toHaveCount(0);
    });
  }
}

for (const mode of [
  { name: '390px mobile', width: 390, height: 844, reduced: false },
  { name: 'desktop reduced motion', width: 1440, height: 900, reduced: true },
]) {
  test(`${mode.name} retains native wheel reading without chapter capture`, async ({
    page,
  }, testInfo) => {
    await page.setViewportSize(mode);
    await open(page, '/', { reduced: mode.reduced });
    await page.mouse.move(20, 450);
    await page.mouse.wheel(0, 60);
    await expect.poll(() => page.evaluate(() => scrollY)).toBeGreaterThan(0);
    const samples = await page.evaluate(async () => {
      const start = performance.now();
      const frames: { at: number; y: number; state?: string }[] = [];
      while (performance.now() - start < 600) {
        await new Promise(requestAnimationFrame);
        frames.push({
          at: performance.now(),
          y: scrollY,
          state: document.documentElement.dataset.scrollState,
        });
      }
      return frames;
    });
    await attach(testInfo, 'native-reading-frames', samples);
    expect(samples.every((sample) => sample.state === 'idle')).toBe(true);
    expect(samples.at(-1)!.y).toBeGreaterThan(0);
    expect(samples.at(-1)!.y).toBeLessThan(
      (await range(page, 'scoring')).start - 2,
    );
    const quiet = samples.filter(
      (sample) => sample.at >= samples.at(-1)!.at - 200,
    );
    expect(
      Math.max(...quiet.map((sample) => sample.y)) -
        Math.min(...quiet.map((sample) => sample.y)),
    ).toBeLessThanOrEqual(2);
    await expect(page.locator('.pin-spacer')).toHaveCount(0);
  });
}

test('a fixed pointer can preview, return and repeatedly commit upward through cards', async ({
  page,
}, testInfo) => {
  await open(page, '/#experience');
  await seekEdge(page, 'experience', 'start');
  const box = (await page
    .locator('[data-glass-id="experience-controls"]')
    .boundingBox())!;
  const pointer = { x: box.x + box.width / 2, y: box.y + 24 };
  await page.mouse.move(pointer.x, pointer.y);
  const before = await page.evaluate(() => scrollY);
  await page.mouse.wheel(0, -23);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'tracking',
  );
  await reading(page, 'experience');
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - before),
  ).toBeLessThanOrEqual(2);
  const results = [];
  for (const [delta, destination] of [
    [-24, 'scoring'],
    [-24, 'hero'],
    [24, 'scoring'],
    [24, 'experience'],
    [-24, 'scoring'],
  ] as const) {
    await page.mouse.wheel(0, delta);
    await reading(page, destination);
    results.push({ delta, destination, y: await page.evaluate(() => scrollY) });
  }
  await attach(testInfo, 'fixed-pointer-native-wheel', {
    pointer,
    before,
    results,
  });
});

test('keyboard, navigation and modal actions take over a committed motion', async ({
  page,
}, testInfo) => {
  await open(page, '/');
  await reading(page, 'hero');
  await page.mouse.move(20, 450);
  await page.mouse.wheel(0, 24);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await page.keyboard.press('End');
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect(page.locator('.footer-bottom small')).toBeInViewport();
  await page.locator('.site-footer a[href="#hero"]').click();
  await reading(page, 'hero');
  await page.mouse.move(20, 450);
  await page.mouse.wheel(0, 24);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  await page.locator('.nav-download').click();
  await reading(page, 'download');
  await page.locator('.download-package [data-download]').click();
  await expect(page.locator('[data-download-dialog]')).toBeVisible();
  const before = await page.evaluate(() => scrollY);
  await page.keyboard.press('PageDown');
  await page.mouse.wheel(0, -120);
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - before),
  ).toBeLessThanOrEqual(2);
  await page.keyboard.press('Escape');
  await expect(page.locator('[data-download-dialog]')).not.toBeVisible();
  await reading(page, 'download');
  await attach(testInfo, 'native-takeover', {
    y: before,
    range: await range(page, 'download'),
  });
});

test('@webgl both flight directions keep rendered optical regions on their real DOM cards', async ({
  page,
}, testInfo) => {
  test.setTimeout(60_000);
  const capable = await page.evaluate(() => {
    const context = document
      .createElement('canvas')
      .getContext('webgl2', { failIfMajorPerformanceCaveat: true });
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!context;
  });
  await attach(testInfo, 'webgl-capability', { capable });
  test.skip(
    !capable,
    'Production WebGL2 capability probe is unavailable; CSS coverage runs separately.',
  );
  // Observe real scene submissions and flushes, without changing their timing,
  // input, material, quality or rendering behavior.
  await page.route(sceneChunk, async (route) => {
    const response = await route.fetch();
    let body = await response.text();
    const exports = body.match(/export\s*\{([^}]*\bcreateCourtScene\b[^}]*)\}/);
    const factory = exports?.[1].match(
      /(?:^|,)\s*([\w$]+)\s+as\s+createCourtScene\b/,
    )?.[1];
    if (!exports || !factory)
      throw new Error('Cannot observe the production scene factory.');
    body = body.replace(
      exports[0],
      exports[0].replace(
        /[\w$]+\s+as\s+createCourtScene\b/,
        '__polishSceneCreate as createCourtScene',
      ),
    );
    body += `\nasync function __polishSceneCreate(...args) {
      const scene = await ${factory}(...args);
      let surfaces = [];
      const frames = [];
      Reflect.set(window, '__polishOpticalFrames', frames);
      const set = scene.setGlassSurfaces.bind(scene);
      scene.setGlassSurfaces = (value) => { surfaces = structuredClone(value); set(value); };
      const flush = scene.flushFrame.bind(scene);
      scene.flushFrame = () => {
        const before = Number(args[0].dataset.renderCount);
        flush();
        if (Number(args[0].dataset.renderCount) === before) return;
        frames.push({ time: performance.now(), y: scrollY, quality: args[0].dataset.quality,
          renderer: args[0].dataset.renderer, glass: args[0].dataset.glass,
          surfaces: surfaces.map(surface => {
            const element = [...document.querySelectorAll('[data-glass-id]')].find(card => card.dataset.glassId === surface.id);
            const bounds = element.getBoundingClientRect();
            return { id: surface.id, region: surface.region, dom: {left:bounds.left, top:bounds.top, width:bounds.width, height:bounds.height},
              error: Math.max(...['left','top','width','height'].map(key => Math.abs(bounds[key] - surface.region[key]))) };
          }) });
      };
      return scene;
    }`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
  await open(page, '/#hero', { css: false });
  // A positive capability probe followed by failed startup is a test failure,
  // not a reason to reclassify the run as unsupported WebGL.
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20_000,
  });
  const flights: {
    source: string;
    started: number;
    ended: number;
    from: number;
    to: number;
  }[] = [];
  for (const [source, edge, delta] of [
    ['hero', 'end', 24],
    ['experience', 'start', -24],
  ] as const) {
    await seekEdge(page, source, edge);
    await page.mouse.move(20, 450);
    const from = await page.evaluate(() => scrollY);
    const to = (await range(page, 'scoring'))[delta > 0 ? 'start' : 'end'];
    const started = await page.evaluate(() => performance.now());
    await page.mouse.wheel(0, delta);
    await reading(page, 'scoring');
    flights.push({
      source,
      started,
      ended: await page.evaluate(() => performance.now()),
      from,
      to,
    });
  }
  const frames = await page.evaluate(
    () =>
      Reflect.get(window, '__polishOpticalFrames') as {
        time: number;
        y: number;
        quality: string;
        glass: string;
        surfaces: { error: number }[];
      }[],
  );
  await attach(testInfo, 'all-production-optical-flushes', frames);
  await attach(testInfo, 'production-flight-intervals', flights);
  expect(frames.length).toBeGreaterThan(6);
  for (const flight of flights) {
    const moving = frames.filter(
      (frame) =>
        frame.time >= flight.started &&
        frame.time <= flight.ended &&
        Math.min(flight.from, flight.to) + 2 < frame.y &&
        frame.y < Math.max(flight.from, flight.to) - 2,
    );
    expect(
      moving.length,
      `${flight.source}: real rendered moving frames`,
    ).toBeGreaterThan(3);
  }
  const optical = frames.filter(
    (frame) => frame.quality === 'full' && frame.glass === 'webgl',
  );
  await attach(testInfo, 'optical-capability-result', {
    renderedFrames: frames.length,
    opticalFrames: optical.length,
    modes: [
      ...new Set(frames.map((frame) => `${frame.quality}/${frame.glass}`)),
    ],
  });
  if (optical.length) {
    expect(
      optical.filter((frame) => frame.surfaces.length).length,
    ).toBeGreaterThan(6);
    expect(
      Math.max(
        ...optical.flatMap((frame) =>
          frame.surfaces.map((surface) => surface.error),
        ),
      ),
    ).toBeLessThan(0.1);
  } else {
    testInfo.annotations.push({
      type: 'capability',
      description:
        'WebGL court rendered with CSS optics; this run does not establish WebGL optical contour coverage.',
    });
  }
  for (const frame of frames.filter((frame) => frame.quality !== 'full')) {
    expect(frame.surfaces).toHaveLength(0);
  }
});
