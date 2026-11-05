import * as THREE from 'three';
import { storyPose, evaluateCameraTrack } from './story-pose.ts';
import type { StoryPose } from './story-pose.ts';
import type {
  CameraPlacement,
  CourtPoint,
  SceneRegion,
  StoryFrame,
} from './scene-contract.ts';

const WIDTH = 15;
const LENGTH = 14;
const INSET = 24;
const floor = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
const clamp = (value: number) => Math.max(0, Math.min(1, value));
const validRegion = (region: SceneRegion) =>
  [region.left, region.top, region.width, region.height].every(
    Number.isFinite,
  ) &&
  region.width > 0 &&
  region.height > 0;

export function normalizeCameraPlacement(
  placement: CameraPlacement | null,
): CameraPlacement | null {
  if (
    !placement ||
    !Number.isFinite(placement.blend) ||
    !validRegion(placement.region) ||
    (placement.restRegion !== undefined &&
      (!validRegion(placement.restRegion) ||
        placement.restRegion.width <= INSET * 2 ||
        placement.restRegion.height <= INSET * 2)) ||
    placement.region.width <= INSET * 2 ||
    placement.region.height <= INSET * 2
  )
    return null;
  return {
    region: { ...placement.region },
    restRegion: { ...(placement.restRegion ?? placement.region) },
    blend: clamp(placement.blend),
    inputEnabled: placement.inputEnabled === true,
  };
}

/** The projection and inverse share the floor plane; marker lift is visual only. */
export function projectCourtPoint(
  point: CourtPoint,
  camera: THREE.PerspectiveCamera,
  viewport: SceneRegion,
): { x: number; y: number } | null {
  if (
    !validRegion(viewport) ||
    !Number.isFinite(point.x) ||
    !Number.isFinite(point.y)
  )
    return null;
  const projected = new THREE.Vector3(
    (point.x - 0.5) * WIDTH,
    0,
    (point.y - 0.5) * LENGTH,
  ).project(camera);
  if (![projected.x, projected.y, projected.z].every(Number.isFinite))
    return null;
  return {
    x: viewport.left + ((projected.x + 1) * viewport.width) / 2,
    y: viewport.top + ((1 - projected.y) * viewport.height) / 2,
  };
}

export function courtPointFromClient(
  clientX: number,
  clientY: number,
  camera: THREE.PerspectiveCamera,
  viewport: SceneRegion,
): CourtPoint | null {
  if (
    !validRegion(viewport) ||
    !Number.isFinite(clientX) ||
    !Number.isFinite(clientY)
  )
    return null;
  const pointer = new THREE.Vector2(
    ((clientX - viewport.left) / viewport.width) * 2 - 1,
    1 - ((clientY - viewport.top) / viewport.height) * 2,
  );
  const raycaster = new THREE.Raycaster();
  raycaster.setFromCamera(pointer, camera);
  const hit = raycaster.ray.intersectPlane(floor, new THREE.Vector3());
  if (!hit) return null;
  const x = hit.x / WIDTH + 0.5;
  const y = hit.z / LENGTH + 0.5;
  return x >= 0.02 && x <= 0.98 && y >= 0.04 && y <= 0.98 ? { x, y } : null;
}

function overheadPose(viewport: SceneRegion, region: SceneRegion): StoryPose {
  const pose = storyPose({ chapter: 'experience', progress: 0, active: true });
  const camera = new THREE.PerspectiveCamera(
    pose.fov,
    viewport.width / viewport.height,
    0.015,
    100,
  );
  camera.up.set(0, 0, -1);
  const center = new THREE.Vector2(
    ((region.left + region.width / 2 - viewport.left) / viewport.width) * 2 - 1,
    1 - ((region.top + region.height / 2 - viewport.top) / viewport.height) * 2,
  );
  const scale = Math.min(
    (region.width - INSET * 2) / WIDTH,
    (region.height - INSET * 2) / LENGTH,
  );
  let height =
    viewport.height / (2 * scale * Math.tan((pose.fov * Math.PI) / 360));
  const target = new THREE.Vector3();
  const raycaster = new THREE.Raycaster();
  const intersection = new THREE.Vector3();
  const corners = [
    { x: 0, y: 0 },
    { x: 1, y: 0 },
    { x: 0, y: 1 },
    { x: 1, y: 1 },
  ];
  // An explicit floor-aligned up vector stays well defined at the pole.
  // Reproject corners to retain the full 24px safety inset without cropping.
  for (let iteration = 0; iteration < 4; iteration += 1) {
    target.set(0, 0, 0);
    camera.position.set(0, height, 0);
    camera.lookAt(target);
    camera.updateMatrixWorld();
    raycaster.setFromCamera(center, camera);
    raycaster.ray.intersectPlane(floor, intersection);
    target.set(-intersection.x, 0, -intersection.z);
    camera.position.add(target);
    camera.lookAt(target);
    camera.updateMatrixWorld();
    let overflow = 1;
    for (const point of corners) {
      const client = projectCourtPoint(point, camera, viewport)!;
      overflow = Math.max(
        overflow,
        Math.abs(client.x - region.left - region.width / 2) /
          (region.width / 2 - INSET),
        Math.abs(client.y - region.top - region.height / 2) /
          (region.height / 2 - INSET),
      );
    }
    if (overflow <= 1.000001 || iteration === 3) break;
    height *= overflow * 1.000001;
  }
  // Keep the optical axis above x=0 so elevated basket hardware shares the
  // floor centerline. The horizontal film shift reproduces the fitted ground
  // projection exactly, without the height parallax of a translated camera.
  const filmOffset = (target.x / height) * camera.getFilmWidth();
  camera.position.x = 0;
  target.x = 0;
  return {
    ...pose,
    position: camera.position.toArray() as StoryPose['position'],
    target: target.toArray() as StoryPose['target'],
    up: [0, 0, -1],
    filmOffset,
  };
}

