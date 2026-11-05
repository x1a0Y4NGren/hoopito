import {
  mobileBackdropPose,
  mobileItemPose,
  mobileLayerOpacity,
  mobileScenesToLoad,
  type MobileRole,
  type MobileScene,
  type MobileSceneAnchors,
} from './mobile-presentation-math';

interface MobilePresentationOptions {
  reduced(): boolean;
  requestUpdate(): void;
  layoutChanged(): void;
}

/** Offset geometry ignores the animation transforms and never feeds them back. */
function documentTop(element: HTMLElement) {
  let top = 0;
  let current: HTMLElement | null = element;
  while (current) {
    top += current.offsetTop;
    current = current.offsetParent as HTMLElement | null;
  }
  return top;
}

/** Phone-only presentation; the story's existing frame owns all its updates. */
export function createMobilePresentation(options: MobilePresentationOptions) {
  const root = document.documentElement;
  const phone = matchMedia('(max-width: 767px)');
  const field = document.querySelector<HTMLElement>('[data-mobile-background]');
  const images = new Map<MobileScene, HTMLImageElement>();
  for (const image of document.querySelectorAll<HTMLImageElement>(
    '[data-mobile-scene]',
  ))
    images.set(image.dataset.mobileScene as MobileScene, image);
  const items = [
    ...document.querySelectorAll<HTMLElement>(
      '[data-story-item], [data-mobile-item]',
    ),
  ];
  const localItems = items.filter((item) =>
    item.hasAttribute('data-mobile-item'),
  );
  const disclosures = [
    ...document.querySelectorAll<HTMLDetailsElement>(
      '[data-mobile-disclosure]',
    ),
  ];
  const expanded = new WeakMap<HTMLDetailsElement, boolean>();
  const automaticToggle = new WeakSet<HTMLDetailsElement>();
  const ready = new Set<MobileScene>();
  const pending = new Set<MobileScene>();
  const failed = new Set<MobileScene>();
  const tops = new WeakMap<HTMLElement, number>();
  const poses = new WeakMap<HTMLElement, ReturnType<typeof mobileItemPose>>();
  const imageStates = new WeakMap<HTMLImageElement, string>();
  const listeners = new AbortController();
  let anchors: MobileSceneAnchors = { court: 0, hoop: 0, end: 1 };
  let dirty = true;
  let alive = true;
  let paused = false;
  let input = false;
  let scrolled = false;
  let inputStart = scrollY;
  let phoneMode = phone.matches;
  let lastGood: MobileScene | undefined;
  const listen = (
    target: EventTarget,
    event: string,
    callback: EventListener,
    passive = false,
  ) =>
    target.addEventListener(event, callback, {
      signal: listeners.signal,
      passive,
    });
  const height = () =>
    Math.max(1, Math.min(innerHeight, visualViewport?.height ?? innerHeight));

  function invalidate() {
    dirty = true;
  }

  function measure() {
    if (!dirty || !phone.matches) return;
    dirty = false;
    const heading = (id: string) => {
      const section = document.getElementById(id)!;
      return section.querySelector<HTMLElement>('h2') ?? section;
    };
    anchors = {
      court: documentTop(heading('scoring')),
      hoop: documentTop(heading('download')),
      end: document.documentElement.scrollHeight,
    };
    for (const item of items) tops.set(item, documentTop(item));
  }

  function request(scene: MobileScene) {
    const image = images.get(scene);
    if (!image || ready.has(scene) || pending.has(scene) || failed.has(scene))
      return;
    const src = image.dataset.src;
    if (!src) return;
    pending.add(scene);
    image.src = src;
    image
      .decode()
      .then(() => {
        if (!alive) return;
        pending.delete(scene);
        ready.add(scene);
        options.requestUpdate();
      })
      .catch(() => {
        if (!alive) return;
        pending.delete(scene);
        failed.add(scene);
        if (scene === 'hero') {
          const fallback = document.querySelector<HTMLSourceElement>(
            '[data-mobile-poster-source]',
          );
          if (fallback) fallback.srcset = '/art/scene-mobile.webp';
        }
        options.requestUpdate();
      });
  }

  function update() {
    if (!alive || !phone.matches || paused) return;
    measure();
    // Display-contents wrappers leave their independently placed children in
    // the phone grid. Animate those children from their own static bounds.
    for (const item of localItems) {
      const pose = itemPose(
        item,
        item.dataset.mobileItem as MobileRole,
        item.closest<HTMLElement>('[data-story-stage]')?.dataset.storyStage ??
          '',
      )!;
      item.style.transform = `translate3d(0, ${pose.y}px, 0) scale(${pose.scale})`;
      item.style.opacity = String(pose.opacity);
    }
    const view = height();
    for (const scene of mobileScenesToLoad({
      phone: true,
      scroll: scrollY,
      height: view,
      anchors,
      scrolled,
      hash: location.hash,
    }))
      request(scene);
    const pose = mobileBackdropPose(scrollY, view, anchors, options.reduced());
    const visible = (['hero', 'court', 'hoop'] as const).filter(
      (id) => pose.opacity[id] > 0,
    );
    const decoded = visible.filter((id) => ready.has(id));
    const opacity = { hero: 0, court: 0, hoop: 0 };
    if (decoded.length === visible.length) {
      Object.assign(opacity, pose.opacity);
      lastGood = decoded.at(-1);
    } else if (decoded.length) {
      lastGood = decoded.at(-1);
      opacity[lastGood!] = 1;
    } else {
      const fallback =
        lastGood && ready.has(lastGood)
          ? lastGood
          : ready.has('hero')
            ? 'hero'
            : undefined;
      if (fallback) opacity[fallback] = 1;
    }
    const showing = Object.values(opacity).some((value) => value > 0);
    if (showing) {
      const layers = mobileLayerOpacity(opacity);
      if (root.dataset.mobileBackground !== 'ready')
        root.dataset.mobileBackground = 'ready';
      for (const [scene, image] of images) {
        const transform = `translate3d(0, ${pose.y[scene].toFixed(3)}px, 0)`;
        const key = `${layers[scene]}:${transform}`;
        if (imageStates.get(image) !== key) {
          image.style.opacity = String(layers[scene]);
          image.style.transform = transform;
          imageStates.set(image, key);
        }
      }
      const active = decoded.at(-1) ?? lastGood ?? 'hero';
      if (field && field.dataset.activeScene !== active)
        field.dataset.activeScene = active;
    }
  }

  function itemPose(item: HTMLElement, role: MobileRole, chapter: string) {
    if (!phone.matches) return undefined;
    if (paused)
      return (
        poses.get(item) ?? mobileItemPose(0, 1, role, { stationary: true })
      );
    measure();
    const stationary =
      chapter === 'hero' ||
      (chapter === 'experience' && role !== 'heading') ||
      getComputedStyle(item).display === 'contents' ||
      !item.getClientRects().length;
    const pose = mobileItemPose(
      (tops.get(item) ?? documentTop(item)) - scrollY,
      height(),
      role,
      {
        reduced: options.reduced(),
        focused: item.contains(document.activeElement),
        stationary,
      },
    );
    poses.set(item, pose);
    return pose;
  }

  function syncDisclosures() {
    for (const detail of disclosures) {
      const keepFocus = detail.contains(document.activeElement);
      const open =
        !phone.matches || keepFocus || (expanded.get(detail) ?? false);
      if (detail.open !== open) {
        automaticToggle.add(detail);
        detail.open = open;
      }
    }
  }

  for (const detail of disclosures) {
    expanded.set(detail, false);
    listen(detail, 'toggle', () => {
      if (automaticToggle.has(detail)) automaticToggle.delete(detail);
      else if (phone.matches) expanded.set(detail, detail.open);
      invalidate();
      options.layoutChanged();
      options.requestUpdate();
    });
  }

  function mediaChanged() {
    // Native toggle events are queued. Preserve the actual disclosure state
    // before changing modes, even if rotation beats the pending user toggle.
    if (phoneMode)
      for (const detail of disclosures) expanded.set(detail, detail.open);
    phoneMode = phone.matches;
    syncDisclosures();
    invalidate();
    if (phone.matches) root.dataset.mobilePresentation = 'ready';
    else {
      delete root.dataset.mobilePresentation;
      delete root.dataset.mobileBackground;
      for (const item of localItems) {
        item.style.removeProperty('transform');
        item.style.removeProperty('opacity');
      }
    }
    options.layoutChanged();
    options.requestUpdate();
  }
  listen(phone, 'change', mediaChanged);
  const arm = () => {
    input = true;
    inputStart = scrollY;
  };
  listen(
    window,
    'wheel',
    ((event: WheelEvent) => {
      if (!event.ctrlKey && Math.abs(event.deltaY) > Math.abs(event.deltaX))
        arm();
    }) as EventListener,
    true,
  );
  listen(window, 'touchstart', arm, true);
  listen(window, 'pointerdown', arm, true);
  listen(window, 'keydown', ((event: KeyboardEvent) => {
    if (
      [
        'ArrowUp',
        'ArrowDown',
        'PageUp',
        'PageDown',
        'Home',
        'End',
        ' ',
      ].includes(event.key)
    )
      arm();
  }) as EventListener);
  listen(
    window,
    'scroll',
    () => {
      if (input && Math.abs(scrollY - inputStart) > 1) scrolled = true;
    },
    true,
  );
  listen(window, 'hashchange', () => options.requestUpdate());
  listen(
    window,
    'resize',
    () => {
      invalidate();
      options.requestUpdate();
    },
    true,
  );
  if (visualViewport)
    listen(visualViewport, 'resize', () => options.requestUpdate(), true);
  for (const image of document.images)
    listen(image, 'load', () => {
      invalidate();
      options.requestUpdate();
    });
  syncDisclosures();
  if (phone.matches) root.dataset.mobilePresentation = 'ready';

  return {
    update,
    itemPose,
    invalidate,
    setPaused(value: boolean) {
      paused = value;
      if (!paused) {
        invalidate();
        options.requestUpdate();
      }
    },
    dispose() {
      alive = false;
      listeners.abort();
      delete root.dataset.mobilePresentation;
      delete root.dataset.mobileBackground;
    },
  };
}
