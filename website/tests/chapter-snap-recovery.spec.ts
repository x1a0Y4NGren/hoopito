import { expect, test, type Page, type TestInfo } from '@playwright/test';

type Stop =
  'hero' | 'scoring' | 'experience' | 'replay' | 'download' | 'community';
const selector = (id: Stop) => `[data-story-stage="${id}"]`;
const sceneChunk = /court-scene[^/]*\.(?:js|ts)(?:\?|$)/;

async function range(page: Page, id: Stop) {
  const stage = page.locator(selector(id));
  await expect(stage).toHaveAttribute('data-scroll-read-start', /\d/);
  return stage.evaluate((element) => ({
    start: Number((element as HTMLElement).dataset.scrollReadStart),
    end: Number((element as HTMLElement).dataset.scrollReadEnd),
  }));
}

async function boundaryLayoutStable(page: Page) {
  let previous = '';
  let stableSince = 0;
  await expect
    .poll(async () => {
      const layout = await page.evaluate(() => {
        const header = document.querySelector('.site-header')!;
        const measuredHeader = parseFloat(
          getComputedStyle(document.documentElement).getPropertyValue(
            '--measured-header',
          ),
        );
        const stages = [
          ...document.querySelectorAll<HTMLElement>(
            '[data-story-stage], #closing',
          ),
        ].map((stage) => ({
          readStart: stage.dataset.scrollReadStart,
          readEnd: stage.dataset.scrollReadEnd,
          storyStart: stage.dataset.storyStart,
          storyEnd: stage.dataset.storyEnd,
          width: stage.getBoundingClientRect().width,
          height: stage.getBoundingClientRect().height,
          contentHeight: stage.scrollHeight,
        }));
        return {
          identity: JSON.stringify({
            stages,
            documentHeight: document.documentElement.scrollHeight,
            headerHeight: header.getBoundingClientRect().height,
            measuredHeader,
          }),
          ready:
            document.fonts.status === 'loaded' &&
            document.documentElement.dataset.scrollState === 'idle' &&
            Math.abs(header.getBoundingClientRect().height - measuredHeader) <=
              1 &&
            stages.every(
              (stage) =>
                stage.readStart !== undefined &&
                stage.readEnd !== undefined &&
                Number.isFinite(Number(stage.readStart)) &&
                Number(stage.readEnd) >= Number(stage.readStart),
            ),
        };
      });
      if (layout.identity !== previous || !layout.ready) {
        previous = layout.identity;
        stableSince = Date.now();
      }
      return layout.ready && Date.now() - stableSince >= 200;
    })
    .toBe(true);
}

async function openBoundary(
  page: Page,
  source: Stop = 'replay',
  direction = 1,
  css = true,
  viewport = { width: 1440, height: 900 },
) {
  await page.setViewportSize(viewport);
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  if (css) await page.route(sceneChunk, (route) => route.abort());
  await page.goto('/#' + source);
  await page.evaluate(() => document.fonts.ready);
  // Clear fragment navigation ownership before the scrollbar-like preparation.
  await page.mouse.click(12, 450);
  // Fonts can finish before the ResizeObserver publishes the current reading
  // map. Wait for both actual geometry and its published bounds, then seek once.
  await boundaryLayoutStable(page);
  const bounds = await range(page, source);
  const top = direction > 0 ? bounds.end : bounds.start;
  await page.evaluate(
    (value) => scrollTo({ top: value, behavior: 'instant' }),
    top,
  );
  await expect
    .poll(async () => {
      const current = await range(page, source);
      return Math.abs(
        (await page.evaluate(() => scrollY)) -
          (direction > 0 ? current.end : current.start),
      );
    })
    .toBeLessThanOrEqual(2);
  expect(await range(page, source)).toEqual(bounds);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-stop',
    source,
  );
  await page.mouse.move(20, 450);
}

