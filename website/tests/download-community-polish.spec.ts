import { expect, test, type Locator, type Page } from '@playwright/test';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { release } from '../src/data/release';
import { community } from '../src/data/community';

const sceneChunk = /court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/;

async function textBoxes(targets: Locator) {
  return targets.evaluateAll((elements) =>
    elements.map((element) => {
      const box = element.getBoundingClientRect();
      const ink = document.createRange();
      ink.selectNodeContents(element);
      const lines = [...ink.getClientRects()].filter(
        (line) => line.width > 0 && line.height > 0,
      );
      const clipping: string[] = [];
      for (const line of lines) {
        if (
          line.left < box.left - 1 ||
          line.right > box.right + 1 ||
          line.top < box.top - 1 ||
          line.bottom > box.bottom + 1
        )
          clipping.push('text box');
        for (
          let parent = element.parentElement;
          parent && parent !== document.body;
          parent = parent.parentElement
        ) {
          const style = getComputedStyle(parent),
            bounds = parent.getBoundingClientRect();
          if (
            (/^(hidden|clip)$/.test(style.overflowX) &&
              (line.left < bounds.left - 1 || line.right > bounds.right + 1)) ||
            (/^(hidden|clip)$/.test(style.overflowY) &&
              (line.top < bounds.top - 1 || line.bottom > bounds.bottom + 1))
          )
            clipping.push(parent.className || parent.tagName);
        }
      }
      return {
        text: element.textContent?.trim(),
        size: parseFloat(getComputedStyle(element).fontSize),
        clipped: clipping.length > 0,
        clipping,
        box: {
          left: box.left,
          top: box.top,
          right: box.right,
          bottom: box.bottom,
        },
        lines: lines.map((line) => ({
          left: line.left,
          top: line.top,
          right: line.right,
          bottom: line.bottom,
        })),
      };
    }),
  );
}

async function stableLayout(page: Page) {
  let previous = '';
  let stableSince = 0;
  await expect
    .poll(async () => {
      const key = await page.evaluate(() =>
        JSON.stringify([
          document.fonts.status,
          document.documentElement.scrollHeight,
          ...[
            ...document.querySelectorAll<HTMLElement>(
              '[data-story-stage], #closing',
            ),
          ].map((stage) => [
            stage.dataset.scrollReadStart,
            stage.dataset.scrollReadEnd,
            stage.offsetWidth,
            stage.offsetHeight,
          ]),
        ]),
      );
      if (key !== previous) stableSince = Date.now();
      previous = key;
      return Date.now() - stableSince;
    })
    .toBeGreaterThanOrEqual(250);
}

async function open(page: Page, path = '/#download') {
  await page.route(sceneChunk, (route) => route.abort());
  await page.goto(path);
  await page.evaluate(async () => {
    await document.fonts.ready;
    await Promise.all(
      [
        ...document.querySelectorAll<HTMLImageElement>(
          '#download img, #community img',
        ),
      ].map((image) => {
        image.loading = 'eager';
        return image.decode();
      }),
    );
  });
  await expect(page.locator('#closing')).toHaveAttribute(
    'data-scroll-read-start',
    /\d/,
  );
  await stableLayout(page);
}

async function range(page: Page, id: string) {
  return page
    .locator(id === 'closing' ? '#closing' : `[data-story-stage="${id}"]`)
    .evaluate((el) => ({
      start: Number((el as HTMLElement).dataset.scrollReadStart),
      end: Number((el as HTMLElement).dataset.scrollReadEnd),
    }));
}

async function atReading(page: Page, id: string) {
  await expect(page.locator('html')).toHaveAttribute('data-scroll-stop', id);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  const bounds = await range(page, id);
  const top = await page.evaluate(() => scrollY);
  expect(top).toBeGreaterThanOrEqual(bounds.start - 2);
  expect(top).toBeLessThanOrEqual(bounds.end + 2);
}

