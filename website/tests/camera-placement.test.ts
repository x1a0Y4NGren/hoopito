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
  camera.filmOffset = pose.filmOffset ?? 0;
  camera.updateProjectionMatrix();
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
    assert.ok(Math.abs(pose.position[2] - pose.target[2]) < 0.000001);
  }
});

test('off-axis overhead keeps the original floor fit while aligning elevated basket hardware with its floor centerline', async () => {
  const { composeCameraPose, projectCourtPoint, courtPointFromClient } =
    await helpers();
  for (const bounds of [
    { left: 0, top: 0, width: 1425, height: 900 },
    { left: 0, top: 0, width: 1905, height: 1080 },
    { left: 80, top: 25, width: 944, height: 650 },
  ]) {
    for (const horizontal of [0.28, 0.5, 0.73]) {
      const target = {
        left: bounds.left + bounds.width * horizontal - bounds.width * 0.2,
        top: bounds.top + 120,
        width: bounds.width * 0.4,
        height: bounds.height - 170,
      };
      const scale = Math.min(
        (target.width - 48) / 15,
        (target.height - 48) / 14,
      );
      // Independent reference: the prior translated true-overhead perspective
      // fits the floor exactly but introduces horizontal height parallax.
      const height =
        bounds.height / (2 * scale * Math.tan((38 * Math.PI) / 360));
      const shiftX =
        -(target.left + target.width / 2 - bounds.left - bounds.width / 2) /
        scale;
      const shiftZ =
        -(target.top + target.height / 2 - bounds.top - bounds.height / 2) /
        scale;
      const legacy = cameraFor(
        {
          position: [shiftX, height, shiftZ],
          target: [shiftX, 0, shiftZ],
          up: [0, 0, -1],
          fov: 38,
          light: 1,
          reveal: 1,
        },
        bounds,
      );
      const pose = composeCameraPose(experience, bounds, {
        ...placement,
        region: target,
      });
      const camera = cameraFor(pose, bounds);
      assert.equal(
        pose.position[0],
        0,
        'the camera sits over the court centerline',
      );
      assert.equal(
        pose.target[0],
        0,
        'the optical axis follows the same centerline',
      );
      assert.ok(
        Math.abs(
          (pose.filmOffset ?? 0) - (shiftX / height) * camera.getFilmWidth(),
        ) < 1e-8,
      );
      for (const point of [
        { x: 0, y: 0 },
        { x: 1, y: 0 },
        { x: 0, y: 1 },
        { x: 1, y: 1 },
        { x: 0.4, y: 0.65 },
      ]) {
        const before = projectCourtPoint(point, legacy, bounds)!;
        const after = projectCourtPoint(point, camera, bounds)!;
        assert.ok(
          Math.hypot(after.x - before.x, after.y - before.y) < 0.01,
          'floor pixels retain the original fit',
        );
        assert.ok(
          after.x >= target.left + 24 - 0.01 &&
            after.x <= target.left + target.width - 24 + 0.01,
        );
        assert.ok(
          after.y >= target.top + 24 - 0.01 &&
            after.y <= target.top + target.height - 24 + 0.01,
        );
        if (point.x === 0.4) {
          const recovered = courtPointFromClient(
            after.x,
            after.y,
            camera,
            bounds,
          )!;
          assert.ok(
            Math.abs(recovered.x - point.x) < 1e-8 &&
              Math.abs(recovered.y - point.y) < 1e-8,
          );
        }
      }
      const hardwareX = [0, 3.05, 3.575].map((y) => {
        const point = new THREE.Vector3(0, y, -5.3).project(camera);
        return bounds.left + ((point.x + 1) * bounds.width) / 2;
      });
      assert.ok(
        Math.max(...hardwareX) - Math.min(...hardwareX) <= 0.01,
        'rim and backboard stay centered above the floor markings',
      );
    }
  }
});

