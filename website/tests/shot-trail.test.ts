import assert from 'node:assert/strict';
import { test } from 'node:test';
import { gsap } from 'gsap';
import * as timing from '../src/scripts/shot-timing.ts';
import { createShotFeedback } from '../src/scripts/shot-feedback.ts';
import type { CourtPoint } from '../src/scripts/scene-contract.ts';

type Point = { x: number; y: number };
type TrailFrame = { path: string; start: Point; end: Point; opacity: number };
const point = { x: 0.25, y: 0.65 };
const close = (actual: number, expected: number) =>
  assert.ok(Math.abs(actual - expected) < 1e-8, `${actual} != ${expected}`);
const frame = (time: number, origin = point): TrailFrame => {
  const sample = Reflect.get(timing, 'shotTrailFrame') as
    ((time: number, point: CourtPoint) => TrailFrame) | undefined;
  assert.equal(
    typeof sample,
    'function',
    'The SVG trail needs a moving subcurve',
  );
  return sample!(time, origin);
};

test('the early trail uses the exact quadratic segment ending at the current ball', () => {
  const trail = frame(0.12);
  const coordinates = trail.path
    .match(/[-+]?\d*\.?\d+(?:e[-+]?\d+)?/gi)!
    .map(Number);
  assert.equal(coordinates.length, 6);
  for (const [actual, expected] of coordinates.map(
    (value, index) =>
      [value, [164, 355.6, 170.8, 321.54, 177.6, 291.583][index]!] as const,
  ))
    close(actual, expected);
  assert.deepEqual(trail.start, { x: 164, y: 355.6 });
  close(trail.end.x, 177.6);
  close(trail.end.y, 291.583);
});

test('a rolling 220ms trail follows the original flight without retaining the launch point', () => {
  for (const elapsed of [0.3, 0.6, 1, 1.2]) {
    const trail = frame(elapsed);
    const tail = timing.shotFrame(elapsed - 0.22, point);
    const head = timing.shotFrame(elapsed, point);
    close(trail.start.x, tail.x);
    close(trail.start.y, tail.y);
    close(trail.end.x, head.x);
    close(trail.end.y, head.y);
    assert.notEqual(trail.start.x, 164);
    const values = trail.path
      .match(/[-+]?\d*\.?\d+(?:e[-+]?\d+)?/gi)!
      .map(Number);
    const [x0, y0, x1, y1, x2, y2] = values as [
      number,
      number,
      number,
      number,
      number,
      number,
    ];
    for (const p of [0.2, 0.5, 0.8]) {
      const expected = timing.shotFrame(elapsed - 0.22 + 0.22 * p, point);
      close((1 - p) ** 2 * x0 + 2 * (1 - p) * p * x1 + p ** 2 * x2, expected.x);
      close((1 - p) ** 2 * y0 + 2 * (1 - p) * p * y1 + p ** 2 * y2, expected.y);
    }
  }
});

test('the last short trail stays at the rim during swish and disappears by recording', () => {
  const rim = frame(1.2);
  assert.deepEqual(frame(1.4).start, rim.start);
  assert.deepEqual(frame(1.4).end, { x: 300, y: 84.7 });
  assert.equal(frame(1.4).path, rim.path);
  assert.ok(frame(1.4).opacity > 0 && frame(1.4).opacity < rim.opacity);
  for (const elapsed of [1.55, 2.13, 100])
    assert.equal(frame(elapsed).opacity, 0);
  for (const elapsed of [-1, NaN, Infinity]) {
    assert.deepEqual(frame(elapsed), frame(0));
    assert.equal(frame(elapsed).opacity, 0);
  }
});

class SvgFixture {
  attributes = new Map<string, string>();
  style = { opacity: '' };
  ownerSVGElement: {
    querySelector: (selector: string) => SvgFixture | null;
    querySelectorAll?: (selector: string) => SvgFixture[];
    getScreenCTM?: () => { a: number; b: number };
  } | null = null;
  setAttribute(name: string, value: string) {
    this.attributes.set(name, value);
  }
  getAttribute(name: string) {
    return this.attributes.get(name) ?? null;
  }
  toggleAttribute(name: string, force: boolean) {
    if (force) this.attributes.set(name, '');
    else this.attributes.delete(name);
  }
}

