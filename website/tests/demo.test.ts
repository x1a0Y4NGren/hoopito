import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { CourtPoint } from '../src/scripts/scene-contract.ts';
import type { DemoAction, DemoState } from '../src/scripts/demo-state.ts';

async function demoModule() {
  return await import('../src/scripts/demo-state.ts');
}

const inside: CourtPoint = { x: 0.5, y: 0.35 };
const outside: CourtPoint = { x: 0.5, y: 0.85 };
const freeThrow: CourtPoint = { x: 0.5, y: 5.8 / 14 };

test('a location requires an explicit score choice before recording', async () => {
  const demo = await demoModule();
  const initial = demo.initialDemoState();
  assert.equal(initial.blue, 6);
  assert.equal(initial.red, 6);
  assert.equal(demo.reduceDemo(initial, { type: 'record' }), initial);
  const selected = demo.reduceDemo(initial, { type: 'select', point: inside });
  assert.equal(demo.reduceDemo(selected, { type: 'record' }), selected);
  assert.equal(selected.blue, 6);
});

for (const points of [1, 2, 3] as const) {
  test(`score-first +${points} records one made shot from 6:6 to ${6 + points}:6`, async () => {
    const demo = await demoModule();
    let state = demo.reduceDemo(demo.initialDemoState(), {
      type: 'selectScore',
      points,
    });
    assert.equal(state.points, points);
    assert.equal(
      state.blue,
      6,
      'Choosing a score requires a separate record action',
    );
    assert.equal(state.phase, 'ready');
    if (points === 1) {
      assert.deepEqual(state.point, freeThrow);
      assert.equal(state.freeThrowEligible, true);
    } else {
      assert.equal(state.point, null);
      assert.equal(demo.reduceDemo(state, { type: 'record' }), state);
      state = demo.reduceDemo(state, {
        type: 'select',
        point: points === 2 ? inside : outside,
      });
    }
    state = demo.reduceDemo(state, { type: 'record' });
    assert.equal(state.phase, 'shooting');
    assert.equal(state.blue, 6 + points);
    assert.equal(state.red, 6);
    assert.equal(state.hasLocation, false);
    assert.equal(state.generation, 1);
    assert.equal(demo.reduceDemo(state, { type: 'record' }), state);
    state = demo.reduceDemo(state, {
      type: 'complete',
      generation: state.generation,
    });
    assert.equal(state.phase, 'scored');
    assert.equal(
      state.hasLocation,
      true,
      'Completion reveals the visual marker',
    );
    assert.equal(demo.reduceDemo(state, { type: 'record' }), state);
  });
}

test('location-first movement updates eligible scores until a score is chosen', async () => {
  const demo = await demoModule();
  let state = demo.initialDemoState();
  assert.equal(state.points, null);
  assert.equal(state.freeThrowEligible, false);
  assert.deepEqual(demo.allowedDemoPoints(state), [1, 2, 3]);
  assert.equal(demo.demoRegion(state), null);
  state = demo.reduceDemo(state, { type: 'select', point: inside });
  assert.deepEqual(demo.allowedDemoPoints(state), [2]);
  assert.equal(demo.demoRegion(state), null);
  assert.equal(
    demo.reduceDemo(state, { type: 'selectScore', points: 1 }),
    state,
  );
  assert.equal(
    demo.reduceDemo(state, { type: 'selectScore', points: 3 }),
    state,
  );
  state = demo.reduceDemo(state, { type: 'select', point: outside });
  assert.deepEqual(demo.allowedDemoPoints(state), [3]);
  assert.equal(
    demo.reduceDemo(state, { type: 'selectScore', points: 2 }),
    state,
  );
  state = demo.reduceDemo(state, { type: 'selectScore', points: 3 });
  assert.deepEqual(
    state.point,
    outside,
    'The legal field-goal draft is retained',
  );
  assert.equal(demo.demoRegion(state), 'outsideArc');
  state = demo.reduceDemo(state, { type: 'record' });
  assert.equal(state.blue, 9);
  assert.deepEqual(demo.allowedDemoPoints(state), []);
  state = demo.reduceDemo(state, {
    type: 'complete',
    generation: state.generation,
  });
  assert.deepEqual(demo.allowedDemoPoints(state), []);
});

test('a free-throw-band location offers an explicit free throw or a two-point field goal', async () => {
  const demo = await demoModule();
  const draftPoint = { x: 0.54, y: 5.8 / 14 };
  const draft = demo.reduceDemo(demo.initialDemoState(), {
    type: 'select',
    point: draftPoint,
    freeThrowEligible: true,
  });
  assert.deepEqual(demo.allowedDemoPoints(draft), [1, 2]);
  const fieldGoal = demo.reduceDemo(draft, { type: 'selectScore', points: 2 });
  assert.deepEqual(fieldGoal.point, draftPoint);
  assert.equal(demo.demoRegion(fieldGoal), 'insideArc');
  assert.equal(demo.reduceDemo(fieldGoal, { type: 'record' }).blue, 8);

  const selected = demo.reduceDemo(draft, { type: 'selectScore', points: 1 });
  assert.deepEqual(
    selected.point,
    freeThrow,
    'A free throw anchors at line center',
  );
  assert.equal(selected.blue, 6);
  assert.equal(demo.demoRegion(selected), 'freeThrowLine');
  assert.equal(
    demo.reduceDemo(selected, { type: 'select', point: inside }),
    selected,
  );
  assert.equal(
    demo.reduceDemo(selected, { type: 'select', point: outside }),
    selected,
  );
  assert.equal(demo.reduceDemo(selected, { type: 'record' }).blue, 7);
});

