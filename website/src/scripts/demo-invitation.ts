import { gsap } from 'gsap';
import { createArrowDrawing } from './arrow-drawing';

type CueKind = 'court' | 'presets' | 'record';
type InvitationOptions = {
  projectCourtHint?: () => { x: number; y: number } | null;
};

/** Presentation only: visibility arms each hint without selecting or scoring. */
export function createDemoInvitation(
  courtHost: HTMLElement,
  presetGroup: HTMLElement,
  record: HTMLButtonElement,
  options: InvitationOptions = {},
) {
  const svgNamespace = 'http://www.w3.org/2000/svg';
  const targets: Record<CueKind, HTMLElement> = {
    court: courtHost,
    presets: presetGroup,
    record,
  };
  const cues = (Object.keys(targets) as CueKind[]).map((kind) => {
    const target = targets[kind];
    // Mobile lays out .demo-controls with display:contents, so it has no
    // containing box. Keep the preset layer local to the actual grid instead.
    const container = kind === 'record' ? target.parentElement! : target;
    container.classList.add('demo-invitation-container');
    target.dataset.demoInvitation = 'idle';
    const layer = document.createElement('span');
    layer.className = 'demo-invitation-layer';
    layer.dataset.cueKind = kind;
    layer.dataset.invitationState = 'idle';
    layer.setAttribute('aria-hidden', 'true');
    const light = document.createElement('span');
    light.className = 'demo-invitation-light';
    const shade = document.createElement('span');
    shade.className = 'demo-invitation-shade';
    const arrow = document.createElementNS(svgNamespace, 'svg');
    arrow.classList.add('demo-invitation-arrow');
    arrow.setAttribute('viewBox', '0 0 88 66');
    arrow.setAttribute('focusable', 'false');
    const shaft = document.createElementNS(svgNamespace, 'path');
    shaft.dataset.arrowShaft = '';
    shaft.setAttribute('d', 'M72 9C45 0 24 14 22 46');
    const head = document.createElementNS(svgNamespace, 'path');
    head.dataset.arrowHead = '';
    head.dataset.arrowSize = '10';
    arrow.append(shaft, head);
    layer.append(light, shade, arrow);
    container.append(layer);
    const draw = createArrowDrawing(shaft, head);
    draw(0);
    return { kind, target, container, layer, light, shade, arrow, draw };
  });

  let invited = false;
  let selectedOnce = false;
  let dismissed = false;
  let paused = false;
  let active: CueKind | undefined;
  let animation: gsap.core.Timeline | undefined;
  const pending = new Set<CueKind>();
  const visible = new Set<CueKind>();

  function alignActiveLayer() {
    if (!active) return;
    const cue = cues.find((candidate) => candidate.kind === active)!;
    // Finish all geometry reads before writing. Projection uses browser client
    // coordinates, so the hint stays on the same floor point as the camera moves.
    const rect = cue.target.getBoundingClientRect();
    const parent =
      cue.container === cue.target
        ? rect
        : cue.container.getBoundingClientRect();
    const borderLeft = cue.container.clientLeft;
    const borderTop = cue.container.clientTop;
    const projected =
      cue.kind === 'court' ? options.projectCourtHint?.() : null;
    const left = rect.left - parent.left - borderLeft;
    const top = rect.top - parent.top - borderTop;
    const localX = projected
      ? projected.x - parent.left - borderLeft - left
      : rect.width * 0.5;
    const localY = projected
      ? projected.y - parent.top - borderTop - top
      : rect.height * 0.65;
    const placement = {
      left: `${left}px`,
      top: `${top}px`,
      width: `${rect.width}px`,
      height: `${rect.height}px`,
    };
    for (const [property, value] of Object.entries(placement))
      if (cue.layer.style.getPropertyValue(property) !== value)
        cue.layer.style.setProperty(property, value);
    if (cue.kind === 'court') {
      const floorPlacement = {
        '--court-hint-x': `${localX}px`,
        '--court-hint-y': `${localY}px`,
        '--court-arrow-width': `${Math.max(72, Math.min(105, rect.width * 0.16))}px`,
      };
      for (const [property, value] of Object.entries(floorPlacement))
        if (cue.layer.style.getPropertyValue(property) !== value)
          cue.layer.style.setProperty(property, value);
    }
  }

  function restoreLayers() {
    cues.forEach((cue) => {
      cue.layer.dataset.invitationState =
        cue.target.dataset.demoInvitation === 'done' ? 'done' : 'idle';
      gsap.set(cue.layer, { autoAlpha: 0, display: 'none' });
      gsap.set([cue.light, cue.shade, cue.arrow], { opacity: 0 });
      gsap.set(cue.arrow, { clearProps: 'transform' });
      cue.draw(0);
    });
  }

  function stop() {
    observer.disconnect();
    pending.clear();
    visible.clear();
    animation?.kill();
    animation = undefined;
    active = undefined;
    cues.forEach((cue) => {
      if (cue.target.dataset.demoInvitation !== 'idle')
        cue.target.dataset.demoInvitation = 'done';
    });
    restoreLayers();
  }

  function runNext() {
    if (dismissed || paused || active) return;
    const cue = cues.find(
      (candidate) => pending.has(candidate.kind) && visible.has(candidate.kind),
    );
    if (!cue) return;
    pending.delete(cue.kind);
    observer.unobserve(cue.target);
    active = cue.kind;
    cue.target.dataset.demoInvitation = 'playing';
    restoreLayers();
    alignActiveLayer();
    cue.layer.dataset.invitationState = 'playing';
    gsap.set(cue.layer, { autoAlpha: 1, display: 'block' });
    const reveal = { progress: 0 };
    animation = gsap.timeline({
      onComplete: () => {
        cue.target.dataset.demoInvitation = 'done';
        animation = undefined;
        active = undefined;
        restoreLayers();
        runNext();
      },
    });
    animation
      .to(cue.light, { opacity: 1, duration: 0.28, ease: 'power2.out' }, 0)
      .fromTo(
        cue.arrow,
        { opacity: 0, x: 3, y: -3 },
        { opacity: 1, x: 0, y: 0, duration: 0.28, ease: 'power2.out' },
        0.08,
      )
      .to(
        reveal,
        {
          progress: 1,
          duration: 0.56,
          ease: 'sine.inOut',
          onUpdate: () => cue.draw(reveal.progress),
        },
        0.12,
      )
      .to(
        cue.arrow,
        { y: 4, duration: 0.2, repeat: 1, yoyo: true, ease: 'sine.inOut' },
        0.74,
      )
      .to(cue.arrow, { opacity: 0, duration: 0.26, ease: 'power2.inOut' }, 1.22)
      .to(cue.light, { opacity: 0, duration: 0.38, ease: 'power2.inOut' }, 1.3);
  }

  const observer = new IntersectionObserver(
    (entries) => {
      entries.forEach((entry) => {
        const cue = cues.find(
          (candidate) => candidate.target === entry.target,
        )!;
        if (entry.isIntersecting && entry.intersectionRatio >= 0.55)
          visible.add(cue.kind);
        else visible.delete(cue.kind);
      });
      runNext();
    },
    { threshold: 0.55, rootMargin: '-76px 0px 0px' },
  );
  const resizeObserver = new ResizeObserver(() => {
    if (active) alignActiveLayer();
  });
  cues.forEach((cue) => resizeObserver.observe(cue.target));

  function arm(kind: CueKind) {
    pending.add(kind);
    targets[kind].dataset.demoInvitation = 'armed';
    observer.observe(targets[kind]);
  }

  return {
    refresh() {
      if (active) alignActiveLayer();
    },
    invite(reduced: boolean) {
      if (invited || dismissed) return;
      invited = true;
      if (reduced) {
        targets.court.dataset.demoInvitation = 'done';
        targets.presets.dataset.demoInvitation = 'done';
        return;
      }
      arm('court');
      arm('presets');
    },
    selected(reduced: boolean) {
      if (selectedOnce || dismissed) return;
      selectedOnce = true;
      invited = true;
      stop();
      if (reduced) {
        record.dataset.demoInvitation = 'done';
        return;
      }
      arm('record');
    },
    cancel() {
      dismissed = true;
      stop();
      resizeObserver.disconnect();
    },
    pause() {
      paused = true;
      animation?.pause();
    },
    resume() {
      paused = false;
      if (animation) animation.resume();
      else runNext();
    },
  };
}
