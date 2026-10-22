import assert from 'node:assert/strict';
import { test } from 'node:test';
import * as THREE from 'three';
import { storyPose } from '../src/scripts/story-pose.ts';
import type {
  CameraPlacement,
  SceneRegion,
  StoryFrame,
} from '../src/scripts/scene-contract.ts';
import type { StoryPose } from '../src/scripts/story-pose.ts';

const viewport: SceneRegion = {
  left: 748.8,
  top: 0,
  width: 691.2,
  height: 900,
};
const region: SceneRegion = { left: 786, top: 154, width: 590, height: 650 };
const experience: StoryFrame = {
  chapter: 'experience',
  progress: 0.5,
  active: true,
};
const placement: CameraPlacement = { region, blend: 1, inputEnabled: true };

async function helpers() {
  const module = await import('../src/scripts/camera-placement.ts').catch(
    () => null,
  );
  assert.ok(module, 'The shared camera placement and projection helpers exist');
  return module;
}

function cameraFor(pose: StoryPose, bounds: SceneRegion) {
  const camera = new THREE.PerspectiveCamera(
    pose.fov,
    bounds.width / bounds.height,
    0.015,
    100,
  );
  camera.position.set(...pose.position);
  camera.up.set(...(pose.up ?? [0, 1, 0]));
  camera.lookAt(new THREE.Vector3(...pose.target));
  camera.updateMatrixWorld();
  return camera;
}

test('the entire half court fits inside the transparent region with a 24px inset on an offset canvas', async () => {
  const { composeCameraPose, projectCourtPoint } = await helpers();
  for (const bounds of [
    viewport,
    { left: 998.4, top: 0, width: 921.6, height: 1080 },
    { left: 532.48, top: 25, width: 491.52, height: 650 },
  ]) {
    const target = {
      left: bounds.left + 30,
      top: bounds.top + 100,
      width: bounds.width - 70,
      height: bounds.height - 160,
    };
    const pose = composeCameraPose(experience, bounds, {
      ...placement,
      region: target,
    });
    const camera = cameraFor(pose, bounds);
    for (const point of [
      { x: 0, y: 0 },
      { x: 1, y: 0 },
      { x: 0, y: 1 },
      { x: 1, y: 1 },
    ]) {
      const client = projectCourtPoint(point, camera, bounds)!;
      assert.ok(client.x >= target.left + 24 - 0.01);
      assert.ok(client.x <= target.left + target.width - 24 + 0.01);
      assert.ok(client.y >= target.top + 24 - 0.01);
      assert.ok(client.y <= target.top + target.height - 24 + 0.01);
    }
    const center = projectCourtPoint({ x: 0.5, y: 0.5 }, camera, bounds)!;
    assert.ok(Math.abs(center.x - (target.left + target.width / 2)) < 0.05);
    assert.ok(Math.abs(center.y - (target.top + target.height / 2)) < 0.05);
    assert.equal(pose.fov, 38);
    assert.ok(Math.abs(pose.position[0] - pose.target[0]) < 0.000001);
    assert.ok(Math.abs(pose.position[2] - pose.target[2] - 0.01) < 0.000001);
  }
});

test('camera roll resolves throughout the approach instead of collapsing at the overhead pole', async () => {
  const { composeCameraPose } = await helpers();
  const samples: THREE.Quaternion[] = [];
  for (let step = 0; step <= 1000; step += 1) {
    const progress = step / 1000;
    const blend = progress * progress * (3 - 2 * progress);
    const pose = composeCameraPose(experience, viewport, {
      ...placement,
      blend,
    });
    const camera = cameraFor(pose, viewport);
    samples.push(camera.quaternion.clone());
  }
  const angles = samples
    .slice(1)
    .map((current, index) =>
      THREE.MathUtils.radToDeg(current.angleTo(samples[index]!)),
    );
  assert.ok(
    Math.max(...angles) < 0.25,
    `a 0.1% scroll step must not snap: ${Math.max(...angles).toFixed(3)} degrees`,
  );
  // The last 5% is a gentle settle, not a delayed screen rotation.
  assert.ok(
    THREE.MathUtils.radToDeg(samples[950]!.angleTo(samples[1000]!)) < 1,
  );
  for (const chapter of ['scoring', 'experience', 'replay'] as const) {
    const pose = composeCameraPose(
      { chapter, progress: 0, active: true },
      viewport,
      placement,
    );
    assert.ok(
      cameraFor(pose, viewport).quaternion.angleTo(samples.at(-1)!) < 1e-7,
    );
  }
});

