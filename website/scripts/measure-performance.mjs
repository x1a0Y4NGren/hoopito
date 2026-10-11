import { chromium } from '@playwright/test';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, relative, extname } from 'node:path';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { platform, release } from 'node:os';

// Fixed, repeatable local measurements. This is lab evidence, not field CWV.
const dist = resolve('dist');
const output = resolve('output/playwright/performance');
const types = {
  '.html': 'text/html',
  '.css': 'text/css',
  '.js': 'text/javascript',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
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
    if (relative(dist, path).startsWith('..')) {
      response.writeHead(403).end();
      return;
    }
    const raw = await readFile(path);
    const compress = /\.(html|css|js|svg)$/.test(path);
    const body = compress ? gzipSync(raw) : raw;
    response.writeHead(200, {
      'Content-Type': types[extname(path)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
      ...(compress ? { 'Content-Encoding': 'gzip' } : {}),
    });
    response.end(body);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((resolve) => server.listen(4322, '127.0.0.1', resolve));
await mkdir(output, { recursive: true });
let browser;
try {
  browser = await chromium.launch({
    channel: 'chrome',
    headless: true,
    args: ['--enable-gpu'],
  });
  const report = {
    date: new Date().toISOString(),
    browser: browser.version(),
    platform: `${platform()} ${release()}`,
    buildHtmlSha256: createHash('sha256')
      .update(await readFile(resolve(dist, 'index.html')))
      .digest('hex'),
    mobileEnvironment: {
      viewport: '390x844',
      dpr: 1,
      cpuSlowdown: 4,
      latencyMs: 150,
      downloadBitsPerSecond: 1_600_000,
      uploadBitsPerSecond: 750_000,
      cache: 'disabled',
      compression: 'gzip for HTML, CSS, JS and SVG; WOFF2/WebP native',
      runsPerLocale: 3,
    },
    mobile: [],
    desktop: null,
  };
  for (const path of ['/', '/en/']) {
    for (let run = 1; run <= 3; run++) {
      const context = await browser.newContext({
        viewport: { width: 390, height: 844 },
        deviceScaleFactor: 1,
        isMobile: true,
        hasTouch: true,
        reducedMotion: 'no-preference',
      });
      const page = await context.newPage();
      const session = await context.newCDPSession(page);
      await session.send('Network.enable');
      await session.send('Network.setCacheDisabled', { cacheDisabled: true });
      await session.send('Network.emulateNetworkConditions', {
        offline: false,
        latency: 150,
        downloadThroughput: 1_600_000 / 8,
        uploadThroughput: 750_000 / 8,
      });
      await session.send('Emulation.setCPUThrottlingRate', { rate: 4 });
      await page.addInitScript(() => {
        window.hooptraceVitals = { lcp: 0, cls: 0, lcpElement: '' };
        new PerformanceObserver((list) => {
          const entry = list.getEntries().at(-1);
          if (entry) {
            window.hooptraceVitals.lcp = entry.startTime;
            window.hooptraceVitals.lcpElement = entry.element?.tagName ?? '';
          }
        }).observe({ type: 'largest-contentful-paint', buffered: true });
        new PerformanceObserver((list) => {
          for (const entry of list.getEntries())
            if (!entry.hadRecentInput)
              window.hooptraceVitals.cls += entry.value;
        }).observe({ type: 'layout-shift', buffered: true });
      });
      await page.goto(`http://127.0.0.1:4322${path}`, {
        waitUntil: 'networkidle',
      });
      await page.evaluate(() => document.fonts.ready);
      const vitals = await page.evaluate(() => ({
        ...window.hooptraceVitals,
        scene: document.documentElement.dataset.scene,
        resources: performance.getEntriesByType('resource').map((resource) => ({
          url: resource.name,
          transferred: resource.transferSize,
        })),
      }));
      report.mobile.push({
        path,
        run,
        ...vitals,
        passes: vitals.lcp <= 2500 && vitals.cls <= 0.1,
      });
      console.log(
        `${path} cold ${run}: LCP ${vitals.lcp.toFixed(0)}ms / CLS ${vitals.cls.toFixed(4)} / ${vitals.scene}`,
      );
      if (run === 1)
        await page.screenshot({
          path: resolve(output, `${path === '/' ? 'zh' : 'en'}-390-cold.png`),
        });
      await context.close();
    }
  }
  const context = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 1,
    reducedMotion: 'no-preference',
  });
  const page = await context.newPage();
  await page.goto('http://127.0.0.1:4322/');
  await page.waitForFunction(
    () => document.documentElement.dataset.scene !== 'loading',
  );
  const renderer = await page
    .locator('#court-canvas')
    .getAttribute('data-renderer');
  const hardware = renderer && !/SwiftShader|software|llvmpipe/i.test(renderer);
  if (
    hardware &&
    (await page.locator('html').getAttribute('data-scene')) === '3d'
  ) {
    const frames = await page.evaluate(async () => {
      const samples = [];
      const chapters = [
        'hero',
        'scoring',
        'experience',
        'replay',
        'download',
      ].map((id) => document.getElementById(id));
      const anchors = chapters.map((chapter) => chapter.offsetTop);
      for (let i = 0; i < 5; i++) {
        scrollTo({ top: anchors[i], behavior: 'instant' });
        const intervals = [];
        await new Promise((resolve) => {
          let last = 0;
          function frame(now) {
            if (last) intervals.push(now - last);
            last = now;
            if (intervals.length >= 180) resolve();
            else requestAnimationFrame(frame);
          }
          requestAnimationFrame(frame);
        });
        const sorted = [...intervals].sort((a, b) => a - b);
        samples.push({
          chapter: chapters[i].id,
          frames: intervals.length,
          durationMs: intervals.reduce((a, b) => a + b, 0),
          meanFrameMs: intervals.reduce((a, b) => a + b, 0) / intervals.length,
          p95FrameMs: sorted[Math.ceil(sorted.length * 0.95) - 1],
          quality: document.querySelector('#court-canvas').dataset.quality,
          scene: document.documentElement.dataset.scene,
        });
      }
      return samples;
    });
    report.desktop = {
      renderer,
      viewport: '1440x900',
      dpr: 1,
      mode: 'Installed Chrome headless with --enable-gpu; actual hardware renderer. rAF frame cadence, includes rendering load; no GPU timer queries or physical display measurement.',
      samples: frames,
      averageFps: frames.map((sample) => ({
        chapter: sample.chapter,
        fps: 1000 / sample.meanFrameMs,
      })),
    };
    await page.screenshot({
      path: resolve(output, 'zh-1440-hardware-download.png'),
    });
    console.log(`GPU: ${renderer}`);
    console.log(JSON.stringify(report.desktop.averageFps));
  } else {
    report.desktop = {
      renderer,
      limitation: 'A real GPU renderer was unavailable. No hardware FPS claim.',
    };
    console.log(report.desktop.limitation);
  }
  await writeFile(
    resolve(output, 'measurements.json'),
    `${JSON.stringify(report, null, 2)}\n`,
  );
  if (report.mobile.some((sample) => !sample.passes)) process.exitCode = 1;
} finally {
  await browser?.close();
  await new Promise((resolve) => server.close(resolve));
}
