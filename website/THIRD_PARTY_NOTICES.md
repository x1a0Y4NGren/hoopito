# Website third-party notices

This website's original source and generated illustrations use the repository's
MIT license. Third-party libraries and fonts retain their own terms. This file
applies to `website/`; it does not change the Flutter app's dependency notices.

## Browser and static-site dependencies

| Dependency           | Version | License                           | Local notice                               |
| -------------------- | ------- | --------------------------------- | ------------------------------------------ |
| Astro                | 7.4.0   | MIT                               | [License](public/licenses/astro.txt)       |
| Three.js             | 0.186.1 | MIT                               | [License](public/licenses/three.txt)       |
| GSAP / ScrollTrigger | 3.15.0  | Standard “No Charge” GSAP License | [Identification](public/licenses/GSAP.txt) |

GSAP is not distributed under MIT. Its bundled source notice is “Copyright
2008-2026, GreenSock. All rights reserved.”; its standard license also identifies
Copyright © 2025 Webflow. The website uses it
to animate this product presentation. Its [upstream license](https://gsap.com/community/standard-license/)
governs use and redistribution; preserve upstream copyright and proprietary
notices when bundling. It restricts competing visual animation building tools.

## Fonts

- Barlow Condensed Medium, SemiBold and Bold: Copyright 2017 The Barlow Project
  Authors ([upstream](https://github.com/jpt/barlow)); [SIL Open Font License 1.1](public/fonts/OFL-Barlow.txt).
- Noto Sans SC Regular: © 2014–2021 Adobe ([upstream Noto CJK](https://github.com/notofonts/noto-cjk));
  [SIL Open Font License 1.1](public/fonts/OFL-NotoSansSC.txt). The original bundled
  font is the Simplified Chinese subset OTF from commit
  `f8d157532fbfaeda587e826d4cd5b21a49186f7c`.

Barlow is converted to WOFF2 without removing its glyph set. The Chinese font is
further subset to website text and interface symbols. Copyright and license name
records are retained. Original app fonts and their licenses remain untouched.
The share image uses outlines from Barlow and Noto Sans SC, with both font
licenses retained here.

## Asset build tools

| Tool        | Version | License      | Local notice                               |
| ----------- | ------- | ------------ | ------------------------------------------ |
| TypeScript  | 6.0.3   | Apache-2.0   | [License](public/licenses/typescript.txt)  |
| sharp       | 0.35.5  | Apache-2.0   | [License](public/licenses/sharp.txt)       |
| qrcode      | 1.5.4   | MIT          | [License](public/licenses/qrcode.txt)      |
| subset-font | 2.9.0   | BSD-3-Clause | [License](public/licenses/subset-font.txt) |

Font conversion and shaping use subset-font's fontverter and harfbuzzjs 1.6.3
dependencies, retaining their upstream licenses in the installed build tools.
The lockfile records the complete dependency graph. These build tools are not
served as website scripts.

## Repository images and provenance

The approved C “one-eyed basketball creature” mark is resized from
`assets/icons/hoopito-app-icon-foreground.png`. Its geometry, expression, seams,
opaque black detail and alpha transparency are preserved; its approval record is
`docs/design/brand/source.json`.

The eight bilingual screenshots are losslessly encoded from the originals under
`fastlane/metadata/android/`. Public presentation copies remove only calibrated system bars and system insets,
retaining the App pixels losslessly. Originals and their capture dimensions remain
unchanged; crop rectangles and output hashes are recorded in
`docs/design/screenshot-presentation.json` and `ASSET_SOURCES.json`. Their synthetic match/player data and signed Release capture
provenance come from `docs/release/v2.0.1-screenshots.json`. They were captured
directly from the published v2.0.1 APK built from
`4ecd960e5af1f6b12124a43e330d67efb628281b`. Historical v2.0.0 Debug captures retain
their original provenance in `docs/release/v2.0.0-screenshots.json`; they are not
relabeled as current release images.

[ASSET_SOURCES.json](ASSET_SOURCES.json) records original and optimized SHA-256
values, image dimensions, font subset sources, QR payload, transformations and
license links. All deployed assets are local files loaded from the same origin.

The v4 maple-floor and basketball-leather color sources were generated with the
built-in `image_gen.imagegen` tool. Original PNGs remain under
[`assets/materials/source/`](assets/materials/source/); full prompts, source
dimensions, SHA-256 values and conversion settings are recorded in
[`assets/materials/generation.json`](assets/materials/generation.json). Metal and
glass retain the earlier sources identified in that record. The historical
[`generation-v3.json`](assets/materials/generation-v3.json) and its source images
retain their original identities.

The lightweight SVG court uses independent honey-maple and transparent
backboard/rim images generated with the built-in `image_gen.imagegen` tool.
Original PNGs, the complete generation/edit prompts, source hashes, transparent
crop and measured rim registration are recorded in
[`assets/materials/demo-court-generation-v2.json`](assets/materials/demo-court-generation-v2.json).
[`scripts/prepare-demo-court.mjs`](scripts/prepare-demo-court.mjs) proportionally
encodes these local images while retaining alpha. Court lines, branding,
interaction markers and the animated nylon net remain original SVG code;
the desktop 3D material sources are unchanged. The foreshortened v1 sprite and
its generation record remain historical rejected design evidence after the
true-overhead projection correction.

The 512×512 packed floor normal-XY/roughness and leather microheight data maps are
deterministic outputs of the repository's original MIT-licensed
[`scripts/material-data.mjs`](scripts/material-data.mjs), generated independently
of the color images. They are linear material data; albedo textures use sRGB.
`ASSET_SOURCES.json` binds the generator or source image, generation record,
conversion and output hashes. Runtime lighting, reflections, court markings,
ball channels and hardware geometry are produced by the scene code.

## Continuous court and glass

The continuous court, native-scroll card poses and HDR glass shader are original
repository code under MIT, built with the Three.js postprocessing interfaces.
The camera follows a shared scroll-derived world track between static reading
poses; the same scene owns the fitted court-input projection, cached floor
lighting, prebuilt geometry levels and deterministic shot timeline. These changes
add no model engine or screen-space reflection dependency.
The glass samples only the live court after Bloom and before OutputPass; it does
not incorporate third-party shader source or DOM captures. The mobile background
and desktop placeholders are captures from the same compiled desktop court. Their
source inputs, crop rectangles, dimensions and SHA-256 values are recorded in
`assets/art/scene-poster.json` and `ASSET_SOURCES.json`.

The thin-glass revision consulted the following upstream implementations on
2026-11-01 for edge refraction, restrained highlights and keeping content sharp.
These are design and implementation references, not installed dependencies or
copied source. The local rounded-distance shader remains original repository code;
no React runtime, SVG displacement package or additional rendering context was
added.

- **Shu Ding, liquid-glass**: reference commit
  [`a2d2e847f793430e3409a52927af815a23f4d372`](https://github.com/shuding/liquid-glass/commit/a2d2e847f793430e3409a52927af815a23f4d372)
  from `main`; consulted [README](https://github.com/shuding/liquid-glass/blob/a2d2e847f793430e3409a52927af815a23f4d372/README.md)
  and [liquid-glass.js](https://github.com/shuding/liquid-glass/blob/a2d2e847f793430e3409a52927af815a23f4d372/liquid-glass.js).
  [MIT license](https://github.com/shuding/liquid-glass/blob/a2d2e847f793430e3409a52927af815a23f4d372/LICENSE),
  Copyright (c) 2025 Shu Ding.
- **Max Rovensky, liquid-glass-react**: reference commit
  [`ac48eab18d1f7f444ae30002d240cae29c863a21`](https://github.com/rdev/liquid-glass-react/commit/ac48eab18d1f7f444ae30002d240cae29c863a21)
  from `master`; consulted [README](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/README.md)
  and [src/index.tsx](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/src/index.tsx).
  [MIT license](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/LICENSE),
  Copyright 2025 MAX ROVENSKY. Its
  [package metadata](https://github.com/rdev/liquid-glass-react/blob/ac48eab18d1f7f444ae30002d240cae29c863a21/package.json)
  requires React and React DOM >=18. Its README reports partial Safari/Firefox
  support with invisible displacement; that statement describes the upstream
  implementation and is not a test result for this website.

Both upstream MIT licenses require their copyright and permission notices in
copies or substantial portions of their software. Any future source adoption
must preserve the applicable full notice and update this provenance record.
The exact reviewed Git blob identities are recorded in the
[thin-glass maintenance note](docs/thin-glass-2026-11-01.md).

## Chapter rail liquid motion references

The 2026-11-03 liquid revision replaces the earlier scroll-derived pointed outline
and hand-drawn connector with at most three SVG liquid bodies. A local Gaussian
blur and alpha threshold produce their shared contour, while the existing
approved Hoopito bitmap remains upright and outside the filter. The position
model, SVG markup and integration are original repository code using this common
rendering technique. It consulted [Liquid Orb Navigation at 44b0b1e7](https://github.com/Anima529/liquid-orb-navigation/blob/44b0b1e7691cede2d347cfa1b88b51b76919f213/index.html)
([MIT, Copyright 2026 Anima529](https://github.com/Anima529/liquid-orb-navigation/blob/44b0b1e7691cede2d347cfa1b88b51b76919f213/LICENSE))
for multi-body fusion, and [liquid-taffy goo calibration at 4bcf4005](https://github.com/arknow91/liquid-taffy/blob/4bcf4005f857c371bf53d60b2cee14abcecedf6a/src/components/liquid/goo.ts)
([MIT, Copyright 2026 arknow91](https://github.com/arknow91/liquid-taffy/blob/4bcf4005f857c371bf53d60b2cee14abcecedf6a/LICENSE))
for paired blur/alpha calibration and separating crisp content from the liquid
layer. The earlier rail also consulted [Fancy GooeySvgFilter at f9f62c61](https://github.com/danielpetho/fancy/blob/f9f62c61207b2dd3210476dd98af3c9a5be24094/src/fancy/components/filter/gooey-svg-filter.tsx)
([MIT, Copyright 2024 Daniel Petho](https://github.com/danielpetho/fancy/blob/f9f62c61207b2dd3210476dd98af3c9a5be24094/LICENSE)).
No substantial upstream source, React component, spring engine or runtime
dependency was adopted. Future substantial source
adoption must preserve the applicable full MIT notice. The fixed references,
brand presentation and verification boundaries are documented in the
[chapter rail maintenance note](docs/chapter-rail-2026-11-02.md).
