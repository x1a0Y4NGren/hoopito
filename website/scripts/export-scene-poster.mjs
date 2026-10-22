import { chromium } from '@playwright/test';
import { createHash } from 'node:crypto';
import { readFile, readdir, mkdir, writeFile } from 'node:fs/promises';
import { resolve } from 'node:path';

// Development-only capture tool: no debug handle or second renderer ships in the website.
const dist = resolve('dist');
const origin = process.env.HOOPITO_LOCAL_ORIGIN ?? 'http://127.0.0.1:4321';
const sceneChunk = (await readdir(resolve(dist, '_astro'))).find((name) =>
  /^court-scene.*\.js$/.test(name),
);
if (!sceneChunk)
  throw new Error('Build the website before exporting its scene.');
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const runId = new Date().toISOString().replaceAll(/[:.]/g, '-');
const evidence = resolve('output/court-continuity');
await mkdir(evidence, { recursive: true });
const sourceInputs = [];
for (const path of [
  'src/scripts/main.ts',
  'src/scripts/court-scene.ts',
  'src/scripts/camera-placement.ts',
  'src/scripts/replay-cards.ts',
  'src/scripts/demo-invitation.ts',
  'src/scripts/court-hardware.ts',
  'src/scripts/court-floor.ts',
  'src/scripts/court-textures.ts',
  'src/scripts/scene-contract.ts',
  'src/scripts/shot-timing.ts',
  'src/scripts/scene-performance.ts',
  'src/scripts/gpu-calibration.ts',
  'src/scripts/story-pose.ts',
  'src/scripts/shaders/court.ts',
  'src/styles/site.css',
  'src/styles/refinement.css',
  'src/styles/replay-cards.css',
  'src/styles/mobile-download-polish.css',
  'src/components/Layout.astro',
  'src/components/Landing.astro',
  'src/data/content.ts',
  '../docs/design/screenshot-presentation.json',
  'src/data/court-materials.ts',
  'assets/materials/generation.json',
  'package-lock.json',
  'scripts/export-scene-poster.mjs',
]) {
  sourceInputs.push({
    path,
    sha256: sha256(await readFile(path)),
  });
}
const compiledScene = {
  path: `_astro/${sceneChunk}`,
  sha256: sha256(await readFile(resolve(dist, '_astro', sceneChunk))),
};
const browser = await chromium.launch({
  channel: 'chrome',
  headless: true,
  args: ['--enable-gpu'],
});
const captures = [];
await mkdir('assets/art/source', { recursive: true });
const previousRecord = await readFile('assets/art/scene-poster.json').catch(
  (error) => {
    if (error.code !== 'ENOENT') throw error;
    return null;
  },
);
if (previousRecord)
  await writeFile(
    resolve(evidence, `poster-record-before-${runId}.json`),
    previousRecord,
  );
