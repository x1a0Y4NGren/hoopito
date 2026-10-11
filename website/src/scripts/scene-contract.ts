export type CourtPoint = { x: number; y: number };

export interface CourtScene {
  /** Normalized progress across hero, scoring, demo, replay and download. */
  setJourney(progress: number): void;
  selectPoint(point: CourtPoint | null): void;
  /** Restore a recorded location without replaying a decorative flight. */
  setMadePoint(point: CourtPoint | null): void;
  /** One decorative flight; the DOM demo owns scoring and completion. */
  shoot(point: CourtPoint): void;
  reset(): void;
  /** System accessibility preference changes animation, never the scene or renderer. */
  setMotionEnabled(enabled: boolean): void;
  setPaused(paused: boolean): void;
  dispose(): void;
}

export interface CourtSceneOptions {
  signal: AbortSignal;
  motionEnabled: boolean;
  onPoint(point: CourtPoint): void;
  onFailure(reason: 'context-lost' | 'performance' | 'initialization'): void;
  onQualityChange?(quality: 'high' | 'low'): void;
}
