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
              '[data-demo-points], [data-point-preset], [data-record], [data-reset]',
            ),
          ].map(rect),
        };
      });
      expect(metrics.overflow).toBeLessThanOrEqual(1);
      expect(metrics.titleBackdrop).toBe('none');
      expect(metrics.bodyBackdrop).toBe('""');
      expect(metrics.noteZones).toBe(1);
      expect(metrics.statusLive).toBe('polite');
      expect(metrics.ghostCount).toBe(12);
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
        await stable('awaiting a score');
        await page.locator('[data-reset]').dispatchEvent('click');
        await page.locator('[data-demo-points="2"]').dispatchEvent('click');
        await stable('awaiting a matching location');
        await page
          .locator('[data-point-preset="center"]')
          .dispatchEvent('click');
        await expect(status).toHaveText(
          (await status.getAttribute('data-selected'))!.replaceAll(
            '{points}',
            '2',
          ),
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

const guideRoot = '[data-demo-guide]';
const cue = (page: Page, kind: 'court' | 'score' | 'record') =>
  page.locator(`[data-demo-cue="${kind}"]`);

async function scrollToTarget(page: Page, target: string) {
  return page.locator(target).evaluate((el) => {
    el.scrollIntoView({ behavior: 'instant', block: 'center' });
    return scrollY;
  });
}

async function setPageHidden(page: Page, hidden: boolean) {
  await page.evaluate((value) => {
    Object.defineProperty(document, 'hidden', { configurable: true, value });
    document.dispatchEvent(new Event('visibilitychange'));
  }, hidden);
}

test('experience guide waits for settled reading and draws each entry cue once per reset', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await open(page, '/');
  await pause();
  const guide = page.locator(guideRoot);
  const observed = await guide.evaluateHandle((element) => {
    const events: {
      kind: string;
      at: number;
      state: string;
      chapter?: string;
      scrollState?: string;
    }[] = [];
    const observer = new MutationObserver((records) => {
      for (const record of records) {
        const target = record.target as HTMLElement;
        if (!target.dataset.demoCue || !target.dataset.cueState) continue;
        events.push({
          kind: target.dataset.demoCue,
          at: performance.now(),
          state: target.dataset.cueState,
          chapter: document.documentElement.dataset.scrollStop,
          scrollState: document.documentElement.dataset.scrollState,
        });
      }
    });
    observer.observe(element, {
      attributes: true,
      subtree: true,
      attributeFilter: ['data-cue-state'],
    });
    return { events, observer };
  });
  try {
    await page.evaluate(() => {
      const previous = document.querySelector<HTMLElement>(
        '[data-story-stage="scoring"]',
      )!;
      const current = document.querySelector<HTMLElement>(
        '[data-story-stage="experience"]',
      )!;
      const from = Number(previous.dataset.scrollReadEnd);
      const to = Number(current.dataset.scrollReadStart);
      scrollTo({ top: from + (to - from) * 0.2, behavior: 'instant' });
    });
    await page.clock.runFor(200);
    await expect(guide).toBeHidden();
    expect(await observed.evaluate(({ events }) => events)).toEqual([]);
    await settleLayoutClock(page, true);
    await reading(page);
    await page.clock.runFor(650);
    for (const kind of ['court', 'score'] as const)
      await expect(cue(page, kind)).toHaveAttribute('data-cue-state', 'steady');
    const first = await observed.evaluate(({ events }) => events);
    for (const kind of ['court', 'score'] as const) {
      const steps = first.filter((event) => event.kind === kind);
      expect(steps.map(({ state }) => state)).toEqual(['drawing', 'steady']);
      expect(steps[0].chapter).toBe('experience');
      expect(steps[0].scrollState).toBe('idle');
      const duration = steps[1].at - steps[0].at;
      // A 420ms draw may include the companion cue's short stagger and one RAF.
      expect(duration).toBeGreaterThanOrEqual(400);
      expect(duration).toBeLessThanOrEqual(560);
    }
    const articleScroll = await page.evaluate(() => scrollY);
    const reset = page.locator('[data-reset]');
    await reset.evaluate((el) =>
      (el as HTMLButtonElement).focus({ preventScroll: true }),
    );
    for (let round = 0; round < 2; round++) {
      await reset.dispatchEvent('click');
      await page.clock.runFor(100);
      await expect(cue(page, 'court')).toHaveAttribute(
        'data-cue-state',
        'drawing',
      );
      await page.clock.runFor(600);
      await expect(cue(page, 'score')).toHaveAttribute(
        'data-cue-state',
        'steady',
      );
    }
    await expect(reset).toBeFocused();
    expect(await page.evaluate(() => scrollY)).toBe(articleScroll);
    await expect(guide).toHaveAttribute('aria-hidden', 'true');
    await expect(guide).toHaveCSS('pointer-events', 'none');
    await expect(page.locator('[data-demo] [aria-pressed="true"]')).toHaveCount(
      0,
    );
    await expect(page.locator('[data-blue-score]')).toHaveText('6');
    await expect(page.locator('[data-record]')).toBeDisabled();
  } finally {
    await observed.evaluate(({ observer }) => observer.disconnect());
    await observed.dispose();
  }
});

