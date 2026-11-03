import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  assessEnvironment,
  assessPresentation,
  combineGates,
  summarizeSubmissions,
} from '../scripts/gpu-measurement.mjs';

const viewport = { width: 1440, height: 900, dpr: 2 };
const environment = {
  time: 0,
  scene: '3d',
  renderer: 'ANGLE (AMD, AMD Radeon(TM) Graphics, D3D11)',
  hidden: false,
  visibility: 'visible',
  focused: true,
  width: 1440,
  height: 900,
  dpr: 2,
  canvasWidth: 2160,
  canvasHeight: 1350,
  displayWidth: 1440,
  displayHeight: 900,
  pixelRatio: 1.5,
  bufferWidth: 2160,
  bufferHeight: 1350,
  quality: 'effects',
  pipeline: 'native-msaa',
};

test('focus or visibility loss between good endpoint observations invalidates the phase', () => {
  for (const gap of [
    { focused: false },
    { hidden: true, visibility: 'hidden' },
    { focused: undefined },
  ]) {
    const result = assessEnvironment(
      [
        environment,
        { ...environment, time: 8, ...gap },
        { ...environment, time: 16 },
      ],
      { viewport, rendererExpression: /AMD Radeon/i, headless: false },
    );
    assert.equal(result.status, 'fail');
  }
});

test('renderer mismatch or software rendering invalidates real hardware evidence', () => {
  for (const renderer of [
    'ANGLE (NVIDIA, NVIDIA GeForce RTX 4070, D3D11)',
    'ANGLE (SwiftShader Device)',
    undefined,
  ]) {
    assert.equal(
      assessEnvironment([{ ...environment, renderer }], {
        viewport,
        rendererExpression: /AMD Radeon/i,
        headless: false,
      }).status,
      'fail',
    );
  }
});

test('backing-buffer density is verified independently from emulated device density', () => {
  assert.equal(
    assessEnvironment([environment], {
      viewport,
      rendererExpression: /AMD Radeon/i,
      headless: false,
    }).status,
    'pass',
  );
  assert.equal(
    assessEnvironment([{ ...environment, canvasWidth: 1440 }], {
      viewport,
      rendererExpression: /AMD Radeon/i,
      headless: false,
    }).status,
    'fail',
  );
});

test('rounded runtime density metadata accepts a consistent capped backing buffer', () => {
  const result = assessEnvironment(
    [
      {
        ...environment,
        width: 1920,
        height: 1080,
        displayWidth: 1920,
        displayHeight: 1080,
        canvasWidth: 2981,
        canvasHeight: 1677,
        bufferWidth: 2981,
        bufferHeight: 1677,
        pixelRatio: 1.55,
      },
    ],
    {
      viewport: { width: 1920, height: 1080, dpr: 2 },
      rendererExpression: /AMD Radeon/i,
      headless: false,
    },
  );
  assert.equal(result.status, 'pass');
});

test('Chrome floating point device density is accepted while a real density mismatch fails', () => {
  for (const [dpr, status] of [
    [2.0000000298023224, 'pass'],
    [2.01, 'fail'],
  ] as const) {
    assert.equal(
      assessEnvironment([{ ...environment, dpr }], {
        viewport,
        rendererExpression: /AMD Radeon/i,
        headless: false,
      }).status,
      status,
    );
  }
});

test('a genuine long active frame remains in submission statistics and fails the gate', () => {
  const times = [0, 16, 32, 48, 64, 80, 96, 112, 512, 528, 544, 560, 576, 592];
  const result = summarizeSubmissions(
    times.map((time, count) => ({
      time,
      count: count + 1,
      rendering: 'active',
    })),
  );
  assert.equal(result.status, 'fail');
  assert.equal(result.maxFrameMs, 400);
  assert.equal(result.intervals.length, 13);
  assert.equal(result.activeDurationMs, 592);
});

test('idle gaps are excluded while the final active draw interval is retained', () => {
  const result = summarizeSubmissions(
    [
      { time: 0, count: 1, rendering: 'active' },
      { time: 16, count: 2, rendering: 'idle' },
      { time: 5000, count: 3, rendering: 'active' },
      { time: 5016, count: 4, rendering: 'idle' },
    ],
    { minimumIntervals: 2 },
  );
  assert.deepEqual(result.intervals, [16, 16]);
  assert.equal(result.status, 'pass');
});

