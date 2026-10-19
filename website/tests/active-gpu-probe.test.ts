import assert from 'node:assert/strict';
import { test } from 'node:test';
import vm from 'node:vm';
import {
  createActiveGpuProbe,
  installActiveGpuProbe,
} from '../scripts/active-gpu-probe.mjs';

function fixture(overrides: Record<string, unknown> = {}) {
  let time = 0;
  let nextQuery = 0;
  let nextTimer = 0;
  let current: any = null;
  let lost = false;
  let disjoint = false;
  let extensionAvailable = true;
  const calls: { method: string; query?: number }[] = [];
  const queries = new Map<
    number,
    { available: boolean; nanoseconds: number }
  >();
  const timers = new Map<number, { callback: () => void; delay: number }>();
  const state: any = {
    phase: 'experience-wheel-entry',
    scene: '3d',
    sceneReady: true,
    visible: true,
    focused: true,
    renderCount: 0,
    quality: 'density',
    pipeline: 'direct',
    pixelRatio: 1.5,
    bufferWidth: 1371,
    bufferHeight: 1485,
  };
  const extension = { TIME_ELAPSED_EXT: 99, GPU_DISJOINT_EXT: 100 };
  const gl: any = {
    CURRENT_QUERY: 101,
    QUERY_RESULT_AVAILABLE: 102,
    QUERY_RESULT: 103,
    getExtension: () => {
      calls.push({ method: 'extension' });
      return extensionAvailable ? extension : null;
    },
    isContextLost: () => lost,
    createQuery: () => {
      const query = { id: ++nextQuery };
      calls.push({ method: 'create', query: query.id });
      queries.set(query.id, { available: false, nanoseconds: 5_250_000 });
      return query;
    },
    getQuery: () => current,
    beginQuery: (_target: number, query: any) => {
      if (current) throw new Error('Nested TIME_ELAPSED query');
      current = query;
      calls.push({ method: 'begin', query: query.id });
    },
    endQuery: () => {
      calls.push({ method: 'end', query: current?.id });
      current = null;
    },
    getParameter: () => disjoint,
    getQueryParameter: (query: any, parameter: number) => {
      calls.push({
        method: parameter === gl.QUERY_RESULT ? 'result' : 'available',
        query: query.id,
      });
      return parameter === gl.QUERY_RESULT
        ? queries.get(query.id)?.nanoseconds
        : queries.get(query.id)?.available;
    },
    deleteQuery: (query: any) => {
      calls.push({ method: 'delete', query: query.id });
    },
  };
  const driver: any = {
    readState: () => ({ ...state }),
    clock: () => time,
    schedule: (callback: () => void, delay: number) => {
      const id = ++nextTimer;
      timers.set(id, { callback, delay });
      return id;
    },
    cancel: (id: number) => {
      timers.delete(id);
    },
    ...overrides,
  };
  const probe: any = createActiveGpuProbe(gl, driver);
  return {
    gl,
    driver,
    probe,
    state,
    calls,
    queries,
    timers,
    draw: (count = 1) => {
      state.renderCount += count;
    },
    advance: (milliseconds: number) => {
      time += milliseconds;
    },
    ready: (nanoseconds = 5_250_000) => {
      // Results become available on a later asynchronous poll, never at t=0.
      time += 16;
      for (const query of queries.values()) {
        query.available = true;
        query.nanoseconds = nanoseconds;
      }
    },
    setForeign: () => {
      current = { id: 999 };
    },
    current: () => current,
    setLost: (value: boolean) => {
      lost = value;
    },
    setDisjoint: (value: boolean) => {
      disjoint = value;
    },
    setExtension: (value: boolean) => {
      extensionAvailable = value;
    },
  };
}

const countCalls = (f: ReturnType<typeof fixture>, method: string) =>
  f.calls.filter((call) => call.method === method).length;

test('GPU query waits for scene readiness and never measures initialization calibration', () => {
  const f = fixture();
  f.state.sceneReady = false;
  f.setForeign();
  f.probe.aroundCallback(() => f.draw())();
  assert.equal(countCalls(f, 'create'), 0);
  assert.equal(countCalls(f, 'end'), 0);
  assert.equal(f.current()?.id, 999);
  assert.equal(f.state.renderCount, 1);
  f.probe.dispose();
});

