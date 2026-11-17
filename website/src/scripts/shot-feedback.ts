import { gsap } from 'gsap';
import type { CourtPoint } from './scene-contract';
import {
  SHOT_TIMING,
  shotFrame,
  shotTrailFrame,
  netPath,
} from './shot-timing.ts';
import { SHOT_VISUALS } from './shot-visuals.ts';

export function createShotFeedback(
  ball: SVGGElement,
  net: SVGPathElement,
  trail: SVGPathElement,
) {
  const svg = trail.ownerSVGElement;
  const halo = svg?.querySelector<SVGPathElement>('[data-demo-trail-halo]');
  const edge = svg?.querySelector<SVGPathElement>('[data-demo-trail-edge]');
  const gradients =
    svg?.querySelectorAll<SVGLinearGradientElement>(
      '[data-demo-trail-gradient]',
    ) ?? [];
  const trailFilter = svg?.querySelector<SVGFilterElement>(
    '[data-demo-trail-filter]',
  );
  const trailBlur = svg?.querySelector<SVGFEGaussianBlurElement>(
    '[data-demo-trail-blur]',
  );
  const markerGlows =
    svg?.querySelectorAll?.<SVGCircleElement>('[data-demo-marker-glow]') ?? [];
  const ballGlow = svg?.querySelector<SVGCircleElement>(
    '[data-demo-ball-glow]',
  );
  const trails = [halo, edge, trail].filter((layer) => layer != null);
  let animation: gsap.core.Tween | undefined;
  let paused = false;
  let revision = 0;
  let screenScale = 1,
    ballScale = 1;
  function sizeBallGlow() {
    ballGlow?.setAttribute(
      'r',
      String(SHOT_VISUALS.ballHaloPixels / 2 / screenScale / ballScale),
    );
  }
  function sizeGlows() {
    const matrix = svg?.getScreenCTM?.();
    screenScale = matrix ? Math.hypot(matrix.a, matrix.b) || 1 : 1;
    for (const glow of markerGlows)
      glow.setAttribute(
        'r',
        String(SHOT_VISUALS.markerHaloPixels / 2 / screenScale),
      );
    sizeBallGlow();
  }
  const resizeObserver =
    svg && typeof ResizeObserver !== 'undefined'
      ? new ResizeObserver(sizeGlows)
      : undefined;
  resizeObserver?.observe(svg!);
  sizeGlows();
  function rest() {
    ball.setAttribute('hidden', '');
    ballScale = 1;
    sizeBallGlow();
    for (const layer of trails) {
      layer.setAttribute('hidden', '');
      layer.setAttribute('d', '');
      layer.style.opacity = '0';
    }
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
      let delivered = false;
      const draw = () => {
        if (current !== revision) return;
        const pose = shotFrame(clock.time, point);
        ballScale = pose.scale;
        sizeBallGlow();
        ball.toggleAttribute('hidden', !pose.visible);
        ball.setAttribute(
          'transform',
          `translate(${pose.x} ${pose.y}) rotate(${pose.rotation}) scale(${pose.scale})`,
        );
        net.setAttribute('d', netPath(pose.impact));
        const segment = shotTrailFrame(clock.time, point);
        for (const layer of trails) {
          layer.toggleAttribute('hidden', segment.opacity <= 0);
          layer.style.opacity = String(segment.opacity);
          layer.setAttribute('d', segment.path);
        }
        for (const gradient of gradients) {
          gradient.setAttribute('x1', String(segment.start.x));
          gradient.setAttribute('y1', String(segment.start.y));
          gradient.setAttribute('x2', String(segment.end.x));
          gradient.setAttribute('y2', String(segment.end.y));
        }
        // Keep the soft layer's filter local to this short segment, in CSS pixels.
        const pad = SHOT_VISUALS.trailHaloPixels / screenScale;
        trailFilter?.setAttribute(
          'x',
          String(Math.min(segment.start.x, segment.end.x) - pad),
        );
        trailFilter?.setAttribute(
          'y',
          String(Math.min(segment.start.y, segment.end.y) - pad),
        );
        trailFilter?.setAttribute(
          'width',
          String(Math.abs(segment.end.x - segment.start.x) + pad * 2),
        );
        trailFilter?.setAttribute(
          'height',
          String(Math.abs(segment.end.y - segment.start.y) + pad * 2),
        );
        trailBlur?.setAttribute('stdDeviation', String(1.5 / screenScale));
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
    dispose() {
      cancel();
      resizeObserver?.disconnect();
    },
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
