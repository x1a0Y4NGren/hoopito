import { gsap } from 'gsap';
import { ScrollTrigger } from 'gsap/ScrollTrigger';
import { createAnimationClock } from './animation-clock';
import { initialDemoState, reduceDemo, type DemoAction } from './demo-state';
import { createScreenshotViewer } from './screenshot-viewer';
import { createDownloadChooser } from './download-chooser';
import { createShotFeedback } from './shot-feedback';
import { createScoringFeedback } from './scoring-feedback';
import { createDemoInvitation } from './demo-invitation';
import { createReplayPresentation } from './replay-cards';
import { createChapterRail } from './chapter-rail';
import { createMobileNavigation } from './mobile-navigation';
import { createMobilePresentation } from './mobile-presentation';
import { createMobileProgress } from './mobile-progress';
import { createMobileTouch } from './mobile-touch';
import { mobileContentBottom } from './mobile-reading';
import { createDemoArt } from './demo-art';
import {
  storyItemPose,
  storyStageState,
  storyStageOffset,
  storyOrnamentVisibility,
  stageLayoutHeight,
  type StoryRole,
  type StoryEnter,
} from './story-choreography';
import { createSceneCommitGuard } from './scene-commit';
import {
  cameraStateAtScroll,
  isOverheadReadingFrame,
  transitionReadingRegion,
} from './camera-track';
import {
  createChapterScroll,
  type ChapterStop,
  type StopId,
} from './chapter-scroll';
import type {
  CourtPoint,
  GlassSurface,
  CourtScene,
  StoryChapter,
  StoryFrame,
  SceneRegion,
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
const chapterIds: StoryChapter[] = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
  'community',
];
let navigationChapter: StoryChapter | undefined;
let readingStop: StopId = 'hero';
let chapterScroll: ReturnType<typeof createChapterScroll> | undefined;
let chapterRail: ReturnType<typeof createChapterRail> | undefined;
let mobilePresentation: ReturnType<typeof createMobilePresentation> | undefined;
let mobileProgress: ReturnType<typeof createMobileProgress> | undefined;
let mobileTouch: ReturnType<typeof createMobileTouch> | undefined;
let readingStops: ChapterStop[] = [];
root.dataset.scrollStop = readingStop;
function syncCurrentNavigation(chapter: StoryChapter) {
  if (navigationChapter === chapter) return;
  navigationChapter = chapter;
  for (const link of chapterLinks) {
    if (link.hash === `#${chapter}`)
      link.setAttribute('aria-current', 'location');
    else link.removeAttribute('aria-current');
  }
  syncLanguage(
    phone.matches
      ? readingStop
      : readingStop === 'closing'
        ? 'closing'
        : chapter,
  );
}
const select = <T extends Element>(selector: string) =>
  document.querySelector<T>(selector)!;
