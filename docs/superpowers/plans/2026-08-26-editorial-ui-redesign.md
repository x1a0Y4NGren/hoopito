# HoopTrace Editorial UI Redesign Implementation Plan

> Historical editorial redesign plan, not a current assignment. Execution instructions and checkboxes below describe that task only; see [history scope](../README.md).

**Goal:** Replace HoopTrace's warm-paper/doodle interface with a unified, premium “black-court editorial desk” visual system across every screen while preserving all scoring, persistence, routing, accessibility, and localization behavior.

**Architecture:** Build and freeze a semantic editorial design system first, then migrate feature pages in isolated batches. Pages consume theme extensions and focused shared components rather than declaring feature-local colors, card shapes, or motion constants. Existing domain controllers, repositories, routes, scoring receipts, and motion queue remain the source of truth.

**Tech Stack:** Flutter, Material 3 foundations, Riverpod, go_router, ARB localization, CustomPainter, Lottie, Flutter unit/widget/golden/integration tests.

**Spec:** The user-approved “HoopTrace 黑场编辑部全界面升级实施计划” in the task conversation on 2026-08-26.

## Global Constraints

- Start from commit `81db9f4abe63a4142f64bd9048ad49139350aeb7` and work on `codex/editorial-ui-redesign`.
- Replace the old warm-paper/doodle presentation completely; do not add a legacy-theme toggle.
- Light theme canvas `#F4F3EF`, light surface `#FFFFFF`, light ink `#101112`; dark canvas `#0C0D0E`, dark surface `#151719`, dark ink `#F4F3EF`.
- Arena orange is `#FF5A1F` in light theme and `#FF6A32` in dark theme and is reserved for primary action, focus, and immediate feedback.
- Team blue/red are identity and data colors only. Never use color as the sole carrier of meaning.
- Bundle OFL-licensed Barlow Condensed weights 500, 600, and 700 for score, timer, numeric labels, and English mastheads only. Chinese and body copy use the platform system font.
- Do not use gradients, glass effects, ornamental shadows, generic Material cards, pervasive rounded cards, or pervasive pill buttons.
- Preserve all domain models, database schema, command behavior, route paths, score/undo/location semantics, activity-resume semantics, and JSON compatibility.
- Chinese remains the default locale. Every new user-visible string must exist in both `app_zh.arb` and `app_en.arb`; generated localization files are controller-owned integration files.
- Light and dark themes are intentionally designed, not mechanically inverted. Default theme mode continues to follow the system.
- Basketball court line art may appear only on home, pregame, scoring, and replay screens.
- All interactive targets are at least 48×48 dp; normal text contrast is at least 4.5:1; large text and non-text controls are at least 3:1.
- Standard motion: press 90 ms, state 180 ms, sheet 220 ms, page reveal 200–240 ms, scoring flight 480 ms and splash 180 ms. Queues over three items use 320 ms flight and 120 ms splash without dropping or reordering events.
- Reduced motion keeps only a 120 ms color reveal. `MediaQuery.disableAnimations` takes precedence and produces the final state immediately.
- There are no continuous looping, breathing, or drifting animations.
- Each task uses TDD for observable behavior changes: add a failing test, verify the expected failure, implement, and verify green. Generated files and static asset registration do not require artificial source-text tests.
- Do not merge, push, publish, or create a release. Preserve all user-owned untracked files outside the worktree.

---

### Task 1: Editorial design system, typography, and shared primitives

**Owned files:** `lib/app/app_theme.dart`, new `lib/app/design_system/**`, `lib/app/widgets/doodle_components.dart`, `pubspec.yaml`, `assets/fonts/**`, font license, theme/component tests.

**Produces:** `HoopTraceEditorialTheme`, retained/retuned `HoopTraceMotionTheme`, and shared `EditorialScaffold`, `EditorialMasthead`, `EditorialSectionRule`, `EditorialIndexRow`, `MatchScoreRow`, `ScoreNumeral`, `TeamActionRail`, `EditorialSheet`, `EditorialEmptyState`, and `EditorialErrorState` APIs.

**Requirements:** Implement exact palette and typography constraints, deterministic court-line brand painter, responsive spacing/type scales, high-contrast focus/disabled states, and static/reduced animation behavior. Keep temporary compatibility wrappers only when existing pages require them during migration; mark them internal and remove in Task 7.

**Tests:** Theme values and contrast, 48 dp component bounds, light/dark rendering, score typography fallback, reduced/disabled animation behavior, and deterministic painter output.

### Task 2: Home and pregame editorial experience

**Owned files:** `lib/features/home/**`, `lib/features/pregame/**`, their tests. Do not edit design-system, router, or generated localization files.

