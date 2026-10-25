import { readFile } from 'node:fs/promises';

export const presentation = JSON.parse(
  await readFile(
    new URL('../../docs/design/screenshot-presentation.json', import.meta.url),
    'utf8',
  ),
);

export function presentationForCapture(capture) {
  const name = capture.path
    .split('/')
    .at(-1)
    .replace(/^\d-/, '')
    .replace(/\.png$/, '');
  const rule = presentation.screenshots[name];
  if (!rule)
    throw new Error(`Missing screenshot presentation: ${capture.path}`);
  const [width, height] = capture.dimensions_px;
  if (
    width !== rule.source_dimensions_px[0] ||
    height !== rule.source_dimensions_px[1]
  ) {
    throw new Error(`Uncalibrated screenshot dimensions: ${capture.path}`);
  }
  const {
    left,
    top,
    width: croppedWidth,
    height: croppedHeight,
  } = rule.extract;
  if (
    ![left, top, croppedWidth, croppedHeight].every(Number.isInteger) ||
    left < 0 ||
    top < 0 ||
    croppedWidth <= 0 ||
    croppedHeight <= 0 ||
    left + croppedWidth > width ||
    top + croppedHeight > height
  )
    throw new Error(`Invalid screenshot presentation crop: ${capture.path}`);
  return { name, extract: { ...rule.extract } };
}