const canvas = select<HTMLCanvasElement>('#court-canvas');
const sceneBackground = select<HTMLElement>('.scene-background');
const siteHeader = select<HTMLElement>('.site-header');
let measuredHeaderHeight = 0;
function measureHeaderInset() {
  const height = siteHeader.getBoundingClientRect().height;
  if (
    !Number.isFinite(height) ||
    height <= 0 ||
    Math.abs(height - measuredHeaderHeight) < 0.5
  )
    return false;
  // Keep the base --header untouched: it controls the header's own min-height.
  // Only content safety spacing consumes this measured border-box height.
  chapterScroll?.prepareRefresh();
  measuredHeaderHeight = height;
  root.style.setProperty('--measured-header', `${height}px`);
  return true;
}
measureHeaderInset();
const experienceSection = select<HTMLElement>('#experience');
const traceBridge = select<HTMLElement>('.trace-bridge');
const desktop = matchMedia('(min-width: 1024px) and (pointer: fine)');
const phone = matchMedia('(max-width: 767px)');
const systemMotion = matchMedia('(prefers-reduced-motion: reduce)');
let scene: CourtScene | undefined;
let sceneGlassMode: 'webgl' | 'css' = 'css';
let shotFeedback: ReturnType<typeof createShotFeedback> | undefined;
let scoringFeedback: ReturnType<typeof createScoringFeedback> | undefined;
let demoInvitation: ReturnType<typeof createDemoInvitation> | undefined;
const animationClock = createAnimationClock(document.hidden ? ['hidden'] : []);
const suspension = animationClock.suspension;
function setSuspended(reason: string, paused: boolean) {
  if (paused) mobileTouch?.cancel();
  if (paused) chapterScroll?.cancel();
  animationClock.setSuspended(reason, paused);
  chapterRail?.setPaused(suspension.size > 0);
  mobilePresentation?.setPaused(suspension.size > 0);
  scene?.setPaused(suspension.size > 0);
  if (suspension.size) shotFeedback?.pause();
  else shotFeedback?.resume();
  if (suspension.size) scoringFeedback?.pause();
  else scoringFeedback?.resume();
  // A pause can precede the first invitation, so resuming an absent timeline
  // must also re-evaluate its current reading/visibility eligibility.
  if (!suspension.size && scoringFeedback) queueMicrotask(queueStoryUpdate);
  if (suspension.size) demoInvitation?.pause();
  else demoInvitation?.resume();
  if (!suspension.size) mobileTouch?.recoverGap();
}
const viewer = createScreenshotViewer((open) => setSuspended('viewer', open));
const downloadChooser = createDownloadChooser((open) =>
  setSuspended('download-dialog', open),
);
const mobileNavigation = createMobileNavigation((open) =>
  setSuspended('mobile-menu', open),
);
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
let scoreInvitationFrame = 0;
let scoringOnChapter = false;
function syncScoringFeedback(
  phase: ReturnType<typeof storyStageState>['phase'],
) {
  const stage = scoreDevice.closest<HTMLElement>('[data-story-stage]')!;
  const bounds = stage.getBoundingClientRect();
  const headerBottom = siteHeader.getBoundingClientRect().bottom;
  // A refresh can publish the new reading boundary one frame before anchor
  // reconciliation. Preserve the current idle chapter's local cue during that
  // frame; a gesture/navigation departure still owns cancellation immediately.
  const holdingReadingChapter =
    scoringOnChapter &&
    root.dataset.scrollState === 'idle' &&
    root.dataset.scrollStop === 'scoring' &&
    bounds.bottom > headerBottom &&
    bounds.top < innerHeight;
  const onChapter =
    desktop.matches && !reduced()
      ? phase === 'reading' || holdingReadingChapter
      : bounds.bottom > headerBottom && bounds.top < innerHeight;
  if (!onChapter) {
    cancelAnimationFrame(scoreInvitationFrame);
    scoreInvitationFrame = 0;
    if (scoringOnChapter) scoringFeedback?.cancel();
    scoringOnChapter = false;
    return;
  }
  scoringOnChapter = true;
  const first = scoreFeatures[0];
  const rect = first.getBoundingClientRect();
  const visible = Math.max(
    0,
    Math.min(rect.bottom, innerHeight) - Math.max(rect.top, headerBottom),
  );
  const ready =
    visible >= rect.height * 0.6 &&
    rect.height > 0 &&
    !suspension.size &&
    (!desktop.matches || reduced() || root.dataset.scrollState === 'idle');
  if (!ready || first.dataset.scoreInvitation !== 'idle') {
    cancelAnimationFrame(scoreInvitationFrame);
    scoreInvitationFrame = 0;
    return;
  }
  if (!scoreInvitationFrame)
    scoreInvitationFrame = requestAnimationFrame(() => {
      scoreInvitationFrame = 0;
      if (!disposed && scoringOnChapter && !suspension.size)
        scoringFeedback?.invite(reduced());
    });
}
let abort: AbortController | undefined;
let deadline: ReturnType<typeof setTimeout> | undefined;
const choreography = gsap.matchMedia();
const stages = new Map<
  StoryChapter,
  { progress: number; trigger: ScrollTrigger }
