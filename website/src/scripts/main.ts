import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { initialDemoState, reduceDemo, type DemoAction } from './demo-state';
import type {
  CourtPoint,
  CourtScene,
  StoryChapter,
  StoryFrame,
} from './scene-contract';

gsap.registerPlugin(ScrollTrigger);
const root = document.documentElement;
const select = <T extends Element>(selector: string) =>
  document.querySelector<T>(selector)!;
const canvas = select<HTMLCanvasElement>('#court-canvas');
const desktop = matchMedia('(min-width: 1024px) and (pointer: fine)');
const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
let scene: CourtScene | undefined;
let abort: AbortController | undefined;
let deadline: ReturnType<typeof setTimeout> | undefined;
let completion: ReturnType<typeof setTimeout> | undefined;
let flight: gsap.core.Tween | undefined;
const choreography = gsap.matchMedia();
const stages = new Map<
  StoryChapter,
  { progress: number; trigger: ScrollTrigger }
>();
let sceneFailed = false;
let disposed = false;
let state = initialDemoState();
let storyFrame: StoryFrame = { chapter: 'hero', progress: 0, active: true };
const reduced = () => systemMotion.matches;
const blue = select<HTMLElement>('[data-blue-score]');
const record = select<HTMLButtonElement>('[data-record]');
const reset = select<HTMLButtonElement>('[data-reset]');
const status = select<HTMLElement>('[data-demo-status]');
const court = select<SVGSVGElement>('[data-demo-court]');
const marker = select<SVGGElement>('[data-demo-marker]');
const selection = select<SVGGElement>('[data-demo-selection]');
const ball = select<SVGGElement>('[data-demo-ball]');
const net = document.querySelector<SVGGElement>('[data-demo-net]');
const presets = [
  ...document.querySelectorAll<HTMLButtonElement>('[data-point-preset]'),
];
const positions: Record<string, CourtPoint> = {
  left: { x: 0.25, y: 0.65 },
  center: { x: 0.5, y: 0.65 },
  right: { x: 0.75, y: 0.65 },
};

function render() {
  blue.textContent = String(state.blue);
  record.disabled = state.phase !== 'ready' || !state.point;
  reset.disabled = false;
  presets.forEach((button) => {
    button.disabled = state.phase !== 'ready';
    const point = positions[button.dataset.pointPreset!];
    button.setAttribute(
      'aria-pressed',
      String(
        !!state.point &&
          Math.abs(state.point.x - point.x) < 0.01 &&
          Math.abs(state.point.y - point.y) < 0.01,
      ),
    );
  });
  const key =
    state.phase === 'scored'
      ? 'scored'
      : state.phase === 'shooting'
        ? 'shooting'
        : state.point
          ? 'selected'
          : 'ready';
  status.textContent = status.dataset[key]!;
  marker.toggleAttribute('hidden', !state.hasLocation);
  selection.toggleAttribute('hidden', !state.point || state.hasLocation);
  if (state.point) {
    const transform = `translate(${28 + state.point.x * 544} ${28 + state.point.y * 504})`;
    marker.setAttribute('transform', transform);
    selection.setAttribute('transform', transform);
  }
}
function dispatch(action: DemoAction) {
  state = reduceDemo(state, action);
  render();
  if (action.type === 'complete' && state.hasLocation) {
    scene?.setMadePoint(state.point);
  }
}
function choose(point: CourtPoint) {
  if (state.phase !== 'ready') return;
  dispatch({ type: 'select', point });
  scene?.selectPoint(state.point);
}
function stopFlight() {
  clearTimeout(completion);
  flight?.kill();
  flight = undefined;
  ball.setAttribute('hidden', '');
  if (net) gsap.set(net, { scaleY: 1, skewX: 0 });
}
function completeShot() {
  stopFlight();
  dispatch({ type: 'complete', generation: state.generation });
}
presets.forEach((button) =>
  button.addEventListener('click', () =>
    choose(positions[button.dataset.pointPreset!]),
  ),
);
court.addEventListener('click', (event) => {
  const matrix = court.getScreenCTM();
  if (!matrix) return;
  const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(
    matrix.inverse(),
  );
  if (point.x < 28 || point.x > 572 || point.y < 28 || point.y > 532) return;
  choose({ x: (point.x - 28) / 544, y: (point.y - 28) / 504 });
});
record.addEventListener('click', () => {
  if (!state.point || state.phase !== 'ready') return;
  dispatch({ type: 'record' });
  if (reduced()) {
    completeShot();
    return;
  }
  scene?.shoot(state.point!);
  const point = state.point!;
  const animation = { progress: 0 };
  ball.removeAttribute('hidden');
  flight = gsap.to(animation, {
    progress: 1,
    duration: 1.55,
    ease: 'none',
    onUpdate: () => {
      const t = animation.progress;
      const x = (28 + point.x * 544) * (1 - t) + 300 * t;
      const y =
        (28 + point.y * 504) * (1 - t) + 82 * t - Math.sin(t * Math.PI) * 95;
      ball.setAttribute(
        'transform',
        `translate(${x} ${y}) rotate(${t * 500}) scale(${1 - t * 0.35})`,
      );
      if (net)
        gsap.set(net, {
          scaleY: 1 + Math.sin((Math.max(0, t - 0.78) * Math.PI) / 0.22) * 0.22,
          svgOrigin: '300 82',
        });
    },
  });
  const generation = state.generation;
  completion = setTimeout(() => {
    stopFlight();
    dispatch({ type: 'complete', generation });
  }, 1550);
});
reset.addEventListener('click', () => {
  stopFlight();
  dispatch({ type: 'reset' });
  scene?.reset();
});
render();