**Consumes:** Task 1 shared components and tokens.

**Requirements:** Home becomes a brand hub with HOOPTRACE masthead, one state-aware hero for start/continue, compact latest-result strip, and editorial directory. Pregame uses symmetrical team panels and a separate configuration rail; compact ordering is blue, red, rules/configuration. Preserve controllers, mappings, start flow, activity-resume behavior, semantics, and stable primary action.

**Tests:** No-active/active/recent-result states; wide and narrow layouts; dark/light; 200% text; semantic labels; start and continue navigation contracts.

### Task 3: Scoring shell and signature motion refinement

**Owned files:** `lib/features/scoring/**` and scoring UI/motion tests. Do not edit commands, repositories, route definitions, design-system files, or generated localization files.

**Consumes:** Task 1 `ScoreNumeral`, `TeamActionRail`, `EditorialSheet`, palette, and motion tokens.

**Requirements:** Preserve the approved blue-left/court-center/red-right skeleton, center header order back/timer/undo/more, and four equally spaced one-column actions `+1/+2/+3/foul` on each side. Narrow side rails and enlarge the court. Convert More into a grouped high-contrast action index with a separate destructive match section. Retune the receipt-driven flight/trail/splash presentation to the exact durations while preserving FIFO, hidden marker, supplement, failure, cancellation, and lifecycle semantics. Add vertical score transition, foul stamp, and eraser undo without introducing loops.

**Tests:** Existing scoring behavior remains green; exact structural layout at 731×411 and 1095×616; 48 dp controls; 200% text; motion progress 0/50/100; queue ordering and acceleration; reduced/disabled modes; no animation on command failure; cancellation on undo/rotate/route exit.

### Task 4: Replay and history editorial content pages

**Owned files:** `lib/features/replay/**`, `lib/features/history/**`, related tests. Do not edit design-system, router, or generated localization files.

**Consumes:** Task 1 page, row, sheet, state, and court-line components.

**Requirements:** Make the replay court the visual focus and express the event timeline as a play-by-play editorial rail/sheet; selected events synchronize textual and court emphasis. History is grouped by date with compact score rows, integrated search/filter hierarchy, and unified empty/error/loading states. Preserve editing, audit, filters, analytics, export, navigation, and final/active replay behavior.

**Tests:** Selection synchronization, edit/audit flows, active/final return behavior, search/filter, empty/error, light/dark, narrow/wide, 200% text, and contrast.

### Task 5: Players and rule templates

**Owned files:** `lib/features/players/**`, `lib/features/rules/**`, related tests. Do not edit design-system, router, or generated localization files.

**Consumes:** Task 1 shared page, index, row, state, form, and typography patterns.

**Requirements:** Player career pages emphasize number, core statistics, and shot distribution; list/editor pages use editorial rows and disciplined field grouping. Rule templates render as technical specification sheets with distinct system/user/enabled states. Preserve create/edit/delete constraints, validation, career analytics, and navigation.

**Tests:** CRUD and validation contracts, career statistics, template state identity beyond color, light/dark, narrow/wide, semantics, and 200% text.

### Task 6: Settings, About integration, and centralized localization

**Owned files:** `lib/features/settings/**`, `lib/features/project/**`, `lib/app/l10n/app_zh.arb`, `lib/app/l10n/app_en.arb`, generated localization files, router integration where required, related tests.

**Consumes:** All frozen design-system interfaces and page patterns.

**Requirements:** Group Settings into appearance, scoring feedback, language, data, and About; include standard/reduced motion preview. Make About the visible home for current project details while preserving the existing project route/deep link. Centralize all new bilingual strings from Tasks 2–5, regenerate localization once, and keep Chinese as the default.

**Tests:** Settings persistence, motion preview, language switching, About navigation and legacy deep link, all ARB keys generated in both locales, light/dark, semantics, and 200% text.

### Task 7: Full-app cleanup, visual regression, and Android verification

**Owned files:** cross-feature integration tests, golden tests/assets, obsolete presentation code, and only the minimal production files required to resolve integration findings.

**Consumes:** Tasks 1–6 complete branch.

**Requirements:** Remove all remaining doodle/warm-paper compatibility code and feature-local hardcoded presentation that violates the editorial system. Ensure court graphics only appear on the four approved key pages. Reconcile information density and spacing across every route without changing business behavior.

**Tests and commands:** Run `dart format --output=none --set-exit-if-changed .`, `flutter analyze`, complete `flutter test`, golden tests for home/pregame/scoring/replay in light/dark and Chinese/English, Android integration tests, and `flutter build apk --debug`. Install and launch the APK on the configured emulator/device and capture real screenshots for 390×844 portrait plus 731×411 and 1095×616 landscape acceptance.

