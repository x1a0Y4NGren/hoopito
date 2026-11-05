import assert from 'node:assert/strict';
import test from 'node:test';
import { gsap } from 'gsap';
import {
  ChapterGesture,
  createChapterScroll,
  createChapterPath,
  normalizeWheelDelta,
  type ChapterStop,
} from '../src/scripts/chapter-scroll.ts';

const stops: ChapterStop[] = [
  { id: 'hero', readStart: 0, readEnd: 0 },
  { id: 'scoring', readStart: 1000, readEnd: 1000 },
  { id: 'experience', readStart: 2000, readEnd: 2000 },
  { id: 'download', readStart: 3000, readEnd: 3600 },
  { id: 'closing', readStart: 4600, readEnd: 5000 },
];

test('wheel intent respects pixel, line and page units without accepting invalid input', () => {
  assert.equal(normalizeWheelDelta(12, 0, 800), 12);
  assert.equal(normalizeWheelDelta(3, 1, 800), 48);
  assert.equal(normalizeWheelDelta(-1, 2, 800), -800);
  assert.equal(normalizeWheelDelta(3, 1, 800, 20), 60);
  for (const value of [NaN, Infinity, -Infinity])
    assert.equal(normalizeWheelDelta(value, 0, 800), 0);
});

test('tiny wheel previews then returns to its reading stop only after quiet', () => {
  const gesture = new ChapterGesture();
  assert.deepEqual(gesture.input(20, 0, 1000, stops, 900), {
    kind: 'preview',
    y: 1020,
    stop: 'scoring',
  });
  assert.equal(gesture.rest(139), undefined);
  assert.deepEqual(gesture.rest(140), {
    kind: 'settle',
    y: 1000,
    duration: 0.28,
    stop: 'scoring',
  });
});

test('touchpad input resuming within180ms interrupts rollback and retains signed intent', () => {
  const gesture = new ChapterGesture();
  gesture.input(10, 979, 0, stops, 900);
  assert.equal(gesture.rest(1119)?.duration, 0.28);
  assert.deepEqual(gesture.input(8, 1151, 8, stops, 900), {
    kind: 'preview',
    y: 18,
    stop: 'hero',
  });
  assert.equal(gesture.rest(1291)?.duration, 0.28);
  assert.deepEqual(gesture.input(14, 1309, 15, stops, 900), {
    kind: 'settle',
    y: 1000,
    duration: 1.2,
    stop: 'scoring',
  });
  assert.equal(gesture.input(14, 1400, 100, stops, 900).kind, 'hold');
});

test('a new gesture after180ms interrupts rollback and starts a fresh intent total', () => {
  const gesture = new ChapterGesture();
  gesture.input(15, 0, 1000, stops, 900);
  gesture.rest(140);
  assert.deepEqual(gesture.input(15, 190, 1010, stops, 900), {
    kind: 'preview',
    y: 1025,
    stop: 'scoring',
  });
  assert.equal(gesture.rest(330)?.duration, 0.28);
});

test('threshold commits one adjacent chapter and large impulses do not skip stops', () => {
  for (const delta of [24, 25, 48, 120, 5000]) {
    const gesture = new ChapterGesture();
    assert.deepEqual(gesture.input(delta, 0, 1000, stops, 900), {
      kind: 'settle',
      y: 2000,
      duration: 1.2,
      stop: 'experience',
    });
  }
  const gesture = new ChapterGesture();
  assert.equal(gesture.input(23, 0, 1000, stops, 900).kind, 'preview');
  assert.equal(gesture.input(1, 30, 1023, stops, 900).kind, 'settle');
});

test('direction uses signed intent, so reversing a small preview can select the previous chapter', () => {
  const gesture = new ChapterGesture();
  gesture.input(12, 0, 1000, stops, 900);
  assert.deepEqual(gesture.input(-20, 30, 1012, stops, 900), {
    kind: 'preview',
    y: 992,
    stop: 'scoring',
  });
  assert.deepEqual(gesture.input(-16, 60, 992, stops, 900), {
    kind: 'settle',
    y: 0,
    duration: 1.2,
    stop: 'hero',
  });
});

test('committed motion consumes inertia without queuing and waits for completion plus quiet', () => {
  const gesture = new ChapterGesture();
  gesture.input(120, 0, 0, stops, 900);
  assert.equal(gesture.input(120, 100, 300, stops, 900).kind, 'hold');
  assert.equal(gesture.input(-120, 500, 700, stops, 900).kind, 'hold');
  assert.equal(gesture.input(10, 1020, 995, stops, 900).kind, 'hold');
  gesture.complete(1050);
  assert.equal(gesture.state, 'draining');
  assert.equal(gesture.input(4, 1100, 1000, stops, 900).kind, 'hold');
  gesture.release(1279);
  assert.equal(gesture.state, 'draining');
  gesture.release(1280);
  assert.equal(gesture.state, 'idle');
  assert.equal(gesture.input(48, 1290, 1000, stops, 900).kind, 'settle');
});

test('continued deliberate wheel pulses can leave a completed chapter without a quiet gap', () => {
  const gesture = new ChapterGesture();
  gesture.input(120, 0, 0, stops, 900);
  for (let now = 90; now < 1050; now += 90)
    assert.equal(gesture.input(120, now, 500, stops, 900).kind, 'hold');
  gesture.complete(1050);
  assert.equal(gesture.input(120, 1080, 1000, stops, 900).kind, 'hold');
  assert.equal(gesture.input(120, 1170, 1000, stops, 900).kind, 'hold');
  assert.deepEqual(gesture.input(120, 1260, 1000, stops, 900), {
    kind: 'settle',
    y: 2000,
    duration: 1.2,
    stop: 'experience',
  });
  for (let now = 1350; now < 2310; now += 90)
    assert.equal(gesture.input(120, now, 1500, stops, 900).kind, 'hold');
  gesture.complete(2310);
  // Samples during the animation never queue another chapter on completion.
  assert.equal(gesture.state, 'draining');
  assert.equal(gesture.stop, 'experience');
});

test('a long decaying or fine constant momentum tail never becomes another chapter', () => {
  for (const deltas of [
    [180, 160, 140, 120, 100, 80, 64, 48, 32, 24, 20, 16, 12, 8, 4, 2],
    Array<number>(30).fill(12),
  ]) {
    const gesture = new ChapterGesture();
    gesture.input(120, 0, 0, stops, 900);
    gesture.input(60, 1000, 950, stops, 900);
    gesture.complete(1050);
    for (const [index, delta] of deltas.entries())
      assert.equal(
        gesture.input(delta, 1080 + index * 90, 1000, stops, 900).kind,
        'hold',
      );
    assert.equal(gesture.stop, 'scoring');
  }
});

