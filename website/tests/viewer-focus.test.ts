import { test } from 'node:test';
import assert from 'node:assert/strict';
import { constrainView, zoomView } from '../src/scripts/presentation-state.ts';

test('viewer bounds keep fit images centered and let enlarged content reach its edges', () => {
  const size = { width: 300, height: 500, imageWidth: 280, imageHeight: 462 };
  assert.deepEqual(constrainView({ zoom: 1, x: 500, y: -500 }, size), {
    zoom: 1,
    x: 0,
    y: 0,
  });
  assert.deepEqual(constrainView({ zoom: 4, x: 500, y: -999 }, size), {
    zoom: 4,
    x: 410,
    y: -674,
  });
  assert.equal(constrainView({ zoom: 8, x: 0, y: 0 }, size).zoom, 4);
  assert.equal(constrainView({ zoom: 0, x: 0, y: 0 }, size).zoom, 1);
});

test('zoom keeps the selected point fixed until an image edge constrains it', () => {
  const size = { width: 300, height: 500, imageWidth: 280, imageHeight: 462 };
  assert.deepEqual(
    zoomView({ zoom: 1, x: 0, y: 0 }, 2, { x: 50, y: 60 }, size),
    { zoom: 2, x: -50, y: -60 },
  );
  assert.deepEqual(
    zoomView({ zoom: 3, x: 100, y: 40 }, 1, { x: 50, y: 60 }, size),
    { zoom: 1, x: 0, y: 0 },
  );
});
