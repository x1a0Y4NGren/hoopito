import {
  getReplayMomentPresentation,
  getReplayPlotPoint,
  getReplayState,
  replayExample,
  replayPlotBounds,
  type ReplayKeyMomentId,
} from '../data/replay-example';

/** Prepare only the approaching desktop cards; never gate their scroll playhead. */
function prepareReplayImages(stage: HTMLElement) {
  let disposed = false;
  let idle: number | undefined;
  let timer: ReturnType<typeof setTimeout> | undefined;
  const prepare = () => {
    if (disposed) return;
    for (const image of stage.querySelectorAll<HTMLImageElement>(
      '[data-replay-device] img',
    )) {
      image.loading = 'eager';
      // A failed decode leaves the normal image/link fallback intact.
      void image.decode().catch(() => {});
    }
  };
  const observer = new IntersectionObserver(
    (entries) => {
      if (!entries.some((entry) => entry.isIntersecting)) return;
      observer.disconnect();
      if (typeof window.requestIdleCallback === 'function')
        idle = window.requestIdleCallback(prepare, { timeout: 250 });
      else timer = setTimeout(prepare, 0);
    },
    { rootMargin: `${window.innerHeight}px 0px` },
  );
  observer.observe(stage);
  return () => {
    disposed = true;
    observer.disconnect();
    if (idle !== undefined) window.cancelIdleCallback(idle);
    clearTimeout(timer);
  };
}

/** One shared approach-to-landing clock for the card faces and the score story. */
export function createReplayPresentation(stage: HTMLElement) {
  const cancelImagePreparation = prepareReplayImages(stage);
  const clip = stage.querySelector<SVGRectElement>('[data-replay-clip]')!;
  const cursor = stage.querySelector<SVGGElement>('[data-replay-cursor]')!;
  const blueDot = stage.querySelector<SVGCircleElement>(
    '[data-replay-blue-dot]',
  )!;
  const redDot = stage.querySelector<SVGCircleElement>(
    '[data-replay-red-dot]',
  )!;
  const blue = stage.querySelector<HTMLElement>('[data-replay-blue]')!;
  const red = stage.querySelector<HTMLElement>('[data-replay-red]')!;
  const event = stage.querySelector<HTMLElement>('[data-replay-event]')!;
  const moments = [
    ...stage.querySelectorAll<HTMLElement>('[data-replay-moment]'),
  ];
  let previousPoint = -1;

  function drawGraph(progress: number) {
    const state = getReplayState(progress);
    const plot = getReplayPlotPoint(state);
    const width = String(
      1 +
        (replayPlotBounds.xMax - replayPlotBounds.xMin) * state.progress +
        (state.progress === 1 ? 5 : 0),
    );
    const transform = `translate(${plot.x} 0)`;
    if (clip.getAttribute('width') !== width) clip.setAttribute('width', width);
    if (cursor.getAttribute('transform') !== transform)
      cursor.setAttribute('transform', transform);
    if (state.pointIndex !== previousPoint) {
      previousPoint = state.pointIndex;
      blue.textContent = String(state.leftScore);
      red.textContent = String(state.rightScore);
      blueDot.setAttribute('cy', String(plot.leftY));
      redDot.setAttribute('cy', String(plot.rightY));
      event.textContent = event.dataset[state.stage]!;
      for (const element of moments) {
        const moment = replayExample.keyMoments.find(
          (item) => item.id === element.dataset.replayMoment,
        )!;
        element.dataset.reached = String(state.progress >= moment.progress);
        element.dataset.current = String(state.stage === moment.id);
      }
    }
    // Opacity and the short rule continue between events, including in reverse.
    for (const element of moments) {
      const presentation = getReplayMomentPresentation(
        state.progress,
        element.dataset.replayMoment as Exclude<ReplayKeyMomentId, 'final'>,
      );
      for (const [property, value] of [
        ['--moment-reveal', presentation.reveal],
        ['--moment-emphasis', presentation.emphasis],
      ] as const) {
        const next = value.toFixed(5);
        if (element.style.getPropertyValue(property) !== next)
          element.style.setProperty(property, next);
      }
    }
  }

  drawGraph(1);
  return {
    update(progress = 1) {
      // The graph reaches its final event as the glass cards finish entering.
      // Reading states and direct anchors always show the complete example.
      const value = Math.max(0, Math.min(1, progress / 0.22));
      stage.dataset.replayProgress = value.toFixed(4);
      drawGraph(value);
    },
    restore() {
      cancelImagePreparation();
      drawGraph(1);
      delete stage.dataset.replayProgress;
    },
  };
}
