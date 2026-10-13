import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { initialDemoState, reduceDemo, type DemoAction } from './demo-state';
import { ScoringFocus } from './presentation-state';
import { createScreenshotViewer } from './screenshot-viewer';
import { createShotFeedback } from './shot-feedback';
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
let shotFeedback: ReturnType<typeof createShotFeedback> | undefined;
const suspension = new Set<string>(document.hidden ? ['hidden'] : []);
function setSuspended(reason: string, paused: boolean) {
  if (paused) suspension.add(reason);
  else suspension.delete(reason);
  scene?.setPaused(suspension.size > 0);
  if (suspension.size) shotFeedback?.pause();
  else shotFeedback?.resume();
}
const viewer = createScreenshotViewer((open) => setSuspended('viewer', open));
const scoringFocus = new ScoringFocus();
const scoreDevice = select<HTMLElement>('[data-story-device]');
const scoreFeatures = [
  ...document.querySelectorAll<HTMLButtonElement>('[data-score-feature]'),
];
function paintScoring(index: number | null) {
  scoreDevice.dataset.scoreFocus = index === null ? 'none' : String(index);
  scoreFeatures.forEach((button, i) =>
    button.setAttribute('aria-pressed', String(index === i)),
  );
}
scoreFeatures.forEach((button, index) => {
  button.disabled = false;
  const chooseFeature = () => paintScoring(scoringFocus.choose(index));
  button.addEventListener('click', chooseFeature);
  button.addEventListener('focus', chooseFeature);
});
let abort: AbortController | undefined;
let deadline: ReturnType<typeof setTimeout> | undefined;
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
const net = select<SVGPathElement>('[data-net-weave]');
const trail = select<SVGPathElement>('[data-demo-trail]');
shotFeedback = createShotFeedback(ball, net, trail);
if (suspension.size) shotFeedback.pause();
const surface = select<SVGImageElement>('[data-demo-surface]');
const surfaceObserver = new IntersectionObserver(
  (entries) => {
    if (entries.some((entry) => entry.isIntersecting)) {
      surface.setAttribute('href', surface.dataset.src!);
      surfaceObserver.disconnect();
    }
  },
  { rootMargin: '200px' },
);
surfaceObserver.observe(court);
const presets = [
  ...document.querySelectorAll<HTMLButtonElement>('[data-point-preset]'),
];
const positions: Record<string, CourtPoint> = {
  left: { x: 0.25, y: 0.65 },
  center: { x: 0.5, y: 0.65 },
  right: { x: 0.75, y: 0.65 },
};