>();
let experienceRestRegion: SceneRegion | undefined;
let sceneFailed = false;
let disposed = false;
let state = initialDemoState();
let storyFrame: StoryFrame = { chapter: 'hero', progress: 0, active: true };
let storyUpdateQueued = false;
let sceneFrameQueued = false;
const sceneCommitChanged = createSceneCommitGuard();
function queueStoryUpdate() {
  if (storyUpdateQueued) return;
  storyUpdateQueued = true;
  queueMicrotask(() => {
    storyUpdateQueued = false;
    if (!disposed) updateStory();
  });
}
function queueSceneFrame() {
  if (sceneFrameQueued || root.dataset.scene !== '3d') return;
  sceneFrameQueued = true;
  queueMicrotask(() => {
    sceneFrameQueued = false;
    if (!disposed) scene?.flushFrame();
  });
}
const reduced = () => systemMotion.matches;
mobilePresentation = createMobilePresentation({
  reduced,
  requestUpdate: queueStoryUpdate,
  layoutChanged() {
    queueMicrotask(() => {
      if (disposed) return;
      chapterScroll?.prepareRefresh();
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(() => {
        if (disposed) return;
        if (needsChoreographyRefresh()) refreshChoreography();
        else ScrollTrigger.refresh();
        updateStory();
      }, 0);
    });
  },
});
if (suspension.size) mobilePresentation.setPaused(true);
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
const demoArt = createDemoArt(court, {
  eligible: () => !desktop.matches || sceneFailed,
});
const presets = [
  ...document.querySelectorAll<HTMLButtonElement>('[data-point-preset]'),
];
let demoHintReading = false;
let demoHintEligible = false;
demoInvitation = createDemoInvitation(
  courtHost,
  select<HTMLElement>('.point-presets'),
  record,
  {
    isReading: () => demoHintReading,
    canShowHint: () => demoHintEligible && !suspension.size,
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
    { scale: 0.98 },
    { scale: 1, duration: 0.18, ease: 'power2.out', clearProps: 'transform' },
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
  chapter: StopId | undefined = root.dataset.scrollStop as StopId | undefined,
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
  sceneGlassMode = 'css';
  courtHost.dataset.renderer = '2d';
  root.dataset.scene = '2d';
  root.dataset.glass = 'css';
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
  // Decode the first desktop poster image while the arena is preparing, before
  // its large texture shares the first chapter transition with WebGL drawing.
  const firstPreview = select<HTMLImageElement>('[data-desktop-preload]');
  firstPreview.loading = 'eager';
  void firstPreview.decode().catch(() => {});
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
      onGlassChange: (mode) => {
        sceneGlassMode = mode;
        if (root.dataset.scene === '3d') root.dataset.glass = mode;
      },
      onQualityChange: (quality) => {
        root.dataset.quality = quality;
        // Restore optical rectangles before the first full-quality draw.
        if (quality === 'full' && scene)
          scene.setGlassSurfaces(readGlassSurfaces());
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
    root.dataset.glass = sceneGlassMode;
  } catch {
    if (!controller.signal.aborted && abort === controller)
      stopScene('initialization');
  }
}
function updateStory() {
  const sections = chapterIds.map((id) => {
    const element = document.getElementById(id)!;
    return { element, bounds: element.getBoundingClientRect() };
  });
  const focus = Math.min(window.innerHeight * 0.3, 260);
  const pinned = sections.find(({ element }) => {
    const trigger = stages.get(element.id as StoryChapter)?.trigger;
    return trigger?.pin && scrollY >= trigger.start && scrollY <= trigger.end;
  });
  const current =
    pinned ??
    [...sections].reverse().find((section) => section.bounds.top <= focus) ??
    sections[0];
  const chapter = current.element.id as StoryChapter;
  const closingBounds = select<HTMLElement>('#closing').getBoundingClientRect();
  const closingActive =
    closingBounds.top <=
    select<HTMLElement>('.site-header').getBoundingClientRect().bottom + 26;
  const nextReadingStop =
    mobileProgress?.update() ?? (closingActive ? 'closing' : chapter);
  if (nextReadingStop !== readingStop) {
    readingStop = nextReadingStop;
    root.dataset.scrollStop = readingStop;
    syncLanguage(readingStop);
  }
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
  const progress = stage?.trigger.pin
    ? stage.progress
    : Math.max(0, Math.min(1, flowProgress));
  const cameraState = cameraStateAtScroll(scrollY, readingStops, chapter);
  storyFrame = { ...cameraState, progress, active: true };
  mobilePresentation?.update();
  demoArt.update();
  updateStoryItems(sections);
  chapterRail?.update();
  const hostBounds = courtHost.getBoundingClientRect();
  const smooth = (value: number) => value * value * (3 - 2 * value);
  const track = storyFrame.cameraTrack;
  // Retain the DOM presentation signal; the camera itself has one world track.
  const blend = isOverheadReadingFrame(storyFrame)
    ? 1
    : track?.to === 'experience'
      ? smooth(track.progress)
      : track?.from === 'experience'
        ? 1 - smooth(track.progress)
        : 0;
  const demoBounds = sections[2].bounds;
  const interactive =
    !!scene &&
    isOverheadReadingFrame(storyFrame) &&
    !layoutRefreshing &&
    !mediaPosition &&
    !refreshPosition &&
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
          : (reduced() || choreographyReduced !== reduced()) &&
              lastReplayPosition?.element === element
            ? lastReplayPosition.progress
            : undefined,
    };
  }
  const placement = {
    region: {
      left: hostBounds.left,
      top: hostBounds.top,
      width: hostBounds.width,
      height: hostBounds.height,
    },
    // A long natural-flow interval moves the live host while being read.
    // Flights join the accepted reading interval, including native landing tolerance.
    restRegion:
      experienceRestRegion &&
      transitionReadingRegion(
        experienceRestRegion,
        readingStops.find((stop) => stop.id === 'experience') ?? {
          readStart: 0,
          readEnd: 0,
        },
        track,
        Boolean(stages.get('experience')?.trigger.pin),
      ),
    blend,
    inputEnabled: interactive,
  };
  const surfaces = readGlassSurfaces();
  const sceneChanged =
    scene &&
    sceneCommitChanged(scene, {
      frame: storyFrame,
      placement,
      surfaces,
      viewport: {
        width: innerWidth,
        height: innerHeight,
        dpr: devicePixelRatio,
      },
    });
  if (sceneChanged) {
    scene!.setCameraPlacement(placement);
    scene!.setGlassSurfaces(surfaces);
    scene!.setStoryFrame(storyFrame);
  }
  // The hint needs the final camera projection, but must measure before this
  // update changes inherited lighting and section state.
  const experienceReading = storyStageState(
    'experience',
    scrollY,
    readingStops,
    storyFrame.cameraTrack,
  );
  const experienceRect = experienceStage.getBoundingClientRect();
  demoHintReading =
    desktop.matches && !reduced()
      ? experienceReading.phase === 'reading'
      : experienceRect.bottom > siteHeader.getBoundingClientRect().bottom &&
        experienceRect.top < innerHeight;
  demoHintEligible =
    demoHintReading &&
    !layoutRefreshing &&
    (!desktop.matches || reduced() || root.dataset.scrollState === 'idle') &&
    (!desktop.matches || !!root.dataset.sceneFallback || interactive);
  demoInvitation?.refresh();
  if (demoHintEligible) demoInvitation?.invite(reduced());
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
      ? Number(['replay', 'download', 'community'].includes(chapter))
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
  if (sceneChanged) queueSceneFrame();
}
let scrollFrame = 0;
let resizeTimer: ReturnType<typeof setTimeout> | undefined;
let motionTimer: ReturnType<typeof setTimeout> | undefined;
let choreographyReduced = reduced();

