import assert from 'node:assert/strict';
import test from 'node:test';
import { cameraStateAtScroll } from '../src/scripts/camera-track.ts';
import {
  ChapterGesture,
  createChapterPath,
} from '../src/scripts/chapter-scroll.ts';
import {
  storyItemPose,
  storyStageState,
  storyStageOffset,
  storyOrnamentVisibility,
  type StoryRole,
} from '../src/scripts/story-choreography.ts';

const rest = { x: 0, y: 0, scale: 1, opacity: 1, reveal: 1 };
const roles: StoryRole[] = ['heading', 'visual', 'control', 'detail'];
const stops = [
  { id: 'hero' as const, readStart: 0, readEnd: 0 },
  { id: 'scoring' as const, readStart: 1000, readEnd: 1300 },
  { id: 'experience' as const, readStart: 2300, readEnd: 2600 },
  { id: 'replay' as const, readStart: 3600, readEnd: 3900 },
];

test('incoming roles use the shared flight windows and finish exactly at the reading pose', () => {
  for (const [role, start, end] of [
    ['visual', 0.32, 0.88],
    ['heading', 0.5, 0.94],
    ['control', 0.7, 1],
    ['detail', 0.7, 1],
  ] as const) {
    assert.equal(
      storyItemPose(start, role, 'left', 1600, { phase: 'incoming' }).opacity,
      0,
    );
    const middle = storyItemPose((start + end) / 2, role, 'left', 1600, {
      phase: 'incoming',
    });
    assert.ok(Math.abs(middle.opacity - 0.5) < 1e-10);
    assert.ok(Math.abs(middle.reveal - 0.5) < 1e-10);
    assert.deepEqual(
      storyItemPose(end, role, 'left', 1600, { phase: 'incoming' }),
      rest,
    );
    assert.deepEqual(
      storyItemPose(1, role, 'left', 1600, { phase: 'incoming' }),
      rest,
    );
  }
});

test('each outgoing window mirrors its incoming window for the same reverse arrival order', () => {
  for (const role of roles)
    assert.deepEqual(
      storyItemPose(0, role, 'right', 1600, { phase: 'outgoing' }),
      rest,
    );
  for (const role of ['control', 'detail'] as const) {
    assert.equal(
      storyItemPose(0.3 + 1e-10, role, 'left', 1600, { phase: 'outgoing' })
        .opacity,
      0,
    );
  }
  assert.equal(
    storyItemPose(0.5, 'heading', 'up', 1600, { phase: 'outgoing' }).opacity,
    0,
  );
  assert.equal(
    storyItemPose(0.68 + 1e-10, 'visual', 'right', 1600, { phase: 'outgoing' })
      .opacity,
    0,
  );
});

test('replay introduces the real result before its analysis and secondary archive, with complete reversible landings', () => {
  const pose = (preset: string, progress: number) =>
    storyItemPose(progress, 'visual', 'right', 1600, {
      phase: 'incoming',
      preset,
    });
  const presets = ['replay-summary', 'replay-analysis', 'replay-history'];
  const at = (progress: number) =>
    presets.map((preset) => pose(preset, progress).opacity);
  assert.ok(at(0.4)[0] > 0);
  assert.equal(at(0.4)[1], 0);
  assert.equal(at(0.4)[2], 0);
  assert.ok(at(0.5)[0] > at(0.5)[1]);
  assert.ok(at(0.5)[1] > 0);
  assert.equal(at(0.5)[2], 0);
  assert.ok(at(0.7)[1] > at(0.7)[2]);
  assert.ok(at(0.7)[2] > 0);
  assert.deepEqual(pose('replay-summary', 0.84), rest);
  for (const preset of presets) {
    assert.deepEqual(pose(preset, 1), rest);
    const positions = Array.from({ length: 201 }, (_, index) => index / 200);
    const sample = (progress: number) => pose(preset, progress);
    assert.deepEqual(
      positions.map(sample),
      positions.toReversed().map(sample).toReversed(),
    );
  }
});

