import assert from 'node:assert/strict';
import test from 'node:test';
import { demoCourtArt } from '../src/data/demo-court-art.ts';
import {
  netPoint,
  SHOT_TIMING,
  shotFrame,
} from '../src/scripts/shot-timing.ts';

const close = (actual: number, expected: number) =>
  assert.ok(
    Math.abs(actual - expected) < 1e-8,
    `${actual} differs from ${expected}`,
  );

test('the measured sprite opening lands on the existing shot endpoint without distorting the raster', () => {
  const art = demoCourtArt.hoop;
  const sourceToProduction = art.production.width / art.crop.width;
  const productionToSvg = art.placement.width / art.production.width;
  close(art.placement.height / art.production.height, productionToSvg);
  const cx =
    art.placement.x + art.sourceRim.cx * sourceToProduction * productionToSvg;
  const cy =
    art.placement.y + art.sourceRim.cy * sourceToProduction * productionToSvg;
  // The asymmetric sprite cannot be registered using its image center.
  assert.notEqual(art.sourceRim.cy, art.crop.height / 2);
  for (const point of [
    { x: 0, y: 0 },
    { x: 0.25, y: 0.65 },
    { x: 1, y: 1 },
  ]) {
    const shot = shotFrame(SHOT_TIMING.flight, point);
    close(cx, shot.x);
    close(cy, shot.y);
  }
  close(art.sourceRim.rx * sourceToProduction * productionToSvg, 20);
  close(art.sourceRim.ry * sourceToProduction * productionToSvg, art.rim.ry);
});

test('the circular overhead net keeps all rim attachments fixed through the swish', () => {
  const art = demoCourtArt.hoop;
  close(art.rim.ry, art.rim.rx);
  const scale = art.rim.rx / 16;
  for (const impact of [-0.3, 0, 0.3, 1]) {
    for (const [x, y] of [
      [-16, 0],
      [0, -16],
      [16, 0],
      [0, 16],
    ] as const) {
      const attachment = netPoint(x, y, impact);
      close(attachment.x * scale, x * 1.25);
      close(attachment.y * scale, y * 1.25);
      close(Math.hypot(attachment.x, attachment.y) * scale, 20);
    }
  }
  close(SHOT_TIMING.flight, 1.2);
  close(SHOT_TIMING.mark, 1.55);
  close(SHOT_TIMING.total, 2.13);
});
