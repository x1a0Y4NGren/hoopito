import assert from 'node:assert/strict';
import { test } from 'node:test';
import {
  createWheelWorkload,
  runWheelInput,
  serializeMeasurementFailure,
} from '../scripts/gpu-wheel-input.mjs';

const layout = {
  hero: { anchor: 0, stageTop: 0, start: 0, end: 675 },
  experience: { anchor: 2480, stageTop: 2568, start: 2480, end: 2768 },
  replay: { anchor: 4375, stageTop: 4150, start: 3700, end: 4375 },
};

function fixture() {
  let time = 100;
  let position = 0;
  const sent: { x: number; y: number }[] = [];
  const driver = {
    now: () => time,
    wait: async (milliseconds: number) => {
      time += milliseconds;
    },
    readPosition: async () => ({ scrollY: position, time }),
    wheel: async (x: number, y: number) => {
      sent.push({ x, y });
      position += y;
      time += 2;
    },
  };
  return {
    driver,
    sent,
    setPosition: (value: number) => {
      position = value;
    },
  };
}

test('entry inputs start before the 85% arrival line and end at actual chapter anchors', () => {
  for (const chapter of ['experience', 'replay'] as const) {
    const workload = createWheelWorkload(`${chapter}-wheel-entry`, layout, 900);
    assert.ok(layout[chapter].stageTop - workload.startY > 900 * 0.85);
    assert.equal(workload.targetY, layout[chapter].anchor);
    assert.equal(workload.targetChapter, chapter);
    assert.ok(workload.inputSequence.every((input) => input.deltaY > 0));
    const total = workload.inputSequence.reduce(
      (sum, input) => sum + input.deltaY,
      0,
    );
    assert.ok(Math.abs(total - (workload.targetY - workload.startY)) < 1e-7);
  }
});

test('cold and warmed documents with the same geometry replay exactly the same input schedule', () => {
  const cold = createWheelWorkload('experience-wheel-entry', layout, 900);
  const warm = createWheelWorkload(
    'experience-wheel-entry',
    structuredClone(layout),
    900,
  );
  assert.deepEqual(cold, warm);
  assert.equal(cold.inputMethod, 'page.mouse.wheel');
  assert.ok(cold.workloadVersion);
  const finalInput = cold.inputSequence.at(-1);
  assert.ok(finalInput);
  assert.ok(finalInput.atMs > 2000);
});

test('reverse workload crosses actual chapter boundaries with negative wheel input', () => {
  const workload = createWheelWorkload('reverse-wheel', layout, 900);
  assert.equal(workload.startY, layout.replay.anchor);
  assert.equal(workload.targetY, layout.hero.anchor);
  assert.equal(workload.targetChapter, 'hero');
  assert.ok(workload.inputSequence.every((input) => input.deltaY < 0));
});

test('runner sends every planned input and records dispatch timings and measured positions', async () => {
  const workload = createWheelWorkload('experience-wheel-entry', layout, 900);
  const { driver, sent, setPosition } = fixture();
  setPosition(workload.startY);
  const result = await runWheelInput(workload, driver);
  assert.equal(result.completed, true);
  assert.equal(sent.length, workload.inputSequence.length);
  assert.equal(result.emitted.length, sent.length);
  assert.ok(result.start);
  assert.ok(result.end);
  assert.equal(result.start.scrollY, workload.startY);
  assert.ok(Math.abs(result.end.scrollY - workload.targetY) < 1e-7);
  assert.ok(
    result.emitted.every(
      (event, index) =>
        event.dispatchedAtMs >= workload.inputSequence[index].atMs,
    ),
  );
  assert.ok(
    result.emitted.every(
      (event) =>
        event.completedAtMs !== null &&
        event.completedAtMs >= event.dispatchedAtMs,
    ),
  );
});

test('an early snap to the endpoint never short-circuits the prescribed wheel sequence', async () => {
  const workload = createWheelWorkload('replay-wheel-entry', layout, 900);
  const { driver, sent, setPosition } = fixture();
  setPosition(workload.startY);
  driver.wheel = async (x: number, y: number) => {
    sent.push({ x, y });
    setPosition(workload.targetY);
  };
  const result = await runWheelInput(workload, driver);
  assert.equal(result.completed, true);
  assert.equal(sent.length, workload.inputSequence.length);
});

test('expired schedules stop dispatching and retain partial input evidence', async () => {
  const workload = createWheelWorkload('experience-wheel-entry', layout, 900);
  const { driver, sent, setPosition } = fixture();
  setPosition(workload.startY);
  await assert.rejects(
    runWheelInput(workload, driver, { maximumMs: 100 }),
    (error: any) => {
      assert.match(error.message, /timed out/i);
      assert.equal(error.evidence.completed, false);
      assert.equal(error.evidence.emitted.length, sent.length);
      assert.ok(sent.length > 0 && sent.length < workload.inputSequence.length);
      return true;
    },
  );
});

