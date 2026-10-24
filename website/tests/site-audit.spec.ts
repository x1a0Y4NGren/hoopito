import { createServer, request as proxyRequest } from 'node:http';
import { expect, test as base, type Page } from '@playwright/test';

const apk = '/downloads/v2.0.1/Hoopito-v2.0.1-android.apk';
const apkFilename = 'Hoopito-v2.0.1-android.apk';
const upstreamApk =
  'https://github.com/x1a0Y4NGren/hoopito/releases/download/v2.0.1/Hoopito-v2.0.1-android.apk';
const lanzouShare = 'https://wwbdc.lanzoub.com/ixNAU4d7x6kj';
const githubAttachment = '/__download-fixture__/github.apk';

const test = base.extend<{
  downloadServer: { origin: string; apkRequests: string[] };
}>({
  downloadServer: async ({ baseURL }, use) => {
    if (!baseURL) throw new Error('Download tests need the built site baseURL');
    const apkRequests: string[] = [];
    // Native downloads bypass Playwright routing in Chromium. Replace only the
    // public GitHub attachment href at the HTTP boundary; the dialog, scripts,
    // click handling and native download remain the real production behavior.
    const server = createServer((request, response) => {
      const target = new URL(request.url ?? '/', baseURL);
      if (target.pathname.endsWith('.apk')) {
        apkRequests.push(`${target.pathname}${target.search}`);
        if (![apk, githubAttachment].includes(target.pathname)) {
          response.writeHead(404).end();
          return;
        }
        response.writeHead(200, {
          'content-type': 'application/vnd.android.package-archive',
          'content-disposition': `attachment; filename="${apkFilename}"`,
          'cache-control': 'no-store',
        });
        response.end('Small native APK attachment fixture');
        return;
      }
      const upstream = proxyRequest(
        target,
        {
          method: request.method,
          // The fixture rewrites HTML below; request uncompressed bytes instead
          // of treating a compressed preview response as UTF-8 markup.
          headers: {
            ...request.headers,
            host: target.host,
            'accept-encoding': 'identity',
          },
        },
        (upstreamResponse) => {
          if (upstreamResponse.headers['content-type']?.includes('text/html')) {
            const chunks: Buffer[] = [];
            upstreamResponse.on('data', (chunk: Buffer) => chunks.push(chunk));
            upstreamResponse.on('end', () => {
              const html = Buffer.concat(chunks)
                .toString('utf8')
                .replaceAll(
                  `href="${upstreamApk}"`,
                  `href="${githubAttachment}"`,
                );
              const headers = { ...upstreamResponse.headers };
              delete headers['content-length'];
              delete headers['content-encoding'];
              response.writeHead(upstreamResponse.statusCode ?? 502, headers);
              response.end(html);
            });
            return;
          }
          response.writeHead(
            upstreamResponse.statusCode ?? 502,
            upstreamResponse.headers,
          );
          upstreamResponse.pipe(response);
        },
      );
      upstream.on('error', (error) => {
        if (response.headersSent) response.destroy(error);
        else response.writeHead(502).end('Built-site proxy failed');
      });
      request.pipe(upstream);
    });
    await new Promise<void>((resolve) =>
      server.listen(0, '127.0.0.1', resolve),
    );
    const address = server.address();
    if (!address || typeof address === 'string')
      throw new Error('Download fixture did not bind a local TCP port');
    try {
      await use({
        origin: `http://127.0.0.1:${address.port}`,
        apkRequests,
      });
    } finally {
      server.closeAllConnections();
      await new Promise<void>((resolve, reject) =>
        server.close((error) => (error ? reject(error) : resolve())),
      );
    }
  },
});

