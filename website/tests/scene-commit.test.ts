import assert from 'node:assert/strict';
import { test } from 'node:test';
import { createSceneCommitGuard } from '../src/scripts/scene-commit.ts';

const initial = () => ({
  frame: { chapter: 'experience' as const, progress: 0.4, active: true },
  placement: {
    region: { left: 200, top: 180, width: 500, height: 420 },
    blend: 1,
    inputEnabled: true,
  },
  surfaces: [
    {
      id: 'score',
      region: { left: 100, top: 120, width: 600, height: 80 },
      radius: 20,
      opacity: 1,
    },
  ],
  viewport: { width: 1440, height: 900, dpr: 1 },
});

test('duplicate scroll notifications with identical scene input need no additional commit', () => {
  const changed = createSceneCommitGuard();
  const scene = {};
  assert.equal(changed(scene, initial()), true);
  assert.equal(changed(scene, initial()), false);
  assert.equal(changed(scene, initial()), false);
});

test('every camera, optical, timeline and viewport change remains eligible, including subpixels', () => {
  const mutations = [
    (s: ReturnType<typeof initial>) => {
      s.frame.progress += 0.000001;
    },
    (s: ReturnType<typeof initial>) => {
      s.frame.active = false;
    },
    (s: ReturnType<typeof initial>) => {
      s.placement.region.left += 0.000001;
    },
    (s: ReturnType<typeof initial>) => {
      s.placement.blend -= 0.000001;
    },
    (s: ReturnType<typeof initial>) => {
      s.placement.inputEnabled = false;
    },
    (s: ReturnType<typeof initial>) => {
      s.surfaces[0].region.top += 0.000001;
    },
    (s: ReturnType<typeof initial>) => {
      s.surfaces[0].opacity -= 0.000001;
    },
    (s: ReturnType<typeof initial>) => {
      s.surfaces[0].radius += 0.000001;
    },
    (s: ReturnType<typeof initial>) => {
      s.surfaces[0].id = 'replacement';
    },
    (s: ReturnType<typeof initial>) => {
      s.surfaces.length = 0;
    },
    (s: ReturnType<typeof initial>) => {
      s.viewport.width += 1;
    },
    (s: ReturnType<typeof initial>) => {
      s.viewport.dpr = 2;
    },
  ];
  for (const mutate of mutations) {
    const changed = createSceneCommitGuard(),
      scene = {},
      state = initial();
    assert.equal(changed(scene, state), true);
    mutate(state);
    assert.equal(changed(scene, state), true);
    assert.equal(changed(scene, state), false);
  }
});

test('a replacement scene and a return to a previous pose both require a fresh commit', () => {
  const changed = createSceneCommitGuard(),
    scene = {};
  changed(scene, initial());
  const moved = initial();
  moved.frame.progress = 0.5;
  assert.equal(changed(scene, moved), true);
  assert.equal(changed(scene, initial()), true);
  assert.equal(changed({}, initial()), true);
});