async function settled(page: Page, id: Stop) {
  await expect
    .poll(async () => {
      const bounds = await range(page, id);
      return page.evaluate(async ({ start, end }) => {
        const before = scrollY;
        await new Promise(requestAnimationFrame);
        await new Promise(requestAnimationFrame);
        return (
          before >= start - 2 &&
          before <= end + 2 &&
          Math.abs(scrollY - before) < 1 &&
          document.documentElement.dataset.scrollState === 'idle'
        );
      }, bounds);
    })
    .toBe(true);
  await expect(page.locator('html')).toHaveAttribute('data-scroll-stop', id);
  await expect(
    page.locator(selector(id) + ' [data-glass-card]').first(),
  ).toHaveCSS('opacity', '1');
}

async function beginTransition(page: Page, direction = 1) {
  await page.mouse.wheel(0, direction * 24);
  await expect(page.locator('html')).toHaveAttribute(
    'data-scroll-state',
    'settling',
  );
  // Interrupt an actual in-progress transition, not a completed reading stop.
  await page.waitForTimeout(180);
}

async function withEvidence(
  page: Page,
  testInfo: TestInfo,
  run: () => Promise<void>,
) {
  await page.evaluate(() => {
    const frames: {
      time: number;
      y: number;
      state?: string;
      chapter?: string;
      stop?: string;
    }[] = [];
    const inputs: Record<string, unknown>[] = [];
    const wheel = (event: WheelEvent) =>
      inputs.push({
        time: performance.now(),
        delta: event.deltaY,
        cancelable: event.cancelable,
        prevented: event.defaultPrevented,
        y: scrollY,
        state: document.documentElement.dataset.scrollState,
        stop: document.documentElement.dataset.scrollStop,
      });
    window.addEventListener('wheel', wheel, { passive: true });
    Reflect.set(window, '__snapRecoveryInputs', inputs);
    let active = true;
    const sample = () => {
      frames.push({
        time: performance.now(),
        y: scrollY,
        state: document.documentElement.dataset.scrollState,
        chapter: document.documentElement.dataset.chapter,
        stop: document.documentElement.dataset.scrollStop,
      });
      if (active) requestAnimationFrame(sample);
    };
    sample();
    Reflect.set(window, '__snapRecoveryTrace', () => {
      active = false;
      window.removeEventListener('wheel', wheel);
      return {
        frames,
        inputs,
        root: { ...document.documentElement.dataset },
        canvas: {
          ...(document.querySelector('#court-canvas') as HTMLElement).dataset,
        },
        stops: [
          ...document.querySelectorAll<HTMLElement>('[data-scroll-read-start]'),
        ].map((stage) => ({
          id: stage.id || stage.dataset.storyStage,
          start: stage.dataset.scrollReadStart,
          end: stage.dataset.scrollReadEnd,
        })),
      };
    });
  });
  try {
    await run();
  } finally {
    if (!page.isClosed()) {
      const evidence = await page.evaluate(() =>
        (Reflect.get(window, '__snapRecoveryTrace') as () => unknown)(),
      );
      await testInfo.attach('recovery-scroll-frames', {
        body: JSON.stringify(evidence, null, 2),
        contentType: 'application/json',
      });
      await page.screenshot({
        path: testInfo.outputPath('recovery-result.png'),
      });
    }
  }
}

async function verifyWheelSequence(
  page: Page,
  expected: number[],
  browserName: string,
) {
  const inputs = await page.evaluate(
    (direction) =>
      (
        Reflect.get(window, '__snapRecoveryInputs') as {
          time: number;
          delta: number;
        }[]
      ).filter((input) => Math.sign(input.delta) === direction),
    Math.sign(expected[0]),
  );
  const maximumGap = Math.max(
    0,
    ...inputs.slice(1).map((input, index) => input.time - inputs[index].time),
  );
  const faithful =
    inputs.length === expected.length &&
    inputs.every((input, index) => input.delta === expected[index]) &&
    maximumGap < 180;
  test.skip(
    browserName === 'webkit' && !faithful,
    'Windows WebKit coalesced/delayed native wheel delivery; this run cannot prove an uninterrupted sequence. Raw input retained.',
  );
  expect(inputs.map((input) => input.delta)).toEqual(expected);
  expect(
    maximumGap,
    'the actual browser input must not contain a quiet release',
  ).toBeLessThan(180);
}

