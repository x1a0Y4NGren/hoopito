import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import sharp from 'sharp';
import { mobileScenes } from '../src/data/mobile-scenes.ts';

const root = new URL('../', import.meta.url);
const digest = (bytes: Buffer) =>
  createHash('sha256').update(bytes).digest('hex');

test('phone plates retain three distinct reading cameras and portrait compositions', async () => {
  const poster = JSON.parse(
    await readFile(new URL('assets/art/scene-poster.json', root), 'utf8'),
  );
  const manifest = JSON.parse(
    await readFile(new URL('ASSET_SOURCES.json', root), 'utf8'),
  );
  assert.deepEqual(
    mobileScenes.map(({ id, chapter }) => [id, chapter]),
    [
      ['hero', 'hero'],
      ['court', 'scoring'],
      ['hoop', 'download'],
    ],
  );
  const hashes = new Set();
  for (const scene of mobileScenes) {
    const capture = poster.captures.find(
      (candidate: { id: string }) => candidate.id === scene.captureId,
    );
    assert.ok(capture, `Missing actual scene capture: ${scene.id}`);
    assert.equal(capture.pose.chapter, scene.chapter);
    assert.match(capture.engine, /^three\.js r\d+$/);
    assert.ok(
      capture.renderer,
      'The capture must record its actual GPU renderer',
    );
    const asset = manifest.assets.find(
      (candidate: { output: string }) =>
        candidate.output === `public${scene.src}`,
    );
    assert.ok(asset, `Missing production plate provenance: ${scene.id}`);
    const source = await readFile(
      new URL(`assets/art/${capture.source}`, root),
    );
    assert.equal(digest(source), capture.source_sha256);
    assert.equal(asset.source_sha256, capture.source_sha256);
    assert.deepEqual(asset.source_dimensions_px, [
      capture.width,
      capture.height,
    ]);
    assert.ok(asset.crop_px.left >= 0);
    assert.equal(asset.crop_px.top, 0);
    assert.ok(asset.crop_px.left + asset.crop_px.width <= capture.width);
    assert.equal(asset.crop_px.height, capture.height);
    assert.ok(
      Math.abs(asset.crop_px.width / asset.crop_px.height - 9 / 16) < 0.001,
    );
    const bytes = await readFile(new URL(`public${scene.src}`, root));
    const metadata = await sharp(bytes).metadata();
    assert.deepEqual([metadata.width, metadata.height], [720, 1280]);
    assert.deepEqual(asset.dimensions_px, [720, 1280]);
    assert.equal(digest(bytes), asset.sha256);
    assert.equal(bytes.length, asset.bytes);
    assert.ok(
      bytes.length <= 120 * 1024,
      `${scene.id} exceeds the plate budget`,
    );
    hashes.add(asset.sha256);
  }
  assert.equal(hashes.size, 3, 'Phone sections must not reuse the hero image');
});