test('an existing foreign query is left untouched while the real callback still runs', () => {
  const f = fixture();
  f.setForeign();
  f.probe.aroundCallback(() => f.draw())();
  assert.equal(countCalls(f, 'begin'), 0);
  assert.equal(countCalls(f, 'end'), 0);
  assert.equal(countCalls(f, 'delete'), 0);
  assert.equal(f.current()?.id, 999);
  assert.equal(f.probe.snapshot().coverage.foreignQuerySkipped, 1);
  f.probe.dispose();
});

test('a single draw resolves asynchronously with exact callback and GPU metadata', () => {
  const f = fixture();
  const receiver = { id: 'raf-owner' };
  const wrapped = f.probe.aroundCallback(function (
    this: typeof receiver,
    value: number,
  ) {
    assert.equal(this, receiver);
    f.advance(2);
    f.draw();
    return value + 1;
  });
  assert.equal(wrapped.call(receiver, 9), 10);
  assert.equal(countCalls(f, 'end'), 1);
  assert.equal(countCalls(f, 'result'), 0);
  f.probe.poll();
  assert.equal(countCalls(f, 'result'), 0);
  assert.equal(f.probe.snapshot().pendingCount, 1);
  assert.equal([...f.timers.values()][0]?.delay, 16);
  f.ready();
  f.probe.poll();
  const report = f.probe.snapshot();
  assert.equal(report.availability, 'available');
  assert.equal(report.singleDraws.count, 1);
  assert.equal(report.singleDraws.p95GpuMs, 5.25);
  const sample = report.samples.find(
    (sample: any) => sample.outcome === 'single-draw',
  );
  assert.deepEqual(
    {
      phase: sample.phase,
      quality: sample.quality,
      pipeline: sample.pipeline,
      pixelRatio: sample.pixelRatio,
      bufferWidth: sample.bufferWidth,
      bufferHeight: sample.bufferHeight,
    },
    {
      phase: 'experience-wheel-entry',
      quality: 'density',
      pipeline: 'direct',
      pixelRatio: 1.5,
      bufferWidth: 1371,
      bufferHeight: 1485,
    },
  );
  assert.equal(sample.callbackStartedAt, 0);
  assert.equal(sample.callbackEndedAt, 2);
  assert.equal(sample.resolvedAt, 18);
  assert.equal(countCalls(f, 'delete'), 1);
  f.probe.dispose();
  assert.equal(countCalls(f, 'delete'), 1);
});

test('empty callbacks and batched draws cannot become single-draw samples', () => {
  const f = fixture();
  f.probe.aroundCallback(() => {})();
  f.probe.aroundCallback(() => f.draw(2))();
  f.ready(8_000_000);
  f.probe.poll();
  const report = f.probe.snapshot();
  assert.equal(report.coverage.emptyCallbacks, 1);
  assert.equal(report.coverage.batchedCallbacks, 1);
  assert.equal(report.singleDraws.count, 0);
  assert.ok(
    report.samples.some(
      (sample: any) =>
        sample.outcome === 'batched-draws' &&
        sample.drawCount === 2 &&
        sample.gpuMs === 8,
    ),
  );
  assert.equal(countCalls(f, 'delete'), 2);
  f.probe.dispose();
});

test('query ring stays bounded at four without blocking or dropping real draws', () => {
  const f = fixture();
  for (let index = 0; index < 5; index++)
    f.probe.aroundCallback(() => f.draw())();
  assert.equal(f.state.renderCount, 5);
  assert.equal(countCalls(f, 'create'), 4);
  assert.equal(f.probe.snapshot().pendingCount, 4);
  assert.equal(f.probe.snapshot().coverage.pendingOverflowSkipped, 1);
  f.probe.dispose();
  assert.equal(countCalls(f, 'delete'), 4);
  assert.equal(f.timers.size, 0);
});

