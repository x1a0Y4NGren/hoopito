import { chromium } from '@playwright/test';
import { createServer } from 'node:http';
import { readFile, mkdir, writeFile, readdir, access } from 'node:fs/promises';
import { resolve, relative, extname, sep } from 'node:path';
import { gzipSync } from 'node:zlib';
import { createHash } from 'node:crypto';
import { platform, release } from 'node:os';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';

// Cold, fixed local laboratory measurements; Android field testing is separate.
const dist = resolve('dist');
const stamp = new Date().toISOString().replaceAll(/[:.]/g, '-');
const output = resolve(
  process.env.HOOPTRACE_PERF_OUTPUT ??
    `output/cinematic/performance/mobile-${stamp}`,
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
const types = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.woff2': 'font/woff2',
  '.avif': 'image/avif',
  '.webp': 'image/webp',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
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
    const compress = /\.(html|css|js|svg)$/.test(path);
    response.writeHead(200, {
      'Content-Type': types[extname(path)] ?? 'application/octet-stream',
      'Cache-Control': 'no-store',
      ...(compress
        ? { 'Content-Encoding': 'gzip', Vary: 'Accept-Encoding' }
        : {}),
    });
    response.end(compress ? gzipSync(raw) : raw);
  } catch {
    response.writeHead(404).end();
  }
});
await new Promise((done) => server.listen(0, '127.0.0.1', done));
const origin = `http://127.0.0.1:${server.address().port}`;
await mkdir(output, { recursive: true });
const sha256 = (bytes) => createHash('sha256').update(bytes).digest('hex');
const buildFiles = await readdir(dist, { recursive: true });
const buildManifest = [];
for (const name of buildFiles
  .filter((name) => /\.[a-z0-9]+$/i.test(name))
  .sort()) {
  const bytes = await readFile(resolve(dist, name));
  buildManifest.push({
    path: name.replaceAll('\\', '/'),
    bytes: bytes.length,
    sha256: sha256(bytes),
  });
}
const median = (values) =>
  [...values].sort((a, b) => a - b)[Math.floor(values.length / 2)];
