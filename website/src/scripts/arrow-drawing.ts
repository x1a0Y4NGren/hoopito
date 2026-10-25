/** Draw the shaft and head from the same arc-length sample, including during reveal. */
export function createArrowDrawing(path: SVGPathElement, head: SVGPathElement) {
  const length = path.getTotalLength();
  const size = Number(head.dataset.arrowSize ?? 16);
  path.style.strokeDasharray = `${length} ${length}`;
  return (progress: number) => {
    const distance = Math.max(0, Math.min(1, progress)) * length;
    const tip = path.getPointAtLength(distance);
    const before = path.getPointAtLength(Math.max(0, distance - 0.5));
    const after = path.getPointAtLength(Math.min(length, distance + 0.5));
    const angle = Math.atan2(after.y - before.y, after.x - before.x);
    const dx = Math.cos(angle),
      dy = Math.sin(angle);
    const ax = tip.x - dx * size,
      ay = tip.y - dy * size;
    const wing = size * 0.5;
    head.setAttribute(
      'd',
      `M${ax - dy * wing} ${ay + dx * wing}L${tip.x} ${tip.y}L${ax + dy * wing} ${ay - dx * wing}`,
    );
    head.style.opacity = `${Math.min(1, progress * 8)}`;
    path.style.strokeDashoffset = `${length - distance}`;
  };
}
