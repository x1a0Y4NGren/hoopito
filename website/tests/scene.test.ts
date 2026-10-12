import assert from 'node:assert/strict';
import { test } from 'node:test';

test('chapter camera endpoints join without a jump and invalid progress cannot poison a pose', async () => {
  const { storyPose } = await import('../src/scripts/story-pose.ts');
  const chapters = [
    'hero',
    'scoring',
    'experience',
    'replay',
    'download',
  ] as const;
  for (let index = 1; index < chapters.length; index += 1) {
    const previous = storyPose({
      chapter: chapters[index - 1]!,
      progress: 1,
      active: true,
    });
    const next = storyPose({
      chapter: chapters[index]!,
      progress: 0,
      active: true,
    });
    assert.deepEqual(
      next,
      previous,
      'Adjacent chapters share one camera and lighting pose',
    );
  }
  for (const progress of [NaN, Infinity, -1]) {
    assert.deepEqual(
      storyPose({ chapter: 'hero', progress, active: true }),
      storyPose({ chapter: 'hero', progress: 0, active: true }),
    );
  }
  assert.deepEqual(
    storyPose({ chapter: 'replay', progress: 2, active: true }),
    storyPose({ chapter: 'replay', progress: 1, active: true }),
  );
});

test('idle, background and one delayed frame do not lower rendering quality', async () => {
  const { ActiveFrameMonitor } =
    await import('../src/scripts/scene-performance.ts');
  const monitor = new ActiveFrameMonitor();
  for (let now = 0; now < 20_000; now += 100) monitor.observe(now, false);
  let now = 20_000;
  for (let frame = 0; frame < 200; frame += 1) {
    now += 1000 / 60;
    monitor.observe(now, true);
  }
  now += 20_000;
  monitor.observe(now, true);
  for (let frame = 0; frame < 150; frame += 1) {
    now += 1000 / 60;
    monitor.observe(now, true);
  }
  assert.equal(monitor.quality, 'full');
});

test('sustained active load removes effects before reducing density and respects cooldown', async () => {
  const { ActiveFrameMonitor, renderDensity } =
    await import('../src/scripts/scene-performance.ts');
  const monitor = new ActiveFrameMonitor();
  let now = 0;
  const changes: string[] = [];
  for (; now < 5500; now += 28) {
    const sample = monitor.observe(now, true);
    if (sample?.changed) changes.push(sample.quality);
  }
  assert.deepEqual(changes, ['effects']);
  for (; now < 12_000; now += 28) {
    const sample = monitor.observe(now, true);
    if (sample?.changed) changes.push(sample.quality);
  }
  assert.deepEqual(changes, ['effects', 'density']);
  assert.equal(renderDensity(2, 'density', 1440, 900), 1.5);
  assert.equal(renderDensity(1, 'density', 1920, 1080), 1);
  assert.ok(renderDensity(2, 'full', 1920, 1080) >= 1.5);
});

test('short recovery cannot oscillate quality and sustained recovery restores only one tier at a time', async () => {
  const { ActiveFrameMonitor } =
    await import('../src/scripts/scene-performance.ts');
  const monitor = new ActiveFrameMonitor();
  let now = 0;
  for (; now < 5500; now += 28) monitor.observe(now, true);
  for (; now < 8000; now += 1000 / 60) monitor.observe(now, true);
  assert.equal(monitor.quality, 'effects');
  for (; now < 25_000; now += 1000 / 60) monitor.observe(now, true);
  assert.equal(monitor.quality, 'full');
});

test('reading and download stop refreshes while a visible shot or camera movement keeps rendering', async () => {
  const { shouldRenderContinuously } =
    await import('../src/scripts/scene-performance.ts');
  const reading = {
    active: true,
    chapter: 'hero' as const,
    paused: false,
    motionEnabled: true,
    moving: false,
  };
  assert.equal(shouldRenderContinuously(reading), false);
  assert.equal(shouldRenderContinuously({ ...reading, moving: true }), true);
  assert.equal(
    shouldRenderContinuously({ ...reading, moving: true, paused: true }),
    false,
  );
  assert.equal(
    shouldRenderContinuously({ ...reading, moving: true, chapter: 'download' }),
    false,
  );
  assert.equal(
    shouldRenderContinuously({ ...reading, moving: true, active: false }),
    false,
  );
  assert.equal(
    shouldRenderContinuously({
      ...reading,
      moving: true,
      motionEnabled: false,
    }),
    false,
  );
});

test('reduced motion keeps one hero pose across scrolling and full motion resolves the retained chapter', async () => {
  const { storyPose } = await import('../src/scripts/story-pose.ts');
  const hero = storyPose({ chapter: 'hero', progress: 0, active: true });
  const latest = { chapter: 'replay' as const, progress: 0.72, active: true };
  for (const chapter of [
    'hero',
    'scoring',
    'experience',
    'replay',
    'download',
  ] as const) {
    for (const progress of [0, 0.5, 1]) {
      assert.deepEqual(
        storyPose({ chapter, progress, active: true }, false),
        hero,
      );
    }
  }
  assert.deepEqual(storyPose(latest, false), hero);
  assert.deepEqual(latest, { chapter: 'replay', progress: 0.72, active: true });
  assert.deepEqual(storyPose(latest, true), storyPose(latest));
  assert.notDeepEqual(storyPose(latest, true), hero);
});

