import { expect, test, type Page } from '@playwright/test';
import { installContractClock } from './controlled-clock';

const sceneChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;

async function open(page: Page, path: string) {
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('[data-point-preset="center"]')).toBeEnabled();
  await expect(page.locator('[data-story-stage="experience"]')).toHaveAttribute(
    'data-scroll-read-start',
    /\d/,
  );
}

async function reading(page: Page) {
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'experience',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
}

async function settleLayoutClock(page: Page, readingStop = false) {
  let previous = '';
  let stableFor = 0;
  for (let sample = 0; sample < 30; sample++) {
    if (readingStop)
      await page.evaluate(() =>
        scrollTo({
          top: Number(
            document.querySelector<HTMLElement>(
              '[data-story-stage="experience"]',
            )!.dataset.scrollReadStart,
          ),
          behavior: 'instant',
        }),
      );
    await page.clock.runFor(80);
    const state = await page.evaluate(() => {
      const stage = document.querySelector<HTMLElement>(
        '[data-story-stage="experience"]',
      )!;
      const control = document.querySelector('.demo-controls')!;
      const transform = new DOMMatrix(getComputedStyle(control).transform);
      return {
        key: JSON.stringify([
          document.documentElement.scrollHeight,
          stage.dataset.scrollReadStart,
          stage.dataset.scrollReadEnd,
          stage.offsetHeight,
          control.getBoundingClientRect().height,
        ]),
        atRest:
          Math.abs(scrollY - Number(stage.dataset.scrollReadStart)) <= 1 &&
          Math.abs(transform.m11 - 1) < 0.0001 &&
          Number(getComputedStyle(control).opacity) === 1,
      };
    });
    if (state.key === previous && (!readingStop || state.atRest))
      stableFor += 80;
    else stableFor = 0;
    previous = state.key;
    if (stableFor >= 320) return;
  }
  expect(
    stableFor,
    'layout and the real reading pose must settle before measuring text',
  ).toBeGreaterThanOrEqual(320);
}

const layouts = [
  { name: 'compact desktop', width: 1024, height: 768 },
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'wide desktop', width: 1920, height: 1080 },
  { name: 'mobile', width: 390, height: 844 },
  { name: 'short desktop', width: 1440, height: 640 },
  { name: '200 percent text', width: 1024, height: 640, largeText: true },
];

