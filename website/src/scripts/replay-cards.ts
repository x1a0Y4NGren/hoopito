import {
  getReplayPlotPoint,
  getReplayState,
  replayExample,
  replayPlotBounds,
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
export function addReplayCardChoreography(
  story: gsap.core.Timeline,
  stage: HTMLElement,
) {
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
  }

  // The page's arrival, both faces and the score use the SAME scrub playhead.
  // Easing the page's travel must not slow down this scroll-driven clock.
  const motion = story;
  for (const [index, name] of ['summary', 'history'].entries()) {
    const figure = stage.querySelector<HTMLElement>(
      `[data-replay-device="${name}"]`,
    )!;
    const card = figure.querySelector<HTMLElement>('[data-replay-card]')!;
    const shadow = figure.querySelector<HTMLElement>('[data-replay-shadow]')!;
    const sheen = figure.querySelector<HTMLElement>('[data-replay-sheen]')!;
    const caption = figure.querySelector('figcaption')!;
    const at = index * 0.05;
    // Y advances exactly 540 degrees. The initial X tilt presents the edge;
    // unfolding X to zero brings the final 360-degree Y pose fully face-on.
    motion
      .fromTo(
        card,
        {
          xPercent: index ? -20 : 18,
          y: index ? -92 : -65,
          z: -620,
          rotationX: 82,
          rotationY: -180,
          rotation: index ? 13 : -12,
          scale: 0.74,
          transformPerspective: 1700,
          transformOrigin: '50% 55%',
          force3D: true,
          willChange: 'transform',
        },
        {
          xPercent: 0,
          y: 0,
          z: 0,
          rotationX: 0,
          rotationY: 360,
          rotation: 0,
          scale: 1,
          duration: 0.95,
          ease: 'sine.inOut',
        },
        at,
      )
      .set(card, { willChange: 'auto' }, at + 0.95)
      .fromTo(
        shadow,
        { y: 42, scale: 0.72, opacity: 0.04 },
        {
          y: 14,
          scale: 0.98,
          opacity: 0.36,
          duration: 0.95,
          ease: 'sine.inOut',
        },
        at,
      )
      .fromTo(
        caption,
        { opacity: 0.32, y: 8 },
        { opacity: 1, y: 0, duration: 0.28, ease: 'sine.inOut' },
        at + 0.66,
      )
      .fromTo(
        sheen,
        { xPercent: -120, opacity: 0 },
        { xPercent: 200, opacity: 0.4, duration: 0.16, ease: 'sine.inOut' },
        at + 0.71,
      )
      .to(sheen, { opacity: 0, duration: 0.08, ease: 'sine.out' }, at + 0.87);
  }
  drawGraph(motion.progress());
  stage.dataset.replayProgress = motion.progress().toFixed(4);
  return {
    update() {
      const progress = motion.progress();
      const trigger = motion.scrollTrigger;
      const range = trigger ? trigger.end - trigger.start : 0;
      // Scroll positions are quantized to CSS pixels, including on 2x displays.
      // Resolve the final partial pixel on the shared playhead, so the cards,
      // page and final score all arrive together rather than leaving 8:9 visible.
      if (
        range > 1 &&
        progress > 0 &&
        progress < 1 &&
        (1 - progress) * range < 1
      ) {
        motion.progress(1);
      }
      stage.dataset.replayProgress = motion.progress().toFixed(4);
      drawGraph(motion.progress());
    },
    restore() {
      cancelImagePreparation();
      previousPoint = -1;
      drawGraph(1);
      delete stage.dataset.replayProgress;
      delete stage.dataset.replayStart;
      delete stage.dataset.replayEnd;
    },
  };
}
