import { expect, test, type Page } from '@playwright/test';
import {
  getReplayMomentPresentation,
  getReplayState,
  type ReplayKeyMomentId,
} from '../src/data/replay-example';

const sceneChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;
const stageSelector = '[data-story-stage="replay"]';

async function open(page: Page, path = '/#replay') {
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path);
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all(
      [...document.querySelectorAll<HTMLImageElement>('#replay img')].map(
        (image) => {
          image.loading = 'eager';
          return image.decode();
        },
      ),
    );
  });
  await expect(page.locator(stageSelector)).toHaveAttribute(
    'data-scroll-read-start',
    /\d/,
  );
  await stableLayout(page);
}

async function stableLayout(page: Page) {
  let previous = '';
  let stableSince = 0;
  await expect
    .poll(async () => {
      const key = await page.evaluate(() =>
        JSON.stringify({
          fonts: document.fonts.status,
          height: document.documentElement.scrollHeight,
          stages: [
            ...document.querySelectorAll<HTMLElement>(
              '[data-story-stage], #closing',
            ),
          ].map((stage) => [
            stage.dataset.scrollReadStart,
            stage.dataset.scrollReadEnd,
            stage.offsetWidth,
            stage.offsetHeight,
          ]),
        }),
      );
      if (key !== previous) stableSince = Date.now();
      previous = key;
      return Date.now() - stableSince;
    })
    .toBeGreaterThanOrEqual(250);
}

async function range(page: Page, id = 'replay') {
  return page.locator(`[data-story-stage="${id}"]`).evaluate((stage) => ({
    start: Number((stage as HTMLElement).dataset.scrollReadStart),
    end: Number((stage as HTMLElement).dataset.scrollReadEnd),
  }));
}

async function atReading(page: Page, id = 'replay') {
  await expect(page.locator('html')).toHaveAttribute('data-scroll-stop', id);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  const bounds = await range(page, id);
  expect(await page.evaluate(() => scrollY)).toBeGreaterThanOrEqual(
    bounds.start - 2,
  );
  expect(await page.evaluate(() => scrollY)).toBeLessThanOrEqual(
    bounds.end + 2,
  );
}

