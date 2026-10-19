#!/usr/bin/env node
// Run against an already-built, already-running local preview. Never installs an
// app, starts an emulator, retrieves an APK, or changes the site's motion policy.
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { createReadStream, writeFileSync } from 'node:fs';
import { mkdir, readdir, readFile, stat, writeFile } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { _android, chromium, expect as baseExpect } from '@playwright/test';

const root = fileURLToPath(new URL('..', import.meta.url));
const repo = path.dirname(root);
const args = process.argv.slice(2);
if (args.includes('--help')) {
  console.log(`node scripts/check-journey.mjs --desktop | --android
HOOPITO_LOCAL_ORIGIN=http://127.0.0.1:4321 (running local build required)
HOOPITO_JOURNEY_OUTPUT=output/frontend-refinement/journey (parent directory)
HOOPITO_APK_PATH=absolute/path/to/official.apk (optional; known local copies checked)
HOOPITO_ANDROID_AVD=Pixel_API_36 (exact AVD name; never a fixed serial)
HOOPITO_ADB_PATH=D:/Android/Sdk/platform-tools/adb.exe
HOOPITO_HEADED=1 (optional desktop Chrome window)
Each invocation creates a new timestamped directory; existing evidence is preserved.`);
  process.exit(0);
}
if (args.length !== 1 || !['--desktop', '--android'].includes(args[0]))
  throw new Error('Choose exactly one of --desktop or --android; see --help.');
const mode = args[0].slice(2);
const origin = new URL(
  process.env.HOOPITO_LOCAL_ORIGIN || 'http://127.0.0.1:4321',
);
if (
  !['127.0.0.1', 'localhost', '[::1]'].includes(origin.hostname) ||
  !['http:', 'https:'].includes(origin.protocol)
)
  throw new Error('HOOPITO_LOCAL_ORIGIN must point to a local preview.');
const expect = baseExpect.configure({ timeout: 10_000 });
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const outputParent = path.resolve(
  root,
  process.env.HOOPITO_JOURNEY_OUTPUT || 'output/frontend-refinement/journey',
);
await mkdir(outputParent, { recursive: true });
const output = path.join(outputParent, `${stamp}-${mode}-${process.pid}`);
await mkdir(output); // Deliberately exclusive: never replace an earlier sample.
const report = {
  schema: 1,
  startedAt: new Date().toISOString(),
  mode,
  origin: origin.origin,
  output,
  checks: [],
  issues: [],
  errors: [],
  requests: [],
  gestures: [],
  screenshots: [],
  screenshotAttempts: [],
  nativeUiInspections: [],
  orientations: [],
  galleryOpenings: [],
  androidConnectionTimeouts: [],
  nativePrompts: [],
  notes: [
    'Both languages run in one browser context and one page.',
    'Browser-page screenshots omit browser chrome, Android status/navigation bars and emulator frames.',
    'Download link inspection and local artifact verification are separate evidence; this runner never downloads or installs the APK.',
  ],
};
let browser, context, page, device, cdp, activeLanguage;
let androidState;
let presentation;
const androidCancellationTasks = [];
/** @type {Promise<void> | undefined} */
let signalCleanup;
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
async function bounded(label, promise, milliseconds, cancel) {
  let timer;
  try {
    return await Promise.race([
      promise,
      new Promise((_, reject) => {
        timer = setTimeout(() => {
          if (mode === 'android' && cancel) {
            const timeout = {
              operation: label,
              milliseconds,
              timedOutAt: new Date().toISOString(),
              cancellation: 'pending',
              cancellationError: /** @type {string | undefined} */ (undefined),
            };
            report.androidConnectionTimeouts.push(timeout);
            const cancellation = Promise.resolve()
              .then(cancel)
              .then(() => {
                timeout.cancellation = 'completed';
                timeout.cancellationCompletedAt = new Date().toISOString();
              })
              .catch((error) => {
                timeout.cancellation = 'failed';
                timeout.cancellationError = error.message;
                issue('cancel-android-connection', 'failed', error.message);
              });
            androidCancellationTasks.push(cancellation);
          }
          reject(
            new Error(
              `${label} exceeded ${milliseconds} ms; closing the device connection.`,
            ),
          );
        }, milliseconds);
      }),
    ]);
  } finally {
    clearTimeout(timer);
  }
}
const hash = (value) => createHash('sha256').update(value).digest('hex');
const command = (executable, values) =>
  execFileSync(executable, values, {
    cwd: root,
    encoding: 'utf8',
    timeout: 15_000,
    windowsHide: true,
  }).trim();
const adbPath =
  process.env.HOOPITO_ADB_PATH ||
  path.join(
    process.env.ANDROID_HOME || 'D:/Android/Sdk',
    'platform-tools',
    'adb.exe',
  );
const adb = (...values) => command(adbPath, ['-s', device.serial(), ...values]);
const issue = (name, status, detail) =>
  report.issues.push({ language: activeLanguage, name, status, detail });
let interrupted = false;
for (const signal of ['SIGINT', 'SIGTERM'])
  process.once(signal, () => {
    if (interrupted) return;
    interrupted = true;
    issue('runner-interrupted', 'failed', signal);
    signalCleanup = (async () => {
      try {
        await restoreAndroid();
      } catch (error) {
        issue('restore-android-state', 'failed', error.message);
      }
      report.passed = false;
      report.finishedAt = new Date().toISOString();
      writeFileSync(
        path.join(output, 'interrupted-results.json'),
        `${JSON.stringify(report, null, 2)}\n`,
        { flag: 'wx' },
      );
      // The ordinary finally still handles browser/video/trace shutdown.
      await context?.close().catch(() => {});
      process.exitCode = signal === 'SIGINT' ? 130 : 143;
    })();
  });

async function shaFile(file) {
  const digest = createHash('sha256');
  for await (const chunk of createReadStream(file)) digest.update(chunk);
  return digest.digest('hex');
}

