import assert from 'node:assert/strict';
import { test } from 'node:test';

async function demoModule() {
  return await import('../src/scripts/demo-state.ts');
}

test('a selected location and one record action change the demo from 6:6 to 8:6', async () => {
  const demo = await demoModule();
  assert.ok(demo, 'The demo state module must exist');
  let state = demo.initialDemoState();
  assert.equal(state.blue, 6);
  assert.equal(state.red, 6);
  state = demo.reduceDemo(state, { type: 'record' });
  assert.equal(state.phase, 'ready', 'A location is required');
  state = demo.reduceDemo(state, { type: 'select', point: { x: 0.3, y: 0.6 } });
  state = demo.reduceDemo(state, { type: 'record' });
  const generation = state.generation;
  state = demo.reduceDemo(state, { type: 'record' });
  assert.equal(state.blue, 8, 'Repeated clicks cannot add extra points');
  state = demo.reduceDemo(state, { type: 'complete', generation });
  assert.equal(state.phase, 'scored');
  assert.equal(state.hasLocation, true);
});

test('reset during flight rejects its stale completion and restores the initial result', async () => {
  const demo = await demoModule();
  assert.ok(demo, 'The demo state module must exist');
  let state = demo.reduceDemo(demo.initialDemoState(), {
    type: 'select',
    point: { x: 0.5, y: 0.5 },
  });
  state = demo.reduceDemo(state, { type: 'record' });
  const generation = state.generation;
  state = demo.reduceDemo(state, { type: 'reset' });
  state = demo.reduceDemo(state, { type: 'complete', generation });
  assert.equal(state.blue, 6);
  assert.equal(state.red, 6);
  assert.equal(state.point, null);
  assert.equal(state.hasLocation, false);
  assert.equal(state.phase, 'ready');
});

test('invalid and out-of-court locations cannot enter the demo', async () => {
  const demo = await demoModule();
  assert.ok(demo, 'The demo state module must exist');
  for (const point of [
    { x: NaN, y: 0 },
    { x: Infinity, y: 0.5 },
    { x: -0.1, y: 0.5 },
    { x: 0.5, y: 1.1 },
  ]) {
    const state = demo.reduceDemo(demo.initialDemoState(), {
      type: 'select',
      point,
    });
    assert.equal(state.point, null);
  }
});
