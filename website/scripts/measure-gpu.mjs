import { chromium } from '@playwright/test';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, readdir } from 'node:fs/promises';
import { resolve, relative, extname, sep } from 'node:path';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { platform, release } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import {
  assessEnvironment,
  assessPresentation,
  combineGates,
  summarizeSubmissions,
} from './gpu-measurement.mjs';
import {
  createWheelWorkload,
  runWheelInput,
  serializeMeasurementFailure,
  WHEEL_WORKLOAD_VERSION,
} from './gpu-wheel-input.mjs';

// GPU selection affects only isolated Chrome processes, never Windows preferences.
// Chromium ui/gl/gl_display.cc accepts --use-adapter-luid=<signed high>,<unsigned low>.
// LUIDs are enumerated on every run because they change after a machine restart.
const dxgiSource = String.raw`
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class HoopitoGpuAdapters {
  [DllImport("dxgi.dll", CallingConvention=CallingConvention.StdCall)]
  private static extern int CreateDXGIFactory(ref Guid riid, out IntPtr factory);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)]
  private delegate int EnumAdapters(IntPtr self, uint index, out IntPtr adapter);
  [UnmanagedFunctionPointer(CallingConvention.StdCall)]
  private delegate int GetDesc(IntPtr self, out AdapterDesc desc);
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  private struct AdapterDesc {
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst=128)] public string Description;
    public uint VendorId, DeviceId, SubSysId, Revision;
    public UIntPtr DedicatedVideoMemory, DedicatedSystemMemory, SharedSystemMemory;
    public uint LowPart; public int HighPart;
  }
  public class Adapter {
    public string Name; public uint VendorId, DeviceId; public uint LowPart; public int HighPart;
  }
  public static List<Adapter> Read() {
    var result = new List<Adapter>();
    var iid = new Guid("7b7166ec-21c7-44ae-b21a-c9ae321ae369");
    IntPtr factory;
    Marshal.ThrowExceptionForHR(CreateDXGIFactory(ref iid, out factory));
    try {
      var enumerate = (EnumAdapters)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(Marshal.ReadIntPtr(factory), 7 * IntPtr.Size), typeof(EnumAdapters));
      for (uint index = 0; ; ++index) {
        IntPtr adapter;
        if (enumerate(factory, index, out adapter) != 0) break;
        try {
          var describe = (GetDesc)Marshal.GetDelegateForFunctionPointer(Marshal.ReadIntPtr(Marshal.ReadIntPtr(adapter), 8 * IntPtr.Size), typeof(GetDesc));
          AdapterDesc desc;
          Marshal.ThrowExceptionForHR(describe(adapter, out desc));
          result.Add(new Adapter { Name=desc.Description, VendorId=desc.VendorId, DeviceId=desc.DeviceId, LowPart=desc.LowPart, HighPart=desc.HighPart });
        } finally { Marshal.Release(adapter); }
      }
    } finally { Marshal.Release(factory); }
    return result;
  }
}
`;

const dist = resolve('dist');
const stamp = new Date().toISOString().replaceAll(/[:.]/g, '-');
const output = resolve(
  process.env.HOOPITO_GPU_OUTPUT ?? `output/cinematic/performance/gpu-${stamp}`,
);
const reportPath = resolve(output, 'measurements.json');
try {
  if ((await readdir(output)).length)
    throw new Error(
      `Evidence already exists in ${output}. Select a new output directory.`,
    );
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}
await mkdir(output, { recursive: true });
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const manifest = [];
for (const name of (await readdir(dist, { recursive: true }))
  .filter((name) => /\.[a-z0-9]+$/i.test(name))
  .sort()) {
  const bytes = await readFile(resolve(dist, name));
  manifest.push({
    path: name.replaceAll('\\', '/'),
    bytes: bytes.length,
    sha256: sha256(bytes),
  });
}
await writeFile(
  resolve(output, 'build-manifest.json'),
  `${JSON.stringify(manifest, null, 2)}\n`,
);
const windowsHardware =
  platform() === 'win32'
    ? JSON.parse(
        execFileSync(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            `$taskGpuSource = @'\n${dxgiSource}\n'@; Add-Type -TypeDefinition $taskGpuSource; @{ adapters = @([HoopitoGpuAdapters]::Read()); displays = @(Get-CimInstance Win32_VideoController | Select-Object Name,DriverVersion,CurrentHorizontalResolution,CurrentVerticalResolution,CurrentRefreshRate) } | ConvertTo-Json -Depth 6`,
          ],
          { encoding: 'utf8', windowsHide: true },
        ).replace(/^\uFEFF/, ''),
      )
    : null;
