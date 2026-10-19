import assert from 'node:assert/strict';
import { test } from 'node:test';

async function replayModule() {
  return await import('../src/data/replay-example.ts');
}

test('the fictional replay is an independent basketball sequence ending at 8:11', async () => {
  const { replayExample } = await replayModule();
  assert.equal(replayExample.kind, 'fictional');
  assert.deepEqual(
    replayExample.points.map(({ leftScore, rightScore }) => [
      leftScore,
      rightScore,
    ]),
    [
      [0, 0],
      [2, 0],
      [2, 2],
      [4, 2],
      [6, 2],
      [6, 4],
      [6, 6],
      [6, 7],
      [8, 7],
      [8, 9],
      [8, 11],
    ],
  );
  assert.equal(replayExample.points[0].progress, 0);
  assert.equal(replayExample.points.at(-1)?.progress, 1);

  for (let index = 1; index < replayExample.points.length; index += 1) {
    const previous = replayExample.points[index - 1];
    const current = replayExample.points[index];
    const leftDelta = current.leftScore - previous.leftScore;
    const rightDelta = current.rightScore - previous.rightScore;
    assert.ok(current.progress > previous.progress && current.progress <= 1);
    assert.ok(
      (leftDelta === 0 && rightDelta >= 1 && rightDelta <= 3) ||
        (rightDelta === 0 && leftDelta >= 1 && leftDelta <= 3),
      'Each scoring event changes only one side by a valid basketball score',
    );
  }
});

test('scores and the last reached key stage change at the same replay boundary', async () => {
  const { getReplayState, replayExample } = await replayModule();
  const cases = [
    { progress: 0, scores: [0, 0], index: 0, stage: 'opening' },
    { progress: 0.399, scores: [4, 2], index: 3, stage: 'opening' },
    { progress: 0.4, scores: [6, 2], index: 4, stage: 'lead' },
    { progress: 0.599, scores: [6, 4], index: 5, stage: 'lead' },
    { progress: 0.6, scores: [6, 6], index: 6, stage: 'tie' },
    { progress: 0.8, scores: [8, 7], index: 8, stage: 'tie' },
    { progress: 0.9, scores: [8, 9], index: 9, stage: 'turnaround' },
    { progress: 1, scores: [8, 11], index: 10, stage: 'final' },
  ];
  for (const { progress, scores, index, stage } of cases) {
    const state = getReplayState(progress);
    assert.deepEqual([state.leftScore, state.rightScore], scores);
    assert.equal(state.pointIndex, index);
    assert.equal(state.stage, stage);
    assert.equal(state.keyMoment?.id ?? 'opening', stage);
  }
  assert.deepEqual(
    replayExample.keyMoments.map(({ id, progress, leftScore, rightScore }) => ({
      id,
      progress,
      scores: [leftScore, rightScore],
    })),
    [
      { id: 'lead', progress: 0.4, scores: [6, 2] },
      { id: 'tie', progress: 0.6, scores: [6, 6] },
      { id: 'turnaround', progress: 0.9, scores: [8, 9] },
      { id: 'final', progress: 1, scores: [8, 11] },
    ],
  );
});

test('replay progress stays bounded and non-finite input resets to the opening', async () => {
  const { getReplayState } = await replayModule();
  for (const progress of [-1, NaN, Infinity, -Infinity]) {
    const state = getReplayState(progress);
    assert.equal(state.progress, 0);
    assert.deepEqual([state.leftScore, state.rightScore], [0, 0]);
    assert.equal(state.leftPath, 'M34 166');
    assert.equal(state.rightPath, 'M34 166');
  }
  const complete = getReplayState(2);
  assert.equal(complete.progress, 1);
  assert.deepEqual([complete.leftScore, complete.rightScore], [8, 11]);
});

test('partial staircase paths stop at the current progress before the next score', async () => {
  const { getReplayPaths, getReplayState } = await replayModule();
  const paths = getReplayPaths(0.45);
  assert.equal(
    paths.left,
    'M34 166 H73.2 V143 H112.4 H151.6 V120 H190.8 V97 H210.4',
  );
  assert.equal(paths.right, 'M34 166 H73.2 H112.4 V143 H151.6 H190.8 H210.4');
  const state = getReplayState(0.45);
  assert.deepEqual([state.leftScore, state.rightScore], [6, 2]);
  assert.equal(state.leftPath, paths.left);
  assert.equal(state.rightPath, paths.right);
});

test('full paths and plot points share the final score coordinates and support custom bounds', async () => {
  const { getReplayPaths, getReplayPlotPoint, replayExample } =
    await replayModule();
  const paths = getReplayPaths();
  assert.ok(paths.left.endsWith('V74 H386.8 H426'));
  assert.ok(paths.right.endsWith('H386.8 V62.5 H426 V39.5'));
  assert.deepEqual(getReplayPlotPoint(replayExample.points[4]), {
    x: 190.8,
    leftY: 97,
    rightY: 143,
  });
  assert.deepEqual(getReplayPlotPoint(replayExample.points[10]), {
    x: 426,
    leftY: 74,
    rightY: 39.5,
  });
  const bounds = { xMin: 0, xMax: 100, yMin: 0, yMax: 120, maxScore: 12 };
  assert.deepEqual(getReplayPlotPoint(replayExample.points[10], bounds), {
    x: 100,
    leftY: 40,
    rightY: 10,
  });
  assert.equal(
    getReplayPaths(0.45, bounds).left,
    'M0 120 H10 V100 H20 H30 V80 H40 V60 H45',
  );
});
