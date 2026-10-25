# HoopTrace 1.1 Player Comparison Implementation Plan

> Historical 1.1 implementation plan, not release authorization or a new assignment. Execution instructions and checkboxes below describe that task only; see [history scope](../README.md).

**Goal:** Release-ready `1.1.0+3` support for comparing two matches or adjacent rolling windows for one profile-linked player, backed by persistent analytics snapshots included in backups.

**Architecture:** Schema v3 adds one derived snapshot per completed/archived match and linked player. Canonical match data remains authoritative: database triggers invalidate snapshots, repositories rebuild them in bounded batches, and backup restore validates or rebuilds derived rows. A dedicated comparison domain/repository/controller/page keeps comparison state out of the existing career aggregate.

**Tech Stack:** Flutter 3.41.9, Dart 3.11.5, Drift 2.34.0, Riverpod 3.3.2, go_router 17.5.0, SQLite, flutter_test, integration_test.

**Spec:** User-approved plan in the 2026-08-28 Codex task; this file is its execution copy.

## Global Constraints

- Remain permanently free, open source, offline-first, and without accounts, cloud sync, ads, payments, or telemetry.
- Keep Android first and continue focusing on 1v1; do not add team modes.
- Support complete Simplified Chinese and English localization, light/dark themes, compact layouts, and 200% text.
- Preserve schema v2 user data and accept v1.0 format-1/schema-2 backups; schema v1 remains blocked.
- Use profile IDs as comparison identity; temporary names never become comparison subjects.
- Do not upgrade major dependencies, publish, push, tag, submit F-Droid metadata, or release iOS.
- Do not perform unrelated refactors in MatchCommandService or ScoringPage.

---

### Task 1: Baseline Hygiene and Current Documentation

**Files:**
- Modify: `test/core/export/task13_backup_merge_test.dart`
- Modify: test files that redundantly register `close` after `createTestDatabase`
- Modify: `HANDOFF.md`, `docs/release/fdroid-notes.md`

**Deliverable:** The full test run emits no Drift multiple-database warning, database cleanup is owned once, and release/F-Droid documentation reflects the published 1.0 state.

- Reproduce the warning with the named backup merge test.
- Change the source export fixture to `withTestDatabase`, closing it before the destination is opened.
- Remove redundant explicit teardown registrations already provided by `createTestDatabase`.
- Run the focused export tests, full tests, format, and analyze.
- Update human documentation without changing release or remote state.

### Task 2: Schema v3 and Snapshot Core

**Files:**
- Modify: `lib/core/data/app_database.dart`, generated Drift output and migration schema fixtures
- Create: `lib/core/domain/analytics/player_analytics_snapshot.dart`
- Create: `lib/core/domain/analytics/player_analytics_snapshot_calculator.dart`
- Create: `lib/core/data/repositories/player_analytics_snapshot_repository.dart`
- Test: matching domain, repository, schema, trigger, migration, and performance tests

**Interfaces:**
- Produce `PlayerAnalyticsSnapshot` with match/player/opponent identity, played-at UTC, points, FG/FT totals, tracking coverage, confirmed/locatable locations, zone distribution, calculator version, and source SHA-256.
- Produce `PlayerAnalyticsSnapshotRepository.ensureSnapshots({String? playerId})` using one bounded canonical query plus batched inserts.

**Deliverable:** Schema v3 migrates v2 without eager backfill, snapshot rows are deterministic, and inserts/updates/deletes in matches, participants, events, or locations invalidate both old and new match IDs.

- Start with failing pure calculator and schema/migration/trigger tests.
- Add `player_analytics_snapshots` with composite `(matchId, playerId)` primary key, cascade semantics, and player/date plus player/opponent/date indexes.
- Add invalidation triggers and exclude snapshot writes from automatic-backup dirty triggers.
- Implement deterministic calculation and batch ensure behavior.
- Regenerate Drift code/schema only after tests define the contract.
- Verify 1,000-match cold build is below 2 seconds in the existing benchmark harness.

### Task 3: Backup Format 2 and Snapshot Portability

**Files:**
- Modify: `lib/core/export/json_backup_codec.dart`
- Modify: `lib/core/export/backup_merge_service.dart`
- Modify: backup format, codec, merge, coordinator, and automatic-backup tests

**Interfaces:**
- Extend `JsonBackupDocument` with snapshots.
- Set `JsonBackupCodec.currentFormatVersion = 2` while accepting format-1/schema-2 input.
- Extend `BackupMergeResult` with `rebuiltAnalyticsSnapshotCount`.

