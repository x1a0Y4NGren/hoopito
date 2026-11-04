import { expect, test, type Page } from '@playwright/test';
import { installContractClock } from './controlled-clock';

const sceneChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;

async function open(page: Page, path: string) {
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('[data-score-feature="0"]')).toBeEnabled();
  await expect(page.locator('[data-story-stage="scoring"]')).toHaveAttribute(
    'data-scroll-read-start',
    /\d/,
  );
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
    test(`${path}: scoring polish ${layout.name} preserves the product and one readable information group`, async ({
      page,
    }, info) => {
      await page.setViewportSize({
        width: layout.width,
        height: layout.height,
      });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await open(page, `${path}#scoring`);
      if (layout.largeText)
        await page.addStyleTag({ content: 'html {font-size:200%!important}' });
      const stage = page.locator('[data-story-stage="scoring"]');
      const image = stage.locator('.score-screen img');
      await image.evaluate(async (element) => {
        await (element as HTMLImageElement).decode();
      });
      const metrics = await stage.evaluate((element) => {
        const title = element.querySelector('h2')!;
        const lines = [
          ...title.querySelectorAll<HTMLElement>('[data-story-line]'),
        ];
        const image =
          element.querySelector<HTMLImageElement>('.score-screen img')!;
        const caption = element.querySelector('figcaption')!;
        const body = element.querySelector('.section-intro > p')!;
        const current = element.querySelector('[data-score-current]')!;
        const rect = (el: Element) => {
          const r = el.getBoundingClientRect();
          return { x: r.x, y: r.y, width: r.width, height: r.height };
        };
        return {
          overflow: document.documentElement.scrollWidth - innerWidth,
          natural: [image.naturalWidth, image.naturalHeight],
          image: rect(image),
          titleBackdrop: getComputedStyle(
            element.querySelector('.section-intro')!,
            '::before',
          ).content,
          bodyBackdrop: getComputedStyle(body, '::before').content,
          lines: lines.map((line) => ({
            ...rect(line),
            size: parseFloat(getComputedStyle(line).fontSize),
            lineHeight: parseFloat(getComputedStyle(line).lineHeight),
          })),
          captionZones:
            Number(caption.matches('.reading-zone')) +
            caption.querySelectorAll('.reading-zone').length,
          current: rect(current),
          currentClip: getComputedStyle(current).clipPath,
          source: caption.querySelector('.capture-source')!.textContent,
          captionTextSizes: [
            ...caption.querySelectorAll(
              '.capture-note, .viewer-link, [data-score-note]',
            ),
          ].map((el) => parseFloat(getComputedStyle(el).fontSize)),
          targets: [...element.querySelectorAll('[data-score-feature]')].map(
            rect,
          ),
        };
      });
      expect(metrics.overflow).toBeLessThanOrEqual(1);
      expect(metrics.natural).toEqual([1818, 954]);
      expect(metrics.image.width / metrics.image.height).toBeCloseTo(
        1818 / 954,
        2,
      );
      expect(metrics.titleBackdrop).toBe('none');
      expect(metrics.bodyBackdrop).toBe('""');
      expect(metrics.captionZones).toBe(1);
      expect(metrics.current.width).toBeLessThanOrEqual(1);
      expect(metrics.current.height).toBeLessThanOrEqual(1);
      expect(metrics.currentClip).toBe('inset(50%)');
      expect(metrics.source?.trim()).not.toBe('');
      for (const size of metrics.captionTextSizes)
        expect(size).toBeGreaterThanOrEqual(14);
      for (const target of metrics.targets) {
        expect(target.height).toBeGreaterThanOrEqual(48);
        expect(target.width).toBeGreaterThanOrEqual(48);
      }
      if (path === '/' && layout.width >= 1024 && !layout.largeText) {
        expect(metrics.lines[1].size).toBeGreaterThanOrEqual(32);
        expect(metrics.lines[1].size).toBeLessThanOrEqual(42);
        expect(metrics.lines[1].height).toBeLessThanOrEqual(
          metrics.lines[1].lineHeight + 1,
        );
        expect(metrics.lines[0].size).toBeGreaterThan(metrics.lines[1].size);
      }
      if (layout.width >= 1024 && !layout.largeText)
        expect(
          Math.abs(metrics.lines[0].y - metrics.image.y),
        ).toBeLessThanOrEqual(1);
      await expect(stage.locator('[data-glass-card]')).toHaveCount(1);
      await expect(
        stage.locator(
          '.score-preview-label, .score-preview-icon, [data-score-cursor], [data-score-invite-arrow], .score-region-trace, .score-operation-path, .score-operation-head',
        ),
      ).toHaveCount(0);
      await expect(
        stage.locator('figcaption [data-score-preview]'),
      ).toHaveCount(1);
      await expect(stage.locator('.score-current')).toHaveAttribute(
        'aria-live',
        'polite',
      );
      await expect(stage.locator('figcaption')).toContainText(
        path === '/' ? '正式包真实计分界面' : 'Actual release screen',
      );
      const hint = stage.locator('[data-score-note]');
      await expect(hint).not.toContainText(/下方|below/i);
      await info.attach('scoring-static-layout', {
        body: JSON.stringify(metrics, null, 2),
        contentType: 'application/json',
      });
    });
  }

  for (const width of [390, 1440]) {
    test(`${path}: scoring feedback reserves its longest text through selection and reflow at ${width}px`, async ({
      page,
    }, info) => {
      await page.setViewportSize({ width, height: 900 });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await open(page, `${path}#scoring`);
      const note = page.locator('[data-score-note]');
      const preview = page.locator('[data-score-preview]');
      await expect(preview.locator('[aria-hidden="true"]')).toHaveCount(4);
      const check = async () => {
        const initial = (await preview.boundingBox())!;
        const heights = [];
        for (const index of [0, 1, 2, 0]) {
          const feature = page.locator(`[data-score-feature="${index}"]`);
          await feature.click();
          await expect(note).toHaveText(
            (await feature.getAttribute('data-score-feedback'))!,
          );
          const current = (await preview.boundingBox())!;
          expect(current.height).toBeCloseTo(initial.height, 1);
          const bounds = await note.evaluate((element) => ({
            client: element.clientHeight,
            content: element.scrollHeight,
          }));
          expect(bounds.content).toBeLessThanOrEqual(bounds.client + 1);
          heights.push(current.height);
          const activeColor = await feature
            .locator('.feature-index')
            .evaluate((element) => getComputedStyle(element).color);
          const inactiveColor = await page
            .locator(`[data-score-feature="${(index + 1) % 3}"] .feature-index`)
            .evaluate((element) => getComputedStyle(element).color);
          const accentColor = await feature.evaluate(
            (element) => getComputedStyle(element, '::after').backgroundColor,
          );
          expect(activeColor).toBe(accentColor);
          expect(inactiveColor).not.toBe(activeColor);
        }
        return heights;
      };
      const original = await check();
      await page.setViewportSize({
        width: width === 390 ? 430 : 1024,
        height: 900,
      });
      await page.addStyleTag({ content: 'html {font-size:200%!important}' });
      await page.evaluate(() => document.fonts.ready);
      const resized = await check();
      await info.attach('scoring-note-reserved-heights', {
        body: JSON.stringify({ original, resized }),
        contentType: 'application/json',
      });
      const opener = page.locator('.scoring-display .viewer-link');
      await opener.focus();
      await page.keyboard.press('Enter');
      await expect(page.locator('[data-viewer]')).toBeVisible();
      await page.keyboard.press('Escape');
      await expect(opener).toBeFocused();
    });
  }
}

