import type { Page, TestInfo } from '@playwright/test';

/** Read-only receipts around native writes, retained only for failure diagnosis. */
export async function installScrollAudit(page: Page) {
  await page.addInitScript(() => {
    const rows: Record<string, unknown>[] = [];
    const record = (kind: string, data: Record<string, unknown> = {}) => {
      rows.push({
        kind,
        at: performance.now(),
        y: scrollY,
        state: document.documentElement.dataset.scrollState,
        stop: document.documentElement.dataset.scrollStop,
        ...data,
      });
      if (rows.length > 160) rows.shift();
    };
    const nativeScrollTo = window.scrollTo;
    window.scrollTo = (...args: unknown[]) => {
      const first = args[0];
      const requested =
        first && typeof first === 'object'
          ? (first as ScrollToOptions).top
          : args[1];
      const before = scrollY;
      Reflect.apply(nativeScrollTo, window, args);
      record('write', { requested, before });
    };
    window.addEventListener('scroll', () => record('scroll'), {
      capture: true,
      passive: true,
    });
    for (const name of ['pointerdown', 'wheel', 'keydown', 'focusin', 'resize'])
      window.addEventListener(
        name,
        (event) => {
          const element = event.target;
          record(name, {
            target:
              element instanceof Element
                ? element.tagName + '#' + element.id
                : undefined,
            key: event instanceof KeyboardEvent ? event.key : undefined,
            delta: event instanceof WheelEvent ? event.deltaY : undefined,
          });
        },
        { capture: true, passive: true },
      );
    document.addEventListener('visibilitychange', () =>
      record('visibility', { hidden: document.hidden }),
    );
    const observeState = () =>
      new MutationObserver(() => record('state')).observe(
        document.documentElement,
        {
          attributes: true,
          attributeFilter: ['data-scroll-state', 'data-scroll-stop'],
        },
      );
    if (document.documentElement) observeState();
    else
      document.addEventListener('DOMContentLoaded', observeState, {
        once: true,
      });
    Reflect.set(window, '__scrollAudit', rows);
  });
}

export async function attachScrollAudit(page: Page, testInfo: TestInfo) {
  if (testInfo.status === testInfo.expectedStatus || page.isClosed()) return;
  const audit = await page.evaluate(() => ({
    rows: Reflect.get(window, '__scrollAudit'),
    root: { ...document.documentElement.dataset },
    stops: [
      ...document.querySelectorAll<HTMLElement>('[data-scroll-read-start]'),
    ].map((stage) => ({
      id: stage.dataset.storyStage ?? stage.id,
      start: stage.dataset.scrollReadStart,
      end: stage.dataset.scrollReadEnd,
    })),
  }));
  await testInfo.attach('native-scroll-audit', {
    body: JSON.stringify(audit, null, 2),
    contentType: 'application/json',
  });
}
