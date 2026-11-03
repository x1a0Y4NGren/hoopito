# Task 4 report — transactional match command kernel

## Scope

Implemented a Drift-backed `MatchCommandService` for `start`, `record`,
`correct`, `undo`, `pause`, `resume`, `finish`, and `abandon`. Every public
method generates command/entity UUIDs before entering one awaited Drift
transaction. The transaction writes event/location/audit/receipt state and
builds the resulting `MatchDetail` from transaction-local rows; the public
method returns that projection only after the transaction commits. No UI
state is published from inside a transaction.

The service reuses `audit_logs` as a durable command-receipt ledger rather
than adding a schema-v2 table. Receipt rows use `action = command`, contain a
SHA-256 payload fingerprint, and persist the first committed projection in
their JSON. Record, correction, undo, pause/resume, finish, and abandon also
write their business mutation/audit state in the same transaction as the
receipt.

The production scoring route now constructs a command-backed coordinator in
`HoopTraceApp`. `AppRouter` waits for `startCommitted`/`loadCommitted`, and
`ScoringPage` sends score/foul/undo operations through the service and updates
only from the committed projection. The legacy snapshot adapter remains only
for explicit non-command compatibility construction, is documented as
retired, and is marked deprecated; the production route cannot fall back to
`replaceMatchSnapshot`.

## TDD RED evidence

The behavior test was written before the service existed:

```text
flutter test test/core/data/match_command_service_test.dart --reporter expanded
Error when reading 'lib/core/data/commands/match_command_service.dart':
系统找不到指定的路径。
Type 'StartMatchCommand' not found.
Method not found: 'MatchCommandService'.
...
Compilation failed for testPath=.../test/core/data/match_command_service_test.dart
```

After the first GREEN slice, a detailed-shot projection test was added before
changing the reducer. Its expected RED was:

```text
record projection counts made field goals and free throws but not misses
Expected: <2>
  Actual: <0>
test/core/data/match_command_service_test.dart:165:7
```

The reducer was then minimally extended to count made `fieldGoal` and
`freeThrow` events while ignoring misses.

The fix-round review tests were then run before each corresponding change. The
first review RED included:

```text
duplicate start expected 0 actual 2
finish draft returned MatchDetail instead of CommandValidationFailure
pause/resume returned MatchDetail instead of enforcing alternating state
score with location returned MatchDetail instead of rejecting the old location
mutable rule template changed to [1, 2, 3]
fieldGoal counters expected 1 actual 0
watcher observed a non-empty projection before the transaction committed
production scoring route created 0 command receipts
```

After fixture-only corrections (backup timestamps and direct button callback
invocation for the off-screen responsive layout), the production route still
failed its durable assertion with `commandReceipts length >= 2`, actual `0`.
The bridge was implemented and the app integration test went GREEN.

For the final validation rule, the test was written first and produced:

```text
flutter test --no-pub test/core/data/match_command_review_test.dart \
  --plain-name "correction rejects a non-made score outcome" --reporter expanded
Expected throws CommandValidationFailure; Actual emitted Future<MatchDetail>
```

The command validation was then added; the same test passed (`+1`).

## Design and idempotency keys

- `StartMatchCommand` generates command, match, participant, and clock UUIDs
  before the transaction. Its rule-template lists are copied and wrapped in
  unmodifiable lists, so equivalent commands have stable immutable payloads
  and fingerprints.
- `RecordMatchEventCommand` generates command, event, optional location, and
  audit UUIDs before the transaction. New command locations are restricted to
  `fieldGoal`; score outcomes are restricted to `made` and are validated before
  reducer writes.
- Correction and undo generate command/audit UUIDs before the transaction;
  correction never changes event `id` or `match_id`, and undo soft-deletes for
  auditability. Correction/undo audit JSON contains human-readable before and
  after values.
- Pause/resume generate command and semantic-event UUIDs. The latest semantic
  event is read by SQLite insertion order, enforcing pause → resume → pause
  sequencing without implementing Task 5 elapsed-time algorithms.
- A receipt is looked up by its primary key (`audit_logs.id`). Equal
  fingerprints decode and return the receipt's original committed projection,
  not the current match projection after later commands; different
  fingerprints raise `CommandConflictFailure` with the last committed
  projection. The persisted projection survives a new service instance and
  backup/restore.
