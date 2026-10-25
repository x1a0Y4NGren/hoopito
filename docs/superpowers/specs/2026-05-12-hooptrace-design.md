# HoopTrace Product Design

> Historical first-release design. Later changes supersede parts of its visual and scoring behavior; consult current code, tests, and the [history scope](../README.md) before reusing it.

## Overview

HoopTrace is an open-source, permanently free, offline-first mobile app for basketball one-on-one scoring, shot location capture, and post-game review. The first release targets Android while keeping the Flutter codebase ready for future iOS support.

The app is not intended to enforce basketball rules as an authority. Its role is to help players record a match quickly, correct mistakes safely, and review trustworthy local data after the game.

## Product Principles

- Permanently free and permanently open source.
- Fully local and offline by default.
- Android first, with iOS expansion preserved through Flutter.
- Fast enough for live court-side use.
- Professional enough for meaningful replay, statistics, audit history, and data export.
- Manual correction always remains possible.
- The main scoring and replay experiences prioritize the court view over dense controls.

## First Release Scope

Included in the first release:

- Home page, pre-game setup, scoring page, replay page, replay history page, player management, rule template management, settings page, and project details page.
- Offline SQLite storage.
- Local player profiles and temporary match-only player names.
- Free scoring plus configurable rule templates.
- Lightweight possession and round tracking.
- Scoring events, missed-shot events, fouls, free throw or reward events, pause or interruption events, notes, and custom event types.
- Shot location capture with a confirm or skip flow.
- Full edit mode with audit history.
- Professional replay with timeline, shot chart, filters, scoring flow, lead changes, key possessions, fouls, and long-term local statistics.
- JSON full backup export and import, CSV export, replay image export, and user-authorized automatic backup.
- Chinese-first UI copy with an internationalization structure ready for English.
- GitHub Releases APK distribution and F-Droid-friendly preparation.

Not included in the first release:

- Accounts, login, cloud sync, online leaderboard, community features, in-app issue forms, video capture, AI recognition, PDF reports, and Play Store launch.

## Visual Direction

The selected visual direction is court-first.

- Core match pages are landscape.
- The center court occupies the largest area.
- Blue side controls stay on the left; red side controls stay on the right.
- The visual system uses a warm off-white base, bright orange accent, and clear red/blue team colors.
- Data density is controlled so the live scoring page remains readable and hard to mis-tap.
- Repeated items may use compact cards, but page sections should feel like functional surfaces, not marketing panels.

## Page Model

### Home Page

The home page is a portrait-friendly entry point.

- Main actions: start scoring and open replay history.
- A low-distraction project details icon sits in the lower-right area.
- Settings are reachable from a top or corner entry.

### Pre-Game Setup

The pre-game setup page is portrait-friendly and optimized for fast start.

Default visible fields:

- Red player and blue player.
- Rule template.
- Timer enabled or disabled.

Expandable advanced settings:

- Target score.
- Time limit.
- Win-by-two setting.
- Foul rules.
- Score button configuration.
- Possession hint rules.
- Custom event types.

Users can start a match without filling player profiles. Temporary names are allowed.

### Scoring Page

The scoring page is the core product surface and is forced to landscape.

Center:

- A custom-painted half court.
- Confirmed red and blue scoring locations.
- Missed-shot locations and special event markers.
- Temporary drag marker while a location is being placed.

Left and right:

- Blue player controls on the left.
- Red player controls on the right.
- Each side shows player name, total score, foul count, possession status, and quick actions.
- Default quick actions are `+1`, `+2`, `+3`, missed shot, foul, and note.
- Score buttons are configurable through the active rule template.

Top:

- Current score for each side.
- Timer or rule status in the center.
- Replay entry near the center top.
- Low-interruption rule hints, such as target score reached or possession change suggested.

Bottom:

- Temporary action bar for pending shot location.
- Actions: confirm location, skip location, undo.
- Also used for possession hints, rule hints, and edit-mode tools.

Scoring interaction:

