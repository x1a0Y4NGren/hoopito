import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as THREE from 'three';
import { storyPose } from '../src/scripts/story-pose.ts';
import { composeCameraPose } from '../src/scripts/camera-placement.ts';
import type {
  StoryChapter,
  StoryFrame,
} from '../src/scripts/scene-contract.ts';

const chapters: StoryChapter[] = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
  'community',
];
const viewport = { left: 0, top: 0, width: 1440, height: 900 };
const restRegion = { left: 740, top: 165, width: 600, height: 650 };
const placement = {
  region: restRegion,
  restRegion,
  blend: 1,
  inputEnabled: true,
};
const frame = (
  chapter: StoryChapter,
  cameraTrack?: StoryFrame['cameraTrack'],
): StoryFrame => ({
  chapter,
  progress: 0.5,
  active: true,
  ...(cameraTrack ? { cameraTrack } : {}),
});

async function timeline() {
  const module = await import('../src/scripts/camera-track.ts').catch(
    () => null,
  );
  assert.ok(module, 'the scroll-derived camera timeline exists');
  return module;
}

test('camera tracks use only gaps between reading intervals and reverse without history', async () => {
  const { cameraStateAtScroll } = await timeline();
  const stops = chapters.map((id, index) => ({
    id,
    readStart: index * 1000,
    readEnd: index * 1000 + 300,
  }));
  const forward = Array.from({ length: 54 }, (_, index) =>
    cameraStateAtScroll(index * 100, stops, 'hero'),
  );
  const reverse = Array.from({ length: 54 }, (_, index) =>
    cameraStateAtScroll((53 - index) * 100, stops, 'hero'),
  ).reverse();
  assert.deepEqual(reverse, forward);
  assert.deepEqual(cameraStateAtScroll(650, stops, 'hero').cameraTrack, {
    from: 'hero',
    to: 'scoring',
    progress: 0.5,
  });
  for (const y of [0, 150, 300, 1000, 1250, 1300])
    assert.equal(cameraStateAtScroll(y, stops, 'hero').cameraTrack, undefined);
  assert.equal(cameraStateAtScroll(1250, stops, 'hero').chapter, 'scoring');
});

test('overlap and zero gaps resolve to the nearest reading pose with ties forward; closing holds community', async () => {
  const { cameraStateAtScroll } = await timeline();
  const stops = [
    { id: 'hero' as const, readStart: 0, readEnd: 300 },
    { id: 'scoring' as const, readStart: 300, readEnd: 600 },
    { id: 'experience' as const, readStart: 500, readEnd: 800 },
  ];
  assert.deepEqual(cameraStateAtScroll(300, stops, 'hero'), {
    chapter: 'scoring',
  });
  assert.deepEqual(cameraStateAtScroll(550, stops, 'hero'), {
    chapter: 'experience',
  });
  assert.deepEqual(cameraStateAtScroll(480, stops, 'hero'), {
    chapter: 'scoring',
  });
  const closing = [
    { id: 'community' as const, readStart: 5000, readEnd: 5200 },
    { id: 'closing' as const, readStart: 6000, readEnd: 6500 },
  ];
  for (const y of [5000, 5500, 6000, 7000])
    assert.deepEqual(cameraStateAtScroll(y, closing, 'hero'), {
      chapter: 'community',
    });
});

test('native scroll rounding within two CSS pixels lands on the reading pose without starving input', async () => {
  const { cameraStateAtScroll } = await timeline();
  const stops = [
    { id: 'scoring' as const, readStart: 1000, readEnd: 1300 },
    { id: 'experience' as const, readStart: 2200.4, readEnd: 2500.4 },
    { id: 'replay' as const, readStart: 3300.4, readEnd: 3600 },
  ];
  for (const y of [2200.333, 2200, 2201, 2198.4, 2502.4])
    assert.deepEqual(cameraStateAtScroll(y, stops, 'scoring'), {
      chapter: 'experience',
    });
  for (const y of [1302.01, 1700, 2198.39, 2502.41, 3298.39])
    assert.ok(
      cameraStateAtScroll(y, stops, 'scoring').cameraTrack,
      `${y} remains a real scroll-driven flight`,
    );
});

test('all reading poses remain static for local progress and reduced motion keeps the current chapter', () => {
  for (const chapter of chapters) {
    const rest = storyPose(frame(chapter));
    for (const progress of [0, 0.2, 0.8, 1, NaN])
      assert.deepEqual(storyPose({ ...frame(chapter), progress }), rest);
    assert.deepEqual(
      storyPose(
        frame(chapter, { from: 'hero', to: 'scoring', progress: 0.4 }),
        false,
      ),
      rest,
    );
  }
  assert.notDeepEqual(storyPose(frame('scoring')), storyPose(frame('replay')));
  assert.notDeepEqual(
    storyPose(frame('download')),
    storyPose(frame('community')),
  );
});

