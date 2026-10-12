import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  final l10n = AppLocalizationsZh();

  test(
    'activeMatchProvider reacts to committed match and score writes',
    () async {
      final database = createTestDatabase();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      final now = DateTime.utc(2026, 8, 23, 12);
      final commandService = container.read(matchCommandServiceProvider);
      container.listen(activeMatchProvider, (_, _) {}, fireImmediately: true);
      final command = StartMatchCommand(
        commandId: 'task6-active-start',
        matchId: 'task6-active',
        redName: '红队',
        blueName: '蓝队',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: '自由计分',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        createdAt: now,
        startedAt: now,
      );

      await commandService.start(command);
      final started = await container.read(activeMatchProvider.future);
      expect(started?.match.id, 'task6-active');
      expect(started?.redScore, 0);

      await commandService.record(
        RecordMatchEventCommand(
          commandId: 'task6-active-score',
          matchId: command.matchId,
          side: TeamSide.red,
          points: 2,
          occurredAt: now,
        ),
      );

      await _eventually(
        () => container.read(activeMatchProvider).valueOrNull?.redScore == 2,
      );
      expect(container.read(activeMatchProvider).valueOrNull?.redScore, 2);
    },
  );

  test(
    'latestFinishedMatchProvider follows the newest finished match',
    () async {
      final database = createTestDatabase();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });
      container.listen(
        latestFinishedMatchProvider,
        (_, _) {},
        fireImmediately: true,
      );
      final service = container.read(matchCommandServiceProvider);
      await _eventually(() {
        final latest = container.read(latestFinishedMatchProvider);
        return latest is AsyncData<MatchDetail?> && latest.value == null;
      });

      Future<void> finishMatch(String id, DateTime startedAt) async {
        await service.start(
          StartMatchCommand(
            commandId: 'start-$id',
            matchId: id,
            redName: 'Red $id',
            blueName: 'Blue $id',
            ruleTemplate: const RuleTemplate(
              id: 'free',
              name: 'Free scoring',
              scoreButtons: [1, 2, 3],
            ),
            recordingMode: RecordingMode.simple,
            createdAt: startedAt,
            startedAt: startedAt,
          ),
        );
        await service.record(
          RecordMatchEventCommand(
            commandId: 'score-$id',
            matchId: id,
            side: TeamSide.red,
            points: 2,
            occurredAt: startedAt.add(const Duration(minutes: 1)),
          ),
        );
        await service.finish(
          FinishMatchCommand(
            commandId: 'finish-$id',
            matchId: id,
            endedAt: startedAt.add(const Duration(minutes: 10)),
            confirmFinalScore: true,
          ),
        );
      }

      await finishMatch('older-finished', DateTime.utc(2026, 8, 23, 10));
      await _eventually(
        () =>
            container.read(latestFinishedMatchProvider).valueOrNull?.match.id ==
            'older-finished',
      );
      await finishMatch('newer-finished', DateTime.utc(2026, 8, 24, 10));
      await _eventually(
        () =>
            container.read(latestFinishedMatchProvider).valueOrNull?.match.id ==
            'newer-finished',
      );
      final latest = container.read(latestFinishedMatchProvider).valueOrNull!;
      expect(latest.redScore, 2);
      expect(latest.match.redName, 'Red newer-finished');
    },
  );

  testWidgets(
    'rebuilding the widget tree with the same database shows resume card',
    (tester) async {
      final database = createTestDatabase();
      _closeDatabaseAfterWidgetTest(tester, database);
      final commandService = MatchCommandService(database);
      final now = DateTime.utc(2026, 8, 23, 12);
      await commandService.start(
        StartMatchCommand(
          commandId: 'task6-rebuild-start',
          matchId: 'task6-rebuild',
          redName: '重建红方',
          blueName: '重建蓝方',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: '自由计分',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          createdAt: now,
          startedAt: now,
        ),
      );
      await commandService.record(
        RecordMatchEventCommand(
          commandId: 'task6-rebuild-score',
          matchId: 'task6-rebuild',
          side: TeamSide.blue,
          points: 3,
          occurredAt: now,
        ),
      );

      await tester.pumpWidget(
        HoopitoApp(database: database, showEntryAnimation: false),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('home-resume-card')));
      expect(find.text('重建红方'), findsOneWidget);
      expect(find.text('重建蓝方'), findsOneWidget);
      _expectResumeScores(tester, [3, 0]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpWidget(
        HoopitoApp(database: database, showEntryAnimation: false),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('home-resume-card')));
      expect(find.text('重建红方'), findsOneWidget);
      _expectResumeScores(tester, [3, 0]);
    },
  );

  testWidgets('active match hides new match entry until explicitly abandoned', (
    tester,
  ) async {
    final database = createTestDatabase();
    _closeDatabaseAfterWidgetTest(tester, database);
    final now = DateTime.utc(2026, 8, 23, 12);
    await MatchCommandService(database).start(
      StartMatchCommand(
        commandId: 'task6-block-start',
        matchId: 'task6-block',
        redName: '已进行红方',
        blueName: '已进行蓝方',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: '自由计分',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        createdAt: now,
        startedAt: now,
      ),
    );

    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume-card')));
    expect(find.byKey(const Key('home-start-scoring')), findsNothing);

    await tester.tap(find.byKey(const Key('active-abandon')));
    await tester.pump();
    expect(find.text(l10n.homeAbandonTitle), findsOneWidget);
    await tester.tap(find.text(l10n.homeConfirmAbandon));
    await _pumpUntilFound(tester, find.byKey(const Key('home-start-scoring')));
    expect(find.byKey(const Key('home-resume-card')), findsNothing);

    await tester.tap(find.byKey(const Key('home-start-scoring')));
    await _pumpUntilFound(tester, find.text(l10n.pregameTitle));
  });

  testWidgets('leaving live scoring offers keep running, pause and stay', (
    tester,
  ) async {
    final database = createTestDatabase();
    _closeDatabaseAfterWidgetTest(tester, database);
    final now = DateTime.now().toUtc();
    final commandService = MatchCommandService(database);
    await commandService.start(
      StartMatchCommand(
        commandId: 'task6-leave-start',
        matchId: 'task6-leave',
        redName: '离开红方',
        blueName: '离开蓝方',
        ruleTemplate: const RuleTemplate(
          id: 'free',
          name: '自由计分',
          scoreButtons: [1, 2, 3],
        ),
        recordingMode: RecordingMode.simple,
        timerEnabled: true,
        regulationSeconds: 600,
        createdAt: now,
        startedAt: now,
      ),
    );

    await tester.pumpWidget(
      HoopitoApp(database: database, showEntryAnimation: false),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume-card')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scoring-leave')));
    await tester.pumpAndSettle();
    expect(find.text(l10n.routeLeaveTitle), findsOneWidget);
    expect(find.byKey(const Key('leave-stay')), findsOneWidget);
    expect(find.byKey(const Key('leave-keep-running')), findsOneWidget);
    expect(find.byKey(const Key('leave-pause-and-leave')), findsOneWidget);

    await tester.tap(find.byKey(const Key('leave-stay')));
    await tester.pumpAndSettle();
    expect(find.byType(ScoringPage), findsOneWidget);

    await tester.tap(find.byKey(const Key('scoring-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-keep-running')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('home-resume')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect((await commandService.readClock('task6-leave'))?.isRunning, isTrue);

    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('scoring-leave')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('leave-pause-and-leave')));
    await _pumpUntilMissing(tester, find.byType(ScoringPage));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('home-resume')).hitTestable(),
    );
    await tester.pumpAndSettle();
    expect((await commandService.readClock('task6-leave'))?.isRunning, isFalse);
  });

  testWidgets('legacy bootstrap explains that v0.1 data is preserved', (
    tester,
  ) async {
    final database = createTestDatabase();
    _closeDatabaseAfterWidgetTest(tester, database);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          databaseCompatibilityProbeProvider.overrideWith(
            (ref) =>
                (_) async => throw const LegacySchemaDetectedException(1),
          ),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('legacy-bootstrap')));
    expect(find.text(l10n.legacyBootstrapHeadline), findsOneWidget);
    expect(find.text(l10n.legacyBootstrapBody(' v1')), findsOneWidget);
  });
}

void _expectResumeScores(WidgetTester tester, List<int> scores) {
  final values = tester
      .widgetList<ScoreNumeral>(
        find.descendant(
          of: find.byKey(const Key('home-resume-card')),
          matching: find.byType(ScoreNumeral),
        ),
      )
      .map((score) => score.value)
      .toList();
  expect(values, scores);
}

void _closeDatabaseAfterWidgetTest(WidgetTester tester, AppDatabase database) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for reactive provider update.');
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      // Let the bounded go_router transition finish before the next tap.
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpUntilMissing(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder to disappear');
}