test('valid GPU samples remain explicitly a subset when the query ring skips real draws', () => {
  const f = fixture();
  for (let index = 0; index < 5; index++)
    f.probe.aroundCallback(() => f.draw())();
  f.ready();
  f.probe.poll();
  const report = f.probe.snapshot();
  assert.equal(report.singleDraws.count, 4);
  assert.equal(report.singleDraws.averageGpuMs, 5.25);
  assert.equal(report.coverage.unmeasuredCallbackDraws, 1);
  assert.equal(report.coverage.pendingOverflowSkipped, 1);
  assert.equal(report.coverage.implausibleElapsedQueries, 0);
  assert.equal(report.singleDraws.validSubsetOnly, true);
  f.probe.dispose();
});

test('timeouts remain invalid evidence and delete each query exactly once', () => {
  const f = fixture();
  f.probe.aroundCallback(() => f.draw())();
  f.advance(1001);
  f.probe.poll();
  f.probe.poll();
  const report = f.probe.snapshot();
  assert.equal(report.pendingCount, 0);
  assert.equal(report.singleDraws.count, 0);
  assert.ok(report.samples.some((sample: any) => sample.reason === 'timeout'));
  assert.equal(countCalls(f, 'result'), 0);
  assert.equal(countCalls(f, 'delete'), 1);
  f.probe.dispose();
});

test('disjoint invalidates the whole pending generation and re-arms only after it clears', () => {
  const f = fixture();
  f.probe.aroundCallback(() => f.draw())();
  f.probe.aroundCallback(() => f.draw())();
  f.setDisjoint(true);
  f.ready();
  f.probe.poll();
  f.probe.aroundCallback(() => f.draw())();
  assert.equal(countCalls(f, 'create'), 2);
  assert.equal(countCalls(f, 'result'), 0);
  assert.equal(countCalls(f, 'delete'), 2);
  assert.equal(
    f.probe
      .snapshot()
      .samples.filter((sample: any) => sample.reason === 'disjoint').length,
    2,
  );
  f.setDisjoint(false);
  f.probe.aroundCallback(() => f.draw())();
  f.ready();
  f.probe.poll();
  assert.equal(f.probe.snapshot().singleDraws.count, 1);
  f.probe.dispose();
});

test('callback exceptions propagate unchanged and the owned query is ended and released in finally', () => {
  const f = fixture();
  const failure = new Error('RAF failed');
  assert.throws(
    f.probe.aroundCallback(() => {
      f.draw();
      throw failure;
    }),
    (error: unknown) => error === failure,
  );
  assert.equal(f.current(), null);
  assert.equal(countCalls(f, 'end'), 1);
  assert.equal(countCalls(f, 'delete'), 1);
  assert.ok(
    f.probe
      .snapshot()
      .samples.some((sample: any) => sample.reason === 'callback-error'),
  );
  f.probe.dispose();
});

test('falsy thrown values still invalidate GPU timing and propagate without replacement', () => {
  for (const failure of [null, undefined, false, 0]) {
    const f = fixture();
    try {
      f.probe.aroundCallback(() => {
        f.draw();
        throw failure;
      })();
      assert.fail('The original callback must throw');
    } catch (caught) {
      assert.equal(caught, failure);
    }
    assert.equal(countCalls(f, 'end'), 1);
    assert.equal(countCalls(f, 'delete'), 1);
    assert.ok(
      f.probe
        .snapshot()
        .samples.some((sample: any) => sample.reason === 'callback-error'),
    );
    f.probe.dispose();
  }
});

test('phase changes, background and focus loss preserve invalidation reasons and cleanup', () => {
  const f = fixture();
  f.probe.aroundCallback(() => f.draw())();
  f.state.phase = 'replay-wheel-entry';
  f.probe.aroundCallback(() => f.draw())();
  f.state.visible = false;
  f.probe.poll();
  f.state.visible = true;
  f.probe.aroundCallback(() => f.draw())();
  f.state.focused = false;
  f.probe.poll();
  const reasons = f.probe
    .snapshot()
    .samples.map((sample: any) => sample.reason);
  assert.ok(reasons.includes('phase-change'));
  assert.ok(reasons.includes('background'));
  assert.ok(reasons.includes('focus-loss'));
  assert.equal(countCalls(f, 'delete'), 3);
  f.probe.dispose();
});

