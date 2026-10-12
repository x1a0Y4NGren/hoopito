import type { StoryChapter, StoryFrame } from './scene-contract';

type Point3 = [number, number, number];

export interface StoryPose {
  position: Point3;
  target: Point3;
  fov: number;
  light: number;
  reveal: number;
}

// These are shared edit points, rather than independently authored chapter cameras.
// A chapter's final pose is exactly the next chapter's first pose in either scroll direction.
const anchors: readonly StoryPose[] = [
  {
    position: [2.73, 0.195, 4.44],
    target: [2.5, 0.2, 4.03],
    fov: 48,
    light: 1,
    reveal: 1.1,
  },
  {
    position: [12.5, 7.8, 15.5],
    target: [-0.8, 1, -3],
    fov: 42,
    light: 0.88,
    reveal: 1.1,
  },
  {
    position: [8.8, 4.6, 3.8],
    target: [-0.1, 2.2, -4.7],
    fov: 44,
    light: 0.8,
    reveal: 1.1,
  },
  {
    position: [0, 19, 9],
    target: [0, 0.1, -1],
    fov: 42,
    light: 0.85,
    reveal: 1.1,
  },
  {
    position: [0.3, 21, 1.6],
    target: [0, 0, -1.1],
    fov: 39,
    light: 0.72,
    reveal: 1.1,
  },
  {
    position: [-4.5, 4.6, 3.2],
    target: [0, 2.6, -5.3],
    fov: 40,
    light: 0.3,
    reveal: 1.1,
  },
];

const chapters: readonly StoryChapter[] = [
  'hero',
  'scoring',
  'experience',
  'replay',
  'download',
];
const controls: readonly [Point3, Point3][] = [
  [
    [3.5, 0.7, 6.7],
    [10, 5.3, 13.5],
  ],
  [
    [12, 7.8, 12.5],
    [10.1, 4.6, 6.2],
  ],
  [
    [9.2, 7.5, 6.2],
    [2.6, 15.5, 10.4],
  ],
  [
    [0, 20.5, 6.1],
    [0.3, 21, 3.9],
  ],
  [
    [-1.8, 17.8, 2.3],
    [-4.5, 8.8, 3.2],
  ],
];

const mix = (from: number, to: number, progress: number) =>
  from + (to - from) * progress;

export function storyPose(frame: StoryFrame, motionEnabled = true): StoryPose {
  // Accessibility keeps the same hero artwork while the caller retains current chapter state.
  const index = motionEnabled
    ? Math.max(0, chapters.indexOf(frame.chapter))
    : 0;
  const from = anchors[index]!;
  const to = anchors[index + 1]!;
  const raw =
    motionEnabled && Number.isFinite(frame.progress)
      ? Math.max(0, Math.min(1, frame.progress))
      : 0;
  if (raw === 0 || raw === 1) {
    const anchor = raw === 0 ? from : to;
    return {
      ...anchor,
      position: [...anchor.position],
      target: [...anchor.target],
    };
  }
  // Zero derivatives at chapter boundaries make reverse and fast scroll joins calm.
  const progress = raw * raw * (3 - 2 * raw);
  const inverse = 1 - progress;
  const control = controls[index]!;
  return {
    position: from.position.map(
      (value, axis) =>
        inverse ** 3 * value +
        3 * inverse ** 2 * progress * control[0][axis]! +
        3 * inverse * progress ** 2 * control[1][axis]! +
        progress ** 3 * to.position[axis]!,
    ) as Point3,
    target: from.target.map((value, axis) =>
      mix(value, to.target[axis]!, progress),
    ) as Point3,
    fov: mix(from.fov, to.fov, progress),
    light: mix(from.light, to.light, progress),
    reveal: mix(from.reveal, to.reveal, progress),
  };
}