const requestedGpuNames = (process.env.HOOPITO_GPU ?? 'amd,nvidia').split(',');
const gpuTargets = windowsHardware
  ? requestedGpuNames.map((name) => {
      const expression =
        name === 'amd'
          ? /AMD Radeon/i
          : name === 'nvidia'
            ? /RTX 4070/i
            : new RegExp(name, 'i');
      const adapter = windowsHardware.adapters.find((device) =>
        expression.test(device.Name),
      );
      return { name, expression, adapter };
    })
  : [{ name: 'default', expression: /./, adapter: null }];
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
  '.avif': 'image/avif',
  '.webp': 'image/webp',
  '.png': 'image/png',
};
const server = createServer(async (request, response) => {
  try {
    const url = new URL(request.url, 'http://localhost');
    const path = resolve(
      dist,
      `.${decodeURIComponent(url.pathname)}${url.pathname.endsWith('/') ? 'index.html' : ''}`,
    );
    const within = relative(dist, path);
    if (within === '..' || within.startsWith(`..${sep}`)) {
      response.writeHead(403).end();
      return;
    }
    const raw = await readFile(path);
    const compressed = /\.(html|css|js|svg)$/.test(path);
    response.writeHead(200, {
      'Content-Type': types[extname(path)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
      ...(compressed ? { 'Content-Encoding': 'gzip' } : {}),
    });
    response.end(compressed ? gzipSync(raw) : raw);
  } catch {
    response.writeHead(404).end();
  }
});
const headless = process.env.HOOPITO_GPU_HEADLESS === '1';
const traceOnly = process.env.HOOPITO_GPU_TRACE_ONLY === '1';
const viewports = process.env.HOOPITO_GPU_VIEWPORTS
  ? JSON.parse(process.env.HOOPITO_GPU_VIEWPORTS)
  : [
      { width: 1440, height: 900, dpr: 1 },
      { width: 1440, height: 900, dpr: 2 },
      { width: 1920, height: 1080, dpr: 1 },
      { width: 1920, height: 1080, dpr: 2 },
    ];
const phaseNames = [
  'intro',
  'experience-wheel-entry',
  'replay-wheel-entry',
  'reverse-wheel',
  'experience-entry',
  'replay-entry',
  'reverse-story',
  'shot',
];
const selectedPhases = process.env.HOOPITO_GPU_PHASES
  ? process.env.HOOPITO_GPU_PHASES.split(',').map((name) => name.trim())
  : [
      'intro',
      'experience-wheel-entry',
      'replay-wheel-entry',
      'reverse-wheel',
      'shot',
    ];
if (
  !selectedPhases.length ||
  selectedPhases.some((name) => !phaseNames.includes(name))
)
  throw new Error(
    'HOOPITO_GPU_PHASES must contain known, comma-separated phase names.',
  );
const runLimit = process.env.HOOPITO_GPU_RUNS
  ? Number(process.env.HOOPITO_GPU_RUNS)
  : null;
if (
  runLimit !== null &&
  (!Number.isInteger(runLimit) || runLimit < 1 || runLimit > 3)
)
  throw new Error('HOOPITO_GPU_RUNS must be an integer from 1 to 3.');
const tracesEnabled = process.env.HOOPITO_GPU_TRACES !== '0';
const report = {
  date: new Date().toISOString(),
  measurementScriptSha256: sha256(
    await readFile(fileURLToPath(import.meta.url)),
  ),
  measurementHelperSha256: sha256(
    await readFile(new URL('./gpu-measurement.mjs', import.meta.url)),
  ),
  wheelInputHelperSha256: sha256(
    await readFile(new URL('./gpu-wheel-input.mjs', import.meta.url)),
  ),
  workloadVersion: WHEEL_WORKLOAD_VERSION,
  inputMethods: {
    'experience-wheel-entry': 'page.mouse.wheel',
    'replay-wheel-entry': 'page.mouse.wheel',
    'reverse-wheel': 'page.mouse.wheel',
    'experience-entry': 'navigation anchor click (historical)',
    'replay-entry': 'navigation anchor click (historical)',
    'reverse-story': 'scripted native scrollTo (historical)',
  },
  platform: platform() + ' ' + release(),
  sourceCommit: execFileSync('git', ['rev-parse', 'HEAD'], {
    encoding: 'utf8',
  }).trim(),
  sourceStatus: execFileSync(
    'git',
    ['status', '--porcelain', '--', 'src', 'public', 'scripts'],
    { encoding: 'utf8' },
  ).trim(),
  buildHtmlSha256: sha256(await readFile(resolve(dist, 'index.html'))),
  buildManifestSha256: sha256(JSON.stringify(manifest)),
  hardware: windowsHardware,
  method:
    'Headed installed Chrome with a fresh temporary profile/process per configuration run. Actual focus emulation is disabled. The website renderCount counter records WebGL submission returns, with continuous visibility/focus, renderer, dimensions and quality observations. A separate traced browser is diagnostic only.',
  limits:
    'JS render returns do not establish GPU completion, new content presentation or physical scanout. DeviceScaleFactor emulates density; actual drawing-buffer density is recorded independently. Generic compositor callbacks never satisfy presentation. No timestamp-proximity correspondence is inferred.',
  temperatures: {
    cold: 'First document in a fresh browser/profile/GPU process.',
    warmed:
      'Second document in that same browser context after all selected first-document workloads. This replays the real introduction with warm process/shader caches; server responses remain no-store.',
  },
  repeatPolicy: runLimit
    ? 'Explicit run count ' + runLimit + ' per selected configuration.'
    : 'Each configuration once; 1920x1080 DPR2 and environmental/submission failures or unavailable submissions receive three total fresh-process runs. Missing presentation alone does not trigger repeats.',
  phases: selectedPhases,
  targets: { averageFps: 58, p95FrameMs: 20 },
  traceOnly,
  passes: false,
  samples: [],
  traces: [],
  unavailable: [],
  failures: [],
};

const saveReport = () =>
  writeFile(reportPath, JSON.stringify(report, null, 2) + '\n');

function launchBrowser(args) {
  return chromium.launch({
    ...(platform() === 'win32'
      ? {
          executablePath:
            process.env.HOOPITO_CHROME_PATH ??
            'C:/Program Files/Google/Chrome/Application/chrome.exe',
        }
      : { channel: 'chrome' }),
    headless,
    args,
  });
}

// Browser-local instrumentation: no runtime changes, GPU readbacks or synthetic frame IDs.
function observeDocument({ temperature, measureIntro }) {
  const evidence = {
    frames: [],
    environment: [],
    longTasks: [],
    wheelInputs: [],
    phase: null,
    temperature,
    sceneStarted: null,
  };
  window.hoopitoGpuEvidence = evidence;
  const snapshot = (reason) => {
    const canvas = document.querySelector('#court-canvas');
    const data = canvas?.dataset ?? {};
    return {
      time: performance.now(),
      phase: evidence.phase,
      temperature,
      reason,
      scene: document.documentElement.dataset.scene,
      renderer: data.renderer,
      hidden: document.hidden,
      visibility: document.visibilityState,
      focused: document.hasFocus(),
      width: innerWidth,
      height: innerHeight,
      dpr: devicePixelRatio,
      outerWidth,
      outerHeight,
      screenWidth: screen.width,
      screenHeight: screen.height,
      availableScreenWidth: screen.availWidth,
      availableScreenHeight: screen.availHeight,
      canvasWidth: canvas?.width,
      canvasHeight: canvas?.height,
      displayWidth: canvas?.clientWidth,
      displayHeight: canvas?.clientHeight,
      pixelRatio: Number(data.pixelRatio),
      bufferWidth: Number(data.bufferWidth),
      bufferHeight: Number(data.bufferHeight),
      quality: data.quality,
      pipeline: data.pipeline,
      antialias: data.antialias,
    };
  };
  window.hoopitoGpuSnapshot = snapshot;
  const environment = (reason) => {
    if (evidence.phase) evidence.environment.push(snapshot(reason));
  };
  const ready = () => {
    if (
      evidence.sceneStarted !== null ||
      document.documentElement.dataset.scene !== '3d'
    )
      return;
    evidence.sceneStarted = performance.now();
    if (measureIntro) evidence.phase = 'intro';
    environment('scene-ready');
  };
  window.addEventListener('focus', () => environment('focus'));
  window.addEventListener('blur', () => environment('blur'));
  document.addEventListener('visibilitychange', () =>
    environment('visibilitychange'),
  );
  window.addEventListener(
    'wheel',
    (event) => {
      evidence.wheelInputs.push({
        phase: evidence.phase,
        time: performance.now(),
        eventTimeStamp: event.timeStamp,
        deltaX: event.deltaX,
        deltaY: event.deltaY,
        deltaMode: event.deltaMode,
        isTrusted: event.isTrusted,
        scrollY,
      });
    },
    { passive: true },
  );
  window.addEventListener('resize', () => environment('resize'));
  setInterval(() => environment('heartbeat'), 100);
  if (PerformanceObserver.supportedEntryTypes.includes('longtask'))
    new PerformanceObserver((list) => {
      evidence.longTasks.push(
        ...list.getEntries().map((entry) => ({
          phase: evidence.phase,
          startTime: entry.startTime,
          duration: entry.duration,
        })),
      );
    }).observe({ type: 'longtask', buffered: true });
  document.addEventListener(
    'DOMContentLoaded',
    () => {
      const canvas = document.querySelector('#court-canvas');
      if (!canvas) return;
      new MutationObserver((mutations) => {
        ready();
        if (
          !evidence.phase ||
          !mutations.some((mutation) =>
            ['data-render-count', 'data-rendering'].includes(
              mutation.attributeName,
            ),
          )
        )
          return;
        const data = canvas.dataset;
        const state = snapshot('submission');
        evidence.environment.push(state);
        evidence.frames.push({
          ...state,
          count: Number(data.renderCount),
          rendering: data.rendering,
          chapter: data.chapter,
          progress: Number(data.storyProgress),
          drawCalls: Number(data.drawCalls),
          triangles: Number(data.triangles),
        });
      }).observe(canvas, {
        attributes: true,
        attributeFilter: ['data-render-count', 'data-rendering'],
      });
      new MutationObserver(ready).observe(document.documentElement, {
        attributes: true,
        attributeFilter: ['data-scene'],
      });
      ready();
    },
    { once: true },
  );
}

async function storyLayout(page) {
  return page.evaluate(() => {
    const header = document.querySelector('.site-header');
    const inset = header.getBoundingClientRect().bottom + 20;
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
        start: Number.isFinite(start) ? start : null,
        end: Number.isFinite(end) ? end : null,
        rest: Number.isFinite(rest) ? rest : null,
        progress: Number(stage?.dataset.storyProgress),
        pinned,
        sectionTop: scrollY + section.getBoundingClientRect().top,
        stageTop: scrollY + stage.getBoundingClientRect().top,
        anchor: Math.max(0, anchor),
      };
    }
    return result;
  });
}