let browser;
const report = {
  date: new Date().toISOString(),
  browser: null,
  measurementScriptSha256: sha256(
    await readFile(fileURLToPath(import.meta.url)),
  ),
  platform: `${platform()} ${release()}`,
  sourceCommit: execFileSync('git', ['rev-parse', 'HEAD'], {
    encoding: 'utf8',
  }).trim(),
  sourceStatus: execFileSync(
    'git',
    [
      'status',
      '--porcelain',
      '--',
      'src',
      'public',
      'scripts',
      'astro.config.mjs',
      'package.json',
      'package-lock.json',
    ],
    { encoding: 'utf8' },
  ).trim(),
  buildHtmlSha256: sha256(await readFile(resolve(dist, 'index.html'))),
  buildManifestSha256: sha256(JSON.stringify(buildManifest)),
  mobileEnvironment: {
    viewport: { width: 390, height: 844 },
    dpr: 1,
    cpuSlowdown: 4,
    latencyMs: 150,
    downloadBitsPerSecond: 1_600_000,
    uploadBitsPerSecond: 750_000,
    cache: 'disabled; fresh browser context per sample',
    compression: 'gzip HTML/CSS/JS/SVG; AVIF/WebP/WOFF2 already compressed',
    motion: 'no-preference; normal mobile intro enabled',
    runsPerLocale: 3,
    firstScreenBudgetKiB: 500,
    atmosphereAndBallBudgetKiB: 160,
    capture:
      'After network idle, fonts ready, and 2.1 seconds for the finite opening reveal',
  },
  mobile: [],
  summary: [],
  limitation:
    'Installed Chrome headless mobile emulation is reproducible lab evidence, not Android field CWV or desktop display FPS.',
};
try {
  browser = await chromium.launch({
    ...(platform() === 'win32'
      ? {
          executablePath:
            process.env.HOOPTRACE_CHROME_PATH ??
            'C:/Program Files/Google/Chrome/Application/chrome.exe',
        }
      : { channel: 'chrome' }),
    headless: true,
    args: ['--enable-gpu'],
  });
  report.browser = browser.version();
  await writeFile(
    resolve(output, 'build-manifest.json'),
    `${JSON.stringify(buildManifest, null, 2)}\n`,
  );
  for (const path of ['/', '/en/']) {
    for (let run = 1; run <= 3; run += 1) {
      const context = await browser.newContext({
        viewport: report.mobileEnvironment.viewport,
        deviceScaleFactor: 1,
        isMobile: true,
        hasTouch: true,
        reducedMotion: 'no-preference',
      });
      try {
        const page = await context.newPage();
        const session = await context.newCDPSession(page);
        const transfers = new Map();
        session.on(
          'Network.responseReceived',
          ({ requestId, type, response }) => {
            if (response.url.startsWith(origin))
              transfers.set(requestId, {
                path: new URL(response.url).pathname,
                kind: type,
                mimeType: response.mimeType,
                status: response.status,
                transferred: 0,
              });
          },
        );
        session.on(
          'Network.loadingFinished',
          ({ requestId, encodedDataLength }) => {
            const transfer = transfers.get(requestId);
            if (transfer) transfer.transferred = encodedDataLength;
          },
        );
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
          window.hooptraceVitals = {
            lcp: 0,
            cls: 0,
            lcpElement: '',
            lcpResource: '',
            lcpChanges: [],
          };
          new PerformanceObserver((list) => {
            const entry = list.getEntries().at(-1);
            if (!entry) return;
            window.hooptraceVitals.lcp = entry.startTime;
            window.hooptraceVitals.lcpElement =
              entry.element?.outerHTML.slice(0, 300) ?? '';
            window.hooptraceVitals.lcpResource = entry.url ?? '';
            window.hooptraceVitals.lcpChanges.push({
              time: entry.startTime,
              tag: entry.element?.tagName ?? '',
              size: entry.size,
            });
          }).observe({ type: 'largest-contentful-paint', buffered: true });
          new PerformanceObserver((list) => {
            for (const entry of list.getEntries())
              if (!entry.hadRecentInput)
                window.hooptraceVitals.cls += entry.value;
          }).observe({ type: 'layout-shift', buffered: true });
        });
        await page.goto(`${origin}${path}`, { waitUntil: 'networkidle' });
        await page.evaluate(async () => {
          await document.fonts.ready;
          // The specified 1.8-second reveal must finish before the final LCP observation.
          await new Promise((done) => setTimeout(done, 2100));
        });
        const vitals = await page.evaluate(() => ({
          ...window.hooptraceVitals,
          scene: document.documentElement.dataset.scene,
          viewport: {
            width: innerWidth,
            height: innerHeight,
            dpr: devicePixelRatio,
          },
          images: [...document.querySelectorAll('img')]
            .filter((image) => {
              const bounds = image.getBoundingClientRect();
              return bounds.top < innerHeight && bounds.bottom > 0;
            })
            .map((image) => ({
              source: new URL(image.currentSrc || image.src).pathname,
              naturalWidth: image.naturalWidth,
              naturalHeight: image.naturalHeight,
              displayWidth: image.clientWidth,
              displayHeight: image.clientHeight,
            })),
          resources: performance
            .getEntriesByType('resource')
            .map((resource) => ({
              path: new URL(resource.name).pathname,
              initiator: resource.initiatorType,
              transferred: resource.transferSize,
              encodedBody: resource.encodedBodySize,
              durationMs: resource.duration,
            })),
        }));
        const requests = [...transfers.values()];
        const firstScreenBytes = requests.reduce(
          (total, resource) => total + resource.transferred,
          0,
        );
        const heroArtBytes = requests
          .filter((resource) =>
            /\/art\/(?:arena-(?:tall|wide)-|basketball-)/.test(resource.path),
          )
          .reduce((total, resource) => total + resource.transferred, 0);
        const desktopAssetsRequested = requests.filter((resource) =>
          /\/textures\/|court-scene|court-hardware|three\.module/.test(
            resource.path,
          ),
        );
        report.mobile.push({
          path,
          run,
          ...vitals,
          requests,
          firstScreenBytes,
          firstScreenKiB: firstScreenBytes / 1024,
          heroArtBytes,
          heroArtKiB: heroArtBytes / 1024,
          desktopAssetsRequested,
          passes:
            vitals.lcp > 0 &&
            vitals.lcp <= 2500 &&
            vitals.cls <= 0.1 &&
            firstScreenBytes <= 500 * 1024 &&
            heroArtBytes <= 160 * 1024 &&
            desktopAssetsRequested.length === 0,
        });
        console.log(
          `${path} cold ${run}: LCP ${vitals.lcp.toFixed(0)}ms / CLS ${vitals.cls.toFixed(4)} / ${vitals.scene} / ${(firstScreenBytes / 1024).toFixed(1)}KiB transferred`,
        );
        if (run === 1)
          await page.screenshot({
            path: resolve(output, `${path === '/' ? 'zh' : 'en'}-390-cold.png`),
          });
        await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
      } finally {
        await context.close();
      }
    }
    const samples = report.mobile.filter((sample) => sample.path === path);
    const lcpMedian = median(samples.map((sample) => sample.lcp));
    const clsMax = Math.max(...samples.map((sample) => sample.cls));
    const requestedDesktopAssets = samples.some(
      (sample) => sample.desktopAssetsRequested.length > 0,
    );
    const firstScreenMaxKiB = Math.max(
      ...samples.map((sample) => sample.firstScreenKiB),
    );
    const heroArtMaxKiB = Math.max(
      ...samples.map((sample) => sample.heroArtKiB),
    );
    report.summary.push({
      path,
      lcpMedian,
      clsMax,
      firstScreenMaxKiB,
      heroArtMaxKiB,
      passes:
        lcpMedian > 0 &&
        lcpMedian <= 2500 &&
        clsMax <= 0.1 &&
        firstScreenMaxKiB <= 500 &&
        heroArtMaxKiB <= 160 &&
        !requestedDesktopAssets,
    });
  }
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  for (const summary of report.summary)
    console.log(
      `${summary.path} median LCP ${summary.lcpMedian.toFixed(0)}ms / maximum CLS ${summary.clsMax.toFixed(4)}: ${summary.passes ? 'PASS' : 'FAIL'}`,
    );
  console.log(`Evidence: ${output}`);
  if (report.summary.some((sample) => !sample.passes)) process.exitCode = 1;
} catch (error) {
  report.error = error.message;
  await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`);
  throw error;
} finally {
  await browser?.close();
  await new Promise((done) => server.close(done));
}
