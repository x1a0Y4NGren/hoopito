import { expect, test, type Page } from '@playwright/test';

test('replay refresh preserves its plot without rewriting unchanged SVG geometry', async ({
  page,
}) => {
  await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
    route.abort(),
  );
  await page.goto('/en/');
  await page.evaluate(() => document.fonts.ready);
  const stage = page.locator('[data-story-stage="replay"]');
  await expect(stage).toHaveAttribute('data-replay-progress', '0.0000');
  await page.evaluate(() => {
    const stage = document.querySelector('[data-story-stage="replay"]')!;
    const clip = stage.querySelector('[data-replay-clip]')!;
    const cursor = stage.querySelector('[data-replay-cursor]')!;
    const writes: string[] = [];
    const original = SVGElement.prototype.setAttribute;
    SVGElement.prototype.setAttribute = function (name, value) {
      if (
        ((this === clip && name === 'width') ||
          (this === cursor && name === 'transform')) &&
        this.getAttribute(name) === value
      )
        writes.push(name);
      return original.call(this, name, value);
    };
    const probe = {
      writes,
      refreshes: 0,
      before: [clip.getAttribute('width'), cursor.getAttribute('transform')],
      stop: () => {},
    };
    const observer = new MutationObserver((records) => {
      probe.refreshes += records.length;
    });
    observer.observe(stage, {
      attributes: true,
      attributeFilter: ['data-story-start'],
    });
    probe.stop = () => {
      SVGElement.prototype.setAttribute = original;
      observer.disconnect();
    };
    Reflect.set(window, '__replayRefreshProbe', probe);
    dispatchEvent(new Event('resize'));
  });
  await expect
    .poll(() =>
      page.evaluate(
        () => Reflect.get(window, '__replayRefreshProbe').refreshes,
      ),
    )
    .toBeGreaterThan(0);
  const result = await page.evaluate(() => {
    const probe = Reflect.get(window, '__replayRefreshProbe');
    probe.stop();
    const stage = document.querySelector('[data-story-stage="replay"]')!;
    return {
      before: probe.before,
      after: [
        stage.querySelector('[data-replay-clip]')!.getAttribute('width'),
        stage.querySelector('[data-replay-cursor]')!.getAttribute('transform'),
      ],
      writes: probe.writes,
    };
  });
  expect(result.after).toEqual(result.before);
  expect(result.writes).toEqual([]);
  await page.locator('.site-header a[href="#replay"]').click();
  await expect(stage).toHaveAttribute('data-replay-progress', '1.0000');
  await expect(page.locator('[data-replay-blue]')).toHaveText('8');
  await expect(page.locator('[data-replay-red]')).toHaveText('11');
});

test('scroll batching: one stationary scroll notification reads each chapter boundary once', async ({
  page,
}) => {
  await page.setViewportSize({ width: 1440, height: 900 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
    route.abort(),
  );
  await page.goto('/en/#experience');
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter',
    'experience',
  );
  const reads = await page.evaluate(async () => {
    const chapters = new Set([
      'hero',
      'scoring',
      'experience',
      'replay',
      'download',
    ]);
    const reads: Record<string, number> = {};
    const original = Element.prototype.getBoundingClientRect;
    Element.prototype.getBoundingClientRect = function () {
      if (chapters.has(this.id)) reads[this.id] = (reads[this.id] ?? 0) + 1;
      return original.call(this);
    };
    try {
      // An unchanged scroll notification still updates the story, but must not
      // ask layout for the current chapter three separate times in that update.
      dispatchEvent(new Event('scroll'));
      await new Promise(requestAnimationFrame);
      await new Promise(requestAnimationFrame);
      return reads;
    } finally {
      Element.prototype.getBoundingClientRect = original;
    }
  });
  expect(reads.experience).toBe(1);
  for (const count of Object.values(reads)) expect(count).toBe(1);
  await expect(
    page.locator('.site-header a[href="#experience"]'),
  ).toHaveAttribute('aria-current', 'location');
});