for (const path of ['/', '/en/']) {
  for (const layout of layouts) {
    test(`${path}: experience polish ${layout.name} preserves the court and clear component hierarchy`, async ({
      page,
    }, info) => {
      await page.setViewportSize({
        width: layout.width,
        height: layout.height,
      });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await open(page, `${path}#experience`);
      if (layout.largeText)
        await page.addStyleTag({ content: 'html{font-size:200%!important}' });
      const stage = page.locator('[data-story-stage="experience"]');
      const metrics = await stage.evaluate((element) => {
        const rect = (el: Element) => {
          const r = el.getBoundingClientRect();
          return { x: r.x, y: r.y, width: r.width, height: r.height };
        };
        const host = element.querySelector('[data-demo-court-host]')!;
        const map = element.querySelector('.demo-map')!;
        const slot = element.querySelector('.experience-score-slot')!;
        const board = element.querySelector('.demo-scoreboard')!;
        const heading = element.querySelector('.experience-heading')!;
        const notes = element.querySelector('.demo-control-notes')!;
        return {
          overflow: document.documentElement.scrollWidth - innerWidth,
          titleBackdrop: getComputedStyle(heading, '::before').content,
          bodyBackdrop: getComputedStyle(
            heading.querySelector('.section-body')!,
            '::before',
          ).content,
          lines: [...heading.querySelectorAll('[data-story-line]')].map(
            (el) => ({
              ...rect(el),
              size: parseFloat(getComputedStyle(el).fontSize),
            }),
          ),
          host: rect(host),
          map: rect(map),
          slot: rect(slot),
          board: rect(board),
          mapGrid: getComputedStyle(map).gridColumn,
          hostOverflow: getComputedStyle(host).overflow,
          noteZones:
            Number(notes.matches('.reading-zone')) +
            notes.querySelectorAll('.reading-zone').length,
          statusLive: element
            .querySelector('[data-demo-status]')!
            .getAttribute('aria-live'),
          ghostCount: element.querySelectorAll(
            '.demo-status-slot [aria-hidden="true"]',
          ).length,
          noteSizes: [
            ...notes.querySelectorAll('.demo-status, .fine-print'),
          ].map((el) => parseFloat(getComputedStyle(el).fontSize)),
          scores: [...element.querySelectorAll('.demo-score strong')].map(
            (el) => ({
              ...rect(el),
              size: parseFloat(getComputedStyle(el).fontSize),
            }),
          ),
          targets: [
            ...element.querySelectorAll(
              '[data-point-preset], [data-record], [data-reset]',
            ),
          ].map(rect),
        };
      });
      expect(metrics.overflow).toBeLessThanOrEqual(1);
      expect(metrics.titleBackdrop).toBe('none');
      expect(metrics.bodyBackdrop).toBe('""');
      expect(metrics.noteZones).toBe(1);
      expect(metrics.statusLive).toBe('polite');
      expect(metrics.ghostCount).toBe(4);
      expect(metrics.host.width).toBeCloseTo(metrics.map.width, 1);
      expect(metrics.host.height).toBeGreaterThan(0);
      expect(metrics.hostOverflow).toBe('visible');
      for (const size of metrics.noteSizes)
        expect(size).toBeGreaterThanOrEqual(14);
      for (const target of metrics.targets) {
        expect(target.width).toBeGreaterThanOrEqual(48);
        expect(target.height).toBeGreaterThanOrEqual(48);
      }
      if (layout.width >= 1024 && !layout.largeText) {
        expect(metrics.board.width).toBeLessThanOrEqual(680.1);
        expect(
          Math.abs(
            metrics.board.x +
              metrics.board.width / 2 -
              metrics.slot.x -
              metrics.slot.width / 2,
          ),
        ).toBeLessThanOrEqual(1);
        expect(metrics.mapGrid).toBe('4 / 11');
        expect(metrics.host.height).toBeCloseTo(
          Math.max(340, Math.min(440, layout.height * 0.46)),
          1,
        );
        expect(metrics.lines[1].size).toBeGreaterThanOrEqual(32);
        expect(metrics.lines[1].size).toBeLessThanOrEqual(40);
        for (const score of metrics.scores) {
          expect(score.size).toBeGreaterThanOrEqual(64);
          expect(score.size).toBeLessThanOrEqual(80);
        }
      }
      if (layout.width < 1024)
        expect(metrics.host.width / metrics.host.height).toBeCloseTo(
          15 / 14,
          2,
        );
      await expect(stage.locator('[data-glass-card]')).toHaveCount(2);
      await expect(stage.locator('.point-presets .display')).toHaveCount(0);
      for (const button of await stage.locator('[data-point-preset]').all())
        await expect(button).not.toContainText(/0[123]/);
      await expect(stage.locator('.demo-label')).toContainText(
        path === '/' ? '示例数据' : 'Sample data',
      );
      await info.attach('experience-static-layout', {
        body: JSON.stringify(metrics, null, 2),
        contentType: 'application/json',
      });
    });
  }

  for (const width of [390, 1440]) {
    test(`${path}: experience status reserves every state through selection scoring reset and reflow at ${width}px`, async ({
      page,
    }, info) => {
      const pause = await installContractClock(page);
      await page.setViewportSize({ width, height: 900 });
      await open(page, `${path}#experience`);
      await pause();
      await page.clock.runFor(2000);
      const slot = page.locator('.demo-status-slot');
      const status = page.locator('[data-demo-status]');
      const phase = page.locator('[data-demo]');
      const check = async () => {
        // A font/viewport refresh can move the new reading stop. First settle
        // at that real stop; a 0.99 transition scale is not a text-height change.
        await settleLayoutClock(page, true);
        const initial = (await slot.boundingBox())!;
        const samples: unknown[] = [];
        const stable = async (state: string) => {
          const box = (await slot.boundingBox())!;
          expect(box.height).toBeCloseTo(initial.height, 1);
          const text = await status.evaluate((el) => ({
            content: el.scrollHeight,
            client: el.clientHeight,
            value: el.textContent,
          }));
          expect(text.content).toBeLessThanOrEqual(text.client + 1);
          samples.push({ state, height: box.height, ...text });
        };
        await page.locator('[data-reset]').dispatchEvent('click');
        await stable('ready');
        await page
          .locator('[data-point-preset="center"]')
          .dispatchEvent('click');
        await expect(status).toHaveText(
          (await status.getAttribute('data-selected'))!,
        );
        await stable('selected');
        await page.locator('[data-record]').dispatchEvent('click');
        // Recording is the user's action. The visual flight does not own scoring.
        await expect(page.locator('[data-blue-score]')).toHaveText('8');
        await expect(page.locator('[data-red-score]')).toHaveText('6');
        await expect(phase).toHaveAttribute('data-demo-phase', 'shooting');
        await stable('shooting');
        await page.clock.runFor(2200);
        await expect(phase).toHaveAttribute('data-demo-phase', 'scored');
        await expect(page.locator('[data-demo-marker]')).toBeVisible();
        await stable('scored');
        await page.locator('[data-reset]').dispatchEvent('click');
        await expect(page.locator('[data-blue-score]')).toHaveText('6');
        await expect(page.locator('[data-demo-marker]')).not.toBeVisible();
        await stable('reset');
        return samples;
      };
      const original = await check();
      await page.setViewportSize({
        width: width === 390 ? 430 : 1024,
        height: 900,
      });
      await page.addStyleTag({ content: 'html{font-size:200%!important}' });
      await page.clock.runFor(400);
      const enlarged = await check();
      await info.attach('experience-status-heights', {
        body: JSON.stringify({ original, enlarged }, null, 2),
        contentType: 'application/json',
      });
    });
  }
}

