// ImageGen owns the invitation's atmosphere; the machine-readable QQ code is
// always inserted from the original user image without resampling or recoloring.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const repo = dirname(root);
const fontTools = createRequire(
  createRequire(import.meta.url).resolve('subset-font'),
);
const hb = await fontTools('harfbuzzjs');
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');

function lettering(bytes, text, x, y, size, color) {
  const blob = hb.createBlob(bytes),
    face = hb.createFace(blob, 0),
    font = hb.createFont(face),
    buffer = hb.createBuffer();
  try {
    buffer.addText(text);
    buffer.guessSegmentProperties();
    hb.shape(font, buffer);
    const scale = size / face.upem;
    let advance = 0;
    const paths = buffer
      .json()
      .map((glyph) => {
        assert.ok(glyph.g, `Missing invitation glyph: ${text}`);
        const path = `<path d="${font.glyphToPath(glyph.g)}" transform="translate(${advance + glyph.dx} ${glyph.dy})"/>`;
        advance += glyph.ax;
        return path;
      })
      .join('');
    return `<g fill="${color}" transform="translate(${x} ${y}) scale(${scale} ${-scale})">${paths}</g>`;
  } finally {
    buffer.destroy();
    font.destroy();
    face.destroy();
    blob.destroy();
  }
}

export async function prepareCommunityAssets() {
  const recordPath = 'website/assets/community/generation.json';
  const recordBytes = await readFile(join(repo, recordPath));
  const record = JSON.parse(recordBytes);
  const sources = [];
  async function source(path) {
    const bytes = await readFile(join(repo, path));
    sources.push({ source: path, sha256: sha256(bytes) });
    return bytes;
  }
  const original = await source(
    `website/assets/community/${record.original_qr_source}`,
  );
  assert.equal(
    sha256(original),
    record.original_qr_sha256,
    'Recalibrate the crop when replacing the group code',
  );
  const metadata = await sharp(original).metadata();
  assert.deepEqual(
    [metadata.width, metadata.height],
    record.original_dimensions_px,
  );
  const background = await source(
    `website/assets/community/${record.generated_source}`,
  );
  await source('website/scripts/prepare-community.mjs');
  assert.equal(sha256(background), record.generated_source_sha256);
  const logo = await source('assets/icons/hoopito-app-icon-foreground.png');
  const bold = await source('assets/fonts/BarlowCondensed-Bold.ttf');
  const noto = await source('assets/fonts/NotoSansSC-Regular.otf');
  const qr = await sharp(original).extract(record.qr_crop).png().toBuffer();
  const tightLogo = await sharp(logo)
    .extract({ left: 202, top: 204, width: 620, height: 614 })
    .resize(128, 128, { fit: 'inside' })
    .png()
    .toBuffer();
  const [width, height] = record.poster_dimensions_px;
  const panel = record.quiet_panel;
  const overlay = `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}">
    <rect width="${width}" height="${height}" fill="#080b0b" fill-opacity=".28"/>
    <rect x="${panel.left}" y="${panel.top}" width="${panel.width}" height="${panel.height}" fill="#fff"/>
    ${lettering(bold, 'HOOPITO', 344, 159, 88, '#F4F3EF')}
    ${lettering(noto, '· 球豆', 635, 154, 57, '#F4F3EF')}
    ${lettering(noto, `球友交流群 / QQ ${record.group_number}`, 344, 232, 38, '#F2BC9B')}
    ${lettering(noto, '用 QQ 扫码加入 · 一起聊球、聊产品', 334, 1519, 28, '#F4F3EF')}
  </svg>`;
  const png = await sharp(background)
    .resize(width, height, { fit: 'cover' })
    .composite([
      { input: Buffer.from(overlay) },
      { input: tightLogo, left: 176, top: 106 },
      { input: qr, ...record.qr_destination },
    ])
    .removeAlpha()
    .png({ compressionLevel: 9 })
    .toBuffer();
  const webp = await sharp(png).webp({ lossless: true, effort: 6 }).toBuffer();
  const expected = await sharp(original)
    .extract(record.qr_crop)
    .removeAlpha()
    .raw()
    .toBuffer();
  const entries = [];
  for (const [format, bytes] of [
    ['png', png],
    ['webp', webp],
  ]) {
    const actual = await sharp(bytes)
      .extract({
        ...record.qr_destination,
        width: record.qr_crop.width,
        height: record.qr_crop.height,
      })
      .removeAlpha()
      .raw()
      .toBuffer();
    assert.deepEqual(
      actual,
      expected,
      `${format} must retain every native QQ code pixel`,
    );
    const output = `public/community/hoopito-qq-group.${format}`;
    await mkdir(dirname(join(root, output)), { recursive: true });
    await writeFile(join(root, output), bytes);
    entries.push({
      output,
      bytes: bytes.length,
      sha256: sha256(bytes),
      source: `website/assets/community/${record.original_qr_source}`,
      source_sha256: sha256(original),
      generation_record: recordPath,
      generation_record_sha256: sha256(recordBytes),
      generated_with: record.generated_with,
      generation_mode: record.mode,
      source_inputs: sources,
      dimensions_px: [width, height],
      qr_crop: record.qr_crop,
      qr_destination: record.qr_destination,
      transformation: `ImageGen atmosphere resized to ${width}×${height}; original QQ code inserted at native dimensions with 128px added white quiet zone, approved mascot scaled, bundled font glyph paths; lossless ${format.toUpperCase()}; QR pixels verified identical.`,
      scan_verification: record.scan_verification,
    });
  }
  const preview = await sharp(png)
    .resize(768, 768)
    .webp({ lossless: true, effort: 6 })
    .toBuffer();
  const previewOutput = 'public/community/hoopito-qq-group-preview.webp';
  await writeFile(join(root, previewOutput), preview);
  entries.push({
    ...entries[1],
    output: previewOutput,
    bytes: preview.length,
    sha256: sha256(preview),
    dimensions_px: [768, 768],
    qr_crop: undefined,
    qr_destination: undefined,
    transformation:
      'Proportional 768×768 downsample of the full invitation, encoded as lossless WebP for lazy website/README preview. Native-size unmodified QR pixels remain available in the linked PNG and full WebP.',
  });
  return entries;
}

if (
  process.argv[1] &&
  resolve(process.argv[1]) === fileURLToPath(import.meta.url)
) {
  for (const asset of await prepareCommunityAssets())
    console.log(`${asset.output}: ${asset.bytes} bytes; ${asset.sha256}`);
}