async function pendingState(page) {
  return page.evaluate(() => ({
    time: performance.now(),
    scrollY,
    hash: location.hash,
    environment: window.hoopitoGpuSnapshot('pending-motion'),
    root: { ...document.documentElement.dataset },
    canvas: { ...document.querySelector('#court-canvas')?.dataset },
    demo: document.querySelector('[data-demo]')?.dataset.demoPhase,
    stages: [...document.querySelectorAll('[data-story-stage]')].map(
      (stage) => ({
        ...stage.dataset,
        top: stage.getBoundingClientRect().top,
      }),
    ),
    animations: document.getAnimations().map((animation) => ({
      playState: animation.playState,
      currentTime: animation.currentTime,
      target: animation.effect?.target?.className,
    })),
  }));
}

// Demand bounded stability, never wait for the global GSAP ticker to become idle.
async function settle(
  page,
  { maximumMs = 2800, minimumMs = 200, chapter, target } = {},
) {
  return page.evaluate(
    async ({ maximumMs, minimumMs, chapter, target }) => {
      const begin = performance.now();
      let lastY = scrollY;
      let stableSince = begin;
      let ended = false;
      let raf;
      return new Promise((done) => {
        const finish = (settled) => {
          if (ended) return;
          ended = true;
          cancelAnimationFrame(raf);
          clearTimeout(timer);
          done({ settled, elapsedMs: performance.now() - begin, scrollY });
        };
        const timer = setTimeout(() => finish(false), maximumMs);
        const tick = () => {
          const now = performance.now();
          if (Math.abs(scrollY - lastY) > 0.5) stableSince = now;
          lastY = scrollY;
          const canvas = document.querySelector('#court-canvas');
          const matchingChapter =
            !chapter || canvas?.dataset.chapter === chapter;
          const matchingTarget =
            !Number.isFinite(target) || Math.abs(scrollY - target) < 4;
          if (
            now - begin >= minimumMs &&
            now - stableSince >= 160 &&
            matchingChapter &&
            matchingTarget &&
            canvas?.dataset.rendering === 'idle'
          )
            finish(true);
          else if (now - begin >= maximumMs) finish(false);
          else raf = requestAnimationFrame(tick);
        };
        raf = requestAnimationFrame(tick);
      });
    },
    { maximumMs, minimumMs, chapter, target },
  );
}