test('horizontal film shift joins overhead track endpoints continuously and resets on every other reading pose', async () => {
  const { composeCameraPose } = await helpers();
  const bounds = { left: 0, top: 0, width: 1440, height: 900 };
  const currentPlacement = {
    ...placement,
    region: { left: 740, top: 160, width: 600, height: 650 },
  };
  const overhead = composeCameraPose(experience, bounds, currentPlacement);
  assert.notEqual(
    overhead.filmOffset ?? 0,
    0,
    'this fixture needs horizontal optical shift',
  );
  for (const route of [
    { from: 'scoring' as const, to: 'experience' as const },
    { from: 'experience' as const, to: 'replay' as const },
  ]) {
    const sample = (progress: number) =>
      composeCameraPose(
        { ...experience, cameraTrack: { ...route, progress } },
        bounds,
        currentPlacement,
      );
    const forward = Array.from({ length: 1001 }, (_, index) =>
      sample(index / 1000),
    );
    assert.deepEqual(
      Array.from({ length: 1001 }, (_, index) =>
        sample((1000 - index) / 1000),
      ).reverse(),
      forward,
    );
    for (let index = 1; index < forward.length; index += 1)
      assert.ok(
        Math.abs(
          (forward[index]!.filmOffset ?? 0) -
            (forward[index - 1]!.filmOffset ?? 0),
        ) < 0.02,
      );
    assert.equal(
      forward[route.to === 'experience' ? 1000 : 0]!.filmOffset,
      overhead.filmOffset,
    );
    assert.equal(
      forward[route.to === 'experience' ? 0 : 1000]!.filmOffset ?? 0,
      0,
    );
  }
  for (const chapter of [
    'hero',
    'scoring',
    'replay',
    'download',
    'community',
  ] as const)
    assert.equal(
      composeCameraPose(
        { chapter, progress: 0.5, active: true },
        bounds,
        currentPlacement,
      ).filmOffset ?? 0,
      0,
    );
});

