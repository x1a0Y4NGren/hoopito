export const WHEEL_WORKLOAD_VERSION = 'native-wheel-snap-v2';

function plainEvidence(value, ancestors = new Set()) {
  if (value === null || typeof value === 'string' || typeof value === 'boolean')
    return value;
  if (typeof value === 'number') return Number.isFinite(value) ? value : null;
  if (typeof value !== 'object' || value instanceof Error) return undefined;
  if (ancestors.has(value)) return null;
  if (
    !Array.isArray(value) &&
    ![Object.prototype, null].includes(Object.getPrototypeOf(value))
  )
    return undefined;
  ancestors.add(value);
  const result = Array.isArray(value)
    ? value.map((entry) => plainEvidence(entry, ancestors) ?? null)
    : Object.fromEntries(
        Object.entries(value)
          .map(([key, entry]) => [key, plainEvidence(entry, ancestors)])
          .filter(([, entry]) => entry !== undefined),
      );
  ancestors.delete(value);
  return result;
}

/**
 * Preserve failed input evidence as detached JSON data, never exception objects.
 * @param {*} failure
 * @param {ReturnType<typeof createWheelWorkload> | null} [workload]
 */
export function serializeMeasurementFailure(failure, workload = null) {
  const error =
    typeof failure?.message === 'string' ? failure.message : String(failure);
  const original = plainEvidence(failure?.evidence);
  const evidence =
    original && !Array.isArray(original) && typeof original === 'object'
      ? original
      : null;
  if (!evidence && !workload) return { error, errorEvidence: null };
  return {
    error,
    errorEvidence: {
      ...(workload
        ? {
            phase: workload.phase,
            workloadVersion: workload.workloadVersion,
            inputMethod: workload.inputMethod,
            inputSequence: plainEvidence(workload.inputSequence),
            emitted: [],
            start: null,
            end: null,
          }
        : {}),
      ...evidence,
      completed: false,
    },
  };
}

/** Derive an identical, bounded input schedule from this build's actual layout. */
export function createWheelWorkload(phase, layout, viewportHeight) {
  const chapter =
    phase === 'experience-wheel-entry'
      ? 'experience'
      : phase === 'replay-wheel-entry'
        ? 'replay'
        : phase === 'reverse-wheel'
          ? 'hero'
          : null;
  if (!chapter) throw new Error(`Unknown wheel workload: ${phase}`);
  const reverse = phase === 'reverse-wheel';
  const hasReadingMetadata = Object.values(layout ?? {}).some(
    (geometry) =>
      geometry?.readStart !== undefined || geometry?.readEnd !== undefined,
  );
  if (hasReadingMetadata) {
    // A gesture now commits one adjacent stop. Its intent deltas are deliberately
    // independent of physical travel; the production controller supplies the rest.
    const sourceChapter =
      phase === 'replay-wheel-entry' ? 'experience' : 'scoring';
    const source = layout[sourceChapter];
    const target = layout[chapter];
    if (
      ![
        source?.readStart,
        source?.readEnd,
        target?.readStart,
        target?.readEnd,
        viewportHeight,
      ].every(Number.isFinite) ||
      viewportHeight <= 0 ||
      source.readStart < 0 ||
      target.readStart < 0 ||
      source.readEnd < source.readStart ||
      target.readEnd < target.readStart
    )
      throw new Error('Wheel workload requires finite reading geometry.');
    const startY = reverse ? source.readStart : source.readEnd;
    const targetY = reverse ? target.readEnd : target.readStart;
    if ((reverse && targetY >= startY) || (!reverse && targetY <= startY))
      throw new Error('Wheel workload has an invalid travel direction.');
    const inputSequence = [20, 18, 14, 10, 8, 6, 4, 3, 2, 1].map(
      (delta, index) => ({
        atMs: index * 40,
        deltaX: 0,
        deltaY: reverse ? -delta : delta,
      }),
    );
    return {
      workloadVersion: WHEEL_WORKLOAD_VERSION,
      phase,
      inputMethod: 'page.mouse.wheel',
      startY,
      targetY,
      targetChapter: chapter,
      durationMs: inputSequence.at(-1).atMs,
      inputSequence,
    };
  }
  const geometry = reverse
    ? [layout.replay?.anchor, layout.hero?.anchor, viewportHeight]
    : [layout[chapter]?.stageTop, layout[chapter]?.anchor, viewportHeight];
  if (!geometry.every(Number.isFinite) || viewportHeight <= 0)
    throw new Error('Wheel workload requires finite chapter geometry.');
  // Preparation ends before the camera/card arrival begins at top 85%.
  const startY = reverse
    ? layout.replay.anchor
    : Math.max(0, layout[chapter].stageTop - viewportHeight * 0.95);
  const targetY = layout[chapter].anchor;
  const distance = targetY - startY;
  if ((reverse && distance >= 0) || (!reverse && distance <= 0))
    throw new Error('Wheel workload has an invalid travel direction.');
  const count = 60;
  const cadenceMs = 40;
  const ease = (value) => 0.5 - Math.cos(Math.PI * value) / 2;
  const inputSequence = Array.from({ length: count }, (_, index) => ({
    atMs: index * cadenceMs,
    deltaX: 0,
    deltaY: distance * (ease((index + 1) / count) - ease(index / count)),
  }));
  return {
    workloadVersion: 'native-wheel-v1',
    phase,
    inputMethod: 'page.mouse.wheel',
    startY,
    targetY,
    targetChapter: chapter,
    durationMs: (count - 1) * cadenceMs,
    inputSequence,
  };
}

