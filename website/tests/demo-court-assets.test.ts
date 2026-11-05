import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import sharp from 'sharp';
import { encodeDemoCourtAsset } from '../scripts/prepare-demo-court.mjs';
import { demoCourtArt } from '../src/data/demo-court-art.ts';

const digest = (bytes: Buffer) =>
  createHash('sha256').update(bytes).digest('hex');

async function sourceFixture(alpha = true) {
  // A small test-only raster supplies known transparent gutters around an object.
  const width = 800,
    height = 400,
    channels = alpha ? 4 : 3;
  const data = Buffer.alloc(width * height * channels);
  for (let y = 20; y < height - 20; y++)
    for (let x = 30; x < width - 30; x++) {
      const at = (y * width + x) * channels;
      data[at] = 180;
      data[at + 1] = 125;
      data[at + 2] = 65;
      if (alpha) data[at + 3] = 255;
    }
  return sharp(data, { raw: { width, height, channels: alpha ? 4 : 3 } })
    .png()
    .toBuffer();
}

test('hoop export keeps genuine alpha, source proportions and its measured rim registration', async () => {
  const source = await sourceFixture();
  const asset = {
    id: 'hoop',
    source_sha256: digest(source),
    source_dimensions_px: [800, 400],
    crop_px: { left: 20, top: 10, width: 760, height: 380 },
    rim_anchor_px: { cx: 400, cy: 250, rx: 100, ry: 43.75 },
  };
  const { bytes, provenance } = await encodeDemoCourtAsset(source, asset);
  assert.ok(bytes.length <= 24 * 1024);
  assert.deepEqual(provenance.dimensions_px, [512, 256]);
  assert.equal((await sharp(bytes).metadata()).hasAlpha, true);
  assert.ok(provenance.alpha_pixels);
  assert.ok(provenance.alpha_pixels.transparent > 0);
  assert.ok(provenance.alpha_pixels.solid > 0);
  const anchor = provenance.rim_anchor_px_production;
  const placement = provenance.placement_svg;
  assert.ok(anchor && placement);
  const scale = placement.width / 512;
  assert.ok(Math.abs(placement.x + anchor.cx * scale - 300) < 1e-8);
  assert.ok(Math.abs(placement.y + anchor.cy * scale - 82) < 1e-8);
  assert.ok(Math.abs(anchor.rx * scale - 20) < 1e-8);
  assert.ok(Math.abs(anchor.ry * scale - 8.75) < 1e-8);
  assert.ok(Math.abs(placement.width / placement.height - 2) < 1e-8);
});

test('the generator rejects stale source identity and fake opaque hoop art', async () => {
  const source = await sourceFixture(false);
  const asset = {
    id: 'hoop',
    source_sha256: digest(source),
    source_dimensions_px: [800, 400],
    rim_anchor_px: { cx: 400, cy: 250, rx: 100, ry: 43.75 },
  };
  await assert.rejects(encodeDemoCourtAsset(source, asset), /real transparent/);
  await assert.rejects(
    encodeDemoCourtAsset(source, { ...asset, source_sha256: 'invalid' }),
    /source changed/,
  );
  await assert.rejects(
    encodeDemoCourtAsset(source, { ...asset, source_dimensions_px: [2, 4] }),
    /dimensions changed/,
  );
});

test('floor export stays square and never silently stretches a non-square material', async () => {
  const source = await sharp({
    create: { width: 800, height: 800, channels: 3, background: '#b78a52' },
  })
    .png()
    .toBuffer();
  const asset = {
    id: 'maple',
    source_sha256: digest(source),
    source_dimensions_px: [800, 800],
  };
  const exported = await encodeDemoCourtAsset(source, asset);
  assert.deepEqual(exported.provenance.dimensions_px, [384, 384]);
  assert.ok(exported.bytes.length <= 12 * 1024);
  await assert.rejects(
    encodeDemoCourtAsset(source, {
      ...asset,
      crop_px: { left: 0, top: 0, width: 800, height: 400 },
    }),
    /must be square/,
  );
});

test('selected independent generated assets reproduce their production files and the actual SVG registration', async () => {
  const record = JSON.parse(
    await readFile(
      new URL(
        '../assets/materials/demo-court-generation-v2.json',
        import.meta.url,
      ),
      'utf8',
    ),
  );
  assert.equal(record.tool, 'image_gen.imagegen');
  assert.equal(record.mode, 'built-in');
  assert.deepEqual(
    record.assets.map((asset: { id: string }) => asset.id),
    ['maple', 'hoop'],
  );
  for (const asset of record.assets) {
    assert.ok(asset.prompt.length > 100);
    assert.ok(!asset.source.endsWith('maple-floor-v4.png'));
    const source = await readFile(
      new URL(`../assets/materials/${asset.source}`, import.meta.url),
    );
    assert.equal(digest(source), asset.source_sha256);
    const result = await encodeDemoCourtAsset(source, asset);
    const path =
      asset.id === 'maple' ? demoCourtArt.floor.src : demoCourtArt.hoop.src;
    assert.deepEqual(
      result.bytes,
      await readFile(new URL(`../public${path}`, import.meta.url)),
    );
    if (asset.id === 'hoop') {
      assert.equal(asset.rim_shape, 'circle');
      assert.equal(asset.rim_anchor_px.rx, asset.rim_anchor_px.ry);
      assert.ok(result.provenance.placement_svg);
      for (const dimension of ['x', 'y', 'width', 'height'] as const)
        assert.ok(
          Math.abs(
            result.provenance.placement_svg[dimension] -
              demoCourtArt.hoop.placement[dimension],
          ) < 1e-8,
          `The generated hoop ${dimension} must agree with its SVG image`,
        );
    }
  }
});
