import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { initialDemoState, reduceDemo, type DemoAction } from './demo-state';
import { createScreenshotViewer } from './screenshot-viewer';
import { createShotFeedback } from './shot-feedback';
import { createScoringFeedback } from './scoring-feedback';
import { createDemoInvitation } from './demo-invitation';
import { addReplayCardChoreography } from './replay-cards';
import type {
  CourtPoint,
  CourtScene,
  StoryChapter,
  StoryFrame,
} from './scene-contract';

gsap.registerPlugin(ScrollTrigger);
// GSAP 3.15 exports these media lifecycle hooks at runtime; its declarations
// omit them. Keep the verified bridge narrow instead of weakening other GSAP types.
const mediaEvents = gsap as typeof gsap & {
  addEventListener(
    type: 'matchMediaInit' | 'matchMedia',
    callback: () => void,
  ): void;
  removeEventListener(
    type: 'matchMediaInit' | 'matchMedia',
    callback: () => void,
  ): void;
};
const root = document.documentElement;
const chapterLinks = [
  ...document.querySelectorAll<HTMLAnchorElement>(
    '.site-header nav > a[href^="#"]',
  ),
];
let navigationChapter: StoryChapter | undefined;
function syncCurrentNavigation(chapter: StoryChapter) {
  if (navigationChapter === chapter) return;
  navigationChapter = chapter;
  for (const link of chapterLinks) {
    if (link.hash === `#${chapter}`)
      link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  }
  syncLanguage(chapter);
}
const select = <T extends Element>(selector: string) =>
  document.querySelector<T>(selector)!;
