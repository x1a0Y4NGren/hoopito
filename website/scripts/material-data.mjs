/** Linear material data, deliberately independent of generated color pixels. */
export function makeMaterialData(kind, size = 512) {
  if (
    !['maple', 'leather'].includes(kind) ||
    !Number.isInteger(size) ||
    size < 16 ||
    size > 512
  )
    throw new RangeError(
      'Material data requires maple/leather and16–512 pixels.',
    );
  const data = new Uint8Array(size * size * 3);
  const tau = Math.PI * 2;
  const hash = (x, y) => {
    const n = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
    return n - Math.floor(n);
  };
  const wrap = (n, period) => ((n % period) + period) % period;
  for (let y = 0; y < size; y++)
    for (let x = 0; x < size; x++) {
      const u = x / size,
        v = y / size,
        index = (y * size + x) * 3;
      if (kind === 'maple') {
        const board = Math.floor(u * 20);
        const phase = hash(board, 0) * tau;
        const fiber = Math.sin(
          tau * (u * 80 + 0.15 * Math.sin(v * tau * 4)) + phase,
        );
        data[index] = Math.round(128 + fiber * 11);
        data[index + 1] = Math.round(128 + Math.sin(v * tau * 8 + phase) * 3);
        data[index + 2] = Math.round(
          105 + hash(board, 1) * 24 + Math.sin(v * tau * 4 + phase) * 3,
        );
      } else {
        //64 periodic cells across a tile: height relief, not a directional photograph.
        const cells = 64,
          px = u * cells,
          py = v * cells;
        let distance = Infinity;
        for (let dy = -1; dy <= 1; dy++)
          for (let dx = -1; dx <= 1; dx++) {
            const cx = Math.floor(px) + dx,
              cy = Math.floor(py) + dy;
            const jx = 0.25 + hash(wrap(cx, cells), wrap(cy, cells)) * 0.5;
            const jy =
              0.25 + hash(wrap(cx + 137, cells), wrap(cy + 59, cells)) * 0.5;
            distance = Math.min(
              distance,
              Math.hypot(px - cx - jx, py - cy - jy),
            );
          }
        const t = Math.min(1, distance / 0.67);
        const height = Math.round(92 + (1 - t * t * (3 - 2 * t)) * 68);
        data[index] = data[index + 1] = data[index + 2] = height;
      }
    }
  return { data, width: size, height: size, channels: 3 };
}