async function treeHash(directory) {
  const files = [];
  async function visit(current) {
    for (const entry of await readdir(current, { withFileTypes: true })) {
      const file = path.join(current, entry.name);
      if (entry.isDirectory()) await visit(file);
      else if (entry.isFile())
        files.push({
          path: path.relative(directory, file).replaceAll('\\', '/'),
          sha256: await shaFile(file),
        });
    }
  }
  await visit(directory);
  files.sort((a, b) => a.path.localeCompare(b.path));
  return { sha256: hash(JSON.stringify(files)), files };
}

async function screenshot(name, fullPage = false) {
  for (let attempt = 1; attempt <= 2; attempt++) {
    const file = `${activeLanguage || 'setup'}-${name}${attempt === 1 ? '' : '-retry-2'}.png`;
    const observation = {
      language: activeLanguage,
      file,
      fullPage,
      attempt,
      status: 'pending',
      error: /** @type {string | undefined} */ (undefined),
    };
    report.screenshotAttempts.push(observation);
    try {
      await page.evaluate(async () => {
        await document.fonts.ready;
        await new Promise((resolve) =>
          requestAnimationFrame(() => requestAnimationFrame(resolve)),
        );
      });
      await page.screenshot({
        path: path.join(output, file),
        fullPage,
        timeout: 20_000,
      });
      observation.status = 'passed';
      report.screenshots.push({ language: activeLanguage, file, fullPage });
      return;
    } catch (error) {
      observation.status = 'failed';
      observation.error = error.message;
      if (attempt === 2 || !/timeout|timed out/i.test(error.message))
        throw error;
    }
  }
}

async function check(name, body) {
  if (interrupted || report.androidConnectionTimeouts.length)
    throw new Error(
      'Journey interrupted or Android connection timed out; stopping further input.',
    );
  const started = Date.now();
  try {
    const detail = await body();
    report.checks.push({
      language: activeLanguage,
      name,
      status: 'passed',
      durationMs: Date.now() - started,
      detail,
    });
    console.log(`${activeLanguage || mode}: PASS ${name}`);
    return detail;
  } catch (error) {
    const detail = error.stack || String(error);
    issue(name, 'failed', detail);
    report.checks.push({
      language: activeLanguage,
      name,
      status: 'failed',
      detail,
    });
    console.error(`${activeLanguage || mode}: FAIL ${name}: ${error.message}`);
    if (page && !page.isClosed())
      await screenshot(`failure-${report.issues.length}`).catch(() => {});
    return undefined;
  }
}

function unavailable(name, detail) {
  issue(name, 'unavailable', detail);
  report.checks.push({
    language: activeLanguage,
    name,
    status: 'unavailable',
    detail,
  });
}

async function inspectArtifact(release) {
  const name = path.basename(new URL(release.apkUrl).pathname);
  const candidates = process.env.HOOPITO_APK_PATH
    ? [path.resolve(process.env.HOOPITO_APK_PATH)]
    : [
        path.join(repo, 'build/app/outputs/flutter-apk/app-release.apk'),
        path.join(repo, 'build/app/outputs/apk/release/app-release.apk'),
        path.join(root, 'output/download', name),
        `D:/DevCache/HoopitoArtifacts/issue-6-20261012/formal-apk-4ecd960/${name}`,
        `D:/DevCache/HoopitoArtifacts/issue-6-20261012/public-release-readback/${name}`,
      ];
  const inspected = [];
  for (const file of candidates) {
    const info = await stat(file).catch(() => null);
    if (!info?.isFile()) continue;
    const sha256 = await shaFile(file);
    inspected.push({ path: file, bytes: info.size, sha256 });
    if (info.size === release.apkBytes && sha256 === release.sha256)
      return {
        status: 'verified-local-artifact',
        artifact: inspected.at(-1),
        officialUrl: release.apkUrl,
        retrieval: 'not-performed-by-this-runner',
        inspected,
      };
  }
  unavailable(
    'official-apk-artifact',
    'No local APK matched current release.ts bytes and SHA-256. Set HOOPITO_APK_PATH to an already-retrieved official artifact. Link inspection alone does not establish artifact retrieval.',
  );
  return { status: 'unavailable', inspected, retrieval: 'not-performed' };
}

async function restoreAndroid() {
  if (!androidState || !device) return;
  const restores = [
    [
      'shell',
      'settings',
      'put',
      'system',
      'user_rotation',
      androidState.rotation,
    ],
    [
      'shell',
      'settings',
      'put',
      'system',
      'accelerometer_rotation',
      androidState.auto,
    ],
  ];
  if (androidState.reverseChanged) {
    restores.push(
      androidState.previousReverse
        ? ['reverse', androidState.remote, androidState.previousReverse]
        : ['reverse', '--remove', androidState.remote],
    );
  }
  for (const values of restores) {
    try {
      adb(...values);
    } catch (error) {
      issue('restore-android-state', 'failed', error.message);
    }
  }
  const deadline = Date.now() + 2000;
  do {
    report.android.restored = {
      rotation: adb('shell', 'settings', 'get', 'system', 'user_rotation'),
      auto: adb('shell', 'settings', 'get', 'system', 'accelerometer_rotation'),
      reverse: adb('reverse', '--list'),
    };
    if (
      report.android.restored.rotation === androidState.rotation &&
      report.android.restored.auto === androidState.auto &&
      normalizeReverse(report.android.restored.reverse) ===
        normalizeReverse(androidState.reverse)
    )
      break;
    if (Date.now() >= deadline) break;
    await sleep(200);
  } while (true);
  const restored = !(
    report.android.restored.rotation !== androidState.rotation ||
    report.android.restored.auto !== androidState.auto ||
    normalizeReverse(report.android.restored.reverse) !==
      normalizeReverse(androidState.reverse)
  );
  report.android.restorationStatus = restored ? 'verified' : 'failed';
  if (!restored)
    issue(
      'restore-android-state',
      'failed',
      'Original rotation/reverse mapping differs after restoration.',
    );
}

