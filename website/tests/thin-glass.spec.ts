import { expect, test, type Page, type TestInfo } from '@playwright/test';

const sceneChunk = /court-scene[^/]*\.(?:js|ts)(?:\?|$)/;
const captures = [
  {
    selector: '.scoring-display',
    preset: 'scoring-screen',
    image: 'scoring',
    width: 1818,
    height: 954,
    chapter: 'scoring',
  },
  {
    selector: '[data-replay-device="summary"]',
    preset: 'replay-summary',
    image: 'summary',
    width: 1080,
    height: 1783,
    chapter: 'replay',
  },
  {
    selector: '[data-replay-device="history"]',
    preset: 'replay-history',
    image: 'history',
    width: 1080,
    height: 1783,
    chapter: 'replay',
  },
] as const;

async function attach(info: TestInfo, name: string, data: unknown) {
  await info.attach(name, {
    body: JSON.stringify(data, null, 2),
    contentType: 'application/json',
  });
}

async function layoutStable(page: Page) {
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('#closing')).toHaveAttribute(
    'data-scroll-read-end',
    /\d/,
  );
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
      return checkpoint.ready && Date.now() - stableSince >= 200;
    })
    .toBe(true);
}

async function openCSS(page: Page, path: string, reduced = true) {
  await page.route(sceneChunk, (route) => route.abort());
  await page.emulateMedia({
    reducedMotion: reduced ? 'reduce' : 'no-preference',
  });
  await page.goto(path);
  await layoutStable(page);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  await expect(page.locator('html')).not.toHaveAttribute('data-glass', 'webgl');
  // Mobile intentionally never creates a scene and needs no mode attribute.
  // Check the actual default CSS material instead of inventing initialization.
  await expect(page.locator('[data-glass-card]').first()).toHaveCSS(
    'background-color',
    'rgba(21, 27, 30, 0.54)',
  );
}

async function seek(
  page: Page,
  chapter: string,
  edge: 'start' | 'end' = 'start',
) {
  await layoutStable(page);
  // Read only coordinates published after fonts and ResizeObserver have settled.
  const stage = page.locator(`[data-story-stage="${chapter}"]`);
  await stage.evaluate((element: HTMLElement, edge) => {
    scrollTo({
      top: Number(
        edge === 'start'
          ? element.dataset.scrollReadStart
          : element.dataset.scrollReadEnd,
      ),
      behavior: 'instant',
    });
  }, edge);
  await expect
    .poll(() =>
      stage.evaluate((element: HTMLElement) => {
        const start = Number(element.dataset.scrollReadStart);
        const end = Number(element.dataset.scrollReadEnd);
        return (
          scrollY >= start - 2 &&
          scrollY <= end + 2 &&
          document.documentElement.dataset.scrollState === 'idle' &&
          [...element.querySelectorAll<HTMLElement>('[data-story-item]')].every(
            (item) => Number(getComputedStyle(item).opacity) >= 0.999,
          )
        );
      }),
    )
    .toBe(true);
}

async function revealHistory(page: Page) {
  const disclosure = page.locator('[data-mobile-disclosure="history"]');
  if (
    !(await disclosure.evaluate((element: HTMLDetailsElement) => element.open))
  ) {
    await disclosure.locator(':scope > summary').click();
    await expect(disclosure).toHaveAttribute('open');
  }
}

const layouts = [
  { name: 'mobile', width: 390, height: 844 },
  { name: 'compact', width: 1024, height: 768 },
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'wide', width: 1920, height: 1080 },
  { name: 'short', width: 1440, height: 600 },
  { name: '200 percent text', width: 1024, height: 640, scale: 2 },
] as const;

