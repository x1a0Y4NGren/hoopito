import { chromium } from '@playwright/test';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, access, readdir } from 'node:fs/promises';
import { resolve, relative, extname, sep } from 'node:path';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { platform, release } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

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
  await access(reportPath);
  throw new Error(
    `Evidence already exists: ${reportPath}. Select a new output directory.`,
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
await new Promise((done) => server.listen(0, '127.0.0.1', done));
const origin = `http://127.0.0.1:${server.address().port}`;
const headless = process.env.HOOPITO_GPU_HEADLESS === '1';
const viewports = process.env.HOOPITO_GPU_VIEWPORTS
  ? JSON.parse(process.env.HOOPITO_GPU_VIEWPORTS)
  : [
      { width: 1440, height: 900, dpr: 1 },
      { width: 1440, height: 900, dpr: 2 },
      { width: 1920, height: 1080, dpr: 1 },
      { width: 1920, height: 1080, dpr: 2 },
    ];
const report = {
  date: new Date().toISOString(),
  measurementScriptSha256: sha256(
    await readFile(fileURLToPath(import.meta.url)),
  ),
  platform: `${platform()} ${release()}`,
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
  method: headless
    ? 'Headless auxiliary test; renderer-verified WebGL scene-render submission cadence. Does not satisfy headed display acceptance.'
    : 'Headed installed Chrome, isolated temporary profiles, verified WebGL UNMASKED_RENDERER. Frame intervals come from renderCount mutations after composer.render() returns during active animation. This measures main-thread scene-render submission cadence, not GPU completion or idle requestAnimationFrame loops. A separate browser compositor trace is retained as diagnostic evidence.',
  limits:
    'WebGL submission uses the named GPU, but JavaScript render() return and MutationObserver timestamps do not prove GPU command completion, presentation, or physical monitor scanout. Viewport and deviceScaleFactor are browser emulation settings; a DPR2 sample proves a larger backing buffer, not a physically Retina monitor. Trace profiling is separate from threshold samples to avoid profiling overhead.',
  targets: { averageFps: 58, p95FrameMs: 20 },
  samples: [],
  traces: [],
  unavailable: [],
  failures: [],
};

function summarize(events) {
  const intervals = [];
  let previous;
  let segments = 0;
  for (const event of events) {
    if (event.rendering !== 'active') {
      // The last draw returns before the runtime marks a finished animation idle.
      // Its interval belongs to the preceding active segment; paused/off transitions do not.
      if (
        previous &&
        event.rendering === 'idle' &&
        event.count > previous.count
      )
        intervals.push(event.time - previous.time);
      previous = undefined;
      continue;
    }
    if (previous && event.count > previous.count)
      intervals.push(event.time - previous.time);
    if (!previous) segments += 1;
    if (!previous || event.count > previous.count) previous = event;
  }
  if (intervals.length < 12)
    return {
      passes: false,
      limitation:
        'Too few active scene frames; idle browser frames are deliberately excluded.',
      frames: intervals.length,
    };
  const sorted = [...intervals].sort((a, b) => a - b);
  const meanFrameMs =
    intervals.reduce((total, value) => total + value, 0) / intervals.length;
  const p95FrameMs = sorted[Math.ceil(sorted.length * 0.95) - 1];
  return {
    frames: intervals.length + segments,
    activeSegments: segments,
    activeDurationMs: intervals.reduce((total, value) => total + value, 0),
    meanFrameMs,
    averageFps: 1000 / meanFrameMs,
    p95FrameMs,
    maxFrameMs: sorted.at(-1),
    passes: 1000 / meanFrameMs >= 58 && p95FrameMs <= 20,
    intervals,
    qualities: [
      ...new Set(events.map((event) => event.quality).filter(Boolean)),
    ],
    chapters: [
      ...new Set(events.map((event) => event.chapter).filter(Boolean)),
    ],
  };
}

async function captureEvents(page, phase, operation) {
  await page.evaluate((phase) => {
    window.hoopitoGpuPhase = phase;
  }, phase);
  await operation();
  await page.evaluate(() => {
    window.hoopitoGpuPhase = null;
  });
  return page.evaluate(
    (phase) => window.hoopitoGpuFrames.filter((event) => event.phase === phase),
    phase,
  );
}

async function scrollStory(page, duration = 6000) {
  await page.evaluate(async (duration) => {
    const end =
      document.querySelector('#replay').getBoundingClientRect().top +
      scrollY +
      innerHeight * 0.75;
    const begin = performance.now();
    await new Promise((done) => {
      function animate(now) {
        const progress = Math.min(1, (now - begin) / duration);
        // A real native-scroll workload drives the website's normal ScrollTrigger callbacks.
        scrollTo({ top: Math.max(0, end * progress), behavior: 'instant' });
        if (progress === 1) done();
        else requestAnimationFrame(animate);
      }
      requestAnimationFrame(animate);
    });
  }, duration);
}

async function traceCompositor(browser, page, gpuName, viewport) {
  const session = await browser.newBrowserCDPSession();
  const completed = new Promise((done) =>
    session.once('Tracing.tracingComplete', done),
  );
  await session.send('Tracing.start', {
    categories: 'benchmark,cc,gpu,viz,toplevel',
    transferMode: 'ReturnAsStream',
  });
  await scrollStory(page, 2000);
  await session.send('Tracing.end');
  const { stream } = await completed;
  const chunks = [];
  while (true) {
    const chunk = await session.send('IO.read', { handle: stream });
    chunks.push(
      chunk.base64Encoded
        ? Buffer.from(chunk.data, 'base64')
        : Buffer.from(chunk.data),
    );
    if (chunk.eof) break;
  }
  await session.send('IO.close', { handle: stream });
  const bytes = Buffer.concat(chunks);
  const file = `${gpuName}-${viewport.width}-${viewport.dpr}x-compositor-trace.json.gz`;
  await writeFile(resolve(output, file), gzipSync(bytes));
  const trace = JSON.parse(bytes);
  const events = trace.traceEvents.filter((event) =>
    /DrawAndSwap|FramePresented|SwapBuffers|FrameDisplayed/.test(event.name),
  );
  const groups = new Map();
  for (const event of events) {
    const key = `${event.name}:${event.ph}:${event.pid}:${event.tid}`;
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
  const displayedGroups = new Map();
  for (const event of trace.traceEvents) {
    if (
      event.name !== 'Display::FrameDisplayed' ||
      !['I', 'i'].includes(event.ph) ||
      !Number.isFinite(event.ts)
    )
      continue;
    // Different compositor threads/displays are separate streams, never merged.
    const key = `${event.pid}:${event.tid}`;
    const group = displayedGroups.get(key) ?? {
      pid: event.pid,
      tid: event.tid,
      timestampsUs: [],
    };
    group.timestampsUs.push(event.ts);
    displayedGroups.set(key, group);
  }
  const compositorDisplayedCadence = [...displayedGroups.values()].map(
    (group) => {
      const timestamps = [...new Set(group.timestampsUs)].sort((a, b) => a - b);
      const intervals = timestamps
        .slice(1)
        .map((time, index) => (time - timestamps[index]) / 1000);
      const sorted = [...intervals].sort((a, b) => a - b);
      const durationMs = intervals.reduce(
        (total, interval) => total + interval,
        0,
      );
      const meanFrameMs = intervals.length
        ? durationMs / intervals.length
        : null;
      return {
        name: 'Display::FrameDisplayed',
        pid: group.pid,
        tid: group.tid,
        frames: timestamps.length,
        durationMs,
        meanFrameMs,
        averageFps: meanFrameMs ? 1000 / meanFrameMs : null,
        p95FrameMs: sorted.length
          ? sorted[Math.ceil(sorted.length * 0.95) - 1]
          : null,
        maxFrameMs: sorted.at(-1) ?? null,
        limitation:
          'Browser compositor displayed callback cadence during a separate traced scroll. Profiling overhead is included. These callbacks do not prove a physical monitor scanout or distinguish every displayed frame as a new 3D scene frame.',
      };
    },
  );
  report.traces.push({
    gpu: gpuName,
    viewport,
    file,
    bytes: bytes.length,
    sha256: sha256(bytes),
    eventGroups: [...groups.values()].sort((a, b) => b.count - a.count),
    compositorDisplayedCadence,
    limitation:
      'Separate traced scroll pass. Compositor event counts are not asserted to be physical display FPS.',
  });
  await session.detach();
}

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
            `--use-adapter-luid=${target.adapter.HighPart},${target.adapter.LowPart}`,
          ]
        : []),
    ];
    // Isolate each backing-buffer configuration in a fresh GPU process. Reusing
    // native windows produced one-second RAF stalls on this hybrid AMD/NVIDIA
    // host even while document.visibilityState remained visible.
    for (const viewport of viewports) {
      const browser = await chromium.launch({
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
      try {
        const context = await browser.newContext({
          viewport: { width: viewport.width, height: viewport.height },
          deviceScaleFactor: viewport.dpr,
          reducedMotion: 'no-preference',
        });
        try {
          const page = await context.newPage();
          // Each browser context opens a new native window. Explicitly activate
          // it before measuring; hidden pages intentionally suspend the demo.
          await page.bringToFront();
          await page.waitForFunction(() => !document.hidden);
          const errors = [];
          page.on('pageerror', (error) => errors.push(error.message));
          await page.addInitScript(() => {
            window.hoopitoGpuFrames = [];
            window.hoopitoGpuPhase = 'intro';
            const observe = () => {
              const canvas = document.querySelector('#court-canvas');
              if (!canvas) return;
              new MutationObserver((mutations) => {
                if (
                  !mutations.some(
                    (mutation) =>
                      mutation.attributeName === 'data-render-count' ||
                      mutation.attributeName === 'data-rendering',
                  )
                )
                  return;
                const count = Number(canvas.dataset.renderCount);
                if (!Number.isFinite(count)) return;
                window.hoopitoGpuFrames.push({
                  time: performance.now(),
                  count,
                  rendering: canvas.dataset.rendering,
                  chapter: canvas.dataset.chapter,
                  progress: Number(canvas.dataset.storyProgress),
                  quality: canvas.dataset.quality,
                  pipeline: canvas.dataset.pipeline,
                  pixelRatio: Number(canvas.dataset.pixelRatio),
                  bufferWidth: Number(canvas.dataset.bufferWidth),
                  bufferHeight: Number(canvas.dataset.bufferHeight),
                  phase: window.hoopitoGpuPhase,
                });
              }).observe(canvas, {
                attributes: true,
                attributeFilter: ['data-render-count', 'data-rendering'],
              });
            };
            document.addEventListener('DOMContentLoaded', observe, {
              once: true,
            });
          });
          await page.goto(`${origin}/`, { waitUntil: 'load' });
          await page.bringToFront();
          await page.waitForFunction(
            () =>
              document.documentElement.dataset.scene === '3d' ||
              document.documentElement.dataset.sceneFallback,
            null,
            { timeout: 15000 },
          );
          const details = await page.evaluate(() => ({
            scene: document.documentElement.dataset.scene,
            renderer: document.querySelector('#court-canvas').dataset.renderer,
            window: {
              innerWidth,
              innerHeight,
              outerWidth,
              outerHeight,
              devicePixelRatio,
              screenWidth: screen.width,
              screenHeight: screen.height,
              availableScreenWidth: screen.availWidth,
              availableScreenHeight: screen.availHeight,
            },
            canvas: {
              width: document.querySelector('#court-canvas').width,
              height: document.querySelector('#court-canvas').height,
              displayWidth: document.querySelector('#court-canvas').clientWidth,
              displayHeight:
                document.querySelector('#court-canvas').clientHeight,
            },
            quality: document.querySelector('#court-canvas').dataset.quality,
            pipeline: document.querySelector('#court-canvas').dataset.pipeline,
            calibration: document.querySelector('#court-canvas').dataset
              .calibration
              ? JSON.parse(
                  document.querySelector('#court-canvas').dataset.calibration,
                )
              : null,
            antialias:
              document.querySelector('#court-canvas').dataset.antialias,
            pixelRatio:
              document.querySelector('#court-canvas').dataset.pixelRatio,
          }));
          if (
            details.scene !== '3d' ||
            !details.renderer ||
            /SwiftShader|software|llvmpipe/i.test(details.renderer) ||
            !target.expression.test(details.renderer)
          ) {
            report.unavailable.push({
              gpu: target.name,
              viewport,
              ...details,
              reason:
                'The actual website WebGL renderer did not match the requested hardware adapter.',
            });
            continue;
          }
          await page.waitForFunction(
            () =>
              document.querySelector('#court-canvas').dataset.rendering ===
              'idle',
            null,
            { timeout: 10000 },
          );
          const intro = await page.evaluate(() =>
            window.hoopitoGpuFrames.filter((event) => event.phase === 'intro'),
          );
          const scroll = await captureEvents(page, 'scroll', () =>
            scrollStory(page),
          );
          await page.locator('#experience').scrollIntoViewIfNeeded();
          await page.waitForFunction(
            () =>
              document.querySelector('#court-canvas').dataset.chapter ===
              'experience',
          );
          const shot = await captureEvents(page, 'shot', async () => {
            for (let run = 0; run < 4; run += 1) {
              await page.locator('[data-reset]').click();
              await page.locator('[data-point-preset="center"]').click();
              await page.locator('[data-record]').click();
              await page.waitForFunction(
                () =>
                  document
                    .querySelector('[data-demo-marker]')
                    .hasAttribute('hidden') === false,
              );
              // Preserve the full net recoil after the score/marker becomes visible.
              await page.waitForFunction(
                () =>
                  document.querySelector('#court-canvas').dataset.rendering ===
                  'idle',
                null,
                { timeout: 5000 },
              );
            }
          });
          const sample = {
            passes: false,
            gpu: target.name,
            browser: browser.version(),
            launchArgs: args,
            headless,
            viewport,
            ...details,
            phases: {
              intro: summarize(intro),
              scroll: summarize(scroll),
              shot: summarize(shot),
            },
            errors,
          };
          sample.passes =
            !headless &&
            Object.values(sample.phases).every((phase) => phase.passes) &&
            errors.length === 0;
          report.samples.push(sample);
          await writeFile(
            resolve(
              output,
              `${target.name}-${viewport.width}-${viewport.dpr}x-render-events.json`,
            ),
            `${JSON.stringify({ intro, scroll, shot }, null, 2)}\n`,
          );
          await page.screenshot({
            path: resolve(
              output,
              `${target.name}-${viewport.width}-${viewport.dpr}x-shot.png`,
            ),
          });
          for (const [phase, result] of Object.entries(sample.phases))
            console.log(
              `${target.name} ${viewport.width}x${viewport.height} ${viewport.dpr}x ${phase}: ${result.averageFps?.toFixed(1) ?? '?'} FPS / p95 ${result.p95FrameMs?.toFixed(2) ?? '?'}ms / ${result.passes ? 'PASS' : 'FAIL'}`,
            );
          console.log(`Verified renderer: ${details.renderer}`);
          if (
            (viewport.width === 1440 && viewport.dpr === 1) ||
            (viewport.width === 1920 && viewport.dpr === 2)
          ) {
            try {
              await traceCompositor(browser, page, target.name, viewport);
            } catch (error) {
              report.traces.push({
                gpu: target.name,
                viewport,
                error: error.message,
                limitation:
                  'Diagnostic compositor trace failed; untraced scene-frame samples above remain available.',
              });
            }
          }
          await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
        } catch (error) {
          const page = context.pages().at(-1);
          const state = await page
            ?.evaluate(() => ({
              hidden: document.hidden,
              visibility: document.visibilityState,
              root: { ...document.documentElement.dataset },
              demo: document.querySelector('[data-demo]')?.dataset.demoPhase,
              canvas: { ...document.querySelector('#court-canvas')?.dataset },
            }))
            .catch(() => null);
          report.failures.push({
            gpu: target.name,
            viewport,
            error: error.message,
            state,
          });
          await page
            ?.screenshot({
              path: resolve(
                output,
                `${target.name}-${viewport.width}-${viewport.dpr}x-failed.png`,
              ),
            })
            .catch(() => {});
          await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
          console.log(
            `${target.name} ${viewport.width} ${viewport.dpr}x: FAILED ${error.message}; state ${JSON.stringify(state)}`,
          );
        } finally {
          await context.close();
        }
      } finally {
        await browser.close();
      }
    }
  }
  report.passes =
    report.samples.length > 0 &&
    report.unavailable.length === 0 &&
    report.failures.length === 0 &&
    report.samples.every((sample) => sample.passes);
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  console.log(`Evidence: ${output}`);
  if (!report.passes) process.exitCode = 1;
} catch (error) {
  report.error = error.message;
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  throw error;
} finally {
  await new Promise((done) => server.close(done));
}