test('scroll batching: a stationary court invitation does not rewrite its placement', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/en/#experience');
  await page.evaluate(() => document.fonts.ready);
  const host = page.locator('[data-demo-court-host]');
  await host.scrollIntoViewIfNeeded();
  await expect(host).toHaveAttribute('data-demo-invitation', 'playing');
  const placement = await page.evaluate(async () => {
    const layer = document.querySelector<HTMLElement>(
      '[data-demo-court-host] .demo-invitation-layer[data-cue-kind="court"]',
    )!;
    const original = CSSStyleDeclaration.prototype.setProperty;
    const repeated: string[] = [];
    CSSStyleDeclaration.prototype.setProperty = function (
      name,
      value,
      priority,
    ) {
      if (
        this === layer.style &&
        name.startsWith('--court-') &&
        this.getPropertyValue(name) === value
      )
        repeated.push(name);
      original.call(this, name, value, priority);
    };
    try {
      dispatchEvent(new Event('scroll'));
      await new Promise(requestAnimationFrame);
      await new Promise(requestAnimationFrame);
      return repeated;
    } finally {
      CSSStyleDeclaration.prototype.setProperty = original;
    }
  });
  expect(placement).toEqual([]);
});

async function enlargeChapterText(page: Page) {
  await page.evaluate(() => {
    const nodes = [...document.querySelectorAll<HTMLElement>('body *')].filter(
      (element) =>
        [...element.childNodes].some(
          (node) =>
            node.nodeType === Node.TEXT_NODE && node.textContent?.trim(),
        ),
    );
    const sizes = nodes.map(
      (element) =>
        [element, parseFloat(getComputedStyle(element).fontSize)] as const,
    );
    for (const [element, size] of sizes)
      element.style.fontSize = `${size * 2}px`;
    dispatchEvent(new Event('resize'));
  });
}

for (const locale of ['/', '/en/']) {
  for (const width of [360, 390, 768]) {
    test(`chapter polish: ${locale} ${width}px actions and FAQ retain readable type and touch targets`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 844 });
      await page.goto(`${locale}#download`);
      await page.evaluate(() => document.fonts.ready);
      const sizes = await page
        .locator(
          '[data-record], [data-reset], .download-package [data-download], .faq summary',
        )
        .evaluateAll((elements) =>
          elements.map((element) => {
            const bounds = element.getBoundingClientRect();
            return {
              text: element.textContent!.trim(),
              font: parseFloat(getComputedStyle(element).fontSize),
              width: bounds.width,
              height: bounds.height,
            };
          }),
        );
      for (const size of sizes) {
        expect.soft(size.font, size.text).toBeGreaterThanOrEqual(14);
        expect.soft(size.width, size.text).toBeGreaterThanOrEqual(48);
        expect.soft(size.height, size.text).toBeGreaterThanOrEqual(48);
      }
    });
  }

  for (const viewport of [
    { width: 360, height: 844 },
    { width: 768, height: 1024 },
    { width: 640, height: 360 },
  ]) {
    test(`chapter polish: ${locale} ${viewport.width}px full release and expanded details reflow at 200 percent text`, async ({
      page,
    }) => {
      await page.setViewportSize(viewport);
      await page.goto(`${locale}#download`);
      await page.evaluate(() => document.fonts.ready);
      await expect(page.locator('.version-line > b')).toHaveText('2.0.1');
      await expect(page.locator('.release-tag')).toHaveText(
        locale === '/' ? '正式版' : 'Stable',
      );
      const apk =
        'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.0.1/Hoopito-v2.0.1-android.apk';
      await expect(
        page.locator('.download-package [data-download]'),
      ).toHaveAttribute('href', apk);
      await expect(page.locator('.checksum code')).toHaveText(
        'c42a9a71836f47c70bd1cafb08ae1232083909970afdc7d9e150ce9cc68b87b9',
      );
      await enlargeChapterText(page);
      for (const selector of [
        '.checksum',
        '.upgrade',
        '.faq details:first-child',
      ]) {
        await page.locator(`${selector} summary`).click();
        await expect(page.locator(selector)).toHaveAttribute('open');
      }
      const iconOverflow = await page.evaluate(async () => {
        const faq = document.querySelector('.faq')!;
        const icon = faq.querySelector('details[open] summary > .icon')!;
        const overflow: number[] = [];
        for (let frame = 0; frame < 20; frame++) {
          await new Promise(requestAnimationFrame);
          overflow.push(
            icon.getBoundingClientRect().right -
              faq.getBoundingClientRect().right,
          );
        }
        return Math.max(...overflow);
      });
      expect(iconOverflow).toBeLessThanOrEqual(1);
      const layout = await page.evaluate(() => {
        const card = document
          .querySelector('.download-package')!
          .getBoundingClientRect();
        const version = document
          .querySelector('.version-line > b')!
          .getBoundingClientRect();
        const record = document
          .querySelector('[data-record]')!
          .getBoundingClientRect();
        const reset = document
          .querySelector('[data-reset]')!
          .getBoundingClientRect();
        return {
          overflow: document.documentElement.scrollWidth - innerWidth,
          clipped: [
            ...document.querySelectorAll<HTMLElement>(
              '.version-line, .demo-actions, .faq',
            ),
          ].map((element) => element.scrollWidth - element.clientWidth),
          cardContentInside: [
            ...document.querySelectorAll<HTMLElement>('.download-package > *'),
          ].every((element) => {
            const bounds = element.getBoundingClientRect();
            return (
              bounds.left >= card.left - 1 && bounds.right <= card.right + 1
            );
          }),
          versionInside:
            version.left >= card.left && version.right <= card.right,
          actionsApart:
            reset.top >= record.bottom - 1 || reset.left >= record.right - 1,
        };
      });
      expect(layout.overflow).toBeLessThanOrEqual(1);
      expect(layout.clipped.every((value) => value <= 1)).toBe(true);
      expect(layout.cardContentInside).toBe(true);
      expect(layout.versionInside).toBe(true);
      expect(layout.actionsApart).toBe(true);
    });
  }
}

