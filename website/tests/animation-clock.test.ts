import assert from 'node:assert/strict';
import { after, mock, test } from 'node:test';

// GSAP captures Date.now when it loads. Install the clock first so sparse
// display frames exercise its real ticker, rather than seeking a tween.
mock.timers.enable({ apis: ['Date'], now: 1_000_000 });
const { gsap } = await import('gsap');
const { createChapterPath } = await import('../src/scripts/chapter-scroll.ts');
const { createAnimationClock } =
  await import('../src/scripts/animation-clock.ts');
const { createShotFeedback } = await import('../src/scripts/shot-feedback.ts');
createAnimationClock();

function frameAfter(milliseconds: number) {
  mock.timers.tick(milliseconds);
  gsap.ticker.tick();
  gsap.ticker.sleep();
}

after(() => {
  gsap.globalTimeline.clear();
  gsap.ticker.sleep();
  mock.timers.reset();
});

test('hidden time and overlapping dialogs cannot advance a paused shot on resume', () => {
  const clock = createAnimationClock();
  const svg = () => ({ style: {}, setAttribute() {}, toggleAttribute() {} });
  const shot = createShotFeedback(
    svg() as unknown as SVGGElement,
    svg() as unknown as SVGPathElement,
    svg() as unknown as SVGPathElement,
  );
  let recorded = 0;
  shot.start({ x: 0.5, y: 0.5 }, () => recorded++);
  gsap.ticker.sleep();
  try {
    frameAfter(200);
    assert.equal(shot.elapsed(), 0.2);
    clock.setSuspended('hidden', true);
    shot.pause();
    const pausedAt = gsap.ticker.time;
    mock.timers.tick(10_000);
    clock.setSuspended('viewer', true);
    clock.setSuspended('hidden', false);
    assert.deepEqual([...clock.suspension], ['viewer']);
    assert.equal(gsap.ticker.time, pausedAt);
    assert.equal(shot.elapsed(), 0.2);
    mock.timers.tick(10_000);
    clock.setSuspended('viewer', false);
    assert.equal(clock.suspension.size, 0);
    assert.equal(
      shot.elapsed(),
      0.2,
      'catch up while the shot is still paused',
    );
    assert.equal(recorded, 0, 'hidden time cannot score the shot');
    shot.resume();
    gsap.ticker.sleep();
    assert.equal(shot.elapsed(), 0.2);
    frameAfter(100);
    assert.ok(
      Math.abs(shot.elapsed()! - 0.3) < 1e-9,
      'only visible resumed time advances the shot',
    );
    frameAfter(2000);
    assert.equal(recorded, 1, 'resumed playback still records exactly once');
  } finally {
    shot.cancel();
  }
});

test('a real 1.2-second chapter tween keeps its duration across slow software-rendered frames', () => {
  const path = createChapterPath(0, 1200);
  const motion = { progress: 0 };
  const positions: number[] = [];
  const started = Date.now();
  const tween = gsap.to(motion, {
    progress: 1,
    duration: 1.2,
    ease: 'none',
    onUpdate: () => positions.push(path(motion.progress)),
  });
  gsap.ticker.sleep();
  try {
    frameAfter(900);
    assert.equal(motion.progress, 0.75);
    assert.equal(tween.isActive(), true);
    frameAfter(900);
    assert.equal(motion.progress, 1);
    assert.equal(positions.at(-1), 1200);
    assert.equal(tween.isActive(), false);
    assert.equal(Date.now() - started, 1800);
  } finally {
    tween.kill();
  }
});