for (const locale of ['/', '/en/']) {
  for (const width of [390, 1440]) {
    for (const javaScriptEnabled of [true, false]) {
      test(`download chooser: ${locale} ${width}px JavaScript ${javaScriptEnabled ? 'enabled' : 'disabled'} preserves native GitHub downloads for mouse and Enter`, async ({
        browser,
        downloadServer,
      }) => {
        const context = await browser.newContext({
          baseURL: downloadServer.origin,
          acceptDownloads: true,
          javaScriptEnabled,
          reducedMotion: 'reduce',
          viewport: { width, height: 900 },
        });
        try {
          const page = await context.newPage();
          // This matrix verifies HTML dialogs and native attachments. Keep
          // software WebGL from dominating every assertion in WebKit; the
          // dedicated scene suite still exercises the real rendering lifecycle.
          await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
            route.abort(),
          );
          const githubRequests: string[] = [];
          const lanzouRequests: string[] = [];
          page.on('request', (request) => {
            const url = new URL(request.url());
            if (
              /(^|\.)(github\.com|githubusercontent\.com)$/.test(url.hostname)
            )
              githubRequests.push(request.url());
            if (url.hostname.endsWith('.lanzoub.com'))
              lanzouRequests.push(request.url());
          });
          // Safety net: no test should transfer the full public 77 MB APK.
          await page.route(
            /https:\/\/[^/]*(?:github\.com|githubusercontent\.com)\//,
            (route) => route.abort(),
          );
          await page.goto(locale);
          await page.waitForLoadState('networkidle');
          expect(
            downloadServer.apkRequests,
            'Initial load must not request or prefetch an APK',
          ).toEqual([]);
          expect(githubRequests).toEqual([]);
          expect(lanzouRequests).toEqual([]);
          await expect(page.locator('[data-download]')).toHaveCount(2);
          const initialUrl = page.url();
          for (const selector of [
            '.hero-actions [data-download]',
            '.download-package [data-download]',
          ]) {
            const action = page.locator(selector);
            await expect(action).toHaveAttribute('href', githubAttachment);
            await expect(action).toHaveAttribute('aria-haspopup', 'dialog');
            await expect(action).toHaveAttribute(
              'aria-controls',
              'download-dialog',
            );
            for (const activation of ['mouse', 'Enter']) {
              await action.scrollIntoViewIfNeeded();
              if (activation === 'Enter') await action.focus();
              let pendingDownload;
              const beforeRequests = downloadServer.apkRequests.length;
              const activate = async () => {
                if (activation === 'mouse') await action.click();
                else await page.keyboard.press('Enter');
              };
              if (javaScriptEnabled) {
                await activate();
                const dialog = page.locator('[data-download-dialog]');
                await expect(dialog).toBeVisible();
                await expect(dialog).toHaveAttribute('open', '');
                await expect(
                  page.locator('[data-download-close]'),
                ).toBeFocused();
                await expect(page).toHaveURL(initialUrl);
                expect(downloadServer.apkRequests).toHaveLength(beforeRequests);
                const github = page.locator('[data-download-channel="github"]');
                // Static content and touch targets belong to this one shared
                // dialog. Verify once per locale/viewport, while replaying all
                // invokers and input methods below without costly duplicate RPCs.
                if (beforeRequests === 0) {
                  await expect(dialog).toHaveAccessibleName(
                    locale === '/'
                      ? '选择下载渠道'
                      : 'Choose a download channel',
                  );
                  const lanzou = page.locator(
                    '[data-download-channel="lanzou"]',
                  );
                  await expect(lanzou).toBeEnabled();
                  await expect(lanzou).toHaveAttribute('href', lanzouShare);
                  await expect(lanzou).toContainText(
                    locale === '/'
                      ? '蓝奏云下载渠道（国内）'
                      : 'Lanzou download (China)',
                  );
                  await expect(
                    page.locator('[data-download-password]'),
                  ).toHaveText(
                    locale === '/' ? /密码：\s*gkyz/ : /Password:\s*gkyz/,
                  );
                  await expect(
                    page.locator('[data-download-channel="baidu"]'),
                  ).toHaveCount(0);
                  await expect(github).toHaveAttribute(
                    'href',
                    githubAttachment,
                  );
                  for (const control of [
                    github,
                    lanzou,
                    page.locator('[data-download-close]'),
                  ]) {
                    const bounds = (await control.boundingBox())!;
                    expect(bounds.width).toBeGreaterThanOrEqual(48);
                    expect(bounds.height).toBeGreaterThanOrEqual(48);
                  }
                }
                pendingDownload = page.waitForEvent('download');
                if (activation === 'mouse') await github.click();
                else {
                  await github.focus();
                  await page.keyboard.press('Enter');
                }
              } else {
                pendingDownload = page.waitForEvent('download');
                await activate();
              }
              const download = await pendingDownload;
              expect(download.url()).toBe(
                new URL(githubAttachment, initialUrl).href,
              );
              expect(download.suggestedFilename()).toBe(apkFilename);
              expect(await download.failure()).toBeNull();
              await expect(page).toHaveURL(initialUrl);
              if (javaScriptEnabled) {
                await expect(
                  page.locator('[data-download-dialog]'),
                ).not.toBeVisible();
                await expect(action).toBeFocused();
              }
              await download.delete();
            }
          }
          expect(downloadServer.apkRequests).toEqual(
            Array(4).fill(githubAttachment),
          );
          expect(
            githubRequests,
            'The HTTP attachment fixture must prevent real GitHub transfers',
          ).toEqual([]);
          expect(
            lanzouRequests,
            'GitHub downloads must not contact Lanzou',
          ).toEqual([]);
        } finally {
          await context.close();
        }
      });
    }
  }

  test(`download chooser: ${locale} lists Lanzou first with its visible password and keeps the original GitHub release`, async ({
    page,
  }) => {
    await page.goto(locale);
    for (const action of await page.locator('[data-download]').all()) {
      await expect(action).toHaveAttribute('href', upstreamApk);
      await expect(action).toHaveAttribute('aria-haspopup', 'dialog');
      await expect(action).toHaveAttribute('aria-controls', 'download-dialog');
    }
    await expect(
      page.locator('[data-download-channel="github"]'),
    ).toHaveAttribute('href', upstreamApk);
    const channels = page.locator('a[data-download-channel]');
    await expect(channels).toHaveCount(2);
    await expect(channels.nth(0)).toHaveAttribute(
      'data-download-channel',
      'lanzou',
    );
    await expect(channels.nth(1)).toHaveAttribute(
      'data-download-channel',
      'github',
    );
    await expect(channels.nth(0)).toContainText(
      locale === '/' ? '蓝奏云下载渠道（国内）' : 'Lanzou download (China)',
    );
    await expect(channels.nth(1)).toContainText(
      locale === '/'
        ? 'GitHub下载渠道（国外）'
        : 'GitHub download (international)',
    );
    await expect(channels.nth(0)).toHaveAttribute('href', lanzouShare);
    await expect(channels.nth(0)).toHaveAttribute(
      'aria-describedby',
      'download-lanzou-password',
    );
    const password = page.locator('p[data-download-password]');
    await expect(password).toHaveAttribute('id', 'download-lanzou-password');
    await expect(password).toHaveText(
      locale === '/' ? /密码：\s*gkyz/ : /Password:\s*gkyz/,
    );
    await expect(password.locator('code')).toHaveText('gkyz');
    await expect(page.locator('[data-download-channel="baidu"]')).toHaveCount(
      0,
    );
    await expect(page.locator('.download-fallback')).toHaveCount(0);
    await expect(
      page.locator('.download-links .release-link:not(.download-fallback)'),
    ).toHaveAttribute(
      'href',
      'https://github.com/x1a0Y4NGren/hoopito/releases/tag/v2.0.1',
    );
  });

  for (const width of [390, 1440]) {
    test(`download chooser: ${locale} ${width}px dismisses without navigation and restores its invoker`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await page.goto(locale);
      await page.evaluate(() => document.fonts.ready);
      const action = page.locator('.download-package [data-download]');
      const dialog = page.locator('[data-download-dialog]');
      const initialUrl = page.url();
      const downloads: string[] = [];
      page.on('download', (download) => downloads.push(download.url()));
      for (const dismissal of ['Escape', 'close', 'backdrop']) {
        await action.scrollIntoViewIfNeeded();
        await action.focus();
        const initialScroll = await page.evaluate(() => scrollY);
        await page.keyboard.press('Enter');
        await expect(dialog).toBeVisible();
        await expect(page.locator('[data-download-close]')).toBeFocused();
        // The two links follow their visible domestic/international order and
        // cycle back to close, including Safari's Tab-to-links preference.
        for (const channel of ['lanzou', 'github', 'close']) {
          await page.keyboard.press('Tab');
          await expect(
            page.locator(
              channel === 'close'
                ? '[data-download-close]'
                : `[data-download-channel="${channel}"]`,
            ),
          ).toBeFocused();
        }
        for (const channel of ['github', 'lanzou', 'close']) {
          await page.keyboard.press('Shift+Tab');
          await expect(
            page.locator(
              channel === 'close'
                ? '[data-download-close]'
                : `[data-download-channel="${channel}"]`,
            ),
          ).toBeFocused();
        }
        if (dismissal === 'Escape') await page.keyboard.press('Escape');
        else if (dismissal === 'close')
          await page.locator('[data-download-close]').click();
        else await page.mouse.click(2, 2);
        await expect(dialog).not.toBeVisible();
        await expect(action).toBeFocused();
        await expect(page).toHaveURL(initialUrl);
        expect(
          Math.abs((await page.evaluate(() => scrollY)) - initialScroll),
        ).toBeLessThanOrEqual(1);
        expect(downloads).toEqual([]);
      }
    });
  }

  test(`download chooser: ${locale} keeps every channel readable at 200 percent mobile text`, async ({
    page,
  }) => {
    await page.setViewportSize({ width: 390, height: 844 });
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(locale);
    await page.evaluate(() => document.fonts.ready);
    await page.evaluate(() => {
      const sizes = [...document.querySelectorAll<HTMLElement>('body *')].map(
        (element) =>
          [element, parseFloat(getComputedStyle(element).fontSize)] as const,
      );
      for (const [element, size] of sizes)
        element.style.fontSize = `${size * 2}px`;
    });
    await page.locator('.hero-actions [data-download]').click();
    const dialog = page.locator('[data-download-dialog]');
    await expect(dialog).toBeVisible();
    expect(
      await dialog.evaluate(
        (element) => element.scrollWidth - element.clientWidth,
      ),
    ).toBeLessThanOrEqual(1);
    for (const selector of [
      '[data-download-close]',
      '[data-download-channel="github"]',
      '[data-download-channel="lanzou"]',
      '[data-download-password]',
    ]) {
      const control = page.locator(selector);
      await control.scrollIntoViewIfNeeded();
      await expect(control).toBeInViewport();
      const bounds = (await control.boundingBox())!;
      expect(bounds.x).toBeGreaterThanOrEqual(0);
      expect(bounds.x + bounds.width).toBeLessThanOrEqual(391);
    }
    await page.keyboard.press('Escape');
    await expect(dialog).not.toBeVisible();
  });

  for (const width of [390, 1440]) {
    test(`download chooser: ${locale} ${width}px opens the exact Lanzou share without leaving the website`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
        route.abort(),
      );
      const shareRequests: string[] = [];
      await page.context().route(/^https:\/\/[^/]*lanzoub\.com\//, (route) => {
        if (route.request().isNavigationRequest())
          shareRequests.push(route.request().url());
        return route.fulfill({
          status: 200,
          contentType: 'text/html; charset=utf-8',
          body: '<h1>Controlled Lanzou share page</h1>',
        });
      });
      await page.goto(locale);
      await page.evaluate(() => document.fonts.ready);
      expect(
        shareRequests,
        'Browsing must not contact a download channel',
      ).toEqual([]);
      const initialUrl = page.url();
      for (const [selector, activation] of [
        ['.hero-actions [data-download]', 'mouse'],
        ['.download-package [data-download]', 'Enter'],
      ]) {
        const invoker = page.locator(selector);
        await invoker.scrollIntoViewIfNeeded();
        await invoker.click();
        const dialog = page.locator('[data-download-dialog]');
        const lanzou = page.locator('[data-download-channel="lanzou"]');
        await expect(dialog).toBeVisible();
        const password = page.locator('[data-download-password]');
        await expect(password).toBeVisible();
        const [lanzouBounds, passwordBounds, githubBounds] = await Promise.all([
          lanzou.boundingBox(),
          password.boundingBox(),
          page.locator('[data-download-channel="github"]').boundingBox(),
        ]);
        expect(passwordBounds!.y).toBeGreaterThanOrEqual(
          lanzouBounds!.y + lanzouBounds!.height,
        );
        expect(passwordBounds!.y + passwordBounds!.height).toBeLessThanOrEqual(
          githubBounds!.y,
        );
        const beforeShareRequests = shareRequests.length;
        await expect(page).toHaveURL(initialUrl);
        const popupOpened = page.waitForEvent('popup');
        if (activation === 'mouse') await lanzou.click();
        else {
          await lanzou.focus();
          await page.keyboard.press('Enter');
        }
        const popup = await popupOpened;
        await expect(popup).toHaveURL(lanzouShare);
        await expect(popup.locator('h1')).toHaveText(
          'Controlled Lanzou share page',
        );
        expect(shareRequests.slice(beforeShareRequests)).toEqual([lanzouShare]);
        await expect(dialog).not.toBeVisible();
        await expect(page).toHaveURL(initialUrl);
        await expect(invoker).toBeFocused();
        await popup.close();
      }
      expect(shareRequests).toEqual([lanzouShare, lanzouShare]);
    });
  }
}

