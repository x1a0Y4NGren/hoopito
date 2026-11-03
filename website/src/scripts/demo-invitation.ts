import { gsap } from 'gsap';

type CueKind = 'court' | 'record';
type InvitationOptions = {
  projectCourtHint?: () => { x: number; y: number } | null;
  isReading?: () => boolean;
  canShowHint?: () => boolean;
};

/** Local, one-shot light only; never selects a point or records a basket. */
export function createDemoInvitation(
  courtHost: HTMLElement,
  presetGroup: HTMLElement,
  record: HTMLButtonElement,
  options: InvitationOptions = {},
) {
  const targets = { court: courtHost, record };
  // Kept as an argument for existing callers; presets now use ordinary states.
  presetGroup.removeAttribute('data-demo-invitation');
  const cues = (['court', 'record'] as const).map((kind) => {
    const target = targets[kind];
    target.classList.add('demo-invitation-container');
    target.dataset.demoInvitation = 'idle';
    const layer = document.createElement('span');
    layer.className = 'demo-invitation-layer';
    layer.dataset.cueKind = kind;
    layer.dataset.invitationState = 'idle';
    layer.setAttribute('aria-hidden', 'true');
    const light = document.createElement('span');
    light.className = 'demo-invitation-light';
    layer.append(light);
    target.append(layer);
    return { kind, target, layer, light };
  });
  let invited = false;
  let selectedOnce = false;
  let dismissed = false;
  let paused = false;
  let active: CueKind | undefined;
  let animation: gsap.core.Timeline | undefined;
  const pending = new Set<CueKind>();

  function restoreLayers() {
    for (const cue of cues) {
      cue.layer.dataset.invitationState =
        cue.target.dataset.demoInvitation === 'done' ? 'done' : 'idle';
      gsap.set(cue.layer, { autoAlpha: 0, display: 'none' });
      gsap.set(cue.light, { opacity: 0 });
    }
  }
  function stopActive() {
    animation?.kill();
    animation = undefined;
    if (active) targets[active].dataset.demoInvitation = 'done';
    active = undefined;
    restoreLayers();
  }
  function visible(target: HTMLElement) {
    const rect = target.getBoundingClientRect();
    const header =
      document.querySelector('.site-header')?.getBoundingClientRect().bottom ??
      0;
    const width = Math.max(
      0,
      Math.min(innerWidth, rect.right) - Math.max(0, rect.left),
    );
    const height = Math.max(
      0,
      Math.min(innerHeight, rect.bottom) - Math.max(header, rect.top),
    );
    return (
      rect.width > 0 &&
      rect.height > 0 &&
      width * height >= rect.width * rect.height * 0.55
    );
  }
  function alignActiveLayer() {
    if (active !== 'court') return;
    const cue = cues[0];
    const rect = courtHost.getBoundingClientRect();
    const projected = options.projectCourtHint?.();
    cue.layer.style.setProperty(
      '--court-hint-x',
      `${projected ? projected.x - rect.left - courtHost.clientLeft : rect.width * 0.5}px`,
    );
    cue.layer.style.setProperty(
      '--court-hint-y',
      `${projected ? projected.y - rect.top - courtHost.clientTop : rect.height * 0.65}px`,
    );
  }
  function runNext() {
    if (
      dismissed ||
      paused ||
      active ||
      options.isReading?.() === false ||
      options.canShowHint?.() === false
    )
      return;
    const cue = cues.find(
      (c) =>
        pending.has(c.kind) &&
        visible(c.target) &&
        !(c.target instanceof HTMLButtonElement && c.target.disabled),
    );
    if (!cue) return;
    pending.delete(cue.kind);
    active = cue.kind;
    cue.target.dataset.demoInvitation = 'playing';
    cue.layer.dataset.invitationState = 'playing';
    alignActiveLayer();
    gsap.set(cue.layer, { autoAlpha: 1, display: 'block' });
    animation = gsap.timeline({
      onComplete() {
        cue.target.dataset.demoInvitation = 'done';
        animation = undefined;
        active = undefined;
        restoreLayers();
      },
    });
    animation
      .to(cue.light, { opacity: 1, duration: 0.2, ease: 'sine.out' }, 0)
      .to(cue.light, { opacity: 0, duration: 0.4, ease: 'sine.inOut' }, 0.4);
  }
  const observer = new IntersectionObserver(() => runNext(), {
    threshold: [0, 0.55, 1],
  });
  const resizeObserver = new ResizeObserver(() => {
    alignActiveLayer();
    runNext();
  });
  for (const cue of cues) {
    observer.observe(cue.target);
    resizeObserver.observe(cue.target);
  }
  function arm(kind: CueKind) {
    pending.add(kind);
    targets[kind].dataset.demoInvitation = 'armed';
    runNext();
  }
  return {
    refresh() {
      if (
        options.isReading?.() === false ||
        (!paused && options.canShowHint?.() === false)
      ) {
        if (active) stopActive();
        return;
      }
      alignActiveLayer();
      runNext();
    },
    invite(reduced: boolean) {
      if (invited || dismissed) return;
      invited = true;
      if (reduced) {
        courtHost.dataset.demoInvitation = 'done';
        return;
      }
      arm('court');
    },
    selected(reduced: boolean) {
      if (selectedOnce || dismissed) return;
      selectedOnce = true;
      invited = true;
      pending.delete('court');
      stopActive();
      courtHost.dataset.demoInvitation = 'done';
      if (reduced) {
        record.dataset.demoInvitation = 'done';
        return;
      }
      arm('record');
    },
    cancel() {
      dismissed = true;
      pending.clear();
      stopActive();
      for (const cue of cues) cue.target.dataset.demoInvitation = 'done';
      observer.disconnect();
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