test('presets keep movement close to the viewport and expose only uniform transforms and reveal', () => {
  const screen = storyItemPose(0, 'visual', 'right', 1600, {
    phase: 'incoming',
    preset: 'scoring-screen',
  });
  const rail = storyItemPose(0, 'control', 'left', 1600, {
    phase: 'incoming',
    preset: 'scoring-rail',
  });
  assert.equal(screen.x, 288);
  assert.equal(rail.x, -192);
  assert.equal(screen.scale, 0.98);
  assert.equal(rail.scale, 0.99);
  for (const preset of ['hero-title', 'chapter-title', 'download-title']) {
    const title = storyItemPose(0, 'heading', 'up', 1600, {
      phase: 'incoming',
      preset,
    });
    assert.equal(title.y, -24);
    assert.equal(title.scale, 1);
  }
  for (const role of ['control', 'detail'] as const)
    assert.equal(
      storyItemPose(0, role, 'up', 1600, { phase: 'incoming' }).y,
      -20,
    );
  const vertical = storyItemPose(0, 'visual', 'down', 1600, {
    phase: 'incoming',
    preset: 'download-card',
  });
  assert.ok(vertical.y > 0 && vertical.y <= 56);
  assert.deepEqual(Object.keys(screen).sort(), [
    'opacity',
    'reveal',
    'scale',
    'x',
    'y',
  ]);
  assert.notEqual(screen.x, Math.abs(rail.x));
});

test('elapsed wheel time composes through real scroll and camera state into spaced arrivals in either direction', () => {
  const groups = [
    {
      items: [{ role: 'visual' }, { role: 'heading' }, { role: 'control' }],
      expected: [497, 628, 779],
    },
    {
      items: ['replay-summary', 'replay-analysis', 'replay-history'].map(
        (preset) => ({ role: 'visual', preset }),
      ),
      expected: [495, 621, 746],
    },
  ] as { items: { role: StoryRole; preset?: string }[]; expected: number[] }[];
  for (const { items, expected } of groups) {
    const starts: number[][] = [];
    for (const direction of [1, -1]) {
      const gesture = new ChapterGesture();
      const origin = direction > 0 ? 1300 : 2300;
      const action = gesture.input(direction * 24, 0, origin, stops, 900);
      assert.equal(action.kind, 'settle');
      if (action.kind !== 'settle') continue;
      assert.equal(action.duration, 1.2);
      const path = createChapterPath(origin, action.y);
      const arriving = direction > 0 ? 'experience' : 'scoring';
      const poseAt = (milliseconds: number, item: (typeof items)[number]) => {
        const y = path(milliseconds / (action.duration * 1000));
        const frame = cameraStateAtScroll(y, stops, 'hero');
        const stage = storyStageState(arriving, y, stops, frame.cameraTrack);
        return storyItemPose(stage.progress, item.role, 'left', 1600, {
          phase: stage.phase,
          preset: item.preset,
        });
      };
      const onsets = items.map((item, index) => {
        let min = 1,
          max = action.duration * 1000;
        for (let sample = 0; sample < 40; sample++) {
          const mid = (min + max) / 2;
          if (poseAt(mid, item).opacity >= 0.02) max = mid;
          else min = mid;
        }
        assert.ok(
          Math.abs(max - expected[index]) < 1,
          `onset ${index}: ${max}`,
        );
        assert.deepEqual(poseAt(1200, item), rest);
        let previous = 0;
        for (let elapsed = 1; elapsed <= 1200; elapsed++) {
          const opacity = poseAt(elapsed, item).opacity;
          assert.ok(opacity >= previous - 1e-12);
          previous = opacity;
        }
        return max;
      });
      assert.ok(onsets[1] - onsets[0] >= 120);
      assert.ok(onsets[2] - onsets[1] >= 120);
      starts.push(onsets);
    }
    for (let index = 0; index < items.length; index++)
      assert.ok(Math.abs(starts[0][index] - starts[1][index]) < 1e-8);
  }
});

test('all role and replay windows have mirrored opacity and scale with reversible poses and still endpoints', () => {
  const items = [
    ...roles.map((role) => ({ role, preset: undefined })),
    ...['replay-summary', 'replay-analysis', 'replay-history'].map(
      (preset) => ({ role: 'visual' as const, preset }),
    ),
  ];
  for (const { role, preset } of items) {
    for (const p of [0, 0.2, 0.4, 0.6, 0.8, 1]) {
      const incoming = storyItemPose(p, role, 'left', 1600, {
        phase: 'incoming',
        preset,
      });
      const reverse = storyItemPose(1 - p, role, 'left', 1600, {
        phase: 'outgoing',
        preset,
      });
      assert.ok(Math.abs(incoming.opacity - reverse.opacity) < 1e-10);
      assert.ok(Math.abs(incoming.scale - reverse.scale) < 1e-10);
      assert.ok(incoming.x <= 0 && reverse.x >= 0);
    }
    for (const phase of ['incoming', 'outgoing'] as const) {
      const sample = (p: number) =>
        storyItemPose(p, role, 'up', 1600, { phase, preset });
      for (const end of [0, 1]) {
        const a = sample(end),
          b = sample(end === 0 ? 1e-7 : 1 - 1e-7);
        assert.ok(Math.abs(a.y - b.y) / 1e-7 < 0.01);
        assert.ok(Math.abs(a.opacity - b.opacity) / 1e-7 < 0.001);
      }
    }
  }
});