async function seekReading(page: Page, edge: 'start' | 'end' = 'start') {
  await page.mouse.click(8, 450);
  await stableLayout(page);
  const bounds = await range(page);
  await page.evaluate(async (top) => {
    scrollTo({ top, behavior: 'instant' });
    await new Promise(requestAnimationFrame);
    await new Promise(requestAnimationFrame);
  }, bounds[edge]);
  await atReading(page);
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
    test(`${path}: replay polish ${layout.name} keeps the example legible and real screenshots unframed`, async ({
      page,
    }, info) => {
      await page.setViewportSize(layout);
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await open(page, `${path}#replay`);
      if (layout.largeText) {
        await page.addStyleTag({ content: 'html{font-size:200%!important}' });
        await stableLayout(page);
      }
      const stage = page.locator(stageSelector);
      const metrics = await stage.evaluate((element) => {
        const rect = (el: Element) => {
          const box = el.getBoundingClientRect();
          return {
            x: box.x,
            y: box.y,
            width: box.width,
            height: box.height,
            bottom: box.bottom,
            right: box.right,
          };
        };
        const heading = element.querySelector('.replay-introduction')!;
        const notes = element.querySelector('.replay-analysis-notes')!;
        const svg = element.querySelector('.replay-plot svg')!;
        const svgBox = svg.getBoundingClientRect();
        return {
          overflow: document.documentElement.scrollWidth - innerWidth,
          titleBackdrop: getComputedStyle(heading, '::before').content,
          bodyBackdrop: getComputedStyle(
            heading.querySelector('.section-body')!,
            '::before',
          ).content,
          body: rect(heading.querySelector('.section-body')!),
          analysis: rect(element.querySelector('.replay-analysis')!),
          secondTitle: parseFloat(
            getComputedStyle(heading.querySelectorAll('[data-story-line]')[1])
              .fontSize,
          ),
          scoreSize: parseFloat(
            getComputedStyle(element.querySelector('.replay-live-score')!)
              .fontSize,
          ),
          notes: rect(notes),
          noteZones:
            Number(notes.matches('.reading-zone')) +
            notes.querySelectorAll('.reading-zone').length,
          labels: [
            ...element.querySelectorAll<HTMLElement>('.replay-axis > span'),
          ].map((label) => ({
            text: label.textContent?.trim(),
            size: parseFloat(getComputedStyle(label).fontSize),
            xScale: new DOMMatrix(getComputedStyle(label).transform).m11,
            ...rect(label),
          })),
          gridY: [28, 74, 120, 166].map(
            (y) => svgBox.y + (y / 204) * svgBox.height,
          ),
          text: [
            ...notes.querySelectorAll('p, dt, dd'),
            ...element.querySelectorAll('.replay-moments strong'),
          ].map((item) => ({
            text: item.textContent?.trim(),
            size: parseFloat(getComputedStyle(item).fontSize),
            clipped: item.scrollHeight > item.clientHeight + 1,
            ...rect(item),
          })),
          devices: [
            ...element.querySelectorAll<HTMLElement>('[data-replay-device]'),
          ].map((device) => {
            const image = device.querySelector<HTMLImageElement>('img')!;
            const caption = device.querySelector('figcaption')!;
            const captionStyle = getComputedStyle(caption);
            const viewer = device.querySelector('.viewer-link')!;
            return {
              id: device.dataset.replayDevice,
              optical: device.hasAttribute('data-glass-card'),
              image: rect(image),
              natural: [image.naturalWidth, image.naturalHeight],
              caption: rect(caption),
              captionPadding: [
                captionStyle.paddingInlineStart,
                captionStyle.paddingInlineEnd,
              ],
              sizes: [...caption.querySelectorAll('strong, small')].map((el) =>
                parseFloat(getComputedStyle(el).fontSize),
              ),
              viewer: rect(viewer),
            };
          }),
        };
      });
      expect(metrics.overflow).toBeLessThanOrEqual(1);
      expect(metrics.titleBackdrop).toBe('none');
      expect(metrics.bodyBackdrop).toBe('""');
      expect(metrics.body.bottom).toBeLessThanOrEqual(metrics.analysis.y + 1);
      expect(metrics.noteZones).toBe(1);
      for (const text of metrics.text) {
        expect(text.size).toBeGreaterThanOrEqual(14);
        expect(text.clipped, text.text).toBe(false);
      }
      expect(metrics.labels).toHaveLength(6);
      expect(metrics.labels.slice(0, 4).map((label) => label.text)).toEqual([
        '12',
        '8',
        '4',
        '0',
      ]);
      for (const label of metrics.labels) {
        expect(label.size).toBeGreaterThanOrEqual(14);
        expect(label.xScale).toBe(1);
      }
      for (let index = 0; index < 4; index++)
        expect(
          metrics.labels[index].y + metrics.labels[index].height / 2,
        ).toBeCloseTo(metrics.gridY[index], 0);
      if (!layout.largeText) {
        expect(metrics.secondTitle).toBeGreaterThanOrEqual(32);
        expect(metrics.secondTitle).toBeLessThanOrEqual(
          layout.width < 1024 ? 44 : 42,
        );
        expect(metrics.scoreSize).toBeGreaterThanOrEqual(40);
        expect(metrics.scoreSize).toBeLessThanOrEqual(44);
      }
      for (const device of metrics.devices) {
        expect(device.optical).toBe(false);
        expect(device.natural).toEqual([1080, 1783]);
        expect(device.image.width / device.image.height).toBeCloseTo(
          1080 / 1783,
          3,
        );
        expect(device.captionPadding).toEqual(['0px', '0px']);
        expect(device.caption.y).toBeGreaterThanOrEqual(
          device.image.bottom - 1,
        );
        expect(device.viewer.width).toBeGreaterThanOrEqual(48);
        expect(device.viewer.height).toBeGreaterThanOrEqual(48);
        for (const size of device.sizes)
          expect(size).toBeGreaterThanOrEqual(14);
      }
      if (layout.width >= 1024) {
        expect(metrics.devices[0].image.width).toBeLessThanOrEqual(340);
        expect(metrics.devices[1].image.width).toBeLessThanOrEqual(190);
      }
      await expect(stage.locator('[data-glass-card]')).toHaveCount(1);
      await expect(stage.locator('.replay-axis')).toHaveAttribute(
        'aria-hidden',
        'true',
      );
      await expect(stage.locator('.replay-graph svg')).toHaveAttribute(
        'aria-label',
        /\S/,
      );
      await expect(stage.locator('.replay-graph-source')).toContainText(
        path === '/' ? '虚构' : /fictional/i,
      );
      await expect(stage.locator('.replay-findings dt .display')).toHaveCount(
        0,
      );
      await info.attach('replay-polish-layout', {
        body: JSON.stringify(metrics, null, 2),
        contentType: 'application/json',
      });
    });
  }

  test(`${path}: direct replay anchor shows the final independent example and both real viewers restore keyboard focus`, async ({
    page,
  }) => {
    await open(page, `${path}#replay`);
    await atReading(page);
    const stage = page.locator(stageSelector);
    await expect(stage).toHaveAttribute('data-replay-progress', '1.0000');
    await expect(stage.locator('[data-replay-blue]')).toHaveText('8');
    await expect(stage.locator('[data-replay-red]')).toHaveText('11');
    for (const moment of await stage.locator('[data-replay-moment]').all()) {
      await expect(moment).toHaveAttribute('data-reached', 'true');
      await expect(moment).toHaveAttribute('data-current', 'false');
      const values = await moment.evaluate((el) => ({
        reveal: Number(
          (el as HTMLElement).style.getPropertyValue('--moment-reveal'),
        ),
        emphasis: Number(
          (el as HTMLElement).style.getPropertyValue('--moment-emphasis'),
        ),
      }));
      expect(values).toEqual({ reveal: 1, emphasis: 0 });
    }
    for (const id of ['summary', 'history']) {
      const opener = stage.locator(`[data-replay-device="${id}"] .viewer-link`);
      const href = await opener.getAttribute('href');
      await opener.focus();
      await page.keyboard.press('Enter');
      await expect(page.locator('[data-viewer]')).toBeVisible();
      await expect(page.locator('[data-viewer-image]')).toHaveAttribute(
        'src',
        new URL(href!, page.url()).href,
      );
      await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
        'naturalWidth',
        1080,
      );
      await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
        'naturalHeight',
        1783,
      );
      await page.keyboard.press('Escape');
      await expect(opener).toBeFocused();
      await expect(stage.locator('[data-replay-blue]')).toHaveText('8');
      await expect(stage.locator('[data-replay-red]')).toHaveText('11');
    }
  });
}

