/** One design source; CSS uses display color, optics converts it to linear HDR. */
export const glassMaterial = Object.freeze({
  tintSrgb: '#151b1e',
  tintRgb: '21 27 30',
  opacity: 0.54,
  blurCssPx: 12,
  saturation: 0.9,
  densityOpacity: 0.9,
  reducedTransparencyOpacity: 0.97,
  readingOpacity: 0.18,
  exposedReadingOpacity: 0.58,
  edgeTopOpacity: 0.12,
  edgeSideOpacity: 0.07,
  edgeBottomOpacity: 0.035,
  bevelWidthPx: 5,
  refractionPx: 2.5,
  dispersionPx: 0,
  // Optical filtering is a small diffusion kernel, not a CSS blur-radius copy.
  diffusionSamplePx: 1.4,
  edgeEnergyLinear: 0.012,
  shadow: '0 12px 28px -18px rgb(0 0 0 / 0.24)',
});

/** Emitted by Astro at build time; no client-side Three.js import is required. */
export const glassMaterialStyles = Object.freeze({
  '--glass-rgb': glassMaterial.tintRgb,
  '--glass-fill-opacity': String(glassMaterial.opacity),
  '--glass-blur': `${glassMaterial.blurCssPx}px`,
  '--glass-saturation': String(glassMaterial.saturation),
  '--glass-density-opacity': String(glassMaterial.densityOpacity),
  '--glass-reduced-transparency-opacity': String(
    glassMaterial.reducedTransparencyOpacity,
  ),
  '--glass-reading-opacity': String(glassMaterial.readingOpacity),
  '--glass-exposed-reading-opacity': String(
    glassMaterial.exposedReadingOpacity,
  ),
  '--glass-edge-top': String(glassMaterial.edgeTopOpacity),
  '--glass-edge-side': String(glassMaterial.edgeSideOpacity),
  '--glass-edge-bottom': String(glassMaterial.edgeBottomOpacity),
  '--glass-shadow': glassMaterial.shadow,
});
