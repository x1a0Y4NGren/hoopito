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
const sourceInputs = [];
for (const path of [
  'src/scripts/court-scene.ts',
  'src/scripts/court-hardware.ts',
  'src/scripts/court-floor.ts',
  'src/scripts/court-textures.ts',
  'src/scripts/scene-contract.ts',
  'src/scripts/scene-performance.ts',
  'src/scripts/gpu-calibration.ts',
  'src/scripts/story-pose.ts',
  'src/scripts/shaders/court.ts',
  'src/styles/site.css',
  'src/styles/refinement.css',
  'src/components/Layout.astro',
  'src/components/Landing.astro',
  '../docs/design/screenshot-presentation.json',
  'src/data/court-materials.ts',
  'assets/materials/generation.json',
  'package-lock.json',
]) {
  sourceInputs.push({
    path,
    sha256: createHash('sha256')
      .update(await readFile(path))
      .digest('hex'),
  });
}
const browser = await chromium.launch({
  channel: 'chrome',
  headless: true,
  args: ['--enable-gpu'],
});
const captures = [];
await mkdir('assets/art/source', { recursive: true });
try {
  for (const [id, width, height] of [
    ['compact', 492, 678],
    ['standard', 691, 810],
    ['wide', 922, 990],
  ]) {
    const context = await browser.newContext({
      viewport: { width: Math.round(width / 0.48), height: height + 90 },
      reducedMotion: 'reduce',
      deviceScaleFactor: 1,
    });
    const page = await context.newPage();
    await page.goto(origin);
    const capture = await page.evaluate(
      async ({ sceneChunk, width, height }) => {
        const { createCourtScene } = await import(`/_astro/${sceneChunk}`);
        const element = document.createElement('canvas');
        element.style.cssText = `position:fixed;right:0;top:0;width:${width}px;height:${height}px;pointer-events:none`;
        document.body.append(element);
        const controller = new AbortController();
        const scene = await createCourtScene(element, {
          signal: controller.signal,
          motionEnabled: false,
          onPoint() {},
          onFailure(reason) {
            throw new Error(`Poster render failed: ${reason}`);
          },
        });
        try {
          scene.setStoryFrame({ chapter: 'hero', progress: 0, active: true });
          const image = scene.exportFrame();
          return {
            image,
            renderer: element.dataset.renderer,
            engine: element.dataset.engine,
            width: element.width,
            height: element.height,
            quality: element.dataset.quality,
            antialias: element.dataset.antialias,
          };
        } finally {
          scene.dispose();
          controller.abort();
          element.remove();
        }
      },
      { sceneChunk, width, height },
    );
    const source = `source/scene-poster-${id}.webp`;
    const bytes = Buffer.from(capture.image.split(',')[1], 'base64');
    await writeFile(`assets/art/${source}`, bytes);
    const { image: _, ...metadata } = capture;
    captures.push({
      id,
      source,
      source_sha256: createHash('sha256').update(bytes).digest('hex'),
      pose: { chapter: 'hero', progress: 0, active: true },
      ...metadata,
    });
    await context.close();
  }
  await writeFile(
    'assets/art/scene-poster.json',
    `${JSON.stringify({ version: 1, captured_at: new Date().toISOString(), generated_by: 'node scripts/export-scene-poster.mjs', browser: browser.version(), source_inputs: sourceInputs, captures }, null, 2)}\n`,
  );
  console.log(JSON.stringify(captures));
} finally {
  await browser.close();
}