async function seek(page: Page, id: string, edge: 'start' | 'end' = 'start') {
  await page.mouse.click(8, 450);
  await stableLayout(page);
  const bounds = await range(page, id);
  await page.evaluate(async (top) => {
    scrollTo({ top, behavior: 'instant' });
    await new Promise(requestAnimationFrame);
    await new Promise(requestAnimationFrame);
  }, bounds[edge]);
  await atReading(page, id);
}

const layouts = [
  { name: 'compact desktop', width: 1024, height: 768 },
  { name: 'desktop', width: 1440, height: 900 },
  { name: 'wide desktop', width: 1920, height: 1080 },
  { name: 'mobile', width: 390, height: 844 },
  { name: 'short desktop', width: 1440, height: 640 },
  { name: 'fractional DPR', width: 1413, height: 871, dpr: 1.5 },
  { name: '200 percent text', width: 1024, height: 640, largeText: true },
];

for (const path of ['/', '/en/']) {
  for (const layout of layouts) {
    test.describe(`${path}: download community polish ${layout.name}`, () => {
      test.use({
        viewport: { width: layout.width, height: layout.height },
        deviceScaleFactor: layout.dpr ?? 1,
      });
      test('keeps open headings local reading protection and complete action content', async ({
        page,
      }, info) => {
        await page.emulateMedia({ reducedMotion: 'reduce' });
        await open(page, `${path}#download`);
        if (layout.largeText) {
          await page.addStyleTag({ content: 'html{font-size:200%!important}' });
          await stableLayout(page);
        }
        const metrics = await page.evaluate(() => {
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
          const backdrop = (selector: string) =>
            getComputedStyle(document.querySelector(selector)!, '::before')
              .content;
          const actions = document.querySelector('.community-actions');
          const note = document.querySelector('.community-note')!;
          const save = document.querySelector('[data-community-save]')!;
          const number = document.querySelector('[data-community-number]')!;
          const version = document.querySelector('.version-line')!;
          const install = document.querySelector('.install-note')!;
          const versionChildren = [...version.children];
          const lineCount = (element: Element) => {
            const range = document.createRange();
            range.selectNodeContents(element);
            return [...range.getClientRects()].filter(
              (line) => line.width > 0 && line.height > 0,
            ).length;
          };
          const beforeBaseline = versionChildren.map((el) => ({
            ...rect(el),
            lines: lineCount(el),
          }));
          // A zero-size inline block sits on the text baseline. Differently
          // sized font line boxes can have different bottoms on that same line.
          const markers = versionChildren.map((el) => {
            const marker = document.createElement('span');
            marker.style.cssText =
              'display:inline-block;width:0;height:0;margin:0;padding:0;border:0;vertical-align:baseline;line-height:0;font-size:0';
            el.append(marker);
            return marker;
          });
          const baselines = markers.map((el) => el.getBoundingClientRect().top);
          const duringBaseline = versionChildren.map((el) => ({
            ...rect(el),
            lines: lineCount(el),
          }));
          markers.forEach((el) => el.remove());
          const afterBaseline = versionChildren.map((el) => ({
            ...rect(el),
            lines: lineCount(el),
          }));
          return {
            overflow: document.documentElement.scrollWidth - innerWidth,
            dpr: devicePixelRatio,
            scrims: [
              '.download-invitation',
              '.community-heading',
              '.community-copy',
            ].map(backdrop),
            local: [
              '.download-lead',
              '.community-description',
              '.community-instructions',
              '.community-note',
            ].map(backdrop),
            secondTitle: parseFloat(
              getComputedStyle(
                document.querySelector(
                  '.community-heading [data-story-line] + [data-story-line]',
                )!,
              ).fontSize,
            ),
            version: [...version.children].map((el) => ({
              ...rect(el),
              size: parseFloat(getComputedStyle(el).fontSize),
            })),
            baselineProof: {
              baselines,
              before: beforeBaseline,
              during: duringBaseline,
              after: afterBaseline,
            },
            install: {
              text: install.textContent,
              whiteSpace: getComputedStyle(install).whiteSpace,
              size: parseFloat(getComputedStyle(install).fontSize),
              ...rect(install),
            },
            number: {
              text: number.textContent?.trim(),
              select: getComputedStyle(number).userSelect,
              clipped: number.scrollWidth > number.clientWidth + 1,
              ...rect(number),
            },
            actions: {
              exists: !!actions,
              actor: actions?.hasAttribute('data-story-item'),
              children: actions
                ? [...actions.children].map((el) =>
                    el.getAttribute('data-story-item'),
                  )
                : [],
              sameParent: note.parentElement === save.parentElement,
              noteAfterSave: !!(
                save.compareDocumentPosition(note) &
                Node.DOCUMENT_POSITION_FOLLOWING
              ),
            },
            note: {
              size: parseFloat(getComputedStyle(note).fontSize),
              ...rect(note),
            },
            save: rect(save),
            open: document.querySelector('.community-open')
              ? rect(document.querySelector('.community-open')!)
              : null,
          };
        });
        // Feathered reading pseudo-elements extend scrollHeight by 16px.
        // Measure real text lines and clipping ancestors rather than that fill.
        const text = await textBoxes(
          page.locator(
            '#download .install-note, #download .package-meta, .community-description, .community-instructions, .community-note, .community-artwork figcaption',
          ),
        );
        await info.attach('download-community-layout', {
          body: JSON.stringify({ ...metrics, text }, null, 2),
          contentType: 'application/json',
        });
        expect(metrics.overflow).toBeLessThanOrEqual(1);
        expect(metrics.dpr).toBe(layout.dpr ?? 1);
        expect(metrics.scrims).toEqual(['none', 'none', 'none']);
        for (const backdrop of metrics.local) expect(backdrop).toBe('""');
        await expect(page.locator('.download-brand')).toHaveCount(0);
        await expect(page.locator('.download-sigil')).toHaveCount(1);
        await expect(page.locator('#download [data-glass-card]')).toHaveCount(
          1,
        );
        await expect(page.locator('#community [data-glass-card]')).toHaveCount(
          1,
        );
        expect(metrics.install.whiteSpace).toBe('pre-line');
        expect(metrics.install.text).toContain(release.version);
        expect(metrics.install.text).toContain('2.0.0');
        expect(metrics.install.text).toMatch(
          path === '/'
            ? /允许.*来源.*安装/
            : /allow installation from this source/i,
        );
        expect(metrics.install.text).toMatch(
          path === '/' ? /保留数据和设置/ : /keep your data and settings/i,
        );
        expect(metrics.number.text).toBe('1129560287');
        expect(metrics.number.select).not.toBe('none');
        expect(metrics.number.clipped).toBe(false);
        expect(metrics.actions).toEqual({
          exists: true,
          actor: false,
          children: ['control', 'detail'],
          sameParent: true,
          noteAfterSave: true,
        });
        expect(metrics.note.y).toBeGreaterThanOrEqual(metrics.save.bottom);
        expect(metrics.save.width).toBeGreaterThanOrEqual(48);
        expect(metrics.save.height).toBeGreaterThanOrEqual(48);
        expect(metrics.open).not.toBeNull();
        expect(metrics.open!.width).toBeGreaterThanOrEqual(48);
        expect(metrics.open!.height).toBeGreaterThanOrEqual(48);
        for (const item of text) {
          expect(item.size, item.text).toBeGreaterThanOrEqual(14);
          expect(
            item.clipped,
            `${item.text}: ${item.clipping.join(', ')}`,
          ).toBe(false);
        }
        if (!layout.largeText) {
          expect(metrics.secondTitle).toBeGreaterThanOrEqual(32);
          expect(metrics.secondTitle).toBeLessThanOrEqual(
            layout.width < 1024 ? 44 : 42,
          );
          expect(metrics.baselineProof.before).toEqual(
            metrics.baselineProof.during,
          );
          expect(metrics.baselineProof.before).toEqual(
            metrics.baselineProof.after,
          );
          expect(
            Math.abs(
              metrics.baselineProof.baselines[0] -
                metrics.baselineProof.baselines[1],
            ),
          ).toBeLessThanOrEqual(1);
        }
        await expect(page.locator('.community-note')).toContainText(
          path === '/' ? '自愿' : /optional/i,
        );
        await expect(page.locator('.community-note')).toContainText(
          path === '/' ? '离线' : /offline/i,
        );
      });
    });
  }

  test(`${path}: download chooser preserves keyboard ownership channels and release facts without downloading an APK`, async ({
    page,
  }) => {
    const external: string[] = [];
    const downloads: string[] = [];
    page.on('request', (request) => {
      if (
        /^https?:/.test(request.url()) &&
        new URL(request.url()).origin !== 'http://127.0.0.1:4321'
      )
        external.push(request.url());
    });
    page.on('download', (download) =>
      downloads.push(download.suggestedFilename()),
    );
    await open(page, `${path}#download`);
    await atReading(page, 'download');
    const opener = page.locator('.download-package [data-download]');
    await expect(opener).toHaveAttribute('href', release.upstreamApkUrl);
    await opener.focus();
    await page.keyboard.press('Enter');
    const dialog = page.locator('[data-download-dialog]');
    await expect(dialog).toBeVisible();
    await expect(dialog.locator('[data-download-close]')).toBeFocused();
    await expect(dialog).toContainText(release.version);
    await expect(dialog).toContainText(release.minimumAndroid);
    await expect(dialog.locator('[data-download-channel]')).toHaveCount(2);
    await expect(
      dialog.locator('[data-download-channel="lanzou"]'),
    ).toHaveAttribute('href', release.lanzouUrl);
    await expect(
      dialog.locator('[data-download-channel="github"]'),
    ).toHaveAttribute('href', release.upstreamApkUrl);
    await expect(dialog.locator('[data-download-password] code')).toHaveText(
      release.lanzouPassword,
    );
    for (let index = 0; index < 5; index++) {
      await page.keyboard.press('Tab');
      expect(
        await dialog.evaluate((el) => el.contains(document.activeElement)),
      ).toBe(true);
    }
    const top = await page.evaluate(() => scrollY);
    await page.mouse.wheel(0, -120);
    expect(
      Math.abs((await page.evaluate(() => scrollY)) - top),
    ).toBeLessThanOrEqual(2);
    await page.keyboard.press('Escape');
    await expect(dialog).not.toBeVisible();
    await expect(opener).toBeFocused();
    await atReading(page, 'download');
    expect(external).toEqual([]);
    expect(downloads).toEqual([]);
  });

  test(`${path}: release disclosures retain complete backup facts use a 160ms content fade and expand the real reading range`, async ({
    page,
  }, info) => {
    await page.setViewportSize({ width: 1440, height: 640 });
    await open(page, `${path}#download`);
    await page.addStyleTag({ content: 'html{font-size:200%!important}' });
    await stableLayout(page);
    const collapsed = await range(page, 'download');
    const motions = [];
    for (const [selector, bodySelector] of [
      ['.checksum', 'code'],
      ['.upgrade', 'p'],
    ]) {
      const details = page.locator(selector);
      await details.locator('summary').focus();
      await page.keyboard.press('Enter');
      await expect(details).toHaveAttribute('open', '');
      const body = details.locator(bodySelector);
      const motion = await body.evaluate((el) => {
        const style = getComputedStyle(el);
        return {
          name: style.animationName,
          duration: style.animationDuration,
          height: el.getBoundingClientRect().height,
          content: el.scrollHeight,
          client: el.clientHeight,
        };
      });
      expect(motion.name).toBe('download-detail-reveal');
      expect(motion.duration).toBe('0.16s');
      expect(motion.height).toBeGreaterThan(0);
      await expect(body).toHaveCSS('opacity', '1');
      const ink = await textBoxes(body);
      expect(
        ink[0].clipped,
        `${ink[0].text}: ${ink[0].clipping.join(', ')}`,
      ).toBe(false);
      motions.push({ ...motion, ink });
    }
    await stableLayout(page);
    const expanded = await range(page, 'download');
    expect(expanded.end - expanded.start).toBeGreaterThan(
      collapsed.end - collapsed.start,
    );
    await expect(page.locator('.checksum code')).toHaveText(release.sha256);
    const backup = page.locator('.upgrade > p');
    for (const fact of path === '/'
      ? [
          /新.*签名/,
          /不能覆盖.*v1/,
          /JSON.*App.*之外/,
          /确认.*保存/,
          /卸载旧版/,
          /恢复/,
          /CSV.*图片.*不能.*完整恢复/,
        ]
      : [
          /new signing certificate/i,
          /cannot install over.*v1/i,
          /JSON.*outside the app/i,
          /confirm.*saved/i,
          /uninstalling v1/i,
          /restore your JSON/i,
          /CSV and images cannot restore your full data/i,
        ])
      await expect(backup).toContainText(fact);
    await backup.scrollIntoViewIfNeeded();
    await expect(backup).toBeInViewport();
    await expect(page.locator('html')).toHaveAttribute(
      'data-scroll-stop',
      'download',
    );
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await stableLayout(page);
    for (const selector of ['.checksum', '.upgrade']) {
      const summary = page.locator(`${selector} summary`);
      await summary.focus();
      await page.keyboard.press('Enter');
      await expect(page.locator(selector)).not.toHaveAttribute('open', '');
      await page.keyboard.press('Enter');
      await expect(page.locator(`${selector} > :last-child`)).toHaveCSS(
        'animation-name',
        'none',
      );
    }
    await info.attach('download-disclosure-reading-ranges', {
      body: JSON.stringify({ collapsed, expanded, motions }, null, 2),
      contentType: 'application/json',
    });
  });

  test(`${path}: community exposes the same full PNG through keyboard viewing and a real local save`, async ({
    page,
    context,
  }, info) => {
    const external: string[] = [];
    context.on('request', (request) => {
      if (
        /^https?:/.test(request.url()) &&
        new URL(request.url()).origin !== 'http://127.0.0.1:4321'
      )
        external.push(request.url());
    });
    await open(page, `${path}#community`);
    await atReading(page, 'community');
    const source = await page.request.get(community.posterDownload);
    expect(source.ok()).toBe(true);
    expect(source.headers()['content-type']).toContain('image/png');
    const png = await source.body();
    expect(png.subarray(0, 8).toString('hex')).toBe('89504e470d0a1a0a');
    const width = png.readUInt32BE(16),
      height = png.readUInt32BE(20);
    expect(width).toBeGreaterThanOrEqual(community.imageWidth);
    expect(height).toBeGreaterThanOrEqual(community.imageHeight);
    const openLink = page.locator('.community-open');
    const save = page.locator('[data-community-save]');
    await expect(openLink).toHaveAttribute('href', community.posterDownload);
    await expect(page.locator('.community-poster-link')).toHaveAttribute(
      'href',
      community.posterDownload,
    );
    await expect(save).toHaveAttribute('href', community.posterDownload);
    await openLink.focus();
    const popupPromise = context.waitForEvent('page');
    await page.keyboard.press('Enter');
    const popup = await popupPromise;
    await expect(popup).toHaveURL(
      new URL(community.posterDownload, page.url()).href,
    );
    await expect(popup.locator('img')).toHaveJSProperty('naturalWidth', width);
    await expect(popup.locator('img')).toHaveJSProperty(
      'naturalHeight',
      height,
    );
    await popup.close();
    await page.bringToFront();
    await expect(openLink).toBeFocused();
    await save.focus();
    const downloadPromise = page.waitForEvent('download');
    await page.keyboard.press('Enter');
    const download = await downloadPromise;
    expect(download.suggestedFilename()).toBe('Hoopito-QQ-1129560287.png');
    const output = info.outputPath('Hoopito-QQ-1129560287.png');
    await download.saveAs(output);
    const saved = await readFile(output);
    expect(createHash('sha256').update(saved).digest('hex')).toBe(
      createHash('sha256').update(png).digest('hex'),
    );
    expect(external).toEqual([]);
    await info.attach('community-full-png-source', {
      body: JSON.stringify(
        {
          width,
          height,
          bytes: png.length,
          sha256: createHash('sha256').update(png).digest('hex'),
        },
        null,
        2,
      ),
      contentType: 'application/json',
    });
  });
}