test('experience invitation waits for settled reading then finishes one 800ms court light without selecting', async ({
  page,
}, info) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await open(page, '/');
  await pause();
  const host = page.locator('[data-demo-court-host]');
  const observed = await host.evaluateHandle((element) => {
    const starts: { at: number; scrollState?: string; chapter?: string }[] = [];
    const ends: number[] = [];
    const frames: number[] = [];
    let frame = 0;
    const sampleFrame = () => {
      frames.push(Date.now());
      frame = requestAnimationFrame(sampleFrame);
    };
    frame = requestAnimationFrame(sampleFrame);
    let previous = (element as HTMLElement).dataset.demoInvitation;
    const observer = new MutationObserver(() => {
      const state = (element as HTMLElement).dataset.demoInvitation;
      if (state === previous) return;
      previous = state;
      if (state === 'playing')
        starts.push({
          at: Date.now(),
          scrollState: document.documentElement.dataset.scrollState,
          chapter: document.documentElement.dataset.scrollStop,
        });
      if (state === 'done') ends.push(Date.now());
    });
    observer.observe(element, {
      attributes: true,
      attributeFilter: ['data-demo-invitation'],
    });
    return {
      read: () => ({
        starts: [...starts],
        ends: [...ends],
        frames: [...frames],
      }),
      stop: () => {
        observer.disconnect();
        cancelAnimationFrame(frame);
      },
    };
  });
  try {
    await page.evaluate(() => {
      const previous = document.querySelector<HTMLElement>(
        '[data-story-stage="scoring"]',
      )!;
      const current = document.querySelector<HTMLElement>(
        '[data-story-stage="experience"]',
      )!;
      const from = Number(previous.dataset.scrollReadEnd),
        to = Number(current.dataset.scrollReadStart);
      scrollTo({ top: from + (to - from) * 0.2, behavior: 'instant' });
    });
    await page.clock.runFor(200);
    expect(
      (await observed.evaluate((value) => value.read())).starts,
    ).toHaveLength(0);
    await page.evaluate(() =>
      scrollTo({
        top: Number(
          document.querySelector<HTMLElement>(
            '[data-story-stage="experience"]',
          )!.dataset.scrollReadStart,
        ),
        behavior: 'instant',
      }),
    );
    await page.clock.runFor(1200);
    await reading(page);
    await expect(host).toHaveAttribute('data-demo-invitation', 'done');
    const record = await observed.evaluate((value) => value.read());
    expect(record.starts).toHaveLength(1);
    expect(record.ends).toHaveLength(1);
    expect(record.starts[0].scrollState).toBe('idle');
    expect(record.starts[0].chapter).toBe('experience');
    const gaps = record.frames
      .slice(1)
      .map((at, index) => at - record.frames[index]);
    const frameInterval = Math.max(...gaps);
    expect(gaps.length).toBeGreaterThan(20);
    expect(frameInterval).toBeGreaterThan(0);
    expect(frameInterval).toBeLessThanOrEqual(20);
    // GSAP advances on its last ticker frame. Attribute mutation Date.now can
    // lead/lag that sample by one observed RAF interval (792ms in the raw run),
    // so verify the 800ms profile at actual measured frame resolution.
    expect(
      Math.abs(record.ends[0] - record.starts[0].at - 800),
    ).toBeLessThanOrEqual(frameInterval);
    await expect(page.locator('.point-presets')).not.toHaveAttribute(
      'data-demo-invitation',
      /.+/,
    );
    await expect(page.locator('.demo-invitation-layer')).toHaveCount(2);
    await expect(
      page.locator(
        '.demo-invitation-arrow, .demo-invitation-shade, [data-cue-kind="presets"]',
      ),
    ).toHaveCount(0);
    await expect(
      page.locator('[data-point-preset][aria-pressed="true"]'),
    ).toHaveCount(0);
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await expect(page.locator('[data-record]')).toBeDisabled();
    await info.attach('experience-once-court-light', {
      body: JSON.stringify(record, null, 2),
      contentType: 'application/json',
    });
  } finally {
    await observed.evaluate((value) => value.stop());
    await observed.dispose();
  }
});

