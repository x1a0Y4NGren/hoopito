export type ViewState = { zoom: number; x: number; y: number };
export type ViewSize = {
  width: number;
  height: number;
  imageWidth: number;
  imageHeight: number;
};
const clamp = (value: number, min: number, max: number) =>
  Math.min(max, Math.max(min, value));

export function constrainView(view: ViewState, size: ViewSize): ViewState {
  const zoom = clamp(view.zoom, 1, 4);
  const x = Math.max(0, (size.imageWidth * zoom - size.width) / 2);
  const y = Math.max(0, (size.imageHeight * zoom - size.height) / 2);
  return {
    zoom,
    x: x ? clamp(view.x, -x, x) : 0,
    y: y ? clamp(view.y, -y, y) : 0,
  };
}

export function zoomView(
  view: ViewState,
  zoom: number,
  anchor: { x: number; y: number },
  size: ViewSize,
): ViewState {
  const next = clamp(zoom, 1, 4);
  const ratio = next / view.zoom;
  return constrainView(
    {
      zoom: next,
      x: anchor.x - (anchor.x - view.x) * ratio,
      y: anchor.y - (anchor.y - view.y) * ratio,
    },
    size,
  );
}

export class ScoringFocus {
  private manual: number | undefined;
  private active = false;
  get isManual() {
    return this.manual !== undefined;
  }
  choose(index: number) {
    this.manual = index;
    return index;
  }
  resume() {
    this.manual = undefined;
  }
  update(progress: number, active: boolean): number | null {
    if (this.active && !active) this.manual = undefined;
    this.active = active;
    if (!active) return null;
    if (this.manual !== undefined) return this.manual;
    // Open with a useful explanation and keep the final operation visible
    // through the reading pause; no unexplained blank state at either end.
    return progress < 0.38 ? 0 : progress < 0.68 ? 1 : 2;
  }
}