function syncLanguage() {
  const link = select<HTMLAnchorElement>('[data-language]');
  link.href = (root.lang === 'en' ? '/' : '/en/') + location.hash;
}
syncLanguage();
window.addEventListener('hashchange', syncLanguage);

function stopScene(reason?: string) {
  clearTimeout(deadline);
  abort?.abort();
  abort = undefined;
  scene?.dispose();
  scene = undefined;
  root.dataset.scene = '2d';
  root.dataset.interactive = 'false';
  if (reason) {
    root.dataset.sceneFallback = reason;
    sceneFailed = true;
  }
}
function hasWebGL2() {
  try {
    const probe = document.createElement('canvas');
    const context = probe.getContext('webgl2', {
      failIfMajorPerformanceCaveat: true,
    });
    if (!context) return false;
    context.getExtension('WEBGL_lose_context')?.loseContext();
    return true;
  } catch {
    return false;
  }
}
async function startScene() {
  if (disposed || sceneFailed || abort || scene || !desktop.matches) return;
  if (!hasWebGL2()) {
    stopScene('webgl-unavailable');
    return;
  }
  const controller = new AbortController();
  abort = controller;
  root.dataset.scene = 'loading';
  deadline = setTimeout(() => {
    if (abort === controller) stopScene('timeout');
  }, 8000);
  try {
    const { createCourtScene } = await import('./court-scene');
    if (controller.signal.aborted || disposed) return;
    const created = await createCourtScene(canvas, {
      signal: controller.signal,
      motionEnabled: !reduced(),
      onPoint: choose,
      onFailure: (reason) => {
        if (abort === controller) stopScene(reason);
      },
      onQualityChange: (quality) => {
        root.dataset.quality = quality;
      },
    });
    if (controller.signal.aborted || disposed || abort !== controller) {
      created.dispose();
      return;
    }
    clearTimeout(deadline);
    scene = created;
    scene.setMotionEnabled(!reduced());
    root.dataset.scene = '3d';
    scene.setStoryFrame(storyFrame);
    if (state.hasLocation) scene.setMadePoint(state.point);
    else scene.selectPoint(state.point);
    scene.setPaused(document.hidden);
    updateStory();
  } catch {
    if (!controller.signal.aborted && abort === controller)
      stopScene('initialization');
  }
}
function updateStory() {
  const sections = ['hero', 'scoring', 'experience', 'replay', 'download'].map(
    (id) => document.getElementById(id)!,
  );
  const focus = Math.min(window.innerHeight * 0.3, 260);
  const current =
    [...sections]
      .reverse()
      .find((section) => section.getBoundingClientRect().top <= focus) ??
    sections[0];
  const chapter = current.id as StoryChapter;
  const bounds = current.getBoundingClientRect();
  const stage = stages.get(chapter);
  const progress = stage
    ? stage.progress
    : chapter === 'hero'
      ? 0
      : Math.max(
          0,
          Math.min(
            1,
            (focus - bounds.top) /
              Math.max(1, bounds.height - window.innerHeight * 0.45),
          ),
        );
  storyFrame = {
    chapter,
    progress,
    active: chapter !== 'download' && bounds.bottom > 90,
  };
  scene?.setStoryFrame(storyFrame);
  root.dataset.chapter = chapter;
  const demoBounds = sections[2].getBoundingClientRect();
  root.dataset.interactive = String(
    !!scene &&
      demoBounds.top < window.innerHeight * 0.4 &&
      demoBounds.bottom > window.innerHeight * 0.6,
  );
}
let scrollFrame = 0;
let resizeTimer: ReturnType<typeof setTimeout> | undefined;
let openingPlayed = false;
function onScroll() {
  if (!scrollFrame)
    scrollFrame = requestAnimationFrame(() => {
      scrollFrame = 0;
      updateStory();
    });
}
window.addEventListener('scroll', onScroll, { passive: true });
window.addEventListener(
  'resize',
  () => {
    onScroll();
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      if (!disposed) {
        gsap.matchMediaRefresh();
        ScrollTrigger.refresh();
        updateStory();
      }
    }, 200);
  },
  { passive: true },
);
function applyMotion() {
  scene?.setMotionEnabled(!reduced());
  if (reduced()) {
    if (state.phase === 'shooting') completeShot();
  }
  void startScene();
  updateStory();
}
choreography.add(
  {
    desktop: '(min-width: 1024px) and (pointer: fine)',
    reduce: '(prefers-reduced-motion: reduce)',
    mobile: '(max-width: 1023px)',
  },
  (context) => {
    const { desktop: isDesktop, reduce } = context.conditions!;
    stages.clear();
    if (reduce) return;
    if (!openingPlayed) {
      openingPlayed = true;
      gsap.from('[data-hero-line]', {
        yPercent: 35,
        opacity: 0,
        duration: isDesktop ? 1.3 : 0.9,
        stagger: isDesktop ? 0.14 : 0.08,
        ease: 'power3.out',
        clearProps: 'all',
      });
      gsap.from('.hero-ball', {
        rotation: -14,
        scale: 0.88,
        duration: 1.8,
        ease: 'power2.out',
        clearProps: 'all',
      });
    }
    for (const [chapter, extra] of [
      ['hero', 0.75],
      ['scoring', 1],
      ['replay', 0.75],
    ] as const) {
      const stage = document.querySelector<HTMLElement>(
        `[data-story-stage="${chapter}"]`,
      );
      if (!stage) continue;
      const value = { progress: 0 };
      // Expanded text is allowed to flow naturally instead of being clipped by a pinned viewport.
      const canPin = isDesktop && stage.scrollHeight <= window.innerHeight - 50;
      const timeline = gsap.timeline({
        scrollTrigger: {
          id: `story-${chapter}`,
          trigger: stage,
          start: canPin
            ? chapter === 'hero'
              ? 'top top'
              : 'top 88px'
            : 'top 75%',
          end: () =>
            canPin ? `+=${window.innerHeight * extra}` : 'bottom 25%',
          pin: canPin,
          pinSpacing: true,
          scrub: 0.55,
          invalidateOnRefresh: true,
          onRefresh: (trigger) => {
            stage.dataset.storyStart = String(trigger.start);
            stage.dataset.storyEnd = String(trigger.end);
            updateStory();
          },
        },
        onUpdate: () => {
          const entry = stages.get(chapter);
          if (entry) entry.progress = value.progress;
          stage.dataset.storyProgress = value.progress.toFixed(4);
          updateStory();
        },
      });
      stages.set(chapter, { progress: 0, trigger: timeline.scrollTrigger! });
      timeline.to(value, { progress: 1, duration: 1, ease: 'none' }, 0);
      if (chapter === 'hero') {
        timeline.to(
          '.hero-art',
          {
            scale: isDesktop ? 0.94 : 1.04,
            yPercent: isDesktop ? 0 : 5,
            duration: 1,
            ease: 'none',
          },
          0,
        );
      } else if (chapter === 'scoring') {
        timeline.fromTo(
          '[data-story-device]',
          {
            rotationY: isDesktop ? -16 : 0,
            rotationX: isDesktop ? 8 : 0,
            scale: 0.93,
          },
          {
            rotationY: 0,
            rotationX: 0,
            scale: 1,
            duration: 0.85,
            ease: 'power2.out',
          },
          0,
        );
        timeline.from(
          '[data-score-callout]',
          {
            opacity: 0.2,
            x: isDesktop ? 24 : 0,
            stagger: 0.12,
            duration: 0.35,
          },
          0.35,
        );
      } else {
        timeline.fromTo(
          '[data-replay-device="summary"]',
          { rotation: isDesktop ? -6 : 0, y: isDesktop ? 28 : 0 },
          { rotation: 0, y: 0, duration: 0.85, ease: 'power2.out' },
          0,
        );
        timeline.fromTo(
          '[data-replay-device="history"]',
          { rotation: isDesktop ? 6 : 0, y: isDesktop ? -28 : 0 },
          { rotation: 0, y: 0, duration: 0.85, ease: 'power2.out' },
          0.1,
        );
        const path = document.querySelector<SVGPathElement>(
          '[data-example-path]',
        );
        if (path) {
          const length = path.getTotalLength();
          timeline.fromTo(
            path,
            { strokeDasharray: length, strokeDashoffset: length },
            { strokeDashoffset: 0, duration: 0.65, ease: 'none' },
            0.15,
          );
        }
      }
    }
    return () => {
      stages.clear();
      updateStory();
    };
  },
);
systemMotion.addEventListener('change', applyMotion);
desktop.addEventListener('change', () => {
  if (desktop.matches) void startScene();
  else stopScene();
});
document.addEventListener('visibilitychange', () =>
  scene?.setPaused(document.hidden),
);
document.fonts.ready.then(() => {
  if (!disposed) {
    gsap.matchMediaRefresh();
    ScrollTrigger.refresh();
    if (location.hash)
      document
        .getElementById(location.hash.slice(1))
        ?.scrollIntoView({ behavior: 'instant', block: 'start' });
    updateStory();
  }
});
window.addEventListener('pagehide', (event) => {
  if (event.persisted) {
    scene?.setPaused(true);
    return;
  }
  disposed = true;
  stopFlight();
  stopScene();
  choreography.revert();
  cancelAnimationFrame(scrollFrame);
  clearTimeout(resizeTimer);
});
window.addEventListener('pageshow', () => scene?.setPaused(document.hidden));
applyMotion();
