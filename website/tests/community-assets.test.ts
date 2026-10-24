import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { test } from 'node:test';
import sharp from 'sharp';

const generation = JSON.parse(
  await readFile(
    new URL('../assets/community/generation.json', import.meta.url),
    'utf8',
  ),
);
for (const format of ['png', 'webp']) {
  test(`community ${format} preserves every original QQ code pixel and its quiet zone`, async () => {
    const source = await sharp(
      await readFile(
        new URL(
          '../assets/community/source/qq-group-original.jpg',
          import.meta.url,
        ),
      ),
    )
      .extract(generation.qr_crop)
      .removeAlpha()
      .raw()
      .toBuffer();
    const bytes = await readFile(
      new URL(
        `../public/community/hoopito-qq-group.${format}`,
        import.meta.url,
      ),
    );
    const output = sharp(bytes);
    const meta = await output.metadata();
    assert.equal(meta.width, 1536);
    assert.equal(meta.height, 1536);
    const actual = await output
      .extract({
        ...generation.qr_destination,
        width: generation.qr_crop.width,
        height: generation.qr_crop.height,
      })
      .removeAlpha()
      .raw()
      .toBuffer();
    assert.deepEqual(
      actual,
      source,
      'Do not let ImageGen redraw, blur, resize or recolor the actual QQ code',
    );
    const panel = generation.quiet_panel;
    const inset = 8;
    for (const area of [
      {
        left: panel.left + inset,
        top: panel.top + inset,
        width: panel.width - 2 * inset,
        height: 100,
      },
      {
        left: panel.left + inset,
        top: panel.top + panel.height - inset - 100,
        width: panel.width - 2 * inset,
        height: 100,
      },
      {
        left: panel.left + inset,
        top: panel.top + 120,
        width: 100,
        height: panel.height - 240,
      },
      {
        left: panel.left + panel.width - inset - 100,
        top: panel.top + 120,
        width: 100,
        height: panel.height - 240,
      },
    ]) {
      const quiet = await sharp(bytes)
        .extract(area)
        .removeAlpha()
        .raw()
        .toBuffer();
      assert.ok(
        quiet.every((value) => value === 255),
        'Keep a plain white quiet zone away from decoration',
      );
    }
  });
}