test('high-frequency small deltas from the user trace can rearm in either direction', () => {
  // The supplied six samples span21ms: 8,8,9,8,8,7px. Repeat that cadence to
  // test sustained input beyond landing; this is an extension, not a full trace.
  const samples = [8, 8, 9, 8, 8, 7];
  for (const direction of [-1, 1]) {
    for (let phase = 0; phase < samples.length; phase++) {
      const gesture = new ChapterGesture();
      gesture.input(direction * 24, 0, direction > 0 ? 0 : 2000, stops, 900);
      gesture.input(direction * 8, 1000, 1000, stops, 900);
      gesture.complete(1050);
      let action;
      for (let index = 0; index <= 100; index++) {
        action = gesture.input(
          direction * samples[(index + phase) % samples.length],
          1080 + index * 4,
          1000,
          stops,
          900,
        );
        if (action.kind === 'settle') break;
        assert.equal(action.kind, 'hold');
      }
      assert.equal(
        action?.kind,
        'settle',
        `small packets must not stay locked: direction${direction}, phase${phase}`,
      );
      assert.equal(gesture.stop, direction > 0 ? 'experience' : 'hero');
    }
  }
});

test('splitting the same sustained distance into smaller packets cannot suppress renewed intent', () => {
  for (const [delta, gap] of [
    [8, 4],
    [16, 8],
    [48, 24],
  ]) {
    const gesture = new ChapterGesture();
    gesture.input(-24, 0, 2000, stops, 900);
    gesture.input(-delta, 1000, 1000, stops, 900);
    gesture.complete(1050);
    let action;
    for (let elapsed = 0; elapsed <= 400; elapsed += gap) {
      action = gesture.input(-delta, 1080 + elapsed, 1000, stops, 900);
      if (action.kind === 'settle') break;
    }
    assert.deepEqual(action, {
      kind: 'settle',
      y: 0,
      duration: 1.2,
      stop: 'hero',
    });
  }
});

test('a dense decaying tail and a short fine plateau cannot become renewed intent', () => {
  for (const plateau of [false, true]) {
    const gesture = new ChapterGesture();
    gesture.input(-24, 0, 2000, stops, 900);
    gesture.input(-20, 1000, 1000, stops, 900);
    gesture.complete(1050);
    for (let index = 0; index < 220; index++) {
      const delta = plateau
        ? Math.max(0.25, 8 - Math.floor(Math.max(0, index - 30) / 8))
        : Math.max(0.25, 18 - Math.floor(index / 8));
      assert.equal(
        gesture.input(-delta, 1080 + index * 4, 1000, stops, 900).kind,
        'hold',
      );
    }
    assert.equal(gesture.stop, 'scoring');
  }
});

test('reflow and horizontal takeover discard a partial high-frequency intent window', () => {
  for (const reset of [
    (gesture: ChapterGesture) => gesture.remeasure(stops, 1000),
    (gesture: ChapterGesture) => gesture.keepAlive(1236),
  ]) {
    const gesture = new ChapterGesture();
    gesture.input(-24, 0, 2000, stops, 900);
    gesture.input(-8, 1000, 1000, stops, 900);
    gesture.complete(1050);
    for (let index = 0; index < 40; index++)
      assert.equal(
        gesture.input(-8, 1080 + index * 4, 1000, stops, 900).kind,
        'hold',
      );
    reset(gesture);
    for (let index = 0; index < 40; index++)
      assert.equal(
        gesture.input(-8, 1240 + index * 4, 1000, stops, 900).kind,
        'hold',
      );
    let action;
    for (let index = 0; index < 61; index++) {
      action = gesture.input(-8, 1400 + index * 4, 1000, stops, 900);
      if (action.kind === 'settle') break;
    }
    assert.equal(action?.kind, 'settle');
  }
});

test('a brief quantized plateau inside a decaying tail cannot rearm a chapter', () => {
  const gesture = new ChapterGesture();
  gesture.input(120, 0, 0, stops, 900);
  gesture.input(120, 1000, 950, stops, 900);
  gesture.complete(1050);
  for (const [now, delta] of [
    [1100, 80],
    [1190, 60],
    [1280, 40],
    [1370, 24],
    [1410, 24],
    [1450, 24],
    [1490, 20],
  ])
    assert.equal(gesture.input(delta, now, 1000, stops, 900).kind, 'hold');
  assert.equal(gesture.stop, 'scoring');
});

test('renewed input must persist after landing and cannot reuse pulses across a reversal', () => {
  const gesture = new ChapterGesture();
  gesture.input(120, 0, 0, stops, 900);
  gesture.input(120, 1000, 950, stops, 900);
  gesture.complete(1050);
  for (const now of [1060, 1080, 1100])
    assert.equal(gesture.input(120, now, 1000, stops, 900).kind, 'hold');
  assert.equal(gesture.input(-120, 1190, 1000, stops, 900).kind, 'hold');
  assert.equal(gesture.input(-120, 1280, 1000, stops, 900).kind, 'hold');
  assert.deepEqual(gesture.input(-120, 1370, 1000, stops, 900), {
    kind: 'settle',
    y: 0,
    duration: 1.2,
    stop: 'hero',
  });
});

test('reflow discards partial renewed input without discarding the completed chapter', () => {
  const gesture = new ChapterGesture();
  gesture.input(120, 0, 0, stops, 900);
  gesture.input(120, 1000, 950, stops, 900);
  gesture.complete(1050);
  gesture.input(120, 1080, 1000, stops, 900);
  gesture.input(120, 1170, 1000, stops, 900);
  assert.equal(gesture.remeasure(stops, 1000), true);
  assert.equal(gesture.input(120, 1260, 1000, stops, 900).kind, 'hold');
  assert.equal(gesture.input(120, 1350, 1000, stops, 900).kind, 'hold');
  assert.equal(gesture.input(120, 1440, 1000, stops, 900).kind, 'settle');
});

test('continued wheel pulses cannot skip the reading boundary of long content', () => {
  const gesture = new ChapterGesture();
  assert.equal(gesture.input(4000, 0, 3200, stops, 900).kind, 'boundary');
  for (let now = 90; now < 2000; now += 90)
    assert.equal(gesture.input(120, now, 3600, stops, 900).kind, 'hold');
  assert.equal(gesture.stop, 'download');
  assert.equal(gesture.input(24, 2200, 3600, stops, 900).kind, 'settle');
});

test('long content scrolls within its reading range and clamps before leaving on the same gesture', () => {
  const gesture = new ChapterGesture();
  assert.equal(gesture.input(200, 0, 3200, stops, 900).kind, 'native');
  assert.deepEqual(gesture.input(400, 20, 3400, stops, 900), {
    kind: 'boundary',
    y: 3600,
    stop: 'download',
  });
  assert.equal(gesture.input(120, 100, 3600, stops, 900).kind, 'hold');
  assert.deepEqual(gesture.input(48, 280, 3600, stops, 900), {
    kind: 'settle',
    y: 4600,
    duration: 1.2,
    stop: 'closing',
  });
});

test('upward handoff enters the previous long chapter at its bottom reading stop', () => {
  const gesture = new ChapterGesture();
  assert.deepEqual(gesture.input(-48, 0, 4600, stops, 900), {
    kind: 'settle',
    y: 3600,
    duration: 1.2,
    stop: 'download',
  });
});

