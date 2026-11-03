import type { StoryFrame } from './scene-contract.ts';

/** Native-scroll pose: no mutable timeline state, so reversing scroll is exact. */
export function cardPose(
  progress: number,
  side: 'left' | 'right',
  travel: number,
  options?: { hero?: boolean; reduced?: boolean },
): { x: number; y: number; scale: number; opacity: number } {
  const settled = { x: 0, y: 0, scale: 1, opacity: 1 };
  if (options?.reduced) return settled;

  const position = Number.isFinite(progress)
    ? Math.min(1, Math.max(0, progress))
    : 0;
  const distance = Number.isFinite(travel) ? Math.max(0, travel) : 0;
  const direction = side === 'left' ? -1 : 1;
  if (position < 0.22 && !options?.hero) {
    const entered = smoothstep(position / 0.22);
    return {
      x: distance === 0 ? 0 : direction * distance * (1 - entered),
      y: 0,
      scale: 0.94 + 0.06 * entered,
      opacity: entered,
    };
  }
  if (position <= 0.78) return settled;

  const exited = smoothstep((position - 0.78) / (1 - 0.78));
  return {
    x: distance === 0 ? 0 : -direction * distance * exited,
    y: 0,
    scale: 1 - 0.03 * exited,
    opacity: 1 - exited,
  };
}

function smoothstep(value: number): number {
  return value * value * (3 - 2 * value);
}

export type StoryRole = 'heading' | 'visual' | 'control' | 'detail';
/** A GSAP pin can fix the border box while its natural grid content grows. */
export function stageLayoutHeight(
  height: number,
  childBottoms: readonly number[],
  paddingBottom: number,
): number {
  return Math.max(
    height,
    ...childBottoms.map((bottom) => bottom + paddingBottom),
  );
}
export type StoryEnter = 'left' | 'right' | 'up' | 'down';
export type StoryItemPose = {
  x: number;
  y: number;
  scale: number;
  opacity: number;
  /** Applied only to an explicitly marked inner reveal wrapper. */
  reveal: number;
};

export type StoryItemPhase = 'incoming' | 'outgoing' | 'reading' | 'hidden';
export interface StoryStageState {
  phase: StoryItemPhase;
  progress: number;
  anchorScroll: number;
}
interface StoryReadingStop {
  id: string;
  readStart: number;
  readEnd: number;
}

/** Camera and components share exactly one track; native reading remains natural. */
export function storyStageState(
  chapter: string,
  scroll: number,
  stops: readonly StoryReadingStop[],
  track?: StoryFrame['cameraTrack'],
): StoryStageState {
  const position = Number.isFinite(scroll) ? scroll : 0;
  const stop = stops.find((item) => item.id === chapter);
  if (
    !stop ||
    !Number.isFinite(stop.readStart) ||
    !Number.isFinite(stop.readEnd)
  )
    return { phase: 'reading', progress: 1, anchorScroll: position };
  if (track?.from === chapter)
    return {
      phase: 'outgoing',
      progress: normalized(track.progress),
      anchorScroll: stop.readEnd + 2,
    };
  if (track?.to === chapter)
    return {
      phase: 'incoming',
      progress: normalized(track.progress),
      anchorScroll: stop.readStart - 2,
    };
  if (position >= stop.readStart - 2 && position <= stop.readEnd + 2)
    return { phase: 'reading', progress: 1, anchorScroll: position };
  return {
    phase: 'hidden',
    progress: position < stop.readStart ? 0 : 1,
    anchorScroll: position,
  };
}

/** Cancel document movement only during a flight, joining the real reading edge. */
export function storyStageOffset(
  state: StoryStageState,
  layout: { scroll: number; top: number; pinned?: boolean; restTop?: number },
): number {
  if (state.phase !== 'incoming' && state.phase !== 'outgoing') return 0;
  const offset = layout.pinned
    ? (layout.restTop ?? layout.top) - layout.top
    : layout.scroll - state.anchorScroll;
  return Number.isFinite(offset) ? offset : 0;
}