test('projected floor points round trip through the actual camera rather than the host rectangle', async () => {
  const { composeCameraPose, projectCourtPoint, courtPointFromClient } =
    await helpers();
  for (const progress of [0, 0.25, 0.5, 1]) {
    const pose = composeCameraPose(
      {
        ...experience,
        cameraTrack: { from: 'scoring', to: 'experience', progress },
      },
      viewport,
      placement,
    );
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

test('CSS court projection and inverse stay within two pixels at every supported render density', async () => {
  const { composeCameraPose, projectCourtPoint, courtPointFromClient } =
    await helpers();
  const pose = composeCameraPose(experience, viewport, placement);
  for (const dpr of [1, 1.5, 2]) {
    const drawingWidth = viewport.width * dpr;
    const drawingHeight = viewport.height * dpr;
    const camera = cameraFor(pose, {
      ...viewport,
      width: drawingWidth,
      height: drawingHeight,
    });
    for (const point of [
      { x: 0.1, y: 0.1 },
      { x: 0.5, y: 0.65 },
      { x: 0.9, y: 0.9 },
    ]) {
      const client = projectCourtPoint(point, camera, viewport)!;
      // Browser input can land on the nearest physical drawing-buffer pixel.
      const pixelX =
        viewport.left + Math.round((client.x - viewport.left) * dpr) / dpr;
      const pixelY =
        viewport.top + Math.round((client.y - viewport.top) * dpr) / dpr;
      const recovered = courtPointFromClient(pixelX, pixelY, camera, viewport);
      assert.ok(recovered, `DPR ${dpr} retains the selected floor point`);
      const roundTrip = projectCourtPoint(recovered, camera, viewport)!;
      assert.ok(
        Math.hypot(roundTrip.x - client.x, roundTrip.y - client.y) <= 2,
      );
    }
  }
});

test('natural-flow experience projects into its live host and joins fixed reading-boundary endpoints', async () => {
  const { composeCameraPose, projectCourtPoint } = await helpers();
  const readStart = 2000;
  const readEnd = 2600;
  const boundary = { ...region };
  const atScroll = (position: number) => ({
    ...boundary,
    top: boundary.top - (position - readStart),
  });
  for (const position of [readStart, 2300, readEnd]) {
    const live = atScroll(position);
    const pose = composeCameraPose(experience, viewport, {
      ...placement,
      region: live,
      restRegion: boundary,
    });
    const camera = cameraFor(pose, viewport);
    const center = projectCourtPoint({ x: 0.5, y: 0.5 }, camera, viewport)!;
    assert.ok(Math.abs(center.x - live.left - live.width / 2) < 1e-8);
    assert.ok(Math.abs(center.y - live.top - live.height / 2) < 1e-8);
  }
  const entering: StoryFrame = {
    ...experience,
    cameraTrack: { from: 'scoring', to: 'experience', progress: 1 },
  };
  const leaving: StoryFrame = {
    ...experience,
    cameraTrack: { from: 'experience', to: 'replay', progress: 0 },
  };
  assert.deepEqual(
    composeCameraPose(entering, viewport, {
      ...placement,
      restRegion: atScroll(readStart),
    }),
    composeCameraPose(experience, viewport, {
      ...placement,
      region: atScroll(readStart),
    }),
  );
  assert.deepEqual(
    composeCameraPose(leaving, viewport, {
      ...placement,
      restRegion: atScroll(readEnd),
    }),
    composeCameraPose(experience, viewport, {
      ...placement,
      region: atScroll(readEnd),
    }),
  );
});

test('native-quantized arrival and departure stay within two pixels when entering the accepted reading interval', async () => {
  const timeline = await import('../src/scripts/camera-track.ts');
  assert.equal(typeof timeline.transitionReadingRegion, 'function');
  const { composeCameraPose, projectCourtPoint } = await helpers();
  for (const fixture of [
    {
      start: 3817.5,
      end: 3817.5,
      height: 900,
      top: 281.1875,
      hostHeight: 414,
      samples: Array.from({ length: 18 }, (_, index) => 3809 + index),
    },
    {
      start: 4107.4,
      end: 4107.4,
      height: 900,
      top: 281.1875,
      hostHeight: 414,
      samples: Array.from(
        { length: 25 },
        (_, index) => Math.round((4107.4 - 4 + index / 3) * 1.5) / 1.5,
      ),
    },
    {
      start: 2700.5,
      end: 4002.968,
      height: 1000,
      top: 115.782 + 4002.968 - 2700.5,
      hostHeight: 440,
      samples: [4001, 4005, 4001],
    },
  ]) {
    const bounds = { left: 0, top: 0, width: 1425, height: fixture.height };
    const baseRegion = {
      left: 404,
      top: fixture.top,
      width: 723.8125,
      height: fixture.hostHeight,
    };
    const reading = { readStart: fixture.start, readEnd: fixture.end };
    const stops = [
      { id: 'scoring' as const, readStart: 1000, readEnd: 2295 },
      { id: 'experience' as const, ...reading },
      {
        id: 'replay' as const,
        readStart: fixture.end + 1000,
        readEnd: fixture.end + 1200,
      },
    ];
    let previous:
      { points: { x: number; y: number }[]; hostTop: number } | undefined;
    for (const scroll of fixture.samples) {
      const current = timeline.cameraStateAtScroll(scroll, stops, 'experience');
      const liveRegion = {
        ...baseRegion,
        top: baseRegion.top - (scroll - fixture.start),
      };
      const currentFrame = { ...current, progress: 0.5, active: true };
      const restRegion = timeline.transitionReadingRegion(
        baseRegion,
        reading,
        currentFrame.cameraTrack,
        false,
      );
      const pose = composeCameraPose(currentFrame, bounds, {
        region: liveRegion,
        restRegion,
        blend: 1,
        inputEnabled: !currentFrame.cameraTrack,
      });
      const camera = cameraFor(pose, bounds);
      const points = [
        { x: 0, y: 0 },
        { x: 1, y: 0 },
        { x: 0, y: 1 },
        { x: 1, y: 1 },
      ].map((point) => projectCourtPoint(point, camera, bounds)!);
      if (previous)
        for (let index = 0; index < points.length; index += 1) {
          const a = previous.points[index]!;
          const b = points[index]!;
          const error = Math.hypot(
            b.x - a.x,
            b.y - a.y - (liveRegion.top - previous.hostTop),
          );
          assert.ok(
            error <= 2,
            `native position ${scroll}, corner ${index}: ${error}px`,
          );
        }
      previous = { points, hostTop: liveRegion.top };
    }
  }
});

test('pinned reading endpoints retain the fixed host instead of applying natural-flow landing travel', async () => {
  const { transitionReadingRegion } =
    await import('../src/scripts/camera-track.ts');
  const reading = { readStart: 2000.4, readEnd: 2000.4 };
  for (const track of [
    { from: 'scoring' as const, to: 'experience' as const, progress: 0.9 },
    { from: 'experience' as const, to: 'replay' as const, progress: 0.1 },
  ])
    assert.deepEqual(
      transitionReadingRegion(region, reading, track, true),
      region,
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
    { ...placement, restRegion: { ...region, height: 0 } },
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
    composeCameraPose(hero, viewport, null),
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

test('two hundred forward and reverse track positions evaluate new poses without refitting the fixed overhead endpoint', async () => {
  const module = await helpers();
  const resolve = module.createCameraPoseResolver();
  const currentPlacement = { ...placement, restRegion: { ...region } };
  const positions = Array.from({ length: 201 }, (_, index) => index / 200);
  const frames = [...positions, ...positions.toReversed()].map(
    (progress): StoryFrame => ({
      chapter: progress < 0.5 ? 'scoring' : 'experience',
      progress,
      active: true,
      cameraTrack: { from: 'scoring', to: 'experience', progress },
    }),
  );
  const expected = frames.map((frame) =>
    module.composeCameraPose(frame, viewport, currentPlacement),
  );
  countCameraRays((count) => {
    const first = resolve(frames[0]!, viewport, currentPlacement);
    const initialRays = count();
    assert.ok(initialRays > 0, 'the endpoint uses a real fit once');
    for (const [index, frame] of frames.entries()) {
      const actual = resolve(frame, viewport, currentPlacement);
      assert.deepEqual(
        actual,
        expected[index],
        `native track position ${index} matches uncached evaluation`,
      );
      if (index === 100)
        assert.notDeepEqual(
          actual,
          first,
          'progress still advances the world camera',
        );
    }
    assert.equal(
      count(),
      initialRays,
      'scrolling and reversing reuse the identical static endpoint',
    );
  });
});

test('only selected ROI and viewport changes refit an endpoint; live geometry and story metadata still refresh the world pose', async () => {
  const module = await helpers();
  const resolve = module.createCameraPoseResolver();
  const currentFrame: StoryFrame = {
    ...experience,
    cameraTrack: { from: 'scoring', to: 'experience', progress: 0.4 },
  };
  const currentViewport = { ...viewport };
  const currentPlacement = {
    ...placement,
    region: { ...region },
    restRegion: { ...region },
  };
  countCameraRays((count) => {
    resolve(currentFrame, currentViewport, currentPlacement);
    for (const [name, mutate, refits] of [
      [
        'progress',
        () => {
          currentFrame.cameraTrack!.progress = 0.6;
        },
        false,
      ],
      [
        'chapter progress',
        () => {
          currentFrame.progress = 0.7;
        },
        false,
      ],
      [
        'active',
        () => {
          currentFrame.active = false;
        },
        false,
      ],
      [
        'live ROI during flight',
        () => {
          currentPlacement.region.top -= 100;
        },
        false,
      ],
      [
        'input eligibility',
        () => {
          currentPlacement.inputEnabled = false;
        },
        false,
      ],
      [
        'presentation blend',
        () => {
          currentPlacement.blend = 0.5;
        },
        false,
      ],
      ...(['left', 'top', 'width', 'height'] as const).map(
        (key) =>
          [
            `viewport ${key}`,
            () => {
              currentViewport[key] += 0.25;
            },
            true,
          ] as const,
      ),
      ...(['left', 'top', 'width', 'height'] as const).map(
        (key) =>
          [
            `selected ROI ${key}`,
            () => {
              currentPlacement.restRegion[key] += 0.25;
            },
            true,
          ] as const,
      ),
    ] as const) {
      mutate();
      const expected = module.composeCameraPose(
        currentFrame,
        currentViewport,
        currentPlacement,
      );
      const before = count();
      assert.deepEqual(
        resolve(currentFrame, currentViewport, currentPlacement),
        expected,
        `${name} remains current`,
      );
      if (refits)
        assert.ok(count() > before, `${name} refits its changed geometry`);
      else
        assert.equal(count(), before, `${name} keeps the same fitted endpoint`);
    }
  });
});

test('rest/live ROI switches and invalid or removed placements invalidate only that scene endpoint fit', async () => {
  const module = await helpers();
  const resolve = module.createCameraPoseResolver();
  const moving: StoryFrame = {
    ...experience,
    cameraTrack: { from: 'scoring', to: 'experience', progress: 0.4 },
  };
  const currentPlacement = { ...placement, restRegion: { ...region } };
  countCameraRays((count) => {
    const check = (
      frame: StoryFrame,
      current: CameraPlacement | null,
      motion = true,
    ) => {
      const expected = module.composeCameraPose(
        frame,
        viewport,
        current,
        motion,
      );
      const before = count();
      const actual = resolve(frame, viewport, current, motion);
      assert.deepEqual(actual, expected);
      return count() - before;
    };
    assert.ok(check(moving, currentPlacement) > 0);
    assert.ok(
      check(experience, currentPlacement) > 0,
      'live reading ROI has an independent source even with equal coordinates',
    );
    assert.equal(
      check({ ...experience, progress: 0.75 }, currentPlacement),
      0,
      'unchanged live ROI stays fitted',
    );
    assert.ok(
      check(moving, currentPlacement) > 0,
      'returning to the static source refits',
    );
    assert.ok(
      check(moving, currentPlacement, false) > 0,
      'reduced motion immediately selects the live reading ROI',
    );
    assert.ok(check(moving, currentPlacement) > 0);
    assert.equal(check(moving, null), 0);
    assert.ok(
      check(moving, currentPlacement) > 0,
      'restoring a removed placement refits',
    );
    assert.equal(check(moving, { ...currentPlacement, blend: NaN }), 0);
    assert.ok(
      check(moving, currentPlacement) > 0,
      'a restored valid placement cannot use an obsolete fit',
    );
  });
});

test('mutated camera input scalars invalidate the scene snapshot and preserve projection', async () => {
  const module = await helpers();
  assert.equal(typeof module.createCameraPoseResolver, 'function');
  const resolve = module.createCameraPoseResolver();
  const currentFrame: StoryFrame = {
    chapter: 'scoring',
    progress: 0.2,
    active: true,
    cameraTrack: { from: 'scoring', to: 'experience', progress: 0.2 },
  };
  const currentViewport = { ...viewport };
  const currentPlacement = {
    ...placement,
    region: { ...region },
    restRegion: { ...region },
    blend: 0.65,
  };
  let motionEnabled = true;
  const mutations: [string, () => void][] = [
    ['progress', () => (currentFrame.progress = 0.7)],
    ['track progress', () => (currentFrame.cameraTrack!.progress = 0.7)],
    ['track source', () => (currentFrame.cameraTrack!.from = 'experience')],
    ['track target', () => (currentFrame.cameraTrack!.to = 'replay')],
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
    ['rest region left', () => (currentPlacement.restRegion.left += 25)],
    ['rest region top', () => (currentPlacement.restRegion.top += 10)],
    ['rest region width', () => (currentPlacement.restRegion.width -= 40)],
    ['rest region height', () => (currentPlacement.restRegion.height -= 30)],
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
      const actual = resolve(
        currentFrame,
        currentViewport,
        currentPlacement,
        motionEnabled,
      );
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