test('reading drift does not enter the active gate but retains its final active transition', () => {
  const result = summarizeSubmissions(
    [
      { time: 0, count: 1, rendering: 'active' },
      { time: 16, count: 2, rendering: 'ambient' },
      { time: 5000, count: 3, rendering: 'ambient' },
      { time: 5016, count: 4, rendering: 'active' },
      { time: 5032, count: 5, rendering: 'idle' },
    ],
    { minimumIntervals: 2 },
  );
  assert.deepEqual(result.intervals, [16, 16]);
  assert.equal(result.status, 'pass');
});

test('reading cadence records deliberate 24Hz separately from active acceptance', async () => {
  const measurement = await import('../scripts/gpu-measurement.mjs');
  assert.equal(typeof measurement.summarizeReadingDrift, 'function');
  const result = measurement.summarizeReadingDrift(
    Array.from({ length: 14 }, (_, index) => ({
      time: index * (1000 / 24),
      count: index + 1,
      rendering: 'ambient',
      chapter: 'hero',
    })),
  );
  assert.equal(result.status, 'recorded');
  assert.equal(result.thresholdApplied, false);
  assert.equal(result.frames, 14);
  assert.equal(result.skippedCounts, 0);
  assert.ok(result.averageFps !== null);
  assert.ok(Math.abs(result.averageFps - 24) < 0.0001);
  assert.equal(result.intervals.length, 13);
});

test('reading cadence retains stalls and marks missed submissions or other motion unavailable', async () => {
  const measurement = await import('../scripts/gpu-measurement.mjs');
  assert.equal(typeof measurement.summarizeReadingDrift, 'function');
  const events = [
    0, 50, 100, 150, 200, 250, 650, 700, 750, 800, 850, 900, 950,
  ].map((time, index) => ({ time, count: index + 1, rendering: 'ambient' }));
  const stalled = measurement.summarizeReadingDrift(events);
  assert.equal(stalled.status, 'recorded');
  assert.equal(stalled.maxFrameMs, 400);
  assert.equal(stalled.observedDurationMs, 950);
  const missed = measurement.summarizeReadingDrift(
    events.map((event, index) => ({
      ...event,
      count: event.count + (index > 5 ? 1 : 0),
    })),
  );
  assert.equal(missed.status, 'unavailable');
  assert.equal(missed.skippedCounts, 1);
  const moving = measurement.summarizeReadingDrift([
    ...events,
    { time: 1000, count: 14, rendering: 'active' },
  ]);
  assert.equal(moving.status, 'unavailable');
  assert.deepEqual(moving.unexpectedRenderStates, ['active']);
});

test('too few actual submissions are unavailable rather than a performance failure', () => {
  const result = summarizeSubmissions([
    { time: 0, count: 1, rendering: 'active' },
    { time: 16, count: 2, rendering: 'active' },
  ]);
  assert.equal(result.status, 'unavailable');
  assert.equal(result.passes, false);
});

test('generic compositor callbacks cannot establish WebGL frame presentation', () => {
  const result = assessPresentation({
    traceEvents: [
      { name: 'Display::FrameDisplayed', ph: 'I', pid: 1, tid: 2, ts: 1000 },
      { name: 'Display::FrameDisplayed', ph: 'I', pid: 1, tid: 2, ts: 17666 },
      {
        name: 'SwapBuffers',
        ph: 'I',
        pid: 1,
        tid: 3,
        ts: 17660,
        args: { frame_token: 42 },
      },
    ],
  });
  assert.equal(result.status, 'unavailable');
  assert.equal(result.passes, false);
  assert.equal(result.diagnosticCallbacks[0].frames, 2);
  assert.equal(result.frameIdentityEvents, 1);
});

test('an unavailable presentation gate prevents overall acceptance despite fast submissions', () => {
  assert.equal(
    combineGates(
      { status: 'pass' },
      { status: 'pass' },
      { status: 'unavailable' },
    ),
    'unavailable',
  );
  assert.equal(
    combineGates(
      { status: 'fail' },
      { status: 'pass' },
      { status: 'unavailable' },
    ),
    'fail',
  );
});
