import { gsap } from 'gsap';
import { createArrowDrawing } from './arrow-drawing';

/** Click-only presentation cues. The release screenshot and its data stay intact. */
export function createScoringFeedback(
  device: HTMLElement,
  note: HTMLElement,
  features: HTMLButtonElement[],
) {
  const regions = [
    ...device.querySelectorAll<SVGGElement>('[data-score-region]'),
  ];
  const actions = [
    ...device.querySelectorAll<SVGGElement>('[data-score-action]'),
  ];
  let animation: gsap.core.Timeline | undefined;
  let paused = false;
  let invitation: gsap.core.Timeline | undefined;
  let invited = false;
  const first = features[0];
  const display = device.closest<HTMLElement>('.scoring-display')!;
  const indicator = first.querySelector('.feature-indicator');
  const inviteArrow = first.querySelector<SVGSVGElement>(
    '[data-score-invite-arrow]',
  )!;
  const drawInvitation = createArrowDrawing(
    inviteArrow.querySelector<SVGPathElement>('[data-arrow-shaft]')!,
    inviteArrow.querySelector<SVGPathElement>('[data-arrow-head]')!,
  );
  const dimmedFeatures = features.slice(1);

  function cancelInvitation() {
    invitation?.kill();
    invitation = undefined;
    first.dataset.scoreInvitation = invited ? 'done' : 'idle';
    gsap.set(display, { clearProps: 'filter' });
    gsap.set(dimmedFeatures, { clearProps: 'opacity' });
    gsap.set(first, { clearProps: '--score-invite' });
    gsap.set(indicator, { clearProps: 'transform' });
    gsap.set(inviteArrow, { opacity: 0, clearProps: 'transform' });
    drawInvitation(0);
  }

  function cancel() {
    animation?.kill();
    animation = undefined;
    device.dataset.scorePlaying = 'false';
    gsap.set(
      device.querySelectorAll(
        '.score-shade, .score-region-trace, [data-score-action]',
      ),
      { opacity: 0 },
    );
    gsap.set(note, { clearProps: 'transform,opacity' });
    cancelInvitation();
  }

  return {
    invite(reduced: boolean) {
      if (invited) return;
      invited = true;
      if (reduced) {
        cancelInvitation();
        return;
      }
      first.dataset.scoreInvitation = 'playing';
      invitation = gsap.timeline({ paused, onComplete: cancelInvitation });
      const reveal = { progress: 0 };
      invitation
        // Keep the screenshot opaque so the arena cannot show through its UI.
        .fromTo(
          display,
          { filter: 'brightness(1)' },
          {
            filter: 'brightness(0.36)',
            duration: 0.24,
            ease: 'power2.out',
          },
          0,
        )
        .to(
          dimmedFeatures,
          { opacity: 0.36, duration: 0.24, ease: 'power2.out' },
          0,
        )
        .fromTo(
          first,
          { '--score-invite': 0 },
          { '--score-invite': 1, duration: 0.3, ease: 'power2.out' },
          0,
        )
        .fromTo(
          inviteArrow,
          { opacity: 0, x: 5, y: -5 },
          { opacity: 1, x: 0, y: 0, duration: 0.3, ease: 'power2.out' },
          0.08,
        )
        .to(
          reveal,
          {
            progress: 1,
            duration: 0.48,
            ease: 'power2.inOut',
            onUpdate: () => drawInvitation(reveal.progress),
          },
          0.12,
        )
        .to(
          inviteArrow,
          { y: 4, duration: 0.18, repeat: 1, yoyo: true, ease: 'sine.inOut' },
          0.64,
        )
        .to(
          inviteArrow,
          { opacity: 0, y: -3, duration: 0.3, ease: 'power2.inOut' },
          1.12,
        )
        .fromTo(
          indicator,
          { scale: 1 },
          {
            scale: 1.8,
            duration: 0.35,
            repeat: 1,
            yoyo: true,
            ease: 'sine.inOut',
          },
          0.18,
        )
        .to(
          display,
          { filter: 'brightness(1)', duration: 0.45, ease: 'power2.inOut' },
          1,
        )
        .to(
          dimmedFeatures,
          { opacity: 1, duration: 0.45, ease: 'power2.inOut' },
          1,
        )
        .to(
          first,
          { '--score-invite': 0, duration: 0.45, ease: 'power2.inOut' },
          1,
        );
    },
    play(index: number, reduced: boolean) {
      // A direct interaction consumes the invitation, including a keyboard
      // selection made before the first button reaches the observer threshold.
      invited = true;
      cancel();
      if (reduced) return;
      const region = regions[index];
      const action = actions[index];
      const cursor = action.querySelector<SVGGElement>('[data-score-cursor]')!;
      const rings = [
        ...action.querySelectorAll<SVGCircleElement>('[data-score-pulse]'),
      ];
      const path = action.querySelector<SVGPathElement>(
        '.score-operation-path',
      );
      const head = action.querySelector<SVGPathElement>(
        '.score-operation-head',
      );
      const drawArrow =
        path && head ? createArrowDrawing(path, head) : undefined;
      drawArrow?.(0);
      gsap.set(cursor, { opacity: 0 });
      device.dataset.scorePlaying = 'true';
      animation = gsap.timeline({
        paused,
        defaults: { ease: 'power2.out' },
        onComplete: cancel,
      });
      animation
        .set(action, { opacity: 1 }, 0)
        .fromTo(
          region.querySelector('.score-shade'),
          { opacity: 0 },
          { opacity: 0.58, duration: 0.18 },
          0,
        )
        .fromTo(
          region.querySelectorAll('.score-region-trace'),
          { opacity: 1, strokeDasharray: 1, strokeDashoffset: 1 },
          { strokeDashoffset: 0, duration: 0.55, ease: 'power2.inOut' },
          0,
        )
        .fromTo(
          note,
          { opacity: 0.55, y: 5 },
          { opacity: 1, y: 0, duration: 0.3 },
          0,
        );
      rings.forEach((ring, order) => {
        const x = Number(ring.getAttribute('cx'));
        const y = Number(ring.getAttribute('cy'));
        const start = (index === 0 ? 0.12 : 1.08) + order * 0.58;
        // Keep the ring's center in screenshot coordinates; radius animation
        // avoids SVG transform-origin drift at different display sizes.
        animation!
          .fromTo(
            cursor,
            {
              opacity: 0,
              attr: { transform: `translate(${x + 65} ${y + 75})` },
            },
            {
              opacity: 1,
              attr: { transform: `translate(${x} ${y})` },
              duration: 0.26,
              immediateRender: false,
            },
            start,
          )
          .fromTo(
            ring,
            { opacity: 1, attr: { r: 22 } },
            {
              opacity: 0,
              attr: { r: 112 },
              duration: index === 0 ? 0.76 : 0.42,
              immediateRender: false,
            },
            start + 0.22,
          )
          .to(cursor, { opacity: 0, duration: 0.18 }, start + 0.48);
      });
      if (drawArrow) {
        const reveal = { progress: 0 };
        animation
          .set(path, { opacity: 1 }, 0.1)
          .to(
            reveal,
            {
              progress: 1,
              duration: 0.58,
              ease: 'sine.inOut',
              onUpdate: () => drawArrow(reveal.progress),
            },
            0.1,
          )
          .to([path, head], { opacity: 0, duration: 0.2 }, 0.94);
      }
      animation.to(
        [
          region.querySelector('.score-shade'),
          ...region.querySelectorAll('.score-region-trace'),
          action,
        ],
        { opacity: 0, duration: 0.26 },
        1.68,
      );
    },
    cancel,
    pause() {
      paused = true;
      animation?.pause();
      invitation?.pause();
    },
    resume() {
      paused = false;
      animation?.resume();
      invitation?.resume();
    },
  };
}
