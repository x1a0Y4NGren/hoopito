import { createHash } from 'node:crypto';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, join, relative } from 'node:path';
import { fileURLToPath } from 'node:url';
import sharp from 'sharp';
import subsetFont from 'subset-font';
import QRCode from 'qrcode';
import { release } from '../src/data/release.ts';
import { courtTextures } from '../src/data/court-materials.ts';

const websiteRoot = dirname(dirname(fileURLToPath(import.meta.url)));
const repositoryRoot = dirname(websiteRoot);
const publicRoot = join(websiteRoot, 'public');
const scriptSha256 = createHash('sha256')
  .update(await readFile(fileURLToPath(import.meta.url)))
  .digest('hex');
// Resolve build tools through their declared owner, including non-hoisted installs.
const fontTools = createRequire(
  createRequire(import.meta.url).resolve('subset-font'),
);
const fontverter = fontTools('fontverter');
const hb = await fontTools('harfbuzzjs');
const sourceRecord = 'docs/release/v2.0.0-screenshots.json';
const screenshots = JSON.parse(
  await readFile(join(repositoryRoot, sourceRecord), 'utf8'),
);
const assets = [];
const ascii = Array.from({ length: 95 }, (_, index) =>
  String.fromCharCode(index + 32),
).join('');
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const portable = (path) => path.replaceAll('\\', '/');

async function output(destination, bytes, provenance) {
  const path = join(publicRoot, destination);
  await mkdir(dirname(path), { recursive: true });
  await writeFile(path, bytes);
  const entry = {
    output: `public/${portable(destination)}`,
    bytes: bytes.length,
    sha256: sha256(bytes),
    ...provenance,
  };
  assets.push(entry);
  console.log(`${entry.output}: ${entry.bytes.toLocaleString('en-US')} bytes`);
}

async function localSource(path) {
  const bytes = await readFile(join(repositoryRoot, path));
  return { bytes, source: path, source_sha256: sha256(bytes) };
}

const materialRecord = 'website/assets/materials/generation.json';
const materialProvenance = await localSource(materialRecord);
const materialGeneration = JSON.parse(
  materialProvenance.bytes.toString('utf8'),
);
for (const [id, maximumSize, quality] of [
  ['maple', 2048, 88],
  ['metal', 1024, 80],
  ['glass', 512, 75],
]) {
  const asset = materialGeneration.assets.find((entry) => entry.id === id);
  if (!asset) throw new Error(`Missing generated court material: ${id}`);
  const source = await localSource(`website/assets/materials/${asset.source}`);
  const optimized = await sharp(source.bytes)
    .resize(maximumSize, maximumSize, {
      fit: 'inside',
      withoutEnlargement: true,
    })
    .webp({ quality, effort: 6 })
    .toBuffer();
  const metadata = await sharp(optimized).metadata();
  await output(courtTextures[id].slice(1), optimized, {
    source: source.source,
    source_sha256: source.source_sha256,
    generation_record: materialRecord,
    generation_record_sha256: materialProvenance.source_sha256,
    generated_with: materialGeneration.tool,
    generation_mode: materialGeneration.mode,
    dimensions_px: [metadata.width, metadata.height],
    transformation: `Proportional resize up to ${maximumSize}px; WebP quality ${quality}; no baked scene lighting or court markings added`,
  });
}

async function sourceFiles(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const files = [];
  for (const entry of entries.sort((left, right) =>
    left.name.localeCompare(right.name, 'en'),
  )) {
    const path = join(directory, entry.name);
    if (entry.isDirectory()) files.push(...(await sourceFiles(path)));
    else if (/\.(?:astro|ts|js|json)$/.test(entry.name)) files.push(path);
  }
  return files;
}

function withFont(bytes, run) {
  const blob = hb.createBlob(bytes);
  const face = hb.createFace(blob, 0);
  const font = hb.createFont(face);
  try {
    return run(font, face);
  } finally {
    font.destroy();
    face.destroy();
    blob.destroy();
  }
}

function glyphPaths(bytes, text, { x, y, size, color, tracking = 0 }) {
  return withFont(bytes, (font, face) => {
    const buffer = hb.createBuffer();
    try {
      buffer.addText(text);
      buffer.guessSegmentProperties();
      hb.shape(font, buffer);
      const scale = size / face.upem;
      let advance = 0;
      const paths = buffer
        .json()
        .map((glyph) => {
          if (!glyph.g)
            throw new Error(`Share graphic font cannot render ${text}`);
          const path = `<path d="${font.glyphToPath(glyph.g)}" transform="translate(${advance + glyph.dx} ${glyph.dy})"/>`;
          advance += glyph.ax + tracking / scale;
          return path;
        })
        .join('');
      return `<g fill="${color}" transform="translate(${x} ${y}) scale(${scale} ${-scale})">${paths}</g>`;
    } finally {
      buffer.destroy();
    }
  });
}

