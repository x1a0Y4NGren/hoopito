import { expect, test, type Page } from '@playwright/test';
import sharp from 'sharp';

const rail = 'aside[data-chapter-rail]';
const liquidSurface = '[data-rail-liquid-surface]';

async function ready(page: Page, path = '/') {
  await page.route(/court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/, (route) =>
    route.abort(),
  );
  await page.goto(path);
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter-rail',
    'ready',
  );
  let previous = '',
    stable = Date.now();
  await expect
    .poll(async () => {
      const current = await page.evaluate(() =>
        JSON.stringify([
          document.documentElement.scrollHeight,
          ...[
            ...document.querySelectorAll<HTMLElement>(
              '[data-story-stage], #closing',
            ),
          ].map((el) => [el.dataset.scrollReadStart, el.dataset.scrollReadEnd]),
        ]),
      );
      if (current !== previous) stable = Date.now();
      previous = current;
      return Date.now() - stable;
    })
    .toBeGreaterThanOrEqual(250);
}

/** A native document seek inspects the same public scroll position the rail reads. */
async function seekOffset(page: Page, offset: number) {
  await page.keyboard.press('Shift');
  const scroll = await page.evaluate((offset) => {
    const nodes = [...document.querySelectorAll('[data-rail-node]')].map(
      (el) => el.getBoundingClientRect().top,
    );
    const target = document.querySelector<HTMLElement>(
      '[data-story-stage="scoring"]',
    )!;
    return (
      (offset / (nodes[1] - nodes[0])) * Number(target.dataset.scrollReadStart)
    );
  }, offset);
  await page.evaluate(async (y) => {
    scrollTo({ top: y, behavior: 'instant' });
    await new Promise(requestAnimationFrame);
    await new Promise(requestAnimationFrame);
  }, scroll);
  return pose(page);
}

async function pose(page: Page) {
  return page.locator(rail).evaluate((el) => {
    const svg = el.querySelector<SVGSVGElement>('[data-rail-liquid-surface]')!;
    const nodes = [...el.querySelectorAll('[data-rail-node]')].map(
      (node) => node.getBoundingClientRect().top + 24,
    );
    const thumb = el
      .querySelector('[data-rail-thumb]')!
      .getBoundingClientRect();
    const circle = (node: Element) => ({
      cx: Number(node.getAttribute('cx') ?? 0),
      cy: Number(node.getAttribute('cy') ?? 0),
      r: Number(node.getAttribute('r') ?? 0),
    });
    return {
      y: scrollY,
      mode: (el as HTMLElement).dataset.liquidMode,
      active: (el as HTMLElement).dataset.liquidActive,
      phase: (el as HTMLElement).dataset.phase,
      rotation: getComputedStyle(el.querySelector('[data-rail-logo]')!)
        .transform,
      circles: [...svg.querySelectorAll('[data-rail-liquid] circle')].map(
        circle,
      ),
      thumb: {
        x: thumb.x,
        y: thumb.y,
        width: thumb.width,
        height: thumb.height,
      },
      position: thumb.top + 24 - nodes[0],
      svg: {
        viewBox: svg.getAttribute('viewBox'),
        height: svg.getBoundingClientRect().height,
      },
      logoFilter: getComputedStyle(el.querySelector('[data-rail-logo]')!)
        .filter,
    };
  });
}

test('the genuine local SVG alpha field is isolated from the clear brand and navigation', async ({
  page,
}, info) => {
  await ready(page);
  await expect(page.locator(rail)).toHaveAttribute('data-liquid-mode', 'svg');
  const topology = await page.locator(rail).evaluate((el) => {
    const svg = el.querySelector<SVGSVGElement>('[data-rail-liquid-surface]')!;
    const group = el.querySelector('[data-rail-liquid]')!;
    const clear = [
      ...el.querySelectorAll(
        '[data-rail-logo], [data-rail-node], .chapter-rail-line, [data-rail-fill], .chapter-rail-tooltip',
      ),
    ];
    return {
      group: group.tagName,
      filter: group.getAttribute('filter'),
      blur: Number(
        svg.querySelector('feGaussianBlur')?.getAttribute('stdDeviation'),
      ),
      alpha: svg.querySelector('feColorMatrix')?.getAttribute('values'),
      groupCircles: group.querySelectorAll('circle').length,
      legacyPaths: group.querySelectorAll('path').length,
      clear: clear.map((node) => ({
        tag: node.tagName,
        inField: group.contains(node),
        filter: getComputedStyle(node).filter,
      })),
      viewBox: svg.viewBox.baseVal
        ? {
            x: svg.viewBox.baseVal.x,
            y: svg.viewBox.baseVal.y,
            width: svg.viewBox.baseVal.width,
            height: svg.viewBox.baseVal.height,
          }
        : null,
    };
  });
  await info.attach('actual-svg-field-topology', {
    body: JSON.stringify(topology, null, 2),
    contentType: 'application/json',
  });
  expect(topology.group.toLowerCase()).toBe('g');
  expect(topology.filter).toContain('chapter-rail-goo');
  expect(topology.blur).toBe(3);
  expect(topology.alpha).toBeTruthy();
  expect(topology.groupCircles).toBeLessThanOrEqual(3);
  expect(topology.groupCircles).toBeGreaterThanOrEqual(2);
  expect(topology.legacyPaths).toBe(0);
  expect(topology.viewBox).toEqual({ x: -28, y: -80, width: 56, height: 160 });
  for (const node of topology.clear) {
    expect(node.inField).toBe(false);
    expect(node.filter).toBe('none');
  }
  const state = await seekOffset(page, 25);
  expect(state.rotation).toBe('none');
  expect(state.logoFilter).toBe('none');
  expect(state.circles.filter((c) => c.r > 0).length).toBeGreaterThan(1);
});