async function sendWheelSequence(
  page: Page,
  deltas: number[],
  interval: number,
) {
  let received = await page.evaluate(
    () => (Reflect.get(window, '__snapRecoveryInputs') as unknown[]).length,
  );
  for (const [index, delta] of deltas.entries()) {
    const sentAt = Date.now();
    // Protocol dispatch does not acknowledge DOM delivery. Concurrent wheel
    // commands can merge into larger packets before the page receives them.
    // Keep one command in flight and wait for its actual browser receipt.
    await page.mouse.wheel(0, delta);
    await page.waitForFunction(
      (count) =>
        (Reflect.get(window, '__snapRecoveryInputs') as unknown[]).length >=
        count,
      ++received,
      { polling: 5 },
    );
    if (index < deltas.length - 1) {
      const remaining = interval - (Date.now() - sentAt);
      if (remaining > 0)
        await new Promise((resolve) => setTimeout(resolve, remaining));
    }
  }
}

test('a wheel over a stationary card still reaches intent when later samples are uncancelable', async ({
  page,
}, testInfo) => {
  await openBoundary(page, 'hero');
  const card = page.locator('[data-glass-id="hero-actions"]');
  const bounds = (await card.boundingBox())!;
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + 24);
  await withEvidence(page, testInfo, async () => {
    await card.evaluate((element) => {
      // The first sample is real input. Inject only the browser's alternative
      // cancelability/default-displacement case; CDP cannot select this flag.
      window.addEventListener(
        'wheel',
        () =>
          queueMicrotask(() => {
            element.dispatchEvent(
              new WheelEvent('wheel', {
                bubbles: true,
                cancelable: false,
                deltaY: 12,
              }),
            );
            scrollTo({ top: scrollY + 12, behavior: 'instant' });
          }),
        { once: true },
      );
    });
    await page.mouse.wheel(0, 12);
    // There is no mouse move or second physical gesture to release the card.
    await settled(page, 'scoring');
  });
});

test('a fresh uncancelable vertical sequence starts a chapter instead of sitting in the pin plateau', async ({
  page,
}, testInfo) => {
  await openBoundary(page, 'hero');
  const card = page.locator('[data-glass-id="hero-actions"]');
  const bounds = (await card.boundingBox())!;
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + 24);
  await withEvidence(page, testInfo, async () => {
    await card.evaluate((element) => {
      element.dispatchEvent(
        new WheelEvent('wheel', {
          bubbles: true,
          cancelable: false,
          deltaY: 24,
        }),
      );
      scrollTo({ top: scrollY + 24, behavior: 'instant' });
    });
    await settled(page, 'scoring');
  });
});

test('real wheel gestures keep working across cards without moving the pointer', async ({
  page,
}, testInfo) => {
  await openBoundary(page, 'hero');
  const bounds = (await page
    .locator('[data-glass-id="hero-actions"]')
    .boundingBox())!;
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + 24);
  await withEvidence(page, testInfo, async () => {
    for (const [stop, delta] of [
      ['scoring', 24],
      ['experience', 24],
      ['scoring', -24],
      ['hero', -24],
    ] as const) {
      await page.mouse.wheel(0, delta);
      await settled(page, stop);
    }
  });
});

test('continued deliberate wheel pulses rearm after landing with the pointer fixed on a card', async ({
  page,
  browserName,
}, testInfo) => {
  await openBoundary(page, 'hero');
  const bounds = (await page
    .locator('[data-glass-id="hero-actions"]')
    .boundingBox())!;
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + 24);
  await withEvidence(page, testInfo, async () => {
    for (const [delta, target] of [
      [120, 'experience'],
      [-120, 'hero'],
    ] as const) {
      await sendWheelSequence(page, Array<number>(19).fill(delta), 90);
      await verifyWheelSequence(
        page,
        Array<number>(19).fill(delta),
        browserName,
      );
      await settled(page, target);
    }
  });
});

