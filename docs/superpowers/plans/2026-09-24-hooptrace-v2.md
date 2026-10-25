# HoopTrace v2.0.0 Implementation Plan

> Implementation and the recorded local acceptance are complete; this is a historical execution plan, not a new assignment or release authorization. Consult [HANDOFF](../../../HANDOFF.md) and the [candidate record](../../release/v2.0.0-candidate.md) for current status.

> The steps below retain the original implementation breakdown. Current maintenance follows [AGENTS.md](../../../AGENTS.md) and [CONTRIBUTING.md](../../../CONTRIBUTING.md); recorded checkbox state does not establish current outstanding work.

**Goal:** Deliver an Android release candidate whose offline 1v1 journey runs from quick setup through trustworthy results and player history.

**Architecture:** Extend the existing command-backed Drift kernel without a schema bump, then compose the product flow with GoRouter/Riverpod and the editorial design system. Keep summary, replay, and share projections sourced from the same `MatchDetail` analytics. Add a file-backed safety-backup service outside SQLite.

**Tech Stack:** Flutter 3.41.9, Dart 3.11.5, Riverpod, GoRouter, Drift/SQLite, Android API 24-36.

**Spec:** `docs/superpowers/specs/2026-09-24-hooptrace-v2-design.md`

## Global Constraints

- Preserve offline operation, audit chronology, idempotent receipts, transactions, and live scoring undo semantics.
- Keep Drift schema 3 and JSON backup format 2; do not reinterpret historical coverage.
- Keep landscape scoring and 48dp primary targets.
- Update both ARB files and regenerate localization output for user-visible text.
- Preserve unrelated user changes and do not publish, tag, push, or expose signing material.

## Review Focus

- Reusing an old finish command ID without the new optional field must return its original receipt rather than conflict.
- A restore safety snapshot must never be presented as recoverable until flush, readback, validation, and atomic publish succeed.
- Deep links to shell tabs, summary, replay, or a player must have deterministic back behavior after process restart.
- Complete-shot confirmation with zero attempts must remain a valid declaration while percentages display no data.
- Large databases exceeding an import limit must fail export before opening a share sheet or replacing data.

---

### Task 1: Release baseline and tracking-coverage contract

**Files:** `third_party/android_runtime/*`, `lib/core/data/commands/match_command_service.dart`, replay audit/localization files, and related tests.

**Interfaces:** Produces optional `FinishMatchCommand.trackingCoverage` and `SetTrackingCoverageCommand`; consumers in Tasks 3-4 call those APIs.

- [ ] Add failing command-service tests for payload compatibility, atomic finish coverage, idempotency, correction, lifecycle validation, audit visibility, and rollback.
- [ ] Implement the minimal command changes and localized audit rendering; keep null finish coverage absent from the fingerprint payload.
- [ ] Reconcile the runtime dependency coordinate and notice from the actual Gradle release graph, retaining CI verification.
- [ ] Run focused command, audit, metadata, and Android runtime checks; commit `feat: add trustworthy shot coverage`.

### Task 2: Safe backup and capacity contract

**Files:** export codec/coordinator/gateway, new safety-backup storage, data-management UI, providers, localization, and export tests.

**Interfaces:** Produces `SafetyBackupStore`, list/restore/delete operations, and export-limit validation for Task 5 release validation.

- [ ] Add failing tests for flush/readback/atomic publication, retention, active-match blocking, replace rollback, write failure, malformed snapshot, and export limits.
- [ ] Implement file-backed safety snapshots outside SQLite and serialize replacement operations so no business write can race the safety capture.
- [ ] Expose the two latest snapshots in data management with localized restore/error states.
- [ ] Run export, settings, backup compatibility, and migration tests; commit `feat: protect replacement restores`.

### Task 3: Product shell, quick setup, and live guidance

**Files:** router/providers, home/history/player shell, pregame/controller, scoring page/preferences, design system, localization, and widget/route tests.

**Interfaces:** Consumes tracking coverage from Task 1; produces `MatchSetupPreset` and shell routes for Task 4 rematch and summary entry.

- [ ] Add failing tests for three-tab state preservation, direct recent-summary navigation, preset safety, inline player creation, coverage choice, guide persistence, retry/save status, large text, and 48dp targets.
- [ ] Implement the indexed shell and bounded recent summaries with deterministic deep-link/back behavior.
- [ ] Implement compact pregame presets and inline profile creation; create a new match ID only on confirmed start.
- [ ] Implement the non-blocking three-step scoring guide and clearer persistence feedback without changing scoring semantics.
- [ ] Run affected route/widget/golden tests and commit `feat: streamline the match journey`.

### Task 4: Result summary and player growth

**Files:** new summary feature, router, replay/share projection helpers, player list/career pages, analytics copy/components, localization, and tests.

**Interfaces:** Consumes Tasks 1 and 3 APIs; produces `/matches/:matchId/summary`, rematch preset construction, and profile-link actions.

- [ ] Add failing tests for finish-to-summary routing, key-moment cap, coverage explanation, rematch freshness, profile linking constraints, refresh, and source-aware return behavior.
- [ ] Build a lightweight summary from the canonical match projection and shared analytics/share components.
- [ ] Add rematch, replay, share, and unlinked-participant actions; preserve match-name snapshots and forbid automatic same-name merges.
- [ ] Make player-row navigation open career, move edit secondary, render readable trends, and correct recent-change wording and statistical denominators.
- [ ] Run summary/replay/player/widget/integration tests and commit `feat: close the postgame loop`.

### Task 5: Candidate metadata, regression validation, and artifacts

**Files:** version metadata, CHANGELOG/README/release docs, screenshots, CI/release scripts where needed, and integration/performance tests.

**Interfaces:** Consumes all prior tasks; produces `2.0.0+4` candidate documentation and verified Android artifacts.

- [ ] Add or extend file-database integration tests for restart recovery, schema-2 upgrade, long command-backed matches, and backup round trip.
- [ ] Update version metadata, bilingual release notes, upgrade guidance, screenshots, privacy/release records, and acceptance evidence.
- [ ] Run formatting, analysis, full tests, performance tests, localization/schema checks, Android native tests, debug build, API 24/36 flows, and unsigned reproducibility checks.
- [ ] When the existing signing environment is available, build the candidate and verify certificate continuity, permissions, version, and SHA-256; otherwise record the exact release blocker.
- [ ] Request a whole-branch review, fix all Critical/Important findings with RED-GREEN tests, and commit `release: prepare 2.0.0 candidate`.
