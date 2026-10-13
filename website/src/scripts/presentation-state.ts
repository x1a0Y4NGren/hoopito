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
