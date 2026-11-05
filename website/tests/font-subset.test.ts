import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { test } from 'node:test';
import { pathToFileURL } from 'node:url';
import { gzipSync } from 'node:zlib';
import { content } from '../src/data/content.ts';

const regular = await readFile(
  new URL('../../assets/fonts/NotoSansSC-Regular.otf', import.meta.url),
);
const black = await readFile(
  new URL('../assets/fonts/NotoSansSC-Black.otf', import.meta.url),
);
const fontTools = createRequire(
  createRequire(import.meta.url).resolve('subset-font'),
);
const fontverter = fontTools('fontverter');
const hb = await import(pathToFileURL(fontTools.resolve('harfbuzzjs')).href);
const faceFor = (bytes: Buffer) => new hb.Face(new hb.Blob(bytes));
const weight = (face: ReturnType<typeof faceFor>) =>
  Buffer.from(face.referenceTable('OS/2')).readUInt16BE(4);

async function helpers() {
  const module = await import('../scripts/poster-font.mjs').catch(() => null);
  assert.ok(module, 'poster titles have a reusable font-only preparation path');
  return module;
}

test('CSS declares the real static Noto weights and keeps English Barlow at 700', async () => {
  assert.equal(weight(faceFor(regular)), 400);
  assert.equal(weight(faceFor(black)), 900);
  assert.deepEqual(Object.keys(faceFor(regular).getAxisInfos()), []);
  assert.deepEqual(Object.keys(faceFor(black).getAxisInfos()), []);
  const css = await readFile(
    new URL('../src/styles/site.css', import.meta.url),
    'utf8',
  );
  const faces = [...css.matchAll(/@font-face\s*\{([^}]+)\}/g)].map(
    (match) => match[1]!,
  );
  const regularFace = faces.find((block) => /font-family:\s*Noto;/.test(block));
  assert.ok(regularFace);
  assert.match(regularFace, /font-weight:\s*400\s*;/);
  const posterFace = faces.find((block) =>
    /font-family:\s*NotoPoster;/.test(block),
  );
  assert.ok(posterFace, 'poster headings have a real Black face');
  assert.match(posterFace, /font-weight:\s*900\s*;/);
  assert.match(posterFace, /noto-poster-black\.woff2/);
  assert.ok(
    faces.some(
      (block) =>
        /barlow-bold\.woff2/.test(block) &&
        /font-weight:\s*700\s*;/.test(block),
    ),
  );
});

test('poster text includes only the approved Chinese chapter titles and FAQ heading', async () => {
  const { posterTitleText } = await helpers();
  const expected = [
    content.zh.hero.lines,
    content.zh.scoring.title,
    content.zh.demo.title,
    content.zh.replay.title,
    content.zh.download.title,
    content.zh.community.title,
    [content.zh.faqTitle],
  ]
    .flat()
    .join('');
  const requested = posterTitleText(content.zh);
  assert.deepEqual(
    [...requested],
    [...new Set(expected)].sort(
      (a, b) => a.codePointAt(0)! - b.codePointAt(0)!,
    ),
  );
  const changedBody = {
    ...content.zh,
    hero: {
      ...content.zh.hero,
      lead: content.zh.hero.lead + String.fromCodePoint(0x10ffff),
    },
    privacy: { ...content.zh.privacy, title: content.zh.privacy.title + '龘' },
  };
  assert.equal(
    posterTitleText(changedBody),
    requested,
    'body/privacy changes cannot expand the title subset',
  );
});