function normalizeReverse(value) {
  return value
    .split(/\r?\n/)
    .map((line) => line.trim().replace(/\s+/g, ' '))
    .filter(Boolean)
    .sort()
    .join('\n');
}

async function launch() {
  if (mode === 'desktop') {
    browser = await chromium.launch({
      channel: 'chrome',
      headless: process.env.HOOPITO_HEADED !== '1',
      args: ['--enable-gpu'],
    });
    context = await browser.newContext({
      baseURL: origin.origin,
      viewport: { width: 1440, height: 1000 },
      reducedMotion: 'no-preference',
      recordVideo: {
        dir: path.join(output, 'video'),
        size: { width: 1440, height: 1000 },
      },
    });
    report.browser = {
      version: browser.version(),
      channel: 'chrome',
      requestedWebGL: true,
    };
    return;
  }
  const avd = process.env.HOOPITO_ANDROID_AVD || 'Pixel_API_36';
  const devices = await _android.devices({ omitDriverInstall: true });
  const matches = [];
  for (const candidate of devices) {
    if (!candidate.serial().startsWith('emulator-')) {
      await candidate.close();
      continue;
    }
    const name = command(adbPath, [
      '-s',
      candidate.serial(),
      'emu',
      'avd',
      'name',
    ])
      .split(/[\r\n]+/)
      .map((line) => line.trim())
      .filter((line) => line && line !== 'OK')
      .join('\n');
    if (name === avd) matches.push(candidate);
    else await candidate.close();
  }
  if (matches.length !== 1) {
    for (const match of matches) await match.close();
    throw new Error(
      `Expected one running exact AVD ${avd}; found ${matches.length}. Start it separately in read-only mode; this runner never starts an emulator.`,
    );
  }
  [device] = matches;
  device.setDefaultTimeout(10_000);
  const rotation = adb('shell', 'settings', 'get', 'system', 'user_rotation');
  const auto = adb(
    'shell',
    'settings',
    'get',
    'system',
    'accelerometer_rotation',
  );
  if (!/^[0-3]$/.test(rotation) || !/^[01]$/.test(auto))
    throw new Error(
      'Unexpected original rotation settings; refusing to change them.',
    );
  const reverse = adb('reverse', '--list');
  const remote = `tcp:${origin.port || (origin.protocol === 'https:' ? '443' : '80')}`;
  const previousReverse = reverse
    .split(/\r?\n/)
    .map((line) => line.trim().split(/\s+/))
    .find((fields) => fields.at(-2) === remote)
    ?.at(-1);
  androidState = {
    rotation,
    auto,
    reverse,
    remote,
    previousReverse,
    reverseChanged: false,
  };
  report.android = {
    avd,
    original: { ...androidState },
  };
  // Cleanup owns this report as soon as the original state is captured, even
  // when a subsequent device metadata read fails before setup changes anything.
  report.android.serial = device.serial();
  report.android.model = device.model();
  report.android.version = adb('shell', 'getprop', 'ro.build.version.release');
  report.android.api = adb('shell', 'getprop', 'ro.build.version.sdk');
  report.android.chrome = adb(
    'shell',
    'dumpsys',
    'package',
    'com.android.chrome',
  ).match(/versionName=(\S+)/)?.[1];
  if (!report.android.chrome)
    throw new Error('Installed Chrome is required; no app will be installed.');
  if (report.android.api !== '36')
    throw new Error(`Expected API 36; found ${report.android.api}.`);
  if (previousReverse !== remote) {
    adb('reverse', remote, remote);
    androidState.reverseChanged = true;
  }
  report.android.swipeMethod =
    'CDP Input.dispatchTouchEvent (single-finger swipe)';
  report.notes.push(
    'Android page scrolling uses real CDP browser touch events in CSS viewport coordinates; this does not establish OS hardware-input injection. ADB remains for the exact native Chrome prompt and device settings.',
  );
  adb('shell', 'settings', 'put', 'system', 'accelerometer_rotation', '0');
  adb('shell', 'settings', 'put', 'system', 'user_rotation', '0');
  context = await bounded(
    'Installed Android Chrome launch',
    device.launchBrowser({
      args: ['--no-first-run', '--disable-fre'],
      baseURL: origin.origin,
      viewport: null,
    }),
    30_000,
    () => device.close(),
  );
}

async function dismissChromeNotificationOnboarding() {
  if (mode !== 'android') return;
  const inspect = async () => {
    const dumpPath = `/data/local/tmp/hoopito-journey-${process.pid}.xml`;
    let xml = '';
    for (let attempt = 1; attempt <= 3; attempt++) {
      const observation = {
        language: activeLanguage,
        attempt,
        status: 'pending',
        error: /** @type {string | undefined} */ (undefined),
        cleanupError: /** @type {string | undefined} */ (undefined),
      };
      report.nativeUiInspections.push(observation);
      let failure;
      try {
        adb('shell', 'uiautomator', 'dump', dumpPath);
        xml = adb('shell', 'cat', dumpPath);
        if (!/<hierarchy\b/.test(xml) || !/<node\b/.test(xml))
          throw new Error(
            'Android native UI inspection returned no hierarchy nodes; notification onboarding absence cannot be verified.',
          );
      } catch (error) {
        failure = error;
        observation.error = error.message;
      } finally {
        try {
          adb('shell', 'rm', '-f', dumpPath);
        } catch (error) {
          observation.cleanupError = error.message;
          failure ??= error;
        }
      }
      if (!failure) {
        observation.status = 'passed';
        break;
      }
      observation.status = 'failed';
      if (attempt === 3) throw failure;
      await sleep(250);
    }
    const nodes = [...xml.matchAll(/<node\b[^>]*>/g)].map(([node]) =>
      Object.fromEntries(
        [...node.matchAll(/([\w:-]+)="([^"]*)"/g)].map(([, key, value]) => [
          key,
          value,
        ]),
      ),
    );
    const prompt = nodes.find(
      (node) =>
        node.package === 'com.android.chrome' &&
        node.text === 'Chrome notifications make things easier',
    );
    const decline = nodes.find(
      (node) =>
        node.package === 'com.android.chrome' &&
        node.text === 'No thanks' &&
        node.enabled !== 'false',
    );
    return { prompt, decline };
  };
  const { prompt, decline } = await inspect();
  if (!prompt) return;
  const bounds = decline?.bounds?.match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
  if (!bounds)
    throw new Error(
      'Chrome notification onboarding is present but its exact No thanks target has no valid native bounds.',
    );
  const x = Math.round((Number(bounds[1]) + Number(bounds[3])) / 2);
  const y = Math.round((Number(bounds[2]) + Number(bounds[4])) / 2);
  const action = {
    language: activeLanguage,
    package: 'com.android.chrome',
    prompt: prompt.text,
    action: 'decline-notification-onboarding',
    button: 'No thanks',
    bounds: decline.bounds,
    tap: { x, y },
    method: 'adb native input tap; no permission granted or package installed',
    verifiedAbsent: false,
  };
  report.nativePrompts.push(action);
  adb('shell', 'input', 'tap', String(x), String(y));
  for (let attempt = 0; attempt < 3; attempt++) {
    await sleep(200);
    if (!(await inspect()).prompt) {
      action.verifiedAbsent = true;
      return;
    }
  }
  throw new Error(
    'Chrome notification onboarding remained after its exact No thanks target was tapped.',
  );
}