test('chapter polish: enabled actions share pressed and keyboard feedback while disabled scoring stays still', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/en/#experience');
  const record = page.locator('[data-record]');
  await record.scrollIntoViewIfNeeded();
  await page.mouse.move(0, 0);
  const disabled = await record.evaluate((element) => ({
    shadow: getComputedStyle(element).boxShadow,
    transform: getComputedStyle(element).transform,
  }));
  const disabledBounds = (await record.boundingBox())!;
  await page.mouse.move(disabledBounds.x + 30, disabledBounds.y + 25);
  await page.mouse.down();
  await expect(record).toBeDisabled();
  expect(
    await record.evaluate((element) => ({
      shadow: getComputedStyle(element).boxShadow,
      transform: getComputedStyle(element).transform,
    })),
  ).toEqual(disabled);
  await page.mouse.move(0, 0);
  await page.mouse.up();
  await page.locator('[data-point-preset="center"]').click();
  const download = page.locator('.download-package [data-download]');
  await page.route((await download.getAttribute('href'))!, (route) =>
    route.fulfill({
      status: 200,
      headers: {
        'content-type': 'application/vnd.android.package-archive',
        'content-disposition': 'attachment; filename="press-feedback.apk"',
      },
      body: 'Local press-feedback test fixture',
    }),
  );
  for (const selector of [
    '[data-record]',
    '[data-reset]',
    '.download-package [data-download]',
  ]) {
    const action = page.locator(selector);
    await action.scrollIntoViewIfNeeded();
    await page.mouse.move(0, 0);
    // The previous hover can still be easing out when a scrolled action is read.
    await page.waitForTimeout(240);
    const before = await action.evaluate(
      (element) => getComputedStyle(element).boxShadow,
    );
    const bounds = (await action.boundingBox())!;
    await page.mouse.move(
      bounds.x + bounds.width / 2,
      bounds.y + bounds.height / 2,
    );
    await page.mouse.down();
    await expect
      .poll(() =>
        action.evaluate((element) => getComputedStyle(element).boxShadow),
      )
      .not.toBe(before);
    const durations = await action.evaluate((element) =>
      getComputedStyle(element).transitionDuration.split(',').map(parseFloat),
    );
    expect(
      durations.every((duration) => Math.abs(duration - 0.2) < 0.001),
    ).toBe(true);
    if (selector === '.download-package [data-download]') {
      // Release on the link: Firefox retains native :active on a cancelled
      // drag even without site styles. Exercise the real click and download.
      const downloadRequest = page.waitForRequest(
        (await download.getAttribute('href'))!,
      );
      await page.mouse.up();
      await downloadRequest;
      await page.mouse.move(0, 0);
    } else {
      await page.mouse.move(0, 0);
      await page.mouse.up();
    }
    await expect
      .poll(() =>
        action.evaluate((element) => getComputedStyle(element).boxShadow),
      )
      .toBe(before);
  }
  // Establish keyboard modality with real Tab input without assuming Safari's
  // Tab-to-links preference. The actual link must show its focused appearance.
  await page.keyboard.press('Tab');
  await download.focus();
  await expect(download).toBeFocused();
  await expect(download).toHaveCSS('outline-style', 'solid');
  expect(
    await download.evaluate((element) =>
      parseFloat(getComputedStyle(element).outlineWidth),
    ),
  ).toBeGreaterThanOrEqual(2);
});