function render() {
  select<HTMLElement>('[data-demo]').dataset.demoPhase = state.phase;
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
  if (!reduced()) {
    const halo = selection.querySelector('.aim-halo');
    gsap.killTweensOf(halo);
    gsap.fromTo(
      halo,
      { scale: 0.65, opacity: 0 },
      {
        scale: 1,
        opacity: 1,
        duration: 0.5,
        ease: 'power2.out',
        svgOrigin: '0 0',
      },
    );
  }
}
function stopFlight() {
  shotFeedback?.cancel();
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
  const generation = state.generation;
  shotFeedback!.start(state.point!, () => {
    dispatch({ type: 'complete', generation });
  });
  gsap.fromTo(
    blue,
    { scale: 0.9 },
    { scale: 1, duration: 0.22, ease: 'power2.out', clearProps: 'transform' },
  );
});
reset.addEventListener('click', () => {
  stopFlight();
  const halo = selection.querySelector('.aim-halo');
  gsap.killTweensOf(halo);
  gsap.set(halo, { scale: 1, opacity: 1 });
  gsap.killTweensOf(blue);
  gsap.set(blue, { clearProps: 'transform' });
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
    scene.setPaused(suspension.size > 0);
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
  // An unpinned visual can enter before its chapter becomes current. Its
  // reveal progress therefore cannot drive the camera without cutting ahead
  // of the shared endpoint. Natural-flow camera spans use the same chapter
  // boundaries as selection, including enlarged text and gaps between sections.
  const nextTop =
    sections[sections.indexOf(current) + 1]?.getBoundingClientRect().top ??
    bounds.bottom;
  const flowProgress =
    chapter === 'hero'
      ? window.scrollY / Math.max(1, nextTop + window.scrollY - focus)
      : (focus - bounds.top) / Math.max(1, nextTop - bounds.top);
  const progress = stage?.trigger.pin
    ? stage.progress
    : Math.max(0, Math.min(1, flowProgress));
  storyFrame = {
    chapter,
    progress,
    active: chapter !== 'download' && bounds.bottom > 90,
  };
  scene?.setStoryFrame(storyFrame);
  root.dataset.chapter = chapter;
  const scoringBounds = sections[1].getBoundingClientRect();
  paintScoring(
    scoringFocus.update(
      stages.get('scoring')?.progress ?? 0,
      scoringBounds.top < window.innerHeight - 100 &&
        scoringBounds.bottom > 100,
    ),
  );
  const demoBounds = sections[2].getBoundingClientRect();
  root.dataset.interactive = String(
    !!scene &&
      demoBounds.top < window.innerHeight * 0.4 &&
      demoBounds.bottom > window.innerHeight * 0.6,
  );
}
let scrollFrame = 0;
let resizeTimer: ReturnType<typeof setTimeout> | undefined;
let motionTimer: ReturnType<typeof setTimeout> | undefined;
let choreographyReduced = reduced();
let openingPlayed = false;
let recentAnchor: { element: HTMLElement } | undefined;
let anchorFrame = 0;
document.addEventListener('click', (event) => {
  if (event.button || event.metaKey || event.ctrlKey || event.shiftKey) return;
  const link =
    event.target instanceof Element
      ? event.target.closest<HTMLAnchorElement>('a[href^="#"]')
      : null;
  const element = link?.hash
    ? document.getElementById(link.hash.slice(1))
    : null;
  if (element) recentAnchor = { element };
});
for (const input of ['wheel', 'touchstart', 'pointerdown', 'keydown']) {
  window.addEventListener(input, () => (recentAnchor = undefined), {
    passive: true,
  });
}
function resumeAnchorNavigation() {
  // Refresh restores scroll positions and can cancel a native smooth anchor
  // scroll. Keep the current navigation intent until manual input cancels it.
  cancelAnimationFrame(anchorFrame);
  anchorFrame = requestAnimationFrame(() => {
    anchorFrame = 0;
    if (
      !disposed &&
      recentAnchor &&
      location.hash === `#${recentAnchor.element.id}`
    )
      recentAnchor.element.scrollIntoView({
        behavior: reduced() ? 'instant' : 'smooth',
        block: 'start',
      });
  });
}
// Include ScrollTrigger's own delayed resize/font measurements. Its refresh
// restores scroll behavior on the next frame, so resume after that restoration.
ScrollTrigger.addEventListener('refresh', resumeAnchorNavigation);
function needsChoreographyRefresh() {
  if (choreographyReduced !== reduced()) return true;
  if (reduced()) return stages.size > 0;
  return (['hero', 'scoring', 'replay'] as const).some((chapter) => {
    const stage = document.querySelector<HTMLElement>(
      `[data-story-stage="${chapter}"]`,
    );
    const trigger = stages.get(chapter)?.trigger;
    const shouldPin =
      desktop.matches &&
      !!stage &&
      stage.scrollHeight <= window.innerHeight - 50;
    return !trigger || Boolean(trigger.pin) !== shouldPin;
  });
}
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
        // Media changes already rebuild the stage. A same-mode resize only
        // needs new measurements unless text growth changed pin eligibility.
        if (needsChoreographyRefresh()) gsap.matchMediaRefresh();
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
    gsap.killTweensOf(blue);
    gsap.set(blue, { clearProps: 'transform' });
    const halo = selection.querySelector('.aim-halo');
    gsap.killTweensOf(halo);
    gsap.set(halo, { scale: 1, opacity: 1 });
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
    choreographyReduced = Boolean(reduce);
    stages.clear();
    if (reduce) return;
    if (!openingPlayed) {
      openingPlayed = true;
      gsap.from('[data-hero-line]', {
        y: isDesktop ? 28 : 12,
        opacity: 0,
        duration: isDesktop ? 1.3 : 0.45,
        stagger: isDesktop ? 0.14 : 0.04,
        ease: 'power3.out',
        clearProps: 'all',
      });
      gsap.from('.hero-ball', {
        rotation: -14,
        scale: 0.88,
        duration: isDesktop ? 1.8 : 0.5,
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
            scale: isDesktop ? 0.94 : 1,
            y: isDesktop ? 0 : 12,
            duration: 1,
            ease: 'none',
          },
          0,
        );
      } else if (chapter === 'scoring' && isDesktop) {
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
            duration: 0.25,
            ease: 'power2.out',
          },
          0,
        );
      } else if (chapter === 'replay' && isDesktop) {
        timeline.fromTo(
          '[data-replay-device="summary"]',
          {
            rotationY: isDesktop ? -12 : 0,
            rotation: isDesktop ? -4 : 0,
            y: isDesktop ? 28 : 0,
            scale: isDesktop ? 0.96 : 1,
          },
          {
            rotationY: isDesktop ? -8 : 0,
            rotation: isDesktop ? -2 : 0,
            y: isDesktop ? 14 : 0,
            scale: 1,
            duration: 0.3,
            ease: 'power2.out',
          },
          0,
        );
        timeline.to(
          '[data-replay-device="summary"]',
          {
            rotationY: 0,
            rotation: 0,
            y: 0,
            duration: 0.4,
            ease: 'power2.inOut',
          },
          0.3,
        );
        timeline.fromTo(
          '[data-replay-device="history"]',
          {
            rotationY: isDesktop ? 14 : 0,
            rotation: isDesktop ? 3 : 0,
            y: isDesktop ? -24 : 0,
            scale: isDesktop ? 0.94 : 1,
          },
          {
            rotationY: isDesktop ? 8 : 0,
            rotation: isDesktop ? 1 : 0,
            y: isDesktop ? -12 : 0,
            scale: 1,
            duration: 0.3,
            ease: 'power2.out',
          },
          0,
        );
        timeline.to(
          '[data-replay-device="history"]',
          {
            rotationY: 0,
            rotation: 0,
            y: 0,
            duration: 0.4,
            ease: 'power2.inOut',
          },
          0.3,
        );
        const path = document.querySelector<SVGPathElement>(
          '[data-example-path]',
        );
        if (path) {
          const length = path.getTotalLength();
          timeline.fromTo(
            path,
            { strokeDasharray: length, strokeDashoffset: length },
            { strokeDashoffset: 0, duration: 0.4, ease: 'none' },
            0.3,
          );
        }
      }
    }
    if (!isDesktop) {
      for (const element of document.querySelectorAll<HTMLElement>(
        '.scoring-display, .score-features, .demo-map, .replay-editorial > *, .download-package',
      )) {
        gsap.from(element, {
          opacity: 0,
          y: 12,
          duration: 0.42,
          ease: 'power2.out',
          clearProps: 'transform,opacity',
          scrollTrigger: {
            trigger: element,
            start: 'top 88%',
            toggleActions: 'play none none none',
          },
        });
      }
    }
    return () => {
      stages.clear();
      updateStory();
    };
  },
);
systemMotion.addEventListener('change', () => {
  applyMotion();
  clearTimeout(motionTimer);
  // GSAP can coalesce media events within one clock tick. Reconcile a missed
  // final preference after the burst, without rebuilding already-correct stages
  // during a user's anchor navigation or replaying the opening animation.
  motionTimer = setTimeout(() => {
    if (!disposed && needsChoreographyRefresh()) {
      gsap.matchMediaRefresh();
      ScrollTrigger.refresh();
      updateStory();
    }
  }, 200);
});
desktop.addEventListener('change', () => {
  if (desktop.matches) void startScene();
  else stopScene();
});
document.addEventListener('visibilitychange', () =>
  setSuspended('hidden', document.hidden),
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
    setSuspended('page-cache', true);
    return;
  }
  disposed = true;
  surfaceObserver.disconnect();
  viewer.dispose();
  stopFlight();
  stopScene();
  choreography.revert();
  cancelAnimationFrame(scrollFrame);
  cancelAnimationFrame(anchorFrame);
  ScrollTrigger.removeEventListener('refresh', resumeAnchorNavigation);
  clearTimeout(resizeTimer);
  clearTimeout(motionTimer);
});
window.addEventListener('pageshow', () => {
  setSuspended('page-cache', false);
  setSuspended('hidden', document.hidden);
});
applyMotion();