async function scrollNative(page, destination, duration = 3000) {
  // A real keydown clears any remembered anchor intent through the site's normal handler.
  await page.keyboard.press('Escape');
  return page.evaluate(
    async ({ destination, duration }) => {
      const start = scrollY;
      const begin = performance.now();
      let raf;
      let finished = false;
      return new Promise((done) => {
        const finish = (completed) => {
          if (finished) return;
          finished = true;
          clearTimeout(timer);
          cancelAnimationFrame(raf);
          done({ completed, begin: start, destination, scrollY });
        };
        const timer = setTimeout(() => finish(false), duration + 1500);
        const tick = (now) => {
          const progress = Math.min(1, (now - begin) / duration);
          scrollTo({
            top: start + (destination - start) * progress,
            behavior: 'instant',
          });
          if (progress >= 1) finish(true);
          else raf = requestAnimationFrame(tick);
        };
        raf = requestAnimationFrame(tick);
      });
    },
    { destination, duration },
  );
}

async function phaseCapture(
  page,
  name,
  target,
  viewport,
  operation,
  alreadyStarted = false,
  workload = null,
) {
  if (!alreadyStarted)
    await page.evaluate((name) => {
      const evidence = window.hoopitoGpuEvidence;
      evidence.phase = name;
      evidence.environment.push(window.hoopitoGpuSnapshot('phase-start'));
    }, name);
  let completion;
  let error;
  let errorEvidence;
  try {
    completion = await operation();
  } catch (caught) {
    ({ error, errorEvidence } = serializeMeasurementFailure(caught, workload));
    completion = errorEvidence;
  }
  const state = await pendingState(page);
  const raw = await page.evaluate((name) => {
    const evidence = window.hoopitoGpuEvidence;
    evidence.environment.push(window.hoopitoGpuSnapshot('phase-end'));
    evidence.phase = null;
    return {
      frames: evidence.frames.filter((entry) => entry.phase === name),
      environment: evidence.environment.filter((entry) => entry.phase === name),
      longTasks: evidence.longTasks.filter((entry) => entry.phase === name),
      wheelInputs: evidence.wheelInputs.filter((entry) => entry.phase === name),
    };
  }, name);
  const environmental = assessEnvironment(raw.environment, {
    viewport,
    rendererExpression: target.expression,
    headless,
  });
  const submissionGate = summarizeSubmissions(raw.frames);
  if (
    error ||
    completion?.settled === false ||
    completion?.completed === false
  ) {
    submissionGate.status = 'fail';
    submissionGate.passes = false;
    submissionGate.completionFailure =
      error ??
      'Bounded phase completion expired while motion or navigation remained pending.';
  }
  const presentationGate = assessPresentation();
  return {
    environmental,
    submissionGate,
    presentationGate,
    status: combineGates(environmental, submissionGate, presentationGate),
    passes: false,
    completion,
    ...(error ? { error, errorEvidence } : {}),
    state,
    raw,
  };
}

