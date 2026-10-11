import type { CourtPoint } from './scene-contract.ts';

export type DemoState = {
  phase: 'ready' | 'shooting' | 'scored';
  point: CourtPoint | null;
  blue: number;
  red: number;
  hasLocation: boolean;
  generation: number;
};
export type DemoAction =
  | { type: 'select'; point: CourtPoint }
  | { type: 'record' }
  | { type: 'complete'; generation: number }
  | { type: 'reset' };

export function initialDemoState(generation = 0): DemoState {
  return {
    phase: 'ready',
    point: null,
    blue: 6,
    red: 6,
    hasLocation: false,
    generation,
  };
}

export function reduceDemo(state: DemoState, action: DemoAction): DemoState {
  if (action.type === 'reset') return initialDemoState(state.generation + 1);
  if (action.type === 'select' && state.phase === 'ready') {
    const { x, y } = action.point;
    if (
      !Number.isFinite(x) ||
      !Number.isFinite(y) ||
      x < 0 ||
      x > 1 ||
      y < 0 ||
      y > 1
    )
      return state;
    return { ...state, point: { x, y } };
  }
  if (action.type === 'record' && state.point && state.phase === 'ready') {
    return {
      ...state,
      phase: 'shooting',
      blue: 8,
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