for (const locale of ['zh', 'en'] as const) {
  const path = locale === 'zh' ? '/' : '/en/';
  for (const layout of layouts) {
    test(`${locale} ${layout.name}: complete App captures have no glass material or crop`, async ({
      page,
    }, info) => {
      await page.setViewportSize(layout);
      await openCSS(page, path);
      if ('scale' in layout) {
        await page.evaluate((scale) => {
          document.documentElement.style.fontSize = `${scale * 100}%`;
        }, layout.scale);
        await layoutStable(page);
      }
      const states = [];
      for (const capture of captures) {
        if (capture.image === 'history') await revealHistory(page);
        const figure = page.locator(capture.selector);
        await figure.evaluate((element) =>
          element.scrollIntoView({ behavior: 'instant', block: 'center' }),
        );
        const image = figure.locator('img');
        await expect(image).toHaveJSProperty('naturalWidth', capture.width);
        await expect(image).toHaveJSProperty('naturalHeight', capture.height);
        await expect(figure).toHaveAttribute('data-story-item', 'visual');
        await expect(figure).toHaveAttribute(
          'data-story-preset',
          capture.preset,
        );
        await expect(figure).not.toHaveAttribute('data-glass-card');
        await expect(figure).not.toHaveAttribute('data-glass-id');
        await expect(image).toHaveAttribute(
          'src',
          `/screenshots/${locale}/${capture.image}.webp`,
        );
        await expect(figure.locator('.viewer-link')).toHaveAttribute(
          'href',
          `/screenshots/${locale}/${capture.image}.webp`,
        );
        const state = await figure.evaluate((element) => {
          const image = element.querySelector('img')!;
          const style = getComputedStyle(element);
          const imageStyle = getComputedStyle(image);
          const box = image.getBoundingClientRect();
          const chain = [];
          for (
            let item: Element | null = image;
            item;
            item = item.parentElement
          ) {
            const computed = getComputedStyle(item);
            chain.push({
              glass: item.hasAttribute('data-glass-card'),
              backdrop:
                computed.getPropertyValue('-webkit-backdrop-filter') ||
                computed.backdropFilter,
              filter: computed.filter,
              mask: computed.maskImage,
            });
            if (item === element) break;
          }
          return {
            preset: (element as HTMLElement).dataset.storyPreset,
            ratio: box.width / box.height,
            naturalRatio: image.naturalWidth / image.naturalHeight,
            background: style.backgroundColor,
            backgroundImage: style.backgroundImage,
            borders: [
              style.borderTopWidth,
              style.borderRightWidth,
              style.borderBottomWidth,
              style.borderLeftWidth,
            ],
            shadow: style.boxShadow,
            padding: style.padding,
            fit: imageStyle.objectFit,
            imageBorder: imageStyle.borderTopWidth,
            imageRadius: imageStyle.borderRadius,
            imageClip: imageStyle.clipPath,
            chain,
          };
        });
        expect(state.ratio).toBeCloseTo(state.naturalRatio, 3);
        expect(state).toMatchObject({
          background: 'rgba(0, 0, 0, 0)',
          backgroundImage: 'none',
          borders: ['0px', '0px', '0px', '0px'],
          shadow: 'none',
          padding: '0px',
          imageBorder: '0px',
          imageRadius: '0px',
          imageClip: 'none',
        });
        expect(state.fit).not.toBe('cover');
        expect(state.chain.every((item) => !item.glass)).toBe(true);
        expect(
          state.chain.every(
            (item) =>
              (!item.backdrop || item.backdrop === 'none') &&
              item.filter === 'none' &&
              item.mask === 'none',
          ),
        ).toBe(true);
        states.push(state);
      }
      await expect(page.locator('#scoring [data-glass-card]')).toHaveCount(1);
      await expect(page.locator('#replay [data-glass-card]')).toHaveCount(1);
      expect(
        await page.evaluate(
          () => document.documentElement.scrollWidth - innerWidth,
        ),
      ).toBeLessThanOrEqual(1);
      await attach(info, 'complete-app-captures', states);
    });
  }

  for (const width of [390, 1440]) {
    test(`${locale} ${width}px: open scoring rows and FAQ keep large targets and working controls`, async ({
      page,
    }, info) => {
      await page.setViewportSize({ width, height: 900 });
      await openCSS(page, `${path}#scoring`);
      const rowStates = [];
      for (const index of [0, 1, 2]) {
        const feature = page.locator(`[data-score-feature="${index}"]`);
        await feature.click();
        await expect(feature).toHaveAttribute('aria-pressed', 'true');
        await expect(page.locator('[data-score-current]')).toHaveText(
          (await feature.locator('strong').textContent())!,
        );
        const state = await feature.evaluate((element) => {
          const style = getComputedStyle(element);
          const bounds = element.getBoundingClientRect();
          return {
            borders: [
              style.borderRightWidth,
              style.borderBottomWidth,
              style.borderLeftWidth,
            ],
            background: style.backgroundColor,
            backgroundImage: style.backgroundImage,
            shadow: style.boxShadow,
            width: bounds.width,
            height: bounds.height,
          };
        });
        expect(state).toMatchObject({
          borders: ['0px', '0px', '0px'],
          background: 'rgba(0, 0, 0, 0)',
          backgroundImage: 'none',
          shadow: 'none',
        });
        expect(state.width).toBeGreaterThanOrEqual(48);
        expect(state.height).toBeGreaterThanOrEqual(48);
        rowStates.push(state);
      }
      for (const capture of captures) {
        if (capture.image === 'history') await revealHistory(page);
        const link = page.locator(`${capture.selector} .viewer-link`);
        await link.click();
        await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
          'data-image-state',
          'ready',
        );
        await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
          'naturalWidth',
          capture.width,
        );
        await expect(page.locator('[data-viewer-image]')).toHaveJSProperty(
          'naturalHeight',
          capture.height,
        );
        await page.keyboard.press('Escape');
        await expect(link).toBeFocused();
      }
      await page.locator('[data-point-preset="center"]').click();
      await page.locator('[data-record]').click();
      await expect(page.locator('[data-blue-score]')).toHaveText('8');
      await page.locator('[data-reset]').click();
      await expect(page.locator('[data-blue-score]')).toHaveText('6');
      await page.locator('.download-package [data-download]').click();
      await expect(page.locator('[data-download-dialog]')).toBeVisible();
      await expect(
        page.locator('[data-download-channel="github"]'),
      ).toHaveAttribute('href', /github\.com\/.*\.apk/);
      await page.keyboard.press('Escape');
      const faq = page.locator('.faq details').first();
      await faq.locator('summary').click();
      await expect(faq).toHaveAttribute('open', '');
      await expect(faq.locator('p')).toBeVisible();
      const faqState = await faq.evaluate((element) => {
        const style = getComputedStyle(element);
        return {
          topColor: style.borderTopColor,
          rightColor: style.borderRightColor,
          bottomColor: style.borderBottomColor,
          leftColor: style.borderLeftColor,
          sideWidths: [style.borderRightWidth, style.borderLeftWidth],
          background: style.backgroundColor,
          backgroundImage: style.backgroundImage,
          shadow: style.boxShadow,
          targetHeight: element
            .querySelector('summary')!
            .getBoundingClientRect().height,
        };
      });
      // Expanded rows use quiet separators; an orange perimeter would match
      // the primary action color and turn each answer into another card.
      expect([
        faqState.topColor,
        faqState.rightColor,
        faqState.bottomColor,
        faqState.leftColor,
      ]).not.toContain('rgb(238, 149, 108)');
      expect(faqState.sideWidths).toEqual(['0px', '0px']);
      expect(faqState.background).toBe('rgba(0, 0, 0, 0)');
      expect(faqState.backgroundImage).toBe('none');
      expect(faqState.shadow).toBe('none');
      expect(faqState.targetHeight).toBeGreaterThanOrEqual(48);
      await attach(info, 'open-reading-rows', { rowStates, faqState });
    });
  }

  test(`${locale}: CSS full and density material states remain distinct from rendered glass`, async ({
    page,
  }, info) => {
    await openCSS(page, path);
    const states = await page
      .locator('[data-glass-id="hero-actions"]')
      .evaluate((card) => {
        const root = document.documentElement;
        const before = {
          glass: root.dataset.glass,
          quality: root.dataset.quality,
        };
        const read = () => {
          const style = getComputedStyle(card);
          const header = getComputedStyle(
            document.querySelector('.site-header')!,
          );
          return {
            background: style.backgroundColor,
            image: style.backgroundImage,
            backdrop:
              style.getPropertyValue('-webkit-backdrop-filter') ||
              style.backdropFilter,
            borders: [
              style.borderTopColor,
              style.borderRightColor,
              style.borderBottomColor,
              style.borderLeftColor,
            ],
            shadow: style.boxShadow,
            header: {
              background: header.backgroundColor,
              backdrop:
                header.getPropertyValue('-webkit-backdrop-filter') ||
                header.backdropFilter,
            },
          };
        };
        try {
          // A CSS contract check only: this deliberately does not claim that a
          // WebGL optical pass ran, or force the renderer's adaptive quality.
          root.dataset.glass = 'css';
          root.dataset.quality = 'full';
          const css = read();
          root.dataset.glass = 'webgl';
          const full = read();
          root.dataset.glass = 'css';
          root.dataset.quality = 'density';
          const density = read();
          return { css, full, density };
        } finally {
          if (before.glass === undefined) delete root.dataset.glass;
          else root.dataset.glass = before.glass;
          if (before.quality === undefined) delete root.dataset.quality;
          else root.dataset.quality = before.quality;
        }
      });
    expect(states.css.background).toBe('rgba(21, 27, 30, 0.54)');
    expect(states.css.image).toBe('none');
    expect(states.css.backdrop).toMatch(/blur\(12px\)/);
    expect(states.css.backdrop).toMatch(/saturate\((?:0\.9|90%)\)/);
    expect(states.full).toMatchObject({
      background: 'rgba(0, 0, 0, 0)',
      image: 'none',
      backdrop: 'none',
      borders: Array(4).fill('rgba(0, 0, 0, 0)'),
    });
    expect(states.full.shadow).not.toContain('inset');
    expect(states.css.shadow).not.toContain('inset');
    expect(states.full.header).toEqual(states.css.header);
    expect(states.density.header).toEqual(states.css.header);
    expect(states.css.header.backdrop).toContain('blur(22px)');
    expect(states.density.background).toBe('rgba(21, 27, 30, 0.9)');
    expect(states.density.image).toBe('none');
    expect(states.density.backdrop).toBe('none');
    await attach(info, 'css-material-contract-only', states);
  });
}

