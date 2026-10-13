import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import sharp from 'sharp';
import { presentationForCapture } from '../scripts/screenshot-presentation.mjs';

const record = JSON.parse(
  await readFile(
    new URL('../../docs/release/v2.0.1-screenshots.json', import.meta.url),
    'utf8',
  ),
);

test('presentation rejects uncalibrated sizes and unknown screenshots', () => {
  assert.throws(
    () =>
      presentationForCapture({
        path: '1-home.png',
        dimensions_px: [1080, 2400],
      }),
    /Uncalibrated screenshot dimensions/,
  );
  assert.throws(
    () =>
      presentationForCapture({
        path: '5-settings.png',
        dimensions_px: [1080, 1920],
      }),
    /Missing screenshot presentation/,
  );
});

for (const capture of record.captures) {
  test(`${capture.locale} ${capture.source_capture}: display is a lossless app-only crop of unchanged evidence`, async () => {
    const source = await readFile(
      new URL(`../../${capture.path}`, import.meta.url),
    );
    assert.equal(
      createHash('sha256').update(source).digest('hex'),
      capture.png_sha256,
    );
    const { name, extract } = presentationForCapture(capture);
    const expected = await sharp(source)
      .extract(extract)
      .ensureAlpha()
      .raw()
      .toBuffer();
    const display = await readFile(
      new URL(
        `../public/screenshots/${capture.locale}/${name}.webp`,
        import.meta.url,
      ),
    );
    const { data, info } = await sharp(display)
      .ensureAlpha()
      .raw()
      .toBuffer({ resolveWithObject: true });
    assert.equal(info.width, extract.width);
    assert.equal(info.height, extract.height);
    assert.equal(
      data.equals(expected),
      true,
      'App content must not be rescaled, repainted or recompressed lossily',
    );
    if (name !== 'scoring') {
      // All six captures have a plain App background above their own title bar.
      // This catches remnants of the clock/battery that a matching-crop test cannot.
      const background = Array.from(data.subarray(0, info.channels));
      for (let y = 0; y < 10; y++) {
        for (let x = 0; x < info.width; x++) {
          const pixel = (y * info.width + x) * info.channels;
          for (let channel = 0; channel < 3; channel++) {
            assert.ok(
              Math.abs(data[pixel + channel]! - background[channel]!) <= 1,
              `System glyph remains above the App title at ${x},${y}`,
            );
          }
        }
      }
    }
  });
}
