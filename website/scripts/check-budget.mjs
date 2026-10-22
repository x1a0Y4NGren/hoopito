import { readFile, readdir } from 'node:fs/promises';
import { resolve, relative, extname, sep } from 'node:path';
import { gzipSync, brotliCompressSync, constants } from 'node:zlib';
import { courtTextures } from '../src/data/court-materials.ts';
import { selectImageResource } from './responsive-images.mjs';

// Measure the generated HTML and its resource graph, rather than guessing from source sizes.
const dist = resolve(process.argv[2] || 'dist');
const budgets = { mobile: 500 * 1024, desktop: 800 * 1024 };
const origin = 'https://budget.invalid';
const cache = new Map();

function localPath(resource, from = 'index.html') {
  if (!resource || resource.startsWith('data:') || resource.startsWith('#'))
    return null;
  const url = new URL(resource, `${origin}/${from.replaceAll(sep, '/')}`);
  if (url.origin !== origin)
    throw new Error(`Initial resource must be hosted locally: ${resource}`);
  const file = resolve(dist, `.${decodeURIComponent(url.pathname)}`);
  if (relative(dist, file).startsWith('..'))
    throw new Error(`Resource escapes build directory: ${resource}`);
  return file;
}

async function bytes(file) {
  if (!cache.has(file)) cache.set(file, await readFile(file));
  return cache.get(file);
}

function attributes(tag) {
  const result = {};
  for (const match of tag.matchAll(
    /([\w:-]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+)))?/g,
  )) {
    result[match[1].toLowerCase()] = match[2] ?? match[3] ?? match[4] ?? '';
  }
  return result;
}