test('a reversed native gesture can read back into the long chapter without leaving it', () => {
  const gesture = new ChapterGesture();
  gesture.input(200, 0, 3500, stops, 900);
  assert.equal(gesture.input(-100, 30, 3600, stops, 900).kind, 'native');
  assert.equal(gesture.input(48, 60, 3500, stops, 900).kind, 'native');
});

test('cancellation invalidates pending rollback or commit and releases ownership', () => {
  for (const delta of [20, 120]) {
    const gesture = new ChapterGesture();
    gesture.input(delta, 0, 1000, stops, 900);
    gesture.cancel();
    assert.equal(gesture.state, 'idle');
    assert.equal(gesture.rest(1000), undefined);
    assert.equal(gesture.input(-48, 2000, 2000, stops, 900).kind, 'settle');
  }
});

test('document edges stay natural and malformed stops cannot produce nonfinite writes', () => {
  const gesture = new ChapterGesture();
  assert.equal(gesture.input(-100, 0, 0, stops, 900).kind, 'native');
  gesture.cancel();
  assert.equal(gesture.input(100, 1000, 5000, stops, 900).kind, 'native');
  gesture.cancel();
  assert.equal(gesture.input(100, 2000, 0, [], 900).kind, 'native');
});

test('committed real scroll uses the cosine endpoint profile without obsolete pin landmarks', () => {
  const source = { ...stops[1], exitStart: 100, exitEnd: 500 };
  const target = { ...stops[2], entryStart: 750, entryEnd: 950 };
  const path = createChapterPath(0, 1000, source, target);
  assert.equal(path(0), 0);
  assert.equal(path(1), 1000);
  for (const p of [0.125, 0.365, 0.635, 0.875])
    assert.ok(
      Math.abs(path(p) - (1000 * (1 - Math.cos(Math.PI * p))) / 2) < 1e-9,
    );
  let previous = 0;
  for (let index = 1; index <= 1000; index++) {
    const y = path(index / 1000);
    assert.ok(y >= previous && y <= 1000);
    previous = y;
  }
  const epsilon = 1e-7;
  assert.ok(Math.abs((path(epsilon) - path(0)) / epsilon) < 0.001);
  assert.ok(Math.abs((path(1) - path(1 - epsilon)) / epsilon) < 0.001);
});

test('reverse endpoint motion remains bounded across unequal gaps', () => {
  const source = { ...stops[2], entryStart: 750, entryEnd: 950 };
  const target = { ...stops[1], exitStart: 100, exitEnd: 500 };
  const reverse = createChapterPath(1000, 0, source, target);
  const forward = createChapterPath(0, 1000, target, source);
  for (const p of [0.125, 0.365, 0.635, 0.875])
    assert.ok(Math.abs(reverse(p) - forward(1 - p)) < 1e-9);
  let previous = 1000;
  for (let index = 1; index <= 1000; index++) {
    const y = reverse(index / 1000);
    assert.ok(y <= previous && y >= 0);
    previous = y;
  }
  const fallback = createChapterPath(
    50,
    5000,
    { ...source, exitStart: NaN, exitEnd: -100 },
    { ...target, entryStart: 1e9 },
  );
  assert.equal(fallback(0), 50);
  assert.equal(fallback(1), 5000);
  assert.equal(fallback(NaN), 50);
});

test('hero approach and return share a generous symmetric timing without speeding through visible exits', () => {
  const hero = { ...stops[0], exitStart: 100, exitEnd: 500 };
  const scoring = { ...stops[1], entryStart: 750, entryEnd: 950 };
  const forward = createChapterPath(0, 1000, hero, scoring);
  const reverse = createChapterPath(1000, 0, scoring, hero);
  let previous = 0;
  for (let index = 1; index <= 1000; index++) {
    const p = index / 1000;
    const y = forward(p);
    assert.ok(y >= previous && y <= 1000);
    assert.ok(Math.abs(y - reverse(1 - p)) < 1e-9);
    previous = y;
  }
});

test('an external seek before the first preview RAF cannot be overwritten by that pending preview', () => {
  const keys = [
    'window',
    'document',
    'Element',
    'innerHeight',
    'scrollY',
    'requestAnimationFrame',
    'cancelAnimationFrame',
  ] as const;
  const original = keys.map(
    (key) => [key, Object.getOwnPropertyDescriptor(globalThis, key)] as const,
  );
  const listeners = new Map<string, (event: unknown) => void>();
  const frames = new Map<number, FrameRequestCallback>();
  let next = 0;
  const writes: number[] = [];
  const stub = {
    addEventListener: (name: string, listener: (event: unknown) => void) =>
      listeners.set(name, listener),
    removeEventListener: (name: string) => listeners.delete(name),
  };
  const globals = {
    window: stub,
    document: {
      ...stub,
      documentElement: { scrollHeight: 6000 },
      body: {},
      hidden: false,
    },
    Element: class {},
    innerHeight: 900,
    scrollY: 0,
    requestAnimationFrame: (callback: FrameRequestCallback) => {
      frames.set(++next, callback);
      return next;
    },
    cancelAnimationFrame: (id: number) => frames.delete(id),
  };
  for (const [key, value] of Object.entries(globals))
    Object.defineProperty(globalThis, key, {
      configurable: true,
      writable: true,
      value,
    });
  const controller = createChapterScroll({
    getStops: () => stops,
    enabled: () => true,
    write: (y) => writes.push(y),
  });
  try {
    let prevented = false;
    listeners.get('wheel')!({
      deltaY: 10,
      deltaX: 0,
      deltaMode: 0,
      cancelable: true,
      preventDefault() {
        prevented = true;
      },
    });
    assert.equal(prevented, true);
    assert.equal(frames.size, 1);
    Object.defineProperty(globalThis, 'scrollY', {
      configurable: true,
      writable: true,
      value: 1600,
    });
    for (const callback of [...frames.values()]) callback(0);
    assert.deepEqual(writes, []);
  } finally {
    controller.dispose();
    for (const [key, descriptor] of original) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor);
      else Reflect.deleteProperty(globalThis, key);
    }
  }
});