test('native1440 midpoint geometry clears departing bright app screens from the next main visual', () => {
  // Production DOM rectangles from the first actual-scroll midpoint captures.
  // Their alpha/scale/windows stay fixed; project only the changed translation.
  const summary = [
    { progress: 0.4, opacity: 0.5581, right: 1011.8, incomingLeft: 624.9 },
    { progress: 0.5, opacity: 0.2769, right: 954.1, incomingLeft: 623.5 },
    { progress: 0.6, opacity: 0.0639, right: 910.5, incomingLeft: 621.6 },
  ];
  for (const sample of summary) {
    const pose = storyItemPose(sample.progress, 'visual', 'right', 1440, {
      phase: 'outgoing',
      preset: 'replay-summary',
    });
    assert.ok(Math.abs(pose.opacity - sample.opacity) < 0.001);
    const previousX = -1440 * 0.14 * (1 - sample.opacity);
    assert.ok(
      sample.right + pose.x - previousX + 16 < sample.incomingLeft,
      `summary clear at ${sample.progress}`,
    );
  }
  const scoring = [
    {
      progress: 0.4,
      opacity: 0.4996,
      left: 360.96,
      width: 865.76,
      incomingLeft: 401.69,
    },
    {
      progress: 0.5,
      opacity: 0.2438,
      left: 296.71,
      width: 860.89,
      incomingLeft: 400.27,
    },
    {
      progress: 0.6,
      opacity: 0.0551,
      left: 249.44,
      width: 857.57,
      incomingLeft: 398.37,
    },
  ];
  for (const sample of scoring) {
    const pose = storyItemPose(sample.progress, 'visual', 'right', 1440, {
      phase: 'outgoing',
      preset: 'scoring-screen',
    });
    const scale = 0.98 + 0.02 * sample.opacity;
    // The 12px padding +1px border and existing horizontal inner reveal bound
    // the actual bright screenshot, rather than the transparent optical shell.
    const brightRight =
      sample.left + 13 * scale + (sample.width - 26 * scale) * sample.opacity;
    const previousX = -1440 * 0.18 * (1 - sample.opacity);
    assert.ok(
      brightRight + pose.x - previousX + 8 < sample.incomingLeft,
      `scoring image clear at ${sample.progress}`,
    );
  }
});

test('native1440 midpoint geometry lifts the old scoreboard and download QR above the arriving visual', () => {
  const scoreboard = [
    { progress: 0.4, opacity: 0.5001, bottom: 323.22, incomingTop: 210.5 },
    { progress: 0.5, opacity: 0.2434, bottom: 333.1, incomingTop: 209.0 },
    { progress: 0.6, opacity: 0.0552, bottom: 340.3, incomingTop: 207.1 },
  ];
  for (const sample of scoreboard) {
    const pose = storyItemPose(sample.progress, 'visual', 'up', 1440, {
      phase: 'outgoing',
      preset: 'experience-scoreboard',
    });
    const previousY = 40 * (1 - sample.opacity);
    assert.ok(
      pose.y < 0,
      'the scoreboard retracts toward its upper entrance side',
    );
    assert.ok(
      sample.bottom + pose.y - previousY + 16 < sample.incomingTop,
      `scoreboard clear at ${sample.progress}`,
    );
  }
  const qr = [
    {
      progress: 0.4,
      opacity: 0.4994,
      top: 218.85,
      height: 130.68,
      incomingTop: 245.82,
    },
    {
      progress: 0.5,
      opacity: 0.2435,
      top: 206.51,
      height: 130.01,
      incomingTop: 244.91,
    },
    {
      progress: 0.6,
      opacity: 0.0557,
      top: 197.47,
      height: 129.51,
      incomingTop: 243.69,
    },
  ];
  for (const sample of qr) {
    const pose = storyItemPose(sample.progress, 'visual', 'down', 1440, {
      phase: 'outgoing',
      preset: 'download-card',
    });
    const previousY = -52 * (1 - sample.opacity);
    assert.ok(
      sample.top + sample.height + pose.y - previousY + 16 < sample.incomingTop,
      `download QR clear at ${sample.progress}`,
    );
  }
});