for (const capture of screenshots.captures) {
  if (capture.fixture.synthetic_only !== true) {
    throw new Error(
      `Website screenshots must contain synthetic data only: ${capture.path}`,
    );
  }
  const source = await localSource(capture.path);
  if (source.source_sha256 !== capture.png_sha256) {
    throw new Error(
      `Screenshot no longer matches its release provenance: ${capture.path}`,
    );
  }
  const metadata = await sharp(source.bytes).metadata();
  if (
    metadata.width !== capture.dimensions_px[0] ||
    metadata.height !== capture.dimensions_px[1]
  ) {
    throw new Error(
      `Screenshot dimensions differ from the original record: ${capture.path}`,
    );
  }
  const name = capture.path
    .split('/')
    .at(-1)
    .replace(/^\d-/, '')
    .replace('.png', '.webp');
  const optimized = await sharp(source.bytes)
    .webp({ lossless: true, effort: 6 })
    .toBuffer();
  await output(`screenshots/${capture.locale}/${name}`, optimized, {
    source: source.source,
    source_sha256: source.source_sha256,
    transformation:
      'Lossless WebP encoding; original dimensions and all system bars retained; no cropping or repainting',
    dimensions_px: capture.dimensions_px,
    locale: capture.locale,
    theme: capture.theme,
    screenshot_record: sourceRecord,
    source_capture: capture.source_capture,
    captured_at_utc: capture.captured_at_utc,
    synthetic_only: capture.fixture.synthetic_only,
    license: 'MIT (repository artwork)',
  });
}

const logo = await localSource(
  'assets/icons/hooptrace-app-icon-foreground.png',
);
const brandApproval = JSON.parse(
  await readFile(join(repositoryRoot, 'docs/design/brand/source.json'), 'utf8'),
);
if (logo.source_sha256 !== brandApproval.normalizedForegroundSha256) {
  throw new Error(
    'The logo source no longer matches the approved C production foreground.',
  );
}
const mark = await sharp(logo.bytes)
  .resize(512, 512)
  .webp({ lossless: true, effort: 6 })
  .toBuffer();
await output('brand/mark.webp', mark, {
  source: logo.source,
  source_sha256: logo.source_sha256,
  approval_record: 'docs/design/brand/source.json',
  dimensions_px: [512, 512],
  transformation:
    'Proportional resize only; alpha transparency and approved C geometry preserved',
  license: 'MIT (repository artwork)',
});
await output(
  'brand/favicon.png',
  await sharp(logo.bytes).resize(96, 96).png().toBuffer(),
  {
    source: logo.source,
    source_sha256: logo.source_sha256,
    approval_record: 'docs/design/brand/source.json',
    dimensions_px: [96, 96],
    transformation:
      'Proportional resize only; approved C mark on transparent canvas',
    license: 'MIT (repository artwork)',
  },
);

const fontCopyright = {
  barlow:
    'Copyright 2017 The Barlow Project Authors (https://github.com/jpt/barlow)',
  noto: '© 2014-2021 Adobe (http://www.adobe.com/).',
};
for (const [weight, filename] of [
  ['medium', 'Medium'],
  ['semibold', 'SemiBold'],
  ['bold', 'Bold'],
]) {
  const source = await localSource(
    `assets/fonts/BarlowCondensed-${filename}.ttf`,
  );
  await output(
    `fonts/barlow-${weight}.woff2`,
    await fontverter.convert(source.bytes, 'woff2'),
    {
      source: source.source,
      source_sha256: source.source_sha256,
      transformation: 'WOFF2 conversion; original font glyph set retained',
      license: 'SIL-OFL-1.1',
      license_file: 'public/fonts/OFL-Barlow.txt',
      copyright: fontCopyright.barlow,
    },
  );
}

const textSources = [];
const textParts = [ascii, '±×÷−→↗←↓↑···…0123456789 : + / %'];
for (const path of await sourceFiles(join(websiteRoot, 'src'))) {
  const bytes = await readFile(path);
  const text = bytes.toString('utf8');
  textSources.push({
    path: portable(relative(websiteRoot, path)),
    sha256: sha256(bytes),
  });
  textParts.push(
    text.replace(/\\u\{([\da-f]+)\}|\\u([\da-f]{4})/gi, (_, braced, basic) =>
      String.fromCodePoint(parseInt(braced ?? basic, 16)),
    ),
  );
}
if (!textSources.some(({ path }) => path === 'src/data/content.ts')) {
  throw new Error(
    'Create src/data/content.ts before preparing the Chinese font.',
  );
}
const glyphText = [...new Set(textParts.join(''))]
  .sort((left, right) => left.codePointAt(0) - right.codePointAt(0))
  .join('');