function withAdapter(
  run: (adapter: {
    controller: ReturnType<typeof createChapterScroll>;
    wheel(deltaY: number, extra?: Record<string, unknown>): void;
    move(y: number): void;
    flush(): void;
    latestTween(): gsap.core.Tween;
    states: string[];
    writes: number[];
    stops: ChapterStop[];
    emit(name: string, event?: unknown): void;
  }) => void,
  options: { enabled?(): boolean; canNavigate?(): boolean } = {},
) {
  const keys = [
    'window',
    'document',
    'Element',
    'innerHeight',
    'scrollY',
    'requestAnimationFrame',
    'cancelAnimationFrame',
  ] as const;
  const original = keys.map(
    (key) => [key, Object.getOwnPropertyDescriptor(globalThis, key)] as const,
  );
  const listeners = new Map<string, (event?: unknown) => void>();
  const frames = new Map<number, FrameRequestCallback>();
  const states: string[] = [],
    writes: number[] = [];
  const ranges = stops.map((stop) => ({ ...stop }));
  let next = 0;
  const stub = {
    addEventListener: (name: string, fn: (event?: unknown) => void) =>
      listeners.set(name, fn),
    removeEventListener: (name: string) => listeners.delete(name),
  };
  const globals = {
    window: stub,
    document: {
      ...stub,
      documentElement: { scrollHeight: 10000 },
      body: {},
      hidden: false,
    },
    Element: class {},
    innerHeight: 900,
    scrollY: 0,
    requestAnimationFrame: (fn: FrameRequestCallback) => {
      frames.set(++next, fn);
      return next;
    },
    cancelAnimationFrame: (id: number) => frames.delete(id),
  };
  for (const [key, value] of Object.entries(globals))
    Object.defineProperty(globalThis, key, {
      configurable: true,
      writable: true,
      value,
    });
  const controller = createChapterScroll({
    getStops: () => ranges,
    enabled: options.enabled ?? (() => true),
    canNavigate: options.canNavigate,
    write(y) {
      writes.push(y);
      Reflect.set(globalThis, 'scrollY', y);
    },
    onState: (state) => states.push(state),
  });
  try {
    run({
      controller,
      states,
      writes,
      stops: ranges,
      emit(name, event) {
        listeners.get(name)?.(event);
      },
      wheel(deltaY, extra = {}) {
        listeners.get('wheel')!({
          deltaY,
          deltaX: 0,
          deltaMode: 0,
          cancelable: true,
          preventDefault() {},
          ...extra,
        });
      },
      move(y) {
        Reflect.set(globalThis, 'scrollY', y);
        listeners.get('scroll')!();
      },
      flush() {
        const pending = [...frames.values()];
        frames.clear();
        for (const fn of pending) fn(performance.now());
      },
      latestTween() {
        const tweens = gsap.globalTimeline.getChildren(false, true, false);
        assert.ok(tweens.length);
        return tweens.at(-1) as gsap.core.Tween;
      },
    });
  } finally {
    controller.dispose();
    for (const [key, descriptor] of original) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor);
      else Reflect.deleteProperty(globalThis, key);
    }
  }
}