const trackWindows: Record<StoryRole, [number, number]> = {
  visual: [0.32, 0.88],
  heading: [0.5, 0.94],
  control: [0.7, 1],
  detail: [0.7, 1],
};
type StoryPreset = {
  fraction: number;
  vertical: number;
  scale: number;
  enter?: [number, number];
  /** Spatial departure clears bright content while retaining the same time window. */
  exitFraction?: number;
  exitVertical?: number;
  exitSameSide?: boolean;
};
const presets: Record<string, StoryPreset> = {
  'hero-title': { fraction: 0.12, vertical: 24, scale: 1 },
  'chapter-title': { fraction: 0.12, vertical: 24, scale: 1 },
  'scoring-screen': {
    fraction: 0.18,
    vertical: 56,
    scale: 0.98,
    exitFraction: 0.75,
  },
  'scoring-rail': { fraction: 0.12, vertical: 20, scale: 0.99 },
  'experience-scoreboard': {
    fraction: 0.12,
    vertical: 40,
    scale: 0.98,
    exitVertical: 350,
    exitSameSide: true,
  },
  'experience-controls': { fraction: 0.12, vertical: 20, scale: 0.99 },
  'replay-summary': {
    fraction: 0.14,
    vertical: 48,
    scale: 0.98,
    enter: [0.32, 0.84],
    exitFraction: 0.8,
  },
  'replay-analysis': {
    fraction: 0.16,
    vertical: 48,
    scale: 0.98,
    enter: [0.49, 0.94],
  },
  'replay-history': {
    fraction: 0.18,
    vertical: 48,
    scale: 0.98,
    enter: [0.66, 0.98],
  },
  'download-title': { fraction: 0.12, vertical: 24, scale: 1 },
  'download-card': {
    fraction: 0.14,
    vertical: 52,
    scale: 0.98,
    exitVertical: 380,
  },
  'community-poster': { fraction: 0.18, vertical: 48, scale: 0.98 },
  'community-copy': { fraction: 0.12, vertical: 20, scale: 0.99 },
};
const normalized = (value: number) =>
  Number.isFinite(value) ? unit(value) : 0;

const windows: Record<
  StoryRole,
  {
    enter: [number, number];
    exit: [number, number];
    distance: number;
    scale: number;
  }
> = {
  heading: { enter: [0, 0.16], exit: [0.84, 1], distance: 48, scale: 1 },
  visual: {
    enter: [0.025, 0.2],
    exit: [0.82, 0.98],
    distance: Infinity,
    scale: 0.965,
  },
  control: {
    enter: [0.05, 0.22],
    exit: [0.8, 0.96],
    distance: 96,
    scale: 0.99,
  },
  detail: { enter: [0.075, 0.22], exit: [0.78, 0.94], distance: 48, scale: 1 },
};
const unit = (value: number) => Math.max(0, Math.min(1, value));

