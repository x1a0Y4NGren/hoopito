export function createDownloadChooser(onOpenChange: (open: boolean) => void) {
  const dialog = document.querySelector<HTMLDialogElement>(
    '[data-download-dialog]',
  )!;
  const listeners = new AbortController();
  let opener: HTMLAnchorElement | undefined;
  let scroll = { left: 0, top: 0 };
  let active = false;
  let alive = true;
  let backdropDown = false;

  const listen = (
    element: EventTarget,
    type: string,
    callback: EventListener,
  ) => element.addEventListener(type, callback, { signal: listeners.signal });
  const plainClick = (event: MouseEvent) =>
    !event.defaultPrevented &&
    !event.button &&
    !event.ctrlKey &&
    !event.metaKey &&
    !event.altKey &&
    !event.shiftKey;

  function restore() {
    if (!active) return;
    active = false;
    document.documentElement.classList.remove('download-chooser-open');
    onOpenChange(false);
    if (alive) {
      opener?.focus({ preventScroll: true });
      window.scrollTo({ ...scroll, behavior: 'instant' });
    }
  }
  listen(document, 'click', (event) => {
    if (!plainClick(event as MouseEvent) || !(event.target instanceof Element))
      return;
    const link = event.target.closest<HTMLAnchorElement>('[data-download]');
    if (!link || dialog.open || typeof dialog.showModal !== 'function') return;
    opener = link;
    scroll = { left: window.scrollX, top: window.scrollY };
    dialog.showModal();
    event.preventDefault();
    active = true;
    document.documentElement.classList.add('download-chooser-open');
    onOpenChange(true);
  });
  listen(dialog, 'close', restore);
  listen(dialog.querySelector('[data-download-close]')!, 'click', () =>
    dialog.close(),
  );
  listen(dialog, 'keydown', (event) => {
    const key = event as KeyboardEvent;
    if (key.key !== 'Tab' || key.ctrlKey || key.altKey || key.metaKey) return;
    const controls = [
      ...dialog.querySelectorAll<HTMLElement>('a[href], button:not(:disabled)'),
    ];
    if (!controls.length) return;
    // Safari's Tab-to-links preference can skip the download anchors entirely.
    // Cycle the small modal's controls explicitly in both keyboard directions.
    const current = controls.indexOf(document.activeElement as HTMLElement);
    const next = key.shiftKey
      ? (current - 1 + controls.length) % controls.length
      : (current + 1) % controls.length;
    key.preventDefault();
    controls[next].focus({ preventScroll: true });
  });
  // Leave the anchor's native action intact: the chosen platform owns the file
  // download or share-page navigation, without a scripted popup or fake status.
  listen(dialog, 'click', (event) => {
    if (!(event.target instanceof Element)) return;
    if (
      plainClick(event as MouseEvent) &&
      event.target.closest('a[data-download-channel]')
    ) {
      dialog.close();
    }
  });
  const outside = (event: MouseEvent) => {
    const bounds = dialog.getBoundingClientRect();
    return (
      event.clientX < bounds.left ||
      event.clientX > bounds.right ||
      event.clientY < bounds.top ||
      event.clientY > bounds.bottom
    );
  };
  listen(dialog, 'pointerdown', (event) => {
    backdropDown = event.target === dialog && outside(event as PointerEvent);
  });
  listen(dialog, 'click', (event) => {
    if (event.target === dialog && backdropDown && outside(event as MouseEvent))
      dialog.close();
    backdropDown = false;
  });
  return {
    dispose() {
      alive = false;
      if (dialog.open) dialog.close();
      restore();
      listeners.abort();
    },
  };
}