const canvas = select<HTMLCanvasElement>('#court-canvas');
const sceneBackground = select<HTMLElement>('.scene-background');
const experienceSection = select<HTMLElement>('#experience');
const traceBridge = select<HTMLElement>('.trace-bridge');
const desktop = matchMedia('(min-width: 1024px) and (pointer: fine)');
const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
let scene: CourtScene | undefined;
let shotFeedback: ReturnType<typeof createShotFeedback> | undefined;
let scoringFeedback: ReturnType<typeof createScoringFeedback> | undefined;
let demoInvitation: ReturnType<typeof createDemoInvitation> | undefined;
const suspension = new Set<string>(document.hidden ? ['hidden'] : []);
function killReplaySnap() {
  // ScrollTrigger uses 0 after a snap finishes; its declarations omit that
  // sentinel. Optional chaining alone would still try to call 0.kill().
  const tween = stages.get('replay')?.trigger.getTween(true);
  if (tween) tween.kill();
}
function setSuspended(reason: string, paused: boolean) {
  if (paused) suspension.add(reason);
  else suspension.delete(reason);
  scene?.setPaused(suspension.size > 0);
  if (suspension.size) shotFeedback?.pause();
  else shotFeedback?.resume();
  if (suspension.size) scoringFeedback?.pause();
  else scoringFeedback?.resume();
  if (suspension.size) demoInvitation?.pause();
  else demoInvitation?.resume();
  if (suspension.size) killReplaySnap();
}
const viewer = createScreenshotViewer((open) => setSuspended('viewer', open));
const scoreDevice = select<HTMLElement>('[data-story-device]');
const scoreStep = select<HTMLElement>('[data-score-step]');
const scoreCurrent = select<HTMLElement>('[data-score-current]');
const scoreNote = select<HTMLElement>('[data-score-note]');
const scoreFeatures = [
  ...document.querySelectorAll<HTMLButtonElement>('[data-score-feature]'),
];
scoringFeedback = createScoringFeedback(scoreDevice, scoreNote, scoreFeatures);
if (suspension.size) scoringFeedback.pause();
function paintScoring(index: number) {
  scoreDevice.dataset.scoreFocus = String(index);
  scoreStep.textContent = `0${index + 1} / 03`;
  scoreCurrent.textContent =
    scoreFeatures[index].querySelector('strong')!.textContent;
  scoreNote.textContent = scoreFeatures[index].dataset.scoreFeedback!;
  scoreFeatures.forEach((button, i) =>
    button.setAttribute('aria-pressed', String(index === i)),
  );
}
scoreFeatures.forEach((button, index) => {
  button.disabled = false;
  button.addEventListener('click', () => {
    paintScoring(index);
    scoringFeedback!.play(index, systemMotion.matches);
  });
});
const scoreInvitationObserver = new IntersectionObserver(
  (entries) => {
    if (
      entries.some(
        (entry) => entry.isIntersecting && entry.intersectionRatio >= 0.6,
      )
    ) {
      scoringFeedback!.invite(systemMotion.matches);
      scoreInvitationObserver.disconnect();
    }
  },
  { threshold: 0.6 },
);
scoreInvitationObserver.observe(scoreFeatures[0]);
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
const courtHost = select<HTMLElement>('[data-demo-court-host]');
const experienceStage = select<HTMLElement>('[data-story-stage="experience"]');
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
demoInvitation = createDemoInvitation(
  courtHost,
  select<HTMLElement>('.point-presets'),
  record,
  {
    projectCourtHint() {
      const point = { x: 0.5, y: 0.65 };
      if (scene) return scene.projectPoint(point);
      const matrix = court.getScreenCTM();
      if (!matrix) return null;
      return new DOMPoint(
        28 + point.x * 544,
        28 + point.y * 504,
      ).matrixTransform(matrix);
    },
  },
);
if (suspension.size) demoInvitation.pause();
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
  demoInvitation?.selected(reduced());
  if (!reduced()) {
    const halo = selection.querySelector('.aim-halo');
    gsap.killTweensOf(halo);
    gsap.fromTo(
      halo,
      {
        // The halo lives inside the translated target group. Establish its
        // local center before scaling; a later global svgOrigin leaves a
        // smooth-origin translation behind even after scale returns to one.
        transformOrigin: '50% 50%',
        smoothOrigin: false,
        scale: 0.65,
        opacity: 0,
      },
      {
        scale: 1,
        opacity: 1,
        duration: 0.5,
        ease: 'power2.out',
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
  if (scene && desktop.matches) return;
  const matrix = court.getScreenCTM();
  if (!matrix) return;
  const point = new DOMPoint(event.clientX, event.clientY).matrixTransform(
    matrix.inverse(),
  );
  if (point.x < 28 || point.x > 572 || point.y < 28 || point.y > 532) return;
  choose({ x: (point.x - 28) / 544, y: (point.y - 28) / 504 });
});
let courtPress:
  { id: number; x: number; y: number; scroll: number } | undefined;
courtHost.addEventListener('pointerdown', (event) => {
  if (
    !scene ||
    !event.isPrimary ||
    event.button !== 0 ||
    root.dataset.interactive !== 'true'
  )
    return;
  courtPress = {
    id: event.pointerId,
    x: event.clientX,
    y: event.clientY,
    scroll: scrollY,
  };
});
courtHost.addEventListener('pointermove', (event) => {
  const press = courtPress;
  if (
    press &&
    event.pointerId === press.id &&
    Math.hypot(event.clientX - press.x, event.clientY - press.y) > 6
  )
    courtPress = undefined;
});
courtHost.addEventListener('pointerup', (event) => {
  const press = courtPress;
  courtPress = undefined;
  if (
    !press ||
    event.pointerId !== press.id ||
    root.dataset.interactive !== 'true' ||
    Math.hypot(event.clientX - press.x, event.clientY - press.y) > 6 ||
    Math.abs(scrollY - press.scroll) > 2
  )
    return;
  const point = scene?.pointFromClient(event.clientX, event.clientY);
  if (point) choose(point);
});
courtHost.addEventListener('pointercancel', () => {
  courtPress = undefined;
});
courtHost.addEventListener('pointerleave', () => {
  courtPress = undefined;
});
record.addEventListener('click', () => {
  if (!state.point || state.phase !== 'ready') return;
  demoInvitation?.cancel();
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
  demoInvitation?.cancel();
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

function syncLanguage(
  chapter = root.dataset.chapter as StoryChapter | undefined,
) {
  const link = select<HTMLAnchorElement>('[data-language]');
  const fragment = chapter
    ? chapter === 'hero'
      ? ''
      : `#${chapter}`
    : location.hash;
  link.href = (root.lang === 'en' ? '/' : '/en/') + fragment;
}
syncLanguage();
window.addEventListener('hashchange', () => syncLanguage());

function stopScene(reason?: string) {
  clearTimeout(deadline);
  abort?.abort();
  abort = undefined;
  scene?.dispose();
  scene = undefined;
  courtHost.dataset.renderer = '2d';
  root.dataset.scene = '2d';
  root.dataset.interactive = 'false';
  if (reason) {
    root.dataset.sceneFallback = reason;
    sceneFailed = true;
    updateStory();
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
    scene.setStoryFrame(storyFrame);
    scene.setPaused(suspension.size > 0);
    const shotElapsed = shotFeedback!.elapsed();
    if (state.point && shotElapsed !== null)
      scene.shoot(state.point, shotElapsed);
    else if (state.hasLocation) scene.setMadePoint(state.point);
    else scene.selectPoint(state.point);
    updateStory();
    scene.presentFrame();
    root.dataset.scene = '3d';
  } catch {
    if (!controller.signal.aborted && abort === controller)
      stopScene('initialization');
  }
}
function updateStory() {
  const sections = ['hero', 'scoring', 'experience', 'replay', 'download'].map(
    (id) => {
      const element = document.getElementById(id)!;
      return { element, bounds: element.getBoundingClientRect() };
    },
  );
  const focus = Math.min(window.innerHeight * 0.3, 260);
  const current =
    [...sections].reverse().find((section) => section.bounds.top <= focus) ??
    sections[0];
  const chapter = current.element.id as StoryChapter;
  const bounds = current.bounds;
  const stage = stages.get(chapter);
  // An unpinned visual can enter before its chapter becomes current. Its
  // reveal progress therefore cannot drive the camera without cutting ahead
  // of the shared endpoint. Natural-flow camera spans use the same chapter
  // boundaries as selection, including enlarged text and gaps between sections.
  const nextTop =
    sections[sections.indexOf(current) + 1]?.bounds.top ?? bounds.bottom;
  const flowProgress =
    chapter === 'hero'
      ? window.scrollY / Math.max(1, nextTop + window.scrollY - focus)
      : (focus - bounds.top) / Math.max(1, nextTop - bounds.top);
  // Replay cards enter before the chapter changes. Start the camera at that
  // actual chapter boundary so neither scroll direction skips its shared pose.
  const cameraStart = window.scrollY + bounds.top - focus;
  const progress =
    chapter === 'replay' && stage?.trigger.pin
      ? Math.max(
          0,
          Math.min(
            1,
            (window.scrollY - cameraStart) /
              Math.max(1, stage.trigger.end - cameraStart),
          ),
        )
      : stage?.trigger.pin
        ? stage.progress
        : Math.max(0, Math.min(1, flowProgress));
  storyFrame = {
    chapter,
    progress,
    active: chapter !== 'download' && bounds.bottom > 90,
  };
  const stageBounds = experienceStage.getBoundingClientRect();
  const hostBounds = courtHost.getBoundingClientRect();
  // Natural flow shares the heading's actual navigation target, including an
  // enlarged header. Pinned stages retain the fixed 88px resting line.
  const arrivalEnd = stages.get('experience')?.trigger.pin
    ? 88
    : select<HTMLElement>('.site-header').getBoundingClientRect().bottom +
      20 -
      (sections[2].element
        .querySelector('.section-top')!
        .getBoundingClientRect().top -
        stageBounds.top);
  const arrival = Math.max(
    0,
    Math.min(
      1,
      (innerHeight * 0.85 - stageBounds.top) /
        Math.max(1, innerHeight * 0.85 - arrivalEnd),
    ),
  );
  const smooth = (value: number) => value * value * (3 - 2 * value);
  const rawBlend = reduced()
    ? Number(chapter === 'experience')
    : chapter === 'scoring' || chapter === 'experience'
      ? smooth(arrival)
      : chapter === 'replay'
        ? 1 - smooth(progress)
        : 0;
  // Native scroll positions are rounded while layout bounds can be fractional.
  // Finish the last subpixel of arrival instead of leaving input almost ready.
  const blend = rawBlend >= 0.99999 ? 1 : rawBlend;
  const demoBounds = sections[2].bounds;
  const interactive =
    !!scene &&
    chapter === 'experience' &&
    blend >= 0.99999 &&
    hostBounds.bottom > 120 &&
    hostBounds.top < innerHeight - 48 &&
    demoBounds.bottom > innerHeight * 0.6;
  // Keep the remaining geometry read ahead of camera/style writes. In replay,
  // this snapshot also preserves the rendered pose through media refreshes.
  if (
    chapter === 'replay' &&
    !layoutRefreshing &&
    !mediaPosition &&
    !refreshPosition
  ) {
    const element = select<HTMLElement>('[data-story-stage="replay"]');
    lastReplayPosition = {
      element,
      top: element.getBoundingClientRect().top,
      progress:
        stage?.trigger.pin &&
        (stage.trigger.isActive || Math.abs(scrollY - stage.trigger.end) < 1)
          ? stage.progress
          : undefined,
    };
  }
  scene?.setCameraPlacement({
    region: {
      left: hostBounds.left,
      top: hostBounds.top,
      width: hostBounds.width,
      height: hostBounds.height,
    },
    blend,
    inputEnabled: interactive,
  });
  scene?.setStoryFrame(storyFrame);
  // The hint needs the final camera projection, but must measure before this
  // update changes inherited lighting and section state.
  demoInvitation?.refresh();
  if (
    chapter === 'experience' &&
    (!desktop.matches || !!root.dataset.sceneFallback || interactive)
  )
    demoInvitation?.invite(reduced());
  const renderer = scene && desktop.matches ? '3d' : '2d';
  if (courtHost.dataset.renderer !== renderer)
    courtHost.dataset.renderer = renderer;
  const courtView =
    chapter === 'experience' || (chapter === 'scoring' && blend > 0)
      ? 'demo'
      : 'story';
  if (root.dataset.courtView !== courtView) root.dataset.courtView = courtView;
  const blendText = blend.toFixed(4);
  // Keep changing custom properties local: inheritance from <html> would make
  // every product screenshot, FAQ and download descendant reconsider its style.
  for (const surface of [sceneBackground, experienceSection])
    if (surface.style.getPropertyValue('--court-blend') !== blendText)
      surface.style.setProperty('--court-blend', blendText);
  // Reading light follows the existing card/score playhead. It has no timer of
  // its own and reverses with the cards, including after a media refresh.
  const replayPhase =
    !desktop.matches || reduced()
      ? Number(chapter === 'replay' || chapter === 'download')
      : (stages.get('replay')?.progress ?? 0);
  const focusPhase = Math.max(0, Math.min(1, (replayPhase - 0.18) / 0.6));
  const replayFocus = smooth(focusPhase).toFixed(4);
  for (const surface of [sceneBackground, traceBridge])
    if (surface.style.getPropertyValue('--replay-focus') !== replayFocus)
      surface.style.setProperty('--replay-focus', replayFocus);
  if (root.dataset.chapter !== chapter) root.dataset.chapter = chapter;
  syncCurrentNavigation(chapter);
  const inputEnabled = String(interactive);
  if (root.dataset.interactive !== inputEnabled)
    root.dataset.interactive = inputEnabled;
}
let scrollFrame = 0;
let resizeTimer: ReturnType<typeof setTimeout> | undefined;
let motionTimer: ReturnType<typeof setTimeout> | undefined;
let choreographyReduced = reduced();
let openingPlayed = false;
const initialAnchor = document.getElementById(location.hash.slice(1));
let recentAnchor: { element: HTMLElement } | undefined = initialAnchor
  ? { element: initialAnchor }
  : undefined;
let replaySnapAllowed = false;
let anchorFrame = 0;
type StagePosition = { element: HTMLElement; top: number; progress?: number };
let mediaPosition: StagePosition | undefined;
let refreshPosition: StagePosition | undefined;
let lastReplayPosition: StagePosition | undefined;
let layoutRefreshing = false;
function rememberDemoPosition() {
  if (recentAnchor || !['experience', 'replay'].includes(storyFrame.chapter))
    return;
  if (mediaPosition) return;
  // ScrollTrigger's own media-init listener reverts pins BEFORE this listener.
  // Replay must use the last rendered pose, not those temporary reverted bounds.
  if (storyFrame.chapter === 'replay' && lastReplayPosition) {
    mediaPosition = lastReplayPosition;
    return;
  }
  const element = select<HTMLElement>(
    `[data-story-stage="${storyFrame.chapter}"]`,
  );
  mediaPosition = { element, top: element.getBoundingClientRect().top };
}
function restoreDemoPosition() {
  const saved = mediaPosition;
  mediaPosition = undefined;
  if (!saved || disposed || recentAnchor) return;
  restoreStagePosition(saved);
}
function restoreStagePosition(saved: StagePosition) {
  const replay =
    saved.element.dataset.storyStage === 'replay'
      ? stages.get('replay')?.trigger
      : undefined;
  if (replay?.pin) {
    // Preserve the card/score phase across a size change. When returning from a
    // natural layout, invert the page travel curve using its visible position.
    if (
      saved.progress === undefined &&
      (saved.top < 87 || saved.top > innerHeight * 0.5)
    ) {
      const top =
        saved.top < 88
          ? replay.end + 88 - saved.top
          : replay.start + innerHeight * 0.5 - saved.top;
      window.scrollTo({ top, behavior: 'instant' });
      ScrollTrigger.update();
      updateStory();
      return;
    }
    const progress =
      saved.progress ??
      (Math.abs(saved.top - 88) < 1
        ? 1
        : Math.asin(
            gsap.utils.clamp(
              0,
              1,
              (innerHeight * 0.5 - saved.top) /
                Math.max(1, innerHeight * 0.5 - 88),
            ),
          ) /
          (Math.PI * 0.5));
    window.scrollTo({
      top: replay.start + (replay.end - replay.start) * progress,
      behavior: 'instant',
    });
    ScrollTrigger.update();
    replay.animation?.progress(progress);
    updateStory();
    return;
  }
  // Pin spacers are removed and recreated during media reconciliation. Preserve
  // the visible stage's position rather than its obsolete document scroll offset.
  window.scrollTo({
    top: Math.max(
      0,
      scrollY + saved.element.getBoundingClientRect().top - saved.top,
    ),
    behavior: 'instant',
  });
  ScrollTrigger.update();
  updateStory();
}
function refreshChoreography() {
  // Explicit refresh reverts before GSAP's media-init event. Capture first here;
  // the event handlers cover native media-query changes.
  rememberDemoPosition();
  const position = mediaPosition;
  gsap.matchMediaRefresh();
  ScrollTrigger.refresh();
  if (position) {
    mediaPosition = position;
    restoreDemoPosition();
  }
}
mediaEvents.addEventListener('matchMediaInit', rememberDemoPosition);
mediaEvents.addEventListener('matchMedia', restoreDemoPosition);
document.addEventListener('click', (event) => {
  if (
    event.defaultPrevented ||
    event.button ||
    event.metaKey ||
    event.ctrlKey ||
    event.shiftKey ||
    event.altKey
  )
    return;
  const link =
    event.target instanceof Element
      ? event.target.closest<HTMLAnchorElement>('a[href^="#"]')
      : null;
  const element = link?.hash
    ? document.getElementById(link.hash.slice(1))
    : null;
  if (element) {
    // Chapter IDs include the breathing room BETWEEN chapters. Navigate to the
    // visible chapter label instead, retaining fragment history and native scroll.
    event.preventDefault();
    if (location.hash !== link!.hash)
      history.pushState(history.state, '', link!.hash);
    syncLanguage();
    if (element.id === 'main') element.focus({ preventScroll: true });
    recentAnchor = { element };
    replaySnapAllowed = false;
    killReplaySnap();
    resumeAnchorNavigation();
  }
});
for (const input of ['wheel', 'touchstart', 'pointerdown', 'keydown']) {
  window.addEventListener(
    input,
    (event) => {
      recentAnchor = undefined;
      replaySnapAllowed =
        event instanceof WheelEvent
          ? !event.ctrlKey && Math.abs(event.deltaY) > Math.abs(event.deltaX)
          : event instanceof KeyboardEvent &&
            ['ArrowDown', 'PageDown', ' '].includes(event.key) &&
            !(
              event.target instanceof Element &&
              event.target.closest(
                'button, input, select, textarea, [contenteditable]',
              )
            );
      if (!replaySnapAllowed) killReplaySnap();
    },
    {
      passive: true,
    },
  );
}
function scrollToChapter(element: HTMLElement, behavior: ScrollBehavior) {
  if (element.id === 'hero' || element.id === 'main') {
    window.scrollTo({ top: 0, behavior });
    return;
  }
  const heading = element.querySelector<HTMLElement>('.section-top');
  if (!heading) {
    element.scrollIntoView({ behavior, block: 'start' });
    return;
  }
  const inset =
    select<HTMLElement>('.site-header').getBoundingClientRect().bottom + 20;
  const stage = element.querySelector<HTMLElement>('[data-story-stage]');
  const trigger = stages.get(element.id as StoryChapter)?.trigger;
  let top = scrollY + heading.getBoundingClientRect().top - inset;
  if (stage && trigger?.pin) {
    const localOffset =
      heading.getBoundingClientRect().top - stage.getBoundingClientRect().top;
    const rest = Number(stage.dataset.storyRestTop);
    const delta = rest + localOffset - inset;
    // Approach and resting states have different scroll offsets. Replay lands
    // at its END; the static input court starts at its START. Positive replay
    // offsets leave the pin naturally; negative experience offsets approach it.
    top =
      element.id === 'replay'
        ? trigger.end + Math.max(0, delta)
        : trigger.start + Math.min(0, delta);
  }
  window.scrollTo({ top: Math.max(0, top), behavior });
}
window.addEventListener('hashchange', () => {
  const element = document.getElementById(location.hash.slice(1));
  if (!element || disposed) return;
  recentAnchor = { element };
  replaySnapAllowed = false;
  resumeAnchorNavigation();
});
function resumeAnchorNavigation() {
  // Refresh restores scroll positions and can cancel a native smooth anchor
  // scroll. Keep the current navigation intent until manual input cancels it.
  cancelAnimationFrame(anchorFrame);
  anchorFrame = requestAnimationFrame(() => {
    // Media-context restoration can queue another RAF during refresh. Let both
    // the native default click and that restoration finish before reconciling.
    anchorFrame = requestAnimationFrame(() => {
      anchorFrame = 0;
      if (
        !disposed &&
        recentAnchor &&
        location.hash === `#${recentAnchor.element.id}`
      )
        scrollToChapter(recentAnchor.element, reduced() ? 'instant' : 'smooth');
    });
  });
}
// Include ScrollTrigger's own delayed resize/font measurements. Its refresh
// restores scroll behavior on the next frame, so resume after that restoration.
ScrollTrigger.addEventListener('refresh', resumeAnchorNavigation);
function rememberReplayRefresh() {
  layoutRefreshing = true;
  if (!recentAnchor && !mediaPosition && storyFrame.chapter === 'replay')
    refreshPosition = lastReplayPosition;
}
function restoreReplayRefresh() {
  layoutRefreshing = false;
  const saved = refreshPosition;
  refreshPosition = undefined;
  if (saved && !disposed && !recentAnchor) restoreStagePosition(saved);
}
ScrollTrigger.addEventListener('refreshInit', rememberReplayRefresh);
ScrollTrigger.addEventListener('refresh', restoreReplayRefresh);
function needsChoreographyRefresh() {
  if (choreographyReduced !== reduced()) return true;
  if (reduced()) return stages.size > 0;
  return (['hero', 'experience', 'replay'] as const).some((chapter) => {
    const stage = document.querySelector<HTMLElement>(
      `[data-story-stage="${chapter}"]`,
    );
    const trigger = stages.get(chapter)?.trigger;
    const shouldPin =
      desktop.matches &&
      !!stage &&
      stage.scrollHeight <=
        window.innerHeight -
          (chapter === 'experience' ? 104 : chapter === 'replay' ? 88 : 50);
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
        if (needsChoreographyRefresh()) refreshChoreography();
        else ScrollTrigger.refresh();
        updateStory();
      }
    }, 200);
  },
  { passive: true },
);
function applyMotion() {
  if (reduced()) scoringFeedback?.cancel();
  if (reduced()) demoInvitation?.cancel();
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
    let replayPresentation:
      ReturnType<typeof addReplayCardChoreography> | undefined;
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
      ['experience', 0.32],
      ['replay', 0.75],
    ] as const) {
      const stage = document.querySelector<HTMLElement>(
        `[data-story-stage="${chapter}"]`,
      );
      if (!stage) continue;
      const value = { progress: 0 };
      // Expanded text is allowed to flow naturally instead of being clipped by a pinned viewport.
      const canPin =
        isDesktop &&
        stage.scrollHeight <=
          window.innerHeight -
            (chapter === 'experience' ? 104 : chapter === 'replay' ? 88 : 50);
      const replayShell =
        chapter === 'replay' && canPin ? stage.parentElement! : undefined;
      const replayTravel = () => Math.max(0, innerHeight * 0.5 - 88);
      const sizeReplayShell = () => {
        if (replayShell)
          replayShell.style.height = `${stage.offsetHeight - replayTravel()}px`;
      };
      sizeReplayShell();
      const timeline = gsap.timeline({
        scrollTrigger: {
          id: `story-${chapter}`,
          trigger: replayShell ?? stage,
          start: canPin
            ? chapter === 'hero'
              ? 'top top'
              : chapter === 'replay'
                ? 'top 50%'
                : 'top 88px'
            : chapter === 'replay' && isDesktop
              ? 'top 85%'
              : 'top 75%',
          end: () =>
            canPin
              ? `+=${window.innerHeight * extra}`
              : chapter === 'replay' && isDesktop
                ? 'top 88px'
                : 'bottom 25%',
          pin: replayShell ?? canPin,
          pinSpacing: true,
          scrub: chapter === 'replay' ? 0.18 : 0.55,
          invalidateOnRefresh: true,
          onRefreshInit: sizeReplayShell,
          snap: replayShell
            ? {
                snapTo: (progress, trigger) =>
                  replaySnapAllowed &&
                  !recentAnchor &&
                  !suspension.size &&
                  (trigger?.direction ?? 0) > 0 &&
                  progress >= 0.84 &&
                  progress < 1
                    ? 1
                    : progress,
                inertia: false,
                delay: 0.12,
                duration: { min: 0.24, max: 0.42 },
                ease: 'power2.out',
              }
            : undefined,
          onRefresh: (trigger) => {
            stage.dataset.storyRestTop = chapter === 'hero' ? '0' : '88';
            stage.dataset.storyStart = String(trigger.start);
            stage.dataset.storyEnd = String(trigger.end);
            stage.dataset.storyProgress = value.progress.toFixed(4);
            const entry = stages.get(chapter);
            if (entry) entry.progress = value.progress;
            if (chapter === 'replay') {
              stage.dataset.replayStart = String(trigger.start);
              stage.dataset.replayEnd = String(trigger.end);
              replayPresentation?.update();
            }
            updateStory();
          },
        },
        onUpdate: () => {
          const entry = stages.get(chapter);
          if (entry) entry.progress = value.progress;
          stage.dataset.storyProgress = value.progress.toFixed(4);
          if (chapter === 'replay') replayPresentation?.update();
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
      } else if (chapter === 'replay' && isDesktop) {
        replayPresentation = addReplayCardChoreography(timeline, stage);
        if (replayShell)
          timeline.to(
            stage,
            {
              y: () => -replayTravel(),
              duration: 1,
              ease: 'sine.out',
              force3D: true,
            },
            0,
          );
      }
    }
    if (!isDesktop) {
      for (const element of document.querySelectorAll<HTMLElement>(
        '.demo-map, .replay-editorial > *, .download-package',
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
      replayPresentation?.restore();
      document
        .querySelector<HTMLElement>('[data-replay-scroll-shell]')
        ?.style.removeProperty('height');
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
      refreshChoreography();
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
    // New font metrics usually need measurements, not a media-context rebuild:
    // reverting that context would cut off the still-playing opening reveal.
    if (needsChoreographyRefresh()) refreshChoreography();
    else ScrollTrigger.refresh();
    const target = document.getElementById(location.hash.slice(1));
    if (target && recentAnchor) scrollToChapter(target, 'instant');
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
  scoreInvitationObserver.disconnect();
  viewer.dispose();
  scoringFeedback?.cancel();
  demoInvitation?.cancel();
  stopFlight();
  stopScene();
  choreography.revert();
  cancelAnimationFrame(scrollFrame);
  cancelAnimationFrame(anchorFrame);
  ScrollTrigger.removeEventListener('refresh', resumeAnchorNavigation);
  ScrollTrigger.removeEventListener('refreshInit', rememberReplayRefresh);
  ScrollTrigger.removeEventListener('refresh', restoreReplayRefresh);
  mediaEvents.removeEventListener('matchMediaInit', rememberDemoPosition);
  mediaEvents.removeEventListener('matchMedia', restoreDemoPosition);
  clearTimeout(resizeTimer);
  clearTimeout(motionTimer);
});
window.addEventListener('pageshow', () => {
  setSuspended('page-cache', false);
  setSuspended('hidden', document.hidden);
  onScroll();
});
applyMotion();
