export type CourtPoint = { x: number; y: number };

/** The DOM result can arrive before the decorative net rebound has finished. */
export class ShotContinuation {
  private point: CourtPoint | null = null;
  private cancelAnimation: (() => void) | undefined;
  private generation = 0;

  begin(point: CourtPoint, cancelAnimation: () => void) {
    this.cancel();
    this.point = { ...point };
    this.cancelAnimation = cancelAnimation;
    return this.generation;
  }

  /** Restoring the same result preserves its remaining animation; other restores cancel it. */
  restore(point: CourtPoint | null) {
    const preserve = Boolean(
      point &&
      this.point &&
      this.cancelAnimation &&
      point.x === this.point.x &&
      point.y === this.point.y,
    );
    if (!preserve) this.cancel();
    return preserve;
  }

  isCurrent(generation: number) {
    return this.generation === generation && this.cancelAnimation !== undefined;
  }

  complete(generation: number) {
    if (!this.isCurrent(generation)) return;
    this.point = null;
    this.cancelAnimation = undefined;
  }

  cancel() {
    const cancelAnimation = this.cancelAnimation;
    this.point = null;
    this.cancelAnimation = undefined;
    this.generation += 1;
    cancelAnimation?.();
  }
}

export type StoryChapter =
  'hero' | 'scoring' | 'experience' | 'replay' | 'download';

/** The DOM and camera consume the same chapter-local, native-scroll timeline. */
export interface StoryFrame {
  chapter: StoryChapter;
  progress: number;
  active: boolean;
}

export type SceneQuality = 'full' | 'effects' | 'density';

/** Browser viewport coordinates in CSS pixels, independent of drawing-buffer density. */
export interface SceneRegion {
  left: number;
  top: number;
  width: number;
  height: number;
}

export interface CameraPlacement {
  region: SceneRegion;
  blend: number;
  inputEnabled: boolean;
}

export interface CourtScene {
  setStoryFrame(frame: StoryFrame): void;
  /** Compose the existing camera into a transparent HTML interaction region. */
  setCameraPlacement(placement: CameraPlacement | null): void;
  pointFromClient(clientX: number, clientY: number): CourtPoint | null;
  /** Project a floor location into browser viewport CSS pixels. */
  projectPoint(point: CourtPoint): { x: number; y: number } | null;
  /** Paint the current chapter at the current host size before revealing it. */
  presentFrame(): void;
  /** Render and capture the current pose before the WebGL drawing buffer is released. */
  exportFrame(): string;
  selectPoint(point: CourtPoint | null): void;
  /** Restore a recorded location, preserving any remaining rebound of that same shot. */
  setMadePoint(point: CourtPoint | null): void;
  /** Adopt the DOM shot's active elapsed seconds, preserving its remaining flight/rebound. */
  shoot(point: CourtPoint, elapsed?: number): void;
  reset(): void;
  /** System accessibility preference changes animation, never the scene or renderer. */
  setMotionEnabled(enabled: boolean): void;
  setPaused(paused: boolean): void;
  dispose(): void;
}

export interface CourtSceneOptions {
  signal: AbortSignal;
  motionEnabled: boolean;
  onFailure(reason: 'context-lost' | 'performance' | 'initialization'): void;
  onQualityChange?(quality: SceneQuality): void;
}
