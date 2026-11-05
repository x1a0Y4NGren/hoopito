import { gsap } from 'gsap';

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
  let invitation: gsap.core.Timeline | undefined;
  let paused = false;
  let invited = false;
  const first = features[0];

  function cancelInvitation() {
    invitation?.kill();
    invitation = undefined;
    first.dataset.scoreInvitation = invited ? 'done' : 'idle';
    gsap.set(first, { clearProps: '--score-invite' });
  }

  function cancel() {
    animation?.kill();
    animation = undefined;
    device.dataset.scorePlaying = 'false';
    gsap.set(
      device.querySelectorAll(
        '.score-shade, [data-score-action], [data-score-pulse]',
      ),
      { opacity: 0 },
    );
    gsap.set(device.querySelectorAll('[data-score-pulse]'), {
      attr: { r: 18 },
    });
    gsap.set(note, { clearProps: 'transform,opacity' });
    cancelInvitation();
  }

  return {
    invite(reduced: boolean) {
      if (invited || paused) return;
      invited = true;
      if (reduced) {
        cancelInvitation();
        return;
      }
      first.dataset.scoreInvitation = 'playing';
      invitation = gsap.timeline({ onComplete: cancelInvitation });
      invitation
        .fromTo(
          first,
          { '--score-invite': 0 },
          { '--score-invite': 1, duration: 0.22, ease: 'sine.out' },
          0,
        )
        .to(
          first,
          { '--score-invite': 0, duration: 0.4, ease: 'sine.inOut' },
          0.4,
        );
    },
    play(index: number, reduced: boolean) {
      // User activation consumes the one-shot invitation, even before arrival.
      invited = true;
      cancel();
      if (reduced) return;
      const region = regions[index];
      const action = actions[index];
      const rings = [
        ...action.querySelectorAll<SVGCircleElement>('[data-score-pulse]'),
      ];
      device.dataset.scorePlaying = 'true';
      animation = gsap.timeline({
        paused,
        defaults: { ease: 'sine.out' },
        onComplete: cancel,
      });
      animation
        .set(action, { opacity: 1 }, 0)
        .fromTo(
          region.querySelector('.score-shade'),
          { opacity: 0 },
          { opacity: 0.18, duration: 0.18 },
          0,
        )
        .fromTo(note, { opacity: 0.7 }, { opacity: 1, duration: 0.18 }, 0);
      rings.forEach((ring, order) => {
        // Radius is in the original screenshot's coordinates; no SVG origin drift.
        animation!.fromTo(
          ring,
          { opacity: 1, attr: { r: 18 } },
          {
            opacity: 0,
            attr: { r: 52 },
            duration: 0.4,
            immediateRender: false,
          },
          0.24 + order * 0.62,
        );
      });
      animation.to(
        [region.querySelector('.score-shade'), action],
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
