import assert from 'node:assert/strict';
import test from 'node:test';
import { makeMaterialData } from '../scripts/material-data.mjs';

test('material data is deterministic linear information independent of albedo images', () => {
  for (const kind of ['maple', 'leather']) {
    const a = makeMaterialData(kind, 64),
      b = makeMaterialData(kind, 64);
    assert.equal(a.channels, 3);
    assert.equal(a.data.length, 64 * 64 * 3);
    assert.deepEqual(a.data, b.data);
    assert.ok(new Set(a.data).size > 12);
  }
});

test('packed maple normals and roughness stay within subtle physical ranges', () => {
  const { data } = makeMaterialData('maple', 128);
  for (let index = 0; index < data.length; index += 3) {
    assert.ok(data[index] >= 96 && data[index] <= 160);
    assert.ok(data[index + 1] >= 96 && data[index + 1] <= 160);
    assert.ok(data[index + 2] >= 75 && data[index + 2] <= 180);
  }
});

test('leather encodes neutral height equally in all channels with no baked light direction', () => {
  const { data } = makeMaterialData('leather', 64);
  for (let index = 0; index < data.length; index += 3) {
    assert.equal(data[index], data[index + 1]);
    assert.equal(data[index], data[index + 2]);
  }
});