const noto = await localSource('assets/fonts/NotoSansSC-Regular.otf');
const notoSubset = await subsetFont(noto.bytes, glyphText, {
  targetFormat: 'woff2',
  preserveNameIds: [0, 7, 8, 9, 11, 13, 14],
});
// Check actual Han and ASCII rendering against the resulting subset, not filenames.
const requiredGlyphs = [
  ...new Set(`${ascii}${glyphText.match(/\p{Script=Han}/gu)?.join('') ?? ''}`),
].join('');
withFont(await fontverter.convert(notoSubset, 'sfnt'), (font) => {
  const buffer = hb.createBuffer();
  try {
    buffer.addText(requiredGlyphs);
    buffer.guessSegmentProperties();
    hb.shape(font, buffer);
    if (buffer.json().some(({ g }) => g === 0))
      throw new Error(
        'The Chinese subset is missing a required website character.',
      );
  } finally {
    buffer.destroy();
  }
});
await output('fonts/noto-sc.woff2', notoSubset, {
  source: noto.source,
  source_sha256: noto.source_sha256,
  upstream_commit: 'f8d157532fbfaeda587e826d4cd5b21a49186f7c',
  transformation:
    'WOFF2 glyph subset from all website Astro/TypeScript/JavaScript/JSON sources, printable ASCII, and interface symbols; original app font untouched',
  subset_code_points: [...glyphText].map((character) =>
    character.codePointAt(0),
  ),
  text_sources: textSources,
  license: 'SIL-OFL-1.1',
  license_file: 'public/fonts/OFL-NotoSansSC.txt',
  copyright: fontCopyright.noto,
});
for (const [sourcePath, destination] of [
  ['assets/fonts/OFL.txt', 'fonts/OFL-Barlow.txt'],
  ['assets/fonts/OFL-NotoSansSC.txt', 'fonts/OFL-NotoSansSC.txt'],
]) {
  const source = await localSource(sourcePath);
  await output(destination, source.bytes, {
    source: source.source,
    source_sha256: source.source_sha256,
    transformation: 'Verbatim license copy',
    license: 'SIL-OFL-1.1',
  });
}

const qr = await QRCode.toString(release.releaseUrl, {
  type: 'svg',
  errorCorrectionLevel: 'M',
  margin: 4,
  width: 256,
  color: { dark: '#101112', light: '#F4F3EF' },
});
await output('brand/release-qr.svg', Buffer.from(qr), {
  source: 'src/data/release.ts',
  source_sha256: sha256(
    await readFile(join(websiteRoot, 'src/data/release.ts')),
  ),
  payload: release.releaseUrl,
  transformation:
    'QR code generated with qrcode; four-module quiet zone preserved',
  license: 'MIT (repository-generated graphic)',
});

const bold = await readFile(
  join(repositoryRoot, 'assets/fonts/BarlowCondensed-Bold.ttf'),
);
const medium = await readFile(
  join(repositoryRoot, 'assets/fonts/BarlowCondensed-Medium.ttf'),
);
const share = `<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="630" viewBox="0 0 1200 630">
<defs>
  <linearGradient id="bg" x2="1" y2="1"><stop stop-color="#16191C"/><stop offset="1" stop-color="#080A0C"/></linearGradient>
  <radialGradient id="light"><stop stop-color="#FF5A1F" stop-opacity=".22"/><stop offset="1" stop-color="#FF5A1F" stop-opacity="0"/></radialGradient>
</defs>
<rect width="1200" height="630" fill="url(#bg)"/>
<ellipse cx="965" cy="310" rx="440" ry="390" fill="url(#light)"/>
<g fill="none" stroke="#FF5A1F" stroke-opacity=".28" stroke-width="2" transform="matrix(1 .22 -.45 .68 792 48)">
  <path d="M0 0H340V630H0Z M95 0V190H245V0 M95 190A75 75 0 0 0 245 190 M42 0V42A130 130 0 0 0 298 42V0"/>
</g>
<path d="M64 73H118" stroke="#FF5A1F" stroke-width="4"/>
${glyphPaths(medium, 'HOOPTRACE', { x: 137, y: 86, size: 31, tracking: 5, color: '#F4F3EF' })}
${glyphPaths(bold, 'EVERY SHOT.', { x: 62, y: 264, size: 115, color: '#F4F3EF' })}
${glyphPaths(bold, 'LEAVES A TRACE.', { x: 62, y: 390, size: 115, color: '#FF5A1F' })}
${glyphPaths(medium, 'OFFLINE 1v1 BASKETBALL', { x: 66, y: 467, size: 29, tracking: 3, color: '#AAA9A5' })}
${glyphPaths(medium, 'FREE / OPEN SOURCE / ANDROID', { x: 66, y: 558, size: 19, tracking: 2, color: '#80827F' })}
<image href="data:image/png;base64,${logo.bytes.toString('base64')}" x="825" y="195" width="300" height="300"/>
<path d="M64 585H1136" stroke="#F4F3EF" stroke-opacity=".12"/>
</svg>`;
await output(
  'brand/share.png',
  await sharp(Buffer.from(share)).png({ compressionLevel: 9 }).toBuffer(),
  {
    source: 'scripts/prepare-assets.mjs',
    source_sha256: scriptSha256,
    source_dependencies: [
      { source: logo.source, sha256: logo.source_sha256 },
      { source: 'assets/fonts/BarlowCondensed-Bold.ttf', sha256: sha256(bold) },
      {
        source: 'assets/fonts/BarlowCondensed-Medium.ttf',
        sha256: sha256(medium),
      },
    ],
    transformation:
      'Original SVG composition rasterized to PNG; embedded approved logo only scaled; Barlow lettering converted to glyph paths for portable rendering',
    dimensions_px: [1200, 630],
    license: 'MIT (repository graphic), SIL-OFL-1.1 (Barlow glyphs)',
  },
);