test('download chooser: closing the chooser does not resume a shot while the page remains hidden', async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto('/');
  await page.locator('[data-point-preset="center"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    document.dispatchEvent(new Event('visibilitychange'));
    document
      .querySelector<HTMLAnchorElement>('.hero-actions [data-download]')!
      .click();
  });
  await expect(page.locator('[data-download-dialog]')).toBeVisible();
  await page.waitForTimeout(1800);
  await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
    'hidden',
    '',
  );
  await page.locator('[data-download-close]').click();
  await page.waitForTimeout(400);
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
  await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
    'hidden',
  );
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await page.locator('[data-reset]').click();
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
});

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
  const waitForLayout = () =>
    expect
      .poll(() =>
        page.evaluate(async () => {
          const measure = () => [
            scrollY,
            document.documentElement.scrollHeight,
            ...Array.from(
              document.querySelectorAll(
                '#download .section-top, .checksum summary, .upgrade summary, .faq details:first-child summary',
              ),
              (element) => {
                const { x, y, width, height } = element.getBoundingClientRect();
                return [x, y, width, height];
              },
            ),
          ];
          const before = measure();
          await new Promise(requestAnimationFrame);
          await new Promise(requestAnimationFrame);
          return JSON.stringify(before) === JSON.stringify(measure());
        }),
      )
      .toBe(true);
  // Cancel the settled fragment intent before text resizing can resume it
  // during Playwright's normal pointer-down/pointer-up on a native summary.
  await waitForLayout();
  await page.mouse.wheel(0, -1);
  try {
    await page.evaluate(() => {
      const pending = new Set(
        ['hero', 'experience', 'replay'].map((chapter) =>
          document.querySelector(`[data-story-stage="${chapter}"]`)!,
        ),
      );
      const probe = { done: false, stop: () => {} };
      const observer = new MutationObserver((records) => {
        for (const record of records) pending.delete(record.target as Element);
        probe.done = pending.size === 0;
      });
      for (const stage of pending)
        observer.observe(stage, {
          attributes: true,
          attributeFilter: ['data-story-start', 'data-story-end'],
        });
      probe.stop = () => observer.disconnect();
      Reflect.set(window, '__chapterTextRefreshProbe', probe);
      const nodes = [
        ...document.querySelectorAll<HTMLElement>('body *'),
      ].filter((element) =>
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
    // Observe actual range publication instead of reproducing GSAP geometry.
    await expect
      .poll(() =>
        page.evaluate(
          () => Reflect.get(window, '__chapterTextRefreshProbe').done,
        ),
      )
      .toBe(true);
    await waitForLayout();
  } finally {
    await page.evaluate(() => {
      Reflect.get(window, '__chapterTextRefreshProbe')?.stop();
      Reflect.deleteProperty(window, '__chapterTextRefreshProbe');
    });
  }
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
      await expect(
        page.locator('.download-package [data-download]'),
      ).toHaveAttribute('href', upstreamApk);
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
  downloadServer,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await page.goto(`${downloadServer.origin}/en/#experience`);
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
  for (const selector of [
    '[data-record]',
    '[data-reset]',
    '.download-package [data-download]',
  ]) {
    const action = page.locator(selector);
    await action.scrollIntoViewIfNeeded();
    await page.mouse.move(0, 0);
    // A busy renderer can still be interpolating after 240 ms of wall time.
    // Read the actual CSS transition lifecycle before taking the exact baseline.
    await expect
      .poll(() =>
        action.evaluate(async (element) => {
          const shadow = () => getComputedStyle(element).boxShadow;
          const transitioning = () =>
            element
              .getAnimations()
              .some(
                (animation) =>
                  animation instanceof CSSTransition &&
                  animation.transitionProperty === 'box-shadow' &&
                  (animation.pending || animation.playState === 'running'),
              );
          const before = shadow();
          if (transitioning()) return true;
          // WebKit can retire the transition before its computed style has
          // consumed the compositor's last interpolation. Require the style
          // itself to survive two native frames before capturing the baseline.
          await new Promise(requestAnimationFrame);
          await new Promise(requestAnimationFrame);
          return transitioning() || shadow() !== before;
        }),
      )
      .toBe(false);
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
      // drag even without site styles. Exercise the real click and dialog.
      const initialUrl = page.url();
      await page.mouse.up();
      await expect(page.locator('[data-download-dialog]')).toBeVisible();
      await page.locator('[data-download-close]').click();
      await expect(page).toHaveURL(initialUrl);
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
      await expect(page.locator('#download [data-download]')).toHaveAttribute(
        'href',
        upstreamApk,
      );
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
