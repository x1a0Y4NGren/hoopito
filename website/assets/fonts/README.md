# Website poster heading font

Chinese chapter headings use the static **Noto Sans SC Black 900** source in
this directory. Body copy continues to use the existing Regular 400 source at
`../../../assets/fonts/NotoSansSC-Regular.otf`; the app font is unchanged.
English headings use the existing Barlow Condensed Bold 700.

`sources.json` pins the original Black file to Noto CJK commit
`f8d157532fbfaeda587e826d4cd5b21a49186f7c`, including its download URL, original
byte count and SHA-256. `OFL-NotoSansSC.txt` is the unmodified SIL Open Font
License 1.1 from that same commit. The Black source is 8,855,916 bytes with
SHA-256 `ccb496022356b7dd14d117538a472ae40feff8f6e8f3fe8bffc5616785d2f3f9`.

The website asset pipeline calls `scripts/poster-font.mjs` to build
`public/fonts/noto-poster-black.woff2`. It includes only the characters in these
Chinese content fields: `hero.lines`, `scoring.title`, `demo.title`,
`replay.title`, `download.title`, `community.title` and `faqTitle`. These are
the only fields intended to use the `NotoPoster` CSS family. The subset retains
the original Black outlines, advances, copyright and license name records;
Regular is not relabelled as a heavier weight.

Run `npm run assets` from `website/` after changing title text. The helper rejects
missing glyphs, a variable or non-900 source, and a subset at or above 35 KiB
gzip. The complete asset manifest records the requested characters, content
fields, source and generator hashes. If source-bound scene captures are stale,
refresh them using the website README's asset workflow before preparing all
assets.

`node --test tests/font-subset.test.ts tests/font-assets.test.ts` verifies the
source weights, title coverage, original outlines, retained attribution and
generated font provenance. The source subset tests can run before regenerating
the full asset manifest; generated asset checks require the latest assets.