1. The user taps a red or blue scoring button.
2. A match event is created.
3. A same-color temporary marker appears on the court.
4. The user drags the marker and confirms, or skips location capture.
5. Confirmed markers are locked.
6. Locked markers can only be changed in edit mode.

If another scoring action is attempted while a location is pending, the app asks the user to confirm, skip, or undo the pending location first.

### Replay Page

The replay page is forced to landscape and defaults to read-only.

Center:

- The court displays all selected match locations.
- Filters can show all events, one side, made shots, missed shots, score values, time ranges, possession segments, and custom event types.

Sides:

- Red and blue side panels expose score history, foul history, and side overview.

Top:

- Total score.
- Global timeline entry.
- Match rule snapshot summary.

Edit mode:

- Allows event correction, marker movement, marker deletion, time note correction, player name correction, foul correction, and custom event edits.
- Every edit writes to the audit log.

### Replay History Page

The replay history page is portrait-friendly.

Each match record shows:

- Date.
- Red and blue player names.
- Final score.
- Winner.
- Rule template name.
- Match duration.
- Whether location data exists.

The page supports search and filters by player, date, template, win or loss, and completeness. Tapping a record opens the replay page for that match.

### Player Page

The player page manages local player profiles.

Player profiles include:

- Nickname.
- Optional color preference.
- Notes.
- Creation time.

Players are local data only. The app has no account system and no multi-user data isolation.

### Rule Template Page

Rule templates support:

- Target score.
- Time limit.
- Win-by-two.
- Foul rules.
- Default scoring buttons.
- Possession hint rules.
- Custom event types.

The first release includes built-in templates and user-created templates. A match stores a snapshot of its selected template at match start.

### Settings Page

The settings page includes:

- Default rule template.
- Default players.
- Theme and accent color.
- Statistical interpretation options.
- JSON backup export and import.
- CSV export.
- Replay image export settings.
- Automatic backup settings.
- Privacy statement.
- Experimental feature toggles.
- Developer diagnostics.
- Project details entry.

Automatic backup is disabled by default and requires explicit user authorization.

### Project Details Page

The project details page includes:

- Permanent open-source and free statement.
- GitHub repository link.
- License information.
- Contribution guide link.
- Issue feedback link.
- Version information.
- Privacy and local data explanation.

External actions open outside the app. The app does not include a network feedback form in the first release.

## Replay And Analytics

Single-match replay includes:

- Chronological scoring flow.
- Foul timeline.
- Pause, interruption, note, reward, and custom event timeline.
- Shot chart with made and missed locations.
- Score value distribution.
- Lead changes.
- Largest lead.
- Ties and overtakes.
- Key possessions, including tie, overtake, match point, and scoring runs.
- Rule snapshot comparison.

Long-term local statistics include:

- Match count.
- Win and loss record.
- Average score.
- Shooting percentage.
- Common shot areas.
- Foul trend.
- Recent match trends.
- Rule-template-based comparison.

All long-term statistics are local only and are derived from stored matches.

## Data Model

The app stores data in SQLite. Match facts are represented as an event stream. Current score and statistics are derived from the event stream or stored as recalculable caches.

Core entities:

- `Match`: one recorded match, with timing, status, red and blue participant snapshots, rule template snapshot, and notes.
- `Player`: local player profile.
- `RuleTemplate`: reusable rule configuration.
- `MatchEvent`: event stream item for score, miss, foul, reward, pause, interruption, note, or custom event.
- `ShotLocation`: normalized court coordinate linked to a match event.
- `PossessionSegment`: lightweight possession or round record.
- `AuditLog`: append-only record of create, undo, edit, delete, import, and restore operations.
- `BackupManifest`: backup package metadata including schema version and checksum information.

Important constraints:

- Events are not silently overwritten.
- Edits update the current event representation and record before/after differences in `AuditLog`.
- Rule templates are snapshotted into a match when a match starts.
- Statistics must be reproducible from event data.
- Court coordinates are normalized as `x` and `y` values from `0.0` to `1.0`.
- Backup import handles schema versions from the first release onward.

