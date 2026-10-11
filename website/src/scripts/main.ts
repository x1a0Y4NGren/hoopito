import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { initialDemoState, reduceDemo, type DemoAction } from './demo-state';
import type { CourtPoint, CourtScene } from './scene-contract';

gsap.registerPlugin(ScrollTrigger);
const root = document.documentElement;
const select = <T extends Element>(selector: string) =>
  document.querySelector<T>(selector)!;
const canvas = select<HTMLCanvasElement>('#court-canvas');
const motionButton = select<HTMLButtonElement>('[data-motion-toggle]');
const desktop = matchMedia('(min-width: 1024px) and (pointer: fine)');
const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
let manualReduced = false;
let scene: CourtScene | undefined;
let abort: AbortController | undefined;
let deadline: ReturnType<typeof setTimeout> | undefined;
let completion: ReturnType<typeof setTimeout> | undefined;
let flight: gsap.core.Tween | undefined;
let reveals: gsap.Context | undefined;
let sceneFailed = false;
let disposed = false;
let state = initialDemoState();
let journey = 0;
const reduced = () => manualReduced || systemMotion.matches;
const blue = select<HTMLElement>('[data-blue-score]');
const record = select<HTMLButtonElement>('[data-record]');
const reset = select<HTMLButtonElement>('[data-reset]');
const status = select<HTMLElement>('[data-demo-status]');
const court = select<SVGSVGElement>('[data-demo-court]');
const marker = select<SVGGElement>('[data-demo-marker]');
const selection = select<SVGGElement>('[data-demo-selection]');
const ball = select<SVGGElement>('[data-demo-ball]');
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
  if (
    disposed ||
    sceneFailed ||
    abort ||
    scene ||
    !desktop.matches ||
    reduced()
  )
    return;
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
    root.dataset.scene = '3d';
    scene.setJourney(journey);
    if (state.hasLocation) scene.setMadePoint(state.point);
    else scene.selectPoint(state.point);
    scene.setPaused(document.hidden);
    updateJourney();
  } catch {
    if (!controller.signal.aborted && abort === controller)
      stopScene('initialization');
  }
}
function updateJourney() {
  const sections = ['hero', 'scoring', 'experience', 'replay', 'download'].map(
    (id) => document.getElementById(id)!,
  );
  const focus = window.scrollY + window.innerHeight * 0.47;
  const centers = sections.map(
    (section, i) =>
      section.offsetTop +
      (i === 0
        ? window.innerHeight * 0.47
        : Math.min(section.offsetHeight * 0.5, window.innerHeight * 0.6)),
  );
  let index = centers.findIndex((center) => center > focus);
  if (index === -1) index = 4;
  const previous = Math.max(0, index - 1);
  const fraction =
    index === 0
      ? 0
      : Math.min(
          1,
          Math.max(
            0,
            (focus - centers[previous]) / (centers[index] - centers[previous]),
          ),
        );
  journey = (previous + fraction) / 4;
  scene?.setJourney(journey);
  const bounds = sections[2].getBoundingClientRect();
  root.dataset.interactive = String(
    !!scene &&
      bounds.top < window.innerHeight * 0.4 &&
      bounds.bottom > window.innerHeight * 0.6,
  );
}
let scrollFrame = 0;
function onScroll() {
  if (!scrollFrame)
    scrollFrame = requestAnimationFrame(() => {
      scrollFrame = 0;
      updateJourney();
    });
}
window.addEventListener('scroll', onScroll, { passive: true });
window.addEventListener('resize', onScroll, { passive: true });
function applyMotion() {
  root.dataset.motion = reduced() ? 'reduced' : 'full';
  motionButton.setAttribute('aria-pressed', String(reduced()));
  motionButton.hidden = false;
  reveals?.revert();
  reveals = undefined;
  if (reduced()) {
    stopScene();
    if (state.phase === 'shooting') completeShot();
  } else {
    reveals = gsap.context(() => {
      document
        .querySelectorAll<HTMLElement>('[data-reveal]')
        .forEach((element) => {
          gsap.from(element, {
            y: 22,
            duration: 0.9,
            ease: 'power3.out',
            scrollTrigger: { trigger: element, start: 'top 95%', once: true },
          });
        });
    });
    void startScene();
  }
  updateJourney();
}
motionButton.addEventListener('click', () => {
  manualReduced = !manualReduced;
  applyMotion();
});
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
    ScrollTrigger.refresh();
    updateJourney();
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
  reveals?.revert();
  cancelAnimationFrame(scrollFrame);
});
window.addEventListener('pageshow', () => scene?.setPaused(document.hidden));
applyMotion();
