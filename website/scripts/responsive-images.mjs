export function selectImageResource(image, sources, viewport) {
  const matches = (media) => {
    if (!media) return true;
    return media
      .split(/\s+and\s+/)
      .map((condition) => {
        const width = condition
          .trim()
          .match(/^\((min|max)-width:\s*(\d+)px\)$/);
        if (width)
          return width[1] === 'min'
            ? viewport.width >= Number(width[2])
            : viewport.width <= Number(width[2]);
        const pointer = condition
          .trim()
          .match(/^\(pointer:\s*(fine|coarse|none)\)$/);
        if (pointer) {
          if (!viewport.pointer)
            throw new Error(
              `Missing pointer capability for budget media: ${media}`,
            );
          return viewport.pointer === pointer[1];
        }
        throw new Error(`Unsupported budget media: ${media}`);
      })
      .every(Boolean);
  };
  const source =
    sources.find(
      (candidate) =>
        matches(candidate.media) &&
        (candidate.type !== 'image/avif' || viewport.avif !== false),
    ) ?? image;
  const candidates = (source.srcset ?? '')
    .split(',')
    .map((candidate) => {
      const [url, descriptor] = candidate.trim().split(/\s+/);
      return {
        url,
        width: descriptor ? Number.parseFloat(descriptor) : 1,
        unit: descriptor?.at(-1) ?? 'x',
      };
    })
    .filter((candidate) => candidate.url && candidate.width > 0);
  if (!candidates.length) return source.src ?? image.src;
  const sizes = (source.sizes ?? image.sizes ?? '100vw').split(',');
  let displayWidth = viewport.width;
  for (const rule of sizes) {
    const condition = rule.match(/\([^)]*\)/)?.[0];
    if (condition && !matches(condition)) continue;
    const length = rule
      .replace(condition ?? '', '')
      .trim()
      .match(/^(\d+(?:\.\d+)?)(vw|px)$/);
    if (!length) throw new Error(`Unsupported image size in budget: ${rule}`);
    displayWidth =
      Number(length[1]) * (length[2] === 'vw' ? viewport.width / 100 : 1);
    break;
  }
  candidates.sort((left, right) => left.width - right.width);
  const needed =
    candidates[0].unit === 'x' ? viewport.dpr : displayWidth * viewport.dpr;
  return (
    candidates.find((candidate) => candidate.width >= needed) ??
    candidates.at(-1)
  ).url;
}
