import { gsap } from 'gsap';
import { createArrowDrawing } from './arrow-drawing';

export type DemoCueKind = 'court' | 'score' | 'record';
type Point = { x: number; y: number };
export type DemoCue = {
  kind: DemoCueKind;
  text: string;
  target: HTMLElement;
  point?: Point;
};

type InvitationState = {
  round: number;
  eligible: boolean;
  reduced: boolean;
};
type Bounds = Pick<DOMRectReadOnly, 'left' | 'right' | 'top' | 'bottom'>;
type Curve = [Point, Point, Point, Point];
type Placement = { label: Bounds; curve: Curve; useStatus?: true };

const kinds: readonly DemoCueKind[] = ['court', 'score', 'record'];
const svgNamespace = 'http://www.w3.org/2000/svg';
const visibilityThreshold = 0.55;
const arrowGap = 5;
const arrowDuration = 0.42;
const stageFade = 0.12;

function createItem(layer: HTMLElement, kind: DemoCueKind) {
  const element = document.createElement('div');
  element.className = 'demo-guide-cue';
  element.dataset.demoCue = kind;
  element.hidden = true;
  const svg = document.createElementNS(svgNamespace, 'svg');
  svg.setAttribute('class', 'demo-guide-arrow');
  const shaft = document.createElementNS(svgNamespace, 'path');
  shaft.setAttribute('data-demo-arrow', '');
  const head = document.createElementNS(svgNamespace, 'path');
  head.setAttribute('data-demo-arrow-head', '');
  head.dataset.arrowSize = '8';
  svg.append(shaft, head);
  const label = document.createElement('span');
  label.className = 'demo-guide-label';
  element.append(svg, label);
  layer.append(element);
  return {
    element,
    label,
    shaft,
    head,
    key: '',
    progress: 1,
    draw: undefined as ReturnType<typeof createArrowDrawing> | undefined,
    animation: undefined as gsap.core.Tween | undefined,
  };
}

type Item = ReturnType<typeof createItem>;

function intersection(a: Bounds, b: Bounds): Bounds {
  return {
    left: Math.max(a.left, b.left),
    right: Math.min(a.right, b.right),
    top: Math.max(a.top, b.top),
    bottom: Math.min(a.bottom, b.bottom),
  };
}

function inset(bounds: Bounds, pixels: number): Bounds {
  return {
    left: bounds.left + pixels,
    right: bounds.right - pixels,
    top: bounds.top + pixels,
    bottom: bounds.bottom - pixels,
  };
}

function area(bounds: Bounds) {
  return (
    Math.max(0, bounds.right - bounds.left) *
    Math.max(0, bounds.bottom - bounds.top)
  );
}

function center(bounds: Bounds): Point {
  return {
    x: (bounds.left + bounds.right) / 2,
    y: (bounds.top + bounds.bottom) / 2,
  };
}

function contains(bounds: Bounds, point: Point) {
  return (
    point.x >= bounds.left &&
    point.x <= bounds.right &&
    point.y >= bounds.top &&
    point.y <= bounds.bottom
  );
}

function viewportBelow(header?: HTMLElement): Bounds {
  const viewport = window.visualViewport;
  const left = viewport?.offsetLeft ?? 0;
  const top = viewport?.offsetTop ?? 0;
  return {
    left,
    right: left + (viewport?.width ?? document.documentElement.clientWidth),
    top: Math.max(top, header?.getBoundingClientRect().bottom ?? top),
    bottom: top + (viewport?.height ?? window.innerHeight),
  };
}

function targetReceives(target: HTMLElement, point: Point) {
  return target.contains(document.elementFromPoint(point.x, point.y));
}

function targetBounds(cue: DemoCue, viewport: Bounds) {
  const { target } = cue;
  if (!target.isConnected || target.closest('[inert], [hidden], :disabled'))
    return null;
  const bounds = target.getBoundingClientRect();
  const visible = intersection(bounds, viewport);
  if (!area(bounds) || area(visible) < area(bounds) * visibilityThreshold)
    return null;
  const point = cue.point ?? center(visible);
  return contains(visible, point) && targetReceives(target, point)
    ? bounds
    : null;
}

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function facingEdge(bounds: Bounds, point: Point, gap: number): Point {
  const midpoint = center(bounds);
  const dx = point.x - midpoint.x;
  const dy = point.y - midpoint.y;
  if (
    Math.abs(dx / (bounds.right - bounds.left)) >
    Math.abs(dy / (bounds.bottom - bounds.top))
  ) {
    return {
      x: dx > 0 ? bounds.right + gap : bounds.left - gap,
      y: clamp(point.y, bounds.top + 7, bounds.bottom - 7),
    };
  }
  return {
    x: clamp(point.x, bounds.left + 7, bounds.right - 7),
    y: dy > 0 ? bounds.bottom + gap : bounds.top - gap,
  };
}

