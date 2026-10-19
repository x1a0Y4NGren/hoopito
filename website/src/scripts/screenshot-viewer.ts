import {
  constrainView,
  zoomView,
  type ViewSize,
  type ViewState,
} from './presentation-state';

export function createScreenshotViewer(onOpenChange: (open: boolean) => void) {
  const dialog = document.querySelector<HTMLDialogElement>('[data-viewer]')!;
  const viewport = dialog.querySelector<HTMLElement>('[data-viewer-viewport]')!;
  const image = dialog.querySelector<HTMLImageElement>('[data-viewer-image]')!;
  const title = dialog.querySelector<HTMLElement>('[data-viewer-title]')!;
  const scale = dialog.querySelector<HTMLElement>('[data-viewer-scale]')!;
  const zoomIn = dialog.querySelector<HTMLButtonElement>('[data-viewer-in]')!;
  const zoomOut = dialog.querySelector<HTMLButtonElement>('[data-viewer-out]')!;
  const fitButton =
    dialog.querySelector<HTMLButtonElement>('[data-viewer-fit]')!;
  const message = dialog.querySelector<HTMLElement>('[data-viewer-status]')!;
  const retry = dialog.querySelector<HTMLButtonElement>('[data-viewer-retry]')!;
  const status = message.parentElement!;
  const listeners = new AbortController();
  const pointers = new Map<number, { x: number; y: number }>();
  let view: ViewState = { zoom: 1, x: 0, y: 0 };
  let size: ViewSize = { width: 1, height: 1, imageWidth: 1, imageHeight: 1 };
  let opener: HTMLElement | undefined;
  let scroll = 0;
  let alive = true;
  let imageState: 'loading' | 'ready' | 'error' = 'loading';
  let source = '';
  let request = 0;
  let deadline: ReturnType<typeof setTimeout> | undefined;
  const listen = (
    element: EventTarget,
    type: string,
    callback: EventListener,
  ) => element.addEventListener(type, callback, { signal: listeners.signal });
  function paint() {
    view = constrainView(view, size);
    image.style.transform = `translate(-50%, -50%) translate(${view.x}px, ${view.y}px) scale(${view.zoom})`;
    scale.textContent = `${Math.round(view.zoom * 100)}%`;
    zoomIn.disabled = imageState !== 'ready' || view.zoom >= 4;
    zoomOut.disabled = imageState !== 'ready' || view.zoom <= 1;
    fitButton.disabled = imageState !== 'ready';
    viewport.dataset.zoomed = String(view.zoom > 1);
  }
  function fit(reset = false) {
    if (
      !dialog.open ||
      imageState !== 'ready' ||
      !image.naturalWidth ||
      !image.naturalHeight
    )
      return;
    const width = viewport.clientWidth,
      height = viewport.clientHeight;
    const ratio = Math.min(
      (width - 32) / image.naturalWidth,
      (height - 32) / image.naturalHeight,
    );
    const previousSize = size;
    size = {
      width,
      height,
      imageWidth: image.naturalWidth * ratio,
      imageHeight: image.naturalHeight * ratio,
    };
    image.style.width = `${size.imageWidth}px`;
    image.style.height = `${size.imageHeight}px`;
    view = reset
      ? { zoom: 1, x: 0, y: 0 }
      : {
          ...view,
          x: (view.x * size.imageWidth) / previousSize.imageWidth,
          y: (view.y * size.imageHeight) / previousSize.imageHeight,
        };
    pointers.clear();
    paint();
  }
  function zoom(value: number) {
    if (imageState !== 'ready') return;
    view = zoomView(view, value, { x: 0, y: 0 }, size);
    paint();
  }
  function setImageState(value: typeof imageState) {
    imageState = value;
    viewport.dataset.imageState = value;
    viewport.setAttribute('aria-busy', String(value === 'loading'));
    image.hidden = value !== 'ready';
    status.hidden = value === 'ready';
    retry.hidden = value !== 'error';
    message.textContent = value === 'ready' ? '' : message.dataset[value]!;
    paint();
  }
  function loadImage() {
    clearTimeout(deadline);
    const current = ++request;
    if (document.activeElement === retry)
      dialog
        .querySelector<HTMLButtonElement>('[data-viewer-close]')!
        .focus({ preventScroll: true });
    pointers.clear();
    view = { zoom: 1, x: 0, y: 0 };
    setImageState('loading');
    // Clearing the previous request prevents a cached old picture from being
    // presented while the new full-resolution image is still unavailable.
    image.removeAttribute('src');
    image.src = source;
    const isCurrent = () => alive && dialog.open && current === request;
    const fail = () => {
      if (!isCurrent()) return;
      request++;
      clearTimeout(deadline);
      setImageState('error');
    };
    deadline = setTimeout(fail, 12000);
    void image
      .decode()
      .then(() => {
        if (!isCurrent()) return;
        clearTimeout(deadline);
        setImageState('ready');
        fit(true);
      })
      .catch(fail);
  }
  listen(document, 'click', (event) => {
    const click = event as MouseEvent;
    if (
      click.button ||
      click.ctrlKey ||
      click.metaKey ||
      click.shiftKey ||
      click.altKey
    )
      return;
    const link = (event.target as Element).closest<HTMLAnchorElement>(
      '[data-image-viewer]',
    );
    if (!link || dialog.open || typeof dialog.showModal !== 'function') return;
    event.preventDefault();
    opener = link;
    scroll = window.scrollY;
    image.alt = link.querySelector('img')?.alt ?? link.dataset.imageTitle ?? '';
    source = link.href;
    title.textContent = link.dataset.imageTitle ?? '';
    document.documentElement.classList.add('image-viewer-open');
    dialog.showModal();
    onOpenChange(true);
    loadImage();
  });
  listen(dialog, 'close', () => {
    request++;
    clearTimeout(deadline);
    image.removeAttribute('src');
    document.documentElement.classList.remove('image-viewer-open');
    pointers.clear();
    onOpenChange(false);
    if (alive) {
      opener?.focus({ preventScroll: true });
      window.scrollTo({ top: scroll, behavior: 'instant' });
    }
  });
  listen(dialog.querySelector('[data-viewer-close]')!, 'click', () =>
    dialog.close(),
  );
  listen(zoomIn, 'click', () => zoom(view.zoom + 0.5));
  listen(zoomOut, 'click', () => zoom(view.zoom - 0.5));
  listen(fitButton, 'click', () => fit(true));
  listen(retry, 'click', loadImage);
  listen(dialog, 'keydown', (event) => {
    const key = event as KeyboardEvent;
    if (
      key.ctrlKey ||
      key.metaKey ||
      key.altKey ||
      key.isComposing ||
      imageState !== 'ready'
    )
      return;
    if (key.key === '+' || key.key === '=') zoom(view.zoom + 0.5);
    else if (key.key === '-') zoom(view.zoom - 0.5);
    else if (key.key === '0') fit(true);
    else if (
      ['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown'].includes(key.key)
    ) {
      const step = key.shiftKey ? 120 : 48;
      view = {
        ...view,
        x:
          view.x +
          (key.key === 'ArrowLeft'
            ? step
            : key.key === 'ArrowRight'
              ? -step
              : 0),
        y:
          view.y +
          (key.key === 'ArrowUp' ? step : key.key === 'ArrowDown' ? -step : 0),
      };
      paint();
    } else return;
    key.preventDefault();
  });
  listen(viewport, 'pointerdown', (event) => {
    const e = event as PointerEvent;
    if (e.button !== 0 || imageState !== 'ready') return;
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    viewport.setPointerCapture(e.pointerId);
  });
  listen(viewport, 'pointermove', (event) => {
    const e = event as PointerEvent,
      previous = pointers.get(e.pointerId);
    if (!previous) return;
    const before = [...pointers.values()];
    pointers.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (pointers.size === 1) {
      view = {
        ...view,
        x: view.x + e.clientX - previous.x,
        y: view.y + e.clientY - previous.y,
      };
    } else {
      const after = [...pointers.values()];
      const distance = (points: typeof before) =>
        Math.hypot(points[0].x - points[1].x, points[0].y - points[1].y);
      const center = (points: typeof before) => ({
        x: (points[0].x + points[1].x) / 2,
        y: (points[0].y + points[1].y) / 2,
      });
      const oldCenter = center(before),
        nextCenter = center(after),
        bounds = viewport.getBoundingClientRect();
      view = zoomView(
        view,
        (view.zoom * distance(after)) / Math.max(1, distance(before)),
        {
          x: oldCenter.x - bounds.left - size.width / 2,
          y: oldCenter.y - bounds.top - size.height / 2,
        },
        size,
      );
      view.x += nextCenter.x - oldCenter.x;
      view.y += nextCenter.y - oldCenter.y;
    }
    paint();
  });
  for (const type of ['pointerup', 'pointercancel', 'lostpointercapture'])
    listen(viewport, type, (event) =>
      pointers.delete((event as PointerEvent).pointerId),
    );
  const observer = new ResizeObserver(() => fit());
  observer.observe(viewport);
  return {
    dispose() {
      alive = false;
      request++;
      clearTimeout(deadline);
      if (dialog.open) dialog.close();
      listeners.abort();
      observer.disconnect();
    },
  };
}
