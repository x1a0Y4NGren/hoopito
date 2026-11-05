interface DemoArtOptions {
  eligible(): boolean;
}

/** Decorates the SVG only when its 2D presentation is actually needed. */
export function createDemoArt(court: SVGSVGElement, options: DemoArtOptions) {
  const images = [
    ...court.querySelectorAll<SVGImageElement>('[data-demo-art]'),
  ];
  const pending = new Set<SVGImageElement>();
  let near = false;
  let alive = true;
  function update() {
    if (!alive || !near || !options.eligible()) return;
    for (const surface of images) {
      if (pending.has(surface) || !surface.dataset.src) continue;
      pending.add(surface);
      const image = new Image();
      image.decoding = 'async';
      image.src = surface.dataset.src;
      image
        .decode()
        .then(() => {
          if (!alive) return;
          surface.setAttribute('href', image.src);
          surface.dataset.artReady = 'true';
          court.dataset[
            surface.dataset.demoArt === 'hoop' ? 'hoopReady' : 'floorReady'
          ] = 'true';
        })
        .catch(() => {
          if (alive) surface.dataset.artFailed = 'true';
        });
    }
  }
  const observer = new IntersectionObserver(
    (entries) => {
      near = entries.some((entry) => entry.isIntersecting);
      update();
    },
    { rootMargin: '200px' },
  );
  observer.observe(court);
  return {
    update,
    dispose() {
      alive = false;
      observer.disconnect();
    },
  };
}