const initialAnchor = document.getElementById(location.hash.slice(1));
let recentAnchor: { element: HTMLElement } | undefined = initialAnchor
  ? { element: initialAnchor }
  : undefined;
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
  const trigger = stages.get(
    saved.element.dataset.storyStage as StoryChapter,
  )?.trigger;
  if (trigger?.pin && saved.progress !== undefined) {
    const top = trigger.start + (trigger.end - trigger.start) * saved.progress;
    window.scrollTo({ top, behavior: 'instant' });
    ScrollTrigger.update();
    trigger.animation?.progress(saved.progress);
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
  chapterScroll?.prepareRefresh();
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
    chapterScroll?.cancel();
    if (location.hash !== link!.hash)
      history.pushState(history.state, '', link!.hash);
    syncLanguage();
    if (element.id === 'main') element.focus({ preventScroll: true });
    if (phone.matches && readingStops.some((stop) => stop.id === element.id)) {
      recentAnchor = undefined;
      cancelAnimationFrame(anchorFrame);
      anchorFrame = 0;
      chapterScroll?.navigateTo(element.id as StopId, { instant: reduced() });
      return;
    }
    recentAnchor = { element };
    resumeAnchorNavigation();
  }
});
for (const input of ['wheel', 'touchstart', 'pointerdown', 'keydown']) {
  window.addEventListener(
    input,
    () => {
      recentAnchor = undefined;
      if (reduced() && lastReplayPosition)
        lastReplayPosition.progress = undefined;
    },
    {
      passive: true,
    },
  );
}
function chapterScrollTop(element: HTMLElement) {
  if (element.id === 'hero' || element.id === 'main') {
    return 0;
  }
  const heading = element.querySelector<HTMLElement>('.section-top');
  const inset =
    select<HTMLElement>('.site-header').getBoundingClientRect().bottom + 20;
  const stage = element.matches('[data-story-stage]')
    ? element
    : element.querySelector<HTMLElement>('[data-story-stage]');
  const trigger = stages.get(element.id as StoryChapter)?.trigger;
  let top = scrollY + (heading ?? element).getBoundingClientRect().top - inset;
  if (stage && trigger?.pin) {
    const localOffset = heading
      ? heading.getBoundingClientRect().top - stage.getBoundingClientRect().top
      : 0;
    const rest = Number(stage.dataset.storyRestTop);
    const delta = rest + localOffset - inset;
    // Navigate into a settled reading/interaction state of the shared story.
    top =
      trigger.start + (trigger.end - trigger.start) * 0.4 + Math.max(0, delta);
  }
  return Math.max(0, top);
}
function scrollToChapter(element: HTMLElement, behavior: ScrollBehavior) {
  chapterScroll?.cancel();
  window.scrollTo({ top: chapterScrollTop(element), behavior });
}
window.addEventListener('hashchange', () => {
  chapterScroll?.cancel();
  const element = document.getElementById(location.hash.slice(1));
  if (!element || disposed) return;
  recentAnchor = { element };
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
        scrollToChapter(
          recentAnchor.element,
          phone.matches || reduced() ? 'instant' : 'smooth',
        );
    });
  });
}
// Include ScrollTrigger's own delayed resize/font measurements. Its refresh
// restores scroll behavior on the next frame, so resume after that restoration.
ScrollTrigger.addEventListener('refresh', resumeAnchorNavigation);
function rememberReplayRefresh() {
  chapterScroll?.prepareRefresh();
  layoutRefreshing = true;
  // Block native input before temporary pin/ROI geometry is exposed.
  courtPress = undefined;
  root.dataset.interactive = 'false';
  if (!recentAnchor && !mediaPosition && storyFrame.chapter === 'replay') {
    // Native input may have arrived before the next story RAF. Regular refresh
    // starts before pins are reverted, so capture today's scroll and geometry
    // instead of restoring the previous rendered playhead over that input.
    const element = select<HTMLElement>('[data-story-stage="replay"]');
    const trigger = stages.get('replay')?.trigger;
    refreshPosition = {
      element,
      top: element.getBoundingClientRect().top,
      progress:
        trigger?.pin && scrollY >= trigger.start && scrollY <= trigger.end
          ? (scrollY - trigger.start) / Math.max(1, trigger.end - trigger.start)
          : undefined,
    };
  }
}
function restoreReplayRefresh() {
  layoutRefreshing = false;
  const saved = refreshPosition;
  refreshPosition = undefined;
  if (saved && !disposed && !recentAnchor) restoreStagePosition(saved);
  refreshReadingStops();
}
ScrollTrigger.addEventListener('refreshInit', rememberReplayRefresh);
ScrollTrigger.addEventListener('refresh', restoreReplayRefresh);
function needsChoreographyRefresh() {
  if (choreographyReduced !== reduced()) return true;
  if (reduced()) return stages.size > 0;
  return chapterIds.some((chapter) => {
    const element = document.querySelector<HTMLElement>(
      `[data-story-stage="${chapter}"]`,
    );
    const trigger = stages.get(chapter)?.trigger;
    return (
      !!element && (!trigger || Boolean(trigger.pin) !== canPinStage(element))
    );
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
    chapterScroll?.prepareRefresh();
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
  chapterScroll?.cancel();
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
function stageRestTop(stage: HTMLElement) {
  if (stage.dataset.storyStage === 'hero') return 0;
  const heading = stage.querySelector<HTMLElement>('.section-top');
  const offset = heading
    ? heading.getBoundingClientRect().top - stage.getBoundingClientRect().top
    : 0;
  return (
    select<HTMLElement>('.site-header').getBoundingClientRect().bottom +
    20 -
    offset
  );
}
function canPinStage(stage: HTMLElement) {
  const available =
    stage.dataset.storyStage === 'hero'
      ? innerHeight + 1
      : innerHeight - stageRestTop(stage) - 16;
  // Child transforms can enlarge scrollHeight during an entrance. The border
  // box is the static grid's real layout footprint and does not include them.
  const footprint = stageLayoutHeight(
    stage.offsetHeight,
    [...stage.children]
      .filter((child): child is HTMLElement => child instanceof HTMLElement)
      .map((child) => child.offsetTop + child.offsetHeight),
    parseFloat(getComputedStyle(stage).paddingBottom) || 0,
  );
  return desktop.matches && !reduced() && footprint <= available;
}
const replayPresentation = createReplayPresentation(
  select<HTMLElement>('[data-story-stage="replay"]'),
);
const glassCards = [
  ...document.querySelectorAll<HTMLElement>('[data-glass-card]'),
];
const storyItems = [
  ...document.querySelectorAll<HTMLElement>('[data-story-item]'),
];
const storyOrnaments = [
  ...document.querySelectorAll<HTMLElement>(
    '.section-top, .hero-topline, .hero-floor',
  ),
];
const lastItemPose = new WeakMap<HTMLElement, string>();
const stageBottomInsets = new WeakMap<HTMLElement, number>();
function updateStoryItems(
  sections: { element: HTMLElement; bounds: DOMRect }[],
) {
  // Read every static stage position before applying any component transform.
  // The resulting optical rectangles are then measured by updateStory once.
  const layouts: {
    chapter: StoryChapter | 'closing';
    stage: HTMLElement;
    state: ReturnType<typeof storyStageState>;
    offset: number;
  }[] = [];
  for (const chapter of [...chapterIds, 'closing'] as const) {
    const stage = select<HTMLElement>(
      chapter === 'closing' ? '#closing' : `[data-story-stage="${chapter}"]`,
    );
    if (!stage) continue;
    const entry = chapter === 'closing' ? undefined : stages.get(chapter);
    const bounds =
      sections.find(({ element }) => element === stage)?.bounds ??
      stage.getBoundingClientRect();
    const state = storyStageState(
      chapter,
      scrollY,
      readingStops,
      storyFrame.cameraTrack,
    );
    // Community flows naturally into FAQ: both share the final camera endpoint.
    if (
      chapter === 'community' &&
      !storyFrame.cameraTrack &&
      state.progress === 1
    )
      state.phase = 'reading';
    const offset =
      desktop.matches && !reduced() && chapter !== 'closing'
        ? storyStageOffset(state, {
            scroll: scrollY,
            top: bounds.top,
            pinned: Boolean(entry?.trigger.pin),
            restTop: entry?.trigger.pin ? stageRestTop(stage) : undefined,
          })
        : 0;
    layouts.push({ chapter, stage, state, offset });
  }
  for (const { chapter, stage, state, offset } of layouts) {
    for (const ornament of stage.querySelectorAll<HTMLElement>(
      '.section-top, .hero-topline, .hero-floor',
    )) {
      const visibility = storyOrnamentVisibility(state, {
        secondary: ornament.classList.contains('hero-floor'),
        reduced: reduced(),
        mobile: !desktop.matches || chapter === 'closing',
        focused: ornament.contains(document.activeElement),
      });
      const opacity = String(visibility.opacity);
      if (ornament.style.opacity !== opacity) ornament.style.opacity = opacity;
      ornament.inert = visibility.inert;
    }
    if (chapter === 'replay')
      replayPresentation.update(
        reduced() ||
          !desktop.matches ||
          state.phase === 'reading' ||
          state.phase === 'outgoing'
          ? 1
          : state.phase === 'incoming'
            ? storyItemPose(state.progress, 'visual', 'left', 0, {
                phase: 'incoming',
                preset: 'replay-analysis',
              }).reveal * 0.22
            : state.progress,
      );
    for (const item of stage.querySelectorAll<HTMLElement>(
      '[data-story-item]',
    )) {
      const role = (item.dataset.storyItem || 'visual') as StoryRole;
      const direction = (item.dataset.storyEnter || 'left') as StoryEnter;
      const pose =
        mobilePresentation?.itemPose(item, role, chapter) ??
        storyItemPose(state.progress, role, direction, innerWidth, {
          hero: chapter === 'hero',
          chapter,
          phase: state.phase,
          preset: item.dataset.storyPreset,
          reduced: reduced(),
          focused: item.contains(document.activeElement),
          mobile: !desktop.matches || chapter === 'closing',
        });
      const y = pose.y + (pose.opacity > 0 ? offset : 0);
      const key = [pose.x, y, pose.scale, pose.opacity, pose.reveal].join(',');
      if (lastItemPose.get(item) !== key) {
        gsap.set(item, {
          x: pose.x,
          y,
          scale: pose.scale,
          opacity: pose.opacity,
          force3D: pose.opacity > 0 && pose.opacity < 1,
        });
        for (const wrapper of item.querySelectorAll<HTMLElement>(
          '[data-story-reveal]',
        )) {
          // Only inner content reveals; the glass outline/ROI stays rectangular.
          if (!wrapper.hasAttribute('data-glass-card'))
            wrapper.style.setProperty('--story-reveal', String(pose.reveal));
        }
        lastItemPose.set(item, key);
      }
      // Keep hidden controls out of both pointer and keyboard navigation.
      // Unlike inline styles, inert cannot be restored by GSAP context cleanup.
      item.inert = pose.opacity < 0.05;
    }
    if (chapter === 'scoring') syncScoringFeedback(state.phase);
  }
}
function readGlassSurfaces(): GlassSurface[] {
  // CSS fallback needs no screen-space optical measurements while scrolling.
  if (root.dataset.quality && root.dataset.quality !== 'full') return [];
  return glassCards
    .flatMap((card) => {
      const bounds = card.getBoundingClientRect();
      const style = getComputedStyle(card);
      const opacity = Number(style.opacity);
      if (
        opacity <= 0.001 ||
        bounds.bottom < 0 ||
        bounds.top > innerHeight ||
        bounds.right < 0 ||
        bounds.left > innerWidth
      )
        return [];
      return [
        {
          id: card.dataset.glassId!,
          region: {
            left: bounds.left,
            top: bounds.top,
            width: bounds.width,
            height: bounds.height,
          },
          radius:
            (parseFloat(style.borderTopLeftRadius) || 24) *
            (bounds.width / Math.max(1, card.offsetWidth)),
          opacity,
        },
      ];
    })
    .slice(0, 6);
}
choreography.add(
  {
    desktop: '(min-width: 1024px) and (pointer: fine)',
    reduce: '(prefers-reduced-motion: reduce)',
  },
  () => {
    choreographyReduced = reduced();
    stages.clear();
    if (reduced()) {
      updateStory();
      return;
    }
    for (const chapter of chapterIds) {
      const stage = select<HTMLElement>(`[data-story-stage="${chapter}"]`);
      if (!stage) continue;
      const pin = canPinStage(stage);
      const trigger = ScrollTrigger.create({
        id: `story-${chapter}`,
        trigger: stage,
        start: () =>
          chapter === 'hero'
            ? 'top top'
            : pin
              ? `top ${stageRestTop(stage)}px`
              : 'top 90%',
        end: pin ? () => `+=${innerHeight * 1.15}` : 'bottom 112px',
        pin,
        pinSpacing: true,
        invalidateOnRefresh: true,
        onRefresh(trigger) {
          stage.dataset.storyRestTop = String(stageRestTop(stage));
          stage.dataset.storyStart = String(trigger.start);
          stage.dataset.storyEnd = String(trigger.end);
          stage.dataset.storyProgress = trigger.progress.toFixed(4);
          const entry = stages.get(chapter);
          if (entry) entry.progress = trigger.progress;
          if (chapter === 'replay') {
            stage.dataset.replayStart = String(trigger.start);
            stage.dataset.replayEnd = String(trigger.end);
          }
        },
        onUpdate(trigger) {
          const entry = stages.get(chapter);
          if (entry) entry.progress = trigger.progress;
          stage.dataset.storyProgress = trigger.progress.toFixed(4);
          queueStoryUpdate();
        },
      });
      stages.set(chapter, { progress: trigger.progress, trigger });
    }
    updateStory();
    return () => {
      stages.clear();
      storyOrnaments.forEach((ornament) => {
        ornament.style.removeProperty('opacity');
        ornament.inert = false;
      });
      lastItemPose &&
        storyItems.forEach((item) => {
          gsap.set(item, { clearProps: 'transform,opacity' });
          item.style.removeProperty('--story-reveal');
          for (const wrapper of item.querySelectorAll<HTMLElement>(
            '[data-story-reveal]',
          ))
            wrapper.style.removeProperty('--story-reveal');
          item.inert = false;
          lastItemPose.delete(item);
        });
    };
  },
);
// Optical rectangles also follow content changes (details, fonts, focus), not
// just scrolling. Transforms do not resize the observed content boxes.
const observedCardSizes = new WeakMap<
  Element,
  { width: number; height: number }
>();
function scheduleContentRefresh() {
  if (disposed) return;
  // Preserve a committed destination before the debounce can outlive its tween.
  chapterScroll?.prepareRefresh();
  onScroll();
  clearTimeout(resizeTimer);
  resizeTimer = setTimeout(() => {
    if (disposed) return;
    if (needsChoreographyRefresh()) refreshChoreography();
    else ScrollTrigger.refresh();
    updateStory();
  }, 120);
}
function onDisclosureToggle(event: Event) {
  // Native details can expand while a browser defers resize delivery. Their
  // semantic event guarantees a new reading map, without waiting for that
  // observer or rebuilding unrelated pins on every animation frame.
  if (
    event.target instanceof HTMLDetailsElement &&
    event.target.closest('main, #closing')
  )
    scheduleContentRefresh();
}
document.addEventListener('toggle', onDisclosureToggle, true);
const cardResizeObserver = new ResizeObserver((entries) => {
  if (disposed) return;
  let changed = false;
  for (const entry of entries) {
    if (entry.target === siteHeader && measureHeaderInset()) changed = true;
    const previous = observedCardSizes.get(entry.target);
    const { width, height } = entry.contentRect;
    observedCardSizes.set(entry.target, { width, height });
    if (
      previous &&
      (Math.abs(previous.width - width) > 1 ||
        Math.abs(previous.height - height) > 1)
    )
      changed = true;
  }
  // Initial observation and subpixel pin rounding do not change document layout.
  // Rebuilding pins for those samples could interrupt the first wheel transition.
  if (!changed) return;
  scheduleContentRefresh();
});
for (const element of new Set<Element>([
  siteHeader,
  ...glassCards,
  ...storyItems,
  ...document.querySelectorAll('[data-story-stage]'),
]))
  cardResizeObserver.observe(element);
cardResizeObserver.observe(select<HTMLElement>('#closing'));

function refreshReadingStops() {
  mobilePresentation?.invalidate();
  const maxScroll = Math.max(
    0,
    document.documentElement.scrollHeight - innerHeight,
  );
  const clamp = (value: number) => Math.max(0, Math.min(maxScroll, value));
  const readingLine =
    select<HTMLElement>('.site-header').getBoundingClientRect().bottom + 24;
  readingStops = ([...chapterIds, 'closing'] as const).map((id) => {
    const element = select<HTMLElement>(`#${id}`);
    const stage =
      id === 'closing'
        ? element
        : select<HTMLElement>(`[data-story-stage="${id}"]`);
    const trigger = id === 'closing' ? undefined : stages.get(id)?.trigger;
    const pin = trigger?.pin;
    const readStart = clamp(chapterScrollTop(element));
    const bottom = scrollY + stage.getBoundingClientRect().bottom;
    const top = scrollY + stage.getBoundingClientRect().top;
    const bottomInset =
      id === 'closing'
        ? 0
        : parseFloat(getComputedStyle(stage).paddingBottom) || 0;
    stageBottomInsets.set(stage, bottomInset);
    const contentBottom = phone.matches
      ? mobileContentBottom(element)
      : bottom - bottomInset;
    const readEnd =
      phone.matches && id === 'closing'
        ? maxScroll
        : pin
          ? readStart
          : Math.max(readStart, clamp(contentBottom - innerHeight + 16));
    stage.dataset.scrollReadStart = readStart.toFixed(3);
    stage.dataset.scrollReadEnd = readEnd.toFixed(3);
    return {
      id,
      readStart,
      readEnd,
      entryStart: clamp(pin ? trigger!.start : top - innerHeight * 0.92),
      entryEnd: clamp(
        pin
          ? trigger!.start + (trigger!.end - trigger!.start) * 0.22
          : top - readingLine,
      ),
      exitStart: clamp(
        pin
          ? trigger!.start + (trigger!.end - trigger!.start) * 0.78
          : contentBottom - innerHeight + 16,
      ),
      exitEnd: clamp(pin ? trigger!.end : contentBottom - readingLine),
    };
  });
  // The map/host have no story-item transforms; subtracting their shared stage
  // translation removes pin motion while preserving fractional grid geometry.
  // Cache once per layout refresh, never from the moving host during flight.
  const stageBounds = experienceStage.getBoundingClientRect();
  const hostBounds = courtHost.getBoundingClientRect();
  experienceRestRegion = {
    left: hostBounds.left,
    top: stageRestTop(experienceStage) + hostBounds.top - stageBounds.top,
    width: hostBounds.width,
    height: hostBounds.height,
  };
  chapterScroll?.refresh();
  mobileTouch?.refresh();
  chapterRail?.refresh();
}
chapterScroll = createChapterScroll({
  getStops: () => readingStops,
  enabled: () => desktop.matches && !reduced() && !disposed && !suspension.size,
  canNavigate: () => !disposed && !suspension.size,
  write: (top) => {
    recentAnchor = undefined;
    cancelAnimationFrame(anchorFrame);
    anchorFrame = 0;
    window.scrollTo({ top, behavior: 'instant' });
    ScrollTrigger.update();
    queueStoryUpdate();
  },
  onState: (phase, targetStop) => {
    if (root.dataset.scrollState !== phase) root.dataset.scrollState = phase;
    queueStoryUpdate();
    if (phase !== 'settling' || !targetStop) return;
    const focused = document.activeElement;
    if (!(focused instanceof HTMLElement)) return;
    const focusedStage = focused.closest<HTMLElement>(
      '[data-story-stage], #closing',
    );
    const focusedStop = focusedStage?.dataset.storyStage ?? focusedStage?.id;
    if (focusedStop && focusedStop !== targetStop) {
      // A committed wheel departure releases its old control, so focus safety
      // cannot keep that entire card visible over the arriving chapter.
      // Same-stop tiny returns and focus outside the story remain untouched.
      focused.blur();
      queueStoryUpdate();
    }
  },
});
mobileProgress = createMobileProgress({ getStops: () => readingStops });
mobileTouch = createMobileTouch({
  getStops: () => readingStops,
  controller: () => chapterScroll,
  enabled: () =>
    phone.matches &&
    (navigator.maxTouchPoints > 0 ||
      ('ontouchstart' in window && matchMedia('(pointer: coarse)').matches)) &&
    !reduced() &&
    !disposed &&
    !suspension.size,
  requestUpdate: queueStoryUpdate,
});
chapterRail = createChapterRail({
  getStops: () => readingStops,
  reduced,
  canUse: () => !disposed && !suspension.size,
  controller: () => chapterScroll,
  requestUpdate: queueStoryUpdate,
  layoutChanged: () => {
    if (disposed) return;
    chapterScroll?.prepareRefresh();
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => {
      if (disposed) return;
      if (needsChoreographyRefresh()) refreshChoreography();
      else ScrollTrigger.refresh();
      updateStory();
    }, 0);
  },
  onNavigate: (id) => {
    recentAnchor = undefined;
    cancelAnimationFrame(anchorFrame);
    anchorFrame = 0;
    if (location.hash !== `#${id}`)
      history.pushState(history.state, '', `#${id}`);
    syncLanguage(id);
  },
});
refreshReadingStops();
document.addEventListener('focusin', onScroll);
document.addEventListener('focusin', () => chapterScroll?.cancel());
systemMotion.addEventListener('change', () => {
  mobileTouch?.cancel();
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
  chapterRail?.dispose();
  chapterScroll?.dispose();
  demoArt.dispose();
  cancelAnimationFrame(scoreInvitationFrame);
  viewer.dispose();
  downloadChooser.dispose();
  mobileNavigation.dispose();
  mobilePresentation?.dispose();
  mobileProgress?.dispose();
  mobileTouch?.dispose();
  scoringFeedback?.cancel();
  demoInvitation?.cancel();
  stopFlight();
  stopScene();
  cardResizeObserver.disconnect();
  document.removeEventListener('toggle', onDisclosureToggle, true);
  document.removeEventListener('focusin', onScroll);
  choreography.revert();
  replayPresentation.restore();
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