- `active_sessions(id = 'active')` is claimed and released in the same
  transaction as match lifecycle changes. SQLite's serialized writer plus the
  fixed primary key rejects simultaneous starts; the service maps the loser to
  `ActiveMatchConflictFailure`.
- Finish/abandon require lifecycle `active`, atomically delete the active row,
  and transition to terminal state. Duplicate command IDs return the original
  receipt; draft/finished/abandoned/archived transitions are typed validation
  failures.
- `CommandTransactionFailure` carries `lastCommittedProjection`, the
  immutable command, `retryable`, and an explicit `retry()` closure. The test
  failure injection occurs after business writes and before transaction
  completion, proving rollback leaves no event, receipt, or watcher-visible
  projection behind.
- `MatchRepository.buildDetail` includes `fieldGoal` location IDs in located
  and attempt counters. `listAuditLogs` excludes internal command receipts.

## Commits

Original implementation and hardening:

- `06519c2 feat: add transactional match command kernel`
- `3e0cb05 fix: retire snapshot command fallback`
- `63d1398 fix: persist record command audit`
- `43d066f fix: score made shot events in projections`
- `840928d feat: expose command kernel compatibility aliases`
- `9114cba fix: validate shot location event types`

Fix round:

- `865e2b6` test: capture command kernel review regressions
- `e9f3a2d` test: stabilize command review fixtures
- `e40fb7b` fix: retain immutable command projections
- `31e6d33` fix: route production scoring through commands
- `83b0b5e` test: remove redundant review import
- `2558759` fix: validate corrected score outcomes
- `0dae003` docs: mark legacy snapshot bridge retired

## Verification

```text
flutter test --no-pub --reporter expanded
# 163 tests passed, 0 failures

flutter analyze --no-pub
# No issues found! (ran in 3.5s)

flutter test --no-pub test/core/data/match_command_review_test.dart --reporter expanded
# 9 review tests passed

flutter test --no-pub test/app/command_backed_scoring_test.dart --reporter expanded
# production command-backed scoring route passed

dart format --output=none --set-exit-if-changed lib test
# Formatted 119 files (0 changed)

git diff --check
# clean (Git may report the repository's LF/CRLF normalization warning)
```

## Concerns / self-review

- Receipt rows intentionally live in `audit_logs`; no schema, generated Drift
  helper, or eleven-table backup change was necessary. Existing backups retain
  and restore receipts, so duplicate commands remain provable after restore.
- Clock persistence is initialized by `start` and semantic pause/resume events
  are recorded, but elapsed-time reconstruction and end-condition algorithms
  remain Task 5 scope.
- The command-backed route commits score/foul/undo before updating the visible
  controller. The existing location dialog's legacy mark action is not used to
  write a new command location; command locations are deliberately
  `fieldGoal`-only until the later location/UI work.
- The command-backed scoring controller now keeps a provisional pending marker
  only after the score command commits, persists confirmation through the
  location command, awaits undo soft-delete, and exposes retryable failures to
  the page. Retry actions reuse the immutable command held by
  `MatchCommandFailure`, so a transient failure cannot create a second event.
- Riverpod/UI composition remains Task 6 scope. The production bridge is
  command-backed now, while the explicit legacy coordinator constructor is
  retained only for compatibility and cannot be selected by `HoopTraceApp`.
  Process-level active-session recovery, provider-owned controller lifetime,
  and the resume/new-match gate are explicitly deferred to Task 6.

## UI closeout verification

The controller/widget closeout added real command-backed coverage for committed
made field goals, unlocated-score skip, persisted location confirmation,
soft-delete undo, and a retryable confirmation failure. The retry test verifies
that the same receipt/command ID is committed after retry and that the pending
state is retained until the retry commits. A controller busy guard prevents
parallel score/foul/confirm/undo/retry commands from publishing conflicting
projections. Skip is rejected while confirmation is in flight, and both the
controller and production foul button reject a foul while a shot location is
pending so undo cannot target the wrong event. After rejection, undo still
soft-deletes the pending shot event.

```text
flutter test --no-pub test/features/scoring/scoring_controller_test.dart \
  test/features/scoring/scoring_page_test.dart --reporter compact
# 26 tests passed

dart format --output=none --set-exit-if-changed \
  lib/features/scoring/scoring_controller.dart \
  lib/features/scoring/scoring_page.dart \
  test/features/scoring/scoring_controller_test.dart \
  test/features/scoring/scoring_page_test.dart
# Formatted 4 files (0 changed)

git diff --check
# clean
```