test('replay moment presentation follows the scroll playhead smoothly through every event and exactly in reverse', async ({
  page,
}, info) => {
  test.setTimeout(60_000);
  await page.setViewportSize({ width: 1920, height: 1440 });
  await open(page, '/#experience');
  await page.mouse.click(8, 450);
  const before = await range(page, 'experience');
  const replay = await range(page);
  const snapshots: unknown[] = [];
  const observe = async (target: number) => {
    const snapshot = await page.locator(stageSelector).evaluate((stage) => ({
      y: scrollY,
      progress: Number((stage as HTMLElement).dataset.replayProgress),
      scores: [
        Number(stage.querySelector('[data-replay-blue]')!.textContent),
        Number(stage.querySelector('[data-replay-red]')!.textContent),
      ],
      moments: [
        ...stage.querySelectorAll<HTMLElement>('[data-replay-moment]'),
      ].map((el) => ({
        id: el.dataset.replayMoment as Exclude<ReplayKeyMomentId, 'final'>,
        reveal: Number(el.style.getPropertyValue('--moment-reveal')),
        emphasis: Number(el.style.getPropertyValue('--moment-emphasis')),
        contentOpacity: Number(
          getComputedStyle(el.querySelector('strong')!).opacity,
        ),
        ruleOpacity: Number(getComputedStyle(el, '::before').opacity),
        reached: el.dataset.reached,
        current: el.dataset.current,
      })),
    }));
    expect(Math.abs(snapshot.progress - target)).toBeLessThan(0.002);
    const state = getReplayState(snapshot.progress);
    expect(snapshot.scores).toEqual([state.leftScore, state.rightScore]);
    for (const moment of snapshot.moments) {
      const presentation = getReplayMomentPresentation(
        snapshot.progress,
        moment.id,
      );
      expect(moment.reveal).toBeCloseTo(presentation.reveal, 2);
      expect(moment.emphasis).toBeCloseTo(presentation.emphasis, 2);
      expect(moment.contentOpacity).toBeCloseTo(0.4 + 0.6 * moment.reveal, 3);
      expect(moment.ruleOpacity).toBeCloseTo(moment.emphasis, 3);
      expect(moment.current).toBe(String(state.stage === moment.id));
      expect(moment.reached).toBe(
        String(
          snapshot.progress >=
            { lead: 0.4, tie: 0.6, turnaround: 0.9 }[moment.id],
        ),
      );
    }
    snapshots.push(snapshot);
    return snapshot;
  };
  const seek = async (target: number) => {
    let low = before.end;
    let high = replay.start;
    for (let attempt = 0; attempt < 15; attempt++) {
      const top = (low + high) / 2;
      const current = await page.evaluate(async (top) => {
        scrollTo({ top, behavior: 'instant' });
        await new Promise(requestAnimationFrame);
        await new Promise(requestAnimationFrame);
        return Number(
          document.querySelector<HTMLElement>('[data-story-stage="replay"]')!
            .dataset.replayProgress,
        );
      }, top);
      if (current < target) low = top;
      else high = top;
    }
    return observe(target);
  };
  const targets = [0.399, 0.43, 0.599, 0.63, 0.899, 0.93, 0.97];
  const forward = [];
  for (const target of targets) forward.push(await seek(target));
  const reverse = [];
  // Return to the exact measured coordinates, so reversal verifies the same
  // scroll input rather than spending another binary search finding it again.
  for (let index = targets.length - 1; index >= 0; index--) {
    await page.evaluate(async (top) => {
      scrollTo({ top, behavior: 'instant' });
      await new Promise(requestAnimationFrame);
      await new Promise(requestAnimationFrame);
    }, forward[index].y);
    reverse.unshift(await observe(targets[index]));
  }
  expect(reverse).toEqual(forward);
  await info.attach('replay-moment-scroll-boundaries', {
    body: JSON.stringify(snapshots, null, 2),
    contentType: 'application/json',
  });
});