## Export, Import, And Backup

JSON full backup:

- Includes matches, players, rule templates, match events, shot locations, audit logs, app settings, and backup metadata.
- Can be imported to restore local data.

CSV export:

- Includes at least match list, event list, and player statistics exports.
- Designed for spreadsheet analysis.

Replay image export:

- Exports a shareable image containing final score, shot chart, and key summary statistics.

Automatic backup:

- Disabled by default.
- Requires explicit user authorization.
- Uses Android-friendly storage and permission behavior.

## Technical Architecture

Technology:

- Flutter.
- Dart.
- SQLite.
- CustomPainter for court rendering.
- GestureDetector or equivalent Flutter gesture handling for marker placement and edit mode.
- Flutter localization resources for Chinese-first UI and future English support.

Layering:

- UI layer: pages, widgets, visual state, layout, navigation.
- State layer: screen controllers and reactive state.
- Domain layer: match, event, rule, possession, scoring, audit, and statistics logic.
- Data layer: repositories, DAOs, schema migrations, and persistence adapters.
- Export layer: JSON, CSV, image export, import, and backup validation.

Suggested source structure:

- `app/`: app entry, routing, theme, orientation strategy.
- `features/scoring/`: scoring page, scoring state, court interaction.
- `features/replay/`: replay page, timeline, filters, edit mode.
- `features/history/`: replay history list and filters.
- `features/players/`: local player profiles.
- `features/rules/`: rule templates.
- `features/settings/`: settings, privacy, local data, project details.
- `core/domain/`: pure domain models and business logic.
- `core/data/`: repositories, SQLite DAOs, schema migrations.
- `core/export/`: JSON, CSV, image export and import.
- `core/audit/`: audit entries and diff format.

## Orientation Strategy

- Scoring and replay pages are forced to landscape.
- Home, pre-game setup, history, player management, rule templates, settings, and project details are portrait-friendly.
- The codebase should keep orientation decisions near routing or page-shell boundaries so future tablet and iOS behavior can be adjusted without rewriting feature logic.

## Testing And Quality Gates

Required test coverage for the first release:

- Core scoring logic.
- Rule templates, including target score, time limit, win-by-two, foul rules, and possession hints.
- Event creation, undo, edit, delete, and audit logging.
- SQLite repositories and migrations.
- JSON backup export and import round trip.
- CSV export fields.
- Replay statistics: scoring flow, shooting percentage, shot zones, lead changes, and key possessions.
- Key UI flows: start match, score, confirm location, skip location, replay, edit, export, and import.

CI gates:

- Format check.
- Static analysis.
- Unit tests.
- Widget or integration tests for key flows.
- Android debug build.

## Release Strategy

The first release ships through:

- GitHub Releases with APK, source package, and changelog.
- Repository documentation with README, development guide, contribution guide, privacy statement, and license.
- F-Droid-friendly dependency and build decisions.
- F-Droid metadata preparation.

Play Store distribution is outside the first release scope.

## Implementation Priority

The first runnable product path is:

1. Flutter project scaffold and app shell.
2. Core domain model for match events and scoring.
3. SQLite persistence.
4. Pre-game setup.
5. Landscape scoring page with court-first layout.
6. Scoring event creation.
7. Shot location confirm or skip flow.
8. Replay page for the current match.
9. Replay history persistence.

After the main loop works, add:

1. Rule templates.
2. Possession hints.
3. Edit mode and audit history.
4. Missed shots, fouls, reward events, notes, and custom events.
5. Statistics.
6. Backup import and export.
7. CSV and replay image export.
8. Settings, project details, and release documentation.

## Open Decisions

These decisions are intentionally deferred until implementation planning:

- Exact Flutter state management package.
- Exact SQLite abstraction.
- Exact charting approach for long-term statistics.
- Exact Android storage location for automatic backups.
- Final app icon and branding assets.

The deferred decisions do not change the product scope or core architecture.