test('context loss abandons invalid handles without GL calls and restore starts a fresh generation', () => {
  const f = fixture();
  f.probe.aroundCallback(() => f.draw())();
  f.setLost(true);
  f.probe.suspend('context-lost');
  const callsAtLoss = f.calls.length;
  f.probe.poll();
  f.probe.aroundCallback(() => f.draw())();
  assert.equal(f.calls.length, callsAtLoss);
  assert.equal(f.probe.snapshot().pendingCount, 0);
  assert.ok(
    f.probe
      .snapshot()
      .samples.some((sample: any) => sample.reason === 'context-lost'),
  );
  f.setLost(false);
  f.probe.contextRestored();
  f.probe.aroundCallback(() => f.draw())();
  f.ready();
  f.probe.poll();
  assert.equal(f.probe.snapshot().singleDraws.count, 1);
  assert.equal(countCalls(f, 'extension'), 2);
  f.probe.dispose();
});

test('abort is idempotent, removes timers and leaves later callbacks uninstrumented', () => {
  const controller = new AbortController();
  const f = fixture({ signal: controller.signal });
  f.probe.aroundCallback(() => f.draw())();
  controller.abort();
  f.probe.dispose();
  f.probe.aroundCallback(() => f.draw())();
  assert.equal(f.state.renderCount, 2);
  assert.equal(countCalls(f, 'create'), 1);
  assert.equal(countCalls(f, 'delete'), 1);
  assert.equal(f.timers.size, 0);
  assert.equal(f.probe.snapshot().disposed, true);
});

test('draws outside wrapped callbacks remain explicit coverage gaps', () => {
  const f = fixture();
  f.probe.aroundCallback(() => f.draw())();
  f.draw(2);
  f.ready();
  f.probe.poll();
  const report = f.probe.snapshot();
  assert.equal(report.coverage.outsideCallbackDraws, 2);
  assert.equal(report.singleDraws.count, 1);
  assert.ok(
    report.samples.some(
      (sample: any) =>
        sample.reason === 'outside-wrapped-callback' && sample.drawCount === 2,
    ),
  );
  f.probe.dispose();
});

test('missing extensions and invalid GPU results never fabricate successful timing', () => {
  for (const value of [0, -1, Number.NaN, Number.POSITIVE_INFINITY]) {
    const f = fixture();
    f.probe.aroundCallback(() => f.draw())();
    f.ready(value);
    f.probe.poll();
    assert.equal(f.probe.snapshot().singleDraws.count, 0);
    assert.ok(
      f.probe
        .snapshot()
        .samples.some((sample: any) => sample.reason === 'implausible-elapsed'),
    );
    assert.equal(countCalls(f, 'delete'), 1);
    f.probe.dispose();
  }
  const f = fixture();
  f.probe.dispose();
  f.setExtension(false);
  const missing: any = createActiveGpuProbe(f.gl, f.driver);
  missing.aroundCallback(() => f.draw())();
  assert.equal(missing.snapshot().availability, 'unavailable');
  assert.equal(countCalls(f, 'create'), 0);
  missing.dispose();
});

test('an impossible positive GPU elapsed value preserves raw timing and invalidates the entire phase', () => {
  const f = fixture();
  f.probe.aroundCallback(() => f.draw())();
  f.ready(5_000_000);
  f.probe.poll();
  assert.equal(f.probe.snapshot().singleDraws.count, 1);
  f.probe.aroundCallback(() => f.draw())();
  f.ready(184_467_910_177);
  f.probe.poll();
  const report = f.probe.snapshot();
  assert.equal(report.availability, 'unavailable');
  assert.equal(report.singleDraws.count, 1);
  assert.equal(report.singleDraws.averageGpuMs, 5);
  const anomaly = report.samples.find(
    (sample: any) => sample.reason === 'implausible-elapsed',
  );
  assert.ok(anomaly);
  assert.equal(anomaly.rawGpuMs, 184467.910177);
  assert.equal(anomaly.queryLifetimeMs, 16);
  assert.equal(anomaly.gpuMs, null);
  assert.equal(report.coverage.implausibleElapsedQueries, 1);
  assert.equal(countCalls(f, 'delete'), 2);
  f.probe.dispose();
});