**Deliverable:** Format 2 exports twelve table groups, format 1/schema 2 restores with snapshot rebuild, replace keeps valid carried snapshots, and merge remaps canonical rows then rebuilds imported snapshots atomically.

- Write failing format-2 round-trip, format-1 compatibility, mismatch rebuild, remap, and rollback tests.
- Ensure snapshots before export without creating an automatic-backup dirty loop.
- Treat structurally valid but stale/unsupported derived rows as rebuildable; canonical payload or envelope checksum failures still reject atomically.
- Insert snapshots after canonical rows on replace; rebuild affected snapshots after merge ID mapping.
- Keep deterministic table/row ordering and resource-limit validation.

### Task 4: Unified Comparison Domain and Repository

**Files:**
- Create: `lib/core/domain/analytics/player_comparison.dart`
- Create: `lib/core/data/repositories/player_comparison_repository.dart`
- Test: `test/core/domain/player_comparison_test.dart`, `test/core/data/player_comparison_repository_test.dart`

**Interfaces:**
- `sealed class PlayerComparisonRequest`
- `MatchPairComparisonRequest(playerId, baselineMatchId, currentMatchId)`
- `AdjacentWindowComparisonRequest(playerId, window, asOfUtc, opponentPlayerId)`
- `enum PlayerComparisonWindow { sevenDays, thirtyDays, ninetyDays }`
- `PlayerComparisonSample`, `PlayerComparisonMetric`, `PlayerComparisonEvidence`, `PlayerComparisonReport`
- `PlayerComparisonRepository.listEligibleMatches`, `.compare`, and `.ensureSnapshots`

**Deliverable:** One profile can compare two distinct eligible matches or current/previous adjacent half-open UTC windows with exact, coverage-aware evidence.

- Write failing hand-derived tests for match pairs, fixed UTC boundaries, opponent filters, archived/deleted data, empty samples, and insufficient tracking.
- Build match options from finished/archived profile-linked matches only, sorted newest first.
- Aggregate snapshots for both request types; default semantics are baseline older/previous and current newer/current.
- Report score/result or match count/win rate, points, margin, FG, FT, trustworthy percentages, location coverage, and confirmed-zone shares.
- Evidence only says increase/decrease/equal/unavailable; percentage deltas use percentage points and never infer prescriptions or significance.
- Verify warm comparison p95 below 100ms.

### Task 5: Comparison UI, Routing, and Localization

**Files:**
- Create: `lib/features/players/player_comparison_controller.dart`, `player_comparison_page.dart`
- Modify: player career page, provider composition/router, ARB and generated localizations
- Test: controller, widget, route, localization, accessibility, and golden tests

**Interfaces:**
- Route `/players/:playerId/analytics/compare`.
- Player career page receives a comparison navigation callback.

**Deliverable:** The player career masthead opens a responsive, bilingual comparison page with match/window modes, selection, swapping, opponent filtering, loading/error/empty states, and coverage-aware metrics.

- Write failing controller and widget tests before each behavior.
- Default match mode to the latest two eligible matches, with older on the baseline side; prevent selecting the same match twice and support swap.
- Capture one `asOfUtc` per page load; window mode offers rolling 7/30/90-day comparisons and the existing profile opponent filter.
- Use baseline/delta/current columns on wide layouts and stacked sections on compact layouts.
- Cover Chinese/English, light/dark, compact/wide, and 200% text; generate and visually inspect goldens.
- Extract only the player route assembly needed to keep the large provider router from growing further.

### Task 6: End-to-End Verification and 1.1 Release Readiness

**Files:**
- Modify/create comparison integration test and performance benchmark
- Modify: version, changelog, README/release documentation as needed for a release candidate

**Deliverable:** `1.1.0+3` is locally release-ready without push, tag, publication, F-Droid submission, or iOS release.

- Add an API 36 integration flow that creates and finishes two profile-linked matches, then completes one match and one window comparison.
- Run format, analyze, all tests, migration/backup tests, performance benchmarks, Debug APK, API 24/36 smoke, Android integration, reproducible Android build, and iOS no-sign CI-equivalent checks where the host permits.
- Confirm the worktree is clean except committed plan changes and no Drift multi-instance warning remains.
- Update version/release documentation and record any environment-only verification not runnable locally.

## Final Verification

```powershell
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --reporter expanded
flutter test test/performance/task15_query_benchmarks_test.dart --reporter expanded
flutter build apk --debug --no-pub
flutter test integration_test/main_loop_test.dart -d <android-device-id>
flutter test integration_test/player_comparison_test.dart -d <android-device-id>
```