test('@webgl real rendered frames exclude App captures while retaining their story transforms', async ({
  page,
}, info) => {
  test.setTimeout(60_000);
  const capable = await page.evaluate(() => {
    const context = document.createElement('canvas').getContext('webgl2', {
      failIfMajorPerformanceCaveat: true,
    });
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!context;
  });
  test.skip(
    !capable,
    'Production WebGL2 unavailable; CSS contracts run separately.',
  );
  await page.route(sceneChunk, async (route) => {
    const response = await route.fetch();
    let body = await response.text();
    const exports = body.match(/export\s*\{([^}]*\bcreateCourtScene\b[^}]*)\}/);
    const factory = exports?.[1].match(
      /(?:^|,)\s*([\w$]+)\s+as\s+createCourtScene\b/,
    )?.[1];
    if (!exports || !factory)
      throw new Error('Cannot observe production scene factory.');
    body = body.replace(
      exports[0],
      exports[0].replace(
        /[\w$]+\s+as\s+createCourtScene\b/,
        '__thinSceneCreate as createCourtScene',
      ),
    );
    body += `\nasync function __thinSceneCreate(...args) {
      const scene = await ${factory}(...args);
      let surfaces = [];
      const frames = [];
      Reflect.set(window, '__thinGlassFrames', frames);
      const set = scene.setGlassSurfaces.bind(scene);
      scene.setGlassSurfaces = value => { surfaces = structuredClone(value); set(value); };
      const flush = scene.flushFrame.bind(scene);
      scene.flushFrame = () => {
        const before = Number(args[0].dataset.renderCount);
        flush();
        if (Number(args[0].dataset.renderCount) === before) return;
        frames.push({ at: performance.now(), y: scrollY, quality: args[0].dataset.quality,
          glass: args[0].dataset.glass,
          visibleOptical: [...document.querySelectorAll('[data-glass-card]')].filter(item => {
            const bounds = item.getBoundingClientRect();
            return Number(getComputedStyle(item).opacity) > .001 && bounds.bottom >= 0 && bounds.top <= innerHeight && bounds.right >= 0 && bounds.left <= innerWidth;
          }).length,
          surfaces: surfaces.map(surface => {
            const card = [...document.querySelectorAll('[data-glass-id]')].find(item => item.dataset.glassId === surface.id);
            const bounds = card.getBoundingClientRect();
            return { id: surface.id, error: Math.max(...['left','top','width','height'].map(key => Math.abs(bounds[key] - surface.region[key]))) };
          }),
          captures: [...document.querySelectorAll('.scoring-display, [data-replay-device]')].map(item => {
            const style = getComputedStyle(item);
            return { preset: item.dataset.storyPreset, role: item.dataset.storyItem,
              transform: style.transform, opacity: Number(style.opacity), inert: item.inert,
              optical: item.closest('[data-glass-card]') !== null };
          }) });
      };
      return scene;
    }`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
  await page.goto('/');
  await layoutStable(page);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20_000,
  });
  for (const [chapter, edge, delta, destination] of [
    ['hero', 'end', 24, 'scoring'],
    ['experience', 'end', 24, 'replay'],
    ['download', 'start', -24, 'replay'],
  ] as const) {
    await seek(page, chapter, edge);
    await page.mouse.move(12, 450);
    await page.mouse.wheel(0, delta);
    await expect(page.locator('html')).toHaveAttribute(
      'data-scroll-stop',
      destination,
    );
    await expect(page.locator('html')).toHaveAttribute(
      'data-scroll-state',
      'idle',
    );
  }
  type Frame = {
    quality: string;
    glass: string;
    visibleOptical: number;
    surfaces: { id: string; error: number }[];
    captures: {
      preset: string;
      role: string;
      transform: string;
      opacity: number;
      inert: boolean;
      optical: boolean;
    }[];
  };
  const frames = await page.evaluate(
    () => Reflect.get(window, '__thinGlassFrames') as Frame[],
  );
  await attach(info, 'real-rendered-glass-and-capture-frames', frames);
  expect(frames.length).toBeGreaterThan(6);
  for (const frame of frames) {
    expect(frame.surfaces.length).toBeLessThanOrEqual(6);
    expect(frame.visibleOptical).toBeLessThanOrEqual(6);
    expect(
      frame.surfaces.some((surface) =>
        ['scoring-screen', 'replay-summary', 'replay-history'].includes(
          surface.id,
        ),
      ),
    ).toBe(false);
    expect(frame.captures).toHaveLength(3);
    expect(
      frame.captures.every(
        (capture) => capture.role === 'visual' && !capture.optical,
      ),
    ).toBe(true);
    expect(
      frame.captures
        .filter((capture) => capture.opacity < 0.05)
        .every((capture) => capture.inert),
    ).toBe(true);
  }
  for (const capture of captures) {
    const moving = frames.flatMap((frame) =>
      frame.captures.filter(
        (item) =>
          item.preset === capture.preset &&
          item.opacity > 0.05 &&
          item.opacity < 0.999,
      ),
    );
    expect(
      moving.length,
      `${capture.preset} real moving frames`,
    ).toBeGreaterThan(0);
    expect(new Set(moving.map((item) => item.transform)).size).toBeGreaterThan(
      1,
    );
  }
  const optical = frames.filter(
    (frame) => frame.quality === 'full' && frame.glass === 'webgl',
  );
  await attach(info, 'actual-optical-capability', {
    opticalFrames: optical.length,
    modes: [
      ...new Set(frames.map((frame) => `${frame.quality}/${frame.glass}`)),
    ],
  });
  if (optical.length) {
    expect(optical.some((frame) => frame.surfaces.length)).toBe(true);
    expect(
      Math.max(
        ...optical.flatMap((frame) =>
          frame.surfaces.map((surface) => surface.error),
        ),
      ),
    ).toBeLessThan(0.1);
  } else {
    info.annotations.push({
      type: 'capability',
      description:
        'Actual adaptive runtime used CSS optics. This run does not establish full WebGL material coverage.',
    });
  }
  for (const frame of frames.filter((frame) => frame.quality !== 'full'))
    expect(frame.surfaces).toHaveLength(0);
});