test.describe('fine input at the reported viewport and DPR', () => {
  test.use({ deviceScaleFactor: 1.5 });
  for (const [direction, source, target] of [
    [-1, 'experience', 'hero'],
    [1, 'hero', 'experience'],
  ] as const) {
    test(`trace-derived small deltas respects reading boundaries ${direction < 0 ? 'upward' : 'downward'} across two chapters`, async ({
      page,
    }, testInfo) => {
      await openBoundary(page, source, direction, true, {
        width: 1413,
        height: 871,
      });
      const card = page.locator(
        `[data-glass-id="${source === 'experience' ? 'experience-controls' : 'hero-actions'}"]`,
      );
      const bounds = (await card.boundingBox())!;
      const point = { x: bounds.x + bounds.width / 2, y: bounds.y + 24 };
      await page.mouse.move(point.x, point.y);
      await withEvidence(page, testInfo, async () => {
        // Protocol wheel commands can coalesce into >24px packets. Inject only
        // this trace-derived sequence to preserve the reported small packets;
        // this does not claim a physical-device recording or native transport.
        const burst = async (duration: number) => {
          const startIndex = await page.evaluate(
            () =>
              (Reflect.get(window, '__snapRecoveryInputs') as unknown[]).length,
          );
          await page.evaluate(
            async ({ direction, point, duration }) => {
              const samples = [8, 8, 9, 8, 8, 7];
              const start = performance.now();
              let index = 0;
              await new Promise<void>((resolve) => {
                const timer = setInterval(() => {
                  const element =
                    document.elementFromPoint(point.x, point.y) ??
                    document.body;
                  const delta = direction * samples[index++ % samples.length];
                  const event = new WheelEvent('wheel', {
                    bubbles: true,
                    cancelable: true,
                    deltaY: delta,
                    clientX: point.x,
                    clientY: point.y,
                  });
                  element.dispatchEvent(event);
                  // This is a trace-state test, not native physical wheel input.
                  // Synthetic events have no default transport: preserve native
                  // reading movement only when production deliberately allows it.
                  if (
                    !event.defaultPrevented &&
                    Math.abs(event.deltaY) > Math.abs(event.deltaX)
                  )
                    window.scrollBy({ top: delta, behavior: 'instant' });
                  if (performance.now() - start >= duration) {
                    clearInterval(timer);
                    resolve();
                  }
                }, 4);
              });
            },
            { direction, point, duration },
          );
          const inputs = await page.evaluate(
            (startIndex) =>
              (
                Reflect.get(window, '__snapRecoveryInputs') as {
                  delta: number;
                  time: number;
                }[]
              ).slice(startIndex),
            startIndex,
          );
          // WebKit clamps timers near16ms. Verify eligible distance/time rather
          // than an arbitrary packet count; packets must remain individually small.
          const elapsed = inputs.at(-1)!.time - inputs[0].time;
          const rate =
            (inputs.reduce((sum, input) => sum + Math.abs(input.delta), 0) *
              1000) /
            elapsed;
          expect(rate).toBeGreaterThanOrEqual(300);
          expect(
            Math.max(...inputs.map((input) => Math.abs(input.delta))),
          ).toBeLessThan(24);
          expect(
            Math.max(
              ...inputs
                .slice(1)
                .map((input, index) => input.time - inputs[index].time),
            ),
          ).toBeLessThan(180);
          return inputs;
        };
        await burst(1600);
        const scoring = await range(page, 'scoring');
        const targetRange = await range(page, target);
        const y = await page.evaluate(() => scrollY);
        const atTarget = y >= targetRange.start - 2 && y <= targetRange.end + 2;
        if (scoring.end - scoring.start > 2 && !atTarget) {
          // A gesture spent reading the scoring range must stop at its edge.
          // Only a fresh gesture after quiet can advance to the next chapter.
          await settled(page, 'scoring');
          const boundary = direction > 0 ? scoring.end : scoring.start;
          expect(
            Math.abs((await page.evaluate(() => scrollY)) - boundary),
          ).toBeLessThanOrEqual(2);
          await page.waitForTimeout(220);
          await burst(500);
        }
        await settled(page, target);
      });
    });
  }
});