test('experience guide resumes the selected step after leaving and returning', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 1440, height: 1000 });
  await open(page, '/#experience');
  await pause();
  await settleLayoutClock(page, true);
  const guide = page.locator(guideRoot);
  await page.locator('[data-demo-points="3"]').dispatchEvent('click');
  await page.clock.runFor(100);
  await expect(cue(page, 'court')).toBeVisible();
  const departure = await page.evaluate(() => {
    const from = scrollY;
    const replay = document.querySelector<HTMLElement>(
      '[data-story-stage="replay"]',
    )!;
    scrollTo({
      top: Number(replay.dataset.scrollReadStart),
      behavior: 'instant',
    });
    return from;
  });
  await page.clock.runFor(150);
  await expect(guide).toBeHidden();
  await page.evaluate(
    (from) => scrollTo({ top: from, behavior: 'instant' }),
    departure,
  );
  await settleLayoutClock(page, true);
  await page.clock.runFor(650);
  await expect(cue(page, 'court')).toBeVisible();
  await expect(cue(page, 'court').locator('.demo-guide-label')).toHaveText(
    (await page
      .locator('[data-demo-status]')
      .getAttribute('data-outside-arc'))!,
  );
  await expect(cue(page, 'score')).toBeHidden();
  await expect(cue(page, 'record')).toBeHidden();
  await expect(page.locator('[data-demo-points="3"]')).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
});

test('offscreen experience controls wait to display a static cue under reduced motion', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 320, height: 667 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await open(page, '/en/');
  await pause();
  await settleLayoutClock(page);
  const host = page.locator('[data-demo-court-host]');
  await host.evaluate((el) => {
    const r = el.getBoundingClientRect();
    scrollTo({
      top: scrollY + r.top - innerHeight + r.height * 0.4,
      behavior: 'instant',
    });
  });
  await page.clock.runFor(200);
  await expect(cue(page, 'court')).toBeHidden();
  await expect(cue(page, 'score')).toBeHidden();

  await scrollToTarget(page, '[data-demo-court-host]');
  await page.clock.runFor(240);
  const court = cue(page, 'court');
  await expect(court).toHaveAttribute('data-cue-state', 'steady');
  const arrow = court.locator('[data-demo-arrow]');
  const geometry = await arrow.getAttribute('d');
  const dashOffset = await arrow.evaluate(
    (el) => getComputedStyle(el).strokeDashoffset,
  );
  await page.clock.runFor(900);
  await expect(arrow).toHaveAttribute('d', geometry!);
  await expect(arrow).toHaveCSS('stroke-dashoffset', dashOffset);
  await expect(court.locator('[data-demo-arrow-head]')).toBeVisible();

  const points = page.locator('[data-demo-points="1"]');
  await points.evaluate((el) =>
    (el as HTMLButtonElement).focus({ preventScroll: true }),
  );
  await points.dispatchEvent('click');
  const record = page.locator('[data-record]');
  await expect(record).toBeEnabled();
  const y = await scrollToTarget(page, '[data-record]');
  await page.clock.runFor(300);
  const recordCue = cue(page, 'record');
  await expect(recordCue).toHaveAttribute('data-cue-state', 'steady');
  await expect(recordCue.locator('.demo-guide-label')).toContainText(
    'Confirm +1',
  );
  await expect(points).toBeFocused();
  expect(await page.evaluate(() => scrollY)).toBe(y);
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(page.locator('[data-demo-marker]')).toBeHidden();
  await expect(court).toBeHidden();
  await expect(cue(page, 'score')).toBeHidden();
  await record.dispatchEvent('click');
  await expect(page.locator(guideRoot)).toBeHidden();
  await expect(page.locator('[data-blue-score]')).toHaveText('7');
  await expect(page.locator('[data-demo-marker]')).toBeVisible();
});

test('the experience guide stays hidden until both gallery and page visibility are released', async ({
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
  await pause();
  await settleLayoutClock(page, true);
  const guide = page.locator(guideRoot);
  await expect(guide).toBeHidden();
  const y = await page.evaluate(() => scrollY);
  await setPageHidden(page, false);
  await page.clock.runFor(650);
  await expect(cue(page, 'court')).toBeVisible();
  await expect(cue(page, 'score')).toBeVisible();

  await page.locator('[data-demo-points="2"]').dispatchEvent('click');
  await page.locator('[data-point-preset="center"]').dispatchEvent('click');
  await page.clock.runFor(100);
  await expect(cue(page, 'record')).toBeVisible();
  await page.locator('#scoring .viewer-link').first().dispatchEvent('click');
  await expect(page.locator('[data-viewer]')).toBeVisible();
  await expect(guide).toBeHidden();
  await setPageHidden(page, true);
  await page.locator('[data-viewer-close]').dispatchEvent('click');
  // The native close event releases the viewer's suspension reason.
  await expect(page.locator('html')).not.toHaveClass(/image-viewer-open/);
  await page.clock.runFor(650);
  await expect(guide).toBeHidden();

  await setPageHidden(page, false);
  await page.clock.runFor(650);
  await expect(cue(page, 'record')).toBeVisible();
  await expect(cue(page, 'record').locator('.demo-guide-label')).toContainText(
    '+2',
  );
  await expect(cue(page, 'court')).toBeHidden();
  await expect(cue(page, 'score')).toBeHidden();
  await expect(page.locator('[data-record]')).toBeEnabled();
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(page.locator('[data-point-preset="center"]')).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  // Restoring native dialog focus can round the scroll position to a device pixel.
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - y),
  ).toBeLessThanOrEqual(1);
});