test('phone touch preview and release share navigation without enabling the desktop wheel', () => {
  withAdapter(
    (adapter) => {
      assert.equal(adapter.controller.beginTouch('hero'), true);
      assert.equal(adapter.states.at(-1), 'tracking');
      adapter.controller.moveTouch(23);
      assert.equal(scrollY, 23);
      adapter.controller.endTouch({ target: 'scoring', duration: 1.2 });
      const tween = adapter.latestTween();
      assert.equal(tween.duration(), 1.2);
      assert.equal(adapter.states.at(-1), 'settling');
      assert.equal(adapter.controller.getMotion()?.target, 'scoring');
      tween.progress(0.5);
      assert.ok(Math.abs(scrollY - 511.5) < 1e-9);
      tween.progress(1);
      assert.equal(scrollY, 1000);
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('native phone reading and its inertia cannot leave the source reading range', () => {
  withAdapter(
    (adapter) => {
      adapter.move(3300);
      assert.equal(
        adapter.controller.beginTouch('download', { native: true }),
        true,
      );
      adapter.move(3400);
      assert.deepEqual(adapter.writes, []);
      adapter.emit('scrollend');
      assert.equal(
        adapter.states.at(-1),
        'tracking',
        'a held finger still owns reading',
      );
      adapter.move(4200);
      assert.equal(scrollY, 3600);
      assert.equal(adapter.controller.getMotion(), undefined);
      adapter.controller.endTouch();
      assert.equal(adapter.states.at(-1), 'draining');
      adapter.move(3900);
      assert.equal(scrollY, 3600);
      adapter.emit('scrollend');
      assert.equal(adapter.states.at(-1), 'idle');
      adapter.move(4000);
      assert.equal(
        scrollY,
        4000,
        'an unrelated seek is free after native scrolling ends',
      );
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('native phone reading uses updated bounds after refresh without inventing another chapter', () => {
  withAdapter(
    (adapter) => {
      adapter.move(3300);
      adapter.controller.beginTouch('download', { native: true });
      adapter.controller.prepareRefresh();
      adapter.stops[3].readEnd = 3800;
      adapter.controller.refresh();
      adapter.flush();
      adapter.move(3750);
      assert.equal(scrollY, 3750);
      adapter.move(4100);
      assert.equal(scrollY, 3800);
      assert.equal(adapter.controller.getMotion(), undefined);
      assert.equal(adapter.states.at(-1), 'tracking');
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('phone ownership releases after120ms quiet only once the finger is lifted', (context) => {
  context.mock.timers.enable({ apis: ['setTimeout'] });
  withAdapter(
    (adapter) => {
      adapter.move(3300);
      adapter.controller.beginTouch('download', { native: true });
      context.mock.timers.tick(500);
      assert.equal(adapter.states.at(-1), 'tracking');
      adapter.controller.endTouch();
      context.mock.timers.tick(119);
      assert.equal(adapter.states.at(-1), 'draining');
      adapter.move(3400);
      context.mock.timers.tick(119);
      assert.equal(adapter.states.at(-1), 'draining');
      context.mock.timers.tick(1);
      assert.equal(adapter.states.at(-1), 'idle');
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('manual touch reflow keeps the latest preview and resumes its selected navigation target', () => {
  withAdapter(
    (adapter) => {
      adapter.controller.beginTouch('hero');
      adapter.controller.moveTouch(18);
      adapter.controller.prepareRefresh();
      adapter.controller.moveTouch(22);
      assert.equal(scrollY, 18);
      adapter.stops[1].readStart = 1200;
      adapter.stops[1].readEnd = 1200;
      adapter.controller.endTouch({ target: 'scoring', duration: 1.2 });
      adapter.controller.refresh();
      adapter.flush();
      assert.equal(scrollY, 22);
      assert.equal(adapter.controller.getMotion()?.target, 'scoring');
      adapter.latestTween().progress(0.55);
      adapter.controller.prepareRefresh();
      adapter.stops[1].readStart = 1300;
      adapter.stops[1].readEnd = 1300;
      adapter.controller.refresh();
      adapter.flush();
      const tail = adapter.latestTween();
      assert.ok(tail.duration() < 1.2);
      tail.progress(1);
      assert.equal(scrollY, 1300);
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('a light phone release returns to its original reading edge with the shared280ms curve', () => {
  withAdapter(
    (adapter) => {
      adapter.move(3600);
      adapter.controller.beginTouch('download');
      adapter.controller.moveTouch(3623);
      adapter.controller.endTouch({
        target: 'download',
        position: 3600,
        duration: 0.28,
      });
      const tween = adapter.latestTween();
      assert.equal(tween.duration(), 0.28);
      assert.equal(
        scrollY,
        3623,
        'release must continue from the current preview',
      );
      tween.progress(0.5);
      assert.equal(scrollY, 3611.5);
      tween.progress(1);
      assert.equal(scrollY, 3600);
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('a pending native quiet timeout cannot cancel a new touch or explicit destination', (context) => {
  context.mock.timers.enable({ apis: ['setTimeout'] });
  withAdapter(
    (adapter) => {
      adapter.move(3300);
      adapter.controller.beginTouch('download', { native: true });
      adapter.controller.endTouch();
      context.mock.timers.tick(100);
      adapter.controller.beginTouch('download');
      context.mock.timers.tick(21);
      assert.equal(adapter.states.at(-1), 'tracking');
      adapter.controller.endTouch({ target: 'closing', duration: 1.2 });
      const tween = adapter.latestTween();
      context.mock.timers.tick(200);
      assert.equal(adapter.controller.getMotion()?.target, 'closing');
      tween.progress(1);
      assert.equal(scrollY, 4600);
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('finger release during native refresh resumes bounded inertia and its quiet fallback', (context) => {
  context.mock.timers.enable({ apis: ['setTimeout'] });
  withAdapter(
    (adapter) => {
      adapter.move(3500);
      adapter.controller.beginTouch('download', { native: true });
      adapter.controller.prepareRefresh();
      adapter.controller.endTouch();
      context.mock.timers.tick(200);
      assert.equal(adapter.states.at(-1), 'draining');
      adapter.stops[3].readEnd = 3700;
      adapter.controller.refresh();
      adapter.flush();
      adapter.move(4000);
      assert.equal(scrollY, 3700);
      context.mock.timers.tick(120);
      assert.equal(adapter.states.at(-1), 'idle');
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('removing a native touch source or cancelling a queued release does not resurrect the old owner', () => {
  withAdapter(
    (adapter) => {
      adapter.move(3500);
      adapter.controller.beginTouch('download', { native: true });
      adapter.controller.prepareRefresh();
      adapter.stops.splice(3, 1);
      adapter.controller.refresh();
      adapter.flush();
      assert.equal(adapter.states.at(-1), 'idle');
      adapter.move(4000);
      assert.equal(scrollY, 4000);
      adapter.move(0);
      adapter.controller.beginTouch('hero');
      adapter.controller.moveTouch(20);
      adapter.controller.prepareRefresh();
      adapter.controller.endTouch({ target: 'scoring', duration: 1.2 });
      adapter.controller.cancel();
      adapter.controller.refresh();
      adapter.flush();
      assert.equal(adapter.controller.getMotion(), undefined);
      assert.equal(adapter.states.at(-1), 'idle');
    },
    { enabled: () => false, canNavigate: () => true },
  );
});

test('fresh input, navigation, pause eligibility and disposal cancel an old touch owner', () => {
  let active = true;
  withAdapter(
    (adapter) => {
      for (const event of ['pointerdown', 'touchstart', 'keydown']) {
        adapter.controller.beginTouch('hero');
        adapter.controller.moveTouch(12);
        adapter.emit(event);
        const count = adapter.writes.length;
        adapter.controller.moveTouch(25);
        assert.equal(adapter.writes.length, count, event);
        assert.equal(adapter.states.at(-1), 'idle');
      }
      assert.equal(adapter.controller.beginTouch('missing' as 'hero'), false);
      adapter.controller.beginTouch('hero');
      adapter.controller.navigateTo('experience');
      const count = adapter.writes.length;
      adapter.controller.moveTouch(30);
      assert.equal(adapter.writes.length, count);
      assert.equal(adapter.controller.getMotion()?.target, 'experience');
      adapter.controller.cancel();
      adapter.controller.beginTouch('hero');
      active = false;
      adapter.controller.moveTouch(35);
      assert.equal(adapter.states.at(-1), 'idle');
      assert.equal(adapter.controller.beginTouch('hero'), false);
      active = true;
      adapter.controller.dispose();
      assert.equal(adapter.controller.beginTouch('hero'), false);
    },
    { enabled: () => false, canNavigate: () => active },
  );
});

test('incidental zero and horizontal samples cannot cancel a committed transition', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    adapter.latestTween().progress(0.25);
    adapter.wheel(0);
    adapter.wheel(1, { deltaX: 20 });
    assert.equal(adapter.states.at(-1), 'settling');
    adapter.latestTween().progress(1);
    assert.equal(adapter.writes.at(-1), 1000);
  });
});

test('23px preview commits at24px from the actual preview position without a first-frame jump', () => {
  withAdapter((adapter) => {
    adapter.wheel(23);
    adapter.flush();
    assert.equal(scrollY, 23);
    assert.equal(adapter.states.at(-1), 'tracking');
    adapter.wheel(1);
    const tween = adapter.latestTween();
    assert.equal(tween.duration(), 1.2);
    assert.equal(scrollY, 23);
    tween.progress(0.5);
    assert.ok(Math.abs(scrollY - 511.5) < 1e-9);
    tween.progress(1);
    assert.equal(scrollY, 1000);
  });
});

test('an uncancelable vertical tail permits only its associated bounded native scroll', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    const tween = adapter.latestTween();
    tween.progress(0.25);
    const before = adapter.writes.at(-1)!;
    adapter.wheel(16, { cancelable: false });
    assert.equal(adapter.states.at(-1), 'settling');
    adapter.move(before + 16);
    assert.equal(adapter.states.at(-1), 'settling');
    tween.progress(0.5);
    // The native allowance was consumed; an unrelated seek still cancels.
    adapter.move(1600);
    assert.equal(adapter.states.at(-1), 'idle');
    const count = adapter.writes.length;
    tween.progress(1);
    assert.equal(adapter.writes.length, count);
  });
});

test('a known native tail delivered after completion reasserts the chosen landing, not an intermediate position', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    const tween = adapter.latestTween();
    tween.progress(0.95);
    adapter.wheel(16, { cancelable: false });
    tween.progress(1);
    assert.equal(adapter.writes.at(-1), 1000);
    adapter.move(1016);
    adapter.flush();
    assert.equal(adapter.writes.at(-1), 1000);
    assert.equal(scrollY, 1000);
    assert.equal(adapter.states.at(-1), 'draining');
  });
});

test('a manual seek overrides a queued landing confirmation after a native tail', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    const tween = adapter.latestTween();
    tween.progress(0.95);
    adapter.wheel(16, { cancelable: false });
    tween.progress(1);
    adapter.move(1016);
    adapter.move(1700);
    const count = adapter.writes.length;
    adapter.flush();
    assert.equal(adapter.states.at(-1), 'idle');
    assert.equal(adapter.writes.length, count);
    assert.equal(scrollY, 1700);
  });
});

test('a real layout refresh preserves the committed target and resumes at its new reading coordinate', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    adapter.latestTween().progress(0.4);
    adapter.controller.prepareRefresh();
    adapter.controller.prepareRefresh();
    assert.equal(adapter.states.at(-1), 'settling');
    adapter.stops[1].readStart = adapter.stops[1].readEnd = 1400;
    adapter.move(300); // pin restoration while refresh owns geometry
    adapter.controller.refresh();
    adapter.flush();
    assert.equal(adapter.states.at(-1), 'settling');
    const resumed = adapter.latestTween();
    assert.ok(resumed.duration() >= 0.2 && resumed.duration() < 1.2);
    resumed.progress(1);
    assert.equal(adapter.writes.at(-1), 1400);
  });
});

test('unchanged refresh keeps the original cosine tail, velocity and remaining time at20/55/90 percent', () => {
  for (const direction of [1, -1])
    for (const progress of [0.2, 0.55, 0.9])
      withAdapter((adapter) => {
        const origin = direction > 0 ? 0 : 2000;
        adapter.move(origin);
        adapter.wheel(direction * 24);
        adapter.latestTween().progress(progress);
        const before = scrollY;
        adapter.controller.prepareRefresh();
        adapter.controller.refresh();
        adapter.flush();
        const resumed = adapter.latestTween();
        assert.ok(Math.abs(resumed.duration() - 1.2 * (1 - progress)) < 1e-10);
        resumed.progress(0);
        assert.ok(Math.abs(scrollY - before) < 1e-9);
        for (const tail of [0.0001, 0.1, 0.5, 0.9]) {
          resumed.progress(tail);
          const stage = progress + (1 - progress) * tail;
          const expected =
            origin + ((1000 - origin) * (1 - Math.cos(Math.PI * stage))) / 2;
          assert.ok(
            Math.abs(scrollY - expected) < 1e-6,
            `same profile at ${progress}/${tail}`,
          );
        }
        resumed.progress(1);
        assert.equal(scrollY, 1000);
      });
});

test('changed geometry retargets actual scroll with a feasible incoming tangent and a bounded still endpoint', () => {
  for (const direction of [1, -1])
    for (const progress of [0.2, 0.55, 0.9])
      withAdapter((adapter) => {
        const origin = direction > 0 ? 0 : 2000;
        adapter.move(origin);
        adapter.wheel(direction * 24);
        adapter.latestTween().progress(progress);
        adapter.controller.prepareRefresh();
        const from = scrollY + direction * 5; // native pin restoration
        adapter.move(from);
        const destination = direction > 0 ? 1400 : 800;
        adapter.stops[1].readStart = adapter.stops[1].readEnd = destination;
        adapter.controller.refresh();
        adapter.flush();
        const resumed = adapter.latestTween();
        const remaining = 1.2 * (1 - progress);
        assert.ok(Math.abs(resumed.duration() - remaining) < 1e-10);
        resumed.progress(0);
        assert.equal(scrollY, from);
        const epsilon = 1e-6;
        resumed.progress(epsilon);
        const speed = (scrollY - from) / (epsilon * remaining);
        const incoming =
          ((((1000 - origin) * Math.PI) / 2) * Math.sin(Math.PI * progress)) /
          1.2;
        assert.ok(
          Math.abs(speed - incoming) < 0.2,
          `feasible tangent at ${progress}: ${speed} vs ${incoming}`,
        );
        let previous = from;
        for (let step = 1; step < 100; step++) {
          resumed.progress(step / 100);
          assert.ok(direction * (scrollY - previous) >= 0);
          assert.ok(direction * (destination - scrollY) >= 0);
          previous = scrollY;
        }
        resumed.progress(1 - epsilon);
        const beforeEnd = scrollY;
        resumed.progress(1);
        assert.equal(scrollY, destination);
        assert.ok(
          Math.abs((destination - beforeEnd) / (epsilon * remaining)) < 0.2,
        );
      });
});

test('repeated unchanged refreshes preserve global profile stage and never extend the late tail', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    adapter.latestTween().progress(0.2);
    for (const globalStage of [0.55, 0.9]) {
      adapter.controller.prepareRefresh();
      adapter.controller.refresh();
      adapter.flush();
      const resumed = adapter.latestTween();
      const start = 1 - resumed.duration() / 1.2;
      resumed.progress((globalStage - start) / (1 - start));
      assert.ok(
        Math.abs(scrollY - (1000 * (1 - Math.cos(Math.PI * globalStage))) / 2) <
          0.001,
      );
    }
    adapter.controller.prepareRefresh();
    adapter.controller.refresh();
    adapter.flush();
    assert.ok(Math.abs(adapter.latestTween().duration() - 0.12) < 1e-6);
    adapter.latestTween().progress(1);
    assert.equal(scrollY, 1000);
  });
});

test('collapsed remaining distance prioritizes bounded landing over an infeasible old tangent', () => {
  for (const direction of [1, -1])
    withAdapter((adapter) => {
      adapter.move(direction > 0 ? 0 : 2000);
      adapter.wheel(direction * 24);
      adapter.latestTween().progress(0.55);
      const from = scrollY;
      adapter.controller.prepareRefresh();
      const destination = from + direction * 3;
      adapter.stops[1].readStart = adapter.stops[1].readEnd = destination;
      adapter.controller.refresh();
      adapter.flush();
      const resumed = adapter.latestTween();
      let previous = from;
      for (let step = 1; step <= 100; step++) {
        resumed.progress(step / 100);
        assert.ok(direction * (scrollY - previous) >= -1e-9);
        assert.ok(direction * (destination - scrollY) >= -1e-9);
        previous = scrollY;
      }
      assert.equal(scrollY, destination);
    });
});

test('a reflow moving the chosen edge behind the current position retains that target and bounds its corrective tail', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    adapter.latestTween().progress(0.55);
    const from = scrollY;
    adapter.controller.prepareRefresh();
    adapter.stops[1].readStart = from - 100;
    adapter.stops[1].readEnd = from - 50;
    adapter.controller.refresh();
    adapter.flush();
    const resumed = adapter.latestTween();
    let previous = from;
    for (let step = 1; step <= 100; step++) {
      resumed.progress(step / 100);
      assert.ok(scrollY <= previous && scrollY >= adapter.stops[1].readStart);
      previous = scrollY;
    }
    assert.equal(scrollY, adapter.stops[1].readStart);
  });
});

test('refresh already inside the committed target reading range completes without pulling to its edge', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    adapter.latestTween().progress(0.55);
    const position = scrollY;
    const writes = adapter.writes.length;
    adapter.controller.prepareRefresh();
    adapter.stops[1].readStart = position - 50;
    adapter.stops[1].readEnd = position + 150;
    adapter.controller.refresh();
    adapter.flush();
    assert.equal(scrollY, position);
    assert.equal(adapter.writes.length, writes);
    assert.ok(
      adapter.states.at(-1) === 'draining' || adapter.states.at(-1) === 'idle',
    );
  });
});

test('manual cancellation overrides a queued layout-refresh resume', () => {
  for (const progress of [0.2, 0.55, 0.9])
    withAdapter((adapter) => {
      adapter.wheel(24);
      const original = adapter.latestTween();
      original.progress(progress);
      adapter.controller.prepareRefresh();
      adapter.controller.refresh();
      adapter.controller.cancel();
      const count = adapter.writes.length;
      adapter.move(1800);
      adapter.flush();
      original.progress(1); // a stale tween callback cannot regain ownership
      assert.equal(adapter.states.at(-1), 'idle');
      assert.equal(adapter.writes.length, count);
    });
});

test('an uncancelable first vertical wheel commits the adjacent chapter despite native displacement', () => {
  withAdapter((adapter) => {
    adapter.wheel(24, { cancelable: false });
    assert.equal(adapter.states.at(-1), 'settling');
    const tween = adapter.latestTween();
    adapter.move(24);
    tween.progress(1);
    assert.equal(adapter.writes.at(-1), 1000);
  });
});

test('uncancelable samples count toward intent after the first cancelable preview', () => {
  withAdapter((adapter) => {
    adapter.wheel(8);
    adapter.wheel(8, { cancelable: false });
    // Browser default scroll can arrive before the first owned preview RAF.
    adapter.move(8);
    adapter.flush();
    assert.equal(adapter.states.at(-1), 'tracking');
    assert.equal(adapter.writes.at(-1), 16);
    adapter.wheel(8, { cancelable: false });
    assert.equal(adapter.states.at(-1), 'settling');
    adapter.move(24);
    adapter.latestTween().progress(1);
    assert.equal(adapter.writes.at(-1), 1000);
  });
});

test('an uncancelable gesture cannot skip unread long content or overshoot its reading boundary', () => {
  withAdapter((adapter) => {
    adapter.move(3200);
    adapter.wheel(16, { cancelable: false });
    assert.equal(adapter.states.at(-1), 'idle');
    assert.deepEqual(adapter.writes, []);
    adapter.move(3550);
    adapter.wheel(100, { cancelable: false });
    assert.equal(adapter.states.at(-1), 'draining');
    assert.equal(adapter.writes.at(-1), 3600);
    adapter.move(3700);
    adapter.flush();
    assert.equal(scrollY, 3600);
    adapter.wheel(24, { cancelable: false });
    assert.equal(adapter.states.at(-1), 'draining');
    assert.equal(adapter.writes.at(-1), 3600);
  });
});

test('uncancelable input still respects zoom takeover', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    adapter.latestTween().progress(0.2);
    adapter.wheel(4, { ctrlKey: true, cancelable: false });
    assert.equal(adapter.states.at(-1), 'idle');
  });
});

test('an idle refresh does not intercept native input or invent a nearest-stop animation', () => {
  withAdapter((adapter) => {
    adapter.controller.prepareRefresh();
    adapter.wheel(12, {
      preventDefault() {
        assert.fail('Idle reflow cannot own the wheel');
      },
    });
    adapter.move(123);
    adapter.controller.refresh();
    adapter.flush();
    assert.equal(adapter.states.at(-1), 'idle');
    assert.deepEqual(adapter.writes, []);
  });
});

test('reverse layout retargeting uses the same previous chapter bottom, not its top or nearest stop', () => {
  withAdapter((adapter) => {
    adapter.move(4600);
    adapter.wheel(-24);
    adapter.latestTween().progress(0.4);
    adapter.controller.prepareRefresh();
    adapter.stops[3].readEnd = 3800;
    adapter.controller.refresh();
    adapter.flush();
    adapter.latestTween().progress(1);
    assert.equal(adapter.writes.at(-1), 3800);
  });
});

test('refresh cancellation cannot resume a chapter that disappeared from the new layout', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    adapter.latestTween().progress(0.2);
    adapter.controller.prepareRefresh();
    adapter.stops.splice(1, 1);
    adapter.controller.refresh();
    adapter.flush();
    assert.equal(adapter.states.at(-1), 'idle');
  });
});

test('rail navigation owns the existing cosine scroll task and preserves its real starting position', () => {
  withAdapter((adapter) => {
    adapter.move(23);
    assert.equal(adapter.controller.navigateTo('download'), true);
    const tween = adapter.latestTween();
    assert.ok(Math.abs(tween.duration() - 1.44) < 1e-10);
    assert.deepEqual(adapter.controller.getMotion(), {
      from: 23,
      to: 3000,
      target: 'download',
    });
    assert.equal(scrollY, 23);
    tween.progress(0.5);
    assert.ok(Math.abs(scrollY - 1511.5) < 1e-9);
    tween.progress(1);
    assert.equal(scrollY, 3000);
    assert.equal(adapter.controller.getMotion(), undefined);
    // Seeking a GSAP test tween does not advance the real quiet-window clock.
    assert.ok(['draining', 'idle'].includes(adapter.states.at(-1)!));
  });
});

test('rail navigation enters a previous long chapter at its reading end and never resets an already read chapter', () => {
  withAdapter((adapter) => {
    adapter.move(4800);
    assert.equal(adapter.controller.navigateTo('download'), true);
    assert.equal(adapter.controller.getMotion()?.to, 3600);
    assert.equal(adapter.latestTween().duration(), 1.2);
    adapter.latestTween().progress(1);
    adapter.move(3300);
    const count = adapter.writes.length;
    assert.equal(adapter.controller.navigateTo('download'), true);
    assert.equal(adapter.writes.length, count);
    assert.equal(scrollY, 3300);
    assert.equal(adapter.controller.getMotion(), undefined);
  });
});

test('rail destinations clamp explicit positions to their reading range and cap a six-hop duration at1.8 seconds', () => {
  withAdapter((adapter) => {
    adapter.stops.splice(
      0,
      adapter.stops.length,
      ...(
        [
          'hero',
          'scoring',
          'experience',
          'replay',
          'download',
          'community',
          'closing',
        ] as const
      ).map((id, index) => ({
        id,
        readStart: index * 1000,
        readEnd: index * 1000,
      })),
    );
    adapter.controller.navigateTo('closing');
    assert.ok(Math.abs(adapter.latestTween().duration() - 1.8) < 1e-10);
    adapter.latestTween().progress(1);
    adapter.stops[4].readEnd = 4400;
    adapter.controller.navigateTo('download', { position: 9000 });
    assert.equal(adapter.controller.getMotion()?.to, 4400);
    adapter.latestTween().progress(1);
    adapter.move(4600);
    adapter.controller.navigateTo('download', {
      position: 3900,
      duration: 0.42,
    });
    assert.equal(adapter.controller.getMotion()?.to, 4000);
    assert.equal(adapter.latestTween().duration(), 0.42);
  });
});

test('reduced-motion navigation can write instantly while wheel ownership is disabled and respects suspension', () => {
  let allowed = true;
  withAdapter(
    (adapter) => {
      assert.equal(
        adapter.controller.navigateTo('download', { instant: true }),
        true,
      );
      assert.equal(scrollY, 3000);
      assert.equal(adapter.states.at(-1), 'idle');
      assert.equal(adapter.controller.getMotion(), undefined);
      allowed = false;
      assert.equal(
        adapter.controller.navigateTo('closing', { instant: true }),
        false,
      );
      adapter.controller.beginDrag();
      assert.equal(adapter.controller.isDragging(), false);
      adapter.controller.dragTo(5000);
      assert.equal(scrollY, 3000);
    },
    { enabled: () => false, canNavigate: () => allowed },
  );
});

test('programmatic navigation retargets the committed chapter through refresh at20/55/90 percent', () => {
  for (const phase of [0.2, 0.55, 0.9])
    withAdapter((adapter) => {
      adapter.move(17);
      adapter.controller.navigateTo('download');
      const original = adapter.latestTween();
      const duration = original.duration();
      original.progress(phase);
      const actual = scrollY;
      adapter.controller.prepareRefresh();
      adapter.stops[3].readStart += 100;
      adapter.stops[3].readEnd += 100;
      adapter.controller.refresh();
      adapter.flush();
      assert.equal(scrollY, actual);
      const resumed = adapter.latestTween();
      assert.ok(Math.abs(resumed.duration() - duration * (1 - phase)) < 1e-10);
      assert.equal(adapter.controller.getMotion()?.target, 'download');
      assert.equal(adapter.controller.getMotion()?.to, 3100);
      resumed.progress(1);
      assert.equal(scrollY, 3100);
    });
});

test('a fresh rail destination and manual input cancel stale wheel or rail callbacks', () => {
  withAdapter((adapter) => {
    adapter.wheel(24);
    const wheel = adapter.latestTween();
    wheel.progress(0.2);
    adapter.controller.navigateTo('closing');
    const rail = adapter.latestTween();
    const count = adapter.writes.length;
    wheel.progress(1);
    assert.equal(adapter.writes.length, count);
    rail.progress(0.3);
    adapter.controller.prepareRefresh();
    adapter.controller.refresh();
    adapter.emit('keydown');
    const cancelled = adapter.writes.length;
    adapter.flush();
    rail.progress(1);
    assert.equal(adapter.writes.length, cancelled);
    assert.equal(adapter.states.at(-1), 'idle');
    assert.equal(adapter.controller.getMotion(), undefined);
  });
});

test('a rail drag supersedes the current task and exclusively owns bounded real scroll until release', () => {
  withAdapter((adapter) => {
    adapter.controller.navigateTo('closing');
    const old = adapter.latestTween();
    old.progress(0.2);
    adapter.emit('pointerdown');
    adapter.controller.beginDrag();
    assert.equal(adapter.controller.isDragging(), true);
    assert.equal(adapter.controller.getMotion(), undefined);
    adapter.controller.dragTo(-50);
    assert.equal(scrollY, 0);
    adapter.controller.dragTo(2400);
    const count = adapter.writes.length;
    let blocked = false;
    adapter.wheel(24, {
      preventDefault() {
        blocked = true;
      },
    });
    old.progress(1);
    assert.equal(adapter.writes.length, count);
    assert.equal(blocked, true);
    assert.equal(scrollY, 2400);
    adapter.controller.dragTo(Infinity);
    assert.equal(scrollY, 2400);
    adapter.controller.endDrag(1);
    assert.equal(adapter.controller.isDragging(), false);
    assert.equal(adapter.controller.getMotion()?.target, 'experience');
    assert.equal(adapter.latestTween().duration(), 0.42);
    adapter.latestTween().progress(1);
    assert.equal(scrollY, 2000);
  });
});

test('drag release keeps long content reading positions and only uses direction to break equal interval distances', () => {
  for (const direction of [-1, 1])
    withAdapter((adapter) => {
      adapter.controller.beginDrag();
      adapter.controller.dragTo(3300);
      const count = adapter.writes.length;
      adapter.controller.endDrag(direction);
      assert.equal(adapter.writes.length, count);
      assert.equal(scrollY, 3300);
      assert.equal(adapter.controller.getMotion(), undefined);
      adapter.controller.beginDrag();
      adapter.controller.dragTo(1500);
      adapter.controller.endDrag(direction);
      assert.equal(
        adapter.controller.getMotion()?.target,
        direction > 0 ? 'experience' : 'scoring',
      );
      adapter.latestTween().progress(1);
      assert.equal(scrollY, direction > 0 ? 2000 : 1000);
    });
});

test('drag refresh retains drag ownership and instant release settles without a tween', () => {
  withAdapter((adapter) => {
    adapter.controller.beginDrag();
    adapter.controller.dragTo(2800);
    adapter.controller.prepareRefresh();
    adapter.stops[3].readStart = 3150;
    adapter.controller.refresh();
    adapter.flush();
    assert.equal(adapter.controller.isDragging(), true);
    adapter.controller.dragTo(2900);
    adapter.controller.endDrag(1, true);
    assert.equal(adapter.controller.isDragging(), false);
    assert.equal(scrollY, 3150);
    assert.equal(adapter.controller.getMotion(), undefined);
    assert.equal(adapter.states.at(-1), 'idle');
  });
});

test('drag reflow consumes the newest pointer mapping without requiring another mouse move', () => {
  withAdapter((adapter) => {
    adapter.controller.beginDrag();
    adapter.controller.dragTo(2400);
    adapter.controller.prepareRefresh();
    adapter.stops[3].readStart += 120;
    adapter.controller.refresh();
    adapter.controller.dragTo(2500);
    adapter.controller.dragTo(2600);
    assert.equal(scrollY, 2400);
    adapter.flush();
    assert.equal(scrollY, 2600);
    assert.equal(adapter.controller.isDragging(), true);
    adapter.controller.cancel();
    adapter.flush();
    assert.equal(scrollY, 2600);
  });
});

test('explicit keyboard endpoints can move within a reading range while plain chapter clicks preserve it', () => {
  withAdapter((adapter) => {
    adapter.move(3300);
    adapter.controller.navigateTo('download');
    assert.equal(scrollY, 3300);
    adapter.controller.navigateTo('download', {
      position: 3000,
      instant: true,
    });
    assert.equal(scrollY, 3000);
    adapter.controller.navigateTo('download', {
      position: 3600,
      instant: true,
    });
    assert.equal(scrollY, 3600);
  });
});

test('Escape resolves the navigation task to a reading interval in the same owner before cancellation observers', () => {
  withAdapter((adapter) => {
    adapter.controller.navigateTo('closing');
    const old = adapter.latestTween();
    old.progress(0.27);
    adapter.emit('keydown', { key: 'Escape' });
    const target = adapter.controller.getMotion()?.target;
    assert.ok(target);
    const landing = adapter.latestTween();
    assert.equal(landing.duration(), 0.42);
    const count = adapter.writes.length;
    old.progress(1);
    assert.equal(adapter.writes.length, count);
    landing.progress(1);
    assert.ok(
      adapter.stops.some(
        (stop) => scrollY >= stop.readStart && scrollY <= stop.readEnd,
      ),
    );
  });
});

test('suspension or manual takeover cancels a drag and disposed controllers reject navigation', () => {
  let allowed = true;
  withAdapter(
    (adapter) => {
      adapter.controller.beginDrag();
      adapter.controller.dragTo(500);
      adapter.emit('keydown');
      assert.equal(adapter.controller.isDragging(), false);
      adapter.controller.dragTo(1500);
      assert.equal(scrollY, 500);
      adapter.controller.beginDrag();
      allowed = false;
      adapter.controller.refresh();
      assert.equal(adapter.controller.isDragging(), false);
      adapter.controller.dispose();
      assert.equal(adapter.controller.navigateTo('hero'), false);
    },
    { canNavigate: () => allowed },
  );
});
