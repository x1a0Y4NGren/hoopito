import type { ChapterStop, StopId } from './chapter-scroll';
import { mobileProgressState } from './mobile-progress-math';

interface MobileProgressOptions {
  getStops(): readonly ChapterStop[];
}

/** The existing story frame drives this small DOM-only view; it owns no clock. */
export function createMobileProgress(options: MobileProgressOptions) {
  const phone = matchMedia('(max-width: 767px)');
  const root = document.documentElement;
  const track = document.querySelector<HTMLElement>('[data-mobile-progress]');
  const fill = document.querySelector<HTMLElement>(
    '[data-mobile-progress-fill]',
  );
  const page = document.querySelector<HTMLElement>('[data-mobile-page]');
  const button = document.querySelector<HTMLButtonElement>(
    '[data-mobile-menu-toggle]',
  );
  const links = [
    ...document.querySelectorAll<HTMLAnchorElement>('[data-mobile-menu-link]'),
  ];
  const originalLabel = button?.getAttribute('aria-label');
  const menuLabel = button?.dataset.mobileMenuLabel ?? '';
  let alive = true;
  let previousPage = '';
  let previousProgress = '';

  function reset() {
    if (track) track.hidden = true;
    if (page) page.hidden = true;
    delete root.dataset.mobileProgressState;
    if (button) {
      if (originalLabel === null || originalLabel === undefined)
        button.removeAttribute('aria-label');
      else button.setAttribute('aria-label', originalLabel);
    }
    previousPage = '';
    previousProgress = '';
  }

  function update(): StopId | undefined {
    if (!alive || !track || !fill || !page || !button || !phone.matches) {
      if (root.dataset.mobileProgressState) reset();
      return undefined;
    }
    const state = mobileProgressState(
      options.getStops(),
      scrollY,
      root.scrollHeight,
      innerHeight,
    );
    // Do not display a misleading partial count while layout is initializing.
    if (!state.id || state.total !== links.length) {
      reset();
      return undefined;
    }
    const fraction = state.progress.toFixed(6);
    if (fraction !== previousProgress) {
      fill.style.transform = `scaleX(${fraction})`;
      track.setAttribute(
        'aria-valuenow',
        String(Math.round(state.progress * 100)),
      );
      previousProgress = fraction;
    }
    const count = `${String(state.index + 1).padStart(2, '0')} / ${String(state.total).padStart(2, '0')}`;
    if (count !== previousPage) {
      page.textContent = count;
      const title =
        links
          .find((link) => link.dataset.mobileMenuLink === state.id)
          ?.querySelector('strong')
          ?.textContent?.trim() ?? '';
      button.setAttribute(
        'aria-label',
        `${menuLabel} ${count} ${title}`.trim(),
      );
      previousPage = count;
    }
    if (root.dataset.mobileProgressState !== 'ready') {
      track.hidden = false;
      page.hidden = false;
      root.dataset.mobileProgressState = 'ready';
    }
    return state.id;
  }

  return {
    update,
    dispose() {
      alive = false;
      reset();
    },
  };
}
