export type MobileScene = 'hero' | 'court' | 'hoop';
export type MobileRole = 'heading' | 'visual' | 'control' | 'detail';
export interface MobileSceneAnchors {
  court: number;
  hoop: number;
  end: number;
}

/** Convert image weights to source-over alphas without a dark crossfade dip. */
export function mobileLayerOpacity(weights: Record<MobileScene, number>) {
  const ids = ['hero', 'court', 'hoop'] as const;
  const result = { hero: 0, court: 0, hoop: 0 };
  let covered = 0;
  for (const id of ids.toReversed()) {
    const weight = unit(weights[id]);
    result[id] = weight > 0 ? unit(weight / Math.max(weight, 1 - covered)) : 0;
    covered += weight;
  }
  return result;
}

const finite = (value: number, fallback = 0) =>
  Number.isFinite(value) ? value : fallback;
const unit = (value: number) => Math.max(0, Math.min(1, finite(value)));
const smooth = (value: number) => {
  const p = unit(value);
  return p * p * (3 - 2 * p);
};

export function mobileSceneForChapter(chapter: string): MobileScene {
  if (['download', 'community', 'closing'].includes(chapter)) return 'hoop';
  if (['scoring', 'experience', 'replay'].includes(chapter)) return 'court';
  return 'hero';
}

/** The same document position always has the same two-image composition. */
export function mobileBackdropPose(
  scroll: number,
  height: number,
  anchors: MobileSceneAnchors,
  reduced = false,
) {
  const y = finite(scroll);
  const view = Math.max(1, finite(height, 1));
  const court = finite(anchors.court, view);
  const hoop = Math.max(court, finite(anchors.hoop, court + view));
  const end = Math.max(hoop + 1, finite(anchors.end, hoop + view));
  const entry = (top: number) =>
    smooth((view * 0.7 - (top - y)) / (view * 0.4));
  const first = entry(court),
    second = entry(hoop);
  let opacity: Record<MobileScene, number> =
    second > 0
      ? { hero: 0, court: 1 - second, hoop: second }
      : { hero: 1 - first, court: first, hoop: 0 };
  if (reduced) {
    const scene = second >= 0.5 ? 'hoop' : first >= 0.5 ? 'court' : 'hero';
    opacity = {
      hero: Number(scene === 'hero'),
      court: Number(scene === 'court'),
      hoop: Number(scene === 'hoop'),
    };
  }
  const drift = (start: number, finish: number) =>
    reduced ? 0 : -6 + unit((y - start) / Math.max(1, finish - start)) * 12;
  return {
    opacity,
    y: {
      hero: drift(0, court),
      court: drift(court, hoop),
      hoop: drift(hoop, end),
    },
  };
}

export function mobileScenesToLoad(options: {
  phone: boolean;
  scroll: number;
  height: number;
  anchors: MobileSceneAnchors;
  scrolled: boolean;
  hash?: string;
}): MobileScene[] {
  if (!options.phone) return [];
  const result = new Set<MobileScene>(['hero']);
  if (options.hash)
    result.add(mobileSceneForChapter(options.hash.replace(/^#/, '')));
  if (options.scrolled) {
    const horizon =
      finite(options.scroll) + Math.max(1, finite(options.height, 1)) * 2;
    if (finite(options.anchors.court, Infinity) <= horizon) result.add('court');
    if (finite(options.anchors.hoop, Infinity) <= horizon) result.add('hoop');
  }
  return [...result];
}

/** Entries are local to each component, not the much longer chapter. */
export function mobileItemPose(
  top: number,
  height: number,
  role: MobileRole,
  options: {
    reduced?: boolean;
    focused?: boolean;
    stationary?: boolean;
    phone?: boolean;
  } = {},
) {
  const rest = { x: 0, y: 0, scale: 1, opacity: 1, reveal: 1 };
  if (
    options.phone === false ||
    options.reduced ||
    options.focused ||
    options.stationary
  )
    return rest;
  const view = Math.max(1, finite(height, 1));
  const progress = smooth((view * 0.94 - finite(top)) / (view * 0.26));
  const distance = role === 'visual' ? 20 : 12;
  const initial = role === 'visual' ? 0.45 : role === 'heading' ? 0.3 : 0.65;
  return {
    x: 0,
    y: (1 - progress) * distance,
    scale: role === 'visual' ? 0.99 + progress * 0.01 : 1,
    opacity: initial + (1 - initial) * progress,
    reveal: 1,
  };
}