async function openDocument(context, temperature) {
  const page = await context.newPage();
  page.setDefaultTimeout(5000);
  const session = await context.newCDPSession(page);
  // Playwright's normal focus emulation would conceal native foreground loss.
  await session.send('Emulation.setFocusEmulationEnabled', { enabled: false });
  await session.detach();
  await page.addInitScript(observeDocument, {
    temperature,
    measureIntro: selectedPhases.includes('intro'),
  });
  await page.bringToFront();
  return page;
}

async function measureDocument(
  context,
  target,
  viewport,
  temperature,
  filePrefix,
  traceSession,
) {
  const page = await openDocument(context, temperature);
  const errors = [];
  page.on('pageerror', (error) => errors.push(error.message));
  const phases = {};
  let activeWorkload = null;
  try {
    if (traceSession)
      await traceSession.send('Tracing.start', {
        categories:
          'benchmark,cc,gpu,viz,toplevel,blink.user_timing,disabled-by-default-devtools.timeline.frame,disabled-by-default-gpu.service',
        transferMode: 'ReturnAsStream',
      });
    await page.goto(origin + '/', { waitUntil: 'load', timeout: 20000 });
    await page.bringToFront();
    await page.waitForFunction(
      () =>
        document.documentElement.dataset.scene === '3d' ||
        document.documentElement.dataset.sceneFallback,
      null,
      { timeout: 20000 },
    );
    const details = await pendingState(page);
    const initialLayout = await storyLayout(page);
    if (selectedPhases.includes('intro'))
      phases.intro = await phaseCapture(
        page,
        'intro',
        target,
        viewport,
        () =>
          settle(page, {
            maximumMs: 3200,
            minimumMs: 350,
            chapter: 'hero',
            target: 0,
          }),
        true,
      );
    else await settle(page, { maximumMs: 3200 });
    for (const [name, chapter] of [
      ['experience-entry', 'experience'],
      ['replay-entry', 'replay'],
    ]) {
      if (!selectedPhases.includes(name)) continue;
      phases[name] = await phaseCapture(
        page,
        name,
        target,
        viewport,
        async () => {
          const layout = await storyLayout(page);
          await page.locator('.site-header a[href="#' + chapter + '"]').click();
          return settle(page, {
            maximumMs: 3500,
            chapter,
            target: layout[chapter].anchor,
          });
        },
      );
    }
    for (const name of [
      'experience-wheel-entry',
      'replay-wheel-entry',
      'reverse-wheel',
    ]) {
      if (!selectedPhases.includes(name)) continue;
      const workload = createWheelWorkload(
        name,
        initialLayout,
        viewport.height,
      );
      activeWorkload = workload;
      const beforePreparation = await pendingState(page);
      const scroll = await scrollNative(page, workload.startY, 900);
      const preparation = {
        inputMethod: 'scripted native scrollTo; outside measured phase',
        measured: false,
        boundary: initialLayout,
        before: beforePreparation,
        scroll,
        stability: await settle(page, {
          maximumMs: 3500,
          target: workload.startY,
        }),
        after: await pendingState(page),
      };
      // Put the pointer in the scene column without touching interactive controls.
      await page.mouse.move(viewport.width * 0.8, viewport.height * 0.5);
      phases[name] = await phaseCapture(
        page,
        name,
        target,
        viewport,
        async () => {
          if (!scroll.completed || !preparation.stability.settled)
            throw new Error('Wheel workload preparation did not settle.');
          const input = await runWheelInput(workload, {
            now: () => performance.now(),
            wait: (milliseconds) => page.waitForTimeout(milliseconds),
            wheel: (deltaX, deltaY) => page.mouse.wheel(deltaX, deltaY),
            readPosition: () =>
              page.evaluate(() => ({ scrollY, time: performance.now() })),
          });
          const stability = await settle(page, {
            maximumMs: 3500,
            chapter: workload.targetChapter,
            target: workload.targetY,
          });
          const final = await pendingState(page);
          const stage = final.stages.find(
            (candidate) => candidate.storyStage === workload.targetChapter,
          );
          const chapterReady =
            final.canvas.chapter === workload.targetChapter &&
            (workload.targetChapter === 'experience'
              ? final.canvas.inputEnabled === 'true'
              : workload.targetChapter === 'replay'
                ? Number(stage?.storyProgress) >= 0.999
                : Math.abs(final.scrollY - workload.targetY) < 4);
          return {
            ...input,
            settled: stability.settled && chapterReady,
            stability,
            qualification: {
              allInputsDispatched:
                input.emitted.length === workload.inputSequence.length,
              chapterReady,
              targetReached: Math.abs(final.scrollY - workload.targetY) < 4,
              chapter: final.canvas.chapter,
              inputEnabled: final.canvas.inputEnabled,
              stageProgress: Number(stage?.storyProgress),
            },
          };
        },
        false,
        workload,
      );
      Object.assign(phases[name], {
        workloadVersion: workload.workloadVersion,
        inputMethod: workload.inputMethod,
        inputSequence: workload.inputSequence,
        workload,
        preparation,
      });
      activeWorkload = null;
    }
    if (selectedPhases.includes('reverse-story')) {
      // Phase filtering still starts reversal from this build's actual replay anchor.
      if (!selectedPhases.includes('replay-entry')) {
        await page.locator('.site-header a[href="#replay"]').click();
        await settle(page, { maximumMs: 3500, chapter: 'replay' });
      }
      phases['reverse-story'] = await phaseCapture(
        page,
        'reverse-story',
        target,
        viewport,
        async () => {
          const layout = await storyLayout(page);
          const scroll = await scrollNative(page, layout.hero.anchor);
          const result = await settle(page, {
            maximumMs: 2800,
            chapter: 'hero',
            target: layout.hero.anchor,
          });
          return { ...result, completed: scroll.completed, boundary: layout };
        },
      );
    }
    if (selectedPhases.includes('shot')) {
      // Positioning is a separate workload from the shot, already captured by experience-entry.
      await page.locator('.site-header a[href="#experience"]').click();
      const preparation = await settle(page, {
        maximumMs: 3500,
        chapter: 'experience',
      });
      phases.shot = await phaseCapture(
        page,
        'shot',
        target,
        viewport,
        async () => {
          const attempts = [];
          for (let index = 0; index < 4; index += 1) {
            await page.locator('[data-reset]').click();
            await page.locator('[data-point-preset="center"]').click();
            await page.locator('[data-record]').click();
            await page.waitForFunction(
              () =>
                document.querySelector('[data-demo]')?.dataset.demoPhase ===
                'scored',
              null,
              { timeout: 3000 },
            );
            const result = await settle(page, {
              maximumMs: 2500,
              minimumMs: 100,
              chapter: 'experience',
            });
            attempts.push(result);
            if (!result.settled) break;
          }
          return {
            settled:
              preparation.settled &&
              attempts.length === 4 &&
              attempts.every((attempt) => attempt.settled),
            preparation,
            attempts,
          };
        },
      );
    }
    const finalState = await pendingState(page);
    const allEvidence = await page.evaluate(() => window.hoopitoGpuEvidence);
    const rawFile = filePrefix + '-' + temperature + '-render-events.json';
    await writeFile(
      resolve(output, rawFile),
      JSON.stringify(
        {
          temperature,
          initialLayout,
          finalLayout: await storyLayout(page),
          allEvidence,
          phases: Object.fromEntries(
            Object.entries(phases).map(([name, phase]) => [name, phase.raw]),
          ),
        },
        null,
        2,
      ) + '\n',
    );
    for (const phase of Object.values(phases)) delete phase.raw;
    const environmental = {
      status: combineGates(
        ...Object.values(phases).map((phase) => phase.environmental),
      ),
    };
    const submissionGate = {
      status: combineGates(
        ...Object.values(phases).map((phase) => phase.submissionGate),
      ),
    };
    if (errors.length) {
      submissionGate.status = 'fail';
      submissionGate.errors = errors;
    }
    const presentationGate = assessPresentation();
    const result = {
      workloadVersion: WHEEL_WORKLOAD_VERSION,
      requestedPhases: selectedPhases,
      temperature,
      details,
      finalState,
      phases,
      environmental,
      submissionGate,
      presentationGate,
      status: combineGates(environmental, submissionGate, presentationGate),
      passes: false,
      rawFile,
      errors,
    };
    await page.screenshot({
      path: resolve(output, filePrefix + '-' + temperature + '-final.png'),
    });
    return result;
  } catch (error) {
    const { errorEvidence } = serializeMeasurementFailure(
      error,
      activeWorkload,
    );
    const state = await pendingState(page).catch(() => null);
    const raw = await page
      .evaluate(() => window.hoopitoGpuEvidence)
      .catch(() => null);
    const diagnosticFile =
      filePrefix + '-' + temperature + '-failed-events.json';
    await writeFile(
      resolve(output, diagnosticFile),
      JSON.stringify(
        {
          workloadVersion: WHEEL_WORKLOAD_VERSION,
          requestedPhases: selectedPhases,
          phaseInProgress: activeWorkload?.phase ?? null,
          state,
          raw,
          error: error.message,
          errorEvidence,
        },
        null,
        2,
      ) + '\n',
    );
    await page
      .screenshot({
        path: resolve(output, filePrefix + '-' + temperature + '-failed.png'),
      })
      .catch(() => {});
    const environmental =
      raw && state
        ? assessEnvironment([state.environment, ...raw.environment], {
            viewport,
            rendererExpression: target.expression,
            headless,
          })
        : {
            status: 'unavailable',
            reasons: ['No website environmental evidence was available.'],
          };
    const failure = {
      workloadVersion: WHEEL_WORKLOAD_VERSION,
      requestedPhases: selectedPhases,
      phaseInProgress: activeWorkload?.phase ?? null,
      errorEvidence,
      temperature,
      environmental,
      submissionGate: {
        status: 'unavailable',
        reason: 'The workload did not complete.',
        error: error.message,
      },
      presentationGate: assessPresentation(),
      status: combineGates(environmental, { status: 'unavailable' }),
      passes: false,
      phases,
      error: error.message,
      state,
      diagnosticFile,
    };
    report.failures.push({
      gpu: target.name,
      viewport,
      filePrefix,
      ...failure,
    });
    return failure;
  } finally {
    await page.close();
  }
}