test('chapter polish: reduced motion preserves pressed contrast without moving actions', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('/en/#experience');
  await page.locator('[data-point-preset="center"]').click();
  for (const selector of [
    '[data-record]',
    '[data-reset]',
    '.download-package [data-download]',
  ]) {
    const action = page.locator(selector);
    await action.scrollIntoViewIfNeeded();
    await page.mouse.move(0, 0);
    const before = await action.evaluate(
      (element) => getComputedStyle(element).boxShadow,
    );
    const bounds = (await action.boundingBox())!;
    await page.mouse.move(
      bounds.x + bounds.width / 2,
      bounds.y + bounds.height / 2,
    );
    await page.mouse.down();
    await expect(action).toHaveCSS('transform', 'none');
    await expect
      .poll(() =>
        action.evaluate((element) => getComputedStyle(element).boxShadow),
      )
      .not.toBe(before);
    const durations = await action.evaluate((element) =>
      getComputedStyle(element).transitionDuration.split(',').map(parseFloat),
    );
    expect(durations.every((duration) => duration === 0)).toBe(true);
    await page.mouse.move(0, 0);
    await page.mouse.up();
  }
});

for (const locale of ['/', '/en/']) {
  test(`${locale}: no JavaScript keeps the unframed court and downloads visible`, async ({
    browser,
  }) => {
    const context = await browser.newContext({
      javaScriptEnabled: false,
      viewport: { width: 1440, height: 900 },
    });
    try {
      const page = await context.newPage();
      await page.goto(locale);
      const court = page.locator('[data-demo-court]');
      await court.scrollIntoViewIfNeeded();
      await expect(court).toBeVisible();
      await expect(court).toHaveCSS('opacity', '1');
      await expect(page.locator('.demo-map')).toHaveCSS(
        'background-color',
        'rgba(0, 0, 0, 0)',
      );
      await expect(
        page.locator('#download a[href*=".apk"]').first(),
      ).toHaveAttribute('href', /github\.com\/.*\.apk$/);
    } finally {
      await context.close();
    }
  });
}

test('enlarged English text reflows the score moments and shot actions by their content', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/en/#experience');
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(() => {
    const nodes = [...document.querySelectorAll<HTMLElement>('body *')].filter(
      (el) =>
        [...el.childNodes].some(
          (node) =>
            node.nodeType === Node.TEXT_NODE && node.textContent?.trim(),
        ),
    );
    const sizes = nodes.map(
      (el) => [el, parseFloat(getComputedStyle(el).fontSize)] as const,
    );
    for (const [el, size] of sizes) el.style.fontSize = `${size * 2}px`;
  });
  // Read both controls in one layout: native anchor scrolling can otherwise
  // move the viewport between two separate remote bounding-box requests.
  const actions = await page.evaluate(() => ({
    scoreBottom: document
      .querySelector('[data-record]')!
      .getBoundingClientRect().bottom,
    resetTop: document.querySelector('[data-reset]')!.getBoundingClientRect()
      .top,
  }));
  expect(actions.resetTop).toBeGreaterThanOrEqual(actions.scoreBottom);
  const second = page.locator('[data-replay-moment="tie"] strong');
  const width = await second.evaluate((el) => {
    const word = document.createRange();
    const node = el.firstChild!;
    word.setStart(node, 4);
    word.setEnd(node, 10);
    return {
      word: word.getBoundingClientRect().width,
      available: el.clientWidth,
    };
  });
  expect(width.available).toBeGreaterThanOrEqual(width.word);
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth - innerWidth,
    ),
  ).toBeLessThanOrEqual(1);
});