test('wheel driver errors propagate with the original cause and partial evidence', async () => {
  const workload = createWheelWorkload('reverse-wheel', layout, 900);
  const { driver, setPosition } = fixture();
  setPosition(workload.startY);
  const failure = new Error('Input dispatch failed');
  driver.wheel = async () => {
    throw failure;
  };
  await assert.rejects(runWheelInput(workload, driver), (error: any) => {
    assert.equal(error.cause, failure);
    assert.equal(error.evidence.completed, false);
    assert.equal(error.evidence.emitted.length, 1);
    assert.equal(error.evidence.emitted[0].error, failure.message);
    return true;
  });
});

test('unknown phases and missing or reversed geometry fail instead of inventing a workload', () => {
  assert.throws(
    () => createWheelWorkload('replay-entry', layout, 900),
    /unknown/i,
  );
  assert.throws(
    () =>
      createWheelWorkload(
        'experience-wheel-entry',
        { ...layout, experience: { ...layout.experience, stageTop: null } },
        900,
      ),
    /geometry/i,
  );
  assert.throws(
    () =>
      createWheelWorkload(
        'experience-wheel-entry',
        { ...layout, experience: { ...layout.experience, anchor: 1 } },
        900,
      ),
    /direction/i,
  );
});

test('failed dispatch evidence survives report JSON with actual partial timings and workload identity', async () => {
  const workload = createWheelWorkload('experience-wheel-entry', layout, 900);
  const { driver, setPosition } = fixture();
  setPosition(workload.startY);
  const originalWheel = driver.wheel;
  let count = 0;
  driver.wheel = async (x: number, y: number) => {
    count += 1;
    if (count === 2) throw new Error('Wheel channel disconnected');
    await originalWheel(x, y);
  };
  try {
    await runWheelInput(workload, driver);
    assert.fail('The interrupted input must fail');
  } catch (failure: any) {
    const report = serializeMeasurementFailure(failure, workload);
    const persisted = JSON.parse(JSON.stringify(report));
    assert.equal(persisted.error, 'Wheel channel disconnected');
    assert.equal(persisted.errorEvidence.completed, false);
    assert.equal(persisted.errorEvidence.phase, workload.phase);
    assert.equal(
      persisted.errorEvidence.workloadVersion,
      workload.workloadVersion,
    );
    assert.equal(persisted.errorEvidence.inputMethod, 'page.mouse.wheel');
    assert.deepEqual(
      persisted.errorEvidence.inputSequence,
      workload.inputSequence,
    );
    assert.equal(persisted.errorEvidence.emitted.length, 2);
    assert.ok(persisted.errorEvidence.emitted[0].completedAtMs >= 0);
    assert.equal(persisted.errorEvidence.emitted[1].completedAtMs, null);
    assert.equal(
      persisted.errorEvidence.emitted[1].error,
      'Wheel channel disconnected',
    );
    assert.ok(persisted.errorEvidence.emitted[1].dispatchedAtMs >= 40);
    report.errorEvidence.emitted[0].deltaY = 999;
    assert.notEqual(failure.evidence.emitted[0].deltaY, 999);
    assert.equal('cause' in persisted, false);
    assert.equal('stack' in persisted, false);
  }
});

test('preparation failures retain the unstarted workload instead of dropping its planned inputs', () => {
  const workload = createWheelWorkload('replay-wheel-entry', layout, 900);
  const report = serializeMeasurementFailure(
    new Error('Preparation did not settle'),
    workload,
  );
  assert.equal(report.errorEvidence.phase, workload.phase);
  assert.equal(report.errorEvidence.workloadVersion, workload.workloadVersion);
  assert.equal(report.errorEvidence.inputMethod, workload.inputMethod);
  assert.deepEqual(report.errorEvidence.inputSequence, workload.inputSequence);
  assert.deepEqual(report.errorEvidence.emitted, []);
  assert.equal(report.errorEvidence.start, null);
  assert.equal(report.errorEvidence.end, null);
  assert.equal(report.errorEvidence.completed, false);
});

test('failure reporting normalizes plain evidence while excluding exception objects and circular references', () => {
  const evidence: any = {
    elapsedMs: 123,
    emitted: [{ dispatchedAtMs: 40, error: 'Input rejected' }],
    diagnostic: new Error('Do not serialize exception'),
    ignored: () => {},
  };
  evidence.self = evidence;
  const failure = Object.assign(
    new Error('Dispatch failed', { cause: new Error('native cause') }),
    { evidence },
  );
  const report = serializeMeasurementFailure(failure);
  const persisted = JSON.parse(JSON.stringify(report));
  assert.equal(persisted.error, 'Dispatch failed');
  assert.deepEqual(persisted.errorEvidence.emitted, evidence.emitted);
  assert.equal(persisted.errorEvidence.elapsedMs, 123);
  assert.equal('diagnostic' in persisted.errorEvidence, false);
  assert.equal('ignored' in persisted.errorEvidence, false);
  assert.equal('cause' in persisted, false);
});

test('non-wheel errors do not invent wheel evidence or metadata', () => {
  assert.deepEqual(
    serializeMeasurementFailure(new Error('Navigation failed')),
    { error: 'Navigation failed', errorEvidence: null },
  );
});
