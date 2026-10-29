# Task 3 report — Domain model and Drift schema v2

## Milestones and commits

- `7e1fd4c test: define schema v2 domain contract` — contract/invariant tests first.
- `bee24c3 feat: establish schema v2 domain contract` — schema, domain records, generated Drift code, native bootstrap probe, and repository compatibility wiring.
- `a1f4dbd test: cover schema v2 review fixes` — review-driven RED tests for native pre-open rejection, canonical participants/lifecycle, FK behavior, event triggers/audit, full v2 backup graph, and official schema export.
- `7b5a026 fix: close schema v2 review gaps` — production/schema/export implementation, regenerated Drift code, and committed schema v2 dump.
- `eed1163 chore: clear analyzer findings` — final analyzer/format cleanup.

## RED evidence

Initial command:

```text
flutter test test/core/data/schema_v2_test.dart --reporter expanded
```

Expected RED: compilation failed because `MatchParticipantsCompanion`, `MatchClocksCompanion`, `ActiveSessionsCompanion`, event `outcome`, possession `source`, and `LegacySchemaDetectedException` were absent from the v1 model. The test file was committed before production changes.

The follow-up ClockState/ActiveSession invariant slice also produced the expected RED for missing `clock_state.dart` and `active_session.dart` before those records were implemented.

## GREEN evidence

```text
flutter test test/core/data/schema_v2_test.dart test/core/data/match_repository_test.dart --reporter expanded
# 17 tests passed

flutter test --reporter expanded
# 126 tests passed

flutter analyze
# no errors (only existing style/info diagnostics)

git diff --check
# clean
```

## Files and contract coverage

- `lib/core/data/app_database.dart`: schema v2 tables, constraints, foreign keys with cascades, indexes, shot-location triggers, v1 incompatibility guard.
- `lib/core/data/app_database.g.dart`: regenerated Drift data classes and companions.
- `lib/core/data/app_database_provider.dart`: `openNativeAppDatabase()` using `getApplicationDocumentsDirectory()/hooptrace.sqlite` and raw `PRAGMA user_version` setup probe.
- `lib/core/data/schema_v2.dart`: public schema version/table export.
- `lib/core/domain/domain_enums.dart`: recording/lifecycle/clock/event/outcome/possession/restore/theme/tracking vocabularies.
- `lib/core/domain/entities/{match.dart,match_participant.dart,clock_state.dart,active_session.dart,match_event.dart,possession_segment.dart,rule_template.dart}`: participant snapshots, clock/session records, normalized event labels, outcome/clock position, soft deletion, possession source, and rule possession policy.
- `lib/core/data/repositories/match_repository.dart`: canonical participant persistence, event extensions, and rule snapshot policy persistence while retaining v0.1 fixture compatibility.
- `test/core/data/schema_v2_test.dart`: domain invariants, schema/table/index/FK integrity, participant/event cascade, shot-location cardinality and free-throw rejection, active-session singleton, and legacy schema guard.

## Fix round 1 evidence

The independent review identified nine important behavior gaps and three analyzer infos. Each behavior slice was added to `test/core/data/schema_v2_fix_round1_test.dart` before implementation; the first run was RED because `openNativeAppDatabaseAt` did not yet exist. After implementation:

```text
flutter test test/core/data/schema_v2_fix_round1_test.dart test/core/data/match_repository_test.dart test/core/export/json_backup_codec_test.dart --reporter expanded
# 26 tests passed

flutter test --reporter expanded
# 136 tests passed at the fix-round-1 checkpoint; superseded by the fresh fix-round-2 count below

flutter analyze
# No issues found! (ran in 8.2s)

dart run build_runner build --delete-conflicting-outputs
# Built successfully; generated app_database.g.dart had zero diff

dart run drift_dev schema dump lib/core/data/app_database.dart drift_schemas/drift_schema_v2.json
# Wrote to drift_schemas/drift_schema_v2.json; committed dump had zero diff

dart format --output=none --set-exit-if-changed lib test
# exit 0; no tracked formatter diff

git diff --check
# clean
git status --short
# clean
```

The native test creates a real temporary SQLite file with `PRAGMA user_version = 1` and a sentinel row, verifies the typed rejection before Drift opens, and verifies both the pragma and sentinel remain unchanged. The app's production `openAppDatabase()` now uses the same raw setup probe against `getApplicationDocumentsDirectory()/hooptrace.sqlite`.

The final vocabulary hardening was also TDD-driven: the new invalid EventKind/side/free-throw/outcome assertions first failed because three database writes were accepted, then passed after the `MatchEvents` CHECK constraints were added. The fix-round test file had 9 passing tests at that checkpoint; the fresh fix-round-2 targeted and expanded counts are recorded below.

## Fix round 2 evidence

The scoped re-review follow-up was completed in small commits:

- `5b3f05d fix: validate v2 backup graphs and shot outcomes` — pre-transaction graph validation and legal/illegal shot combinations.
- `cf3bd2d test: verify official v2 schema snapshot` — official `GeneratedHelper` plus `SchemaVerifier` runtime validation test.
- `aa9c1a4 chore: refresh generated v2 schema baseline` — refreshed official schema dump/helper after constraint changes.
- `6a284ba test: reject non-shot outcomes for shots` — explicit domain policy for shot outcomes versus custom `notApplicable`.
- `b60a5ec chore: clear codec analyzer import` — final analyzer cleanup.

RED evidence was captured before each behavior implementation. The backup RED run accepted a missing participant and an active session pointing at a finished match; the shot RED run rejected legal missed free throws, accepted field-goal events without an outcome, and rejected the corresponding domain combinations. The official schema verifier test then passed against the generated v2 helper.

Fresh final verification:

```text
flutter test test/core/domain/domain_entities_test.dart test/core/data/schema_v2_test.dart test/core/data/schema_v2_fix_round1_test.dart test/core/export/json_backup_codec_test.dart --reporter expanded
# 32 tests passed

flutter test --reporter expanded
# 142 tests passed, 0 failures

flutter analyze
# No issues found! (ran in 8.2s)

dart run build_runner build --delete-conflicting-outputs
# completed with no tracked generated diff

dart run drift_dev schema dump lib/core/data/app_database.dart drift_schemas/drift_schema_v2.json
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
# completed with no tracked schema/helper diff

dart format --output=none --set-exit-if-changed lib test
# FORMAT_EXIT=0

git diff --check
# clean
git status --short
# clean
```

The backup codec now requires exactly one red and one blue participant for every match, validates profile references, enforces one clock per match, validates active-session lifecycle ownership, and checks possession source plus event/match consistency before opening the replacement transaction. Shot domain/SQL rules allow missed free throws (`points = 0`) and missed field goals, require made shots to carry positive points, and preserve `custom + notApplicable`.

## Concerns / self-review

- Existing v0.1 backup/repository fixtures construct generated `Matche` and possession rows directly. Those fixtures were updated to provide the canonical lifecycle/participant fields, and `app_database.g.dart` was regenerated from source rather than hand-edited; a second generator run produced zero diff.
- Domain constructor names/status remain only as compatibility inputs/getters; SQL and repository persistence use participant rows plus the single lifecycle column. The full v2 backup codec now exports/restores all eleven persisted table groups; Task 13 merge/retention/conflict policy remains intentionally out of scope.
- Drift 2.34.0 and drift_dev 2.34.0 are pinned so the official schema dump is reproducible; `sqlite3` is a direct dev dependency for the real native pre-open test.
