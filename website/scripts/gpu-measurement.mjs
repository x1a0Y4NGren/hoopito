const thresholds = { averageFps: 58, p95FrameMs: 20 };

function cadence(intervals) {
  const sorted = [...intervals].sort((a, b) => a - b);
  const activeDurationMs = intervals.reduce((sum, value) => sum + value, 0);
  const meanFrameMs = intervals.length
    ? activeDurationMs / intervals.length
    : null;
  return {
    activeDurationMs,
    meanFrameMs,
    averageFps: meanFrameMs > 0 ? 1000 / meanFrameMs : null,
    p95FrameMs: sorted.length
      ? sorted[Math.ceil(sorted.length * 0.95) - 1]
      : null,
    maxFrameMs: sorted.at(-1) ?? null,
  };
}

/** All observations in a phase matter, including blur/visibility transitions between draws. */
export function assessEnvironment(
  samples,
  { viewport, rendererExpression, headless },
) {
  if (!samples.length)
    return {
      status: 'unavailable',
      passes: false,
      reasons: ['No environmental observations.'],
    };
  const reasons = new Set();
  if (headless)
    reasons.add('Headless Chrome cannot satisfy headed acceptance.');
  for (const sample of samples) {
    if (sample.hidden !== false || sample.visibility !== 'visible')
      reasons.add('Visibility was hidden or missing during the phase.');
    if (sample.focused !== true)
      reasons.add(
        'Actual document focus was lost or missing during the phase.',
      );
    if (sample.scene !== '3d')
      reasons.add('The website did not expose an active 3D scene.');
    rendererExpression.lastIndex = 0;
    if (
      typeof sample.renderer !== 'string' ||
      /SwiftShader|software|llvmpipe|Microsoft Basic Render/i.test(
        sample.renderer,
      ) ||
      !rendererExpression.test(sample.renderer)
    )
      reasons.add(
        'The WebGL renderer did not match the requested hardware adapter.',
      );
    if (
      sample.width !== viewport.width ||
      sample.height !== viewport.height ||
      !Number.isFinite(sample.dpr) ||
      Math.abs(sample.dpr - viewport.dpr) > 1e-6
    )
      reasons.add(
        'Actual viewport or device density did not match the requested configuration.',
      );
    if (
      ![
        sample.canvasWidth,
        sample.canvasHeight,
        sample.displayWidth,
        sample.displayHeight,
        sample.pixelRatio,
        sample.bufferWidth,
        sample.bufferHeight,
      ].every((value) => Number.isFinite(value) && value > 0) ||
      Math.abs(sample.canvasWidth - sample.bufferWidth) > 1 ||
      Math.abs(sample.canvasHeight - sample.bufferHeight) > 1 ||
      // Runtime density metadata has two decimals; the actual buffer keeps
      // the full capped ratio and integer rounding on each axis.
      Math.abs(sample.canvasWidth / sample.displayWidth - sample.pixelRatio) >
        0.0051 + 1 / sample.displayWidth ||
      Math.abs(sample.canvasHeight / sample.displayHeight - sample.pixelRatio) >
        0.0051 + 1 / sample.displayHeight
    )
      reasons.add(
        'Canvas backing-buffer dimensions or render density were missing or inconsistent.',
      );
    if (!sample.quality || !sample.pipeline)
      reasons.add('The runtime quality or render pipeline was missing.');
  }
  const status = reasons.size ? 'fail' : 'pass';
  return {
    status,
    passes: status === 'pass',
    observations: samples.length,
    reasons: [...reasons],
    renderers: [...new Set(samples.map((sample) => sample.renderer))],
    qualities: [...new Set(samples.map((sample) => sample.quality))],
    pipelines: [...new Set(samples.map((sample) => sample.pipeline))],
  };
}

