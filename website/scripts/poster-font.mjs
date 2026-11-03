import { createRequire } from 'node:module';
import { pathToFileURL } from 'node:url';
import { gzipSync } from 'node:zlib';
import subsetFont from 'subset-font';

const fontTools = createRequire(
  createRequire(import.meta.url).resolve('subset-font'),
);
const fontverter = fontTools('fontverter');
const hb = await import(pathToFileURL(fontTools.resolve('harfbuzzjs')).href);

export const posterFontFields = [
  'hero.lines',
  'scoring.title',
  'demo.title',
  'replay.title',
  'download.title',
  'community.title',
  'faqTitle',
];

/** Title-only scope: body copy and privacy edits cannot inflate this font. */
export function posterTitleText(zh) {
  const text = posterFontFields
    .map((path) => {
      const value = path.split('.').reduce((part, key) => part?.[key], zh);
      if (typeof value === 'string') return value;
      if (
        Array.isArray(value) &&
        value.every((line) => typeof line === 'string')
      )
        return value.join('');
      throw new Error(`Missing Chinese poster title: ${path}`);
    })
    .join('');
  return [...new Set(text)]
    .sort((a, b) => a.codePointAt(0) - b.codePointAt(0))
    .join('');
}

/** Return bytes and glyph evidence without writing files or the asset manifest. */
export async function createPosterFontSubset(sourceBytes, zh) {
  const sourceFace = new hb.Face(new hb.Blob(sourceBytes));
  const os2 = Buffer.from(sourceFace.referenceTable('OS/2'));
  if (
    os2.length < 6 ||
    os2.readUInt16BE(4) !== 900 ||
    Object.keys(sourceFace.getAxisInfos()).length
  ) {
    throw new Error(
      'Chinese poster font must be an actual static weight 900 source.',
    );
  }
  const text = posterTitleText(zh);
  const requiredCodePoints = [...text].map((character) =>
    character.codePointAt(0),
  );
  const sourceFont = new hb.Font(sourceFace);
  for (const codePoint of requiredCodePoints) {
    if (!sourceFont.nominalGlyph(codePoint))
      throw new Error(
        `Chinese poster font cannot render U+${codePoint.toString(16).toUpperCase()}.`,
      );
  }
  const bytes = await subsetFont(sourceBytes, text, {
    targetFormat: 'woff2',
    preserveNameIds: [0, 7, 8, 9, 11, 13, 14],
  });
  const face = new hb.Face(
    new hb.Blob(await fontverter.convert(bytes, 'sfnt')),
  );
  const font = new hb.Font(face);
  for (const codePoint of requiredCodePoints) {
    if (!font.nominalGlyph(codePoint))
      throw new Error(
        `Chinese poster subset lost U+${codePoint.toString(16).toUpperCase()}.`,
      );
  }
  const gzipBytes = gzipSync(bytes, { level: 9 }).length;
  if (gzipBytes >= 35 * 1024)
    throw new Error('Chinese poster font exceeds its 35KiB gzip budget.');
  return { bytes, requiredCodePoints, gzipBytes };
}
