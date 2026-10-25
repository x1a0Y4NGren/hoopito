/**
 * Development-only, closure-free injection. The test adapter uses the same core.
 * @param {any} options
 * @param {any} [testing]
 * @returns {any}
 */
export function installActiveGpuProbe(options = {}, testing = null) {
  function createCore(gl, driver) {
    const readState = driver.readState;
    const clock = driver.clock ?? (() => performance.now());
    const schedule =
      driver.schedule ?? ((callback, delay) => setTimeout(callback, delay));
    const cancel = driver.cancel ?? ((id) => clearTimeout(id));
    const maxPending = driver.maxPending ?? 4;
    const pollMs = driver.pollMs ?? 16;
    const timeoutMs = driver.timeoutMs ?? 1000;
    const maxSamples = driver.maxSamples ?? 10000;
    const samples = [];
    const pending = [];
    const coverage = {
      callbacks: 0,
      eligibleCallbacks: 0,
      emptyCallbacks: 0,
      batchedCallbacks: 0,
      foreignQuerySkipped: 0,
      pendingOverflowSkipped: 0,
      unmeasuredCallbackDraws: 0,
      outsideCallbackDraws: 0,
      recordsDropped: 0,
      abandonedContextQueries: 0,
      implausibleElapsedQueries: 0,
    };
    let disposed = false;
    let lost = false;
    let generation = 0;
    let extension = null;
    let active = null;
    let timer = null;
    let phase = null;
    let lastCount = null;
    let disjointLatched = false;
    const safeState = () => {
      try {
        return readState() ?? {};
      } catch {
        return {};
      }
    };
    const readExtension = () => {
      try {
        return gl.getExtension('EXT_disjoint_timer_query_webgl2');
      } catch {
        return null;
      }
    };
    extension = readExtension();
    const initial = safeState();
    lastCount = Number.isFinite(initial.renderCount)
      ? initial.renderCount
      : null;
    phase = initial.phase ?? null;
    const eligible = (state) =>
      Boolean(
        state.phase &&
        state.scene === '3d' &&
        state.sceneReady === true &&
        state.visible === true &&
        state.focused === true &&
        Number.isFinite(state.renderCount),
      );
    const metadata = (state) => ({
      phase: state.phase ?? null,
      generation,
      quality: state.quality ?? null,
      pipeline: state.pipeline ?? null,
      pixelRatio: state.pixelRatio ?? null,
      bufferWidth: state.bufferWidth ?? null,
      bufferHeight: state.bufferHeight ?? null,
    });
    function append(sample) {
      if (samples.length < maxSamples) samples.push(sample);
      else coverage.recordsDropped += 1;
    }
    function record(item, outcome, reason = null, extra = {}) {
      if (item.recorded) return;
      item.recorded = true;
      if (reason === 'implausible-elapsed')
        coverage.implausibleElapsedQueries += 1;
      append({
        ...item.metadata,
        callbackStartedAt: item.startedAt,
        callbackEndedAt: item.endedAt ?? null,
        submissionBefore: item.before,
        submissionAfter: item.after ?? null,
        drawCount: item.drawCount ?? null,
        gpuMs: null,
        outcome,
        reason,
        ...extra,
      });
    }
    function clearPoll() {
      if (timer !== null) cancel(timer);
      timer = null;
    }
    function contextIsLost() {
      if (lost) return true;
      try {
        return gl.isContextLost();
      } catch {
        return true;
      }
    }
    function release(item) {
      if (item.deleted || !item.query) return;
      item.deleted = true;
      if (contextIsLost()) {
        coverage.abandonedContextQueries += 1;
        return;
      }
      try {
        gl.deleteQuery(item.query);
      } catch {
        /* A lost/deleted diagnostic handle cannot break the page. */
      }
    }
    function endOwned(item) {
      if (item.ended || !item.query) return true;
      item.ended = true;
      if (contextIsLost()) return false;
      try {
        if (
          gl.getQuery(extension.TIME_ELAPSED_EXT, gl.CURRENT_QUERY) !==
          item.query
        )
          return false;
        gl.endQuery(extension.TIME_ELAPSED_EXT);
        return true;
      } catch {
        return false;
      }
    }
    function invalidate(reason) {
      clearPoll();
      for (const item of pending.splice(0)) {
        record(item, 'invalid', reason);
        release(item);
      }
      if (active && !active.recorded) {
        endOwned(active);
        record(active, 'invalid', reason);
        release(active);
      }
    }
    function suspend(reason) {
      if (reason === 'context-lost') lost = true;
      invalidate(reason);
      generation += 1;
    }
    function observeGap(state) {
      if (
        eligible(state) &&
        Number.isFinite(lastCount) &&
        state.renderCount > lastCount
      ) {
        const drawCount = state.renderCount - lastCount;
        coverage.outsideCallbackDraws += drawCount;
        append({
          ...metadata(state),
          outcome: 'coverage-gap',
          reason: 'outside-wrapped-callback',
          drawCount,
          submissionBefore: lastCount,
          submissionAfter: state.renderCount,
          observedAt: clock(),
          gpuMs: null,
        });
      }
      lastCount = Number.isFinite(state.renderCount) ? state.renderCount : null;
    }
    function synchronize(state) {
      if (disposed || lost) return false;
      if (contextIsLost()) {
        suspend('context-lost');
        return false;
      }
      if ((state.phase ?? null) !== phase) {
        suspend('phase-change');
        phase = state.phase ?? null;
      }
      const reason =
        state.visible !== true
          ? 'background'
          : state.focused !== true
            ? 'focus-loss'
            : !state.phase
              ? 'phase-inactive'
              : !state.sceneReady || state.scene !== '3d'
                ? 'scene-not-ready'
                : null;
      if (reason) {
        if (pending.length || active) suspend(reason);
        return false;
      }
      if (!eligible(state) || !extension) return false;
      try {
        if (gl.getParameter(extension.GPU_DISJOINT_EXT)) {
          if (!disjointLatched) {
            suspend('disjoint');
            disjointLatched = true;
          }
          return false;
        }
      } catch {
        invalidate('query-error');
        return false;
      }
      if (disjointLatched) {
        disjointLatched = false;
        generation += 1;
      }
      return true;
    }
    function armPoll() {
      if (!disposed && !lost && pending.length && timer === null) {
        timer = schedule(() => {
          timer = null;
          poll();
        }, pollMs);
      }
    }
    function poll() {
      clearPoll();
      if (disposed || lost) return;
      const state = safeState();
      observeGap(state);
      if (!synchronize(state)) return;
      for (const item of [...pending]) {
        let finished = false;
        try {
          if (clock() - item.startedAt >= timeoutMs) {
            record(item, 'invalid', 'timeout');
            finished = true;
          } else if (
            gl.getQueryParameter(item.query, gl.QUERY_RESULT_AVAILABLE)
          ) {
            const gpuMs =
              Number(gl.getQueryParameter(item.query, gl.QUERY_RESULT)) / 1e6;
            const resolvedAt = clock();
            const queryLifetimeMs = resolvedAt - item.startedAt;
            const timing = {
              rawGpuMs: Number.isFinite(gpuMs) ? gpuMs : String(gpuMs),
              queryLifetimeMs,
              resolvedAt,
            };
            if (
              !Number.isFinite(gpuMs) ||
              gpuMs <= 0 ||
              !Number.isFinite(queryLifetimeMs) ||
              queryLifetimeMs < 0 ||
              gpuMs > queryLifetimeMs + 2
            )
              record(item, 'invalid', 'implausible-elapsed', timing);
            else
              record(
                item,
                item.drawCount === 1 ? 'single-draw' : 'batched-draws',
                null,
                { ...timing, gpuMs },
              );
            finished = true;
          }
        } catch {
          record(item, 'invalid', 'query-error');
          finished = true;
        }
        if (finished) {
          pending.splice(pending.indexOf(item), 1);
          release(item);
        }
      }
      armPoll();
    }
    function aroundCallback(callback) {
      return function (...args) {
        if (disposed) return callback.apply(this, args);
        coverage.callbacks += 1;
        const before = safeState();
        observeGap(before);
        let item = null;
        let skip = null;
        const canMeasure = synchronize(before);
        if (canMeasure) {
          coverage.eligibleCallbacks += 1;
          if (active) skip = 'nested-callback';
          else if (pending.length >= maxPending) {
            skip = 'pending-overflow';
            coverage.pendingOverflowSkipped += 1;
          } else {
            try {
              if (gl.getQuery(extension.TIME_ELAPSED_EXT, gl.CURRENT_QUERY)) {
                skip = 'foreign-query';
                coverage.foreignQuerySkipped += 1;
              } else {
                const query = gl.createQuery();
                if (!query) skip = 'query-unavailable';
                else {
                  item = {
                    query,
                    metadata: metadata(before),
                    before: before.renderCount,
                    startedAt: clock(),
                    endedAt: /** @type {number | null} */ (null),
                    ended: false,
                    deleted: false,
                    recorded: false,
                  };
                  gl.beginQuery(extension.TIME_ELAPSED_EXT, query);
                  active = item;
                }
              }
            } catch {
              if (item) {
                release(item);
                item = null;
              }
              skip = 'query-error';
            }
          }
        }
        let failure = null;
        let callbackThrew = false;
        try {
          return callback.apply(this, args);
        } catch (error) {
          callbackThrew = true;
          failure = error;
          throw error;
        } finally {
          const after = safeState();
          const drawCount =
            Number.isFinite(after.renderCount) &&
            Number.isFinite(before.renderCount)
              ? after.renderCount - before.renderCount
              : null;
          lastCount = Number.isFinite(after.renderCount)
            ? after.renderCount
            : null;
          if (item) {
            item.endedAt = clock();
            item.after = after.renderCount;
            item.drawCount = drawCount;
            const ended = endOwned(item);
            if (active === item) active = null;
            if (!item.recorded) {
              if (callbackThrew) {
                record(item, 'invalid', 'callback-error', {
                  error: failure?.message ?? String(failure),
                });
                release(item);
              } else if (!ended) {
                record(
                  item,
                  'invalid',
                  lost ? 'context-lost' : 'query-end-failed',
                );
                release(item);
              } else if (
                !synchronize(after) ||
                (before.phase ?? null) !== (after.phase ?? null)
              ) {
                record(item, 'invalid', 'state-changed-during-callback');
                release(item);
              } else if (drawCount === 0) {
                coverage.emptyCallbacks += 1;
                release(item);
              } else if (!Number.isFinite(drawCount) || drawCount < 0) {
                record(item, 'invalid', 'submission-counter-reset');
                release(item);
              } else {
                if (drawCount > 1) coverage.batchedCallbacks += 1;
                pending.push(item);
                armPoll();
              }
            }
          } else if (
            Number.isFinite(drawCount) &&
            drawCount > 0 &&
            eligible(before)
          ) {
            coverage.unmeasuredCallbackDraws += drawCount;
            append({
              ...metadata(before),
              outcome: 'coverage-gap',
              reason: skip ?? 'not-eligible',
              drawCount,
              submissionBefore: before.renderCount,
              submissionAfter: after.renderCount,
              observedAt: clock(),
              gpuMs: null,
            });
          }
        }
      };
    }
    function contextRestored() {
      if (disposed) return;
      invalidate('context-restored');
      lost = false;
      generation += 1;
      extension = readExtension();
      disjointLatched = false;
      const state = safeState();
      lastCount = Number.isFinite(state.renderCount) ? state.renderCount : null;
    }
    function dispose(reason = 'disposed') {
      if (disposed) return snapshot();
      disposed = true;
      invalidate(reason);
      driver.signal?.removeEventListener('abort', abort);
      return snapshot();
    }
    function snapshot() {
      const values = samples
        .filter((sample) => sample.outcome === 'single-draw')
        .map((sample) => sample.gpuMs)
        .sort((a, b) => a - b);
      return JSON.parse(
        JSON.stringify({
          kind: 'active-gpu-diagnostic',
          acceptance: 'diagnostic-only',
          scope:
            'GPU elapsed interval around one RAF callback with exactly one existing renderCount advance; not presentation or physical FPS.',
          availability:
            values.length && !coverage.implausibleElapsedQueries
              ? 'available'
              : 'unavailable',
          reason: coverage.implausibleElapsedQueries
            ? 'Implausible GPU elapsed results invalidate this diagnostic phase; valid-subset statistics cannot describe the complete phase.'
            : values.length
              ? null
              : 'No valid single-draw GPU timing samples.',
          extensionAvailable: Boolean(extension),
          disposed,
          generation,
          pendingCount: pending.length,
          configuration: {
            maxPending,
            pollMs,
            timeoutMs,
            maxSamples,
            elapsedToleranceMs: 2,
          },
          singleDraws: {
            validSubsetOnly: true,
            scope:
              'Resolved valid single-draw RAF intervals only. Skipped, invalid, batched and unattributed draws are excluded; these statistics do not establish whole-phase GPU coverage or frame presentation.',
            count: values.length,
            averageGpuMs: values.length
              ? values.reduce((sum, value) => sum + value, 0) / values.length
              : null,
            p95GpuMs: values.length
              ? values[Math.ceil(values.length * 0.95) - 1]
              : null,
            maxGpuMs: values.at(-1) ?? null,
          },
          coverage,
          samples,
        }),
      );
    }
    const abort = () => dispose('abort');
    driver.signal?.addEventListener('abort', abort, { once: true });
    if (driver.signal?.aborted) dispose('abort');
    return {
      aroundCallback,
      poll,
      suspend,
      contextRestored,
      dispose,
      snapshot,
    };
  }

  if (testing) return createCore(testing.gl, testing);
  const target = window;
  const canvasId = options.canvasId ?? 'court-canvas';
  const evidenceKey = options.evidenceKey ?? 'hoopitoGpuEvidence';
  const globalKey = options.globalKey ?? '__hoopitoActiveGpuProbe';
  if (target[globalKey]) return target[globalKey];
  const originalGetContext = HTMLCanvasElement.prototype.getContext;
  const originalRaf = target.requestAnimationFrame;
  let core = null;
  let canvas = null;
  let disposed = false;
  const readState = () => ({
    phase: target[evidenceKey]?.phase ?? null,
    scene: document.documentElement.dataset.scene,
    sceneReady: canvas?.dataset.sceneReady === 'true',
    visible: !document.hidden && document.visibilityState === 'visible',
    focused: document.hasFocus(),
    renderCount: Number(canvas?.dataset.renderCount),
    quality: canvas?.dataset.quality,
    pipeline: canvas?.dataset.pipeline,
    pixelRatio: Number(canvas?.dataset.pixelRatio),
    bufferWidth: Number(canvas?.dataset.bufferWidth),
    bufferHeight: Number(canvas?.dataset.bufferHeight),
  });
  const onContextLost = () => core?.suspend('context-lost');
  const onContextRestored = () => core?.contextRestored();
  const onVisibility = () => {
    if (document.hidden) core?.suspend('background');
  };
  const onBlur = () => core?.suspend('focus-loss');
  const onPageHide = () => controller.dispose('pagehide');
  function interceptedGetContext(...args) {
    const context = originalGetContext.apply(this, args);
    if (
      !disposed &&
      !core &&
      this.id === canvasId &&
      args[0] === 'webgl2' &&
      context
    ) {
      canvas = this;
      core = createCore(context, { ...options, readState });
      canvas.addEventListener('webglcontextlost', onContextLost);
      canvas.addEventListener('webglcontextrestored', onContextRestored);
    }
    return context;
  }
  function interceptedRaf(callback) {
    // Core is selected at execution time: RAFs may have been queued before WebGL creation.
    return originalRaf.call(target, function (...args) {
      return core && !disposed
        ? core.aroundCallback(callback).apply(this, args)
        : callback.apply(this, args);
    });
  }
  const controller = {
    snapshot: () =>
      core
        ? core.snapshot()
        : {
            kind: 'active-gpu-diagnostic',
            acceptance: 'diagnostic-only',
            availability: 'unavailable',
            reason: 'The existing court WebGL2 context has not been observed.',
            disposed,
            pendingCount: 0,
            samples: [],
            coverage: {},
          },
    poll: () => core?.poll(),
    dispose(reason = 'disposed') {
      if (!disposed) {
        disposed = true;
        core?.dispose(reason);
        if (target.requestAnimationFrame === interceptedRaf)
          target.requestAnimationFrame = originalRaf;
        if (HTMLCanvasElement.prototype.getContext === interceptedGetContext)
          HTMLCanvasElement.prototype.getContext = originalGetContext;
        canvas?.removeEventListener('webglcontextlost', onContextLost);
        canvas?.removeEventListener('webglcontextrestored', onContextRestored);
        document.removeEventListener('visibilitychange', onVisibility);
        target.removeEventListener('blur', onBlur);
        target.removeEventListener('pagehide', onPageHide);
      }
      return controller.snapshot();
    },
  };
  target[globalKey] = controller;
  HTMLCanvasElement.prototype.getContext = interceptedGetContext;
  target.requestAnimationFrame = interceptedRaf;
  document.addEventListener('visibilitychange', onVisibility);
  target.addEventListener('blur', onBlur);
  target.addEventListener('pagehide', onPageHide);
  return controller;
}

/**
 * CPU-test adapter to the exact core nested in the serializable browser installer.
 * @param {any} gl
 * @param {any} options
 * @returns {any}
 */
export function createActiveGpuProbe(gl, options = {}) {
  return installActiveGpuProbe({}, { ...options, gl });
}
