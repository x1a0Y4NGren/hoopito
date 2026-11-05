import type { ChapterStop, createChapterScroll } from './chapter-scroll';
import { MobileTouchGesture } from './mobile-touch-math';

interface MobileTouchOptions {
  getStops(): readonly ChapterStop[];
  controller(): ReturnType<typeof createChapterScroll> | undefined;
  enabled(): boolean;
  requestUpdate(): void;
}

/** One finger supplies intent; the existing controller owns scroll and settling. */
export function createMobileTouch(options: MobileTouchOptions) {
  const listeners = new AbortController();
  const gesture = new MobileTouchGesture();
  let active:
    | {
        id: number;
        x: number;
        y: number;
        target: EventTarget | null;
        claimed: boolean;
        native: boolean;
      }
    | undefined;
  let alive = true;
  let healthy = true;
  let suppressedClickUntil = 0;
  let recoveryFrame = 0;
  let fingers = 0;
  let needsRecovery = false;

  const viewHeight = () =>
    Math.max(1, Math.min(innerHeight, visualViewport?.height ?? innerHeight));
  const enabled = () => alive && healthy && options.enabled();
  const listen = (
    target: EventTarget,
    type: string,
    handler: EventListener,
    config: AddEventListenerOptions = {},
  ) =>
    target.addEventListener(type, handler, {
      ...config,
      signal: listeners.signal,
    });

  function editable(target: EventTarget | null) {
    return (
      target instanceof Element &&
      !!target.closest(
        'input, textarea, select, [contenteditable]:not([contenteditable="false"]), dialog[open], .site-header, [data-chapter-rail]',
      )
    );
  }

  function selectedText() {
    const selection = window.getSelection();
    return !!selection && !selection.isCollapsed && !!selection.toString();
  }

  function nestedScroll(target: EventTarget | null, delta: number) {
    for (
      let node = target instanceof Element ? target : null;
      node && node !== document.body && node !== document.documentElement;
      node = node.parentElement
    ) {
      if (node.scrollHeight <= node.clientHeight + 1) continue;
      if (!/^(auto|scroll|overlay)$/.test(getComputedStyle(node).overflowY))
        continue;
      if (
        delta > 0
          ? node.scrollTop + node.clientHeight < node.scrollHeight - 1
          : node.scrollTop > 1
      )
        return true;
    }
    return false;
  }

  /** Cancels only a still-held sequence, never an unrelated new navigation. */
  function cancel() {
    cancelAnimationFrame(recoveryFrame);
    recoveryFrame = 0;
    if (active?.claimed) options.controller()?.cancel();
    active = undefined;
    gesture.cancel();
  }

  function fail() {
    cancel();
    healthy = false;
    document.documentElement.dataset.mobileTouch = 'fallback';
  }

  function inReadingRange() {
    return options
      .getStops()
      .some(
        (stop) =>
          Number.isFinite(stop.readStart) &&
          Number.isFinite(stop.readEnd) &&
          stop.readEnd >= stop.readStart &&
          scrollY >= stop.readStart - 2 &&
          scrollY <= stop.readEnd + 2,
      );
  }

  /** Yield click, focus and modal owners before returning an abandoned gap. */
  function recoverGap() {
    needsRecovery ||= !inReadingRange();
    cancelAnimationFrame(recoveryFrame);
    recoveryFrame = requestAnimationFrame(() => {
      recoveryFrame = 0;
      const controller = options.controller();
      if (
        !enabled() ||
        active ||
        fingers ||
        !controller ||
        controller.getMotion() ||
        document.querySelector('dialog[open]') ||
        (visualViewport?.scale ?? 1) > 1.01
      )
        return;
      if (inReadingRange()) {
        needsRecovery = false;
        return;
      }
      let nearest: { id: ChapterStop['id']; position: number } | undefined;
      let distance = Infinity;
      for (const stop of options.getStops()) {
        if (
          !Number.isFinite(stop.readStart) ||
          !Number.isFinite(stop.readEnd) ||
          stop.readEnd < stop.readStart
        )
          continue;
        const position = Math.max(
          stop.readStart,
          Math.min(stop.readEnd, scrollY),
        );
        const difference = Math.abs(position - scrollY);
        if (difference < distance) {
          nearest = { id: stop.id, position };
          distance = difference;
        }
      }
      if (
        nearest &&
        distance > 2 &&
        controller.navigateTo(nearest.id, {
          position: nearest.position,
          duration: 0.28,
        })
      )
        needsRecovery = false;
    });
  }

  function recoverCancelledTouch() {
    const held = active;
    if (held?.claimed && !held.native) needsRecovery = !inReadingRange();
    cancel();
    if (!fingers && needsRecovery) recoverGap();
  }

  function start(event: TouchEvent) {
    // The controller's earlier touchstart listener has already released any
    // prior wheel, navigation, drag or native-inertia ownership.
    fingers = event.touches.length;
    if (enabled() && !inReadingRange()) needsRecovery = true;
    if (fingers !== 1) return recoverCancelledTouch();
    suppressedClickUntil = 0;
    cancel();
    if (!enabled() || selectedText()) return;
    const finger = event.touches[0]!;
    if (
      finger.clientX < 20 ||
      finger.clientX > innerWidth - 20 ||
      editable(event.target)
    )
      return;
    if (
      !gesture.begin(
        options.getStops(),
        scrollY,
        { x: finger.clientX, y: finger.clientY },
        viewHeight(),
      )
    )
      return;
    active = {
      id: finger.identifier,
      x: finger.clientX,
      y: finger.clientY,
      target: event.target,
      claimed: false,
      native: false,
    };
  }

  function move(event: TouchEvent) {
    fingers = event.touches.length;
    const held = active;
    if (!held) return;
    if (!enabled() || event.touches.length !== 1 || selectedText()) {
      recoverCancelledTouch();
      return;
    }
    const finger = Array.from(event.touches).find(
      (touch) => touch.identifier === held.id,
    );
    if (!finger) return recoverCancelledTouch();
    const delta = held.y - finger.clientY;
    if (!held.claimed && nestedScroll(held.target, delta)) return cancel();
    const action = gesture.move(
      options.getStops(),
      { x: finger.clientX, y: finger.clientY },
      viewHeight(),
    );
    if (action.kind === 'pending') return;
    if (action.kind === 'ignored') return cancel();
    if (!action.source) return cancel();
    const controller = options.controller();
    if (!controller) return cancel();
    if (!held.claimed) {
      // If the browser has already claimed an uncancelable pan, contain the
      // current chapter instead of competing with its inertia or jumping ahead.
      held.native = action.kind === 'native' || !event.cancelable;
      let claimed = controller.beginTouch(action.source, {
        native: held.native,
      });
      if (!claimed && held.native && !event.cancelable) {
        const stop = options
          .getStops()
          .find((candidate) => candidate.id === action.source);
        if (stop) {
          controller.navigateTo(stop.id, {
            position: Math.max(stop.readStart, Math.min(stop.readEnd, scrollY)),
            instant: true,
          });
          claimed = controller.beginTouch(stop.id, { native: true });
        }
      }
      if (!claimed) return cancel();
      held.claimed = true;
    }
    suppressedClickUntil = performance.now() + 700;
    if (!held.native) {
      event.preventDefault();
      if (action.kind === 'preview') controller.moveTouch(action.position);
    }
    options.requestUpdate();
  }

  function end(event: TouchEvent) {
    fingers = event.touches.length;
    const held = active;
    if (!held) {
      if (!fingers && needsRecovery) recoverGap();
      return;
    }
    if (fingers) return recoverCancelledTouch();
    const released = Array.from(event.changedTouches ?? []).find(
      (touch) => touch.identifier === held.id,
    );
    if (held.claimed && released)
      gesture.move(
        options.getStops(),
        { x: released.clientX, y: released.clientY },
        viewHeight(),
      );
    const action = gesture.finish(options.getStops());
    active = undefined;
    if (!held.claimed) {
      if (action.kind === 'settle' || needsRecovery) recoverGap();
      return;
    }
    suppressedClickUntil = performance.now() + 700;
    const controller = options.controller();
    if (!enabled() || !controller) return controller?.cancel();
    if (held.native) controller.endTouch();
    else if (action.kind === 'settle')
      controller.endTouch({
        target: action.target,
        position: action.position,
        duration: action.duration,
      });
    else controller.endTouch({ duration: 0.28 });
    options.requestUpdate();
  }

  const safe =
    (handler: (event: TouchEvent) => void): EventListener =>
    (event) => {
      try {
        handler(event as TouchEvent);
      } catch {
        fail();
      }
    };
  try {
    listen(window, 'touchstart', safe(start), { passive: true });
    listen(window, 'touchmove', safe(move), { passive: false });
    listen(window, 'touchend', safe(end), { passive: true });
    listen(
      window,
      'touchcancel',
      safe((event) => {
        fingers = event.touches.length;
        recoverCancelledTouch();
      }),
      {
        passive: true,
      },
    );
    listen(
      window,
      'pointerdown',
      () => {
        suppressedClickUntil = 0;
      },
      { passive: true },
    );
    listen(
      window,
      'click',
      (event) => {
        const click = event as MouseEvent;
        if (
          click.isTrusted &&
          click.detail > 0 &&
          performance.now() < suppressedClickUntil
        ) {
          suppressedClickUntil = 0;
          event.preventDefault();
          event.stopImmediatePropagation();
        }
      },
      { capture: true },
    );
    listen(document, 'visibilitychange', () => {
      if (document.hidden) cancel();
    });
    document.documentElement.dataset.mobileTouch = 'ready';
  } catch {
    fail();
    listeners.abort();
  }
  return {
    refresh() {
      cancelAnimationFrame(recoveryFrame);
      recoveryFrame = 0;
      if (!active) {
        if (needsRecovery) recoverGap();
        return;
      }
      if (!enabled()) return cancel();
      try {
        gesture.refresh(options.getStops(), scrollY, viewHeight());
      } catch {
        fail();
      }
    },
    cancel,
    recoverGap,
    available: () => healthy,
    dispose() {
      cancel();
      alive = false;
      fingers = 0;
      needsRecovery = false;
      listeners.abort();
      delete document.documentElement.dataset.mobileTouch;
    },
  };
}