test('the same actual position restores identical liquid bodies through reverse motion and midpoint crossing', async ({
  page,
}, info) => {
  await ready(page);
  const offsets = [0, 6, 12, 20, 25, 30, 36, 42, 47, 52, 60];
  const forward = [];
  for (const distance of offsets)
    forward.push(await seekOffset(page, distance));
  const reverse = [];
  for (const distance of offsets.toReversed())
    reverse.push(await seekOffset(page, distance));
  reverse.reverse();
  for (let i = 0; i < forward.length; i++) {
    expect(reverse[i].y).toBe(forward[i].y);
    expect(reverse[i].circles).toEqual(forward[i].circles);
    expect(reverse[i].rotation).toBe('none');
    expect(forward[i].circles.length).toBeLessThanOrEqual(3);
    for (const circle of forward[i].circles) {
      expect(Number.isFinite(circle.cy)).toBe(true);
      expect(circle.r).toBeLessThanOrEqual(18);
    }
  }
  await info.attach('forward-reverse-actual-scroll-poses', {
    body: JSON.stringify({ offsets, forward, reverse }, null, 2),
    contentType: 'application/json',
  });
});

/** The actual orange field is painted over black. R>=128 is the same50%
 * coverage threshold as alpha>=128 for this R=255 source, without relying on
 * Firefox's unimplemented transparent element-screenshot path. */
async function alphaIslands(buffer: Buffer) {
  const { data, info } = await sharp(buffer)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const visited = new Uint8Array(info.width * info.height);
  const sizes = [];
  const opaque = (index: number) => data[index * 4] >= 128;
  for (let start = 0; start < visited.length; start++) {
    if (visited[start] || !opaque(start)) continue;
    const queue = [start];
    visited[start] = 1;
    let size = 0;
    for (let i = 0; i < queue.length; i++) {
      const index = queue[i];
      size++;
      const x = index % info.width,
        y = Math.floor(index / info.width);
      for (const next of [
        x > 0 ? index - 1 : -1,
        x < info.width - 1 ? index + 1 : -1,
        y > 0 ? index - info.width : -1,
        y < info.height - 1 ? index + info.width : -1,
      ])
        if (next >= 0 && !visited[next] && opaque(next)) {
          visited[next] = 1;
          queue.push(next);
        }
    }
    if (size >= 8) sizes.push(size);
  }
  return {
    sizes: sizes.sort((a, b) => b - a),
    width: info.width,
    height: info.height,
  };
}

