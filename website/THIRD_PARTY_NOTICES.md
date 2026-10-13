# Website third-party notices

This website's original source and generated illustrations use the repository's
MIT license. Third-party libraries and fonts retain their own terms. This file
applies to `website/`; it does not change the Flutter app's dependency notices.

## Browser and static-site dependencies

| Dependency | Version | License | Local notice |
| --- | --- | --- | --- |
| Astro | 7.3.8 | MIT | [License](public/licenses/astro.txt) |
| Three.js | 0.186.1 | MIT | [License](public/licenses/three.txt) |
| GSAP / ScrollTrigger | 3.15.0 | Standard “No Charge” GSAP License | [Identification](public/licenses/GSAP.txt) |

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

| Tool | Version | License | Local notice |
| --- | --- | --- | --- |
| TypeScript | 6.0.3 | Apache-2.0 | [License](public/licenses/typescript.txt) |
| sharp | 0.35.5 | Apache-2.0 | [License](public/licenses/sharp.txt) |
| qrcode | 1.5.4 | MIT | [License](public/licenses/qrcode.txt) |
| subset-font | 2.5.0 | BSD-3-Clause | [License](public/licenses/subset-font.txt) |

Font conversion and shaping use subset-font's fontverter and harfbuzzjs
dependencies, retaining their upstream licenses in the installed build tools.
The lockfile records the complete dependency graph. These build tools are not
served as website scripts.

## Repository images and provenance

The approved C “one-eyed basketball creature” mark is resized from
`assets/icons/hoopito-app-icon-foreground.png`. Its geometry, expression, seams,
opaque black detail and alpha transparency are preserved; its approval record is
`docs/design/brand/source.json`.

The eight bilingual screenshots are losslessly encoded from the originals under
`fastlane/metadata/android/`. They retain all original pixels, dimensions and
system bars. Their synthetic match/player data and signed Release capture
provenance come from `docs/release/v2.0.1-screenshots.json`. They were captured
directly from the published v2.0.1 APK built from
`4ecd960e5af1f6b12124a43e330d67efb628281b`. Historical v2.0.0 Debug captures retain
their original provenance in `docs/release/v2.0.0-screenshots.json`; they are not
relabeled as current release images.

[ASSET_SOURCES.json](ASSET_SOURCES.json) records original and optimized SHA-256
values, image dimensions, font subset sources, QR payload, transformations and
license links. All deployed assets are local files loaded from the same origin.
