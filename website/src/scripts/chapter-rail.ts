import type {
  ChapterStop,
  StopId,
  createChapterScroll,
} from './chapter-scroll';
import {
  createRailMap,
  liquidRailPose,
  railPosition,
  railReading,
  railScroll,
  type RailMapping,
} from './chapter-rail-math';

interface ChapterRailOptions {
  getStops(): readonly ChapterStop[];
  reduced(): boolean;
  canUse(): boolean;
  controller(): ReturnType<typeof createChapterScroll> | undefined;
  requestUpdate(): void;
  layoutChanged(): void;
  onNavigate?(id: StopId): void;
}

const clamp = (value: number, low: number, high: number) =>
  Math.min(high, Math.max(low, value));

/** This view shares the story's frame. It never owns a tween or an RAF loop. */
export function createChapterRail(options: ChapterRailOptions) {
  const root = document.documentElement;
  const element = document.querySelector<HTMLElement>(
    'aside[data-chapter-rail]',
  );
  const noRail = {
    refresh() {},
    update() {},
    setPaused(_paused: boolean) {},
    dispose() {},
  };
  if (!element) return noRail;
  const rail = element;
  const thumb = rail.querySelector<HTMLElement>('[data-rail-thumb]')!;

  const contactCircles = [
    ...rail.querySelectorAll<SVGCircleElement>('[data-liquid-contact]'),
  ];
  const filterAvailable =
    typeof SVGFEGaussianBlurElement === 'function' &&
    typeof SVGFEColorMatrixElement === 'function';
  rail.dataset.liquidMode = filterAvailable ? 'svg' : 'circle';
  const fill = rail.querySelector<HTMLElement>('[data-rail-fill]')!;
  const counter = rail.querySelector<HTMLElement>('[data-rail-counter]')!;
  const status = rail.querySelector<HTMLElement>('[data-rail-status]')!;
  const thumbTitle = rail.querySelector<HTMLElement>(
    '[data-rail-current-title]',
  )!;
  const nodes = [
    ...rail.querySelectorAll<HTMLAnchorElement>('[data-rail-node]'),
  ];
  const titles = nodes.map((node) =>
    node.querySelector('[data-rail-title]')!.textContent!.trim(),
  );
  const desktop = matchMedia('(min-width: 1024px) and (pointer: fine)');
  const forcedColors = matchMedia('(forced-colors: active)');
  const locale = rail.dataset.locale;
  let disposed = false;
  let failed = false;
  let ready = false;
  let paused = false;
  let mapping: RailMapping | undefined;
  let trackTop = 0;
  let previousGeometry = '';
  let layoutQueued = false;
  let previousY = scrollY;
  let lastDirection = 1;
  let announced = -1;
  let pointer:
    | {
        id: number;
        downY: number;
        lastY: number;
        grab: number;
        direction: number;
        dragging: boolean;
      }
    | undefined;
  let deferredRelease: { y: number; direction: number } | undefined;

  function layoutChanged() {
    if (layoutQueued || disposed) return;
    layoutQueued = true;
    queueMicrotask(() => {
      layoutQueued = false;
      if (!disposed) options.layoutChanged();
    });
  }

  function dismissTooltip() {
    rail.dataset.tooltipDismissed = 'true';
  }

  function releaseCapture() {
    const active = pointer;
    pointer = undefined;
    if (active && thumb.hasPointerCapture(active.id))
      thumb.releasePointerCapture(active.id);
    return active;
  }

  function abortPointer(defer = false) {
    const active = releaseCapture();
    if (!active) return;
    if (active.dragging) {
      if (defer) deferredRelease = { y: scrollY, direction: active.direction };
      options.controller()?.cancel();
    }
  }

  function enable(enabled: boolean) {
    if (ready === enabled) return;
    ready = enabled;
    if (!enabled) {
      abortPointer();
      deferredRelease = undefined;
      delete root.dataset.chapterRail;
      rail.hidden = true;
      rail.inert = true;
    } else {
      rail.hidden = false;
      rail.inert = paused;
      root.dataset.chapterRail = 'ready';
    }
    layoutChanged();
  }

  function fallback() {
    failed = true;
    enable(false);
    delete root.dataset.chapterRail;
    rail.hidden = true;
    root.dataset.railFallback = 'runtime';
  }

  function refresh() {
    if (disposed || failed) return;
    try {
      const stops = options.getStops();
      const headerBottom =
        document.querySelector('.site-header')?.getBoundingClientRect()
          .bottom ?? 0;
      // Reserve 32px for the counter and 24px beyond each end of the whole UI.
      const available = innerHeight - headerBottom - 80;
      const eligible =
        desktop.matches &&
        !forcedColors.matches &&
        available >= 400 &&
        stops.length === 7 &&
        !!options.controller() &&
        (options.canUse() || (paused && ready));
      if (!eligible) {
        enable(false);
        return;
      }
      const height = Math.min(
        Math.max(400, (innerHeight - headerBottom) * 0.75),
        available,
      );
      const top = headerBottom + (innerHeight - headerBottom - height - 32) / 2;
      const maxScroll = Math.max(0, root.scrollHeight - innerHeight);
      mapping = createRailMap(stops, height - 48, maxScroll);
      if (
        mapping.nodes.length !== 7 ||
        mapping.maxScroll <= 0 ||
        mapping.nodes.some(
          (node, i) =>
            i > 0 &&
            node.position - mapping!.nodes[i - 1]!.position < 48 - 0.01,
        )
      ) {
        enable(false);
        return;
      }
      const geometry = `${top}:${height}:${maxScroll}:${mapping.nodes
        .map((node) => `${node.id}:${node.scroll}:${node.position}`)
        .join('|')}`;
      trackTop = top;
      rail.style.top = `${top}px`;
      rail.style.setProperty('--rail-height', `${height}px`);
      for (const node of mapping.nodes) {
        const link = nodes.find((item) => item.dataset.railNode === node.id)!;
        link.parentElement!.style.transform = `translateY(${node.position}px)`;
      }
      thumb.setAttribute('aria-valuemax', String(Math.ceil(maxScroll)));
      enable(true);
      if (geometry !== previousGeometry) {
        previousGeometry = geometry;
        if (pointer?.dragging && !paused) drag(pointer.lastY);
      }
      update();
    } catch {
      fallback();
    }
  }

  function update() {
    if (disposed || !ready || !mapping || failed) return;
    try {
      const stops = options.getStops();
      const y = clamp(scrollY, 0, mapping.maxScroll);
      const reading = railReading(stops, y);
      const phase = reading.segment + reading.progress;
      const direction = Math.sign(y - previousY);
      if (direction) lastDirection = direction;
      const motion = options.controller()?.getMotion();
      const position = railPosition(mapping, y);
      const pose = liquidRailPose(
        position,
        mapping.nodes,
        options.reduced() || !filterAvailable,
      );
      for (const [index, circle] of contactCircles.entries()) {
        const contact = pose.contacts[index];
        circle.setAttribute('cy', String(contact?.y ?? 0));
        circle.setAttribute('r', String(contact?.radius ?? 0));
        if (contact) circle.dataset.node = String(contact.node);
        else delete circle.dataset.node;
      }
      rail.dataset.liquidActive = String(pose.contacts.length > 0);
      thumb.style.transform = `translateY(${position}px)`;
      fill.style.transform = `scaleY(${mapping.travel ? position / mapping.travel : 0})`;
      thumb.setAttribute('aria-valuenow', String(Math.round(y)));
      const index = clamp(reading.index, 0, nodes.length - 1);
      const number = String(index + 1).padStart(2, '0');
      counter.textContent = number;
      thumbTitle.textContent = `${number} ${titles[index]}`;
      const spoken =
        locale === 'zh'
          ? `第 ${index + 1} 页 共 7 页 ${titles[index]}`
          : `${titles[index]}, chapter ${index + 1} of 7`;
      thumb.setAttribute('aria-valuetext', spoken);
      nodes.forEach((node, i) => {
        if (i === index) node.setAttribute('aria-current', 'location');
        else node.removeAttribute('aria-current');
      });
      rail.dataset.current = String(index + 1);
      rail.dataset.phase = phase.toFixed(4);
      rail.dataset.state = paused
        ? 'paused'
        : pointer?.dragging
          ? 'dragging'
          : motion
            ? 'moving'
            : 'idle';
      if (
        reading.reading &&
        !motion &&
        !pointer?.dragging &&
        !paused &&
        announced !== index
      ) {
        announced = index;
        status.textContent = spoken;
      }
      previousY = y;
    } catch {
      fallback();
    }
  }

  function usable() {
    return ready && !paused && !disposed && !failed && options.canUse();
  }

  function click(event: MouseEvent) {
    const node =
      event.target instanceof Element
        ? event.target.closest<HTMLAnchorElement>('[data-rail-node]')
        : null;
    if (
      !node ||
      event.button ||
      event.metaKey ||
      event.ctrlKey ||
      event.shiftKey ||
      event.altKey
    )
      return;
    if (!usable()) return;
    event.preventDefault();
    event.stopPropagation();
    abortPointer();
    const id = node.dataset.railNode as StopId;
    options.onNavigate?.(id);
    options.controller()?.navigateTo(id, { instant: options.reduced() });
    options.requestUpdate();
  }

  function down(event: PointerEvent) {
    if (!usable() || event.button !== 0 || !event.isPrimary || !mapping) return;
    event.preventDefault();
    dismissTooltip();
    thumb.focus({ preventScroll: true });
    pointer = {
      id: event.pointerId,
      downY: event.clientY,
      lastY: event.clientY,
      grab: event.clientY - trackTop - 24 - railPosition(mapping, scrollY),
      direction: 0,
      dragging: false,
    };
    try {
      thumb.setPointerCapture(event.pointerId);
    } catch {
      abortPointer();
    }
  }

  function drag(clientY: number) {
    if (!pointer || !mapping || !usable()) return;
    const direction = Math.sign(clientY - pointer.lastY);
    if (direction) pointer.direction = direction;
    pointer.lastY = clientY;
    if (!pointer.dragging) {
      if (Math.abs(clientY - pointer.downY) <= 4) return;
      pointer.dragging = true;
      options.controller()?.beginDrag();
    }
    const position = clientY - trackTop - 24 - pointer.grab;
    options.controller()?.dragTo(railScroll(mapping, position));
    options.requestUpdate();
  }

  function move(event: PointerEvent) {
    if (pointer?.id === event.pointerId) drag(event.clientY);
  }

  function finish(event?: PointerEvent) {
    if (event && pointer?.id !== event.pointerId) return;
    const active = releaseCapture();
    if (active && usable()) {
      // Capture-phase keyboard cancellation may already have released the task.
      if (!options.controller()?.isDragging())
        options.controller()?.beginDrag();
      options.controller()?.endDrag(active.direction, options.reduced());
      options.requestUpdate();
    }
  }

  function keydown(event: KeyboardEvent) {
    if (event.key === 'Escape') {
      dismissTooltip();
      event.stopPropagation();
      if (pointer) {
        event.preventDefault();
        finish();
      } else if (usable()) {
        // The controller's capture listener already cancelled the old flight.
        // Finish on a readable interval instead of leaving the rail in its gap.
        options.controller()?.beginDrag();
        options.controller()?.endDrag(lastDirection, options.reduced());
        options.requestUpdate();
      }
      return;
    }
    if (event.target !== thumb || !usable() || !mapping) return;
    const keys = [
      'ArrowUp',
      'ArrowDown',
      'ArrowLeft',
      'ArrowRight',
      'PageUp',
      'PageDown',
      'Home',
      'End',
    ];
    if (
      !keys.includes(event.key) ||
      event.altKey ||
      event.ctrlKey ||
      event.metaKey
    )
      return;
    event.preventDefault();
    event.stopPropagation();
    abortPointer();
    const controller = options.controller();
    const stops = options.getStops();
    const state = railReading(stops, scrollY);
    const current = stops[state.index];
    const direction = /Up|Left/.test(event.key) ? -1 : 1;
    const step = event.key.startsWith('Page') ? innerHeight * 0.85 : 40;
    if (event.key === 'Home' || event.key === 'End') {
      const target = event.key === 'Home' ? stops[0] : stops.at(-1);
      if (target) {
        options.onNavigate?.(target.id);
        controller?.navigateTo(target.id, {
          instant: options.reduced(),
          position: event.key === 'End' ? target.readEnd : undefined,
        });
        // End also reaches the remaining natural reading tail.
        if (event.key === 'End' && state.index === stops.length - 1) {
          controller?.beginDrag();
          controller?.dragTo(mapping.maxScroll);
          controller?.endDrag(1, options.reduced());
        }
      }
    } else if (
      current &&
      state.reading &&
      (direction < 0
        ? scrollY > current.readStart + 2
        : scrollY < current.readEnd - 2)
    ) {
      controller?.beginDrag();
      controller?.dragTo(
        clamp(scrollY + direction * step, current.readStart, current.readEnd),
      );
      controller?.endDrag(direction, options.reduced());
    } else {
      const target = stops[clamp(state.index + direction, 0, stops.length - 1)];
      if (target) {
        options.onNavigate?.(target.id);
        controller?.navigateTo(target.id, { instant: options.reduced() });
      }
    }
    options.requestUpdate();
  }

  function clearTooltip() {
    delete rail.dataset.tooltipDismissed;
  }
  function dismissOnEscape(event: KeyboardEvent) {
    if (event.key !== 'Escape') return;
    dismissTooltip();
  }

  function takeOver() {
    if (pointer) abortPointer();
  }

  function blur() {
    if (pointer) abortPointer(true);
    dismissTooltip();
  }

  function resumeDeferred() {
    const release = deferredRelease;
    if (!release || paused || !ready || !options.canUse() || document.hidden)
      return;
    deferredRelease = undefined;
    if (Math.abs(scrollY - release.y) <= 2) {
      options.controller()?.beginDrag();
      options.controller()?.endDrag(release.direction, options.reduced());
    }
  }

  function focus() {
    resumeDeferred();
    options.requestUpdate();
  }

  function setPaused(value: boolean) {
    if (disposed || paused === value) return;
    paused = value;
    rail.inert = paused || !ready;
    if (paused) {
      dismissTooltip();
      abortPointer(true);
    } else {
      resumeDeferred();
      refresh();
    }
    update();
  }

  rail.addEventListener('click', click);
  rail.addEventListener('keydown', keydown);
  rail.addEventListener('pointerover', clearTooltip);
  rail.addEventListener('focusin', clearTooltip);
  thumb.addEventListener('pointerdown', down);
  thumb.addEventListener('pointermove', move);
  thumb.addEventListener('pointerup', finish);
  thumb.addEventListener('pointercancel', finish);
  thumb.addEventListener('lostpointercapture', finish);
  desktop.addEventListener('change', refresh);
  forcedColors.addEventListener('change', refresh);
  window.addEventListener('wheel', takeOver, { passive: true, capture: true });
  window.addEventListener('keydown', dismissOnEscape, true);
  window.addEventListener('blur', blur);
  window.addEventListener('focus', focus);
  refresh();

  return {
    refresh,
    update,
    setPaused,
    dispose() {
      if (disposed) return;
      abortPointer();
      disposed = true;
      ready = false;
      delete root.dataset.chapterRail;
      rail.hidden = true;
      rail.inert = true;
      rail.removeEventListener('click', click);
      rail.removeEventListener('keydown', keydown);
      rail.removeEventListener('pointerover', clearTooltip);
      rail.removeEventListener('focusin', clearTooltip);
      thumb.removeEventListener('pointerdown', down);
      thumb.removeEventListener('pointermove', move);
      thumb.removeEventListener('pointerup', finish);
      thumb.removeEventListener('pointercancel', finish);
      thumb.removeEventListener('lostpointercapture', finish);
      desktop.removeEventListener('change', refresh);
      forcedColors.removeEventListener('change', refresh);
      window.removeEventListener('wheel', takeOver, { capture: true });
      window.removeEventListener('keydown', dismissOnEscape, true);
      window.removeEventListener('blur', blur);
      window.removeEventListener('focus', focus);
    },
  };
}