function bendArrow(start: Point, end: Point): Curve {
  const dx = end.x - start.x;
  const dy = end.y - start.y;
  return [
    start,
    { x: start.x + dx * 0.32 - dy * 0.18, y: start.y + dy * 0.32 + dx * 0.18 },
    { x: start.x + dx * 0.74 - dy * 0.09, y: start.y + dy * 0.74 + dx * 0.09 },
    end,
  ];
}

function arrowClears(curve: Curve, safe: Bounds, obstacles: readonly Bounds[]) {
  const [start, first, second, end] = curve;
  for (let index = 0; index <= 12; index++) {
    const t = index / 12;
    const u = 1 - t;
    const point = {
      x:
        u ** 3 * start.x +
        3 * u ** 2 * t * first.x +
        3 * u * t ** 2 * second.x +
        t ** 3 * end.x,
      y:
        u ** 3 * start.y +
        3 * u ** 2 * t * first.y +
        3 * u * t ** 2 * second.y +
        t ** 3 * end.y,
    };
    if (
      !contains(safe, point) ||
      obstacles.some((bounds) => contains(bounds, point))
    )
      return false;
  }
  return true;
}

function placeCue(
  cue: DemoCue,
  target: Bounds,
  label: DOMRectReadOnly,
  safe: Bounds,
  court: Bounds,
  obstacles: readonly Bounds[],
  compact: boolean,
): Placement | undefined {
  const point = cue.point ?? center(target);
  const halfWidth = label.width / 2;
  const halfHeight = label.height / 2;
  const limit = compact ? 110 : 290;
  if (
    label.width > safe.right - safe.left ||
    label.height > safe.bottom - safe.top
  )
    return;

  const left = (cue.point ? point.x : target.left) - halfWidth;
  const right = (cue.point ? point.x : target.right) + halfWidth;
  const top = (cue.point ? point.y : target.top) - halfHeight;
  const bottom = (cue.point ? point.y : target.bottom) + halfHeight;
  const preferred =
    cue.kind === 'court'
      ? {
          x: compact ? point.x + 60 : court.right + 18 + halfWidth,
          y: point.y - (compact ? 35 : 65),
        }
      : { x: point.x, y: top - 32 };

  const candidates = [preferred];
  for (const gap of [23, 37, 54, 72]) {
    for (const x of [
      point.x,
      target.left + halfWidth,
      target.right - halfWidth,
      point.x - 64,
      point.x + 64,
    ]) {
      candidates.push({ x, y: top - gap }, { x, y: bottom + gap });
    }
    for (const y of [point.y, point.y - 27, point.y + 27]) {
      candidates.push({ x: left - gap, y }, { x: right + gap, y });
    }
  }

  let best: Placement | undefined;
  let lowestCost = Infinity;
  for (const candidate of candidates) {
    const x = clamp(candidate.x, safe.left + halfWidth, safe.right - halfWidth);
    const y = clamp(
      candidate.y,
      safe.top + halfHeight,
      safe.bottom - halfHeight,
    );
    const rect = {
      left: x - halfWidth,
      right: x + halfWidth,
      top: y - halfHeight,
      bottom: y + halfHeight,
    };
    if (obstacles.some((bounds) => area(intersection(rect, bounds)) > 0))
      continue;
    const tip = cue.point ?? facingEdge(target, { x, y }, arrowGap);
    const start = facingEdge(rect, tip, arrowGap);
    const length = Math.hypot(tip.x - start.x, tip.y - start.y);
    if (contains(inset(rect, -8), tip) || length < 12 || length > limit)
      continue;

    const courtOverlap = area(intersection(rect, court)) / area(rect);
    const cost =
      length * 0.28 +
      Math.hypot(x - preferred.x, y - preferred.y) +
      courtOverlap * (compact ? 12 : 55);
    if (lowestCost <= cost) continue;

    const curve = bendArrow(start, tip);
    if (!arrowClears(curve, safe, obstacles)) continue;
    if (
      !cue.point &&
      !targetReceives(cue.target, facingEdge(target, { x, y }, -7))
    )
      continue;
    best = { label: rect, curve };
    lowestCost = cost;
  }
  return best;
}

