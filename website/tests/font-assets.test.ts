import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile, readdir } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { pathToFileURL } from 'node:url';

const fontTools = createRequire(
  createRequire(import.meta.url).resolve('subset-font'),
);
const fontverter = fontTools('fontverter');
const hb = await import(pathToFileURL(fontTools.resolve('harfbuzzjs')).href);
const sourceBytes = await readFile(
  new URL('../../assets/fonts/NotoSansSC-Regular.otf', import.meta.url),
);
const subsetBytes = await readFile(
  new URL('../public/fonts/noto-sc.woff2', import.meta.url),
);
const sourceFace = new hb.Face(new hb.Blob(sourceBytes));
const subsetFace = new hb.Face(
  new hb.Blob(await fontverter.convert(subsetBytes, 'sfnt')),
);
const sourceFont = new hb.Font(sourceFace);
const subsetFont = new hb.Font(subsetFace);
const ascii = Array.from({ length: 95 }, (_, index) => index + 32);
const requiredCodePoints = new Set<number>(ascii);
const sourceSupported = new Set<number>(sourceFace.collectUnicodes());
for (const character of '±×÷−→↗←↓↑···…') {
  const codePoint = character.codePointAt(0)!;
  if (sourceSupported.has(codePoint)) requiredCodePoints.add(codePoint);
}

// Required display characters come from current website sources, independently
// of the generated font manifest. A stale subset must not hide missing Han text.
async function collectHan(directory: URL): Promise<void> {
  for (const entry of await readdir(directory, { withFileTypes: true })) {
    const path = new URL(
      entry.name + (entry.isDirectory() ? '/' : ''),
      directory,
    );
    if (entry.isDirectory()) {
      await collectHan(path);
    } else if (/\.(?:astro|ts|js|json)$/.test(entry.name)) {
      const text = (await readFile(path, 'utf8')).replace(
        /\\u\{([\da-f]+)\}|\\u([\da-f]{4})/gi,
        (_, braced, basic) =>
          String.fromCodePoint(parseInt(braced ?? basic, 16)),
      );
      for (const character of text.match(/\p{Script=Han}/gu) ?? []) {
        requiredCodePoints.add(character.codePointAt(0)!);
      }
    }
  }
}
await collectHan(new URL('../src/', import.meta.url));

test('generated Noto WOFF2 covers website Han, ASCII and supported interface symbols', () => {
  assert.equal(subsetBytes.toString('ascii', 0, 4), 'wOF2');
  const supported = new Set<number>(subsetFace.collectUnicodes());
  assert.ok(
    [...requiredCodePoints].some((codePoint) =>
      /\p{Script=Han}/u.test(String.fromCodePoint(codePoint)),
    ),
    'Expected website Han text',
  );
  for (const codePoint of requiredCodePoints) {
    const label = `U+${codePoint.toString(16).toUpperCase()}`;
    assert.ok(
      sourceFont.nominalGlyph(codePoint),
      `${label} missing from source`,
    );
    assert.ok(supported.has(codePoint), `${label} missing from generated cmap`);
    assert.ok(subsetFont.nominalGlyph(codePoint), `${label} maps to .notdef`);
  }
});

test('subsetting preserves original outlines and advances by Unicode, despite glyph renumbering', () => {
  assert.equal(subsetFace.upem, sourceFace.upem);
  for (const codePoint of requiredCodePoints) {
    const label = `U+${codePoint.toString(16).toUpperCase()}`;
    const original = sourceFont.nominalGlyph(codePoint);
    const generated = subsetFont.nominalGlyph(codePoint);
    assert.ok(original && generated, `${label} must have both glyphs`);
    const outline = subsetFont.glyphToJson(generated);
    assert.deepEqual(outline, sourceFont.glyphToJson(original), label);
    if (codePoint !== 32) {
      assert.ok(outline.length > 0, `${label} lost its visible outline`);
    }
    assert.equal(
      subsetFont.glyphHAdvance(generated),
      sourceFont.glyphHAdvance(original),
      `${label} changed its advance`,
    );
  }
});

test('generated Noto retains original copyright, attribution and license name records', () => {
  const preserved = [0, 7, 8, 9, 11, 13, 14];
  const sourceNames: { nameId: number; language: string }[] = sourceFace
    .listNames()
    .filter(({ nameId }: { nameId: number }) => preserved.includes(nameId));
  assert.deepEqual(
    [...new Set(sourceNames.map(({ nameId }) => nameId))].sort(
      (left, right) => left - right,
    ),
    preserved,
  );
  for (const { nameId, language } of sourceNames) {
    const expected = sourceFace.getName(nameId, language);
    assert.ok(
      expected.length > 0,
      `Source name ${nameId} (${language}) is empty`,
    );
    assert.equal(
      subsetFace.getName(nameId, language),
      expected,
      `Name ${nameId} (${language}) was removed or rewritten`,
    );
  }
});

test('font provenance describes the actual generated WOFF2 and unchanged source', async () => {
  const manifest = JSON.parse(
    await readFile(new URL('../ASSET_SOURCES.json', import.meta.url), 'utf8'),
  );
  const record = manifest.assets.find(
    (asset: { output: string }) =>
      asset.output === 'public/fonts/noto-sc.woff2',
  );
  assert.ok(record, 'Generated Noto font must have provenance');
  const sha256 = (bytes: Buffer) =>
    createHash('sha256').update(bytes).digest('hex');
  assert.equal(record.bytes, subsetBytes.length);
  assert.equal(record.sha256, sha256(subsetBytes));
  assert.equal(record.source_sha256, sha256(sourceBytes));
  const requested = new Set<number>(record.subset_code_points);
  for (const codePoint of requiredCodePoints) {
    assert.ok(
      requested.has(codePoint),
      `Font provenance omitted U+${codePoint.toString(16)}`,
    );
  }
  assert.equal(record.license, 'SIL-OFL-1.1');
  assert.deepEqual(
    await readFile(
      new URL('../public/fonts/OFL-NotoSansSC.txt', import.meta.url),
    ),
    await readFile(
      new URL('../../assets/fonts/OFL-NotoSansSC.txt', import.meta.url),
    ),
  );
});