test('scoring departure cancels a cue while keeping its static selection and original screenshot', async ({
  page,
}) => {
  const pause = await installContractClock(page);
  await page.setViewportSize({ width: 1440, height: 900 });
  await open(page, '/#scoring');
  await pause();
  await page.clock.runFor(2000);
  const feature = page.locator('[data-score-feature="0"]');
  const device = page.locator('[data-story-device]');
  const source = await device.locator('img').getAttribute('src');
  await feature.dispatchEvent('click');
  await page.clock.runFor(400);
  await expect(device).toHaveAttribute('data-score-playing', 'true');
  await page
    .locator('.site-header nav > a[href="#experience"]')
    .dispatchEvent('click');
  await page.clock.runFor(80);
  await expect(device).toHaveAttribute('data-score-playing', 'false');
  await expect(feature).toHaveAttribute('aria-pressed', 'true');
  await expect(device.locator('img')).toHaveAttribute('src', source!);
  for (const ring of await page.locator('[data-score-pulse]').all()) {
    await expect(ring).toHaveCSS('opacity', '0');
    await expect(ring).toHaveAttribute('r', '18');
  }
  await page.clock.runFor(1600);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'experience',
  );
});

test('scoring invitation starts once after background release without requiring new scroll input', async ({
  page,
}, info) => {
  const pause = await installContractClock(page);
  await page.addInitScript(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
  });
  await page.setViewportSize({ width: 1440, height: 900 });
  await open(page, '/#scoring');
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'scoring',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  const first = page.locator('[data-score-feature="0"]');
  await pause();
  await page.clock.runFor(1200);
  await expect(first).toHaveAttribute('data-score-invitation', 'idle');
  const observed = await first.evaluateHandle((element) => {
    const starts: number[] = [],
      ends: number[] = [];
    const transitions: {
      at: number;
      state: string | undefined;
      scroll: number;
      start: string | undefined;
      progress: string | undefined;
    }[] = [];
    let previous = (element as HTMLElement).dataset.scoreInvitation;
    const observer = new MutationObserver(() => {
      const state = (element as HTMLElement).dataset.scoreInvitation;
      if (state === previous) return;
      previous = state;
      const stage = element.closest<HTMLElement>('[data-story-stage]')!;
      transitions.push({
        at: Date.now(),
        state,
        scroll: scrollY,
        start: stage.dataset.scrollReadStart,
        progress: stage.dataset.storyProgress,
      });
      if (state === 'playing') starts.push(Date.now());
      if (state === 'done') ends.push(Date.now());
    });
    observer.observe(element, {
      attributes: true,
      attributeFilter: ['data-score-invitation'],
    });
    return {
      read: () => ({ starts: [...starts], ends: [...ends], transitions }),
      stop: () => observer.disconnect(),
    };
  });
  try {
    const readingPosition = () =>
      page.evaluate(() => ({
        scroll: scrollY,
        start: Number(
          document.querySelector<HTMLElement>('[data-story-stage="scoring"]')!
            .dataset.scrollReadStart,
        ),
        stop: document.documentElement.dataset.scrollStop,
        state: document.documentElement.dataset.scrollState,
      }));
    const before = await readingPosition();
    await page.evaluate(() => {
      Object.defineProperty(document, 'hidden', {
        configurable: true,
        value: false,
      });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await page.clock.runFor(80);
    await expect(first).toHaveAttribute('data-score-invitation', 'playing');
    await page.clock.runFor(900);
    await expect(first).toHaveAttribute('data-score-invitation', 'done');
    const after = await readingPosition();
    // A font/pin refresh may relocate the document's reading stop while the
    // background is paused. The invitation must preserve its reading offset.
    expect(after.scroll - after.start).toBe(before.scroll - before.start);
    expect(after.stop).toBe('scoring');
    expect(after.state).toBe('idle');
    const run = await observed.evaluate((value) => value.read());
    await info.attach('scoring-background-release-transitions', {
      body: JSON.stringify({ ...run, before, after }, null, 2),
      contentType: 'application/json',
    });
    expect(run.starts).toHaveLength(1);
    expect(run.ends).toHaveLength(1);
    expect(run.ends[0] - run.starts[0]).toBeGreaterThanOrEqual(800);
    expect(run.ends[0] - run.starts[0]).toBeLessThanOrEqual(840);
    await page.evaluate(() => scrollTo({ top: 0, behavior: 'instant' }));
    await page.clock.runFor(80);
    await page.evaluate(() =>
      scrollTo({
        top: Number(
          document.querySelector<HTMLElement>('[data-story-stage="scoring"]')!
            .dataset.scrollReadStart,
        ),
        behavior: 'instant',
      }),
    );
    await page.clock.runFor(1200);
    await expect(first).toHaveAttribute('data-score-invitation', 'done');
    const repeated = await observed.evaluate((value) => value.read());
    expect(repeated.starts).toHaveLength(1);
    await info.attach('scoring-background-release-invitation', {
      body: JSON.stringify({ ...repeated, before, after }),
      contentType: 'application/json',
    });
  } finally {
    await observed.evaluate((value) => value.stop());
    await observed.dispose();
  }
});