function placeRecordByStatus(
  cue: DemoCue,
  target: Bounds,
  statusLines: readonly Bounds[],
  safe: Bounds,
  obstacles: readonly Bounds[],
): Placement | undefined {
  // In a narrow toolbar the live instruction can serve as the caption.
  for (const label of statusLines) {
    const y = center(label).y;
    const starts = [
      { x: label.right + 6, y },
      { x: label.left - 6, y },
      { x: center(label).x, y: label.top - 5 },
    ];
    for (const start of starts) {
      const x = clamp(start.x, target.left + 8, target.right - 8);
      const tip = { x, y: target.bottom + arrowGap };
      const distance = Math.hypot(tip.x - start.x, tip.y - start.y);
      if (distance < 12 || distance > 90 || start.y <= tip.y) continue;
      const curve = bendArrow(start, tip);
      if (
        arrowClears(curve, safe, obstacles) &&
        targetReceives(cue.target, { x, y: target.bottom - 7 })
      ) {
        return { label, curve, useStatus: true };
      }
    }
  }
}

function positionItem(item: Item, placement: Placement, layerBounds: Bounds) {
  const coord = (value: number) => Math.round(value * 10) / 10;
  const left = `${coord(placement.label.left - layerBounds.left)}px`;
  const top = `${coord(placement.label.top - layerBounds.top)}px`;
  if (item.label.style.left !== left) item.label.style.left = left;
  if (item.label.style.top !== top) item.label.style.top = top;
  if (item.element.hasAttribute('data-status-anchor') !== !!placement.useStatus)
    item.element.toggleAttribute('data-status-anchor', placement.useStatus);
  const [start, ...points] = placement.curve.map(
    ({ x, y }) =>
      `${coord(x - layerBounds.left)} ${coord(y - layerBounds.top)}`,
  );
  const path = `M${start}C${points.join(' ')}`;
  if (item.shaft.getAttribute('d') === path) return;
  item.shaft.setAttribute('d', path);
  item.draw = createArrowDrawing(item.shaft, item.head);
  item.draw(item.progress);
}

function drawItem(item: Item, animate: boolean, delay: number) {
  item.animation?.kill();
  item.element.style.removeProperty('opacity');
  item.element.hidden = false;
  if (!animate) {
    item.progress = 1;
    item.draw?.(1);
    item.label.style.removeProperty('opacity');
    item.element.dataset.cueState = 'steady';
    return;
  }
  item.progress = 0;
  item.draw?.(0);
  item.label.style.opacity = '0';
  item.element.dataset.cueState = 'drawing';
  const progress = { value: 0 };
  item.animation = gsap.to(progress, {
    value: 1,
    duration: arrowDuration,
    delay,
    ease: 'power2.out',
    onUpdate: () => {
      item.progress = progress.value;
      item.draw?.(item.progress);
      item.label.style.opacity = String(Math.min(1, item.progress * 3.5));
    },
    onComplete: () => {
      item.progress = 1;
      item.draw?.(1);
      item.element.dataset.cueState = 'steady';
      item.label.style.removeProperty('opacity');
      item.animation = undefined;
    },
  });
}

function hideItem(item: Item, fade: boolean, onHidden: () => void) {
  if (item.element.hidden || (fade && !item.key)) return;
  item.animation?.kill();
  item.animation = undefined;
  item.key = '';
  delete item.element.dataset.cueState;
  const finish = () => {
    item.element.hidden = true;
    item.animation = undefined;
    onHidden();
  };
  if (fade) {
    item.animation = gsap.to(item.element, {
      opacity: 0,
      duration: stageFade,
      ease: 'power1.out',
      onComplete: finish,
    });
  } else {
    finish();
  }
}

