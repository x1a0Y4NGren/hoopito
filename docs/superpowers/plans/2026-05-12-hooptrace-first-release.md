# HoopTrace First Release Implementation Plan

> Historical first-release plan, not a current assignment. Execution instructions and checkboxes below describe that task only; see [history scope](../README.md).

**Goal:** Build the Android-first HoopTrace Flutter app with offline scoring, shot location capture, replay, local storage, audit history, statistics, backup/export, settings, and open-source release preparation.

**Architecture:** Use Flutter with a strict feature/domain/data split. Match facts are stored as an event stream in local SQLite, while scores, timelines, and statistics are derived from events or recalculable caches. The first executable path is match setup -> landscape scoring -> shot location confirm/skip -> local save -> replay.

**Tech Stack:** Flutter, Dart 3, Riverpod, GoRouter, Drift SQLite, CustomPainter, Flutter localization, JSON, CSV, Share Plus, Path Provider, GitHub Actions.

---

## Scope And Sequencing

The approved spec covers several subsystems. Implement in this order so each branch can produce working software:

1. Foundation: Flutter scaffold, dependencies, app shell, theme, routes, localization.
2. Domain kernel: players, rules, matches, events, scoring reducer, audit diff models.
3. Persistence: Drift database, repositories, migrations, seed data.
4. Main loop: pre-game setup, scoring page, court painter, pending shot location, current-match replay, history.
5. Professional features: rule templates, possession hints, edit mode, audit history, statistics.
6. Data operations: JSON backup import/export, CSV export, replay image export, automatic backup.
7. Product polish: settings, project details, docs, CI, GitHub release assets, F-Droid metadata preparation.

Do not begin a later phase until the main loop has tests and a working local run.

## File Structure

Create this project structure after Flutter scaffold:

```text
android/
assets/
  icons/
  images/
docs/
  superpowers/
    specs/
    plans/
  release/
lib/
  main.dart
  app/
    hoop_trace_app.dart
    app_router.dart
    app_theme.dart
    orientation_shell.dart
    l10n/
      app_en.arb
      app_zh.arb
  core/
    audit/
      audit_diff.dart
      audit_log_entry.dart
    data/
      app_database.dart
      app_database_provider.dart
      migrations.dart
      repositories/
        match_repository.dart
        player_repository.dart
        rule_template_repository.dart
    domain/
      analytics/
        match_analytics.dart
        match_analytics_calculator.dart
      entities/
        match.dart
        match_event.dart
        player.dart
        possession_segment.dart
        rule_template.dart
        shot_location.dart
      scoring/
        score_state.dart
        scoring_reducer.dart
      rules/
        rule_engine.dart
      value_objects/
        court_point.dart
        team_side.dart
    export/
      backup_manifest.dart
      csv_exporter.dart
      json_backup_codec.dart
      replay_image_exporter.dart
  features/
    history/
      history_page.dart
      history_controller.dart
    home/
      home_page.dart
    players/
      player_list_page.dart
      player_editor_page.dart
    pregame/
      pregame_page.dart
      pregame_controller.dart
    project/
      project_details_page.dart
    replay/
      replay_page.dart
      replay_controller.dart
      widgets/
        replay_timeline_sheet.dart
        replay_filter_bar.dart
    rules/
      rule_template_list_page.dart
      rule_template_editor_page.dart
    scoring/
      scoring_page.dart
      scoring_controller.dart
      widgets/
        court_painter.dart
        court_view.dart
        score_side_panel.dart
        pending_location_bar.dart
    settings/
      settings_page.dart
test/
  core/
    audit/
    data/
    domain/
    export/
  features/
    pregame/
    scoring/
    replay/
integration_test/
  main_loop_test.dart
```

## Task 1: Scaffold Flutter Project And Dependencies

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `lib/main.dart`
- Create: `test/smoke_test.dart`
- Modify: `.gitignore`

- [ ] **Step 1: Create the Flutter project scaffold**

Run from repository root:

```powershell
flutter create --platforms=android,ios .
```

Expected: Flutter creates `android/`, `ios/`, `lib/main.dart`, `test/widget_test.dart`, and project metadata.

- [ ] **Step 2: Replace `pubspec.yaml` dependencies**

Use this dependency baseline:

```yaml
name: hooptrace
description: Offline-first basketball one-on-one scoring and replay.
publish_to: "none"
version: 0.1.0+1

environment:
  sdk: ">=3.5.0 <4.0.0"

dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  collection: ^1.18.0
  csv: ^6.0.0
  drift: ^2.22.1
  drift_flutter: ^0.2.4
  file_picker: ^8.1.7
  flutter_riverpod: ^2.6.1
  go_router: ^14.6.2
  intl: ^0.19.0
  path: ^1.9.0
  path_provider: ^2.1.5
  share_plus: ^10.1.2
  url_launcher: ^6.3.1
  uuid: ^4.5.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: ^2.4.13
  drift_dev: ^2.22.1
  flutter_lints: ^5.0.0
  integration_test:
    sdk: flutter

flutter:
  uses-material-design: true
  generate: true
  assets:
    - assets/icons/
    - assets/images/
```

- [ ] **Step 3: Configure analysis**

Replace `analysis_options.yaml` with:

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_single_quotes: true
    require_trailing_commas: true
    avoid_print: true
    prefer_final_locals: true
```

- [ ] **Step 4: Add generated and temporary folders to `.gitignore`**

Append:

```gitignore
# Flutter / Dart
.dart_tool/
.flutter-plugins
.flutter-plugins-dependencies
.packages
build/
ios/Flutter/Generated.xcconfig
ios/Flutter/flutter_export_environment.sh

# Codex / planning scratch
.superpowers/
```

- [ ] **Step 5: Add a smoke test**

Create `test/smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('test harness runs', () {
    expect('HoopTrace'.contains('Trace'), isTrue);
  });
}
```

- [ ] **Step 6: Verify scaffold**

Run:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add .gitignore analysis_options.yaml pubspec.yaml pubspec.lock lib test android ios
git commit -m "chore: scaffold Flutter app"
```

## Task 2: App Shell, Theme, Routing, And Localization

**Files:**
- Create: `lib/app/hoop_trace_app.dart`
- Create: `lib/app/app_router.dart`
- Create: `lib/app/app_theme.dart`
- Create: `lib/app/orientation_shell.dart`
- Create: `lib/app/l10n/app_zh.arb`
- Create: `lib/app/l10n/app_en.arb`
- Create: `l10n.yaml`
- Modify: `lib/main.dart`
- Test: `test/app/app_shell_test.dart`

- [ ] **Step 1: Write the failing app-shell test**

