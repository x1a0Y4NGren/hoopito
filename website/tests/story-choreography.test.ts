import assert from 'node:assert/strict';
import test from 'node:test';
import { cardPose } from '../src/scripts/story-choreography.ts';

const settled = { x: 0, y: 0, scale: 1, opacity: 1 };

test('cards enter from their side, hold, and exit on the opposite side', () => {
  assert.deepEqual(cardPose(0, 'left', 800), {
    x: -800,
    y: 0,
    scale: 0.94,
    opacity: 0,
  });
  assert.deepEqual(cardPose(0, 'right', 800), {
    x: 800,
    y: 0,
    scale: 0.94,
    opacity: 0,
  });
  for (const progress of [0.22, 0.4, 0.6, 0.78]) {
    assert.deepEqual(cardPose(progress, 'left', 800), settled);
    assert.deepEqual(cardPose(progress, 'right', 800), settled);
  }
  assert.deepEqual(cardPose(1, 'left', 800), {
    x: 800,
    y: 0,
    scale: 0.97,
    opacity: 0,
  });
  assert.deepEqual(cardPose(1, 'right', 800), {
    x: -800,
    y: 0,
    scale: 0.97,
    opacity: 0,
  });
});

test('transition midpoint fixtures preserve scale and readability', () => {
  assert.deepEqual(cardPose(0.11, 'left', 800), {
    x: -400,
    y: 0,
    scale: 0.97,
    opacity: 0.5,
  });
  const exit = cardPose(0.89, 'left', 800);
  assert.ok(Math.abs(exit.x - 400) < 1e-10);
  assert.ok(Math.abs(exit.scale - 0.985) < 1e-10);
  assert.ok(Math.abs(exit.opacity - 0.5) < 1e-10);
});

test('hero starts settled and still exits; reduced motion stays settled', () => {
  for (const progress of [0, 0.11, 0.22, 0.7]) {
    assert.deepEqual(cardPose(progress, 'left', 800, { hero: true }), settled);
  }
  assert.deepEqual(cardPose(1, 'left', 800, { hero: true }), {
    x: 800,
    y: 0,
    scale: 0.97,
    opacity: 0,
  });
  for (const progress of [0, 0.11, 0.89, 1, NaN]) {
    assert.deepEqual(
      cardPose(progress, 'right', 800, { reduced: true }),
      settled,
    );
  }
});

test('invalid inputs and out-of-range scroll never produce nonfinite poses', () => {
  for (const progress of [NaN, Infinity, -Infinity, -1]) {
    assert.deepEqual(cardPose(progress, 'left', 800), cardPose(0, 'left', 800));
  }
  assert.deepEqual(cardPose(2, 'right', 800), cardPose(1, 'right', 800));
  for (const travel of [NaN, Infinity, -Infinity, -800]) {
    for (const progress of [0, 0.11, 0.89, 1]) {
      const pose = cardPose(progress, 'left', travel);
      assert.equal(pose.x, 0);
      assert.ok(Object.values(pose).every(Number.isFinite));
    }
  }
});

test('reverse scroll reproduces the same poses and transitions have smooth joins', () => {
  const progress = Array.from({ length: 101 }, (_, index) => index / 100);
  const forward = progress.map((value) => cardPose(value, 'right', 800));
  const reverse = [...progress]
    .reverse()
    .map((value) => cardPose(value, 'right', 800));
  assert.deepEqual(reverse.reverse(), forward);
  for (const boundary of [0, 0.22, 0.78, 1]) {
    const a = cardPose(boundary - 1e-6, 'left', 800);
    const b = cardPose(boundary + 1e-6, 'left', 800);
    assert.ok(Math.abs(a.x - b.x) < 1e-6, `smooth join at ${boundary}`);
  }
  assert.ok(cardPose(0.055, 'left', 800).x < -600, 'enter eases from rest');
});
