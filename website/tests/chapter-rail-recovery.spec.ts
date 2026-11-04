import { expect, test } from '@playwright/test';

test('native scroll anchoring cannot move the application-owned story position', async ({
  page,
}, testInfo) => {
  await page.route(/Landing\.[^/]*\.js(?:\?|$)/, (route) => route.abort());
  await page.goto('/');
  const styles = await page
    .locator('link[rel="stylesheet"]')
    .evaluateAll((links) => links.map((link) => link.outerHTML).join(''));
  const measure = async (privacy: boolean, managed = true) => {
    // Reuse the shipped stylesheet without the scroll controller. The only
    // anchor is real visible content; growing its preceding sibling exercises
    // native anchoring, independently of JS scrollTo or GSAP's pin handling.
    await page.setContent(`<!doctype html><html ${managed ? 'data-scroll-state="idle"' : ''}><head>${styles}</head>
      <body class="${privacy ? 'privacy-page' : 'zh'}"
        style="margin:0;padding:0;max-width:none;display:block">
        <div id="preceding" style="height:1800px;overflow-anchor:none"></div>
        <div style="height:400px">Visible reading anchor</div>
        <div style="height:6000px;overflow-anchor:none"></div>
      </body></html>`);
    await page.evaluate(async () => {
      scrollTo({ top: 1800, behavior: 'instant' });
      for (let frame = 0; frame < 3; frame++)
        await new Promise(requestAnimationFrame);
    });
    const before = await page.evaluate(() => scrollY);
    await page.evaluate(async () => {
      document.getElementById('preceding')!.style.height = '2040px';
      for (let frame = 0; frame < 3; frame++)
        await new Promise(requestAnimationFrame);
    });
    return { before, after: await page.evaluate(() => scrollY) };
  };
  const native = await measure(true);
  test.skip(
    Math.abs(native.after - native.before - 240) > 2,
    'This engine/port has no active native scroll anchoring; control verified.',
  );
  const story = await measure(false);
  const naturalFallback = await measure(false, false);
  await testInfo.attach('native-anchor-control-and-story', {
    body: JSON.stringify({ native, story, naturalFallback }),
    contentType: 'application/json',
  });
  expect(Math.abs(story.after - story.before)).toBeLessThanOrEqual(2);
  expect(
    Math.abs(naturalFallback.after - naturalFallback.before - 240),
  ).toBeLessThanOrEqual(2);
});

test('a held rail pointer releases on background suspension and restores a readable landing', async ({
  page,
}) => {
  await page.route(/court-(?:scene|engine)[^/]*\.(?:js|ts)(?:\?|$)/, (r) =>
    r.abort(),
  );
  await page.goto('/');
  await page.evaluate(() => document.fonts.ready);
  await expect(page.locator('html')).toHaveAttribute(
    'data-chapter-rail',
    'ready',
  );
  await page.waitForTimeout(300);
  const thumb = await page.locator('[data-rail-thumb]').boundingBox();
  const track = await page.locator('[data-rail-track]').boundingBox();
  await page.mouse.move(thumb!.x + 24, thumb!.y + 24);
  await page.mouse.down();
  await page.mouse.move(
    track!.x + 28,
    track!.y + 24 + (track!.height - 48) * 0.43,
    { steps: 10 },
  );
  await expect(page.locator('aside[data-chapter-rail]')).toHaveAttribute(
    'data-state',
    'dragging',
  );
  // Deterministic lifecycle injection checks suspension ownership separately
  // from actual OS/background presentation, which this test does not claim.
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: true,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await page.mouse.up();
  await expect(page.locator('aside[data-chapter-rail]')).toHaveJSProperty(
    'inert',
    true,
  );
  await page.evaluate(() => {
    Object.defineProperty(document, 'hidden', {
      configurable: true,
      value: false,
    });
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'idle',
  );
  await expect
    .poll(() =>
      page.evaluate(() => {
        const stops = [
          ...document.querySelectorAll<HTMLElement>(
            '[data-story-stage], #closing',
          ),
        ];
        return stops.some(
          (el) =>
            scrollY >= Number(el.dataset.scrollReadStart) - 2 &&
            scrollY <= Number(el.dataset.scrollReadEnd) + 2,
        );
      }),
    )
    .toBe(true);
  await expect(page.locator('aside[data-chapter-rail]')).toHaveJSProperty(
    'inert',
    false,
  );
  await page.locator('[data-rail-node="download"]').focus();
  await page.keyboard.press('Enter');
  await expect(page.locator('[data-rail-node="download"]')).toHaveAttribute(
    'aria-current',
    'location',
  );
});