test('world track endpoints match each reading camera exactly and dense forward/reverse samples remain continuous', () => {
  for (let index = 0; index < chapters.length - 1; index += 1) {
    const from = chapters[index]!;
    const to = chapters[index + 1]!;
    const sample = (progress: number) =>
      composeCameraPose(
        frame(from, { from, to, progress }),
        viewport,
        placement,
      );
    assert.deepEqual(
      sample(0),
      composeCameraPose(frame(from), viewport, placement),
    );
    assert.deepEqual(
      sample(1),
      composeCameraPose(frame(to), viewport, placement),
    );
    let previous: THREE.Quaternion | undefined;
    let previousPosition: THREE.Vector3 | undefined;
    const forward = [];
    for (let step = 0; step <= 1000; step += 1) {
      const pose = sample(step / 1000);
      forward.push(pose);
      const camera = new THREE.PerspectiveCamera(pose.fov, 1.6, 0.015, 100);
      camera.position.set(...pose.position);
      camera.up.set(...(pose.up ?? [0, 1, 0]));
      camera.lookAt(new THREE.Vector3(...pose.target));
      camera.filmOffset = pose.filmOffset ?? 0;
      camera.updateProjectionMatrix();
      if (previous)
        assert.ok(
          THREE.MathUtils.radToDeg(camera.quaternion.angleTo(previous)) < 0.6,
          `${from} → ${to} does not rotate abruptly at ${step}`,
        );
      if (previousPosition)
        assert.ok(
          camera.position.distanceTo(previousPosition) < 0.2,
          `${from} → ${to} does not teleport at ${step}`,
        );
      previous = camera.quaternion.clone();
      previousPosition = camera.position.clone();
    }
    assert.deepEqual(
      Array.from({ length: 1001 }, (_, index) =>
        sample((1000 - index) / 1000),
      ).reverse(),
      forward,
    );
  }
});

test('transition overhead endpoints use the static reading region while natural-flow rest follows the live region', () => {
  const track = frame('scoring', {
    from: 'scoring',
    to: 'experience',
    progress: 0.72,
  });
  const moved = {
    ...placement,
    region: { ...restRegion, top: -1000, left: 350, width: 800 },
  };
  assert.deepEqual(
    composeCameraPose(track, viewport, moved),
    composeCameraPose(track, viewport, placement),
  );
  assert.notDeepEqual(
    composeCameraPose(frame('experience'), viewport, moved),
    composeCameraPose(frame('experience'), viewport, placement),
  );
  assert.deepEqual(
    composeCameraPose(frame('replay'), viewport, moved),
    composeCameraPose(frame('replay'), viewport, null),
  );
});

test('only an exact overhead rest can accept court input', async () => {
  const { isOverheadReadingFrame } = await timeline();
  assert.equal(isOverheadReadingFrame(frame('experience')), true);
  assert.equal(isOverheadReadingFrame(frame('scoring')), false);
  assert.equal(
    isOverheadReadingFrame(
      frame('experience', { from: 'scoring', to: 'experience', progress: 1 }),
    ),
    false,
  );
  assert.equal(
    isOverheadReadingFrame({ ...frame('experience'), active: false }),
    false,
  );
});

test('the fitted input camera is exactly vertical with an explicit floor-aligned screen-up', () => {
  const pose = composeCameraPose(frame('experience'), viewport, placement);
  assert.equal(pose.position[0], pose.target[0]);
  assert.equal(pose.position[2], pose.target[2]);
  assert.deepEqual(pose.up, [0, 0, -1]);
});

test('camera bank stays within six degrees in flight and settles to an upright reading pose', () => {
  for (let index = 0; index < chapters.length - 1; index += 1) {
    const from = chapters[index]!;
    const to = chapters[index + 1]!;
    for (let step = 1; step < 100; step += 1) {
      const pose = composeCameraPose(
        frame(from, { from, to, progress: step / 100 }),
        viewport,
        placement,
      );
      const view = new THREE.Vector3(...pose.target)
        .sub(new THREE.Vector3(...pose.position))
        .normalize();
      const right = view
        .clone()
        .cross(new THREE.Vector3(0, 1, 0))
        .normalize();
      const upright = right.clone().cross(view).normalize();
      assert.ok(
        THREE.MathUtils.radToDeg(
          upright.angleTo(new THREE.Vector3(...pose.up!)),
        ) <=
          6 + 1e-6,
      );
    }
    for (const chapter of [from, to]) {
      const pose = composeCameraPose(frame(chapter), viewport, placement);
      const camera = new THREE.PerspectiveCamera();
      camera.position.set(...pose.position);
      camera.up.set(...(pose.up ?? [0, 1, 0]));
      camera.lookAt(new THREE.Vector3(...pose.target));
      camera.filmOffset = pose.filmOffset ?? 0;
      camera.updateProjectionMatrix();
      const right = new THREE.Vector3(1, 0, 0).applyQuaternion(
        camera.quaternion,
      );
      assert.ok(Math.abs(right.y) < 1e-8, `${chapter} is upright at rest`);
    }
  }
});

test('reading cameras and every low flight sample stay inside the training hall side-wall corridor', () => {
  for (const chapter of ['scoring', 'replay', 'community'] as const) {
    const pose = storyPose(frame(chapter));
    assert.ok(
      pose.position[1] < 6,
      `${chapter} reads from a low athletic viewpoint`,
    );
    assert.ok(
      Math.abs(pose.position[0]) < 12.8,
      `${chapter} stays inside the side walls`,
    );
    assert.ok(
      pose.position[2] <= 15,
      `${chapter} retains the continuous floor behind the court`,
    );
  }
  for (let index = 0; index < chapters.length - 1; index += 1) {
    const from = chapters[index]!;
    const to = chapters[index + 1]!;
    for (const fittedPlacement of [placement, null]) {
      for (let step = 0; step <= 1000; step += 1) {
        const pose = composeCameraPose(
          frame(from, { from, to, progress: step / 1000 }),
          viewport,
          fittedPlacement,
        );
        if (pose.position[1] >= 8) continue;
        assert.ok(
          Math.abs(pose.position[0]) < 12.8,
          `${from} → ${to} at ${step}: low camera x=${pose.position[0]} crosses a side wall`,
        );
        assert.ok(
          pose.position[2] > -12.8,
          `${from} → ${to} at ${step} stays in front of the back wall`,
        );
      }
    }
  }
});
