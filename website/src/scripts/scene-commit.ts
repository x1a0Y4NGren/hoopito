import type {
  CameraPlacement,
  GlassSurface,
  StoryFrame,
} from './scene-contract';

interface SceneCommit {
  frame: StoryFrame;
  placement: CameraPlacement;
  surfaces: readonly GlassSurface[];
  viewport: { width: number; height: number; dpr: number };
}

/** Ignore identical DOM commits, never later changes within the same frame. */
export function createSceneCommitGuard() {
  let previousScene: object | undefined;
  let previousKey: string | undefined;
  return (scene: object, state: SceneCommit): boolean => {
    // Store a value snapshot, not mutable DOM rectangles. No rounding: even a
    // subpixel optical/ROI change must reach the renderer before paint.
    const key = JSON.stringify(state);
    if (scene === previousScene && key === previousKey) return false;
    previousScene = scene;
    previousKey = key;
    return true;
  };
}