/** Role windows all end before reading starts. No tween or mutable playhead. */
export function storyItemPose(
  progress: number,
  role: StoryRole,
  enter: StoryEnter,
  travel: number,
  options?: {
    hero?: boolean;
    reduced?: boolean;
    focused?: boolean;
    mobile?: boolean;
    phase?: StoryItemPhase;
    preset?: string;
    chapter?: string;
  },
): StoryItemPose {
  const rest = { x: 0, y: 0, scale: 1, opacity: 1, reveal: 1 };
  if (options?.reduced || options?.focused || options?.mobile) return rest;
  const p = Number.isFinite(progress) ? unit(progress) : 0;
  if (options?.phase) {
    if (
      options.phase === 'reading' ||
      (options.hero && options.phase === 'incoming')
    )
      return rest;
    if (options.phase === 'hidden') return { ...rest, opacity: 0, reveal: 0 };
    const profile: StoryPreset = presets[options.preset ?? ''] ?? {
      fraction: role === 'visual' ? 0.16 : 0.12,
      vertical: role === 'visual' ? 52 : role === 'heading' ? 24 : 20,
      scale: role === 'visual' ? 0.98 : role === 'heading' ? 1 : 0.99,
    };
    const incoming = options.phase === 'incoming';
    const entrance = profile.enter ?? trackWindows[role];
    // The same scroll mapping gives the same order on reverse without direction state.
    const window = incoming ? entrance : [1 - entrance[1], 1 - entrance[0]];
    const phase = smoothstep(unit((p - window[0]) / (window[1] - window[0])));
    const visible = incoming ? phase : 1 - phase;
    const horizontal = enter === 'left' || enter === 'right';
    const available = Number.isFinite(travel) ? Math.max(0, travel) : 0;
    const distance =
      available *
      (incoming
        ? profile.fraction
        : (profile.exitFraction ?? profile.fraction));
    const vertical =
      !incoming && profile.exitVertical !== undefined
        ? Math.min(profile.exitVertical, available)
        : Math.min(profile.vertical, distance);
    const amount =
      (enter === 'left' || enter === 'up' ? -1 : 1) *
      (incoming || profile.exitSameSide ? 1 : -1) *
      (horizontal ? distance : vertical) *
      (1 - visible);
    return {
      x: horizontal && amount !== 0 ? amount : 0,
      y: !horizontal && amount !== 0 ? amount : 0,
      scale: profile.scale + (1 - profile.scale) * visible,
      opacity: visible,
      reveal: visible,
    };
  }
  const profile = windows[role];
  const distance = Math.min(
    profile.distance,
    Number.isFinite(travel) ? Math.max(0, travel) : 0,
  );
  const sign = enter === 'left' || enter === 'up' ? -1 : 1;
  const horizontal = enter === 'left' || enter === 'right';
  let amount = 0;
  let opacity = 1;
  let scale = 1;
  if (p < 0.22 && !options?.hero) {
    const phase = smoothstep(
      unit((p - profile.enter[0]) / (profile.enter[1] - profile.enter[0])),
    );
    amount = sign * distance * (1 - phase);
    opacity = phase;
    scale = profile.scale + (1 - profile.scale) * phase;
  } else if (p > 0.78) {
    const phase = smoothstep(
      unit((p - profile.exit[0]) / (profile.exit[1] - profile.exit[0])),
    );
    amount = -sign * distance * phase;
    opacity = 1 - phase;
    scale = 1 - (1 - profile.scale) * phase * 0.5;
  }
  return {
    x: horizontal && amount !== 0 ? amount : 0,
    y: !horizontal && amount !== 0 ? amount : 0,
    scale,
    opacity,
    reveal: opacity,
  };
}

/** Fade static labels without moving the geometry used by pins and relay anchors. */
export function storyOrnamentVisibility(
  state: StoryStageState,
  options?: {
    secondary?: boolean;
    reduced?: boolean;
    mobile?: boolean;
    focused?: boolean;
  },
): { opacity: number; inert: boolean } {
  const { opacity } = storyItemPose(
    state.progress,
    options?.secondary ? 'detail' : 'heading',
    'up',
    0,
    { ...options, phase: state.phase },
  );
  return { opacity, inert: opacity < 0.05 };
}

/** Natural-flow content keeps a full reading interval, including short screens. */
export function stageItemProgress(layout: {
  top: number;
  bottom: number;
  readingLine: number;
  viewportHeight: number;
  scroll: number;
  readEnd: number;
  exitEnd: number;
  pinnedProgress?: number;
  hero?: boolean;
  mobile?: boolean;
}): number {
  if (layout.mobile) return 0.4;
  if (layout.pinnedProgress !== undefined) return unit(layout.pinnedProgress);
  if (layout.hero && layout.scroll === 0) return 0.4;
  if (layout.top > layout.readingLine)
    return (
      0.22 *
      unit(
        (layout.viewportHeight * 0.92 - layout.top) /
          Math.max(1, layout.viewportHeight * 0.92 - layout.readingLine),
      )
    );
  if (layout.scroll <= layout.readEnd + 1) return 0.4;
  return (
    0.78 +
    0.22 *
      unit(
        (layout.scroll - layout.readEnd) /
          Math.max(1, layout.exitEnd - layout.readEnd),
      )
  );
}