async function captureTrace(browser, context, target, viewport, filePrefix) {
  const session = await browser.newBrowserCDPSession();
  const completed = new Promise((done) =>
    session.once('Tracing.tracingComplete', done),
  );
  let diagnostic;
  let completionTimer;
  try {
    diagnostic = await measureDocument(
      context,
      target,
      viewport,
      'diagnostic-cold',
      filePrefix,
      session,
    );
    await session.send('Tracing.end');
    const { stream } = await Promise.race([
      completed,
      new Promise((_, reject) => {
        completionTimer = setTimeout(
          () => reject(new Error('Trace stream completion timed out.')),
          15000,
        );
      }),
    ]);
    const chunks = [];
    while (true) {
      const chunk = await session.send('IO.read', { handle: stream });
      chunks.push(
        Buffer.from(chunk.data, chunk.base64Encoded ? 'base64' : 'utf8'),
      );
      if (chunk.eof) break;
    }
    await session.send('IO.close', { handle: stream });
    const bytes = Buffer.concat(chunks);
    const file = filePrefix + '-compositor-trace.json.gz';
    await writeFile(resolve(output, file), gzipSync(bytes));
    const trace = JSON.parse(bytes);
    const presentationGate = assessPresentation(trace);
    const groups = new Map();
    for (const event of trace.traceEvents ?? []) {
      if (
        !/DrawAndSwap|FramePresented|SwapBuffers|FrameDisplayed|SubmitCompositorFrame/.test(
          event.name,
        )
      )
        continue;
      const key =
        event.name + ':' + event.ph + ':' + event.pid + ':' + event.tid;
      const group = groups.get(key) ?? {
        name: event.name,
        phase: event.ph,
        pid: event.pid,
        tid: event.tid,
        count: 0,
      };
      group.count += 1;
      groups.set(key, group);
    }
    return {
      gpu: target.name,
      viewport,
      file,
      bytes: bytes.length,
      sha256: sha256(bytes),
      diagnostic,
      eventGroups: [...groups.values()].sort((a, b) => b.count - a.count),
      presentationGate,
      limitation:
        'Separate traced process; profiling overhead is included. Its timings never substitute for the untraced submission gate.',
    };
  } finally {
    clearTimeout(completionTimer);
    await session.detach().catch(() => {});
  }
}