test('a decaying wheel tail continuing beyond landing stays on its chosen chapter', async ({
  page,
  browserName,
}, testInfo) => {
  await openBoundary(page, 'hero');
  const bounds = (await page
    .locator('[data-glass-id="hero-actions"]')
    .boundingBox())!;
  await page.mouse.move(bounds.x + bounds.width / 2, bounds.y + 24);
  await withEvidence(page, testInfo, async () => {
    const deltas = [
      180, 170, 160, 150, 140, 130, 120, 110, 100, 90, 80, 70, 60, 50, 40, 32,
      24, 20, 16, 12, 8, 4, 2,
    ];
    await sendWheelSequence(page, deltas, 60);
    await verifyWheelSequence(page, deltas, browserName);
    await settled(page, 'scoring');
  });
});

test('a horizontal wheel tail cannot strand replay to download between chapters', async ({
  page,
}, testInfo) => {
  await openBoundary(page);
  await withEvidence(page, testInfo, async () => {
    await beginTransition(page);
    await page.mouse.wheel(40, 0);
    // No second vertical wheel is sent: the original committed intent must finish.
    await settled(page, 'download');
  });
});

test('a horizontal wheel tail cannot strand the reverse download to replay transition', async ({
  page,
}, testInfo) => {
  await openBoundary(page, 'download', -1);
  await withEvidence(page, testInfo, async () => {
    await beginTransition(page, -1);
    await page.mouse.wheel(-40, 0);
    await settled(page, 'replay');
  });
});

for (const noise of ['zero', 'noncancelable'] as const) {
  test(`a synthetic ${noise} wheel tail cannot cancel a committed chapter`, async ({
    page,
  }, testInfo) => {
    await openBoundary(page);
    await withEvidence(page, testInfo, async () => {
      await beginTransition(page);
      // These target browser event edge cases, not simulated physical input.
      // The real-wheel cases above independently cover actual input behavior.
      await page.evaluate((kind) => {
        document.body.dispatchEvent(
          new WheelEvent('wheel', {
            bubbles: true,
            cancelable: kind !== 'noncancelable',
            deltaY: kind === 'zero' ? 0 : 6,
          }),
        );
      }, noise);
      await settled(page, 'download');
    });
  });
}

test('hovering the fixed navigation without clicking cannot leave a chapter transition unfinished', async ({
  page,
}, testInfo) => {
  await openBoundary(page);
  await withEvidence(page, testInfo, async () => {
    await beginTransition(page);
    await page.locator('.site-header .wordmark').hover();
    await settled(page, 'download');
  });
});

test('a genuine offscreen FAQ layout refresh preserves the committed destination', async ({
  page,
}, testInfo) => {
  await openBoundary(page);
  const before = await page
    .locator('#closing')
    .evaluate((element) => element.scrollHeight);
  await withEvidence(page, testInfo, async () => {
    await beginTransition(page);
    await page.locator('#closing').evaluate((element) => {
      for (const details of element.querySelectorAll('details'))
        details.open = true;
    });
    await expect
      .poll(() =>
        page.locator('#closing').evaluate((element) => element.scrollHeight),
      )
      .toBeGreaterThan(before + 20);
    await settled(page, 'download');
  });
});

test('an explicit navigation click overrides the old destination without snapping back later', async ({
  page,
}, testInfo) => {
  await openBoundary(page);
  await withEvidence(page, testInfo, async () => {
    await beginTransition(page);
    await page.locator('.site-header nav > a[href="#experience"]').click();
    await settled(page, 'experience');
    const top = await page.evaluate(() => scrollY);
    await page.waitForTimeout(500);
    expect(
      Math.abs((await page.evaluate(() => scrollY)) - top),
    ).toBeLessThanOrEqual(2);
  });
});

