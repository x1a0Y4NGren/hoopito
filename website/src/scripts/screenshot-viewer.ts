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
  const listeners = new AbortController();
  const pointers = new Map<number, { x: number; y: number }>();
  let view: ViewState = { zoom: 1, x: 0, y: 0 };
  let size: ViewSize = { width: 1, height: 1, imageWidth: 1, imageHeight: 1 };
  let opener: HTMLElement | undefined;
  let scroll = 0;
  let alive = true;
  const listen = (
    element: EventTarget,
    type: string,
    callback: EventListener,
  ) => element.addEventListener(type, callback, { signal: listeners.signal });
  function paint() {
    view = constrainView(view, size);
    image.style.transform = `translate(-50%, -50%) translate(${view.x}px, ${view.y}px) scale(${view.zoom})`;
    scale.textContent = `${Math.round(view.zoom * 100)}%`;
    zoomIn.disabled = view.zoom >= 4;
    zoomOut.disabled = view.zoom <= 1;
    viewport.dataset.zoomed = String(view.zoom > 1);
  }
  function fit() {
    if (!dialog.open || !image.naturalWidth || !image.naturalHeight) return;
    const width = viewport.clientWidth,
      height = viewport.clientHeight;
    const ratio = Math.min(
      (width - 32) / image.naturalWidth,
      (height - 32) / image.naturalHeight,
    );
    size = {
      width,
      height,
      imageWidth: image.naturalWidth * ratio,
      imageHeight: image.naturalHeight * ratio,
    };
    image.style.width = `${size.imageWidth}px`;
    image.style.height = `${size.imageHeight}px`;
    view = { zoom: 1, x: 0, y: 0 };
    pointers.clear();
    paint();
  }
  function zoom(value: number) {
    view = zoomView(view, value, { x: 0, y: 0 }, size);
    paint();
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
    if (!link || typeof dialog.showModal !== 'function') return;
    event.preventDefault();
    opener = link;
    scroll = window.scrollY;
    image.alt = link.querySelector('img')?.alt ?? link.dataset.imageTitle ?? '';
    image.src = link.href;
    title.textContent = link.dataset.imageTitle ?? '';
    document.documentElement.classList.add('image-viewer-open');
    dialog.showModal();
    onOpenChange(true);
    fit();
    void image
      .decode()
      .then(() => {
        if (alive && dialog.open) fit();
      })
      .catch(() => {});
  });
  listen(dialog, 'close', () => {
    document.documentElement.classList.remove('image-viewer-open');
    pointers.clear();
    onOpenChange(false);
    opener?.focus({ preventScroll: true });
    window.scrollTo({ top: scroll, behavior: 'instant' });
  });
  listen(dialog.querySelector('[data-viewer-close]')!, 'click', () =>
    dialog.close(),
  );
  listen(zoomIn, 'click', () => zoom(view.zoom + 0.5));
  listen(zoomOut, 'click', () => zoom(view.zoom - 0.5));
  listen(dialog.querySelector('[data-viewer-fit]')!, 'click', fit);
  listen(image, 'load', fit);
  listen(viewport, 'pointerdown', (event) => {
    const e = event as PointerEvent;
    if (e.button !== 0) return;
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
  const observer = new ResizeObserver(fit);
  observer.observe(viewport);
  return {
    dispose() {
      alive = false;
      if (dialog.open) dialog.close();
      listeners.abort();
      observer.disconnect();
    },
  };
}