test('restoring the same recorded shot keeps its rebound alive while replacement or reset cancels it', async () => {
  const { ShotContinuation } = await import('../src/scripts/scene-contract.ts');
  const owner = new ShotContinuation();
  const shot = new AbortController();
  const point = { x: 0.5, y: 0.65 };
  owner.begin(point, () => shot.abort());
  owner.restore({ ...point });
  assert.equal(
    shot.signal.aborted,
    false,
    'The marker completion must preserve the same shot’s rebound',
  );
  owner.restore({ x: 0.25, y: 0.65 });
  assert.equal(
    shot.signal.aborted,
    true,
    'Restoring a different location cancels the old animation',
  );

  const resetShot = new AbortController();
  owner.begin(point, () => resetShot.abort());
  owner.cancel();
  assert.equal(
    resetShot.signal.aborted,
    true,
    'A real reset still cancels animation callbacks',
  );
});

test('a new decorative shot cancels the previous one and a cleared marker cannot preserve it', async () => {
  const { ShotContinuation } = await import('../src/scripts/scene-contract.ts');
  const owner = new ShotContinuation();
  const oldShot = new AbortController();
  const nextShot = new AbortController();
  const oldGeneration = owner.begin({ x: 0.5, y: 0.65 }, () => oldShot.abort());
  owner.begin({ x: 0.25, y: 0.65 }, () => nextShot.abort());
  assert.equal(oldShot.signal.aborted, true);
  assert.equal(nextShot.signal.aborted, false);
  owner.complete(oldGeneration);
  owner.restore({ x: 0.25, y: 0.65 });
  assert.equal(
    nextShot.signal.aborted,
    false,
    'A stale completion cannot clear the replacement shot owner',
  );
  owner.restore(null);
  assert.equal(nextShot.signal.aborted, true);
});

test('sustained 300ms active frames still reduce effects before density', async () => {
  const { ActiveFrameMonitor } =
    await import('../src/scripts/scene-performance.ts');
  const monitor = new ActiveFrameMonitor();
  const changes: string[] = [];
  for (let now = 0; now < 15_000; now += 300) {
    const sample = monitor.observe(now, true);
    if (sample?.changed) changes.push(sample.quality);
  }
  assert.deepEqual(changes, ['effects', 'density']);
});

test('a severely overloaded 1.8-second introduction reduces effects before it ends', async () => {
  const { ActiveFrameMonitor } =
    await import('../src/scripts/scene-performance.ts');
  const monitor = new ActiveFrameMonitor();
  const changes: string[] = [];
  for (let now = 0; now <= 1800; now += 40) {
    const sample = monitor.observe(now, true);
    if (sample?.changed) changes.push(sample.quality);
  }
  assert.deepEqual(changes, ['effects']);
});

test('short visible reading pauses retain slow active evidence without sampling idle time', async () => {
  const { ActiveFrameMonitor } =
    await import('../src/scripts/scene-performance.ts');
  const monitor = new ActiveFrameMonitor();
  const changes: string[] = [];
  let now = 0;
  for (let segment = 0; segment < 3; segment += 1) {
    const end = now + 1400;
    for (; now <= end; now += 25) {
      const sample = monitor.observe(now, true);
      if (sample) {
        assert.equal(
          sample.average,
          25,
          'Reading time cannot enter the average',
        );
        assert.equal(sample.p95, 25);
      }
      if (sample?.changed) changes.push(sample.quality);
    }
    monitor.observe(now, false);
    now += 4000;
  }
  assert.deepEqual(changes, ['effects']);
});

test('idle expiry and explicit suspension discard partial slow evidence', async () => {
  const { ActiveFrameMonitor } =
    await import('../src/scripts/scene-performance.ts');
  for (const interruption of ['idle-expiry', 'suspension'] as const) {
    const monitor = new ActiveFrameMonitor();
    let now = 0;
    for (; now <= 1700; now += 25) monitor.observe(now, true);
    assert.equal(monitor.quality, 'full');
    monitor.observe(now, false);
    if (interruption === 'suspension') monitor.reset();
    now += interruption === 'idle-expiry' ? 8001 : 1000;
    const end = now + 1700;
    for (; now <= end; now += 25) monitor.observe(now, true);
    assert.equal(
      monitor.quality,
      'full',
      `${interruption} must start a fresh slow-evidence window`,
    );
  }
});

test('severe short shots respect density cooldown across visible idle', async () => {
  const { ActiveFrameMonitor } =
    await import('../src/scripts/scene-performance.ts');
  const monitor = new ActiveFrameMonitor();
  const changes: { quality: string; at: number }[] = [];
  let now = 0;
  for (let segment = 0; segment < 5; segment += 1) {
    const end = now + 1800;
    for (; now <= end; now += 40) {
      const sample = monitor.observe(now, true);
      if (sample?.changed) changes.push({ quality: sample.quality, at: now });
    }
    monitor.observe(now, false);
    now += 1000;
  }
  assert.deepEqual(
    changes.map((change) => change.quality),
    ['effects', 'density'],
  );
  assert.ok(changes[1]!.at - changes[0]!.at >= 6000);
});

test('lower quality uses direct output only when native edge antialiasing is available', async () => {
  const { sceneRenderRoute } =
    await import('../src/scripts/scene-performance.ts');
  assert.equal(sceneRenderRoute('full', 4), 'hdr');
  for (const quality of ['effects', 'density'] as const) {
    assert.equal(sceneRenderRoute(quality, 4), 'direct');
    for (const samples of [0, -1, NaN, Infinity]) {
      assert.equal(
        sceneRenderRoute(quality, samples),
        'hdr',
        'Missing native antialiasing must retain the offscreen antialiasing path',
      );
    }
  }
});
