import type { CourtPoint } from './scene-contract';
import { netResponse, SHOT_TIMING } from './shot-timing.ts';

export type ShotVector = [number, number, number];

export interface ShotPose {
  position: ShotVector;
  /** World units per second; the same derivative is used on both sides of the rim. */
  velocity: ShotVector;
  rotation: ShotVector;
  phase: 'flight' | 'swish' | 'rebound' | 'rest';
  visible: boolean;
  recorded: boolean;
  netImpact: number;
  trailProgress: number;
  trailOpacity: number;
  shadow: {
    center: ShotVector;
    scale: [number, number];
    opacity: number;
  };
}

const RIM: ShotVector = [0, 3.05, -5.3];
const LAUNCH_HEIGHT = 1.2;
const RIM_DOWN_SPEED = -4.2;
const EXIT_DOWN_SPEED = -2.4;
const NET_DROP = 0.95;
const clamp = (value: number) => Math.max(0, Math.min(1, value));
const progress = (value: number) => (Number.isFinite(value) ? clamp(value) : 0);
const coordinate = (value: number) =>
  Number.isFinite(value) ? clamp(value) : 0.5;
const smoothstep = (value: number) => value * value * (3 - 2 * value);

function shotPath(point: CourtPoint) {
  const launch: ShotVector = [
    (coordinate(point.x) - 0.5) * 15,
    LAUNCH_HEIGHT,
    (coordinate(point.y) - 0.5) * 14,
  ];
  const dx = RIM[0] - launch[0];
  const dz = RIM[2] - launch[2];
  const distance = Math.hypot(dx, dz);
  const launchVelocity: ShotVector = [
    (dx * 1.75) / SHOT_TIMING.flight,
    11 + Math.min(5.5, distance * 0.42),
    (dz * 1.75) / SHOT_TIMING.flight,
  ];
  // A small amount of forward momentum survives the rim. Even the far corner
  // stays within 11cm of its centre during the visible net passage.
  const rimVelocity: ShotVector = [
    (dx * 0.025) / SHOT_TIMING.flight,
    RIM_DOWN_SPEED,
    (dz * 0.025) / SHOT_TIMING.flight,
  ];
  return { launch, launchVelocity, rimVelocity };
}

/** Cubic Hermite interpolation with derivatives expressed in seconds. */
function hermite(
  start: ShotVector,
  end: ShotVector,
  startVelocity: ShotVector,
  endVelocity: ShotVector,
  duration: number,
  u: number,
) {
  const u2 = u * u;
  const u3 = u2 * u;
  const h00 = 2 * u3 - 3 * u2 + 1;
  const h10 = u3 - 2 * u2 + u;
  const h01 = -2 * u3 + 3 * u2;
  const h11 = u3 - u2;
  const d00 = (6 * u2 - 6 * u) / duration;
  const d10 = 3 * u2 - 4 * u + 1;
  const d01 = (-6 * u2 + 6 * u) / duration;
  const d11 = 3 * u2 - 2 * u;
  const position: ShotVector = [0, 0, 0];
  const velocity: ShotVector = [0, 0, 0];
  for (let axis = 0; axis < 3; axis++) {
    position[axis] =
      h00 * start[axis]! +
      h10 * duration * startVelocity[axis]! +
      h01 * end[axis]! +
      h11 * duration * endVelocity[axis]!;
    velocity[axis] =
      d00 * start[axis]! +
      d10 * startVelocity[axis]! +
      d01 * end[axis]! +
      d11 * endVelocity[axis]!;
  }
  return { position, velocity };
}

/** Static trail geometry and live animation use precisely the same flight path. */
export function shotFlightPoint(
  point: CourtPoint,
  flightProgress: number,
): ShotVector {
  const path = shotPath(point);
  return hermite(
    path.launch,
    RIM,
    path.launchVelocity,
    path.rimVelocity,
    SHOT_TIMING.flight,
    progress(flightProgress),
  ).position;
}

/** One deterministic timeline; no renderer, mutable clock or physics state. */
export function sampleShotPose(point: CourtPoint, elapsed: number): ShotPose {
  const time = Number.isFinite(elapsed)
    ? Math.max(0, Math.min(SHOT_TIMING.total, elapsed))
    : 0;
  const path = shotPath(point);
  const flightProgress = clamp(time / SHOT_TIMING.flight);
  const fall = clamp((time - SHOT_TIMING.flight) / SHOT_TIMING.swish);
  const visible = time < SHOT_TIMING.mark;
  let motion: { position: ShotVector; velocity: ShotVector };
  if (time < SHOT_TIMING.flight) {
    motion = hermite(
      path.launch,
      RIM,
      path.launchVelocity,
      path.rimVelocity,
      SHOT_TIMING.flight,
      flightProgress,
    );
  } else {
    const exit: ShotVector = [
      RIM[0] + path.rimVelocity[0] * SHOT_TIMING.swish,
      RIM[1] - NET_DROP,
      RIM[2] + path.rimVelocity[2] * SHOT_TIMING.swish,
    ];
    const exitVelocity: ShotVector = [
      path.rimVelocity[0],
      EXIT_DOWN_SPEED,
      path.rimVelocity[2],
    ];
    if (time < SHOT_TIMING.mark) {
      // The net gently slows the descent instead of starting a second eased fall
      // from rest. Shared rim velocity makes the visible trajectory C1.
      motion = hermite(
        RIM,
        exit,
        path.rimVelocity,
        exitVelocity,
        SHOT_TIMING.swish,
        fall,
      );
    } else {
      const afterMark = time - SHOT_TIMING.mark;
      motion = {
        position: [
          exit[0] + exitVelocity[0] * afterMark,
          exit[1] + exitVelocity[1] * afterMark,
          exit[2] + exitVelocity[2] * afterMark,
        ],
        velocity: exitVelocity,
      };
    }
  }
  const height = Math.max(0, motion.position[1]);
  const shadowFade = visible ? 1 - smoothstep(fall) : 0;
  return {
    ...motion,
    rotation: [
      (time * Math.PI * 3.4) / SHOT_TIMING.flight,
      (time * Math.PI * 1.8) / SHOT_TIMING.flight,
      0.15,
    ],
    phase:
      time < SHOT_TIMING.flight
        ? 'flight'
        : time < SHOT_TIMING.mark
          ? 'swish'
          : time < SHOT_TIMING.total
            ? 'rebound'
            : 'rest',
    visible,
    recorded: time >= SHOT_TIMING.mark,
    netImpact: netResponse(time),
    trailProgress: flightProgress,
    trailOpacity: visible ? 0.86 * (1 - smoothstep(fall)) : 0,
    shadow: {
      center: [motion.position[0], 0.018, motion.position[2]],
      scale: [0.6 + height * 0.16, 0.46 + height * 0.12],
      opacity: (0.28 / (1 + height * height * 0.32)) * shadowFade,
    },
  };
}
