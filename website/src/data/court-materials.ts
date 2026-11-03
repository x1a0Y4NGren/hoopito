/** Loaded only by the eligible desktop scene; shared with the build resource budget. */
export const courtTextures = {
  maple: '/textures/maple-albedo-v4.webp',
  mapleDetail: '/textures/maple-detail-v4.webp',
  metal: '/textures/graphite-metal-v2.webp',
  glass: '/textures/glass-detail.webp',
  leather: '/textures/basketball-leather-v4.webp',
  leatherDetail: '/textures/basketball-height-v4.webp',
} as const;

/** Explicit color intent prevents data textures from accidentally receiving sRGB conversion. */
export const courtTextureUsage: Record<
  keyof typeof courtTextures,
  'color' | 'data'
> = {
  maple: 'color',
  mapleDetail: 'data',
  metal: 'color',
  glass: 'data',
  leather: 'color',
  leatherDetail: 'data',
};
