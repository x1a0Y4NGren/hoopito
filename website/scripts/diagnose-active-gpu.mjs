import { chromium } from '@playwright/test';
import { readFile, writeFile, mkdir, readdir } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { performance } from 'node:perf_hooks';
import { fileURLToPath } from 'node:url';
import { installActiveGpuProbe } from './active-gpu-probe.mjs';
import {
  createWheelWorkload,
  runWheelInput,
  serializeMeasurementFailure,
  WHEEL_WORKLOAD_VERSION,
} from './gpu-wheel-input.mjs';

// Development-only, instrumented GPU command-interval diagnostics. These results
// never establish uninstrumented submission cadence or physical presentation.
const output = resolve(
  process.env.HOOPITO_ACTIVE_GPU_OUTPUT ??
    `output/amd-fluidity-20261017/gpu-diagnostic-${Date.now()}`,
);
try {
  if ((await readdir(output)).length)
    throw new Error(`Evidence already exists: ${output}`);
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}
await mkdir(output, { recursive: true });
const origin = process.env.HOOPITO_LOCAL_ORIGIN ?? 'http://127.0.0.1:4321';
if (!['127.0.0.1', 'localhost', '[::1]'].includes(new URL(origin).hostname))
  throw new Error('Use a local origin.');
const inventoryPath =
  process.env.HOOPITO_ACTIVE_GPU_INVENTORY ??
  'output/amd-fluidity-20261017/baseline/measurements.json';
const inventory = JSON.parse(await readFile(inventoryPath, 'utf8'));
const adapter = inventory.hardware.adapters.find((item) =>
  /AMD Radeon/i.test(item.Name),
);
if (!adapter) throw new Error('Missing AMD DXGI inventory.');
const viewport = { width: 1920, height: 1080, dpr: 2 };
const phases = [
  'experience-wheel-entry',
  'replay-wheel-entry',
  'reverse-wheel',
];
const sha = (bytes) => createHash('sha256').update(bytes).digest('hex');
const source = [];
for (const path of [
  'src/scripts/main.ts',
  'src/scripts/court-scene.ts',
  'scripts/active-gpu-probe.mjs',
  'scripts/gpu-wheel-input.mjs',
  'dist/index.html',
])
  source.push({ path, sha256: sha(await readFile(path)) });
const report = {
  startedAt: new Date().toISOString(),
  mode: 'Instrumented headed GPU command-interval diagnostic; never an acceptance FPS measurement.',
  viewport,
  adapter,
  inventoryPath,
  workloadVersion: WHEEL_WORKLOAD_VERSION,
  driverSha256: sha(await readFile(fileURLToPath(import.meta.url))),
  source,
  phases: [],
};
const save = () =>
  writeFile(
    resolve(output, 'gpu-diagnostics.json'),
    JSON.stringify(report, null, 2) + '\n',
  );

async function layout(page) {
  return page.evaluate(() => {
    const inset =
      document.querySelector('.site-header').getBoundingClientRect().bottom +
      20;
    const result = {};
    for (const chapter of ['hero', 'experience', 'replay']) {
      const section = document.getElementById(chapter);
      const stage = section.querySelector('[data-story-stage]');
      const heading = section.querySelector('.section-top');
      const start = Number(stage?.dataset.storyStart);
      const end = Number(stage?.dataset.storyEnd);
      const rest = Number(stage?.dataset.storyRestTop);
      const pinned = Boolean(stage?.closest('.pin-spacer'));
      let anchor =
        chapter === 'hero'
          ? 0
          : scrollY +
            (heading ?? section).getBoundingClientRect().top -
            (heading ? inset : 0);
      if (heading && pinned && [start, end, rest].every(Number.isFinite)) {
        const local =
          heading.getBoundingClientRect().top -
          stage.getBoundingClientRect().top;
        const delta = rest + local - inset;
        anchor =
          chapter === 'replay'
            ? end + Math.max(0, delta)
            : start + Math.min(0, delta);
      }
      result[chapter] = {
        stageTop: scrollY + stage.getBoundingClientRect().top,
        anchor: Math.max(0, anchor),
      };
    }
    return result;
  });
}