const diagnosticTraces = [];
await new Promise((done) => server.listen(0, '127.0.0.1', done));
const origin = `http://127.0.0.1:${server.address().port}`;
try {
  for (const target of gpuTargets) {
    if (windowsHardware && !target.adapter) {
      report.unavailable.push({
        gpu: target.name,
        reason: 'Requested physical DXGI adapter not found.',
      });
      continue;
    }
    const args = [
      '--enable-gpu',
      '--disable-backgrounding-occluded-windows',
      ...(target.adapter
        ? [
            '--use-angle=d3d11',
            '--use-adapter-luid=' +
              target.adapter.HighPart +
              ',' +
              target.adapter.LowPart,
          ]
        : []),
    ];
    for (const viewport of viewports) {
      if (
        tracesEnabled &&
        ((viewport.width === 1440 && viewport.dpr === 1) ||
          (viewport.width === 1920 && viewport.dpr === 2))
      )
        diagnosticTraces.push({ target, viewport, args });
      if (traceOnly) continue;
      let totalRuns = runLimit ?? 1;
      for (let run = 1; run <= totalRuns; run += 1) {
        const filePrefix =
          target.name.replaceAll(/[^a-z0-9_-]/gi, '_') +
          '-' +
          viewport.width +
          'x' +
          viewport.height +
          '-' +
          viewport.dpr +
          'x-run' +
          run;
        let browser;
        const sample = {
          workloadVersion: WHEEL_WORKLOAD_VERSION,
          requestedPhases: selectedPhases,
          gpu: target.name,
          requestedAdapter: target.adapter,
          viewport,
          run,
          filePrefix,
          headless,
          launchArgs: args,
          traceEnabled: false,
        };
        try {
          browser = await launchBrowser(args);
          sample.browser = browser.version();
          const context = await browser.newContext({
            viewport: { width: viewport.width, height: viewport.height },
            deviceScaleFactor: viewport.dpr,
            reducedMotion: 'no-preference',
          });
          try {
            sample.cold = await measureDocument(
              context,
              target,
              viewport,
              'cold',
              filePrefix,
            );
            sample.warmed = await measureDocument(
              context,
              target,
              viewport,
              'warmed',
              filePrefix,
            );
          } finally {
            await context.close();
          }
          sample.environmental = {
            status: combineGates(
              sample.cold.environmental,
              sample.warmed.environmental,
            ),
          };
          sample.submissionGate = {
            status: combineGates(
              sample.cold.submissionGate,
              sample.warmed.submissionGate,
            ),
          };
          sample.presentationGate = assessPresentation();
          sample.status = combineGates(
            sample.environmental,
            sample.submissionGate,
            sample.presentationGate,
          );
        } catch (error) {
          sample.environmental = {
            status: 'unavailable',
            reason:
              'Browser or context could not provide an environmental sample.',
          };
          sample.submissionGate = { status: 'unavailable' };
          sample.presentationGate = assessPresentation();
          sample.status = 'unavailable';
          sample.error = error.message;
          report.failures.push({
            gpu: target.name,
            viewport,
            run,
            error: error.message,
          });
        } finally {
          await browser?.close();
        }
        sample.passes = sample.status === 'pass';
        report.samples.push(sample);
        await writeFile(
          resolve(output, filePrefix + '-measurement.json'),
          JSON.stringify(sample, null, 2) + '\n',
        );
        await saveReport();
        for (const temperature of ['cold', 'warmed'])
          for (const [name, phase] of Object.entries(
            sample[temperature]?.phases ?? {},
          )) {
            const gate = phase.submissionGate;
            console.log(
              target.name +
                ' ' +
                viewport.width +
                'x' +
                viewport.height +
                ' DPR' +
                viewport.dpr +
                ' run' +
                run +
                ' ' +
                temperature +
                ' ' +
                name +
                ': ' +
                (gate.averageFps?.toFixed(1) ?? '?') +
                ' FPS / p95 ' +
                (gate.p95FrameMs?.toFixed(2) ?? '?') +
                'ms / environment ' +
                phase.environmental.status +
                ' / submission ' +
                gate.status +
                ' / presentation ' +
                phase.presentationGate.status,
            );
          }
        if (
          !runLimit &&
          ((viewport.width === 1920 &&
            viewport.height === 1080 &&
            viewport.dpr === 2) ||
            sample.environmental.status !== 'pass' ||
            sample.submissionGate.status !== 'pass')
        )
          totalRuns = 3;
      }
    }
  }
  // All threshold workloads finish before a diagnostic browser starts.
  for (const { target, viewport, args } of diagnosticTraces) {
    let browser;
    const filePrefix =
      target.name.replaceAll(/[^a-z0-9_-]/gi, '_') +
      '-' +
      viewport.width +
      'x' +
      viewport.height +
      '-' +
      viewport.dpr +
      'x-diagnostic';
    try {
      browser = await launchBrowser(args);
      const context = await browser.newContext({
        viewport: { width: viewport.width, height: viewport.height },
        deviceScaleFactor: viewport.dpr,
        reducedMotion: 'no-preference',
      });
      try {
        report.traces.push(
          await captureTrace(browser, context, target, viewport, filePrefix),
        );
      } finally {
        await context.close();
      }
    } catch (error) {
      report.traces.push({
        gpu: target.name,
        viewport,
        error: error.message,
        presentationGate: assessPresentation(),
      });
    } finally {
      await browser?.close();
    }
    await saveReport();
  }
  report.environmental = {
    status: combineGates(
      ...report.samples.map((sample) => sample.environmental),
      ...(report.unavailable.length ? [{ status: 'unavailable' }] : []),
    ),
  };
  report.submissionGate = {
    status: combineGates(
      ...report.samples.map((sample) => sample.submissionGate),
    ),
  };
  report.presentationGate = assessPresentation();
  report.presentationGate.diagnosticTraceFiles = report.traces
    .map((trace) => trace.file)
    .filter(Boolean);
  report.status = combineGates(
    report.environmental,
    report.submissionGate,
    report.presentationGate,
  );
  report.passes = report.status === 'pass';
  await saveReport();
  console.log(
    'Overall ' +
      report.status +
      '; environment ' +
      report.environmental.status +
      '; submission ' +
      report.submissionGate.status +
      '; presentation ' +
      report.presentationGate.status,
  );
  console.log('Evidence: ' + output);
  if (!report.passes) process.exitCode = 1;
} catch (error) {
  report.error = error.message;
  report.status = 'fail';
  report.passes = false;
  await saveReport();
  throw error;
} finally {
  await new Promise((done) => server.close(done));
}