async function graph(start, set = new Set()) {
  for (const file of start) {
    if (!file || set.has(file)) continue;
    set.add(file);
    const content = (await bytes(file)).toString('utf8');
    const from = relative(dist, file).replaceAll(sep, '/');
    const children = [];
    if (extname(file) === '.css') {
      for (const match of content.matchAll(
        /url\(\s*(?:"([^"]*)"|'([^']*)'|([^\s"')]+))\s*\)/g,
      )) {
        children.push(localPath(match[1] ?? match[2] ?? match[3], from));
      }
      for (const match of content.matchAll(/@import\s+["']([^"']+)["']/g))
        children.push(localPath(match[1], from));
    } else if (extname(file) === '.js' || extname(file) === '.mjs') {
      for (const match of content.matchAll(
        /\b(?:import|export)\s*(?:(?:[^"'();]*?)\s*from\s*)?["']([^"']+)["']/g,
      )) {
        children.push(localPath(match[1], from));
      }
      // Non-3D dynamic dependencies are conservatively included in the mobile graph.
      for (const match of content.matchAll(
        /\bimport\(\s*["']([^"']+)["']\s*\)/g,
      )) {
        if (!/court-(?:scene|engine)/.test(match[1]))
          children.push(localPath(match[1], from));
      }
    }
    await graph(children, set);
  }
  return set;
}

async function initialResources(page, viewport) {
  const file = resolve(dist, page);
  const html = (await bytes(file)).toString('utf8');
  const resources = [file];
  const standaloneHtml = html.replace(
    /<picture\b[^>]*>([\s\S]*?)<\/picture>/g,
    (_, picture) => {
      const imageTag = picture.match(/<img\b[^>]*>/)?.[0];
      if (!imageTag) throw new Error('Picture has no fallback image');
      const image = attributes(imageTag);
      if (image.loading !== 'lazy') {
        const sources = [...picture.matchAll(/<source\b[^>]*>/g)].map((match) =>
          attributes(match[0]),
        );
        resources.push(
          localPath(selectImageResource(image, sources, viewport), page),
        );
      }
      return '';
    },
  );
  for (const match of standaloneHtml.matchAll(
    /<(?:script|link|img|source)\b[^>]*>/g,
  )) {
    const tag = match[0];
    const attr = attributes(tag);
    if (tag.startsWith('<script') && attr.src)
      resources.push(localPath(attr.src, page));
    if (
      tag.startsWith('<link') &&
      ['stylesheet', 'preload', 'modulepreload'].includes(attr.rel)
    ) {
      resources.push(localPath(attr.href, page));
    }
    if (tag.startsWith('<img') && attr.loading !== 'lazy' && attr.src)
      resources.push(localPath(selectImageResource(attr, [], viewport), page));
    // Inline CSS background assets are requested independently of HTML images.
  }
  for (const match of html.matchAll(
    /style=["'][^"']*url\(\s*["']?([^\s"')]+)["']?\s*\)/g,
  )) {
    resources.push(localPath(match[1], page));
  }
  return graph(resources);
}

async function demoPosterResource(page, viewport) {
  const html = (await bytes(resolve(dist, page))).toString('utf8');
  for (const match of html.matchAll(
    /<picture\b([^>]*)>([\s\S]*?)<\/picture>/g,
  )) {
    const attr = attributes(match[1]);
    if (!(attr.class ?? '').split(/\s+/).includes('demo-scene-poster'))
      continue;
    const imageTag = match[2].match(/<img\b[^>]*>/)?.[0];
    if (!imageTag)
      throw new Error('The deferred demo poster has no fallback image');
    const sources = [...match[2].matchAll(/<source\b[^>]*>/g)].map((source) =>
      attributes(source[0]),
    );
    return localPath(
      selectImageResource(attributes(imageTag), sources, viewport),
      page,
    );
  }
  throw new Error('Missing deferred demo scene poster picture');
}

async function list(directory) {
  const entries = await readdir(directory, { withFileTypes: true });
  const groups = await Promise.all(
    entries.map((entry) =>
      entry.isDirectory()
        ? list(resolve(directory, entry.name))
        : [resolve(directory, entry.name)],
    ),
  );
  return groups.flat();
}

async function measure(files) {
  let raw = 0,
    gzip = 0,
    brotli = 0;
  for (const file of files) {
    const buffer = await bytes(file);
    raw += buffer.byteLength;
    gzip += gzipSync(buffer, { level: 9 }).byteLength;
    brotli += brotliCompressSync(buffer, {
      params: { [constants.BROTLI_PARAM_QUALITY]: 11 },
    }).byteLength;
  }
  return {
    raw,
    gzip,
    brotli,
    files: [...files]
      .map((file) => relative(dist, file).replaceAll(sep, '/'))
      .sort(),
  };
}

try {
  const mobileReports = [];
  const baseline = new Set();
  for (const page of ['index.html', 'en/index.html']) {
    for (const width of [390, 768])
      for (const dpr of [1, 2])
        for (const avif of [true, false]) {
          const resources = await initialResources(page, {
            width,
            dpr,
            avif,
            pointer: 'coarse',
          });
          resources.forEach((file) => baseline.add(file));
          mobileReports.push({
            label: `Mobile initial ${page === 'index.html' ? 'zh-CN' : 'en'} ${width}px ${dpr}x ${avif ? 'AVIF' : 'WebP'}`,
            budget: budgets.mobile,
            ...(await measure(resources)),
          });
        }
  }
  const courtRoots = (await list(dist)).filter((file) =>
    /court-(?:scene|engine)[^/\\]*\.js$/.test(file),
  );
  if (!courtRoots.length)
    throw new Error(
      'Missing desktop court chunks: the 3D incremental budget cannot be verified.',
    );
  const desktop = await graph(courtRoots);
  // TextureLoader/fetch URLs are not JS imports. Charge their shared scene registry as well.
  for (const url of Object.values(courtTextures)) desktop.add(localPath(url));
  for (const file of baseline) desktop.delete(file);
  const reports = [
    ...mobileReports,
    {
      label: 'Desktop 3D additional',
      budget: budgets.desktop,
      ...(await measure(desktop)),
    },
  ];
  for (const width of [1024, 1440, 1920])
    for (const dpr of [1, 2])
      for (const avif of [true, false]) {
        const extra = new Set(desktop);
        const viewport = {
          width,
          dpr,
          avif,
          pointer: 'fine',
        };
        // Lazy loading defers this image; it still belongs to this desktop scene.
        // Select one responsive candidate exactly as the page does, rather than
        // adding every breakpoint to every viewport's budget.
        const demoPoster = await demoPosterResource('index.html', viewport);
        if (!demoPoster)
          throw new Error(`Missing desktop demo poster at ${width}px`);
        extra.add(demoPoster);
        const initial = await initialResources('index.html', viewport);
        initial.forEach((file) => {
          if (!baseline.has(file)) extra.add(file);
        });
        reports.push({
          label: `Desktop scene + initial art + demo ${width}px ${dpr}x ${avif ? 'AVIF' : 'WebP'}`,
          budget: budgets.desktop,
          ...(await measure(extra)),
        });
      }
  let failed = false;
  for (const report of reports) {
    const ok = report.gzip <= report.budget;
    failed ||= !ok;
    console.log(
      `${ok ? 'PASS' : 'FAIL'} ${report.label}: gzip ${(report.gzip / 1024).toFixed(1)} KiB; Brotli ${(report.brotli / 1024).toFixed(1)} KiB; budget ${report.budget / 1024} KiB`,
    );
  }
  console.log(
    JSON.stringify(
      {
        compression:
          'Independent files; gzip level 9 gates the budget, Brotli quality 11 is reported.',
        reports,
      },
      null,
      2,
    ),
  );
  if (failed) process.exitCode = 1;
} catch (error) {
  console.error(`Resource budget failed: ${error.message}`);
  process.exitCode = 1;
}