test('spatial departures retain the original entrance travel and exact same poses on reversed scroll', () => {
  for (const [preset, enter, entrance, exit] of [
    ['scoring-screen', 'right', { x: 259.2, y: 0 }, { x: -1080, y: 0 }],
    ['replay-summary', 'right', { x: 201.6, y: 0 }, { x: -1152, y: 0 }],
    ['experience-scoreboard', 'up', { x: 0, y: -40 }, { x: 0, y: -350 }],
    ['download-card', 'down', { x: 0, y: 52 }, { x: 0, y: -380 }],
  ] as const) {
    const incoming = storyItemPose(0, 'visual', enter, 1440, {
      phase: 'incoming',
      preset,
    });
    const outgoing = storyItemPose(1, 'visual', enter, 1440, {
      phase: 'outgoing',
      preset,
    });
    assert.ok(Math.abs(incoming.x - entrance.x) < 1e-10);
    assert.equal(incoming.y, entrance.y);
    assert.equal(outgoing.x, exit.x);
    assert.equal(outgoing.y, exit.y);
    for (const phase of ['incoming', 'outgoing'] as const) {
      const values = Array.from({ length: 101 }, (_, index) => index / 100);
      const sample = (progress: number) =>
        storyItemPose(progress, 'visual', enter, 1440, { phase, preset });
      assert.deepEqual(
        values.map(sample),
        values.toReversed().map(sample).toReversed(),
      );
      assert.deepEqual(
        storyItemPose(0.5, 'visual', enter, 1440, { phase: 'reading', preset }),
        rest,
      );
    }
  }
});

test('reading, hero opening, focused controls and disabled motion remain completely visible', () => {
  for (const role of roles) {
    for (const p of [0, 0.25, 0.8, 1]) {
      assert.deepEqual(
        storyItemPose(p, role, 'left', 1600, { phase: 'reading' }),
        rest,
      );
      for (const option of ['reduced', 'mobile', 'focused'] as const)
        assert.deepEqual(
          storyItemPose(p, role, 'left', 1600, {
            phase: 'incoming',
            [option]: true,
          }),
          rest,
        );
    }
    assert.deepEqual(
      storyItemPose(0, role, 'left', 1600, { phase: 'incoming', hero: true }),
      rest,
    );
  }
});

test('stage ownership follows the same camera track, not DOM selection or pin progress', () => {
  const track = cameraStateAtScroll(1800, stops, 'hero').cameraTrack;
  const outgoing = storyStageState('scoring', 1800, stops, track);
  const incoming = storyStageState('experience', 1800, stops, track);
  assert.equal(outgoing.phase, 'outgoing');
  assert.equal(incoming.phase, 'incoming');
  assert.equal(outgoing.progress, 0.5);
  assert.equal(incoming.progress, 0.5);
  for (const y of [1000, 1150, 1300]) {
    const state = storyStageState('scoring', y, stops, undefined);
    assert.equal(state.phase, 'reading');
    assert.equal(storyStageOffset(state, { scroll: y, top: 1500 - y }), 0);
  }
});

test('natural-flow compensation joins both native reading boundaries without a card jump', () => {
  const documentTop = 1500;
  for (const [chapter, boundary] of [
    ['scoring', 1302],
    ['experience', 2298],
  ] as const) {
    const visibleY = (scroll: number) => {
      const frame = cameraStateAtScroll(scroll, stops, chapter);
      const state = storyStageState(chapter, scroll, stops, frame.cameraTrack);
      const pose = storyItemPose(state.progress, 'heading', 'up', 1600, {
        phase: state.phase,
      });
      const offset = storyStageOffset(state, {
        scroll,
        top: documentTop - scroll,
      });
      return documentTop - scroll + offset + pose.y;
    };
    assert.ok(
      Math.abs(visibleY(boundary - 0.0001) - visibleY(boundary + 0.0001)) <
        0.01,
    );
  }
});