for (const locale of ['/', '/en/']) {
  test(`${locale}: language follows the visible chapter after manual scroll away from an old hash`, async ({
    page,
  }) => {
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.goto(`${locale}#download`);
    await page.evaluate(() => document.fonts.ready);
    await expect(page.locator('html')).toHaveAttribute(
      'data-chapter',
      'download',
    );
    // A real scroll gesture cancels a still-pending fragment navigation.
    await page.mouse.wheel(0, -1);
    await page.locator('#experience').evaluate((el) =>
      scrollTo({
        top: scrollY + el.getBoundingClientRect().top - 140,
        behavior: 'instant',
      }),
    );
    await expect(page.locator('html')).toHaveAttribute(
      'data-chapter',
      'experience',
    );
    await page.locator('[data-language]').click();
    await expect(page).toHaveURL(/#experience$/);
    await expect(page.locator('html')).toHaveAttribute(
      'data-chapter',
      'experience',
    );
  });
  test(`${locale}: keyboard skip reaches the start of the main content and skips navigation`, async ({
    page,
  }, testInfo) => {
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.goto(locale);
    // WebKit's platform default excludes links from plain Tab until full
    // keyboard access is enabled. Exercise the same activation/focus behavior.
    if (testInfo.project.name === 'webkit')
      await page.locator('.skip-link').focus();
    else await page.keyboard.press('Tab');
    await expect(page.locator('.skip-link')).toBeFocused();
    await page.keyboard.press('Enter');
    await expect(page.locator('main')).toBeFocused();
    await expect.poll(() => page.evaluate(() => scrollY)).toBeLessThan(2);
    if (testInfo.project.name !== 'webkit') {
      await page.keyboard.press('Tab');
      await expect(page.locator('.hero-actions [data-download]')).toBeFocused();
    }
  });

  test(`${locale}: short desktop reveals all scoring buttons without another scroll`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 1440, height: 900 });
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.goto(`${locale}#scoring`);
    await page.evaluate(() => document.fonts.ready);
    await expect
      .poll(() =>
        page
          .locator('[data-score-feature]')
          .evaluateAll((elements) =>
            Math.max(
              ...elements.map(
                (element) => element.getBoundingClientRect().bottom,
              ),
            ),
          ),
      )
      .toBeLessThanOrEqual(888);
    await expect(page.locator('[data-score-feature="0"]')).toHaveAttribute(
      'aria-pressed',
      'false',
    );
    await page.locator('[data-score-feature="0"]').click();
    await expect(page.locator('[data-story-device]')).toHaveAttribute(
      'data-score-playing',
      'true',
    );
  });

  test(`${locale}: fallback background leaves product screenshots clear beyond the hero`, async ({
    page,
  }) => {
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.goto(`${locale}#replay`);
    await expect(page.locator('html')).toHaveAttribute(
      'data-scene-fallback',
      /\S+/,
    );
    await expect
      .poll(() =>
        page
          .locator('.scene-background > .scene-poster')
          .evaluate((el) => getComputedStyle(el).opacity),
      )
      .toBe('0');
  });

  test(`${locale}: mobile header and privacy links retain 48px touch targets`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(locale);
    for (const locator of [
      page.locator('.site-header .nav-download'),
      page.locator('.footer-bottom a'),
    ]) {
      for (const link of await locator.all()) {
        const size = await link.evaluate((el) => ({
          w: el.getBoundingClientRect().width,
          h: el.getBoundingClientRect().height,
        }));
        expect(size.w).toBeGreaterThanOrEqual(48);
        expect(size.h).toBeGreaterThanOrEqual(48);
      }
    }
    await page.goto(locale === '/' ? '/privacy/' : '/en/privacy/');
    const language = await page.locator('.site-header .language').boundingBox();
    expect(language!.width).toBeGreaterThanOrEqual(48);
    expect(language!.height).toBeGreaterThanOrEqual(48);
  });
}
