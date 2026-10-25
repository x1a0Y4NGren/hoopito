# Hoopito Icon Assets

Hoopito uses the approved **C · one-eyed basketball creature**: an asymmetric
orange ball, one large eye, a mischievous grin, and two simple basketball seams.
The user approved it as the official logo on 2026-10-04 and requested complete
retirement of the old hoop-and-shot-trace identity. Its source was prepared with
OpenAI's built-in ImageGen, preserving the approved concept while removing its
background. No third-party artwork is included.

## Source and palette

The original transparent ImageGen result and exact prompt are preserved in
[the brand record](../../docs/design/brand/README.md). The normalized project
foreground retains the generated alpha and maps visible pixels to three colors:

- Arena orange: `#FF5A1F`
- Near-black pupil, grin, and basketball seams: `#101112`
- Warm-white eye and glint: `#F4F3EF`

The launcher background is also `#101112`. Black facial details retain their ink
in the transparent source. Never reduce the foreground to an orange/white palette.

## File roles and derivation

- `hoopito-app-icon-foreground.png`: transparent 1024 × 1024 production source;
  the complete creature is centered within a 620 × 620 safe zone.
- `hoopito-app-icon.png`: opaque 1024 × 1024 master on the near-black background.
- `hoopito-app-icon-monochrome.png`: transparent single-color master; black
  pupil, grin, and seams become negative spaces, keeping the face recognizable
  when Android applies a themed color.
- Android legacy mipmaps and iOS AppIcon PNGs are opaque resizes of the master.
  Android adaptive foregrounds use the transparent source; monochrome resources
  use the single-color master with antialiased alpha edges.
- Both Fastlane locales use the same 512 × 512 opaque store icon.
- Native Android `launch_mark.png` and iOS LaunchImage use the new foreground
  at 0.78 scale, matching the first Flutter entry frame. Flutter uses the same
  foreground through its bounce and final hold; it no longer draws the old hoop.

The current entry motion uses a 48×48 texture mesh for squash, stretch and a
decaying upper-body wave. Its endpoints render the original image directly.
Startup is silent and has no haptic feedback; scoring feedback preferences are
separate. See the [entry motion record](../../docs/design/brand/entry-motion.md).

Regenerate with Python and Pillow (validated with Python 3.12 and Pillow 12.3):

```sh
python tool/release/generate_launcher_icons.py \
  --import-imagegen-source docs/design/brand/hooptrace-c-imagegen-source.png \
  --contact-sheet build/logo/cyclops-contact-sheet.png
python tool/release/generate_entry_assets.py
python -m unittest discover -s tool/release/tests -v
```

The launcher script validates all platform dimensions, transparency, the three
foreground colors, monochrome details, adaptive XML, and both store icons. It
does not add a Flutter dependency. The entry script also reproduces the existing
legacy swish sound, which the current entry no longer loads or plays; it does not
synthesize replacement artwork.

All source artwork, derivatives, and scripts use the repository MIT License.
