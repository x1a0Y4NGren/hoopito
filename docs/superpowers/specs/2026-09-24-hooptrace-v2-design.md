# HoopTrace v2.0.0 Design

> This design records the approved 2.0 scope. Implementation and local acceptance are recorded in [HANDOFF](../../../HANDOFF.md) and the [candidate record](../../release/v2.0.0-candidate.md); remaining release gates are not completed by this design document.

HoopTrace v2.0.0 turns the existing offline 1v1 scorer into a complete match journey: start quickly, record confidently, understand the result, and build a trustworthy player history. Android is the release-candidate platform. The release remains offline-first, free, open source, account-free, and tracker-free.

## Product flow

- The application shell has three primary destinations: Match, History, and Players. Settings remains accessible from the shell header. Pregame, live scoring, result summary, and replay are full-screen routes outside the shell.
- Match shows the active match or a start action plus the three latest finished matches. A recent result opens its result summary directly.
- Pregame supports temporary names, existing profiles, inline profile creation, recent-match presets, a compact rule summary, and an advanced section. It asks whether the operator will mainly keep score or record every shot; both choices use the same landscape scoring workspace.
- Live scoring retains the fixed `+1`, `+2`, `+3`, and miss controls on both sides and the centered court. It adds clearer save state, last action, retry feedback, and a skippable three-step guide.
- Finishing confirms the score and whether every shot was recorded. A result summary shows the score, key moments, record coverage, replay/share actions, profile-link actions, and a rematch action.
- Players open to a career page; editing is secondary. Career and comparison surfaces distinguish recorded counts from trustworthy percentages and use consistent field-goal, free-throw, and confirmed-location denominators.

## Data contract

- Keep Drift schema 3 and backup format 2. Continue to accept format 1/schema 2 and format 2/schema 3 backups.
- `scoresOnly` means no completeness promise. `shotAttempts` or a stronger existing value means every attempt was recorded. Never infer completeness from misses or locations.
- `FinishMatchCommand` accepts an optional tracking-coverage confirmation. A null value is omitted from its payload to preserve old command fingerprints. Score confirmation, coverage, lifecycle, audit, receipt, and analytics invalidation commit atomically.
- `SetTrackingCoverageCommand` explicitly corrects coverage for active, finished, or archived matches, writes an `edit` audit against the match, produces a receipt, and does not enter the live scoring undo stack.
- Existing `locations` and `full` values remain intact. Coverage changes are visible in the localized audit sheet.
- Field-goal and free-throw percentages are separate. Untrustworthy samples render as unavailable. Location coverage is confirmed field-goal locations divided by recorded field-goal attempts.

## Recovery and compatibility

- Before replace restore, persist a verified internal safety backup outside the database by writing a temporary file, flushing, reading and validating it, and atomically publishing it. Keep two backups.
- Replacement and rollback remain blocked while an active match exists. Business writes are blocked between safety capture and replacement completion.
- Export validates the same 32 MiB, 100,000-row-per-table, and 200,000-total-row limits as import before sharing or publishing a backup.
- Official v1.0 schema 2 data upgrades through the existing incremental migration; current schema 3 data opens unchanged. Older incompatible data remains protected from destructive startup.

## Delivery boundaries

The candidate is version `2.0.0+4`. It includes bilingual copy, updated screenshots and release notes, Android API 24/36 validation, an unsigned reproducibility check, and a signed-candidate verification when the existing signing environment is available. It does not create a tag, publish a GitHub Release, add cloud services, or expand beyond 1v1.