for (const phase of phases) {
  const result = {
    phase,
    error: null,
    acceptance: 'not-applicable-instrumented',
  };
  let browser;
  let context;
  try {
    browser = await chromium.launch({
      executablePath:
        process.env.HOOPITO_CHROME_PATH ??
        'C:/Program Files/Google/Chrome/Application/chrome.exe',
      headless: false,
      args: [
        '--enable-gpu',
        '--disable-backgrounding-occluded-windows',
        '--use-angle=d3d11',
        `--use-adapter-luid=${adapter.HighPart},${adapter.LowPart}`,
      ],
    });
    context = await browser.newContext({
      viewport: { width: viewport.width, height: viewport.height },
      deviceScaleFactor: viewport.dpr,
    });
    await context.addInitScript(() => {
      window.hoopitoGpuEvidence = { phase: null };
    });
    await context.addInitScript(installActiveGpuProbe, {
      maxPending: 4,
      pollMs: 16,
      timeoutMs: 1000,
    });
    const page = await context.newPage();
    const session = await context.newCDPSession(page);
    await session.send('Emulation.setFocusEmulationEnabled', {
      enabled: false,
    });
    await page.goto(origin, { waitUntil: 'load' });
    await page.bringToFront();
    await page.waitForFunction(
      () => document.documentElement.dataset.scene === '3d',
      null,
      { timeout: 20000 },
    );
    await page.waitForTimeout(2300);
    result.environment = await page
      .locator('#court-canvas')
      .evaluate((canvas) => ({
        ...canvas.dataset,
        width: innerWidth,
        height: innerHeight,
        dpr: devicePixelRatio,
        focused: document.hasFocus(),
        hidden: document.hidden,
        bufferWidth: canvas.width,
        bufferHeight: canvas.height,
      }));
    if (
      !/AMD Radeon/i.test(result.environment.renderer ?? '') ||
      !result.environment.focused ||
      result.environment.hidden ||
      result.environment.width !== 1920 ||
      result.environment.height !== 1080 ||
      Math.abs(result.environment.dpr - 2) > 1e-6
    )
      throw new Error(
        'Diagnostic environment does not match requested headed AMD configuration.',
      );
    const workload = createWheelWorkload(
      phase,
      await layout(page),
      viewport.height,
    );
    result.workload = workload;
    await page.keyboard.press('Escape');
    await page.evaluate(
      (top) => scrollTo({ top, behavior: 'instant' }),
      workload.startY,
    );
    await page.waitForTimeout(650);
    result.preparation = {
      method: 'scrollTo outside diagnostic interval',
      ...(await page.evaluate(() => ({
        scrollY,
        chapter: document.documentElement.dataset.chapter,
      }))),
    };
    await page.evaluate((name) => {
      window.hoopitoGpuEvidence.phase = name;
    }, phase);
    try {
      result.wheel = await runWheelInput(workload, {
        now: () => performance.now(),
        wait: (ms) => page.waitForTimeout(ms),
        readPosition: () =>
          page.evaluate(() => ({ scrollY, time: performance.now() })),
        wheel: (x, y) => page.mouse.wheel(x, y),
      });
      await page.waitForFunction(
        (target) =>
          Math.abs(scrollY - target) < 4 &&
          document.querySelector('#court-canvas').dataset.rendering === 'idle',
        workload.targetY,
        { timeout: 3000 },
      );
    } catch (error) {
      Object.assign(result, serializeMeasurementFailure(error, workload));
    }
    // A stopped animation must not prevent queued query results from draining.
    await page.waitForTimeout(1050);
    result.probe = await page.evaluate(() => {
      const probe = window.__hoopitoActiveGpuProbe;
      if (!probe) throw new Error('GPU diagnostic probe was not installed.');
      probe.dispose();
      return probe.snapshot();
    });
    await page.evaluate(() => {
      window.hoopitoGpuEvidence.phase = null;
    });
    result.end = await page.locator('#court-canvas').evaluate((canvas) => ({
      ...canvas.dataset,
      focused: document.hasFocus(),
      hidden: document.hidden,
    }));
  } catch (error) {
    result.error = error.stack ?? String(error);
  } finally {
    // Each owned resource gets an independent teardown attempt. Preserve the
    // original phase error and stage evidence even when a close operation fails.
    for (const { resource, instance } of [
      { resource: 'context', instance: context },
      { resource: 'browser', instance: browser },
    ]) {
      try {
        await instance?.close();
      } catch (error) {
        (result.cleanupErrors ??= []).push({
          resource,
          error: error.stack ?? String(error),
        });
        result.error ??= `GPU diagnostic ${resource} cleanup failed.`;
      }
    }
    report.phases.push(result);
    await save();
  }
  console.log(
    JSON.stringify({
      phase,
      error: result.error,
      availability: result.probe?.availability,
      singleDraws: result.probe?.singleDraws,
      coverage: result.probe?.coverage,
    }),
  );
}
report.finishedAt = new Date().toISOString();
await save();
console.log(`Diagnostic evidence: ${output}`);
if (report.phases.some((phase) => phase.error)) process.exitCode = 1;
