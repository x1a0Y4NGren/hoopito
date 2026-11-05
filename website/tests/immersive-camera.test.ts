import assert from 'node:assert/strict';
import { test } from 'node:test';
import { storyPose } from '../src/scripts/story-pose.ts';

test('community and footer retain finite connected court camera poses', () => {
  const end = storyPose({
    chapter: 'download',
    progress: 1,
    active: true,
    cameraTrack: { from: 'download', to: 'community', progress: 1 },
  });
  const start = storyPose({ chapter: 'community', progress: 0, active: true });
  assert.deepEqual(start, end);
  const rest = storyPose({ chapter: 'community', progress: 1, active: true });
  assert.ok(
    [...rest.position, ...rest.target, rest.fov, rest.light].every(
      Number.isFinite,
    ),
  );
  assert.ok(
    rest.light >= 0.65,
    'The final court must remain visible behind glass',
  );
});

test('fullscreen macro framing keeps the basketball large on the right', async () => {
  const THREE = await import('three');
  const { composeCameraPose } =
    await import('../src/scripts/camera-placement.ts');
  const pose = composeCameraPose(
    { chapter: 'hero', progress: 0, active: true },
    { left: 0, top: 0, width: 1440, height: 900 },
    null,
  );
  const camera = new THREE.PerspectiveCamera(pose.fov, 1440 / 900, 0.015, 100);
  camera.position.set(...pose.position);
  camera.lookAt(new THREE.Vector3(...pose.target));
  camera.filmOffset = pose.filmOffset ?? 0;
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld();
  const ball = new THREE.Vector3(2.5, 0.2, 4.03).project(camera);
  const screenX = (ball.x + 1) * 0.5;
  assert.ok(
    screenX > 0.64 && screenX < 0.93,
    `ball center ${screenX} should leave room for the hero card`,
  );
});
