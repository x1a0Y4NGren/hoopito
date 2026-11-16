import type { CourtPoint } from './scene-contract.ts';
import {
  containsCourtPoint,
  FREE_THROW_POINT,
  isOutsideArc,
  type CourtScoringRegion,
} from './court-geometry.ts';

export type DemoPoints = 1 | 2 | 3;

export type DemoState = {
  phase: 'ready' | 'shooting' | 'scored';
  point: CourtPoint | null;
  points: DemoPoints | null;
  freeThrowEligible: boolean;
  blue: number;
  red: number;
  hasLocation: boolean;
  generation: number;
};
export type DemoAction =
  | { type: 'select'; point: CourtPoint; freeThrowEligible?: boolean }
  | { type: 'selectScore'; points: DemoPoints }
  | { type: 'record' }
  | { type: 'complete'; generation: number }
  | { type: 'reset' };

export function initialDemoState(generation = 0): DemoState {
  return {
    phase: 'ready',
    point: null,
    points: null,
    freeThrowEligible: false,
    blue: 6,
    red: 6,
    hasLocation: false,
    generation,
  };
}

export function allowedDemoPoints(state: DemoState): readonly DemoPoints[] {
  if (state.phase !== 'ready') return [];
  if (!state.point) return [1, 2, 3];
  if (!containsCourtPoint(state.point)) return [];
  if (isOutsideArc(state.point)) return [3];
  return state.freeThrowEligible ? [1, 2] : [2];
}

export function demoRegion(state: DemoState): CourtScoringRegion | null {
  switch (state.points) {
    case 1:
      return 'freeThrowLine';
    case 2:
      return 'insideArc';
    case 3:
      return 'outsideArc';
    default:
      return null;
  }
}

export function demoPresets(
  points: DemoPoints | null,
): Record<'left' | 'center' | 'right', CourtPoint> {
  if (points === 1) {
    return {
      left: { ...FREE_THROW_POINT },
      center: { ...FREE_THROW_POINT },
      right: { ...FREE_THROW_POINT },
    };
  }
  if (points === 3) {
    return {
      left: { x: 0.18, y: 0.8 },
      center: { x: 0.5, y: 0.8 },
      right: { x: 0.82, y: 0.8 },
    };
  }
  return {
    left: { x: 0.25, y: 0.45 },
    center: { x: 0.5, y: 0.45 },
    right: { x: 0.75, y: 0.45 },
  };
}

function matchesFieldGoal(points: DemoPoints, point: CourtPoint): boolean {
  return (
    containsCourtPoint(point) &&
    ((points === 2 && !isOutsideArc(point)) ||
      (points === 3 && isOutsideArc(point)))
  );
}

function canRecord(state: DemoState): boolean {
  if (!state.point || state.points === null) return false;
  if (state.points === 1) {
    return (
      state.freeThrowEligible &&
      state.point.x === FREE_THROW_POINT.x &&
      state.point.y === FREE_THROW_POINT.y
    );
  }
  return matchesFieldGoal(state.points, state.point);
}

export function reduceDemo(state: DemoState, action: DemoAction): DemoState {
  if (action.type === 'reset') return initialDemoState(state.generation + 1);
  if (action.type === 'select' && state.phase === 'ready') {
    if (
      state.points === 1 ||
      !containsCourtPoint(action.point) ||
      (state.points !== null && !matchesFieldGoal(state.points, action.point))
    )
      return state;
    return {
      ...state,
      point: { ...action.point },
      freeThrowEligible:
        action.freeThrowEligible === true && !isOutsideArc(action.point),
    };
  }
  if (
    action.type === 'selectScore' &&
    allowedDemoPoints(state).includes(action.points)
  ) {
    return action.points === 1
      ? {
          ...state,
          points: 1,
          point: { ...FREE_THROW_POINT },
          freeThrowEligible: true,
        }
      : { ...state, points: action.points };
  }
  if (
    action.type === 'record' &&
    state.phase === 'ready' &&
    state.points !== null &&
    canRecord(state)
  ) {
    return {
      ...state,
      phase: 'shooting',
      blue: 6 + state.points,
      generation: state.generation + 1,
    };
  }
  if (
    action.type === 'complete' &&
    state.phase === 'shooting' &&
    action.generation === state.generation
  ) {
    return { ...state, phase: 'scored', hasLocation: true };
  }
  return state;
}