async function nativeScroll(delta, fast = false) {
  const before = await page.evaluate(() => scrollY);
  let method = mode === 'desktop' ? 'mouse.wheel' : report.android.swipeMethod;
  let inputGeometry;
  if (mode === 'desktop') {
    await page.mouse.move(1100, 500);
    await page.mouse.wheel(0, delta);
  } else {
    const viewport = await page.evaluate(() => ({
      width: innerWidth,
      height: innerHeight,
      headerBottom:
        document.querySelector('.site-header')?.getBoundingClientRect()
          .bottom ?? 0,
    }));
    const top = Math.max(16, viewport.headerBottom + 14);
    const bottom = viewport.height - 20;
    if (bottom - top < 48)
      throw new Error(
        'Viewport has insufficient content height below the fixed header for a touch swipe.',
      );
    const distance = Math.min(
      (bottom - top) * 0.75,
      Math.max(32, Math.abs(delta)),
    );
    const x = viewport.width * 0.18;
    const from = { x, y: delta > 0 ? bottom : top };
    const to = { x, y: from.y + distance * (delta > 0 ? -1 : 1) };
    await dragTouch(from, to, 1, fast ? 90 : 320);
    method = 'CDP Input.dispatchTouchEvent (single-finger swipe)';
    inputGeometry = {
      reason:
        'Browser/status-bar insets make physical-screen fractions unreliable; use CSS viewport coordinates below the measured fixed header.',
      units: 'CSS viewport pixels',
      viewport,
      from,
      to,
    };
  }
  await sleep(fast ? 180 : 340);
  const after = await page.evaluate(() => scrollY);
  report.gestures.push({
    language: activeLanguage,
    type: method,
    inputGeometry,
    delta,
    fast,
    before,
    after,
  });
  return after - before;
}

async function nativeToY(target, tolerance = mode === 'android' ? 65 : 12) {
  let stuck = 0;
  for (let i = 0; i < 75; i++) {
    const { y, max } = await page.evaluate(() => ({
      y: scrollY,
      max: document.documentElement.scrollHeight - innerHeight,
    }));
    const wanted = Math.max(0, Math.min(max, target));
    const delta = wanted - y;
    if (Math.abs(delta) <= tolerance) return;
    const movement = await nativeScroll(
      Math.sign(delta) *
        Math.min(Math.abs(delta), mode === 'desktop' ? 820 : 520),
    );
    stuck = Math.abs(movement) < 1 ? stuck + 1 : 0;
    if (stuck >= 3) break;
  }
  throw new Error(
    `Native input could not reach scrollY ${Math.round(target)}; stopped at ${Math.round(await page.evaluate(() => scrollY))}.`,
  );
}

async function chapter(id) {
  const y = await page.locator(`#${id}`).evaluate((element, name) => {
    const stage = element.querySelector('[data-story-stage]');
    if (stage?.hasAttribute('data-story-start'))
      return (
        Number(stage.dataset.storyStart) +
        (Number(stage.dataset.storyEnd) - Number(stage.dataset.storyStart)) *
          (name === 'experience' ? 0.9 : 0.5)
      );
    return element.getBoundingClientRect().top + scrollY - 100;
  }, id);
  await nativeToY(y);
  await expect(
    page.locator(`#${id} ${id === 'hero' ? 'h1' : 'h2'}`),
  ).toBeVisible();
}

async function dragTouch(from, to, fingers = 1, durationMs = 320) {
  if (!cdp) cdp = await context.newCDPSession(page);
  const points = (progress) => {
    const primary = {
      x: from.x + (to.x - from.x) * progress,
      y: from.y + (to.y - from.y) * progress,
      id: 1,
    };
    return fingers === 1
      ? [primary]
      : [
          { x: from.x - (30 + 65 * progress), y: from.y, id: 1 },
          { x: from.x + (30 + 65 * progress), y: from.y, id: 2 },
        ];
  };
  try {
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchStart',
      touchPoints: points(0),
    });
    const steps = Math.max(4, Math.ceil(durationMs / 20));
    for (let i = 1; i <= steps; i++) {
      await cdp.send('Input.dispatchTouchEvent', {
        type: 'touchMove',
        touchPoints: points(i / steps),
      });
      await sleep(durationMs / steps);
    }
  } finally {
    await cdp.send('Input.dispatchTouchEvent', {
      type: 'touchEnd',
      touchPoints: [],
    });
  }
}

