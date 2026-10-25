# HoopTrace Unified Scoring and Route Fix Implementation Plan

> Historical unified-scoring plan, not a current assignment. Execution instructions and checkboxes below describe that task only; see [history scope](../README.md).

**Goal:** Replace the split simple/detailed scoring experience with one clean scoring surface, add court-first and ten-second score-first shot-location capture with action-level undo, and eliminate every terminal-match navigation dead end.

**Architecture:** Keep the persisted recording-mode and tracking-coverage fields as backward-compatible metadata, but stop using them as capability gates. Model unfinished court-first capture and the latest score-first supplement window explicitly in the scoring controller, while all durable scoring, location, and undo changes remain transactional commands with audit receipts. Canonical final replay navigation uses `GoRouter.go` and an explicit exit contract so terminal scoring pages can never remain underneath it.

**Tech Stack:** Flutter, Riverpod, go_router, Drift/SQLite, flutter_test.

**Spec:** The user-approved plan in the Codex task that requested this file on 2026-08-25.

## Global Constraints

- Blue stays on the left and red on the right; each primary side panel exposes only `+1`, `+2`, `+3`, and a bottom foul action.
- The primary scoring screen has no persistent bottom command dock.
- The black scoreboard always exposes Undo and More; all secondary actions live in the grouped More surface.
- The ordinary score-first location supplement window is exactly ten seconds and only the latest score may own it.
- Court-first score plus location is one undoable action; an appended location and its score are two undoable actions.
- Timer controls and match finish are excluded from the scoring undo stack.
- Final replay Back and Up go Home when no prior in-app route exists; history-pushed replay still pops to History.
- Existing database and backup fields for `RecordingMode` and `TrackingCoverage` remain readable; do not add a schema migration solely for unified scoring.
- Minimum interactive target is 48x48 logical pixels; reduced-motion mode uses static highlighting.
- Do not push, publish, or upload.

---

### Task 1: Finish/replay route lifecycle

**Files:**
- Modify: `lib/app/provider_router.dart`
- Modify: `lib/features/replay/replay_page.dart`
- Test: `test/app/task9_completion_route_test.dart`
- Test: `test/app/task6_review_regression_test.dart`

**Interfaces:**
- Produce an explicit replay exit callback used by AppBar Up and system Back.
- Capture `GoRouter` before asynchronous finish, navigate to canonical replay immediately after commit, then run backup without delaying navigation.
- Terminal scoring fallbacks expose replay/home actions.

- [ ] Add failing route tests for scoring finish, replay finish, final replay Back/Up, active replay pop, and terminal scoring escape actions.
- [ ] Run the focused route tests and record the expected failures.
- [ ] Implement the minimal route and replay exit changes.
- [ ] Run focused tests and `flutter analyze`; commit the task.

### Task 2: Transactional shot-location supplement and undo

**Files:**
- Modify: `lib/core/data/commands/match_command_service.dart`
- Modify: `lib/core/data/repositories/match_repository.dart`
- Modify: `lib/features/scoring/scoring_controller.dart`
- Test: `test/core/data/match_clock_service_test.dart`
- Test: `test/features/scoring/task8_scoring_controller_test.dart`

**Interfaces:**
- Produce `CourtFirstShotDraft`, `LocationSupplementWindow`, the controller APIs named in the approved spec, and a ten-second deadline constant.
- Extend location confirmation with a request timestamp and allow an unconfirmed location row to be confirmed again.
- Produce atomic `UndoLastScoringActionCommand` selection using durable audit chronology; filter unconfirmed or deleted-event locations from projections and statistics.

- [ ] Add failing command/controller tests for court-first capture, score-first capture, 9.999/10.000-second boundary, newest-score ownership, rebuild recovery, and both undo granularities.
- [ ] Run focused tests and record expected failures.
- [ ] Implement minimal command, projection, and controller behavior.
- [ ] Run focused tests and `flutter analyze`; commit the task.

### Task 3: Remove pregame mode and coverage choices

**Files:**
- Modify: `lib/features/pregame/pregame_page.dart`
- Modify: `lib/features/pregame/pregame_controller.dart`
- Modify: `lib/features/pregame/start_match_mapper.dart`
- Modify: localization ARB/generated sources only as required by the repository workflow.
- Test: relevant pregame controller/widget and mapper tests.

**Interfaces:**
- New matches receive internal backward-compatible recording metadata without user input.
- Existing persisted and backup enum values remain unchanged and readable.
- Recording metadata no longer gates scoring controller capabilities.

- [ ] Add failing tests proving pregame starts without mode/coverage input and the controls are absent.
- [ ] Run focused tests and record expected failures.
- [ ] Remove the controls and validation while preserving compatibility defaults.
- [ ] Run focused tests and `flutter analyze`; commit the task.

### Task 4: Unified scoring UI and grouped More surface

**Files:**
- Modify: `lib/features/scoring/scoring_page.dart`
- Modify focused widgets under `lib/features/scoring/widgets/`.
- Modify localization resources through the project localization workflow.
- Test: `test/features/scoring/scoring_page_test.dart`
- Test: `test/features/scoring/court_view_test.dart`

**Interfaces:**
- Consume Task 2 controller states and methods verbatim.
- Scoreboard exposes 48dp Undo and More actions.
- More groups missed shots, free throws, possession, timer, note/custom, replay, and match finish.

- [ ] Add failing widget tests for the clean primary layout, gray draft, direct supplement, countdown/highlight, reduced motion, More groups, and text-dialog lifecycle.
- [ ] Run focused tests and record expected failures.
- [ ] Implement the unified three-column UI without a persistent bottom dock.
- [ ] Run responsive widget tests at 731x411, 1095x616, 1920x1080, large text, and reduced motion; commit the task.

### Task 5: Integration, accessibility, and release verification

**Files:**
- Modify only tests or implementation defects revealed by integration review.
- Test: route, scoring, integration, and accessibility suites.

**Interfaces:**
- End-to-end flow: create match, score-first locate, undo location, undo score, court-first score, foul, missed shot through More, finish, final replay, Back to Home.

- [ ] Add the missing end-to-end regression before any integration fix and observe it fail.
- [ ] Implement only defects exposed by the regression.
- [ ] Run formatting check, `flutter analyze`, all focused suites, DB-backed tests in a supported environment, Android integration tests, and Debug APK build/install.
- [ ] Perform final whole-branch review, resolve findings, and commit the verification/fix wave.