test('real browser filtering produces one joined mass then two separate alpha islands', async ({
  page,
  context,
}, info) => {
  await ready(page);
  const rendered = await context.newPage();
  const evidence = [];
  try {
    // At26px the unfiltered18px+7px circles are physically separate. A single
    // opaque island therefore establishes an actual filtered connecting neck.
    for (const distance of [26, 36]) {
      const actual = await seekOffset(page, distance);
      const markup = await page.locator(liquidSurface).evaluate((source) => {
        const svg = source.cloneNode(true) as SVGSVGElement;
        svg.setAttribute('xmlns', 'http://www.w3.org/2000/svg');
        svg.setAttribute('width', '56');
        svg.setAttribute('height', '160');
        svg.style.cssText =
          'display:block;position:static;transform:none;opacity:1;visibility:visible;overflow:visible;width:56px;height:160px';
        const original = [source, ...source.querySelectorAll('*')];
        const cloned = [svg, ...svg.querySelectorAll('*')];
        for (let i = 0; i < original.length; i++) {
          const copy = cloned[i] as SVGElement;
          const computed = getComputedStyle(original[i]);
          if (i > 0) {
            copy.style.opacity = computed.opacity;
            copy.style.visibility = computed.visibility;
            copy.style.display = computed.display;
          }
          if (original[i].tagName.toLowerCase() === 'circle')
            copy.style.fill = computed.fill;
        }
        const group = svg.querySelector<SVGGElement>('[data-rail-liquid]')!;
        group.style.opacity = '1';
        group.style.visibility = 'visible';
        group.style.filter = 'url(#chapter-rail-goo)';
        return new XMLSerializer().serializeToString(svg);
      });
      await rendered.setContent(
        `<!doctype html><html style="background:#000"><body style="margin:0;background:#000">${markup}</body></html>`,
      );
      const image = await rendered.screenshot({
        clip: { x: 0, y: 0, width: 56, height: 160 },
        scale: 'css',
      });
      const islands = await alphaIslands(image);
      evidence.push({ distance, actual, islands });
      await info.attach(`actual-svg-${distance}px`, {
        body: image,
        contentType: 'image/png',
      });
      await info.attach(`actual-svg-pose-${distance}px`, {
        body: JSON.stringify({ distance, actual, islands }, null, 2),
        contentType: 'application/json',
      });
      expect(islands.width).toBe(56);
      expect(islands.height).toBe(160);
      expect(islands.sizes.length).toBe(distance === 26 ? 1 : 2);
      if (distance === 26) {
        await rendered.locator('[data-rail-liquid]').evaluate((group) => {
          group.setAttribute('filter', 'none');
          (group as SVGGElement).style.filter = 'none';
        });
        const unfiltered = await rendered.screenshot({
          clip: { x: 0, y: 0, width: 56, height: 160 },
          scale: 'css',
        });
        const control = await alphaIslands(unfiltered);
        await info.attach('same-circles-without-filter', {
          body: unfiltered,
          contentType: 'image/png',
        });
        expect(control.sizes.length).toBe(2);
      }
    }
  } finally {
    await rendered.close();
  }
  await info.attach('actual-browser-pinch-off', {
    body: JSON.stringify(
      {
        method:
          'Exact SVG/filter/circle snapshot from real document scroll, isolated over black in this browser. The source is orange with red255, so red>=128 measures50% coverage. CSS-pixel screenshots avoid differing engine DPR; no generated UI or mocked renderer.',
        evidence,
      },
      null,
      2,
    ),
    contentType: 'application/json',
  });
});

test('a slow captured drag follows the pointer while contacts grow split and recover without selecting a chapter', async ({
  page,
}, info) => {
  await ready(page);
  const box = await page.locator('[data-rail-thumb]').boundingBox();
  const start = { x: box!.x + 24, y: box!.y + 24 };
  await page.mouse.move(start.x, start.y);
  await page.mouse.down();
  const states = [];
  for (const distance of [6, 12, 20, 25, 30, 36, 42, 48, 60]) {
    await page.mouse.move(start.x, start.y + distance, { steps: 3 });
    const current = await pose(page);
    states.push({ distance, ...current });
    expect(Math.abs(current.position - distance)).toBeLessThanOrEqual(2);
    expect(current.rotation).toBe('none');
  }
  await page.mouse.move(start.x, start.y + 25, { steps: 5 });
  const held = await pose(page);
  await page.waitForTimeout(180);
  expect((await pose(page)).circles).toEqual(held.circles);
  await page.mouse.up();
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await info.attach('actual-slow-drag-contact-poses', {
    body: JSON.stringify(states, null, 2),
    contentType: 'application/json',
  });
});

test('reduced motion keeps a clear upright circle without contact masses', async ({
  page,
}) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await ready(page);
  const state = await seekOffset(page, 25);
  expect(state.rotation).toBe('none');
  expect(state.circles.filter((c) => c.r > 0)).toHaveLength(1);
  await page.locator('[data-rail-node="download"]').click();
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect(page.locator('[data-rail-node="download"]')).toHaveAttribute(
    'aria-current',
    'location',
  );
  expect((await pose(page)).rotation).toBe('none');
});

test('unavailable SVG filters retain circular-brand navigation and drag landing', async ({
  page,
}) => {
  await page.addInitScript(() => {
    Object.defineProperty(window, 'SVGFEGaussianBlurElement', {
      configurable: true,
      value: undefined,
    });
  });
  await ready(page);
  await expect(page.locator(rail)).toHaveAttribute(
    'data-liquid-mode',
    'circle',
  );
  await page.locator('[data-rail-node="download"]').click();
  await expect(page.locator('[data-rail-node="download"]')).toHaveAttribute(
    'aria-current',
    'location',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  const thumb = await page.locator('[data-rail-thumb]').boundingBox();
  await page.mouse.move(thumb!.x + 24, thumb!.y + 24);
  await page.mouse.down();
  await page.mouse.move(thumb!.x + 24, thumb!.y - 42, { steps: 5 });
  await page.mouse.up();
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter-rail',
    'ready',
  );
  expect((await pose(page)).rotation).toBe('none');
});