Create `test/app/app_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/app/hoop_trace_app.dart';

void main() {
  testWidgets('HoopTrace app starts on home route', (tester) async {
    await tester.pumpWidget(const HoopTraceApp());
    await tester.pumpAndSettle();

    expect(find.text('开始计分'), findsOneWidget);
    expect(find.text('复盘历史'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test and verify failure**

Run:

```powershell
flutter test test/app/app_shell_test.dart
```

Expected: FAIL because `HoopTraceApp` does not exist.

- [ ] **Step 3: Add localization resources**

Create `l10n.yaml`:

```yaml
arb-dir: lib/app/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
```

Create `lib/app/l10n/app_zh.arb`:

```json
{
  "@@locale": "zh",
  "appName": "HoopTrace",
  "startScoring": "开始计分",
  "replayHistory": "复盘历史",
  "settings": "设置",
  "projectDetails": "项目详情"
}
```

Create `lib/app/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appName": "HoopTrace",
  "startScoring": "Start",
  "replayHistory": "Replay History",
  "settings": "Settings",
  "projectDetails": "Project"
}
```

- [ ] **Step 4: Add theme**

Create `lib/app/app_theme.dart`:

```dart
import 'package:flutter/material.dart';

class HoopTraceColors {
  const HoopTraceColors._();

  static const offWhite = Color(0xFFFFF8E8);
  static const cream = Color(0xFFF4EADB);
  static const orange = Color(0xFFFF7A1A);
  static const red = Color(0xFFD94735);
  static const blue = Color(0xFF2F67D8);
  static const ink = Color(0xFF2B2520);
}

ThemeData buildHoopTraceTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: HoopTraceColors.orange,
    brightness: Brightness.light,
    primary: HoopTraceColors.orange,
    surface: HoopTraceColors.offWhite,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: HoopTraceColors.offWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: HoopTraceColors.offWhite,
      foregroundColor: HoopTraceColors.ink,
      elevation: 0,
      centerTitle: false,
    ),
  );
}
```

- [ ] **Step 5: Add route shell and temporary home page**

Create `lib/app/app_router.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

GoRouter buildAppRouter() {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const _HomePageShell(),
      ),
    ],
  );
}