test('elapsed-time validation uses exactly the measured query lifetime plus 2ms tolerance', () => {
  for (const [milliseconds, accepted] of [
    [18, true],
    [18.001, false],
  ] as const) {
    const f = fixture();
    f.probe.aroundCallback(() => f.draw())();
    f.ready(milliseconds * 1e6);
    f.probe.poll();
    const report = f.probe.snapshot();
    assert.equal(report.singleDraws.count, accepted ? 1 : 0);
    assert.equal(report.availability, accepted ? 'available' : 'unavailable');
    if (!accepted) {
      const sample = report.samples.find(
        (entry: any) => entry.reason === 'implausible-elapsed',
      );
      assert.equal(sample.rawGpuMs, milliseconds);
      assert.equal(sample.queryLifetimeMs, 16);
    }
    f.probe.dispose();
  }
});

test('probe result-reading failures are recorded without throwing into the page', () => {
  const f = fixture();
  f.probe.aroundCallback(() => f.draw())();
  f.gl.getQueryParameter = () => {
    throw new Error('Context query rejected');
  };
  assert.doesNotThrow(() => f.probe.poll());
  assert.equal(f.probe.snapshot().singleDraws.count, 0);
  assert.ok(
    f.probe
      .snapshot()
      .samples.some((sample: any) => sample.reason === 'query-error'),
  );
  assert.equal(countCalls(f, 'delete'), 1);
  f.probe.dispose();
});

test('browser installer is closure-free and restores original RAF and context interception', () => {
  const f = fixture();
  f.probe.dispose();
  const callbacks = new Map<number, (time: number) => void>();
  let nextRaf = 0;
  const listeners = new Map<string, Function>();
  const canvasListeners = new Map<string, Function>();
  let contextsRequested = 0;
  class FakeCanvas {
    id = 'court-canvas';
    dataset: any = {
      sceneReady: 'true',
      renderCount: '0',
      quality: 'density',
      pipeline: 'direct',
      pixelRatio: '1.50',
      bufferWidth: '1371',
      bufferHeight: '1485',
    };
    getContext(_type?: string) {
      contextsRequested++;
      return f.gl;
    }
    addEventListener(name: string, callback: Function) {
      canvasListeners.set(name, callback);
    }
    removeEventListener(name: string) {
      canvasListeners.delete(name);
    }
  }
  const canvas = new FakeCanvas();
  const originalContext = FakeCanvas.prototype.getContext;
  const originalRaf = (callback: (time: number) => void) => {
    const id = ++nextRaf;
    callbacks.set(id, callback);
    return id;
  };
  const environment: any = {
    HTMLCanvasElement: FakeCanvas,
    requestAnimationFrame: originalRaf,
    cancelAnimationFrame: (id: number) => {
      callbacks.delete(id);
    },
    setTimeout: f.driver.schedule,
    clearTimeout: f.driver.cancel,
    performance: { now: f.driver.clock },
    document: {
      getElementById: () => canvas,
      documentElement: { dataset: { scene: '3d' } },
      hidden: false,
      visibilityState: 'visible',
      hasFocus: () => true,
      addEventListener: (name: string, callback: Function) =>
        listeners.set(name, callback),
      removeEventListener: (name: string) => listeners.delete(name),
    },
    addEventListener: (name: string, callback: Function) =>
      listeners.set(name, callback),
    removeEventListener: (name: string) => listeners.delete(name),
    hoopitoGpuEvidence: { phase: 'experience-wheel-entry' },
  };
  environment.window = environment;
  vm.runInNewContext(`(${installActiveGpuProbe.toString()})({});`, environment);
  assert.equal(canvas.getContext('webgl2'), f.gl);
  assert.equal(contextsRequested, 1);
  const id = environment.requestAnimationFrame(() => {
    canvas.dataset.renderCount = '1';
  });
  callbacks.get(id)?.(16);
  f.ready();
  environment.__hoopitoActiveGpuProbe.poll();
  assert.equal(
    environment.__hoopitoActiveGpuProbe.snapshot().singleDraws.count,
    1,
  );
  assert.equal(contextsRequested, 1);
  environment.__hoopitoActiveGpuProbe.dispose();
  assert.equal(environment.requestAnimationFrame, originalRaf);
  assert.equal(FakeCanvas.prototype.getContext, originalContext);
  assert.equal(listeners.size, 0);
  assert.equal(canvasListeners.size, 0);
  assert.equal(f.timers.size, 0);
});