try {
  for (const [id, width, height, chapter] of [
    ['compact', 1024, 768, 'hero'],
    ['standard', 1440, 900, 'hero'],
    ['wide', 1920, 1080, 'hero'],
    ['demo-compact', 1024, 768, 'experience'],
    ['demo-standard', 1440, 900, 'experience'],
    ['demo-wide', 1920, 1080, 'experience'],
  ]) {
    const context = await browser.newContext({
      viewport: { width, height },
      reducedMotion: 'reduce',
      deviceScaleFactor: 1,
    });
    const page = await context.newPage();
    try {
      // Observe the factory the real page imports. The wrapper never creates a
      // second renderer or substitutes a guessed pose or interaction layout.
      await page.route(`**/_astro/${sceneChunk}`, async (route) => {
        const response = await route.fetch();
        let body = await response.text();
        const exports = body.match(
          /export\s*\{([^}]*\bcreateCourtScene\b[^}]*)\}/,
        );
        const factory = exports?.[1].match(
          /(?:^|,)\s*([\w$]+)\s+as\s+createCourtScene\b/,
        )?.[1];
        if (!exports || !factory)
          throw new Error('The built page must export its real scene factory.');
        body = body.replace(
          exports[0],
          exports[0].replace(
            /[\w$]+\s+as\s+createCourtScene\b/,
            '__courtPosterCreate as createCourtScene',
          ),
        );
        body += `\nasync function __courtPosterCreate(...args) {
          const scene = await ${factory}(...args);
          const previous = Reflect.get(window, '__courtPoster');
          const probe = {
            scene, canvas: args[0], creations: (previous?.creations ?? 0) + 1,
            placement: null, frame: null,
          };
          const place = scene.setCameraPlacement.bind(scene);
          scene.setCameraPlacement = (placement) => {
            probe.placement = placement ? structuredClone(placement) : null;
            return place(placement);
          };
          const frame = scene.setStoryFrame.bind(scene);
          scene.setStoryFrame = (value) => {
            probe.frame = structuredClone(value);
            return frame(value);
          };
          Reflect.set(window, '__courtPoster', probe);
          return scene;
        }\n`;
        await route.fulfill({ response, body, contentType: 'text/javascript' });
      });
      await page.goto(
        `${origin}/${chapter === 'experience' ? '#experience' : ''}`,
      );
      await page.evaluate(() => document.fonts.ready);
      await page.waitForSelector('html[data-scene="3d"]', { timeout: 20000 });
      if (chapter === 'experience') {
        await page.waitForSelector('html[data-interactive="true"]');
        await page.waitForSelector(
          '#court-canvas[data-placement-blend="1.0000"]',
        );
      }
      const capture = await page.evaluate(async (chapter) => {
        await new Promise((resolve) =>
          requestAnimationFrame(() => requestAnimationFrame(resolve)),
        );
        const probe = Reflect.get(window, '__courtPoster');
        const element = document.querySelector('#court-canvas');
        if (
          !probe ||
          probe.creations !== 1 ||
          probe.canvas !== element ||
          element.parentElement?.className !== 'scene-background' ||
          element.dataset.chapter !== chapter
        )
          throw new Error(
            'Capture must use the sole background scene of the current page.',
          );
        const inputEnabled = element.dataset.inputEnabled === 'true';
        probe.scene.setPaused(true);
        const image = probe.scene.exportFrame();
        const bounds = element.getBoundingClientRect();
        return {
          image,
          pose: probe.frame,
          placement: probe.placement,
          input_enabled_before_pause: inputEnabled,
          canvas_css: {
            left: bounds.left,
            top: bounds.top,
            width: bounds.width,
            height: bounds.height,
          },
          renderer: element.dataset.renderer,
          engine: element.dataset.engine,
          width: element.width,
          height: element.height,
          pixel_ratio: Number(element.dataset.pixelRatio),
          quality: element.dataset.quality,
          antialias: element.dataset.antialias,
          view_cutaway: Number(element.dataset.viewCutaway),
        };
      }, chapter);
      const source = `source/scene-poster-${id}-${runId}.webp`;
      const bytes = Buffer.from(capture.image.split(',')[1], 'base64');
      await writeFile(`assets/art/${source}`, bytes);
      const { image: _, ...metadata } = capture;
      captures.push({
        id,
        source,
        source_sha256: sha256(bytes),
        viewport: { width, height, device_scale_factor: 1 },
        ...metadata,
      });
      console.log(
        `${id}: ${capture.width}x${capture.height}; ${sha256(bytes)}`,
      );
    } finally {
      await context.close();
    }
  }
  const record = {
    version: 2,
    captured_at: new Date().toISOString(),
    generated_by: 'node scripts/export-scene-poster.mjs',
    capture_method:
      'The actual production page scene observed at its dynamic factory export; no second renderer or authored capture pose.',
    browser: browser.version(),
    compiled_scene: compiledScene,
    source_inputs: sourceInputs,
    captures,
  };
  const recordBytes = `${JSON.stringify(record, null, 2)}\n`;
  await writeFile('assets/art/scene-poster.json', recordBytes);
  await writeFile(
    resolve(evidence, `poster-export-${runId}.json`),
    recordBytes,
  );
} finally {
  await browser.close();
}