test('poster WOFF2 has true 900 outlines, covers exactly its title glyphs and stays under 35KiB gzip', async () => {
  const { createPosterFontSubset, posterTitleText } = await helpers();
  const result = await createPosterFontSubset(black, content.zh);
  assert.equal(result.bytes.toString('ascii', 0, 4), 'wOF2');
  assert.ok(gzipSync(result.bytes, { level: 9 }).length < 35 * 1024);
  assert.equal(result.gzipBytes, gzipSync(result.bytes, { level: 9 }).length);
  const generated = faceFor(await fontverter.convert(result.bytes, 'sfnt'));
  const source = faceFor(black);
  const body = faceFor(regular);
  const sourceFont = new hb.Font(source);
  const bodyFont = new hb.Font(body);
  const subsetFont = new hb.Font(generated);
  assert.equal(weight(generated), 900);
  assert.deepEqual(Object.keys(generated.getAxisInfos()), []);
  assert.equal(generated.upem, source.upem);
  const points = [...posterTitleText(content.zh)].map((character) =>
    character.codePointAt(0)!,
  );
  assert.deepEqual(result.requiredCodePoints, points);
  assert.deepEqual(
    [...generated.collectUnicodes()].sort((a, b) => a - b),
    points,
  );
  let differsFromRegular = false;
  for (const codePoint of points) {
    const originalGlyph = sourceFont.nominalGlyph(codePoint);
    const subsetGlyph = subsetFont.nominalGlyph(codePoint);
    assert.ok(
      originalGlyph && subsetGlyph,
      `U+${codePoint.toString(16)} renders in both fonts`,
    );
    const outline = subsetFont.glyphToJson(subsetGlyph);
    assert.ok(outline.length > 0);
    assert.deepEqual(outline, sourceFont.glyphToJson(originalGlyph));
    assert.equal(
      subsetFont.glyphHAdvance(subsetGlyph),
      sourceFont.glyphHAdvance(originalGlyph),
    );
    differsFromRegular ||=
      JSON.stringify(outline) !==
      JSON.stringify(bodyFont.glyphToJson(bodyFont.nominalGlyph(codePoint)));
  }
  assert.ok(differsFromRegular, 'a regular outline relabelled 900 cannot pass');
  for (const { nameId, language } of source
    .listNames()
    .filter(({ nameId }: { nameId: number }) =>
      [0, 7, 8, 9, 11, 13, 14].includes(nameId),
    )) {
    assert.equal(
      generated.getName(nameId, language),
      source.getName(nameId, language),
    );
  }
});

test('poster subsetting fails when an approved title contains an unsupported character', async () => {
  const { createPosterFontSubset } = await helpers();
  const changed = {
    ...content.zh,
    hero: {
      ...content.zh.hero,
      lines: [...content.zh.hero.lines, String.fromCodePoint(0x10ffff)],
    },
  };
  await assert.rejects(createPosterFontSubset(black, changed), /U\+10FFFF/);
  await assert.rejects(
    createPosterFontSubset(regular, content.zh),
    /static weight 900/,
  );
});

test('Black source provenance pins the official commit, original bytes and unmodified OFL license', async () => {
  const record = JSON.parse(
    await readFile(
      new URL('../assets/fonts/sources.json', import.meta.url),
      'utf8',
    ).catch(() => 'null'),
  );
  assert.ok(record, 'poster source provenance exists');
  const entry = record.fonts.find(
    (font: { weight: number }) => font.weight === 900,
  );
  assert.ok(entry);
  assert.equal(
    entry.upstream_commit,
    'f8d157532fbfaeda587e826d4cd5b21a49186f7c',
  );
  assert.equal(
    entry.source_url,
    `https://raw.githubusercontent.com/notofonts/noto-cjk/${entry.upstream_commit}/Sans/SubsetOTF/SC/NotoSansSC-Black.otf`,
  );
  assert.equal(
    entry.source_sha256,
    createHash('sha256').update(black).digest('hex'),
  );
  assert.equal(entry.source_bytes, black.length);
  assert.equal(entry.license, 'SIL-OFL-1.1');
  assert.match(entry.copyright, /2014-2021 Adobe/);
  assert.deepEqual(
    await readFile(
      new URL('../assets/fonts/OFL-NotoSansSC.txt', import.meta.url),
    ),
    await readFile(
      new URL('../../assets/fonts/OFL-NotoSansSC.txt', import.meta.url),
    ),
  );
});
