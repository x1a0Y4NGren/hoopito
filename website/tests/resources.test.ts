import assert from 'node:assert/strict';
import { test } from 'node:test';
import { selectImageResource } from '../scripts/responsive-images.mjs';

test('picture budgets respect pointer capability and reject unknown media', () => {
  const image = { src: '/phone.webp' };
  const sources = [
    {
      media: '(min-width: 1024px) and (pointer: fine)',
      srcset: '/desktop.webp',
    },
  ];
  assert.equal(
    selectImageResource(image, sources, {
      width: 1440,
      dpr: 1,
      pointer: 'coarse',
    }),
    '/phone.webp',
  );
  assert.equal(
    selectImageResource(image, sources, {
      width: 1440,
      dpr: 1,
      pointer: 'fine',
    }),
    '/desktop.webp',
  );
  assert.throws(
    () => selectImageResource(image, sources, { width: 1440, dpr: 1 }),
    /Missing pointer/,
  );
  assert.throws(
    () =>
      selectImageResource(
        image,
        [
          {
            media: '(min-width: 1024px) and (hover: hover)',
            srcset: '/desktop.webp',
          },
        ],
        { width: 1440, dpr: 1 },
      ),
    /Unsupported budget media/,
  );
});

test('mobile budget follows picture media and density without charging a desktop poster', () => {
  const image = { src: '/desktop.webp', sizes: '100vw' };
  const sources = [
    {
      media: '(min-width: 1024px)',
      srcset: '/desktop-960.avif 960w, /desktop-1600.avif 1600w',
      type: 'image/avif',
    },
    {
      srcset: '/phone-480.avif 480w, /phone-768.avif 768w',
      type: 'image/avif',
    },
  ];
  assert.equal(
    selectImageResource(image, sources, { width: 390, dpr: 1 }),
    '/phone-480.avif',
  );
  assert.equal(
    selectImageResource(image, sources, { width: 390, dpr: 2 }),
    '/phone-768.avif',
  );
  assert.equal(
    selectImageResource(image, sources, { width: 1440, dpr: 1 }),
    '/desktop-1600.avif',
  );
});

test('budget selects the display width of a transparent ball layer and includes WebP fallback', () => {
  const image = {
    src: '/ball-480.webp',
    srcset: '/ball-480.webp 480w, /ball-900.webp 900w',
    sizes: '(min-width: 1024px) 48vw, 72vw',
  };
  assert.equal(
    selectImageResource(image, [], { width: 390, dpr: 1 }),
    '/ball-480.webp',
  );
  assert.equal(
    selectImageResource(image, [], { width: 390, dpr: 2 }),
    '/ball-900.webp',
  );
  assert.equal(
    selectImageResource(
      image,
      [{ type: 'image/avif', srcset: '/ball.avif 900w' }],
      { width: 390, dpr: 1, avif: false },
    ),
    '/ball-480.webp',
  );
});

test('single-candidate desktop posters count as resources instead of falling back to a data image', () => {
  assert.equal(
    selectImageResource(
      { src: 'data:image/svg+xml,empty' },
      [{ media: '(min-width: 1024px)', srcset: '/scene-poster.webp' }],
      { width: 1440, dpr: 1 },
    ),
    '/scene-poster.webp',
  );
});