test('the single shot clock updates and clears the trail layers and their moving gradient', () => {
  const ball = new SvgFixture(),
    net = new SvgFixture(),
    trail = new SvgFixture();
  const halo = new SvgFixture(),
    edge = new SvgFixture(),
    gradient = new SvgFixture();
  const filter = new SvgFixture(),
    blur = new SvgFixture();
  trail.ownerSVGElement = {
    querySelector: (selector) =>
      selector === '[data-demo-trail-halo]'
        ? halo
        : selector === '[data-demo-trail-edge]'
          ? edge
          : selector === '[data-demo-trail-filter]'
            ? filter
            : selector === '[data-demo-trail-blur]'
              ? blur
              : null,
    querySelectorAll: (selector) =>
      selector === '[data-demo-trail-gradient]' ? [gradient] : [],
  };
  const feedback = createShotFeedback(
    ball as unknown as SVGGElement,
    net as unknown as SVGPathElement,
    trail as unknown as SVGPathElement,
  );
  let recorded = 0;
  try {
    assert.equal(halo.getAttribute('hidden'), '');
    feedback.pause();
    feedback.start(point, () => recorded++);
    const clock = gsap.globalTimeline.getChildren(false, true, false).at(-1)!;
    clock.time(0.6);
    assert.equal(halo.getAttribute('hidden'), null);
    assert.equal(halo.getAttribute('d'), frame(0.6).path);
    assert.equal(trail.getAttribute('d'), halo.getAttribute('d'));
    assert.equal(trail.getAttribute('d'), edge.getAttribute('d'));
    assert.equal(trail.style.opacity, halo.style.opacity);
    close(Number(gradient.getAttribute('x1')), frame(0.6).start.x);
    close(Number(gradient.getAttribute('y1')), frame(0.6).start.y);
    close(Number(gradient.getAttribute('x2')), frame(0.6).end.x);
    close(Number(gradient.getAttribute('y2')), frame(0.6).end.y);
    assert.ok(Number(filter.getAttribute('width')) > 24);
    assert.ok(Number(filter.getAttribute('width')) < 100);
    assert.ok(Number(filter.getAttribute('height')) < 150);
    close(Number(filter.getAttribute('x')), frame(0.6).start.x - 12);
    close(Number(blur.getAttribute('stdDeviation')), 1.5);
    clock.time(1.55);
    assert.equal(recorded, 1);
    assert.equal(halo.getAttribute('hidden'), '');
    feedback.cancel();
    for (const layer of [trail, halo, edge]) {
      assert.equal(layer.getAttribute('hidden'), '');
      assert.equal(layer.getAttribute('d'), '');
      assert.equal(layer.style.opacity, '0');
    }
    feedback.start({ x: 0.8, y: 0.8 }, () => recorded++);
    assert.equal(halo.getAttribute('hidden'), '');
    clock.vars.onUpdate?.call(clock);
    assert.equal(
      recorded,
      1,
      'the cancelled revision cannot record another score',
    );
    assert.equal(halo.getAttribute('hidden'), '');
  } finally {
    feedback.cancel();
    gsap.ticker.sleep();
  }
});

test('local glow diameters survive SVG resizing and disposal releases the observer', () => {
  const ball = new SvgFixture(),
    net = new SvgFixture(),
    trail = new SvgFixture();
  const markerGlow = new SvgFixture(),
    ballGlow = new SvgFixture();
  let scale = 0.5,
    resized: (() => void) | undefined,
    disconnects = 0;
  const previous = globalThis.ResizeObserver;
  globalThis.ResizeObserver = class {
    constructor(callback: () => void) {
      resized = callback;
    }
    observe() {}
    disconnect() {
      disconnects++;
    }
  } as unknown as typeof ResizeObserver;
  trail.ownerSVGElement = {
    querySelector: (selector) =>
      selector === '[data-demo-ball-glow]' ? ballGlow : null,
    querySelectorAll: () => [markerGlow],
    getScreenCTM: () => ({ a: scale, b: 0 }),
  };
  const feedback = createShotFeedback(
    ball as unknown as SVGGElement,
    net as unknown as SVGPathElement,
    trail as unknown as SVGPathElement,
  );
  try {
    close(Number(markerGlow.getAttribute('r')) * scale * 2, 36);
    close(Number(ballGlow.getAttribute('r')) * scale * 2, 26);
    feedback.cancel();
    assert.equal(disconnects, 0, 'reset keeps future resizing active');
    scale = 0.8;
    resized!();
    close(Number(markerGlow.getAttribute('r')) * scale * 2, 36);
    close(Number(ballGlow.getAttribute('r')) * scale * 2, 26);
    const dispose = Reflect.get(feedback, 'dispose');
    assert.equal(typeof dispose, 'function');
    dispose();
    assert.equal(disconnects, 1);
  } finally {
    feedback.cancel();
    globalThis.ResizeObserver = previous;
    gsap.ticker.sleep();
  }
});