for (const [packageName, licenseFilename] of [
  ['astro', 'LICENSE'],
  ['three', 'LICENSE'],
  ['typescript', 'LICENSE.txt'],
  ['sharp', 'LICENSE'],
  ['qrcode', 'license'],
  ['subset-font', 'LICENSE'],
]) {
  const require = createRequire(import.meta.url);
  // Some packages intentionally do not export their package.json subpath.
  let packageRoot = dirname(require.resolve(packageName));
  let packageJson;
  while (true) {
    try {
      const candidate = JSON.parse(
        await readFile(join(packageRoot, 'package.json'), 'utf8'),
      );
      if (candidate.name === packageName) {
        packageJson = candidate;
        break;
      }
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
    const parent = dirname(packageRoot);
    if (parent === packageRoot)
      throw new Error(`Cannot locate ${packageName}'s package root.`);
    packageRoot = parent;
  }
  let license;
  let licenseSource;
  for (const name of [licenseFilename, 'LICENSE', 'LICENSE.txt', 'license']) {
    try {
      license = await readFile(join(packageRoot, name));
      licenseSource = name;
      break;
    } catch (error) {
      if (error.code !== 'ENOENT') throw error;
    }
  }
  if (!license) throw new Error(`No bundled license found for ${packageName}.`);
  await output(`licenses/${packageName}.txt`, license, {
    source: `node_modules/${packageName}/${licenseSource}`,
    source_sha256: sha256(license),
    package: packageName,
    version: packageJson.version,
    license: packageJson.license,
    transformation: 'Verbatim upstream package license',
  });
}
await output(
  'licenses/GSAP.txt',
  Buffer.from(
    `GSAP and ScrollTrigger 3.15.0\nLibrary notice: Copyright 2008-2026, GreenSock. All rights reserved.\nStandard license notice: Copyright (c) 2025 Webflow. All rights reserved.\n\nDistributed under the Standard \"No Charge\" GSAP License, not the MIT License.\nThe license allows implementation on websites and digital interfaces, subject\nto its terms and restrictions. The upstream license and notices continue to\napply to the bundled library.\n\nAuthoritative license: https://gsap.com/community/standard-license/\nPackage metadata: https://www.npmjs.com/package/gsap/v/3.15.0\n`,
  ),
  {
    source: 'node_modules/gsap/package.json',
    package: 'gsap',
    version: '3.15.0',
    source_sha256: sha256(
      await readFile(join(websiteRoot, 'node_modules/gsap/package.json')),
    ),
    license: 'Standard No Charge GSAP License',
    license_url: 'https://gsap.com/community/standard-license/',
    transformation:
      'License identification and authoritative source link; no claim of MIT licensing',
  },
);

const { captures: _, ...screenshotProvenance } = screenshots;
const manifest = {
  version: 1,
  generated_by: 'node scripts/prepare-assets.mjs',
  note: 'Original application assets are never rewritten. Screenshot provenance describes their actual debug capture commit and APK, independently of the published APK linked by this website.',
  screenshot_record: sourceRecord,
  screenshot_record_sha256: sha256(
    await readFile(join(repositoryRoot, sourceRecord)),
  ),
  screenshot_provenance: screenshotProvenance,
  assets,
};
await writeFile(
  join(websiteRoot, 'ASSET_SOURCES.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
);
console.log(
  `Prepared ${assets.length} assets. All original inputs remain unchanged.`,
);