type OverheadFit = (
  viewport: SceneRegion,
  region: SceneRegion,
  source: 'rest' | 'live',
) => StoryPose;

function composeCameraPoseWithFit(
  frame: StoryFrame,
  viewport: SceneRegion,
  normalized: CameraPlacement | null,
  motionEnabled: boolean,
  fitOverhead: OverheadFit,
): StoryPose {
  const reading = (chapter: StoryFrame['chapter'], useRestRegion: boolean) => {
    const pose = storyPose({ chapter, progress: 0, active: true });
    if (chapter === 'experience' && normalized && validRegion(viewport))
      return fitOverhead(
        viewport,
        useRestRegion ? normalized.restRegion! : normalized.region,
        useRestRegion ? 'rest' : 'live',
      );
    // Preserve the existing full-viewport macro framing and ball volume.
    if (chapter === 'hero' && validRegion(viewport)) {
      const position = new THREE.Vector3(...pose.position);
      const target = new THREE.Vector3(...pose.target);
      const forward = target.clone().sub(position);
      const right = forward
        .clone()
        .cross(new THREE.Vector3(0, 1, 0))
        .normalize();
      const shift =
        0.5 *
        forward.length() *
        Math.tan((pose.fov * Math.PI) / 360) *
        (viewport.width / viewport.height);
      target.addScaledVector(right, -shift);
      pose.target = target.toArray() as StoryPose['target'];
    }
    return pose;
  };
  if (!motionEnabled || !frame.cameraTrack)
    return reading(frame.chapter, false);
  // The live card is moving during a flight. Its DOM rectangle must never
  // change a world-space endpoint; fit once to its transform-free reading ROI.
  const { from, to } = frame.cameraTrack;
  return evaluateCameraTrack(
    frame.cameraTrack,
    reading(from, true),
    reading(to, true),
  );
}

/** Uncached composition remains the reference for projection and diagnostics. */
export function composeCameraPose(
  frame: StoryFrame,
  viewport: SceneRegion,
  placement: CameraPlacement | null,
  motionEnabled = true,
): StoryPose {
  return composeCameraPoseWithFit(
    frame,
    viewport,
    normalizeCameraPlacement(placement),
    motionEnabled,
    overheadPose,
  );
}

export function createCameraPoseResolver(): typeof composeCameraPose {
  let previous: readonly unknown[] | undefined;
  let pose: StoryPose | undefined;
  let endpointSnapshot: readonly unknown[] | undefined;
  let endpoint: StoryPose | undefined;
  const fitOverhead: OverheadFit = (viewport, region, source) => {
    // Fit only the selected ROI. A live host moving during a flight has no
    // bearing on its static endpoint; changing progress still evaluates the
    // complete world track below. Keep a single fit owned by this scene.
    const snapshot = [
      source,
      viewport.left,
      viewport.top,
      viewport.width,
      viewport.height,
      region.left,
      region.top,
      region.width,
      region.height,
    ];
    if (
      endpoint &&
      endpointSnapshot &&
      snapshot.every((value, index) =>
        Object.is(value, endpointSnapshot![index]),
      )
    )
      return endpoint;
    endpoint = overheadPose(viewport, region);
    endpointSnapshot = snapshot;
    return endpoint;
  };
  return (frame, viewport, placement, motionEnabled = true) => {
    // Each scene retains one scalar snapshot, so fresh objects can reuse a pose
    // while in-place layout and story mutations always invalidate it.
    const snapshot = [
      frame.chapter,
      frame.progress,
      frame.active,
      frame.cameraTrack?.from,
      frame.cameraTrack?.to,
      frame.cameraTrack?.progress,
      viewport.left,
      viewport.top,
      viewport.width,
      viewport.height,
      placement !== null,
      placement?.region.left,
      placement?.region.top,
      placement?.region.width,
      placement?.region.height,
      placement?.restRegion?.left,
      placement?.restRegion?.top,
      placement?.restRegion?.width,
      placement?.restRegion?.height,
      placement?.blend,
      placement?.inputEnabled,
      motionEnabled,
    ];
    if (
      pose &&
      previous &&
      snapshot.every((value, index) => Object.is(value, previous![index]))
    )
      return pose;
    const normalized = normalizeCameraPlacement(placement);
    if (!normalized || !validRegion(viewport)) {
      // Removal or invalid geometry ends the previous placement's lifetime.
      // Restoration must fit the newly adopted region before accepting input.
      endpoint = undefined;
      endpointSnapshot = undefined;
    }
    pose = composeCameraPoseWithFit(
      frame,
      viewport,
      normalized,
      motionEnabled,
      fitOverhead,
    );
    previous = snapshot;
    return pose;
  };
}