test('@webgl optical initialization failure preserves readable CSS glass and product images', async ({
  page,
}, info) => {
  test.setTimeout(45_000);
  const capable = await page.evaluate(() => {
    const context = document
      .createElement('canvas')
      .getContext('webgl2', { failIfMajorPerformanceCaveat: true });
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!context;
  });
  test.skip(
    !capable,
    'Production WebGL2 unavailable; startup fallback is checked separately.',
  );
  await page.route(sceneChunk, async (route) => {
    const response = await route.fetch();
    const original = await response.text();
    const body = original.replace(
      /name:\s*(["'`])HoopitoLiquidGlass\1/,
      'name: (() => { Reflect.set(window, "__thinOpticalFailure", true); throw new Error("Injected optical initialization failure"); })()',
    );
    if (body === original)
      throw new Error(
        'Cannot target only the real optical pass initialization.',
      );
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
  await page.goto('/#scoring');
  await layoutStable(page);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20_000,
  });
  expect(
    await page.evaluate(() => Reflect.get(window, '__thinOpticalFailure')),
  ).toBe(true);
  await expect(page.locator('html')).toHaveAttribute('data-glass', 'css');
  const controls = page.locator('[data-glass-id="scoring-controls"]');
  await expect(controls).toBeVisible();
  await expect(controls).toHaveCSS('opacity', '1');
  await page.locator('[data-score-feature="0"]').click();
  await expect(page.locator('[data-score-feature="0"]')).toHaveAttribute(
    'aria-pressed',
    'true',
  );
  await expect(page.locator('.scoring-display img')).toHaveJSProperty(
    'naturalWidth',
    1818,
  );
  await expect(page.locator('.scoring-display')).not.toHaveAttribute(
    'data-glass-card',
  );
  await attach(
    info,
    'optical-failure-css-recovery',
    await page.evaluate(() => ({
      root: { ...document.documentElement.dataset },
      canvas: {
        ...document.querySelector<HTMLCanvasElement>('#court-canvas')!.dataset,
      },
    })),
  );
});

test('@webgl reduced motion naturally renders full-quality reading surfaces on their DOM regions', async ({
  page,
}, info) => {
  test.setTimeout(60_000);
  const capable = await page.evaluate(() => {
    const context = document.createElement('canvas').getContext('webgl2', {
      failIfMajorPerformanceCaveat: true,
    });
    context?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!context;
  });
  test.skip(
    !capable,
    'Production WebGL2 unavailable; CSS reading remains covered.',
  );
  await page.emulateMedia({ reducedMotion: 'reduce' });
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
        '__thinReadingCreate as createCourtScene',
      ),
    );
    body += `\nasync function __thinReadingCreate(...args) {
      const scene = await ${factory}(...args);
      let surfaces = [];
      const frames = [];
      Reflect.set(window, '__thinReadingFrames', frames);
      const set = scene.setGlassSurfaces.bind(scene);
      scene.setGlassSurfaces = value => { surfaces = structuredClone(value); set(value); };
      const flush = scene.flushFrame.bind(scene);
      scene.flushFrame = () => {
        const before = Number(args[0].dataset.renderCount);
        flush();
        if (Number(args[0].dataset.renderCount) === before) return;
        frames.push({ quality: args[0].dataset.quality, glass: args[0].dataset.glass,
          renderer: args[0].dataset.renderer, count: Number(args[0].dataset.renderCount),
          surfaces: surfaces.map(surface => {
            const card = [...document.querySelectorAll('[data-glass-id]')].find(item => item.dataset.glassId === surface.id);
            const bounds = card.getBoundingClientRect();
            return { id: surface.id, error: Math.max(...['left','top','width','height'].map(key => Math.abs(bounds[key] - surface.region[key]))) };
          }) });
      };
      return scene;
    }`;
    await route.fulfill({ response, body, contentType: 'text/javascript' });
  });
  await page.goto('/#download');
  await layoutStable(page);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20_000,
  });
  const canvas = page.locator('#court-canvas');
  await expect(canvas).toHaveAttribute('data-rendering', 'idle');
  type Frame = {
    quality: string;
    glass: string;
    renderer: string;
    count: number;
    surfaces: { id: string; error: number }[];
  };
  const frames = () =>
    page.evaluate(
      () => Reflect.get(window, '__thinReadingFrames') as Frame[] | undefined,
    );
  // These are real native reading scrolls with ordinary reduced motion. No
  // dataset, quality, material, calibration or render cadence is overridden.
  for (const delta of [40, -40, 40, -40]) {
    const before = Number(await canvas.getAttribute('data-render-count'));
    await page.evaluate(
      (delta) => scrollBy({ top: delta, behavior: 'instant' }),
      delta,
    );
    await expect
      .poll(async () => Number(await canvas.getAttribute('data-render-count')))
      .toBeGreaterThan(before);
  }
  const observed = (await frames()) ?? [];
  const optical = observed.filter(
    (frame) =>
      frame.quality === 'full' &&
      frame.glass === 'webgl' &&
      frame.surfaces.length > 0,
  );
  const state = await page.evaluate(() => ({
    root: { ...document.documentElement.dataset },
    canvas: {
      ...document.querySelector<HTMLCanvasElement>('#court-canvas')!.dataset,
    },
  }));
  await attach(info, 'natural-reduced-motion-reading-frames', {
    observed,
    state,
  });
  test.skip(
    optical.length === 0,
    `Natural reduced-motion full optical path unavailable: ${JSON.stringify(state)}`,
  );
  expect(optical.length).toBeGreaterThanOrEqual(3);
  for (const frame of optical) {
    expect(frame.surfaces.length).toBeLessThanOrEqual(6);
    expect(
      frame.surfaces.some((surface) =>
        ['scoring-screen', 'replay-summary', 'replay-history'].includes(
          surface.id,
        ),
      ),
    ).toBe(false);
    expect(
      Math.max(...frame.surfaces.map((surface) => surface.error)),
    ).toBeLessThan(0.1);
  }
});
