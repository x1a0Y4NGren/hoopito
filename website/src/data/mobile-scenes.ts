/** Phone plates are exported from the same court and reading cameras as desktop. */
export const mobileScenes = [
  {
    id: 'hero',
    chapter: 'hero',
    captureId: 'mobile-hero',
    src: '/art/scene-mobile-hero.webp',
    cropCenter: 0.74,
  },
  {
    id: 'court',
    chapter: 'scoring',
    captureId: 'mobile-court',
    src: '/art/scene-mobile-court.webp',
    cropCenter: 0.5,
  },
  {
    id: 'hoop',
    chapter: 'download',
    captureId: 'mobile-hoop',
    src: '/art/scene-mobile-hoop.webp',
    cropCenter: 0.5,
  },
] as const;

export type MobileSceneId = (typeof mobileScenes)[number]['id'];
