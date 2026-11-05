import assert from 'node:assert/strict';
import test from 'node:test';
import {
  storyItemPose,
  stageItemProgress,
  type StoryRole,
} from '../src/scripts/story-choreography.ts';

const rest = { x: 0, y: 0, scale: 1, opacity: 1, reveal: 1 };
const roles: StoryRole[] = ['heading', 'visual', 'control', 'detail'];

test('poster roles enter in order and are all settled for the complete reading window', () => {
  const opacity = roles.map(
    (role) => storyItemPose(0.06, role, 'left', 800).opacity,
  );
  assert.ok(opacity[0] > opacity[1] && opacity[1] > opacity[2]);
  assert.equal(opacity[3], 0);
  for (const role of roles)
    for (const progress of [0.22, 0.4, 0.78])
      assert.deepEqual(storyItemPose(progress, role, 'left', 800), rest);
  assert.equal(storyItemPose(0.16, 'heading', 'up', 800).opacity, 1);
  assert.equal(storyItemPose(0.2, 'visual', 'right', 800).opacity, 1);
});

test('poster directions use only translation and uniform scale; headings stay close', () => {
  assert.equal(storyItemPose(0, 'visual', 'right', 900).x, 900);
  assert.equal(storyItemPose(0, 'visual', 'up', 900).y, -900);
  assert.equal(storyItemPose(0, 'visual', 'down', 900).y, 900);
  assert.equal(storyItemPose(0, 'heading', 'up', 900).y, -48);
  assert.equal(storyItemPose(0, 'control', 'left', 900).x, -96);
  for (const role of roles) {
    const middle = storyItemPose(0.9, role, 'left', 900);
    assert.ok(middle.x >= 0);
    assert.equal(middle.y, 0);
  }
});

test('detail and control leave before the main visual and heading', () => {
  const opacity = roles.map(
    (role) => storyItemPose(0.9, role, 'left', 800).opacity,
  );
  assert.ok(
    opacity[0] > opacity[1] &&
      opacity[1] > opacity[2] &&
      opacity[2] > opacity[3],
  );
  for (const role of roles)
    assert.equal(storyItemPose(1, role, 'left', 800).opacity, 0);
});

test('direct hero, reduced motion, keyboard focus and mobile reveal full content', () => {
  for (const role of roles) {
    for (const progress of [0, 0.11, 0.4, 0.78])
      assert.deepEqual(
        storyItemPose(progress, role, 'left', 800, { hero: true }),
        rest,
      );
    for (const option of ['reduced', 'focused', 'mobile'] as const)
      for (const progress of [0, 0.1, 0.89, 1])
        assert.deepEqual(
          storyItemPose(progress, role, 'left', 800, { [option]: true }),
          rest,
        );
  }
});

test('poster poses are exact on reverse scrolling and remain finite at invalid boundaries', () => {
  const positions = Array.from({ length: 201 }, (_, index) => index / 200);
  for (const role of roles) {
    const forward = positions.map((progress) =>
      storyItemPose(progress, role, 'right', 800),
    );
    const reverse = positions
      .toReversed()
      .map((progress) => storyItemPose(progress, role, 'right', 800));
    assert.deepEqual(reverse.toReversed(), forward);
    for (const progress of [NaN, Infinity, -1, 2])
      assert.ok(
        Object.values(storyItemPose(progress, role, 'up', NaN)).every(
          Number.isFinite,
        ),
      );
  }
});

test('short-screen natural content stays settled throughout its full reading interval', () => {
  const layout = {
    top: 100,
    bottom: 1600,
    readingLine: 114,
    viewportHeight: 720,
    scroll: 1000,
    readEnd: 1800,
    exitEnd: 2400,
  };
  assert.equal(stageItemProgress(layout), 0.4);
  assert.equal(stageItemProgress({ ...layout, scroll: 1800 }), 0.4);
  assert.equal(stageItemProgress({ ...layout, scroll: 2100 }), 0.89);
  assert.equal(stageItemProgress({ ...layout, mobile: true, top: 900 }), 0.4);
  assert.equal(stageItemProgress({ ...layout, pinnedProgress: 0.22 }), 0.22);
});

test('static stage footprint includes grown content beyond a pin-fixed border box', async () => {
  const { stageLayoutHeight } =
    await import('../src/scripts/story-choreography.ts');
  assert.equal(stageLayoutHeight(900, [880, 1220], 24), 1244);
  assert.equal(stageLayoutHeight(900, [400, 800], 24), 900);
});