async function gallery() {
  const link = page.locator('#scoring .viewer-link');
  await nativeToY(
    await link.evaluate(
      (element) =>
        element.getBoundingClientRect().top + scrollY - innerHeight * 0.6,
    ),
  );
  const priorBefore = await page.evaluate(() => scrollY);
  await link.evaluate((element) => {
    const controller = new AbortController();
    Reflect.set(element, 'journeyOpeningCapture', controller);
    element.addEventListener(
      'click',
      () => {
        element.dataset.journeyOpeningScroll = String(scrollY);
      },
      { capture: true, once: true, signal: controller.signal },
    );
  });
  let scrollBefore;
  try {
    await link.click();
    scrollBefore = await link.evaluate((element) =>
      Number(element.dataset.journeyOpeningScroll),
    );
    expect(
      Number.isFinite(scrollBefore),
      'The actual gallery opening click must provide its scroll reference',
    ).toBe(true);
    report.galleryOpenings.push({
      language: activeLanguage,
      priorBefore,
      capturedAtClick: scrollBefore,
      delta: scrollBefore - priorBefore,
    });
  } finally {
    await link.evaluate((element) => {
      Reflect.get(element, 'journeyOpeningCapture')?.abort();
      Reflect.deleteProperty(element, 'journeyOpeningCapture');
      delete element.dataset.journeyOpeningScroll;
    });
  }
  await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
    'data-image-state',
    'ready',
  );
  const image = page.locator('[data-viewer-image]');
  const imageInfo = await image.evaluate((element) => ({
    src: element.currentSrc,
    width: element.naturalWidth,
    height: element.naturalHeight,
  }));
  expect(imageInfo.src).toMatch(/\/screenshots\/(zh|en)\/scoring\.webp$/);
  expect(imageInfo.width).toBe(presentation.screenshots.scoring.extract.width);
  expect(imageInfo.height).toBe(
    presentation.screenshots.scoring.extract.height,
  );
  await page.locator('[data-viewer-in]').click();
  await expect(page.locator('[data-viewer-scale]')).toHaveText('150%');
  const viewport = await page.locator('[data-viewer-viewport]').boundingBox();
  const center = {
    x: viewport.x + viewport.width / 2,
    y: viewport.y + viewport.height / 2,
  };
  let pinch;
  if (mode === 'android') {
    let supported = false;
    try {
      await page.locator('[data-viewer-fit]').click();
      await dragTouch(center, center, 2);
      supported = true;
      pinch = await page.locator('[data-viewer-scale]').innerText();
      expect(
        parseInt(pinch),
        'Dual touch must observably magnify the image',
      ).toBeGreaterThan(110);
      report.checks.push({
        language: activeLanguage,
        name: 'android-dual-touch-pinch',
        status: 'passed',
        detail: {
          scale: pinch,
          method: 'CDP Input.dispatchTouchEvent (two touch points)',
        },
      });
    } catch (error) {
      if (!supported) unavailable('android-dual-touch-pinch', error.message);
      else {
        issue('android-dual-touch-pinch', 'failed', error.message);
        report.checks.push({
          language: activeLanguage,
          name: 'android-dual-touch-pinch',
          status: 'failed',
          detail: error.message,
        });
      }
    }
  }
  // 300% makes a pan observable even for the wide scoring image on portrait Android.
  for (let attempt = 0; attempt < 7; attempt++) {
    if (parseInt(await page.locator('[data-viewer-scale]').innerText()) >= 300)
      break;
    await page.locator('[data-viewer-in]').click();
  }
  expect(
    parseInt(await page.locator('[data-viewer-scale]').innerText()),
  ).toBeGreaterThanOrEqual(300);
  const before = await image.boundingBox();
  if (mode === 'android')
    await dragTouch(center, { x: center.x - 65, y: center.y - 35 });
  else {
    await page.mouse.move(center.x, center.y);
    await page.mouse.down();
    await page.mouse.move(center.x - 110, center.y - 55, { steps: 15 });
    await page.mouse.up();
  }
  const after = await image.boundingBox();
  expect(
    Math.hypot(after.x - before.x, after.y - before.y),
    'Actual pointer/touch drag must move the magnified image',
  ).toBeGreaterThan(20);
  expect(await page.evaluate(() => scrollY)).toBeCloseTo(scrollBefore, 0);
  await screenshot('gallery-zoom-pan');
  await page.locator('[data-viewer-close]').click();
  await expect(link).toBeFocused();
  await expect
    .poll(() => page.evaluate(() => scrollY))
    .toBeCloseTo(scrollBefore, 0);
  return {
    cleanImage: imageInfo,
    pinch,
    panDistance: Math.hypot(after.x - before.x, after.y - before.y),
    focusAndScrollRestored: true,
    openingScroll: {
      priorBefore,
      capturedAtClick: scrollBefore,
      delta: scrollBefore - priorBefore,
    },
  };
}