test('moving away from the free-throw band clears its eligibility', async () => {
  const demo = await demoModule();
  const draft = demo.reduceDemo(demo.initialDemoState(), {
    type: 'select',
    point: freeThrow,
    freeThrowEligible: true,
  });
  const moved = demo.reduceDemo(draft, { type: 'select', point: inside });
  assert.equal(moved.freeThrowEligible, false);
  assert.deepEqual(demo.allowedDemoPoints(moved), [2]);
  const outsideDraft = demo.reduceDemo(draft, {
    type: 'select',
    point: outside,
    freeThrowEligible: true,
  });
  assert.deepEqual(demo.allowedDemoPoints(outsideDraft), [3]);
});

for (const points of [2, 3] as const) {
  test(`+${points} rejects the other region before and after a legal location`, async () => {
    const demo = await demoModule();
    let state = demo.reduceDemo(demo.initialDemoState(4), {
      type: 'selectScore',
      points,
    });
    const invalid = points === 2 ? outside : inside;
    const valid = points === 2 ? inside : outside;
    assert.equal(
      demo.reduceDemo(state, { type: 'select', point: invalid }),
      state,
    );
    assert.equal(state.generation, 4);
    state = demo.reduceDemo(state, { type: 'select', point: valid });
    assert.deepEqual(state.point, valid);
    assert.equal(
      demo.reduceDemo(state, { type: 'select', point: invalid }),
      state,
    );
    assert.equal(state.generation, 4);
    assert.equal(state.blue, 6);
  });
}

test('reset clears the score and location and rejects a stale completion', async () => {
  const demo = await demoModule();
  let state = demo.reduceDemo(demo.initialDemoState(8), {
    type: 'selectScore',
    points: 1,
  });
  state = demo.reduceDemo(state, { type: 'record' });
  const generation = state.generation;
  assert.equal(
    demo.reduceDemo(state, { type: 'complete', generation: generation - 1 }),
    state,
  );
  state = demo.reduceDemo(state, { type: 'reset' });
  assert.equal(demo.reduceDemo(state, { type: 'complete', generation }), state);
  assert.deepEqual(state, {
    phase: 'ready',
    point: null,
    points: null,
    freeThrowEligible: false,
    blue: 6,
    red: 6,
    hasLocation: false,
    generation: 10,
  });
});

test('invalid locations and scores leave the same state object and generation', async () => {
  const demo = await demoModule();
  for (const point of [
    { x: NaN, y: 0 },
    { x: Infinity, y: 0.5 },
    { x: 0.5, y: -Infinity },
    { x: -0.1, y: 0.5 },
    { x: 1.1, y: 0.5 },
    { x: 0.5, y: -0.1 },
    { x: 0.5, y: 1.1 },
  ]) {
    const state = demo.initialDemoState(7);
    assert.equal(demo.reduceDemo(state, { type: 'select', point }), state);
  }
  for (const points of [NaN, Infinity, -1, 0, 1.5, 4]) {
    const state = demo.initialDemoState(7);
    assert.equal(
      demo.reduceDemo(state, {
        type: 'selectScore',
        points,
      } as DemoAction),
      state,
    );
  }
});

test('record revalidates forged score/location pairs without changing the score', async () => {
  const demo = await demoModule();
  for (const [points, point, freeThrowEligible] of [
    [2, outside, false],
    [3, inside, false],
    [1, inside, true],
    [1, freeThrow, false],
    [2, { x: NaN, y: 0.35 }, false],
    [4, inside, false],
  ] as [number, CourtPoint, boolean][]) {
    const state = {
      ...demo.initialDemoState(),
      points,
      point,
      freeThrowEligible,
    } as DemoState;
    assert.equal(demo.reduceDemo(state, { type: 'record' }), state);
  }
});

test('shooting and scored demos cannot change their score or point', async () => {
  const demo = await demoModule();
  let state = demo.reduceDemo(demo.initialDemoState(), {
    type: 'selectScore',
    points: 1,
  });
  state = demo.reduceDemo(state, { type: 'record' });
  for (const phase of ['shooting', 'scored'] as const) {
    const locked = { ...state, phase };
    assert.equal(
      demo.reduceDemo(locked, { type: 'select', point: inside }),
      locked,
    );
    assert.equal(
      demo.reduceDemo(locked, { type: 'selectScore', points: 2 }),
      locked,
    );
  }
});

test('keyboard presets remain legal for each selected score', async () => {
  const demo = await demoModule();
  for (const points of [null, 1, 2, 3] as const) {
    const presets = demo.demoPresets(points);
    assert.deepEqual(Object.keys(presets).sort(), ['center', 'left', 'right']);
    for (const point of Object.values(presets)) {
      let state = demo.initialDemoState();
      if (points !== null)
        state = demo.reduceDemo(state, { type: 'selectScore', points });
      state = demo.reduceDemo(state, { type: 'select', point });
      assert.deepEqual(state.point, point);
      if (points !== null) {
        state = demo.reduceDemo(state, { type: 'record' });
        assert.equal(state.blue, 6 + points);
      } else {
        assert.deepEqual(demo.allowedDemoPoints(state), [2]);
      }
    }
  }
});