test('@webgl ordinary court and glass finish the interrupted replay to download transition', async ({
  page,
}, testInfo) => {
  test.skip(
    testInfo.project.name !== 'chromium',
    'One actual Chromium optical path complements the browser-wide CSS regressions.',
  );
  const available = await page.evaluate(() => {
    const gl = document
      .createElement('canvas')
      .getContext('webgl2', { failIfMajorPerformanceCaveat: true });
    gl?.getExtension('WEBGL_lose_context')?.loseContext();
    return !!gl;
  });
  test.skip(
    !available,
    'Production WebGL2 is unavailable; CSS regressions run independently.',
  );
  await openBoundary(page, 'replay', 1, false);
  await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
    timeout: 20000,
  });
  await withEvidence(page, testInfo, async () => {
    await beginTransition(page);
    await page.mouse.wheel(40, 2);
    await settled(page, 'download');
    await expect(page.locator('#court-canvas')).toHaveAttribute(
      'data-rendering',
      'ambient',
    );
    await expect(page.locator('html')).toHaveAttribute(
      'data-glass',
      /^(?:css|webgl)$/,
    );
  });
});

/** Real native writes, with one controlled post-return adjustment and no input event. */
async function interceptNativeWriteReceipt(
  page: Page,
  offset: number,
  reason: string,
) {
  const source = await range(page, 'scoring');
  const target = await range(page, 'experience');
  return page.evaluateHandle(
    ({ sourceEnd, targetStart, offset, reason }) => {
      const original = window.scrollTo;
      const writes: {
        time: number;
        requested: number;
        actual: number;
        integer: boolean;
        reason: string;
      }[] = [];
      let active = true;
      let queued = false;
      let correction:
        | {
            time: number;
            requested: number;
            immediate: number;
            immediateInteger: boolean;
            target: number;
            actual?: number;
            integer?: boolean;
            reason: string;
            notification?: string;
          }
        | undefined;
      const intercepted = function (
        ...args: [options?: ScrollToOptions] | [x: number, y: number]
      ) {
        Reflect.apply(original, window, args);
        const requested =
          typeof args[0] === 'number' ? args[1]! : (args[0]?.top ?? scrollY);
        const immediate = scrollY;
        writes.push({
          time: performance.now(),
          requested,
          actual: immediate,
          integer: Number.isInteger(immediate),
          reason: 'application-native-write',
        });
        if (
          !active ||
          queued ||
          document.documentElement.dataset.scrollState !== 'settling' ||
          immediate <= sourceEnd + 24 ||
          immediate >= targetStart - 24
        )
          return;
        queued = true;
        const entry = {
          time: performance.now(),
          requested,
          immediate,
          immediateInteger: Number.isInteger(immediate),
          target: immediate + offset,
          reason,
        };
        correction = entry;
        // The application first observes the actual result of its own write.
        // Only afterwards does the browser-like correction change native scroll.
        queueMicrotask(() => {
          if (!active) return;
          Reflect.apply(original, window, [
            { top: entry.target, behavior: 'instant' },
          ]);
          Object.assign(entry, {
            actual: scrollY,
            integer: Number.isInteger(scrollY),
          });
          if (reason === 'unknown-post-return-seek') {
            // Deterministic adapter boundary: WebKit may revise the position
            // again before dispatching its delayed native scroll notification.
            // The -3 correction case keeps real native event delivery unchanged.
            Object.assign(entry, {
              notification: 'synchronous-state-boundary',
            });
            window.dispatchEvent(new Event('scroll'));
          }
        });
      } as typeof window.scrollTo;
      window.scrollTo = intercepted;
      return {
        read: () => ({ offset, reason, writes, correction }),
        restore() {
          active = false;
          if (window.scrollTo === intercepted) window.scrollTo = original;
        },
      };
    },
    { sourceEnd: source.end, targetStart: target.start, offset, reason },
  );
}