async function demo() {
  await chapter('experience');
  const host = page.locator('[data-demo-court-host]');
  const actual3d = mode === 'desktop';
  if (actual3d) {
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d');
    await expect(page.locator('html')).toHaveAttribute(
      'data-interactive',
      'true',
    );
    await expect(host).toHaveAttribute('data-renderer', '3d');
  } else await expect(host).toHaveAttribute('data-renderer', '2d');
  const surface = actual3d ? host : page.locator('[data-demo-court]');
  const bounds = await surface.boundingBox();
  await surface.click({
    position: {
      x: bounds.width * 0.5,
      y: bounds.height * (actual3d ? 0.63 : 0.65),
    },
  });
  await expect(page.locator('[data-record]')).toBeEnabled();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-demo]')).toHaveAttribute(
    'data-demo-phase',
    'shooting',
  );
  await expect(page.locator('[data-blue-score]')).toHaveText('8');
  await expect(page.locator('[data-demo-marker]')).not.toHaveAttribute(
    'hidden',
  );
  await expect(page.locator('[data-demo]')).toHaveAttribute(
    'data-demo-phase',
    'scored',
  );
  await screenshot('shot-recorded');
  await page.locator('[data-reset]').click();
  await page.locator('[data-point-preset="left"]').click();
  await page.locator('[data-record]').click();
  await expect(page.locator('[data-demo]')).toHaveAttribute(
    'data-demo-phase',
    'shooting',
  );
  await sleep(300);
  await page.locator('[data-reset]').click();
  // Exceed the original 2.13 s animation deadline to catch stale completion.
  await sleep(2600);
  await expect(page.locator('[data-demo]')).toHaveAttribute(
    'data-demo-phase',
    'ready',
  );
  await expect(page.locator('[data-blue-score]')).toHaveText('6');
  await expect(page.locator('[data-demo-marker]')).toHaveAttribute(
    'hidden',
    '',
  );
  await expect(page.locator('[data-demo-selection]')).toHaveAttribute(
    'hidden',
    '',
  );
  await expect(page.locator('[data-record]')).toBeDisabled();
  await screenshot('reset-stable');
  return {
    renderer: actual3d ? 'real-3d' : '2d',
    courtClickSelected: true,
    completedScore: 8,
    resetScore: 6,
    staleCompletionObservationMs: 2600,
  };
}

async function replay() {
  await chapter('replay');
  const stage = page.locator('[data-story-stage="replay"]');
  const range = await stage.evaluate((element) => ({
    start: Number(element.dataset.replayStart),
    end: Number(element.dataset.replayEnd),
  }));
  const spins = () =>
    page.locator('[data-replay-card]').evaluateAll((elements) =>
      elements.map((element) => ({
        inline: element.style.transform,
        y: Number(
          element.style.transform.match(/rotateY\(([-\d.]+)deg\)/)?.[1],
        ),
        transform: getComputedStyle(element).transform,
      })),
    );
  let initial, final;
  if (mode === 'desktop') {
    expect(
      Number.isFinite(range.start) && range.end > range.start,
      'Desktop replay must expose its actual scroll range',
    ).toBeTruthy();
    await nativeToY(range.start, 1);
    await expect
      .poll(async () =>
        Number(await stage.getAttribute('data-replay-progress')),
      )
      .toBeLessThan(0.005);
    initial = await spins();
    for (const progress of [0.28, 0.48, 0.68, 1]) {
      await nativeToY(range.start + (range.end - range.start) * progress, 1);
      await screenshot(`replay-${Math.round(progress * 100)}`);
    }
    await expect
      .poll(async () =>
        Number(await stage.getAttribute('data-replay-progress')),
      )
      .toBe(1);
    final = await spins();
    for (let i = 0; i < 2; i++)
      expect(
        final[i].y - initial[i].y,
        `Card ${i + 1} must rotate 540 degrees`,
      ).toBeCloseTo(540, 0);
  } else {
    for (const card of await page.locator('[data-replay-card]').all())
      await expect(card).toHaveCSS('transform', 'none');
    report.notes.push(
      `${activeLanguage}: 540-degree card motion is a desktop behavior; Android intentionally uses static, upright cards.`,
    );
  }
  await expect(page.locator('[data-replay-blue]')).toHaveText('8');
  await expect(page.locator('[data-replay-red]')).toHaveText('11');
  for (const caption of await page
    .locator('[data-replay-device] figcaption')
    .all())
    await expect(caption).toHaveCSS('opacity', '1');
  for (const sheen of await page.locator('[data-replay-sheen]').all())
    await expect(sheen).toHaveCSS('opacity', '0');
  await screenshot('replay-landed');
  for (const type of ['summary', 'history']) {
    const link = page.locator(`[data-replay-device="${type}"] .viewer-link`);
    await link.click();
    await expect(page.locator('[data-viewer-viewport]')).toHaveAttribute(
      'data-image-state',
      'ready',
    );
    const dimensions = await page
      .locator('[data-viewer-image]')
      .evaluate((element) => [element.naturalWidth, element.naturalHeight]);
    expect(dimensions[0]).toBe(presentation.screenshots[type].extract.width);
    expect(dimensions[1]).toBe(presentation.screenshots[type].extract.height);
    await page.locator('[data-viewer-close]').click();
    await expect(link).toBeFocused();
  }
  return {
    initial,
    final,
    finalScore: [8, 11],
    bothCardsReadableAndOpenable: true,
  };
}