test('experience selection cancels the court light and invites only the enabled record button once', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 390, height: 1000 });
  await open(page, '/');
  await pause();
  await settleLayoutClock(page);
  const host = page.locator('[data-demo-court-host]');
  await host.evaluate((el) =>
    el.scrollIntoView({ behavior: 'instant', block: 'center' }),
  );
  for (let frame = 0; frame < 10; frame++) {
    await page.clock.runFor(40);
    if ((await host.getAttribute('data-demo-invitation')) === 'playing') break;
  }
  await expect(host).toHaveAttribute('data-demo-invitation', 'playing');
  await page.locator('[data-point-preset="left"]').dispatchEvent('click');
  await expect(host).toHaveAttribute('data-demo-invitation', 'done');
  const record = page.locator('[data-record]');
  await expect(record).toBeEnabled();
  await record.evaluate((el) =>
    el.scrollIntoView({ behavior: 'instant', block: 'center' }),
  );
  await page.clock.runFor(240);
  await expect(record).toHaveAttribute('data-demo-invitation', 'playing');
  const layer = record.locator('.demo-invitation-layer');
  const bounds = await record.evaluate((el) => {
    const r = el.getBoundingClientRect(),
      b = el.querySelector('.demo-invitation-layer')!.getBoundingClientRect();
    return {
      width: r.width,
      height: r.height,
      overflow: Math.max(
        r.left - b.left,
        r.top - b.top,
        b.right - r.right,
        b.bottom - r.bottom,
      ),
      transform: getComputedStyle(el).transform,
    };
  });
  expect(bounds.overflow).toBeLessThanOrEqual(1);
  expect(bounds.transform).toBe('none');
  await page.clock.runFor(900);
  await expect(record).toHaveAttribute('data-demo-invitation', 'done');
  await expect(layer).toHaveCSS('opacity', '0');
  await page.locator('[data-point-preset="right"]').dispatchEvent('click');
  await page.clock.runFor(240);
  await expect(record).toHaveAttribute('data-demo-invitation', 'done');
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
});

test('experience invitation resumes pending eligibility after background release without new scroll', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.addInitScript(() =>
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    }),
  );
  await page.setViewportSize({ width: 1440, height: 1000 });
  await open(page, '/#experience');
  await reading(page);
  await pause();
  const host = page.locator('[data-demo-court-host]');
  await page.clock.runFor(1200);
  await expect(host).not.toHaveAttribute('data-demo-invitation', 'playing');
  await expect(host).not.toHaveAttribute('data-demo-invitation', 'done');
  const y = await page.evaluate(() => scrollY);
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(160);
  await expect(host).toHaveAttribute('data-demo-invitation', 'playing');
  await page.clock.runFor(900);
  await expect(host).toHaveAttribute('data-demo-invitation', 'done');
  expect(await page.evaluate(() => scrollY)).toBe(y);
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
});