test('native write receipt preserves scoring to experience through one queued minus-three-pixel correction', async ({
  page,
}, testInfo) => {
  await openBoundary(page, 'scoring');
  const receipt = await interceptNativeWriteReceipt(
    page,
    -3,
    'post-return-native-rounding',
  );
  try {
    await withEvidence(page, testInfo, async () => {
      await page.mouse.wheel(0, 24);
      await expect
        .poll(() =>
          receipt.evaluate((value) => value.read().correction?.actual),
        )
        .not.toBeUndefined();
      const correction = await receipt.evaluate(
        (value) => value.read().correction!,
      );
      expect(correction.actual! - correction.immediate).toBeCloseTo(-3, 2);
      expect(correction.reason).toBe('post-return-native-rounding');
      expect(typeof correction.immediateInteger).toBe('boolean');
      expect(typeof correction.integer).toBe('boolean');
      // No further wheel, pointer, key or synthetic scroll event is dispatched.
      await settled(page, 'experience');
    });
  } finally {
    await testInfo.attach('native-write-receipt', {
      body: JSON.stringify(
        await receipt.evaluate((value) => value.read()),
        null,
        2,
      ),
      contentType: 'application/json',
    });
    await receipt.evaluate((value) => value.restore());
    await receipt.dispose();
  }
});

for (const offset of [-4, 4]) {
  test(`native write receipt rejects an unknown ${offset > 0 ? 'plus' : 'minus'}-four-pixel seek without resuming the old task`, async ({
    page,
  }, testInfo) => {
    await openBoundary(page, 'scoring');
    const destination = await range(page, 'experience');
    const receipt = await interceptNativeWriteReceipt(
      page,
      offset,
      'unknown-post-return-seek',
    );
    try {
      await withEvidence(page, testInfo, async () => {
        await page.mouse.wheel(0, 24);
        await expect
          .poll(() =>
            receipt.evaluate((value) => value.read().correction?.actual),
          )
          .not.toBeUndefined();
        await expect(page.locator('html')).toHaveAttribute(
          'data-scroll-state',
          'idle',
        );
        const correction = await receipt.evaluate(
          (value) => value.read().correction!,
        );
        expect(correction.actual! - correction.immediate).toBeCloseTo(
          offset,
          2,
        );
        expect(correction.reason).toBe('unknown-post-return-seek');
        expect(typeof correction.integer).toBe('boolean');
        const stopped = await page.evaluate(() => scrollY);
        expect(Math.abs(stopped - correction.actual!)).toBeLessThanOrEqual(2);
        expect(stopped).toBeLessThan(destination.start - 10);
        const count = await receipt.evaluate(
          (value) => value.read().writes.length,
        );
        // Observe longer than the remaining tween and its quiet-release timer.
        await page.waitForTimeout(1200);
        expect(
          Math.abs((await page.evaluate(() => scrollY)) - stopped),
        ).toBeLessThanOrEqual(2);
        expect(
          await receipt.evaluate((value) => value.read().writes.length),
        ).toBe(count);
        await expect(page.locator('html')).toHaveAttribute(
          'data-scroll-state',
          'idle',
        );
      });
    } finally {
      await testInfo.attach('native-write-receipt', {
        body: JSON.stringify(
          await receipt.evaluate((value) => value.read()),
          null,
          2,
        ),
        contentType: 'application/json',
      });
      await receipt.evaluate((value) => value.restore());
      await receipt.dispose();
    }
  });
}