async function languageJourney(locale, release) {
  activeLanguage = locale.lang;
  const requestStart = report.requests.length;
  await page.goto(locale.path, { waitUntil: 'load', timeout: 30_000 });
  await dismissChromeNotificationOnboarding();
  await expect(page.locator('h1')).toBeVisible();
  await page.evaluate(() => document.fonts.ready);
  if (mode === 'desktop')
    await expect(page.locator('html')).toHaveAttribute('data-scene', '3d', {
      timeout: 15_000,
    });
  report[locale.lang] = await page.evaluate(() => ({
    userAgent: navigator.userAgent,
    width: innerWidth,
    height: innerHeight,
    dpr: devicePixelRatio,
    motion: matchMedia('(prefers-reduced-motion: reduce)').matches,
    scene: document.documentElement.dataset.scene,
  }));
  await check('hero-and-native-forward-reverse', async () => {
    await screenshot('hero');
    for (const id of ['scoring', 'experience', 'replay', 'download']) {
      await chapter(id);
      await screenshot(`forward-${id}`);
    }
    for (const id of ['replay', 'experience', 'scoring']) await chapter(id);
    const a = await nativeScroll(1400, true);
    const b = await nativeScroll(-1400, true);
    expect(a, 'Fast forward input must move the document').toBeGreaterThan(20);
    expect(b, 'Fast reverse input must move the document').toBeLessThan(-20);
    await chapter('scoring');
    return {
      nativeForwardReverse: true,
      fastForwardDelta: a,
      fastReverseDelta: b,
    };
  });
  await check('three-scoring-button-activations', async () => {
    const display = page.locator('[data-story-device]');
    const actions = [];
    for (const index of [0, 1, 2]) {
      const button = page.locator(`[data-score-feature="${index}"]`);
      await button.click();
      await expect(button).toHaveAttribute('aria-pressed', 'true');
      await expect(display).toHaveAttribute('data-score-focus', String(index));
      await expect(page.locator('[data-score-step]')).toHaveText(
        `0${index + 1} / 03`,
      );
      await expect(display).toHaveAttribute('data-score-playing', 'true');
      await expect(page.locator(`[data-score-action="${index}"]`)).toHaveCSS(
        'opacity',
        '1',
      );
      await screenshot(`scoring-button-${index + 1}`);
      await expect(display).toHaveAttribute('data-score-playing', 'false');
      actions.push({ button: index + 1, playingThenSettled: true });
    }
    return actions;
  });
  await check('clean-gallery-zoom-pan-close', gallery);
  if (await page.locator('[data-viewer]').isVisible())
    await page.locator('[data-viewer-close]').click();
  await check('court-select-shot-and-mid-animation-reset', demo);
  await check('replay-cards-and-final-score', replay);
  await check('download-links-and-matching-artifact', async () => {
    await page.locator('.nav-download').click();
    await expect(page.locator('#download h2')).toBeInViewport();
    if (mode === 'android')
      await nativeToY(
        await page
          .locator('#download .button')
          .evaluate(
            (element) =>
              element.getBoundingClientRect().top +
              scrollY -
              innerHeight * 0.35,
          ),
      );
    await expect(page.locator('#download .button')).toBeInViewport();
    for (const link of await page.locator('[data-download]').all())
      await expect(link).toHaveAttribute('href', release.apkUrl);
    await expect(page.locator('#download .release-link')).toHaveAttribute(
      'href',
      release.releaseUrl,
    );
    expect(
      report.artifact.status,
      'Artifact hash must be verified separately from link inspection',
    ).toBe('verified-local-artifact');
    await screenshot('download');
    return {
      linkInspection: 'passed',
      href: release.apkUrl,
      artifact: report.artifact.status,
      retrieval: report.artifact.retrieval,
    };
  });
  await check('privacy-and-browser-back', async () => {
    await page.locator(`.site-footer a[href="${locale.privacy}"]`).click();
    await expect(page).toHaveURL(new URL(locale.privacy, origin).href);
    await expect(page.locator('.privacy-content h1')).toBeVisible();
    await screenshot('privacy');
    await expect(page.locator('.privacy-content > .text-link')).toHaveAttribute(
      'href',
      locale.path,
    );
    await page.goBack({ waitUntil: 'load' });
    await expect(page.locator('#download h2')).toBeVisible();
    return { privacy: locale.privacy, back: page.url() };
  });
  if (mode === 'android')
    await check('android-landscape-and-portrait', async () => {
      const orientation = { language: activeLanguage, states: [] };
      report.orientations.push(orientation);
      const observe = async (label) =>
        orientation.states.push({
          label,
          auto: adb(
            'shell',
            'settings',
            'get',
            'system',
            'accelerometer_rotation',
          ),
          rotation: adb('shell', 'settings', 'get', 'system', 'user_rotation'),
          viewport: await page.evaluate(() => ({
            width: innerWidth,
            height: innerHeight,
          })),
        });
      await observe('before');
      try {
        adb(
          'shell',
          'settings',
          'put',
          'system',
          'accelerometer_rotation',
          '0',
        );
        await observe('auto-rotation-disabled-request');
        adb('shell', 'settings', 'put', 'system', 'user_rotation', '1');
        await observe('landscape-request');
        await expect
          .poll(() => page.evaluate(() => innerWidth > innerHeight))
          .toBe(true);
        await observe('landscape-observed');
        await chapter('replay');
        await screenshot('landscape-replay');
        await expect
          .poll(() =>
            page.evaluate(
              () => document.documentElement.scrollWidth <= innerWidth + 1,
            ),
          )
          .toBe(true);
      } finally {
        adb(
          'shell',
          'settings',
          'put',
          'system',
          'accelerometer_rotation',
          '0',
        );
        adb('shell', 'settings', 'put', 'system', 'user_rotation', '0');
        await observe('portrait-request');
        await expect
          .poll(() => page.evaluate(() => innerWidth < innerHeight))
          .toBe(true);
        await observe('portrait-observed');
      }
      await page.locator('.nav-download').click();
      return { landscapeAndPortrait: true };
    });
  await check('language-retains-current-section', async () => {
    await page.locator('.nav-download').click();
    await expect(page.locator('#download h2')).toBeInViewport();
    await page.locator('[data-language]').click();
    await expect(page).toHaveURL(
      new URL(`${locale.other}#download`, origin).href,
    );
    await expect(page.locator('#download h2')).toBeInViewport();
    const switched = page.url();
    await page.locator('[data-language]').click();
    await expect(page).toHaveURL(
      new URL(`${locale.path}#download`, origin).href,
    );
    await expect(page.locator('#download h2')).toBeInViewport();
    return { section: 'download', switched, returned: page.url() };
  });
  await check('whole-page-layout-and-resources', async () => {
    await screenshot('whole-page', true);
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth - innerWidth,
      ),
      'Horizontal document overflow',
    ).toBeLessThanOrEqual(1);
    const requests = report.requests.slice(requestStart);
    if (mode === 'android')
      expect(
        requests.filter((request) =>
          /court-(?:scene|engine)[^/]*\.(?:js|ts)|\/textures\//.test(
            request.url,
          ),
        ),
        'Android must not request desktop 3D resources',
      ).toEqual([]);
    return {
      requests: requests.length,
      noHorizontalOverflow: true,
      desktopResourcePolicy: mode === 'android' ? 'no-3d-resources' : 'real-3d',
    };
  });
}

