import type { StoryChapter, StoryFrame } from './scene-contract.ts';

type Point3 = [number, number, number];

export interface StoryPose {
  position: Point3;
  target: Point3;
  /** Explicit screen-up avoids lookAt roll collapsing at the overhead pole. */
  up?: Point3;
  /** Horizontal off-axis perspective shift in millimetres; unset means zero. */
  filmOffset?: number;
  fov: number;
  light: number;
  reveal: number;
}

const chapters: readonly StoryChapter[] = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
  'community',
];
const reading: Record<StoryChapter, StoryPose> = {
  hero: {
    position: [2.73, 0.195, 4.44],
    target: [2.5, 0.2, 4.03],
    fov: 48,
    light: 1,
    reveal: 1.1,
  },
  scoring: {
    position: [9.8, 4.7, 11.8],
    target: [-1, 1, -3],
    fov: 49,
    light: 0.92,
    reveal: 1.1,
  },
  experience: {
    position: [0, 23.2, 0],
    target: [0, 0, 0],
    up: [0, 0, -1],
    fov: 38,
    light: 0.96,
    reveal: 1.1,
  },
  replay: {
    position: [-10.8, 4.9, 10.5],
    target: [1, 1, -3.8],
    fov: 47,
    light: 0.88,
    reveal: 1.1,
  },
  download: {
    position: [-3.8, 4.7, -1.3],
    target: [0, 3.1, -5.7],
    fov: 43,
    light: 0.95,
    reveal: 1.1,
  },
  community: {
    position: [10.8, 5.1, 15],
    target: [0, 1, -2.4],
    fov: 49,
    light: 0.92,
    reveal: 1.1,
  },
};

const mix = (from: number, to: number, progress: number) =>
  from + (to - from) * progress;
const radians = (degrees: number) => (degrees * Math.PI) / 180;
const cubic = (from: number, a: number, b: number, to: number, t: number) =>
  (1 - t) ** 3 * from +
  3 * (1 - t) ** 2 * t * a +
  3 * (1 - t) * t ** 2 * b +
  t ** 3 * to;

export function readingPose(chapter: StoryChapter): StoryPose {
  const pose = reading[chapter];
  return {
    ...pose,
    position: [...pose.position],
    target: [...pose.target],
    ...(pose.up ? { up: [...pose.up] as Point3 } : {}),
  };
}

// Controls describe an orbit around a moving subject in world metres. They
// retreat at floor level, climb to the pole, descend on the opposite sideline,
// approach the basket, and pull back around the arena. No idle clock is used.
const routes = [
  { yaw: [70, 58], elevation: [0, 12], radius: [5.5, 15.5], bank: -4 },
  { yaw: [40, 0], elevation: [72, 80], radius: [19, 30], bank: 5 },
  { yaw: [-55, -32], elevation: [68, 34], radius: [22, 15], bank: -5 },
  { yaw: [-48, -50], elevation: [24, 16], radius: [12, 7], bank: 3 },
  { yaw: [-100, 37], elevation: [12, 28], radius: [15, 18], bank: 4 },
] as const;

/** A single world-space evaluation, with the fitted reading poses as endpoints. */
export function evaluateCameraTrack(
  track: NonNullable<StoryFrame['cameraTrack']>,
  from: StoryPose,
  to: StoryPose,
): StoryPose {
  const index = chapters.indexOf(track.from);
  const route = routes[index];
  if (
    !route ||
    chapters[index + 1] !== track.to ||
    !Number.isFinite(track.progress)
  )
    return from;
  const raw = Math.max(0, Math.min(1, track.progress));
  if (raw === 0) return from;
  if (raw === 1) return to;
  const t = raw * raw * (3 - 2 * raw);
  const spherical = (pose: StoryPose) => {
    const x = pose.position[0] - pose.target[0];
    const y = pose.position[1] - pose.target[1];
    const z = pose.position[2] - pose.target[2];
    return {
      yaw: Math.atan2(x, z),
      elevation: Math.atan2(y, Math.hypot(x, z)),
      radius: Math.hypot(x, y, z),
    };
  };
  const a = spherical(from);
  const b = spherical(to);
  const yaw = cubic(
    a.yaw,
    radians(route.yaw[0]),
    radians(route.yaw[1]),
    b.yaw,
    t,
  );
  const elevation = cubic(
    a.elevation,
    radians(route.elevation[0]),
    radians(route.elevation[1]),
    b.elevation,
    t,
  );
  const radius = cubic(a.radius, route.radius[0], route.radius[1], b.radius, t);
  const target = from.target.map((value, axis) =>
    mix(value, to.target[axis]!, t),
  ) as Point3;
  const horizontal = Math.cos(elevation) * radius;
  const position: Point3 = [
    target[0] + Math.sin(yaw) * horizontal,
    target[1] + Math.sin(elevation) * radius,
    target[2] + Math.cos(yaw) * horizontal,
  ];
  // Analytic screen-up stays well-defined at the overhead pole. Bank is a
  // bounded accent (at most five degrees), returning to zero at both rests.
  const bank = radians(route.bank) * Math.sin(Math.PI * t) ** 2;
  const right: Point3 = [Math.cos(yaw), 0, -Math.sin(yaw)];
  const up: Point3 = [
    -Math.sin(yaw) * Math.sin(elevation),
    Math.cos(elevation),
    -Math.cos(yaw) * Math.sin(elevation),
  ];
  return {
    position,
    target,
    up: up.map(
      (value, axis) => value * Math.cos(bank) + right[axis]! * Math.sin(bank),
    ) as Point3,
    fov: mix(from.fov, to.fov, t),
    filmOffset: mix(from.filmOffset ?? 0, to.filmOffset ?? 0, t),
    light: mix(from.light, to.light, t),
    reveal: mix(from.reveal, to.reveal, t),
  };
}

export function storyPose(frame: StoryFrame, motionEnabled = true): StoryPose {
  if (!motionEnabled || !frame.cameraTrack) return readingPose(frame.chapter);
  return evaluateCameraTrack(
    frame.cameraTrack,
    readingPose(frame.cameraTrack.from),
    readingPose(frame.cameraTrack.to),
  );
}
