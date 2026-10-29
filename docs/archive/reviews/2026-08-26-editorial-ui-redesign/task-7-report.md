# Task 7 final-review fix wave

Date: 2026-08-27
Branch: `codex/editorial-final-review-fixes`
Base: `673877d7cd45e0710bef94e38c2ae18a25d487a0`

## Scope and implementation

- Repaired the Home Golden pipeline by loading the repository's real Golden fonts in `task14_visual_accessibility_test.dart` while continuing to build the unchanged production `buildHoopTraceTheme`. Extended the production raster/font gate with a rendered CJK assertion, complementing its existing real Latin, Material icon, and Ahem-rejection checks. Regenerated exactly the four requested Home masters.
- Removed the scoring page's unconditional 450 ms periodic pulse/ticker. The active location now has a steady emphasized outline with a one-shot reveal (180 ms standard, 120 ms reduced motion, immediate final state when animations are disabled). A supplement-only one-shot countdown timer schedules the next displayed-second boundary or expiry, preserves the 10-second window, and leaves no periodic timer running while idle.
- Restored compatible score-first `addScore -> confirmPendingLocation(point)` behavior. `confirmPendingLocation` remains callable with its established positional point argument and now accepts an optional expected event ID. Explicit stale requests are rejected only when that captured identity differs from the current pending/supplement event; the existing UI `attachSupplementLocation` path is unchanged.
- Added a compact-height More-sheet treatment. At a 731x411-equivalent viewport with system top/bottom padding, the 48 dp close control moves into the sheet title and the first action in the next section remains discoverable with at least 48 dp visible. Touch targets remain at least 48 dp.
- Did not add duplicate court-first draft UI. The existing draft prompt is state-derived and persists with `courtFirstShotDraft`, and top-level Undo remains available.

## TDD evidence

### RED

- Home Golden: after wiring the real font loader into the Home test, `golden home_en_light_compact` differed from the old Ahem/tofu master by 35.05% (115,368 pixels), proving the masters did not contain the production glyph rendering.
- Compatibility: the restored score-first contract test failed because the shot location remained empty when `confirmPendingLocation(point)` returned with no pending interaction.
- Stale identity: the deterministic test capturing an old event ID failed with `NoSuchMethodError` because the controller accepted only the legacy one-argument shape and had no explicit identity channel.
- Idle motion: the timer-zone regression observed one periodic timer on an idle scoring page instead of zero.
- Steady affordance/reduced motion: the keyed steady reveal widget did not exist under the old pulsing implementation; the 120 ms and zero-duration assertions failed.
- Supplement expiry: the new one-shot countdown/expiry regression failed against the old periodic-pulse implementation before the countdown mechanism was replaced.
- Compact More: with a 731x411-equivalent viewport and 24 dp top/bottom system padding, only 39 dp of the first action was visible (required: at least 48 dp).

### GREEN

- Home/font focused tests: 11 passed.
- Controller compatibility and stale tests: 68 passed.
- Exact deterministic stale regression: 20 independent repeated invocations passed.
- Scoring page and motion tests: 110 passed.
- Full Flutter suite: 930 passed, 0 failed, 0 skipped.

## Verification

- `flutter test test/app/task14_visual_accessibility_test.dart test/app/editorial_golden_font_pipeline_test.dart --reporter expanded`: 11 passed.
- `flutter test test/features/scoring/scoring_controller_test.dart test/features/scoring/task8_scoring_controller_test.dart --reporter expanded`: 68 passed.
- The exact stale projection test was invoked independently 20 times: `STALE_REPEATS_PASSED=20`.
- `flutter test test/features/scoring/scoring_page_test.dart test/features/scoring/scoring_motion_test.dart --reporter expanded`: 110 passed.
- `dart format --output=none --set-exit-if-changed .`: 224 files checked, 0 changed.
- `flutter analyze`: no issues found.
- `flutter test --machine`: 930 passed, 0 failed, 0 skipped, exit 0.
- `git diff --check`: clean after the final report and scope review.

## Golden regeneration and visual inspection

Exactly these four masters were regenerated and reopened at original detail:

- `test/app/goldens/home_en_light_compact.png`
- `test/app/goldens/home_zh_light_compact.png`
- `test/app/goldens/home_en_dark_large.png`
- `test/app/goldens/home_zh_dark_large.png`

All four show readable production Latin/CJK glyphs and recognizable Material icons, with no Ahem blocks or tofu. Light compact variants show the full Home hierarchy. Dark large variants correctly show the hero and the beginning of the scrollable directory within the taller text-scale layout; text and icons remain intact.

## Deferred Minor findings and remaining concerns

- Deferred the duplicated-semantics notes in `history_page.dart:644` and `home_page.dart:112`. The wrappers currently merge labels with interactive/text descendants. Removing or excluding descendants without targeted semantics-tree coverage could erase child actions or labels, so this is not a clearly safe fix for the single final-review wave.
- No remaining Important finding is known. The only remaining concern is the deferred semantics cleanup above, which should be handled with dedicated semantics-tree tests.