test('experience departure cancels an active hint and returning never repeats its consumed cue', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await open(page, '/');
  await pause();
  const host = page.locator('[data-demo-court-host]');
  await page.evaluate(() =>
    scrollTo({
      top: Number(
        document.querySelector<HTMLElement>('[data-story-stage="experience"]')!
          .dataset.scrollReadStart,
      ),
      behavior: 'instant',
    }),
  );
  await page.clock.runFor(200);
  await expect(host).toHaveAttribute('data-demo-invitation', 'playing');
  await page.evaluate(() => {
    const current = document.querySelector<HTMLElement>(
      '[data-story-stage="experience"]',
    )!;
    const next = document.querySelector<HTMLElement>(
      '[data-story-stage="replay"]',
    )!;
    const from = Number(current.dataset.scrollReadEnd),
      to = Number(next.dataset.scrollReadStart);
    scrollTo({ top: from + (to - from) * 0.2, behavior: 'instant' });
  });
  await page.clock.runFor(80);
  await expect(host).toHaveAttribute('data-demo-invitation', 'done');
  for (const layer of await page.locator('.demo-invitation-layer').all())
    await expect(layer).toHaveCSS('opacity', '0');
  await page.evaluate(() =>
    scrollTo({
      top: Number(
        document.querySelector<HTMLElement>('[data-story-stage="experience"]')!
          .dataset.scrollReadStart,
      ),
      behavior: 'instant',
    }),
  );
  await page.clock.runFor(1200);
  await reading(page);
  await expect(host).toHaveAttribute('data-demo-invitation', 'done');
  for (const layer of await page.locator('.demo-invitation-layer').all())
    await expect(layer).toHaveCSS('opacity', '0');
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
});

test('experience mobile light needs 55 percent visible target and reduced motion suppresses both hints', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 390, height: 844 });
  await open(page, '/');
  await pause();
  const host = page.locator('[data-demo-court-host]');
  await host.evaluate((el) => {
    const r = el.getBoundingClientRect();
    scrollTo({
      top: scrollY + r.top - innerHeight + r.height * 0.4,
      behavior: 'instant',
    });
  });
  await page.clock.runFor(200);
  await expect(host).not.toHaveAttribute('data-demo-invitation', 'playing');
  await host.evaluate((el) =>
    el.scrollIntoView({ behavior: 'instant', block: 'center' }),
  );
  await page.clock.runFor(160);
  await expect(host).toHaveAttribute('data-demo-invitation', 'playing');
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.clock.runFor(80);
  await expect(host).toHaveAttribute('data-demo-invitation', 'done');
  await page.locator('[data-point-preset="center"]').dispatchEvent('click');
  await expect(page.locator('[data-record]')).toHaveAttribute(
    'data-demo-invitation',
    'done',
  );
  for (const layer of await page.locator('.demo-invitation-layer').all())
    await expect(layer).toHaveCSS('opacity', '0');
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await page.locator('[data-record]').dispatchEvent('click');
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await expect(page.locator('[data-demo-marker]')).toBeVisible();
});

test('experience active record light stays paused until both gallery and hidden reasons are released', async ({
  page,
}, info) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await open(page, '/#experience');
  await reading(page);
  await pause();
  await settleLayoutClock(page, true);
  await page.locator('[data-point-preset="center"]').dispatchEvent('click');
  await page.clock.runFor(160);
  const record = page.locator('[data-record]');
  await expect(record).toBeEnabled();
  await expect(record).toHaveAttribute('data-demo-invitation', 'playing');
  const light = record.locator('.demo-invitation-light');
  const before = Number(
    await light.evaluate((el) => getComputedStyle(el).opacity),
  );
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    document.dispatchEvent(new Event('visibilitychange'));
    document.querySelector<HTMLAnchorElement>('#scoring .viewer-link')!.click();
  });
  await expect(page.locator('[data-viewer]')).toBeVisible();
  await page.clock.runFor(1600);
  await expect(record).toHaveAttribute('data-demo-invitation', 'playing');
  expect(
    Number(await light.evaluate((el) => getComputedStyle(el).opacity)),
  ).toBeCloseTo(before, 4);
  await page.locator('[data-viewer-close]').dispatchEvent('click');
  await page.clock.runFor(400);
  await expect(record).toHaveAttribute('data-demo-invitation', 'playing');
  expect(
    Number(await light.evaluate((el) => getComputedStyle(el).opacity)),
  ).toBeCloseTo(before, 4);
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.clock.runFor(1000);
  await expect(record).toHaveAttribute('data-demo-invitation', 'done');
  await expect(record.locator('.demo-invitation-layer')).toHaveCSS(
    'opacity',
    '0',
  );
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(page.locator('[data-point-preset="center"]')).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await info.attach('experience-dual-pause-light', {
    body: JSON.stringify({
      opacityBeforePause: before,
      selected: 'center',
      score: '6:6',
    }),
    contentType: 'application/json',
  });
});
