import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  COURT_LIGHTING,
  sampleFloorLighting,
} from '../src/scripts/court-lighting.ts';

test('cached floor lamps read the same source and story strength as scene lights', () => {
  const { key, amber, hemisphere } = COURT_LIGHTING;
  assert.ok(key.position[1] > 7 && amber.position[1] > 7);
  assert.ok(
    hemisphere.intensity >= 0.25,
    'Ambient fill retains the training arena structure',
  );
  const on = sampleFloorLighting(0, -2, 1);
  const dim = sampleFloorLighting(0, -2, 0.25);
  const off = sampleFloorLighting(0, -2, 0);
  for (let index = 0; index < 3; index++) {
    assert.equal(dim.dynamic[index], on.dynamic[index]! * 0.25);
    assert.equal(off.dynamic[index], 0);
    assert.equal(dim.fixed[index], on.fixed[index]);
  }
});