test('pin compensation uses the measured static rest top and disappears during reading', () => {
  const state = storyStageState('experience', 1800, stops, {
    from: 'scoring',
    to: 'experience',
    progress: 0.5,
  });
  assert.equal(
    storyStageOffset(state, {
      scroll: 1800,
      top: 480,
      pinned: true,
      restTop: 100,
    }),
    -380,
  );
  const reading = storyStageState('experience', 2400, stops);
  assert.equal(
    storyStageOffset(reading, {
      scroll: 2400,
      top: 100,
      pinned: true,
      restTop: 100,
    }),
    0,
  );
});

test('track choreography reverses exactly and its role joins have zero visible velocity', () => {
  const values = Array.from({ length: 201 }, (_, index) => index / 200);
  const items: { role: StoryRole; preset?: string; enter: [number, number] }[] =
    [
      { role: 'visual', enter: [0.32, 0.88] },
      { role: 'heading', enter: [0.5, 0.94] },
      { role: 'control', enter: [0.7, 1] },
      { role: 'detail', enter: [0.7, 1] },
      { role: 'visual', preset: 'replay-summary', enter: [0.32, 0.84] },
      { role: 'visual', preset: 'replay-analysis', enter: [0.49, 0.94] },
      { role: 'visual', preset: 'replay-history', enter: [0.66, 0.98] },
    ];
  for (const { role, preset, enter } of items)
    for (const phase of ['incoming', 'outgoing'] as const) {
      const sample = (p: number) =>
        storyItemPose(p, role, 'right', 1600, {
          phase,
          preset,
        });
      assert.deepEqual(
        values.map(sample),
        values.toReversed().map(sample).toReversed(),
      );
      const ends = phase === 'incoming' ? enter : [1 - enter[1], 1 - enter[0]];
      for (const p of ends) {
        const epsilon = 1e-7;
        const a = sample(p - 1e-7),
          b = sample(p + 1e-7);
        assert.ok(Math.abs(a.x - b.x) / (2 * epsilon) < 0.01);
        assert.ok(Math.abs(a.opacity - b.opacity) / (2 * epsilon) < 0.00001);
      }
    }
});

test('composed native reading through long content never changes camera or item poses', () => {
  for (const y of [1000, 1050, 1150, 1250, 1300]) {
    const frame = cameraStateAtScroll(y, stops, 'hero');
    assert.equal(frame.cameraTrack, undefined);
    const state = storyStageState('scoring', y, stops, frame.cameraTrack);
    assert.equal(state.phase, 'reading');
    for (const role of roles)
      assert.deepEqual(
        storyItemPose(state.progress, role, 'left', 1600, {
          phase: state.phase,
        }),
        rest,
      );
  }
});

test('static chapter labels fade with the shared flight while the footer prompt leaves first', () => {
  const state = (
    phase: 'incoming' | 'outgoing' | 'reading' | 'hidden',
    progress: number,
  ) => ({
    phase,
    progress,
    anchorScroll: 1000,
  });
  for (const progress of [0, 0.5, 1])
    assert.deepEqual(storyOrnamentVisibility(state('reading', progress)), {
      opacity: 1,
      inert: false,
    });
  assert.deepEqual(storyOrnamentVisibility(state('hidden', 0)), {
    opacity: 0,
    inert: true,
  });
  assert.equal(storyOrnamentVisibility(state('incoming', 0.5)).opacity, 0);
  assert.equal(storyOrnamentVisibility(state('incoming', 0.94)).opacity, 1);
  assert.equal(storyOrnamentVisibility(state('outgoing', 0.5)).opacity, 0);
  assert.equal(
    storyOrnamentVisibility(state('outgoing', 0.3 + 1e-10), { secondary: true })
      .opacity,
    0,
  );
  assert.ok(storyOrnamentVisibility(state('outgoing', 0.3)).opacity > 0);
  for (const option of ['mobile', 'reduced', 'focused'] as const)
    assert.deepEqual(
      storyOrnamentVisibility(state('hidden', 1), { [option]: true }),
      { opacity: 1, inert: false },
    );
  const sample = (progress: number) =>
    storyOrnamentVisibility(state('incoming', progress));
  const positions = Array.from({ length: 101 }, (_, index) => index / 100);
  assert.deepEqual(
    positions.map(sample),
    positions.toReversed().map(sample).toReversed(),
  );
});