class _HomePageShell extends StatelessWidget {
  const _HomePageShell();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () {},
                child: const Text('开始计分'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {},
                child: const Text('复盘历史'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

Create `lib/app/hoop_trace_app.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hooptrace/app/app_router.dart';
import 'package:hooptrace/app/app_theme.dart';

class HoopTraceApp extends StatelessWidget {
  const HoopTraceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'HoopTrace',
      theme: buildHoopTraceTheme(),
      routerConfig: buildAppRouter(),
      debugShowCheckedModeBanner: false,
    );
  }
}
```

Create `lib/app/orientation_shell.dart`:

```dart
import 'package:flutter/material.dart';

enum HoopTraceOrientationMode { portraitFriendly, landscapeRequired }

class OrientationShell extends StatelessWidget {
  const OrientationShell({
    required this.mode,
    required this.child,
    super.key,
  });

  final HoopTraceOrientationMode mode;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}
```

Modify `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hooptrace/app/hoop_trace_app.dart';

void main() {
  runApp(const HoopTraceApp());
}
```

- [ ] **Step 6: Run app-shell verification**

Run:

```powershell
dart format lib test
flutter test test/app/app_shell_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add l10n.yaml lib/app lib/main.dart test/app
git commit -m "feat: add app shell and theme"
```

## Task 3: Domain Entities And Value Objects

**Files:**
- Create: `lib/core/domain/value_objects/team_side.dart`
- Create: `lib/core/domain/value_objects/court_point.dart`
- Create: `lib/core/domain/entities/player.dart`
- Create: `lib/core/domain/entities/rule_template.dart`
- Create: `lib/core/domain/entities/match.dart`
- Create: `lib/core/domain/entities/match_event.dart`
- Create: `lib/core/domain/entities/shot_location.dart`
- Create: `lib/core/domain/entities/possession_segment.dart`
- Test: `test/core/domain/domain_entities_test.dart`

- [ ] **Step 1: Write failing domain tests**

Create `test/core/domain/domain_entities_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/core/domain/entities/match_event.dart';
import 'package:hooptrace/core/domain/value_objects/court_point.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

void main() {
  test('court point rejects coordinates outside normalized court bounds', () {
    expect(() => CourtPoint(x: -0.1, y: 0.5), throwsArgumentError);
    expect(() => CourtPoint(x: 0.5, y: 1.1), throwsArgumentError);
    expect(const CourtPoint(x: 0.25, y: 0.75).x, 0.25);
  });

  test('score event carries side and points', () {
    final event = MatchEvent.score(
      id: 'event-1',
      matchId: 'match-1',
      side: TeamSide.red,
      points: 2,
      occurredAt: DateTime.utc(2026, 5, 12, 12),
    );

    expect(event.side, TeamSide.red);
    expect(event.points, 2);
    expect(event.type, MatchEventType.score);
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/core/domain/domain_entities_test.dart
```

Expected: FAIL because domain files do not exist.

- [ ] **Step 3: Add value objects**

Create `lib/core/domain/value_objects/team_side.dart`:

```dart
enum TeamSide {
  red,
  blue;

  TeamSide get opponent => this == TeamSide.red ? TeamSide.blue : TeamSide.red;
}
```

Create `lib/core/domain/value_objects/court_point.dart`:

```dart
class CourtPoint {
  const CourtPoint({
    required this.x,
    required this.y,
  }) {
    if (x < 0 || x > 1 || y < 0 || y > 1) {
      throw ArgumentError('CourtPoint coordinates must be normalized.');
    }
  }

  final double x;
  final double y;

  Map<String, Object?> toJson() => {'x': x, 'y': y};

  static CourtPoint fromJson(Map<String, Object?> json) {
    return CourtPoint(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
    );
  }
}
```

- [ ] **Step 4: Add entity model files**

Create `lib/core/domain/entities/match_event.dart`:

```dart
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

enum MatchEventType {
  score,
  miss,
  foul,
  reward,
  pause,
  interruption,
  note,
  custom,
}

class MatchEvent {
  const MatchEvent({
    required this.id,
    required this.matchId,
    required this.type,
    required this.side,
    required this.points,
    required this.occurredAt,
    this.note,
    this.customType,
    this.isDeleted = false,
  });

  factory MatchEvent.score({
    required String id,
    required String matchId,
    required TeamSide side,
    required int points,
    required DateTime occurredAt,
  }) {
    if (points <= 0) {
      throw ArgumentError('Score points must be positive.');
    }
    return MatchEvent(
      id: id,
      matchId: matchId,
      type: MatchEventType.score,
      side: side,
      points: points,
      occurredAt: occurredAt,
    );
  }

  final String id;
  final String matchId;
  final MatchEventType type;
  final TeamSide? side;
  final int points;
  final DateTime occurredAt;
  final String? note;
  final String? customType;
  final bool isDeleted;
}
```

Create the remaining entity files as minimal immutable classes:

```dart
// lib/core/domain/entities/player.dart
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

class Player {
  const Player({
    required this.id,
    required this.nickname,
    required this.createdAt,
    this.preferredSide,
    this.note,
  });

  final String id;
  final String nickname;
  final DateTime createdAt;
  final TeamSide? preferredSide;
  final String? note;
}
```

```dart
// lib/core/domain/entities/rule_template.dart
class RuleTemplate {
  const RuleTemplate({
    required this.id,
    required this.name,
    required this.scoreButtons,
    this.targetScore,
    this.timeLimitSeconds,
    this.winByTwo = false,
    this.foulLimit,
    this.customEventTypes = const [],
  });

  final String id;
  final String name;
  final List<int> scoreButtons;
  final int? targetScore;
  final int? timeLimitSeconds;
  final bool winByTwo;
  final int? foulLimit;
  final List<String> customEventTypes;
}
```

```dart
// lib/core/domain/entities/match.dart
import 'package:hooptrace/core/domain/entities/rule_template.dart';

enum MatchStatus { draft, active, finished, archived }

class Match {
  const Match({
    required this.id,
    required this.createdAt,
    required this.status,
    required this.redName,
    required this.blueName,
    required this.ruleTemplateSnapshot,
    this.startedAt,
    this.endedAt,
    this.timerEnabled = false,
    this.note,
  });

  final String id;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final MatchStatus status;
  final String redName;
  final String blueName;
  final RuleTemplate ruleTemplateSnapshot;
  final bool timerEnabled;
  final String? note;
}
```

```dart
// lib/core/domain/entities/shot_location.dart
import 'package:hooptrace/core/domain/value_objects/court_point.dart';

class ShotLocation {
  const ShotLocation({
    required this.id,
    required this.matchId,
    required this.eventId,
    required this.point,
    required this.isConfirmed,
  });

  final String id;
  final String matchId;
  final String eventId;
  final CourtPoint point;
  final bool isConfirmed;
}
```

```dart
// lib/core/domain/entities/possession_segment.dart
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

class PossessionSegment {
  const PossessionSegment({
    required this.id,
    required this.matchId,
    required this.side,
    required this.startedAtEventId,
    this.endedAtEventId,
    this.reason,
  });

  final String id;
  final String matchId;
  final TeamSide side;
  final String startedAtEventId;
  final String? endedAtEventId;
  final String? reason;
}
```

- [ ] **Step 5: Verify domain tests**

Run:

```powershell
dart format lib/core/domain test/core/domain
flutter test test/core/domain/domain_entities_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/domain test/core/domain
git commit -m "feat: add match domain entities"
```

## Task 4: Scoring Reducer And Rule Engine

**Files:**
- Create: `lib/core/domain/scoring/score_state.dart`
- Create: `lib/core/domain/scoring/scoring_reducer.dart`
- Create: `lib/core/domain/rules/rule_engine.dart`
- Test: `test/core/domain/scoring_reducer_test.dart`
- Test: `test/core/domain/rule_engine_test.dart`

- [ ] **Step 1: Write scoring reducer tests**

Create `test/core/domain/scoring_reducer_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/core/domain/entities/match_event.dart';
import 'package:hooptrace/core/domain/scoring/scoring_reducer.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

void main() {
  test('score is derived from non-deleted score events', () {
    final events = [
      MatchEvent.score(
        id: 'r1',
        matchId: 'm1',
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026),
      ),
      MatchEvent.score(
        id: 'b1',
        matchId: 'm1',
        side: TeamSide.blue,
        points: 3,
        occurredAt: DateTime.utc(2026),
      ),
    ];

    final score = ScoringReducer().reduce(events);

    expect(score.redScore, 2);
    expect(score.blueScore, 3);
  });
}
```

Create `test/core/domain/rule_engine_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/core/domain/entities/rule_template.dart';
import 'package:hooptrace/core/domain/rules/rule_engine.dart';
import 'package:hooptrace/core/domain/scoring/score_state.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

void main() {
  test('target score creates a non-blocking match point hint', () {
    const template = RuleTemplate(
      id: 'standard-11',
      name: '11 points',
      scoreButtons: [1, 2, 3],
      targetScore: 11,
      winByTwo: true,
    );

    final hints = RuleEngine().evaluate(
      template: template,
      score: const ScoreState(redScore: 10, blueScore: 8),
      scoringSide: TeamSide.red,
      scoringPoints: 1,
    );

    expect(hints.any((hint) => hint.type == RuleHintType.matchPoint), isTrue);
    expect(hints.every((hint) => hint.isBlocking == false), isTrue);
  });
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/core/domain/scoring_reducer_test.dart test/core/domain/rule_engine_test.dart
```

Expected: FAIL because reducer and rule engine do not exist.

- [ ] **Step 3: Add score state and reducer**

Create `lib/core/domain/scoring/score_state.dart`:

```dart
class ScoreState {
  const ScoreState({
    required this.redScore,
    required this.blueScore,
  });

  const ScoreState.zero() : redScore = 0, blueScore = 0;

  final int redScore;
  final int blueScore;
}
```

Create `lib/core/domain/scoring/scoring_reducer.dart`:

```dart
import 'package:hooptrace/core/domain/entities/match_event.dart';
import 'package:hooptrace/core/domain/scoring/score_state.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

class ScoringReducer {
  ScoreState reduce(Iterable<MatchEvent> events) {
    var red = 0;
    var blue = 0;

    for (final event in events) {
      if (event.isDeleted || event.type != MatchEventType.score) {
        continue;
      }
      switch (event.side) {
        case TeamSide.red:
          red += event.points;
        case TeamSide.blue:
          blue += event.points;
        case null:
          break;
      }
    }

    return ScoreState(redScore: red, blueScore: blue);
  }
}
```

- [ ] **Step 4: Add rule engine**

Create `lib/core/domain/rules/rule_engine.dart`:

```dart
import 'package:hooptrace/core/domain/entities/rule_template.dart';
import 'package:hooptrace/core/domain/scoring/score_state.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

enum RuleHintType { matchPoint, targetReached, winByTwoRequired, possessionChange }

class RuleHint {
  const RuleHint({
    required this.type,
    required this.message,
    this.isBlocking = false,
  });

  final RuleHintType type;
  final String message;
  final bool isBlocking;
}

class RuleEngine {
  List<RuleHint> evaluate({
    required RuleTemplate template,
    required ScoreState score,
    required TeamSide scoringSide,
    required int scoringPoints,
  }) {
    final targetScore = template.targetScore;
    if (targetScore == null) {
      return const [];
    }

    final newRed = score.redScore + (scoringSide == TeamSide.red ? scoringPoints : 0);
    final newBlue = score.blueScore + (scoringSide == TeamSide.blue ? scoringPoints : 0);
    final sideScore = scoringSide == TeamSide.red ? newRed : newBlue;
    final opponentScore = scoringSide == TeamSide.red ? newBlue : newRed;
    final hints = <RuleHint>[];

    if (sideScore == targetScore - 1) {
      hints.add(const RuleHint(
        type: RuleHintType.matchPoint,
        message: '赛点',
      ));
    }

    if (sideScore >= targetScore) {
      if (template.winByTwo && sideScore - opponentScore < 2) {
        hints.add(const RuleHint(
          type: RuleHintType.winByTwoRequired,
          message: '需要领先 2 分',
        ));
      } else {
        hints.add(const RuleHint(
          type: RuleHintType.targetReached,
          message: '目标分已达到',
        ));
      }
    }

    return hints;
  }
}
```

- [ ] **Step 5: Verify scoring and rules**

Run:

```powershell
dart format lib/core/domain test/core/domain
flutter test test/core/domain/scoring_reducer_test.dart test/core/domain/rule_engine_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/domain test/core/domain
git commit -m "feat: add scoring reducer and rule hints"
```

## Task 5: Audit Models And Event Mutation Policies

**Files:**
- Create: `lib/core/audit/audit_diff.dart`
- Create: `lib/core/audit/audit_log_entry.dart`
- Create: `lib/core/domain/entities/event_mutation.dart`
- Test: `test/core/audit/audit_log_test.dart`

- [ ] **Step 1: Write audit test**

Create `test/core/audit/audit_log_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/core/audit/audit_diff.dart';
import 'package:hooptrace/core/audit/audit_log_entry.dart';

void main() {
  test('audit entry stores before and after values', () {
    final entry = AuditLogEntry(
      id: 'audit-1',
      matchId: 'match-1',
      targetId: 'event-1',
      action: AuditAction.edit,
      createdAt: DateTime.utc(2026),
      diff: const AuditDiff(
        before: {'points': 2},
        after: {'points': 3},
      ),
    );

    expect(entry.diff.before['points'], 2);
    expect(entry.diff.after['points'], 3);
    expect(entry.action, AuditAction.edit);
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/core/audit/audit_log_test.dart
```

Expected: FAIL because audit models do not exist.

- [ ] **Step 3: Add audit models**

Create `lib/core/audit/audit_diff.dart`:

```dart
class AuditDiff {
  const AuditDiff({
    required this.before,
    required this.after,
  });

  final Map<String, Object?> before;
  final Map<String, Object?> after;
}
```

Create `lib/core/audit/audit_log_entry.dart`:

```dart
import 'package:hooptrace/core/audit/audit_diff.dart';

enum AuditAction { create, undo, edit, delete, import, restore }

class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.matchId,
    required this.targetId,
    required this.action,
    required this.createdAt,
    required this.diff,
    this.reason,
  });

  final String id;
  final String matchId;
  final String targetId;
  final AuditAction action;
  final DateTime createdAt;
  final AuditDiff diff;
  final String? reason;
}
```

Create `lib/core/domain/entities/event_mutation.dart`:

```dart
enum EventMutationType { create, undo, edit, delete }

class EventMutation {
  const EventMutation({
    required this.type,
    required this.eventId,
    this.reason,
  });

  final EventMutationType type;
  final String eventId;
  final String? reason;
}
```

- [ ] **Step 4: Verify audit models**

Run:

```powershell
dart format lib/core/audit lib/core/domain/entities test/core/audit
flutter test test/core/audit/audit_log_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 5: Commit**

```powershell
git add lib/core/audit lib/core/domain/entities/event_mutation.dart test/core/audit
git commit -m "feat: add audit model"
```

## Task 6: Drift Database And Repositories

**Files:**
- Create: `lib/core/data/app_database.dart`
- Create: `lib/core/data/app_database_provider.dart`
- Create: `lib/core/data/migrations.dart`
- Create: `lib/core/data/repositories/match_repository.dart`
- Create: `lib/core/data/repositories/player_repository.dart`
- Create: `lib/core/data/repositories/rule_template_repository.dart`
- Test: `test/core/data/match_repository_test.dart`

- [ ] **Step 1: Write repository round-trip test**

Create `test/core/data/match_repository_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/core/data/app_database.dart';
import 'package:hooptrace/core/data/repositories/match_repository.dart';
import 'package:hooptrace/core/domain/entities/match_event.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

void main() {
  test('match repository stores and reads score events', () async {
    final database = AppDatabase.inMemory();
    addTearDown(database.close);

    final repository = MatchRepository(database);
    await repository.createMinimalMatch(
      id: 'match-1',
      redName: 'Red',
      blueName: 'Blue',
      createdAt: DateTime.utc(2026),
    );
    await repository.addEvent(MatchEvent.score(
      id: 'event-1',
      matchId: 'match-1',
      side: TeamSide.red,
      points: 2,
      occurredAt: DateTime.utc(2026),
    ));

    final events = await repository.watchEvents('match-1').first;
    expect(events.single.points, 2);
    expect(events.single.side, TeamSide.red);
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/core/data/match_repository_test.dart
```

Expected: FAIL because database and repository do not exist.

- [ ] **Step 3: Add Drift database tables**

Create `lib/core/data/app_database.dart` with tables for matches, events, shot locations, players, rule templates, possession segments, audit logs, and settings. Use text columns for enum names and JSON snapshots.

Minimum table skeleton:

```dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'app_database.g.dart';

class Matches extends Table {
  TextColumn get id => text()();
  TextColumn get redName => text()();
  TextColumn get blueName => text()();
  TextColumn get status => text()();
  TextColumn get ruleTemplateJson => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get startedAt => dateTime().nullable()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  BoolColumn get timerEnabled => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class MatchEvents extends Table {
  TextColumn get id => text()();
  TextColumn get matchId => text().references(Matches, #id)();
  TextColumn get type => text()();
  TextColumn get side => text().nullable()();
  IntColumn get points => integer().withDefault(const Constant(0))();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get note => text().nullable()();
  TextColumn get customType => text().nullable()();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class ShotLocations extends Table {
  TextColumn get id => text()();
  TextColumn get matchId => text().references(Matches, #id)();
  TextColumn get eventId => text().references(MatchEvents, #id)();
  RealColumn get x => real()();
  RealColumn get y => real()();
  BoolColumn get isConfirmed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DriftDatabase(tables: [Matches, MatchEvents, ShotLocations])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  AppDatabase.inMemory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}
```

- [ ] **Step 4: Add repository mapping**

Create `lib/core/data/repositories/match_repository.dart` with `createMinimalMatch`, `addEvent`, and `watchEvents`. Convert enum values with `.name`.

Core methods:

```dart
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:hooptrace/core/data/app_database.dart';
import 'package:hooptrace/core/domain/entities/match_event.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

class MatchRepository {
  MatchRepository(this._database);

  final AppDatabase _database;

  Future<void> createMinimalMatch({
    required String id,
    required String redName,
    required String blueName,
    required DateTime createdAt,
  }) {
    return _database.into(_database.matches).insert(
      MatchesCompanion.insert(
        id: id,
        redName: redName,
        blueName: blueName,
        status: 'active',
        ruleTemplateJson: jsonEncode({
          'id': 'free',
          'name': '自由计分',
          'scoreButtons': [1, 2, 3],
        }),
        createdAt: createdAt,
      ),
    );
  }

  Future<void> addEvent(MatchEvent event) {
    return _database.into(_database.matchEvents).insert(
      MatchEventsCompanion.insert(
        id: event.id,
        matchId: event.matchId,
        type: event.type.name,
        side: Value(event.side?.name),
        points: Value(event.points),
        occurredAt: event.occurredAt,
        note: Value(event.note),
        customType: Value(event.customType),
        isDeleted: Value(event.isDeleted),
      ),
    );
  }

  Stream<List<MatchEvent>> watchEvents(String matchId) {
    final query = _database.select(_database.matchEvents)
      ..where((event) => event.matchId.equals(matchId));
    return query.watch().map((rows) {
      return rows.map((row) {
        return MatchEvent(
          id: row.id,
          matchId: row.matchId,
          type: MatchEventType.values.byName(row.type),
          side: row.side == null ? null : TeamSide.values.byName(row.side!),
          points: row.points,
          occurredAt: row.occurredAt,
          note: row.note,
          customType: row.customType,
          isDeleted: row.isDeleted,
        );
      }).toList();
    });
  }
}
```

- [ ] **Step 5: Generate Drift code**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
```

Expected: `lib/core/data/app_database.g.dart` is generated.

- [ ] **Step 6: Verify persistence**

Run:

```powershell
dart format lib/core/data test/core/data
flutter test test/core/data/match_repository_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add lib/core/data test/core/data
git commit -m "feat: add local match database"
```

## Task 7: Pre-Game Setup And Match Creation

**Files:**
- Create: `lib/features/pregame/pregame_page.dart`
- Create: `lib/features/pregame/pregame_controller.dart`
- Modify: `lib/app/app_router.dart`
- Test: `test/features/pregame/pregame_page_test.dart`

- [ ] **Step 1: Write pre-game widget test**

Create `test/features/pregame/pregame_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/features/pregame/pregame_page.dart';

void main() {
  testWidgets('pre-game page exposes fast start and advanced settings', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PregamePage()));

    expect(find.text('红方'), findsOneWidget);
    expect(find.text('蓝方'), findsOneWidget);
    expect(find.text('规则模板'), findsOneWidget);
    expect(find.text('高级设置'), findsOneWidget);
    expect(find.text('开始比赛'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/features/pregame/pregame_page_test.dart
```

Expected: FAIL because `PregamePage` does not exist.

- [ ] **Step 3: Add pre-game controller**

Create `lib/features/pregame/pregame_controller.dart`:

```dart
class PregameState {
  const PregameState({
    this.redName = '红方',
    this.blueName = '蓝方',
    this.ruleTemplateId = 'free',
    this.timerEnabled = false,
    this.advancedExpanded = false,
  });

  final String redName;
  final String blueName;
  final String ruleTemplateId;
  final bool timerEnabled;
  final bool advancedExpanded;
}
```

- [ ] **Step 4: Add pre-game page**

Create `lib/features/pregame/pregame_page.dart`:

```dart
import 'package:flutter/material.dart';

class PregamePage extends StatelessWidget {
  const PregamePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('赛前设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const TextField(
            decoration: InputDecoration(labelText: '红方'),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(labelText: '蓝方'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: 'free',
            decoration: const InputDecoration(labelText: '规则模板'),
            items: const [
              DropdownMenuItem(value: 'free', child: Text('自由计分')),
              DropdownMenuItem(value: 'eleven', child: Text('11 分')),
            ],
            onChanged: (_) {},
          ),
          const SwitchListTile(
            value: false,
            onChanged: null,
            title: Text('计时'),
          ),
          ExpansionTile(
            title: const Text('高级设置'),
            children: const [
              ListTile(title: Text('目标分')),
              ListTile(title: Text('赢 2 分')),
              ListTile(title: Text('犯规规则')),
              ListTile(title: Text('自定义事件')),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () {},
            child: const Text('开始比赛'),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Add route**

Modify `lib/app/app_router.dart` so `/pregame` opens `PregamePage` and the home start button calls `context.go('/pregame')`.

- [ ] **Step 6: Verify pre-game**

Run:

```powershell
dart format lib/features/pregame lib/app test/features/pregame
flutter test test/features/pregame/pregame_page_test.dart test/app/app_shell_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/pregame lib/app test/features/pregame
git commit -m "feat: add pre-game setup"
```

## Task 8: Court-First Scoring Page And Painter

**Files:**
- Create: `lib/features/scoring/scoring_page.dart`
- Create: `lib/features/scoring/scoring_controller.dart`
- Create: `lib/features/scoring/widgets/court_painter.dart`
- Create: `lib/features/scoring/widgets/court_view.dart`
- Create: `lib/features/scoring/widgets/score_side_panel.dart`
- Create: `lib/features/scoring/widgets/pending_location_bar.dart`
- Modify: `lib/app/app_router.dart`
- Test: `test/features/scoring/scoring_page_test.dart`

- [ ] **Step 1: Write scoring page widget test**

Create `test/features/scoring/scoring_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/features/scoring/scoring_page.dart';

void main() {
  testWidgets('scoring page shows court-first landscape controls', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ScoringPage(matchId: 'match-1')));

    expect(find.text('蓝方'), findsOneWidget);
    expect(find.text('红方'), findsOneWidget);
    expect(find.text('+1'), findsNWidgets(2));
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('+3'), findsNWidgets(2));
    expect(find.byType(CustomPaint), findsWidgets);
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/features/scoring/scoring_page_test.dart
```

Expected: FAIL because scoring page does not exist.

- [ ] **Step 3: Add court painter**

Create `lib/features/scoring/widgets/court_painter.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:hooptrace/app/app_theme.dart';

class CourtPainter extends CustomPainter {
  const CourtPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = HoopTraceColors.ink.withValues(alpha: 0.62)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fillPaint = Paint()
      ..color = HoopTraceColors.offWhite
      ..style = PaintingStyle.fill;

    final court = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(8),
    );
    canvas.drawRRect(court, fillPaint);
    canvas.drawRRect(court, linePaint);

    final centerX = size.width / 2;
    canvas.drawLine(Offset(centerX, 0), Offset(centerX, size.height), linePaint);
    canvas.drawCircle(Offset(centerX, size.height * 0.18), size.shortestSide * 0.12, linePaint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centerX, size.height * 0.18),
        width: size.width * 0.18,
        height: size.height * 0.24,
      ),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CourtPainter oldDelegate) => false;
}
```

- [ ] **Step 4: Add scoring widgets**

Create `CourtView`, `ScoreSidePanel`, and `PendingLocationBar` as focused widgets. `CourtView` wraps `CustomPaint`; `ScoreSidePanel` receives side label and callbacks; `PendingLocationBar` shows confirm, skip, and undo.

Minimum `CourtView`:

```dart
import 'package:flutter/material.dart';
import 'package:hooptrace/features/scoring/widgets/court_painter.dart';

class CourtView extends StatelessWidget {
  const CourtView({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: CustomPaint(
        painter: CourtPainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}
```

- [ ] **Step 5: Add scoring page layout**

Create `lib/features/scoring/scoring_page.dart` with a landscape-first row:

```dart
import 'package:flutter/material.dart';
import 'package:hooptrace/features/scoring/widgets/court_view.dart';
import 'package:hooptrace/features/scoring/widgets/score_side_panel.dart';

class ScoringPage extends StatelessWidget {
  const ScoringPage({
    required this.matchId,
    super.key,
  });

  final String matchId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 48,
              child: Center(child: Text('00:00')),
            ),
            Expanded(
              child: Row(
                children: const [
                  SizedBox(
                    width: 112,
                    child: ScoreSidePanel(label: '蓝方'),
                  ),
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CourtView(),
                    ),
                  ),
                  SizedBox(
                    width: 112,
                    child: ScoreSidePanel(label: '红方'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Verify scoring layout**

Run:

```powershell
dart format lib/features/scoring test/features/scoring
flutter test test/features/scoring/scoring_page_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/scoring lib/app test/features/scoring
git commit -m "feat: add court-first scoring screen"
```

## Task 9: Scoring Events And Pending Shot Location Flow

**Files:**
- Modify: `lib/features/scoring/scoring_controller.dart`
- Modify: `lib/features/scoring/scoring_page.dart`
- Modify: `lib/features/scoring/widgets/court_view.dart`
- Modify: `lib/features/scoring/widgets/pending_location_bar.dart`
- Test: `test/features/scoring/scoring_controller_test.dart`
- Test: `test/features/scoring/pending_location_flow_test.dart`

- [ ] **Step 1: Write controller tests**

Create `test/features/scoring/scoring_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';
import 'package:hooptrace/features/scoring/scoring_controller.dart';

void main() {
  test('adding a score creates a pending location', () {
    final controller = ScoringController(matchId: 'match-1');

    controller.addScore(side: TeamSide.red, points: 2);

    expect(controller.state.score.redScore, 2);
    expect(controller.state.pendingLocation?.side, TeamSide.red);
    expect(controller.state.pendingLocation?.points, 2);
  });
}
```

- [ ] **Step 2: Run test and verify failure**

Run:

```powershell
flutter test test/features/scoring/scoring_controller_test.dart
```

Expected: FAIL because controller behavior is missing.

- [ ] **Step 3: Implement scoring controller state**

Implement a plain Dart controller first. Riverpod can wrap it after behavior is stable.

Required state fields:

- `matchId`
- `events`
- `score`
- `pendingLocation`
- `ruleHints`

Required methods:

- `addScore({required TeamSide side, required int points})`
- `confirmPendingLocation(CourtPoint point)`
- `skipPendingLocation()`
- `undoLastEvent()`

- [ ] **Step 4: Add pending location UI**

Update `ScoringPage` so tapping `+1`, `+2`, or `+3` calls controller methods and shows `PendingLocationBar` when a pending location exists.

The pending bar must show:

- `确认落点`
- `跳过落点`
- `撤销`

- [ ] **Step 5: Add court drag behavior**

Update `CourtView` to receive a pending point and `ValueChanged<CourtPoint>` callback. Convert local drag positions to normalized `CourtPoint`.

Coordinate conversion rule:

```dart
CourtPoint pointFromLocal(Offset local, Size size) {
  return CourtPoint(
    x: (local.dx / size.width).clamp(0, 1).toDouble(),
    y: (local.dy / size.height).clamp(0, 1).toDouble(),
  );
}
```

- [ ] **Step 6: Verify pending flow**

Run:

```powershell
dart format lib/features/scoring test/features/scoring
flutter test test/features/scoring
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/scoring test/features/scoring
git commit -m "feat: add scoring location flow"
```

## Task 10: Current-Match Replay And History

**Files:**
- Create: `lib/features/replay/replay_page.dart`
- Create: `lib/features/replay/replay_controller.dart`
- Create: `lib/features/replay/widgets/replay_timeline_sheet.dart`
- Create: `lib/features/replay/widgets/replay_filter_bar.dart`
- Create: `lib/features/history/history_page.dart`
- Create: `lib/features/history/history_controller.dart`
- Modify: `lib/app/app_router.dart`
- Test: `test/features/replay/replay_page_test.dart`
- Test: `test/features/history/history_page_test.dart`

- [ ] **Step 1: Write replay and history tests**

Create tests asserting:

- Replay page shows final or current score.
- Replay page shows read-only shot chart.
- History page lists match date, red/blue names, score, template, and duration.

Use this minimum replay test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/features/replay/replay_page.dart';

void main() {
  testWidgets('replay page exposes timeline and filters', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ReplayPage(matchId: 'match-1')));

    expect(find.text('总览历史'), findsOneWidget);
    expect(find.text('筛选'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/features/replay test/features/history
```

Expected: FAIL because pages do not exist.

- [ ] **Step 3: Implement replay read-only page**

Use the existing `CourtView` for shot chart rendering. Replay page must not expose drag handles until edit mode is introduced.

- [ ] **Step 4: Implement history list**

Create `HistoryPage` with list rows showing:

- Date.
- Red and blue names.
- Score.
- Winner.
- Rule template name.
- Match duration.
- Location completeness indicator.

- [ ] **Step 5: Add routes**

Add:

- `/history`
- `/matches/:matchId/replay`

Home replay-history button routes to `/history`.

- [ ] **Step 6: Verify replay and history**

Run:

```powershell
dart format lib/features/replay lib/features/history lib/app test/features
flutter test test/features/replay test/features/history test/app/app_shell_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/replay lib/features/history lib/app test/features
git commit -m "feat: add replay and match history"
```

## Task 11: Rule Templates And Possession Hints

**Files:**
- Create: `lib/features/rules/rule_template_list_page.dart`
- Create: `lib/features/rules/rule_template_editor_page.dart`
- Modify: `lib/core/domain/rules/rule_engine.dart`
- Modify: `lib/core/domain/entities/possession_segment.dart`
- Modify: `lib/core/data/repositories/rule_template_repository.dart`
- Test: `test/features/rules/rule_template_page_test.dart`
- Test: `test/core/domain/possession_hint_test.dart`

- [ ] **Step 1: Write tests**

Test that:

- Built-in templates include free scoring and 11-point one-on-one.
- Custom template can configure score buttons.
- Possession hint is non-blocking after configured scoring events.

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/features/rules test/core/domain/possession_hint_test.dart
```

Expected: FAIL because template UI and possession hint behavior are missing.

- [ ] **Step 3: Implement built-in templates**

Create built-ins:

- `free`: no target, buttons `[1, 2, 3]`.
- `eleven_win_by_two`: target 11, win by two, buttons `[1, 2, 3]`.
- `twenty_one`: target 21, buttons `[1, 2, 3]`.
- `timed_ten`: 10 minute limit, buttons `[1, 2, 3]`.

- [ ] **Step 4: Implement rules pages**

Rule list shows built-in and custom templates. Editor supports target score, time limit, win-by-two, foul limit, score buttons, possession hint, and custom event types.

- [ ] **Step 5: Verify rules**

Run:

```powershell
dart format lib/features/rules lib/core/domain lib/core/data test/features/rules test/core/domain
flutter test test/features/rules test/core/domain/possession_hint_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 6: Commit**

```powershell
git add lib/features/rules lib/core/domain lib/core/data test/features/rules test/core/domain
git commit -m "feat: add rule templates and possession hints"
```

## Task 12: Edit Mode And Audit History

**Files:**
- Modify: `lib/features/replay/replay_controller.dart`
- Modify: `lib/features/replay/replay_page.dart`
- Modify: `lib/core/data/repositories/match_repository.dart`
- Modify: `lib/core/data/app_database.dart`
- Test: `test/features/replay/edit_mode_test.dart`
- Test: `test/core/data/audit_repository_test.dart`

- [ ] **Step 1: Write edit-mode tests**

Test that:

- Moving a shot location creates an audit entry with before and after coordinates.
- Deleting an event marks it deleted rather than removing it silently.
- Replay stays read-only until edit mode is enabled.

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/features/replay/edit_mode_test.dart test/core/data/audit_repository_test.dart
```

Expected: FAIL because edit and audit persistence behavior are missing.

- [ ] **Step 3: Add audit database table**

Extend `AppDatabase` with `AuditLogs` table:

```dart
class AuditLogs extends Table {
  TextColumn get id => text()();
  TextColumn get matchId => text().references(Matches, #id)();
  TextColumn get targetId => text()();
  TextColumn get action => text()();
  TextColumn get beforeJson => text()();
  TextColumn get afterJson => text()();
  TextColumn get reason => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
```

Increase `schemaVersion` to 2 and add a migration in `lib/core/data/migrations.dart`.

- [ ] **Step 4: Implement edit operations**

Repository methods:

- `moveShotLocation({required String locationId, required CourtPoint point, String? reason})`
- `softDeleteEvent({required String eventId, String? reason})`
- `updateEventNote({required String eventId, required String note, String? reason})`

Each method writes an audit entry in the same database transaction.

- [ ] **Step 5: Add replay edit UI**

Replay page shows an edit toggle. In edit mode:

- Existing markers become selectable.
- Selected marker can be moved.
- Event details sheet exposes delete, note edit, and reason input.

- [ ] **Step 6: Verify edit mode**

Run:

```powershell
dart run build_runner build --delete-conflicting-outputs
dart format lib/features/replay lib/core/data test/features/replay test/core/data
flutter test test/features/replay/edit_mode_test.dart test/core/data/audit_repository_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/replay lib/core/data test/features/replay test/core/data
git commit -m "feat: add replay edit mode and audit history"
```

## Task 13: Players, Settings, And Project Details

**Files:**
- Create: `lib/features/players/player_list_page.dart`
- Create: `lib/features/players/player_editor_page.dart`
- Create: `lib/features/settings/settings_page.dart`
- Create: `lib/features/project/project_details_page.dart`
- Create: `lib/features/project/external_link_launcher.dart`
- Modify: `lib/app/app_router.dart`
- Modify: `lib/core/data/repositories/player_repository.dart`
- Test: `test/features/players/player_pages_test.dart`
- Test: `test/features/settings/settings_page_test.dart`
- Test: `test/features/project/project_details_page_test.dart`

- [ ] **Step 1: Write page tests**

Tests must assert:

- Player list exposes create and edit flows.
- Settings page exposes default template, theme, backup, privacy, diagnostics.
- Project page states permanent free and open-source commitment.

Minimum project details test:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/features/project/project_details_page.dart';

void main() {
  testWidgets('project details state open-source and local data principles', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ProjectDetailsPage()));

    expect(find.text('永久免费'), findsOneWidget);
    expect(find.text('永久开源'), findsOneWidget);
    expect(find.text('本地离线'), findsOneWidget);
    expect(find.text('GitHub'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/features/players test/features/settings test/features/project
```

Expected: FAIL because pages do not exist.

- [ ] **Step 3: Implement player pages**

Player fields:

- Nickname.
- Preferred side.
- Notes.

Player page must allow temporary players to remain valid for matches.

- [ ] **Step 4: Implement settings page**

Settings sections:

- Defaults.
- Appearance.
- Statistics.
- Backup and export.
- Privacy.
- Experimental features.
- Developer diagnostics.
- Project details.

- [ ] **Step 5: Implement project details page**

Include text:

- `永久免费`
- `永久开源`
- `本地离线`
- `不会上传个人数据`
- `GitHub`
- `License`
- `贡献指南`
- `问题反馈`

Add `lib/features/project/external_link_launcher.dart`:

```dart
import 'package:url_launcher/url_launcher.dart';

class ExternalLinkLauncher {
  Future<bool> open(String url) {
    final uri = Uri.parse(url);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
```

Project detail buttons use `ExternalLinkLauncher` for:

- GitHub repository.
- License.
- Contribution guide.
- Issue feedback.

- [ ] **Step 6: Verify**

Run:

```powershell
dart format lib/features/players lib/features/settings lib/features/project test/features
flutter test test/features/players test/features/settings test/features/project
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 7: Commit**

```powershell
git add lib/features/players lib/features/settings lib/features/project lib/app test/features
git commit -m "feat: add players settings and project pages"
```

## Task 14: Analytics

**Files:**
- Create: `lib/core/domain/analytics/match_analytics.dart`
- Create: `lib/core/domain/analytics/match_analytics_calculator.dart`
- Modify: `lib/features/replay/replay_controller.dart`
- Test: `test/core/domain/match_analytics_test.dart`

- [ ] **Step 1: Write analytics tests**

Create tests for:

- Scoring flow.
- Lead changes.
- Largest lead.
- Shooting percentage from made and missed events.
- Key possessions for tie, overtake, match point, and scoring runs.

Example test:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hooptrace/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hooptrace/core/domain/entities/match_event.dart';
import 'package:hooptrace/core/domain/value_objects/team_side.dart';

void main() {
  test('analytics calculates largest lead', () {
    final events = [
      MatchEvent.score(
        id: 'r1',
        matchId: 'm1',
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026),
      ),
      MatchEvent.score(
        id: 'r2',
        matchId: 'm1',
        side: TeamSide.red,
        points: 3,
        occurredAt: DateTime.utc(2026, 1, 1, 0, 1),
      ),
      MatchEvent.score(
        id: 'b1',
        matchId: 'm1',
        side: TeamSide.blue,
        points: 2,
        occurredAt: DateTime.utc(2026, 1, 1, 0, 2),
      ),
    ];

    final analytics = MatchAnalyticsCalculator().calculate(events);

    expect(analytics.largestLeadPoints, 5);
    expect(analytics.largestLeadSide, TeamSide.red);
  });
}
```

- [ ] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/core/domain/match_analytics_test.dart
```

Expected: FAIL because analytics code does not exist.

- [ ] **Step 3: Implement analytics models and calculator**

`MatchAnalytics` fields:

- `scoringFlow`
- `largestLeadSide`
- `largestLeadPoints`
- `leadChanges`
- `madeShotCount`
- `missedShotCount`
- `shootingPercentage`
- `keyPossessions`

- [ ] **Step 4: Surface analytics in replay**

Replay page shows:

- Score flow entry.
- Lead change summary.
- Shot percentage.
- Key possessions.

- [ ] **Step 5: Verify analytics**

Run:

```powershell
dart format lib/core/domain/analytics lib/features/replay test/core/domain
flutter test test/core/domain/match_analytics_test.dart test/features/replay
flutter analyze
```

Expected: all commands exit with code 0.

- [ ] **Step 6: Commit**

```powershell
git add lib/core/domain/analytics lib/features/replay test/core/domain test/features/replay
git commit -m "feat: add match analytics"
```

## Task 15: Backup Import/Export, CSV, And Replay Image

**Status:** Completed in Wave 5C. Verified with unit/widget tests, static analysis,
an Android debug build, and emulator share-sheet/image export checks.

**Files:**
- Create: `lib/core/export/backup_manifest.dart`
- Create: `lib/core/export/json_backup_codec.dart`
- Create: `lib/core/export/csv_exporter.dart`
- Create: `lib/core/export/replay_image_exporter.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `test/core/export/json_backup_codec_test.dart`
- Test: `test/core/export/csv_exporter_test.dart`

- [x] **Step 1: Write export tests**

Test that:

- JSON backup round-trips a match with events and locations.
- Backup manifest includes schema version and export timestamp.
- CSV event export includes match id, event id, event type, side, points, timestamp.

- [x] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/core/export
```

Expected: FAIL because export code does not exist.

- [x] **Step 3: Implement backup manifest**

Create `BackupManifest` with:

- `appName`
- `appVersion`
- `schemaVersion`
- `exportedAt`
- `recordCounts`
- `checksum`

- [x] **Step 4: Implement JSON backup codec**

The codec exports:

- matches
- players
- rule templates
- match events
- shot locations
- audit logs
- settings
- manifest

Import validates manifest schema and rejects future unsupported schema versions with a typed exception.

- [x] **Step 5: Implement CSV exporter**

Export at least:

- match list CSV
- event list CSV
- player statistics CSV

- [x] **Step 6: Implement replay image exporter**

Use Flutter rendering to capture a replay summary widget through `RepaintBoundary`. The exported image includes score, shot chart, and key analytics.

- [x] **Step 7: Verify export**

Run:

```powershell
dart format lib/core/export lib/features/settings test/core/export
flutter test test/core/export
flutter analyze
```

Expected: all commands exit with code 0.

- [x] **Step 8: Commit**

```powershell
git add lib/core/export lib/features/settings test/core/export
git commit -m "feat: add local backup and export"
```

## Task 16: Automatic Backup

**Status:** Completed in Wave 5C. Automatic backup remains opt-in, validates a
user-approved directory, and preserves previous backup files.

**Files:**
- Create: `lib/core/export/automatic_backup_service.dart`
- Modify: `lib/features/settings/settings_page.dart`
- Test: `test/core/export/automatic_backup_service_test.dart`

- [x] **Step 1: Write automatic backup tests**

Test that:

- Automatic backup is disabled by default.
- Enabling automatic backup requires a configured export directory.
- Running backup writes a JSON backup through `JsonBackupCodec`.

- [x] **Step 2: Run tests and verify failure**

Run:

```powershell
flutter test test/core/export/automatic_backup_service_test.dart
```

Expected: FAIL because service does not exist.

- [x] **Step 3: Implement automatic backup service**

Service methods:

- `isEnabled()`
- `configureDirectory(String path)`
- `enable()`
- `disable()`
- `runNow()`

Use Android-friendly file picker flow and store only user-approved directory metadata.

- [x] **Step 4: Add settings controls**

Settings backup section shows:

- Current backup status.
- Selected location.
- Enable or disable.
- Run backup now.

- [x] **Step 5: Verify automatic backup**

Run:

```powershell
dart format lib/core/export lib/features/settings test/core/export
flutter test test/core/export/automatic_backup_service_test.dart
flutter analyze
```

Expected: all commands exit with code 0.

- [x] **Step 6: Commit**

```powershell
git add lib/core/export lib/features/settings test/core/export
git commit -m "feat: add automatic local backup"
```

## Task 17: Integration Test For Main Loop

**Files:**
- Create: `integration_test/main_loop_test.dart`
- Modify: `pubspec.yaml`

- [x] **Step 1: Write integration test**

Create `integration_test/main_loop_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:hooptrace/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('user can start match score confirm location and open replay', (tester) async {
    app.main();
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始计分'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('开始比赛'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('+2').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('确认落点'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('复盘'));
    await tester.pumpAndSettle();

    expect(find.text('总览历史'), findsOneWidget);
  });
}
```

- [x] **Step 2: Run integration test and verify failure**

Run:

```powershell
flutter test integration_test/main_loop_test.dart
```

Expected: FAIL until routes and flow are wired end-to-end.

- [x] **Step 3: Wire missing route transitions**

Ensure:

- Home start button opens pre-game.
- Pre-game start button creates a match and opens scoring.
- Scoring replay button opens replay.
- Replay can load the current match from repository.

- [x] **Step 4: Verify main loop**

Run:

```powershell
dart format lib integration_test
flutter test integration_test/main_loop_test.dart
flutter test
flutter analyze
```

Expected: all commands exit with code 0.

- [x] **Step 5: Commit**

```powershell
git add lib integration_test test/features/scoring/scoring_page_test.dart
git commit -m "test: cover main scoring loop"
```

## Task 18: Release Documentation, CI, And F-Droid Preparation

**Files:**
- Create: `README.md`
- Create: `CONTRIBUTING.md`
- Create: `PRIVACY.md`
- Create: `docs/release/release-checklist.md`
- Create: `docs/release/fdroid-notes.md`
- Create: `.github/workflows/flutter-ci.yml`

- [x] **Step 1: Write release docs**

`README.md` must include:

- HoopTrace purpose.
- Permanent free and open-source statement.
- Offline/local data statement.
- Android-first status.
- Development setup.
- Test commands.
- Release channel.

`PRIVACY.md` must state that first release has no account, no cloud sync, and no personal data upload.

- [x] **Step 2: Add GitHub Actions CI**

Create `.github/workflows/flutter-ci.yml`:

```yaml
name: Flutter CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
        with:
          channel: stable
      - run: flutter pub get
      - run: dart format --set-exit-if-changed .
      - run: flutter analyze
      - run: flutter test
      - run: flutter build apk --debug
```

- [x] **Step 3: Add release checklist**

`docs/release/release-checklist.md` must include:

- Version update.
- Changelog update.
- Fresh test run.
- Android debug build.
- Android release build.
- APK smoke test on a device or emulator.
- GitHub Release notes.
- F-Droid metadata review.

- [x] **Step 4: Add F-Droid notes**

`docs/release/fdroid-notes.md` must include:

- Build command.
- Dependency notes.
- Network behavior statement.
- Privacy statement link.
- License.
- Source tarball expectation.

- [x] **Step 5: Verify release docs and CI config**

Run:

```powershell
flutter test
flutter analyze
flutter build apk --debug
```

Expected: all commands exit with code 0.

- [x] **Step 6: Commit**

```powershell
git add README.md CONTRIBUTING.md PRIVACY.md CHANGELOG.md docs/release fastlane assets/icons .github/workflows/flutter-ci.yml android ios
git commit -m "docs: add release and contribution docs"
```

## Final Verification Before First Release

Run these commands from repository root:

```powershell
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test/main_loop_test.dart -d <android-device-id>
flutter build apk --debug
```

Expected:

- Format check passes.
- Static analysis reports no issues.
- Unit and widget tests pass.
- Main integration flow passes.
- Android debug APK builds.

Then create a GitHub Release with:

- APK artifact.
- Source archive.
- Changelog.
- Privacy statement link.
- Known limitations.

## Branching Guidance

Use short-lived branches with the `codex/` prefix:

- `codex/flutter-scaffold`
- `codex/domain-kernel`
- `codex/scoring-main-loop`
- `codex/replay-history`
- `codex/audit-statistics`
- `codex/export-settings-release`

Each branch should include tests for its scope and should avoid unrelated refactors.

## Spec Coverage Review

This plan covers:

- Offline Android-first Flutter app.
- Court-first landscape scoring and replay.
- Home, pre-game, scoring, replay, history, players, rules, settings, and project details.
- Local SQLite persistence.
- Rule templates and non-blocking rule hints.
- Lightweight possession.
- Score, miss, foul, reward, pause, note, and custom events.
- Pending shot location confirm or skip.
- Edit mode and audit history.
- Single-match replay and long-term local analytics.
- JSON backup import/export, CSV export, replay image export, and automatic backup.
- Chinese-first UI with localization structure.
- GitHub Releases and F-Droid preparation.
- Higher quality gate through tests and CI.