test('projected floor points round trip through the actual camera rather than the host rectangle', async () => {
  const { composeCameraPose, projectCourtPoint, courtPointFromClient } =
    await helpers();
  for (const blend of [0, 0.25, 0.5, 1]) {
    const pose = composeCameraPose(experience, viewport, {
      ...placement,
      blend,
    });
    const camera = cameraFor(pose, viewport);
    for (const point of [
      { x: 0.25, y: 0.65 },
      { x: 0.5, y: 0.5 },
      { x: 0.75, y: 0.35 },
    ]) {
      const client = projectCourtPoint(point, camera, viewport)!;
      const recovered = courtPointFromClient(
        client.x,
        client.y,
        camera,
        viewport,
      )!;
      assert.ok(Math.abs(recovered.x - point.x) < 1e-8);
      assert.ok(Math.abs(recovered.y - point.y) < 1e-8);
    }
  }
});

test('placement shares the sideline anchor and joins the interactive and replay cameras in both directions', async () => {
  const { composeCameraPose } = await helpers();
  const sideline = storyPose({ chapter: 'scoring', progress: 0, active: true });
  for (const chapter of ['scoring', 'experience'] as const) {
    for (const progress of [0, 0.5, 1]) {
      assert.deepEqual(
        composeCameraPose({ chapter, progress, active: true }, viewport, {
          ...placement,
          blend: 0,
        }),
        sideline,
      );
    }
  }
  for (const blend of [0, 0.2, 0.7, 1]) {
    assert.deepEqual(
      composeCameraPose(
        { chapter: 'scoring', progress: 1, active: true },
        viewport,
        { ...placement, blend },
      ),
      composeCameraPose(
        { chapter: 'experience', progress: 0, active: true },
        viewport,
        { ...placement, blend },
      ),
    );
  }
  assert.deepEqual(
    composeCameraPose({ ...experience, progress: 1 }, viewport, placement),
    composeCameraPose(
      { chapter: 'replay', progress: 0, active: true },
      viewport,
      placement,
    ),
  );
  const replayEnd = { chapter: 'replay', progress: 1, active: true } as const;
  assert.deepEqual(
    composeCameraPose(replayEnd, viewport, { ...placement, blend: 0 }),
    storyPose(replayEnd),
  );
});

test('invalid geometry never poisons the camera and reduced motion uses the overhead placement immediately', async () => {
  const {
    composeCameraPose,
    normalizeCameraPlacement,
    projectCourtPoint,
    courtPointFromClient,
  } = await helpers();
  for (const invalid of [
    { ...placement, blend: NaN },
    { ...placement, region: { ...region, width: 0 } },
    { ...placement, region: { ...region, left: Infinity } },
  ]) {
    assert.equal(normalizeCameraPlacement(invalid), null);
    assert.deepEqual(
      composeCameraPose(experience, viewport, invalid),
      storyPose(experience),
    );
  }
  assert.deepEqual(
    composeCameraPose(
      experience,
      viewport,
      { ...placement, blend: 0.2 },
      false,
    ),
    composeCameraPose(experience, viewport, placement),
  );
  const hero = { chapter: 'hero', progress: 0.4, active: true } as const;
  assert.deepEqual(
    composeCameraPose(hero, viewport, placement),
    storyPose(hero),
  );
  const camera = cameraFor(storyPose(experience), viewport);
  assert.equal(courtPointFromClient(NaN, 200, camera, viewport), null);
  assert.equal(projectCourtPoint({ x: NaN, y: 0.5 }, camera, viewport), null);
  assert.equal(
    courtPointFromClient(100, 200, camera, { ...viewport, height: 0 }),
    null,
  );
});

function countCameraRays(run: (count: () => number) => void) {
  const original = THREE.Raycaster.prototype.setFromCamera;
  let count = 0;
  THREE.Raycaster.prototype.setFromCamera = function (...args) {
    count += 1;
    return original.apply(this, args);
  };
  try {
    run(() => count);
  } finally {
    THREE.Raycaster.prototype.setFromCamera = original;
  }
}

test('a scene reuses camera calculations for identical scalar snapshots in fresh objects', async () => {
  const module = await helpers();
  assert.equal(typeof module.createCameraPoseResolver, 'function');
  const resolve = module.createCameraPoseResolver();
  countCameraRays((count) => {
    const first = resolve(experience, viewport, placement);
    const initialRays = count();
    assert.ok(initialRays > 0, 'the first pose uses real camera raycasts');
    for (let repeat = 0; repeat < 10; repeat += 1) {
      assert.deepEqual(
        resolve(
          { ...experience },
          { ...viewport },
          { ...placement, region: { ...region } },
          true,
        ),
        first,
      );
    }
    assert.equal(
      count(),
      initialRays,
      'unchanged poses perform no new raycasts',
    );
  });
});