/** The injected driver has no DOM-scrolling capability: only real wheel input. */
export async function runWheelInput(
  workload,
  driver,
  { maximumMs = workload.durationMs + 2500 } = {},
) {
  const startedAt = driver.now();
  const deadline = startedAt + maximumMs;
  /** @type {{
   * workloadVersion: string,
   * inputMethod: string,
   * inputSequence: {atMs: number, deltaX: number, deltaY: number}[],
   * completed: boolean,
   * start: {scrollY: number, time: number} | null,
   * end: {scrollY: number, time: number} | null,
   * emitted: {atMs: number, deltaX: number, deltaY: number, dispatchedAtMs: number, completedAtMs: number | null, error?: string}[],
   * elapsedMs?: number
   * }} */
  const evidence = {
    workloadVersion: workload.workloadVersion,
    inputMethod: workload.inputMethod,
    inputSequence: workload.inputSequence,
    completed: false,
    start: null,
    end: null,
    emitted: [],
  };
  const bounded = async (operation) => {
    const remaining = deadline - driver.now();
    if (remaining <= 0) throw new Error('Wheel input schedule timed out.');
    let timer;
    try {
      return await Promise.race([
        operation(),
        new Promise((_, reject) => {
          timer = setTimeout(
            () => reject(new Error('Wheel input schedule timed out.')),
            remaining,
          );
        }),
      ]);
    } finally {
      clearTimeout(timer);
    }
  };
  try {
    evidence.start = await bounded(driver.readPosition);
    if (Math.abs(evidence.start.scrollY - workload.startY) > 4)
      throw new Error(
        'Wheel input preparation did not reach its start position.',
      );
    for (const input of workload.inputSequence) {
      const delay = startedAt + input.atMs - driver.now();
      if (delay > 0) await bounded(() => driver.wait(delay));
      if (driver.now() >= deadline)
        throw new Error('Wheel input schedule timed out.');
      const event = {
        ...input,
        dispatchedAtMs: driver.now() - startedAt,
        completedAtMs: null,
      };
      evidence.emitted.push(event);
      try {
        await bounded(() => driver.wheel(input.deltaX, input.deltaY));
        event.completedAtMs = driver.now() - startedAt;
      } catch (error) {
        event.error = error.message;
        throw error;
      }
    }
    evidence.end = await bounded(driver.readPosition);
    evidence.elapsedMs = driver.now() - startedAt;
    evidence.completed = true;
    return evidence;
  } catch (cause) {
    evidence.elapsedMs = driver.now() - startedAt;
    const failure = new Error(cause.message, { cause });
    failure.evidence = evidence;
    throw failure;
  }
}
