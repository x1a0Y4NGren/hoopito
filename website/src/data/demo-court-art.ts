/** Registration is measured from the accepted generated sprite, not its center. */
const crop = { width: 1742, height: 704 };
const sourceRim = { cx: 865, cy: 410, rx: 273, ry: 273 };
const production = { width: 512, height: 207 };
const rim = { cx: 300, cy: 82, rx: 20 };
const scale = rim.rx / sourceRim.rx;

export const demoCourtArt = {
  floor: { src: '/art/demo-maple-v2.webp', tile: 272 },
  hoop: {
    src: '/art/demo-hoop-v2.webp',
    crop,
    sourceRim,
    production,
    rim: { ...rim, ry: sourceRim.ry * scale },
    placement: {
      x: rim.cx - sourceRim.cx * scale,
      y: rim.cy - sourceRim.cy * scale,
      width: crop.width * scale,
      height: (production.height / production.width) * crop.width * scale,
    },
  },
} as const;