for (const path of ['/', '/en/']) {
  for (const layout of [
    { name: 'wide desktop', width: 1920, height: 1200 },
    { name: 'small mobile', width: 320, height: 740 },
    { name: 'mobile', width: 390, height: 844 },
    { name: '200 percent text', width: 1024, height: 640, largeText: true },
  ]) {
    test(`${path}: replay scores stay on one line at ${layout.name}`, async ({
      page,
    }) => {
      await page.setViewportSize(layout);
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await open(page, `${path}#replay`);
      if (layout.largeText) {
        await page.addStyleTag({ content: 'html{font-size:200%!important}' });
        await stableLayout(page);
      }
      const samples = await page
        .locator('[data-replay-red]')
        .evaluate((red) => {
          const original = red.textContent;
          const score = red.closest<HTMLElement>('.replay-live-score')!;
          const samples = ['0', '6', '8', '9', '11'].map((value) => {
            red.textContent = value;
            const text = document.createRange();
            text.selectNodeContents(red);
            const rows = new Set(
              [...text.getClientRects()].map((rect) => rect.top),
            );
            return {
              value,
              rows: rows.size,
              height: red.getBoundingClientRect().height,
              lineHeight: parseFloat(getComputedStyle(red).lineHeight),
              scoreWidth: score.getBoundingClientRect().width,
              containerWidth:
                score.parentElement!.getBoundingClientRect().width,
            };
          });
          red.textContent = original;
          return samples;
        });
      for (const sample of samples) {
        expect(sample.rows, `score ${sample.value}`).toBe(1);
        expect(sample.height).toBeLessThanOrEqual(sample.lineHeight + 1);
        expect(sample.scoreWidth).toBeLessThanOrEqual(sample.containerWidth);
      }
      expect(
        await page.evaluate(() => document.documentElement.scrollWidth),
      ).toBeLessThanOrEqual(layout.width);
    });
  }
}

test('native replay wheels return a 23px preview and complete adjacent chapters in both directions with a fixed pointer', async ({
  page,
}, info) => {
  test.setTimeout(60_000);
  await page.setViewportSize({ width: 1920, height: 1200 });
  await open(page);
  await seekReading(page);
  const graph = (await page.locator('.replay-analysis').boundingBox())!;
  const pointer = { x: graph.x + graph.width / 2, y: graph.y + 30 };
  await page.mouse.move(pointer.x, pointer.y);
  const top = await page.evaluate(() => scrollY);
  await page.mouse.wheel(0, -23);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'tracking',
  );
  await atReading(page);
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - top),
  ).toBeLessThanOrEqual(2);
  const stops = [];
  for (const [delta, id] of [
    [-24, 'experience'],
    [-24, 'scoring'],
    [24, 'experience'],
    [24, 'replay'],
    [24, 'download'],
    [-24, 'replay'],
  ] as const) {
    await page.mouse.wheel(0, delta);
    await atReading(page, id);
    stops.push({ delta, id, y: await page.evaluate(() => scrollY) });
  }
  await expect(page.locator(stageSelector)).toHaveAttribute(
    'data-replay-progress',
    '1.0000',
  );
  await info.attach('replay-native-fixed-pointer-stops', {
    body: JSON.stringify({ pointer, top, stops }, null, 2),
    contentType: 'application/json',
  });
});