export function createDemoInvitation(
  layer: HTMLElement,
  { header }: { header?: HTMLElement } = {},
) {
  const items = Object.fromEntries(
    kinds.map((kind) => [kind, createItem(layer, kind)]),
  ) as Record<DemoCueKind, Item>;
  const allItems = kinds.map((kind) => items[kind]);
  const layout = layer.parentElement;
  const court = layout?.querySelector<HTMLElement>('[data-demo-court-host]');
  const solids = [
    ...(layout?.querySelectorAll(
      '.experience-heading h2, .experience-heading .section-body, .demo-scoreboard, .demo-controls button, [data-demo-art="hoop"]',
    ) ?? []),
  ];
  const status = layout?.querySelector('.demo-status');
  const finePrint = layout?.querySelector('.demo-controls .fine-print');
  const range = document.createRange();
  const played = new Set<string>();
  let observed = new Set<HTMLElement>();
  let cues: readonly DemoCue[] = [];
  let state: InvitationState = { round: -1, eligible: false, reduced: false };
  let frame = 0;
  let disposed = false;

  function setLayerHidden() {
    const hidden = allItems.every(({ element }) => element.hidden);
    if (layer.hidden !== hidden) layer.hidden = hidden;
  }

  function render() {
    frame = 0;
    if (!state.eligible || !cues.length || disposed) return;

    for (const { kind, text } of cues) {
      const { label } = items[kind];
      if (label.textContent !== text) label.textContent = text;
    }
    const viewport = viewportBelow(header);
    const layerBounds = layer.getBoundingClientRect();
    const safe = inset(intersection(viewport, layerBounds), 6);
    const host = court?.getBoundingClientRect();
    const courtWidth = host ? Math.min(host.width, (host.height * 15) / 14) : 0;
    const courtBounds = host
      ? {
          left: center(host).x - courtWidth / 2,
          right: center(host).x + courtWidth / 2,
          top: host.top,
          bottom: host.bottom,
        }
      : { left: 0, right: 0, top: 0, bottom: 0 };
    const compact = viewport.right - viewport.left < 730;
    const obstacles = solids
      .map((element) => element.getBoundingClientRect())
      .filter((bounds) => area(bounds) > 0)
      .map((bounds) => inset(bounds, -3));
    layout
      ?.querySelectorAll(
        '[data-demo-selection]:not([hidden]), [data-demo-marker]:not([hidden]), [data-demo-free-throw-point]:not([hidden])',
      )
      .forEach((element) =>
        obstacles.push(inset(element.getBoundingClientRect(), -5)),
      );
    const statusLines = status ? textLines(status) : [];
    const noteLines = finePrint ? textLines(finePrint) : [];
    for (const bounds of [...statusLines, ...noteLines]) {
      obstacles.push(inset(bounds, -3));
    }

    const placements = new Map<DemoCueKind, Placement>();
    if (area(safe)) {
      for (const cue of cues) {
        const target = targetBounds(cue, viewport);
        if (!target) continue;
        const label = items[cue.kind].label.getBoundingClientRect();
        const placement =
          placeCue(cue, target, label, safe, courtBounds, obstacles, compact) ??
          (cue.kind === 'record'
            ? placeRecordByStatus(cue, target, statusLines, safe, obstacles)
            : undefined);
        if (!placement) continue;
        placements.set(cue.kind, placement);
        obstacles.push(inset(placement.label, -6));
      }
    }

    let animated = 0;
    for (const cue of cues) {
      const placement = placements.get(cue.kind);
      const item = items[cue.kind];
      if (!placement) {
        hideItem(item, false, setLayerHidden);
        continue;
      }
      positionItem(item, placement, layerBounds);
      const key = `${cue.kind}:${cue.text}`;
      if (
        item.key === key &&
        (!state.reduced || item.element.dataset.cueState === 'steady')
      )
        continue;
      item.key = key;
      const animate = !state.reduced && !played.has(key);
      played.add(key);
      drawItem(item, animate, animate ? stageFade * animated++ : 0);
    }
    setLayerHidden();
  }

  function refresh() {
    if (state.eligible && cues.length && !frame && !disposed)
      frame = requestAnimationFrame(render);
  }

  function textLines(element: Element) {
    range.selectNodeContents(element);
    return [...range.getClientRects()].filter((bounds) => area(bounds) > 0);
  }

  const resize = new ResizeObserver(refresh);
  const fixed = new Set([
    layer,
    ...solids,
    ...allItems.map(({ label }) => label),
  ]);
  for (const element of [header, court, status, finePrint])
    if (element) fixed.add(element);
  for (const element of fixed) resize.observe(element);
  const viewport = window.visualViewport;
  viewport?.addEventListener('scroll', refresh);
  viewport?.addEventListener('resize', refresh);

  return {
    update(nextCues: readonly DemoCue[], nextState: InvitationState) {
      if (disposed) return;
      const newRound = state.round !== nextState.round;
      state = nextState;
      cues = nextCues;
      if (newRound || !state.eligible) {
        cancelAnimationFrame(frame);
        frame = 0;
        for (const item of allItems) hideItem(item, false, setLayerHidden);
        if (newRound) played.clear();
      } else {
        for (const kind of kinds) {
          if (!cues.some((cue) => cue.kind === kind))
            hideItem(items[kind], !state.reduced, setLayerHidden);
        }
      }
      const targets = new Set(
        cues.map(({ target }) => target).filter((target) => !fixed.has(target)),
      );
      for (const target of observed)
        if (!targets.has(target)) resize.unobserve(target);
      for (const target of targets)
        if (!observed.has(target)) resize.observe(target);
      observed = targets;
      refresh();
    },
    dispose() {
      if (disposed) return;
      disposed = true;
      cancelAnimationFrame(frame);
      resize.disconnect();
      viewport?.removeEventListener('scroll', refresh);
      viewport?.removeEventListener('resize', refresh);
      for (const item of allItems) {
        item.animation?.kill();
        item.element.remove();
      }
      layer.hidden = true;
    },
  };
}
