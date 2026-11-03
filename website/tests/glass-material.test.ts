import assert from 'node:assert/strict';
import test from 'node:test';
import { Color } from 'three';
import {
  glassMaterial,
  glassMaterialStyles,
} from '../src/data/glass-material.ts';
import { LiquidGlassPass } from '../src/scripts/liquid-glass-pass.ts';

test('one restrained material supplies CSS values and a distinct density fallback', () => {
  assert.equal(glassMaterialStyles['--glass-rgb'], '21 27 30');
  assert.equal(
    glassMaterialStyles['--glass-fill-opacity'],
    String(glassMaterial.opacity),
  );
  assert.equal(glassMaterialStyles['--glass-blur'], '12px');
  assert.equal(glassMaterialStyles['--glass-saturation'], '0.9');
  assert.ok(glassMaterial.densityOpacity > glassMaterial.opacity);
  assert.equal(glassMaterial.dispersionPx, 0);
});

test('full optics receives linear color while OutputPass retains output conversion', () => {
  const pass = new LiquidGlassPass(() => {});
  const tint = pass.uniforms.uTint.value as Color;
  const expected = new Color('#151b1e');
  assert.deepEqual(tint.toArray(), expected.toArray());
  assert.ok(tint.r < 21 / 255);
  assert.equal(pass.uniforms.uOptics.value.x, 5);
  assert.equal(pass.uniforms.uOptics.value.y, 2.5);
  assert.equal(pass.uniforms.uOptics.value.z, 0);
  assert.equal(pass.material.toneMapped, false);
  pass.setSize(2880, 1800);
  assert.equal(pass.uniforms.uOptics.value.x, 5);
  pass.dispose();
});