/** Preserve every positive interval inside an active render segment, however long. */
export function summarizeSubmissions(events, { minimumIntervals = 12 } = {}) {
  const intervals = [];
  let previous;
  let segments = 0;
  let skippedCounts = 0;
  for (const event of events) {
    if (!Number.isFinite(event.time) || !Number.isFinite(event.count)) continue;
    if (previous && event.count > previous.count) {
      if (event.rendering === 'active' || event.rendering === 'idle') {
        const interval = event.time - previous.time;
        if (interval > 0) intervals.push(interval);
        skippedCounts += Math.max(0, event.count - previous.count - 1);
      }
    }
    if (event.rendering !== 'active') {
      previous = undefined;
      continue;
    }
    if (!previous) segments += 1;
    if (!previous || event.count > previous.count) previous = event;
  }
  const statistics = cadence(intervals);
  const status =
    intervals.length < minimumIntervals || skippedCounts > 0
      ? 'unavailable'
      : statistics.averageFps >= thresholds.averageFps &&
          statistics.p95FrameMs <= thresholds.p95FrameMs
        ? 'pass'
        : 'fail';
  return {
    status,
    passes: status === 'pass',
    frames: intervals.length + segments,
    activeSegments: segments,
    skippedCounts,
    ...statistics,
    intervals,
    qualities: [
      ...new Set(events.map((event) => event.quality).filter(Boolean)),
    ],
    chapters: [
      ...new Set(events.map((event) => event.chapter).filter(Boolean)),
    ],
    ...(status === 'unavailable'
      ? {
          limitation:
            'Insufficient individually observed active submissions. Idle time is excluded; long active intervals are retained.',
        }
      : {}),
  };
}

function identityFields(value, prefix = '', result = {}) {
  if (!value || typeof value !== 'object') return result;
  for (const [key, entry] of Object.entries(value)) {
    const path = prefix ? `${prefix}.${key}` : key;
    if (/frame_?(token|id)|surface_?id|frame_?sink/i.test(key))
      result[path] = entry;
    else if (entry && typeof entry === 'object')
      identityFields(entry, path, result);
  }
  return result;
}

/**
 * @typedef {object} GpuTraceEvent
 * @property {string} name
 * @property {string} [ph]
 * @property {number} [pid]
 * @property {number} [tid]
 * @property {number} [ts]
 * @property {Record<string, unknown>} [args]
 */

/**
 * Native trace identifiers are inventoried, never equated to DOM renderCount by time proximity.
 * @param {{ traceEvents?: GpuTraceEvent[] }} [trace]
 */
export function assessPresentation({ traceEvents = [] } = {}) {
  const streams = new Map();
  const identities = [];
  for (const event of traceEvents) {
    const fields = identityFields(event.args);
    if (Object.keys(fields).length)
      identities.push({
        name: event.name,
        pid: event.pid,
        tid: event.tid,
        ts: event.ts,
        fields,
      });
    if (
      event.name !== 'Display::FrameDisplayed' ||
      !['I', 'i'].includes(event.ph) ||
      !Number.isFinite(event.ts)
    )
      continue;
    const key = `${event.pid}:${event.tid}`;
    const stream = streams.get(key) ?? {
      pid: event.pid,
      tid: event.tid,
      timestampsUs: [],
    };
    stream.timestampsUs.push(event.ts);
    streams.set(key, stream);
  }
  const diagnosticCallbacks = [...streams.values()].map((stream) => {
    const timestamps = [...new Set(stream.timestampsUs)].sort((a, b) => a - b);
    const intervals = timestamps
      .slice(1)
      .map((time, index) => (time - timestamps[index]) / 1000);
    return {
      name: 'Display::FrameDisplayed',
      pid: stream.pid,
      tid: stream.tid,
      frames: timestamps.length,
      ...cadence(intervals),
    };
  });
  // The site exposes a JS submission counter, but no Chromium frame token or surface ID.
  // Even native FramePresented(frame_token) cannot identify a new court draw without
  // that missing attribution chain. Traced timing also cannot validate untraced gates.
  return {
    status: 'unavailable',
    passes: false,
    reason:
      'No verified frame/surface identity chain connects website WebGL content updates to presented frames. Compositor callbacks and timestamp proximity are diagnostic only.',
    frameIdentityEvents: identities.length,
    frameIdentityExamples: identities.slice(0, 20),
    diagnosticCallbacks,
    physicalScanoutVerified: false,
  };
}

export function combineGates(...gates) {
  if (gates.some((gate) => gate?.status === 'fail')) return 'fail';
  if (!gates.length || gates.some((gate) => gate?.status !== 'pass'))
    return 'unavailable';
  return 'pass';
}