async function interceptNativeTailReceipt(
  page: Page,
  tailDelta: number,
  unknownOffset: number,
) {
  const source = await range(page, 'scoring');
  const destination = await range(page, 'experience');
  return page.evaluateHandle(
    ({ sourceEnd, targetStart, tailDelta, unknownOffset }) => {
      const original = window.scrollTo;
      const samples: {
        reason: string;
        requested: number;
        y: number;
        integer: boolean;
        state: string | undefined;
      }[] = [];
      let active = true;
      let queued = false;
      let writes = 0;
      const record = (reason: string, requested: number) =>
        samples.push({
          reason,
          requested,
          y: scrollY,
          integer: Number.isInteger(scrollY),
          state: document.documentElement.dataset.scrollState,
        });
      const intercepted = function (
        ...args: [options?: ScrollToOptions] | [x: number, y: number]
      ) {
        Reflect.apply(original, window, args);
        writes++;
        const base = scrollY;
        if (
          !active ||
          queued ||
          document.documentElement.dataset.scrollState !== 'settling' ||
          base <= sourceEnd + 24 ||
          base >= targetStart - 24
        )
          return;
        queued = true;
        const requested =
          typeof args[0] === 'number' ? args[1]! : (args[0]?.top ?? base);
        record('active-write-readback', requested);
        queueMicrotask(() => {
          if (!active) return;
          // These synthetic notifications isolate adapter ordering. Positions
          // are real native writes, and no next RAF can issue a new receipt.
          window.dispatchEvent(
            new WheelEvent('wheel', {
              bubbles: true,
              cancelable: false,
              deltaY: tailDelta,
            }),
          );
          Reflect.apply(original, window, [
            { top: base + tailDelta, behavior: 'instant' },
          ]);
          window.dispatchEvent(new Event('scroll'));
          record('known-uncancelable-tail', base + tailDelta);
          Reflect.apply(original, window, [
            { top: base + unknownOffset, behavior: 'instant' },
          ]);
          window.dispatchEvent(new Event('scroll'));
          record('unknown-seek-after-tail', base + unknownOffset);
        });
      } as typeof window.scrollTo;
      window.scrollTo = intercepted;
      return {
        read: () => ({ tailDelta, unknownOffset, writes, samples }),
        restore() {
          active = false;
          if (window.scrollTo === intercepted) window.scrollTo = original;
        },
      };
    },
    {
      sourceEnd: source.end,
      targetStart: destination.start,
      tailDelta,
      unknownOffset,
    },
  );
}

for (const [tailDelta, unknownOffset, label] of [
  [
    3,
    6,
    'consumes a three-pixel tail before rejecting another three-pixel seek',
  ],
  [
    16,
    0,
    'invalidates the old receipt after a sixteen-pixel tail before rejecting rollback',
  ],
] as const) {
  test(`native write receipt tail ${label}`, async ({ page }, testInfo) => {
    await openBoundary(page, 'scoring');
    const receipt = await interceptNativeTailReceipt(
      page,
      tailDelta,
      unknownOffset,
    );
    try {
      await withEvidence(page, testInfo, async () => {
        await page.mouse.wheel(0, 24);
        await expect
          .poll(() => receipt.evaluate((value) => value.read().samples.length))
          .toBe(3);
        const samples = await receipt.evaluate((value) => value.read().samples);
        expect(samples.map((sample) => sample.reason)).toEqual([
          'active-write-readback',
          'known-uncancelable-tail',
          'unknown-seek-after-tail',
        ]);
        expect(samples[1].y - samples[0].y).toBeCloseTo(tailDelta, 2);
        expect(samples[2].y - samples[0].y).toBeCloseTo(unknownOffset, 2);
        expect(samples[1].state).toBe('settling');
        expect(samples[2].state).toBe('idle');
        const writes = await receipt.evaluate((value) => value.read().writes);
        await page.waitForTimeout(1200);
        expect(
          Math.abs((await page.evaluate(() => scrollY)) - samples[2].y),
        ).toBeLessThanOrEqual(2);
        expect(await receipt.evaluate((value) => value.read().writes)).toBe(
          writes,
        );
        await expect(page.locator('html')).toHaveAttribute(
          'data-scroll-state',
          'idle',
        );
      });
    } finally {
      await testInfo.attach('native-write-tail-receipt', {
        body: JSON.stringify(
          await receipt.evaluate((value) => value.read()),
          null,
          2,
        ),
        contentType: 'application/json',
      });
      await receipt.evaluate((value) => value.restore());
      await receipt.dispose();
    }
  });
}