test('mutated camera input scalars invalidate the scene snapshot and preserve projection', async () => {
  const module = await helpers();
  assert.equal(typeof module.createCameraPoseResolver, 'function');
  const resolve = module.createCameraPoseResolver();
  const currentFrame: StoryFrame = {
    chapter: 'replay',
    progress: 0.2,
    active: true,
  };
  const currentViewport = { ...viewport };
  const currentPlacement = { ...placement, region: { ...region }, blend: 0.65 };
  let motionEnabled = true;
  const mutations: [string, () => void][] = [
    ['progress', () => (currentFrame.progress = 0.7)],
    ['chapter', () => (currentFrame.chapter = 'experience')],
    ['active', () => (currentFrame.active = false)],
    ['viewport left', () => (currentViewport.left += 20)],
    ['viewport top', () => (currentViewport.top += 15)],
    ['viewport width', () => (currentViewport.width += 80)],
    ['viewport height', () => (currentViewport.height += 60)],
    ['region left', () => (currentPlacement.region.left += 25)],
    ['region top', () => (currentPlacement.region.top += 10)],
    ['region width', () => (currentPlacement.region.width -= 40)],
    ['region height', () => (currentPlacement.region.height -= 30)],
    ['blend', () => (currentPlacement.blend = 0.8)],
    ['input eligibility', () => (currentPlacement.inputEnabled = false)],
    ['motion', () => (motionEnabled = false)],
  ];
  countCameraRays((count) => {
    resolve(currentFrame, currentViewport, currentPlacement, motionEnabled);
    for (const [name, mutate] of mutations) {
      mutate();
      const expected = module.composeCameraPose(
        currentFrame,
        currentViewport,
        currentPlacement,
        motionEnabled,
      );
      const before = count();
      const actual = resolve(
        currentFrame,
        currentViewport,
        currentPlacement,
        motionEnabled,
      );
      assert.ok(count() > before, `${name} recalculates the camera`);
      assert.deepEqual(actual, expected, `${name} matches the uncached pose`);
      const camera = cameraFor(actual, currentViewport);
      for (const point of [
        { x: 0.25, y: 0.65 },
        { x: 0.5, y: 0.5 },
        { x: 0.75, y: 0.35 },
      ]) {
        const client = module.projectCourtPoint(
          point,
          camera,
          currentViewport,
        )!;
        const recovered = module.courtPointFromClient(
          client.x,
          client.y,
          camera,
          currentViewport,
        );
        assert.ok(recovered, `${name} retains a floor intersection`);
        const roundTrip = module.projectCourtPoint(
          recovered,
          camera,
          currentViewport,
        )!;
        assert.ok(
          Math.hypot(roundTrip.x - client.x, roundTrip.y - client.y) <= 2,
          `${name} keeps the round trip within two CSS pixels`,
        );
      }
      const afterProjection = count();
      resolve(currentFrame, currentViewport, currentPlacement, motionEnabled);
      assert.equal(
        count(),
        afterProjection,
        `${name} becomes the new snapshot`,
      );
    }
  });
});

test('removing and restoring placement replaces the single cached camera snapshot', async () => {
  const module = await helpers();
  assert.equal(typeof module.createCameraPoseResolver, 'function');
  const resolve = module.createCameraPoseResolver();
  countCameraRays((count) => {
    const first = resolve(experience, viewport, placement);
    const beforeRemoval = count();
    assert.deepEqual(
      resolve(experience, viewport, null),
      storyPose(experience),
    );
    assert.equal(count(), beforeRemoval);
    assert.deepEqual(resolve(experience, viewport, placement), first);
    assert.ok(
      count() > beforeRemoval,
      'only the most recent snapshot is retained',
    );
  });
});

test('each scene owns its camera calculation snapshot', async () => {
  const module = await helpers();
  assert.equal(typeof module.createCameraPoseResolver, 'function');
  const firstScene = module.createCameraPoseResolver();
  const secondScene = module.createCameraPoseResolver();
  countCameraRays((count) => {
    const first = firstScene(experience, viewport, placement);
    const firstSceneRays = count();
    assert.deepEqual(secondScene(experience, viewport, placement), first);
    assert.ok(count() > firstSceneRays, 'a second scene computes its own pose');
    const bothSceneRays = count();
    firstScene(experience, viewport, placement);
    secondScene(experience, viewport, placement);
    assert.equal(count(), bothSceneRays, 'each scene keeps its own last pose');
  });
});