try {
  presentation = JSON.parse(
    await readFile(
      path.join(repo, 'docs/design/screenshot-presentation.json'),
      'utf8',
    ),
  );
  const releaseText = await readFile(
    path.join(root, 'src/data/release.ts'),
    'utf8',
  );
  const release = (
    await import(new URL('../src/data/release.ts', import.meta.url))
  ).release;
  report.source = {
    commit: command('git', ['rev-parse', 'HEAD']),
    branch: command('git', ['branch', '--show-current']),
    worktree: command('git', ['status', '--short']),
    src: await treeHash(path.join(root, 'src')),
    releaseConfigSha256: hash(releaseText),
    provenance:
      'Working-tree source; HEAD alone does not describe uncommitted inputs.',
  };
  report.build = await treeHash(path.join(root, 'dist'));
  report.build.htmlSha256 = {
    zh: await shaFile(path.join(root, 'dist/index.html')),
    en: await shaFile(path.join(root, 'dist/en/index.html')),
  };
  const response = await fetch(origin, { signal: AbortSignal.timeout(10_000) });
  if (!response.ok)
    throw new Error(`Local preview returned HTTP ${response.status}.`);
  const servedHtml = await response.text();
  report.build.servedZhSha256 = hash(servedHtml);
  if (report.build.servedZhSha256 !== report.build.htmlSha256.zh)
    throw new Error(
      'Running origin HTML differs from dist/index.html; use the current production preview.',
    );
  report.artifact = await inspectArtifact(release);
  await launch();
  page = await context.newPage();
  page.setDefaultTimeout(10_000);
  page.setDefaultNavigationTimeout(30_000);
  page.on('pageerror', (error) =>
    report.errors.push({
      language: activeLanguage,
      type: 'pageerror',
      message: error.message,
    }),
  );
  page.on('console', (message) => {
    if (message.type() === 'error')
      report.errors.push({
        language: activeLanguage,
        type: 'console',
        message: message.text(),
      });
  });
  page.on('request', (request) =>
    report.requests.push({
      language: activeLanguage,
      url: request.url(),
      method: request.method(),
      type: request.resourceType(),
    }),
  );
  page.on('response', (response) => {
    report.requests.push({
      language: activeLanguage,
      url: response.url(),
      status: response.status(),
      type: 'response',
    });
    if (response.status() >= 400)
      report.errors.push({
        language: activeLanguage,
        type: 'http',
        url: response.url(),
        status: response.status(),
      });
  });
  page.on('requestfailed', (request) =>
    report.errors.push({
      language: activeLanguage,
      type: 'requestfailed',
      url: request.url(),
      message: request.failure()?.errorText,
    }),
  );
  await context.tracing.start({
    screenshots: true,
    snapshots: true,
    sources: true,
  });
  for (const locale of [
    { lang: 'zh', path: '/', other: '/en/', privacy: '/privacy/' },
    { lang: 'en', path: '/en/', other: '/', privacy: '/en/privacy/' },
  ]) {
    if (interrupted || report.androidConnectionTimeouts.length) break;
    try {
      await languageJourney(locale, release);
    } catch (error) {
      issue(
        `aborted-${locale.lang}-journey`,
        'failed',
        error.stack || String(error),
      );
    }
  }
} catch (error) {
  issue('runner', 'failed', error.stack || String(error));
  console.error(error.stack || error);
} finally {
  if (context)
    await context.tracing
      .stop({ path: path.join(output, 'trace.zip') })
      .catch((error) => issue('trace', 'failed', error.message));
  if (page && !page.isClosed()) report.finalUrl = page.url();
  await cdp?.detach().catch(() => {});
  await context
    ?.close()
    .catch((error) => issue('browser-close', 'failed', error.message));
  await Promise.all(androidCancellationTasks);
  await signalCleanup;
  if (androidState) {
    try {
      await restoreAndroid();
    } catch (error) {
      report.android.restorationStatus = 'failed';
      issue('restore-android-state', 'failed', error.message);
    }
  }
  await device
    ?.close()
    .catch((error) => issue('device-close', 'failed', error.message));
  await browser
    ?.close()
    .catch((error) => issue('browser-close', 'failed', error.message));
  report.finishedAt = new Date().toISOString();
  const requiresTimeoutExit =
    mode === 'android' && report.androidConnectionTimeouts.length > 0;
  if (requiresTimeoutExit)
    report.androidTimeoutExit = {
      reason:
        'Playwright can retain a socket-poll timer after device.close(). Exit only after cancellation, teardown, restoration attempts and report writes.',
      cancellationSettled:
        androidCancellationTasks.length ===
        report.androidConnectionTimeouts.length,
      restorationStatus: report.android?.restorationStatus ?? 'not-required',
      teardownCompletedAt: report.finishedAt,
      exitCode: 1,
    };
  report.passed = report.issues.length === 0 && report.errors.length === 0;
  report.summary = {
    passed: report.checks.filter((item) => item.status === 'passed').length,
    failed: report.checks.filter((item) => item.status === 'failed').length,
    unavailable: report.checks.filter((item) => item.status === 'unavailable')
      .length,
    errors: report.errors.length,
  };
  await writeFile(
    path.join(output, 'results.json'),
    `${JSON.stringify(report, null, 2)}\n`,
    { flag: 'wx' },
  );
  console.log(
    JSON.stringify(
      {
        output,
        passed: report.passed,
        summary: report.summary,
        issues: report.issues.map(({ language, name, status }) => ({
          language,
          name,
          status,
        })),
      },
      null,
      2,
    ),
  );
  if (!report.passed) process.exitCode = 1;
  if (requiresTimeoutExit) {
    // Android socket polling in Playwright1.64 does not stop when its backend
    // closes. All evidence and restoration attempts above must finish first.
    await Promise.all([
      new Promise((resolve) => process.stdout.write('', resolve)),
      new Promise((resolve) => process.stderr.write('', resolve)),
    ]);
    process.exit(1);
  }
}