test('native download and community chapters keep 23px return and fixed-pointer reverse navigation through closing', async ({
  page,
}, info) => {
  test.setTimeout(60_000);
  await page.setViewportSize({ width: 1920, height: 1200 });
  await open(page, '/#replay');
  await seek(page, 'replay', 'end');
  await page.mouse.move(20, 450);
  await page.mouse.wheel(0, 24);
  await atReading(page, 'download');
  const downloadBox = (await page.locator('.download-package').boundingBox())!;
  await page.mouse.move(downloadBox.x + 30, downloadBox.y + 30);
  const start = await page.evaluate(() => scrollY);
  await page.mouse.wheel(0, 23);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'tracking',
  );
  await atReading(page, 'download');
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - start),
  ).toBeLessThanOrEqual(2);
  const checkpoints = [];
  for (const [delta, id] of [
    [24, 'community'],
    [24, 'closing'],
    [-24, 'community'],
  ] as const) {
    await page.mouse.wheel(0, delta);
    await atReading(page, id);
    checkpoints.push({ delta, id, y: await page.evaluate(() => scrollY) });
  }
  const saveBox = (await page.locator('[data-community-save]').boundingBox())!;
  const pointer = { x: saveBox.x + 30, y: saveBox.y + 24 };
  await page.mouse.move(pointer.x, pointer.y);
  for (const id of ['download', 'replay']) {
    await page.mouse.wheel(0, -24);
    await atReading(page, id);
    checkpoints.push({ delta: -24, id, y: await page.evaluate(() => scrollY) });
  }
  await info.attach('download-community-native-stops', {
    body: JSON.stringify({ pointer, start, checkpoints }, null, 2),
    contentType: 'application/json',
  });
});

