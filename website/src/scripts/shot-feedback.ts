import { gsap } from 'gsap';
import type { CourtPoint } from './scene-contract';
import { SHOT_TIMING, shotFrame, netPath } from './shot-timing.ts';

export function createShotFeedback(
  ball: SVGGElement,
  net: SVGPathElement,
  trail: SVGPathElement,
) {
  let animation: gsap.core.Tween | undefined;
  let paused = false;
  let revision = 0;
  function rest() {
    ball.setAttribute('hidden', '');
    trail.setAttribute('hidden', '');
    net.setAttribute('d', netPath(0));
  }
  function cancel() {
    revision++;
    animation?.kill();
    animation = undefined;
    rest();
  }
  rest();
  return {
    /** The active GSAP clock excludes suspension and remains alive through rebound. */
    elapsed() {
      return animation?.time() ?? null;
    },
    start(point: CourtPoint, onRecorded: () => void) {
      cancel();
      const current = revision,
        clock = { time: 0 };
      const startX = 28 + point.x * 544,
        startY = 28 + point.y * 504;
      let delivered = false;
      const draw = () => {
        if (current !== revision) return;
        const pose = shotFrame(clock.time, point);
        ball.toggleAttribute('hidden', !pose.visible);
        ball.setAttribute(
          'transform',
          `translate(${pose.x} ${pose.y}) rotate(${pose.rotation}) scale(${pose.scale})`,
        );
        net.setAttribute('d', netPath(pose.impact));
        trail.toggleAttribute('hidden', pose.trailOpacity <= 0);
        trail.style.opacity = String(pose.trailOpacity);
        // A partial quadratic curve ends at the ball; the tail contracts through the rim.
        const p = pose.arcProgress;
        const end = shotFrame(Math.min(clock.time, SHOT_TIMING.flight), point);
        trail.setAttribute(
          'd',
          `M${startX} ${startY}Q${startX + ((300 - startX) * p) / 2} ${startY + (15 - startY) * p} ${end.x} ${end.y}`,
        );
        if (pose.recorded && !delivered) {
          delivered = true;
          onRecorded();
        }
      };
      animation = gsap.to(clock, {
        time: SHOT_TIMING.total,
        duration: SHOT_TIMING.total,
        ease: 'none',
        paused,
        onUpdate: draw,
        onComplete: () => {
          if (current !== revision) return;
          if (!delivered) onRecorded();
          animation = undefined;
          rest();
        },
      });
      draw();
    },
    cancel,
    pause() {
      paused = true;
      animation?.pause();
    },
    resume() {
      paused = false;
      animation?.resume();
    },
  };
}
