import assert from 'node:assert/strict';
import { test } from 'node:test';

test('density uses 1.25 as a target and respects the five-million-pixel budget at 4K', async () => {
  const { renderDensity } = await import('../src/scripts/scene-performance.ts');
  assert.equal(renderDensity(2, 'density', 1920, 1080), 1.25);
  assert.equal(renderDensity(1, 'density', 1920, 1080), 1);
  const fourK = renderDensity(2, 'density', 3840, 2160);
  assert.ok(fourK < 1, 'The budget can lower density below one');
  assert.ok(3840 * 2160 * fourK ** 2 <= 5_000_000 + 0.001);
  assert.ok(Math.abs(fourK - 0.776412492187427) < 0.000001);
});

test('density preserves fractional device ratios and normalizes invalid dimensions', async () => {
  const { renderDensity } = await import('../src/scripts/scene-performance.ts');
  assert.equal(renderDensity(0.8, 'density', 1920, 1080), 0.8);
  for (const ratio of [NaN, Infinity, 0, -1]) {
    assert.equal(renderDensity(ratio, 'density', 1920, 1080), 1);
  }
  for (const dimension of [NaN, Infinity, 0, -100]) {
    assert.equal(renderDensity(2, 'density', dimension, 1080), 1.25);
    assert.equal(renderDensity(2, 'density', 1920, dimension), 1.25);
  }
});

test('full and effects retain their existing density policy', async () => {
  const { renderDensity } = await import('../src/scripts/scene-performance.ts');
  for (const quality of ['full', 'effects'] as const) {
    assert.equal(renderDensity(2, quality, 1440, 900), 1.9641855032959652);
    assert.equal(renderDensity(2, quality, 3840, 2160), 1.5);
    assert.equal(renderDensity(1, quality, 1920, 1080), 1);
  }
});

test('density HDR uses only actual supported two-sample MSAA and otherwise falls back', async () => {
  const { sceneMsaaSamples } =
    await import('../src/scripts/scene-performance.ts');
  assert.equal(sceneMsaaSamples('density', 0.77, [8, 4, 2]), 2);
  assert.equal(sceneMsaaSamples('density', 1.25, [8, 4]), 0);
  assert.equal(sceneMsaaSamples('density', 1.25, []), 0);
  assert.equal(
    sceneMsaaSamples('density', 1.25, [0, 1, NaN, Infinity, 2.5]),
    0,
  );
});

test('other HDR tiers retain their supported MSAA limit based on drawing density', async () => {
  const { sceneMsaaSamples } =
    await import('../src/scripts/scene-performance.ts');
  for (const quality of ['full', 'effects'] as const) {
    assert.equal(sceneMsaaSamples(quality, 1, [8, 4, 2]), 4);
    assert.equal(sceneMsaaSamples(quality, 1.5, [8, 4, 2]), 2);
    assert.equal(sceneMsaaSamples(quality, 2, [8, 4]), 0);
    assert.equal(sceneMsaaSamples(quality, 1, [8, 2]), 2);
  }
});