test('expanded large-text download content scrolls to its real reading boundary before a fresh gesture changes chapters', async ({
  page,
}, info) => {
  test.setTimeout(60_000);
  await page.setViewportSize({ width: 1440, height: 640 });
  await open(page);
  await page.addStyleTag({ content: 'html{font-size:200%!important}' });
  await stableLayout(page);
  for (const selector of ['.checksum', '.upgrade']) {
    await page.locator(`${selector} summary`).focus();
    await page.keyboard.press('Enter');
    await expect(page.locator(selector)).toHaveAttribute('open', '');
  }
  await stableLayout(page);
  const bounds = await range(page, 'download');
  expect(bounds.end - bounds.start).toBeGreaterThan(240);
  await seek(page, 'download');
  await page.mouse.move(20, 450);
  await page.mouse.wheel(0, 120);
  await expect
    .poll(() => page.evaluate(() => scrollY))
    .toBeGreaterThan(bounds.start + 2);
  expect(await page.evaluate(() => scrollY)).toBeLessThan(bounds.end - 2);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'download',
  );
  await page.mouse.wheel(0, 10000);
  await atReading(page, 'download');
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - bounds.end),
  ).toBeLessThanOrEqual(2);
  await page.mouse.wheel(0, 24);
  await atReading(page, 'community');
  await page.mouse.wheel(0, -24);
  await atReading(page, 'download');
  expect(
    Math.abs((await page.evaluate(() => scrollY)) - bounds.end),
  ).toBeLessThanOrEqual(2);
  await page.mouse.wheel(0, -120);
  await expect
    .poll(() => page.evaluate(() => scrollY))
    .toBeLessThan(bounds.end - 2);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    'download',
  );
  await expect(page.locator('.checksum')).toHaveAttribute('open', '');
  await expect(page.locator('.upgrade')).toHaveAttribute('open', '');
  await info.attach('expanded-download-native-reading', {
    body: JSON.stringify(bounds, null, 2),
    contentType: 'application/json',
  });
});
