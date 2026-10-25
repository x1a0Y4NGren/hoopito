import assert from 'node:assert/strict';
import { test } from 'node:test';
import { gsap } from 'gsap';
import { createShotFeedback } from '../src/scripts/shot-feedback.ts';
import { SHOT_TIMING } from '../src/scripts/shot-timing.ts';

function svgNode() {
  const attributes = new Map<string, string>();
  return {
    style: {},
    setAttribute(name: string, value: string) {
      attributes.set(name, value);
    },
    toggleAttribute(name: string, enabled: boolean) {
      if (enabled) attributes.set(name, '');
      else attributes.delete(name);
    },
  };
}

test('shot adoption reads the active animation time, including pauses and the remaining rebound', () => {
  const controller = createShotFeedback(
    svgNode() as unknown as SVGGElement,
    svgNode() as unknown as SVGPathElement,
    svgNode() as unknown as SVGPathElement,
  );
  let recorded = 0;
  assert.equal(controller.elapsed(), null);
  const previous = new Set(gsap.globalTimeline.getChildren());
  controller.start({ x: 0.5, y: 0.65 }, () => recorded++);
  gsap.ticker.sleep();
  const tween = gsap.globalTimeline
    .getChildren()
    .find((candidate) => !previous.has(candidate))!;
  try {
    tween.time(0.64, false);
    assert.equal(controller.elapsed(), 0.64);
    controller.pause();
    gsap.globalTimeline.time(gsap.globalTimeline.time() + 5, false);
    assert.equal(
      controller.elapsed(),
      0.64,
      'Hidden time cannot advance the shot',
    );
    controller.resume();
    gsap.ticker.sleep();
    assert.equal(controller.elapsed(), 0.64);
    tween.time(SHOT_TIMING.mark + 0.2, false);
    assert.equal(recorded, 1);
    assert.equal(controller.elapsed(), SHOT_TIMING.mark + 0.2);
    tween.time(SHOT_TIMING.total, false);
    assert.equal(controller.elapsed(), null);
    assert.equal(recorded, 1, 'Adoption must never score the same shot twice');
    controller.start({ x: 0.25, y: 0.65 }, () => recorded++);
    controller.cancel();
    assert.equal(
      controller.elapsed(),
      null,
      'Reset cannot expose a stale clock',
    );
  } finally {
    controller.cancel();
    gsap.ticker.sleep();
  }
});
