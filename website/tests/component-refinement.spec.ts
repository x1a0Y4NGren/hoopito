import { expect, test } from '@playwright/test';

for (const locale of ['zh', 'en']) {
  for (const width of [390, 1024, 1440, 1920]) {
    test(`${locale} ${width}px component typography and controls remain readable`, async ({
      page,
    }) => {
      await page.setViewportSize({ width, height: 900 });
      await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
        route.abort(),
      );
      await page.emulateMedia({ reducedMotion: 'reduce' });
      await page.goto(locale === 'zh' ? '/' : '/en/');
      await page.evaluate(() => document.fonts.ready);
      const reading = await page.locator('main').evaluate((main) => {
        const captions = [
          ...main.querySelectorAll<HTMLElement>(
            '.fine-print, .feature-description, .viewer-link, .qr-block span, .checksum code, .score-center',
          ),
        ];
        const titles = [...main.querySelectorAll<HTMLElement>('h1, h2, h3')];
        const controls = [
          ...main.querySelectorAll<HTMLElement>(
            '.button, .score-feature, .point-presets button, .reset-button, .faq summary',
          ),
        ];
        return {
          small: captions
            .filter(
              (el) =>
                getComputedStyle(el).display !== 'none' &&
                parseFloat(getComputedStyle(el).fontSize) < 14,
            )
            .map((el) => el.className),
          clipped: titles
            .filter((el) => el.scrollWidth > el.clientWidth + 1)
            .map((el) => el.textContent),
          smallTargets: controls
            .filter((el) => el.getBoundingClientRect().height < 47.9)
            .map((el) => el.textContent),
          overflow: Math.max(
            0,
            document.documentElement.scrollWidth - innerWidth,
          ),
        };
      });
      expect(reading).toEqual({
        small: [],
        clipped: [],
        smallTargets: [],
        overflow: 0,
      });
      expect(
        await page
          .locator('.footer-bottom small')
          .evaluate((copyright) =>
            parseFloat(getComputedStyle(copyright).fontSize),
          ),
      ).toBeGreaterThanOrEqual(12);
      await page.locator('.faq details').first().locator('summary').click();
      await expect(page.locator('.faq details').first()).toHaveAttribute(
        'open',
        '',
      );
      await expect(
        page.locator('.faq details').first().locator('p'),
      ).toBeVisible();
    });
  }
}

test('density CSS fallback removes backdrop copies without requiring a transparency preference', async ({
  page,
}) => {
  await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
    route.abort(),
  );
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-scene', '2d');
  const result = await page
    .locator('[data-glass-card]')
    .first()
    .evaluate((card) => {
      const root = document.documentElement;
      // The production CSS optimizer may retain only the Safari spelling.
      const backdrop = () => {
        const style = getComputedStyle(card);
        return (
          style.getPropertyValue('-webkit-backdrop-filter') ||
          style.backdropFilter
        );
      };
      root.dataset.glass = 'css';
      root.dataset.quality = 'full';
      const full = backdrop();
      root.dataset.quality = 'density';
      const density = backdrop();
      root.dataset.quality = 'full';
      return { full, density, restored: backdrop() };
    });
  expect(result.full).toContain('blur(');
  expect(result.density).toBe('none');
  expect(result.restored).toBe(result.full);
});

for (const locale of ['zh', 'en']) {
  test(`${locale}: display font stays on poster headings while real dialogs retain their complete text font`, async ({
    page,
  }) => {
    await page.route(/court-(?:scene|engine)[^/]*\.js$/, (route) =>
      route.abort(),
    );
    await page.emulateMedia({ reducedMotion: 'reduce' });
    await page.goto(locale === 'zh' ? '/' : '/en/');
    await page.evaluate(() => document.fonts.ready);
    const hero = page.locator('#hero h1');
    await expect(hero).toHaveCSS(
      'font-weight',
      locale === 'zh' ? '900' : '700',
    );
    const family = (selector: string) =>
      page
        .locator(selector)
        .evaluate((title) => getComputedStyle(title).fontFamily);

    await page.locator('.hero-actions [data-download]').click();
    await expect(page.locator('[data-download-dialog]')).toBeVisible();
    expect(await family('#download-dialog-title')).not.toContain('NotoPoster');
    await expect(page.locator('#download-dialog-title')).toHaveText(
      locale === 'zh' ? '选择下载渠道' : 'Choose a download channel',
    );
    await page.locator('[data-download-close]').click();

    await page.locator('.scoring-display .viewer-link').click();
    await expect(page.locator('[data-viewer]')).toBeVisible();
    expect(await family('[data-viewer-title]')).not.toContain('NotoPoster');
    await expect(page.locator('[data-viewer-title]')).not.toBeEmpty();
    await page.locator('[data-viewer-close]').click();
    await expect(hero).toHaveCSS(
      'font-weight',
      locale === 'zh' ? '900' : '700',
    );
    if (locale === 'zh')
      expect(await family('#hero h1')).toContain('NotoPoster');
  });
}
