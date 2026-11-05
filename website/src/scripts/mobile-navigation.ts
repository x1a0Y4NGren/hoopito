/** The phone directory uses the same native-dialog pause ownership as downloads. */
export function createMobileNavigation(onOpenChange: (open: boolean) => void) {
  const dialog =
    document.querySelector<HTMLDialogElement>('[data-mobile-menu]');
  const opener = document.querySelector<HTMLButtonElement>(
    '[data-mobile-menu-toggle]',
  );
  if (!dialog || !opener) return { dispose() {} };
  const menu = dialog;
  const button = opener;
  const phone = matchMedia('(max-width: 767px)');
  const listeners = new AbortController();
  let active = false;
  let alive = true;
  let scroll = { left: 0, top: 0 };
  let backdropDown = false;
  const listen = (target: EventTarget, type: string, handler: EventListener) =>
    target.addEventListener(type, handler, { signal: listeners.signal });

  function restore(navigating = false) {
    if (!active) return;
    active = false;
    button.setAttribute('aria-expanded', 'false');
    document.documentElement.classList.remove('mobile-menu-open');
    onOpenChange(false);
    if (alive && !navigating) {
      button.focus({ preventScroll: true });
      window.scrollTo({ ...scroll, behavior: 'instant' });
    }
  }

  function close(navigating = false) {
    if (menu.open) menu.close();
    // Release the body and pause before the shared anchor handler runs.
    restore(navigating);
  }

  function sync() {
    button.hidden = !phone.matches || typeof menu.showModal !== 'function';
    if (!phone.matches) close();
  }

  listen(button, 'click', () => {
    if (!phone.matches || menu.open) return;
    for (const other of document.querySelectorAll<HTMLDialogElement>(
      'dialog[open]',
    ))
      if (other !== menu) other.close();
    scroll = { left: scrollX, top: scrollY };
    const current = document.documentElement.dataset.scrollStop ?? 'hero';
    for (const link of menu.querySelectorAll<HTMLAnchorElement>(
      '[data-mobile-menu-link]',
    )) {
      if (link.dataset.mobileMenuLink === current)
        link.setAttribute('aria-current', 'location');
      else link.removeAttribute('aria-current');
    }
    menu.showModal();
    active = true;
    button.setAttribute('aria-expanded', 'true');
    document.documentElement.classList.add('mobile-menu-open');
    onOpenChange(true);
    menu.querySelector<HTMLButtonElement>('[data-mobile-menu-close]')?.focus();
  });
  listen(menu, 'close', () => restore());
  listen(menu.querySelector('[data-mobile-menu-close]')!, 'click', () =>
    close(),
  );
  listen(menu, 'click', (event) => {
    const click = event as MouseEvent;
    if (
      click.button ||
      click.metaKey ||
      click.ctrlKey ||
      click.altKey ||
      click.shiftKey
    )
      return;
    if (
      event.target instanceof Element &&
      event.target.closest('[data-mobile-menu-link]')
    )
      close(true);
  });
  listen(menu, 'keydown', (event) => {
    const key = event as KeyboardEvent;
    if (key.key !== 'Tab' || key.ctrlKey || key.altKey || key.metaKey) return;
    const controls = [
      ...menu.querySelectorAll<HTMLElement>('a[href], button:not(:disabled)'),
    ];
    const index = controls.indexOf(document.activeElement as HTMLElement);
    key.preventDefault();
    controls[
      (index + (key.shiftKey ? controls.length - 1 : 1)) % controls.length
    ]?.focus();
  });
  const outside = (event: MouseEvent) => {
    const r = menu.getBoundingClientRect();
    return (
      event.clientX < r.left ||
      event.clientX > r.right ||
      event.clientY < r.top ||
      event.clientY > r.bottom
    );
  };
  listen(menu, 'pointerdown', (event) => {
    backdropDown = event.target === menu && outside(event as MouseEvent);
  });
  listen(menu, 'click', (event) => {
    if (event.target === menu && backdropDown && outside(event as MouseEvent))
      close();
    backdropDown = false;
  });
  phone.addEventListener('change', sync);
  sync();
  return {
    dispose() {
      alive = false;
      close();
      listeners.abort();
      phone.removeEventListener('change', sync);
    },
  };
}
