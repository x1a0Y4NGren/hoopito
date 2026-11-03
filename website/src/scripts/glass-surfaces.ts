import type { GlassSurface, SceneRegion } from './scene-contract';

export const MAX_GLASS_SURFACES = 6;

/** Reject invalid values before uploading uniforms; retain stable caller ordering. */
export function normalizeGlassSurfaces(
  surfaces: readonly GlassSurface[],
  viewport: SceneRegion,
): GlassSurface[] {
  if (
    !Object.values(viewport).every(Number.isFinite) ||
    viewport.width <= 0 ||
    viewport.height <= 0
  )
    return [];
  const result: GlassSurface[] = [];
  const ids = new Set<string>();
  for (const surface of surfaces) {
    const { region, id, opacity, radius } = surface;
    if (
      !id ||
      ids.has(id) ||
      ![...Object.values(region), opacity, radius].every(Number.isFinite) ||
      Object.values(region).some((value) => Math.abs(value) > 1_000_000) ||
      region.width <= 0 ||
      region.height <= 0 ||
      opacity <= 0
    )
      continue;
    const left = Math.max(viewport.left, region.left);
    const top = Math.max(viewport.top, region.top);
    const width =
      Math.min(viewport.left + viewport.width, region.left + region.width) -
      left;
    const height =
      Math.min(viewport.top + viewport.height, region.top + region.height) -
      top;
    if (width <= 0 || height <= 0) continue;
    result.push({
      id,
      region: { left, top, width, height },
      radius: Math.max(0, Math.min(radius, width / 2, height / 2)),
      opacity: Math.min(1, opacity),
    });
    ids.add(id);
    if (result.length === MAX_GLASS_SURFACES) break;
  }
  return result;
}
