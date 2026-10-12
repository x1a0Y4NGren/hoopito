import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/settings/scoring_feedback.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

void main() {
  testWidgets('production rapid pause queues behind an in-flight score', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-queued-score-pause';
    await _startMatch(database, matchId, timerEnabled: true);
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    var armed = false;
    var beforeCommitCalls = 0;
    final gatedService = MatchCommandService(
      database,
      failureInjector: (point) async {
        if (armed && point == MatchCommandFailurePoint.beforeCommit) {
          beforeCommitCalls++;
          if (!entered.isCompleted) {
            entered.complete();
            await release.future;
          }
        }
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(gatedService),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));

    armed = true;
    await tester.tap(find.byKey(const Key('blue-score-1')));
    await tester.pump();
    await entered.future;
    await tester.tap(find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await tester.pump();
    expect(find.byKey(const Key('scoring-paused-panel')), findsNothing);

    release.complete();
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );
    expect(beforeCommitCalls, 2);
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    final events = await database.select(database.matchEvents).get();
    expect(events.map((event) => event.type), [
      EventKind.fieldGoal.name,
      EventKind.pause.name,
    ]);
    expect(events.last.customLabel, 'pause');
  });

  testWidgets('successful resume retry dismisses the blocking paused panel', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-resume-retry-success';
    await _startMatch(database, matchId, timerEnabled: true);
    final normalService = MatchCommandService(database);
    await normalService.pause(
      PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );
    final retryEntered = Completer<void>();
    final retryRelease = Completer<void>();
    addTearDown(() {
      if (!retryRelease.isCompleted) retryRelease.complete();
    });
    var resumeAttempts = 0;
    final retryService = MatchCommandService(
      database,
      failureInjector: (point) async {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          resumeAttempts++;
          if (resumeAttempts == 1) {
            throw StateError('fail first resume');
          }
          if (resumeAttempts == 2) {
            retryEntered.complete();
            await retryRelease.future;
          }
        }
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(retryService),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );

    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
    expect(find.byKey(const Key('paused-resume-failure')), findsOneWidget);
    final retry = find.byKey(const Key('paused-retry')).hitTestable();
    expect(retry, findsOneWidget);
    await tester.tap(retry);
    await tester.pump();
    await retryEntered.future;
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('paused-return-home')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('paused-retry')))
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('paused-finish')))
          .onPressed,
      isNull,
    );
    await tester.tap(
      find.byKey(const Key('paused-retry')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(resumeAttempts, 2);
    retryRelease.complete();
    await _pumpUntilGone(tester, find.byKey(const Key('scoring-paused-panel')));

    expect((await normalService.readClock(matchId))?.isRunning, isTrue);
    final events = await database.select(database.matchEvents).get();
    expect(events.map((event) => event.customLabel), ['pause', 'resume']);
    expect(find.byType(ScoringPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed resume retry remains blocked and retryable', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-resume-retry-fails-again';
    await _startMatch(database, matchId, timerEnabled: true);
    final normalService = MatchCommandService(database);
    await normalService.pause(
      PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );
    final failingService = MatchCommandService(
      database,
      failureInjector: (point) {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          throw StateError('resume remains unavailable');
        }
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(failingService),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );

    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBarAction), findsNothing);
    await tester.tap(find.byKey(const Key('paused-retry')).hitTestable());
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(find.byKey(const Key('paused-resume-failure')), findsOneWidget);
    expect(find.byKey(const Key('paused-retry')).hitTestable(), findsOneWidget);
    expect(find.byType(SnackBarAction), findsNothing);
    expect((await normalService.readClock(matchId))?.isRunning, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production double continue submits one resume command', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-double-resume';
    await _startMatch(database, matchId, timerEnabled: true);
    final normalService = MatchCommandService(database);
    await normalService.pause(
      PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );
    final entered = Completer<void>();
    final release = Completer<void>();
    addTearDown(() {
      if (!release.isCompleted) release.complete();
    });
    var beforeCommitCalls = 0;
    final gatedService = MatchCommandService(
      database,
      failureInjector: (point) async {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          beforeCommitCalls++;
          if (!entered.isCompleted) {
            entered.complete();
            await release.future;
          }
        }
      },
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(gatedService),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );

    final continueButton = find.byKey(const Key('paused-continue'));
    await tester.tap(continueButton);
    await tester.pump();
    await entered.future;
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('paused-return-home')))
          .onPressed,
      isNull,
    );
    expect(tester.widget<FilledButton>(continueButton).onPressed, isNull);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('paused-finish')))
          .onPressed,
      isNull,
    );
    await tester.tap(continueButton, warnIfMissed: false);
    await tester.pump();
    expect(beforeCommitCalls, 1);

    release.complete();
    await _pumpUntilGone(tester, find.byKey(const Key('scoring-paused-panel')));
    expect(beforeCommitCalls, 1);
  });

  testWidgets('external resume does not pop the finish confirmation route', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-paused-confirm-route';
    await _startMatch(database, matchId, timerEnabled: true);
    final service = MatchCommandService(database);
    await service.pause(
      PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );
    await tester.tap(find.byKey(const Key('paused-finish')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scoring-finish-confirm')), findsOneWidget);

    final projection = await service.resume(
      ResumeMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );
    container
        .read(scoringControllerProvider(matchId))
        ?.replaceCommittedProjection(projection);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('scoring-finish-confirm')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('paused scoring shows blocking panel and resumes explicitly', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-resume-control';
    await _startMatch(database, matchId, timerEnabled: true);
    final service = MatchCommandService(database);
    await service.pause(
      PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );

    await _enterScoring(tester, database);
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pump(const Duration(milliseconds: 100));
    expect((await service.readClock(matchId))?.isRunning, isTrue);
    await _pumpUntilGone(tester, find.byKey(const Key('scoring-more-sheet')));
    expect(find.byType(ScoringPage), findsOneWidget);
  });

  testWidgets('resume command failure keeps the button and scoring page', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-resume-failure';
    await _startMatch(database, matchId, timerEnabled: true);
    final normalService = MatchCommandService(database);
    await normalService.pause(
      PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );
    final failingService = MatchCommandService(
      database,
      failureInjector: (point) {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          throw StateError('injected resume failure');
        }
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(failingService),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pump();
    expect(find.byType(ScoringPage), findsOneWidget);
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(find.text('操作失败，请重试。'), findsOneWidget);
  });

  testWidgets(
    'production resume emits feedback only after a successful command',
    (tester) async {
      final database = AppDatabase.inMemory();
      _closeAfterWidgetTest(tester, database);
      const matchId = 'task6-resume-feedback';
      await _startMatch(database, matchId, timerEnabled: true);
      final service = MatchCommandService(database);
      await service.pause(
        PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
      );
      final platform = _ResumeFeedbackPlatform(database);
      final feedback = ScoringFeedbackService(
        ScoringFeedbackPreferencesRepository(database),
        platform: platform,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            scoringFeedbackServiceProvider.overrideWithValue(feedback),
          ],
          child: const HoopitoApp(showEntryAnimation: false),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
      await tester.tap(find.byKey(const Key('home-resume')));
      await _pumpUntilFound(tester, find.byType(ScoringPage));
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('scoring-paused-panel')),
      );
      expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
      await tester.tap(find.byKey(const Key('paused-continue')));
      await _pumpUntilGone(
        tester,
        find.byKey(const Key('scoring-paused-panel')),
      );

      expect(platform.hapticCalls, 1);
      expect(platform.eventCounts, [greaterThanOrEqualTo(2)]);
    },
  );

  testWidgets('production resume failure does not emit feedback', (
    tester,
  ) async {
    final database = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, database);
    const matchId = 'task6-resume-feedback-failure';
    await _startMatch(database, matchId, timerEnabled: true);
    final normalService = MatchCommandService(database);
    await normalService.pause(
      PauseMatchCommand(matchId: matchId, occurredAt: DateTime.now().toUtc()),
    );
    final failingService = MatchCommandService(
      database,
      failureInjector: (point) {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          throw StateError('injected resume failure');
        }
      },
    );
    final platform = _ResumeFeedbackPlatform(database);
    final feedback = ScoringFeedbackService(
      ScoringFeedbackPreferencesRepository(database),
      platform: platform,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(failingService),
          scoringFeedbackServiceProvider.overrideWithValue(feedback),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await tester.tap(find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
    );
    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    await tester.tap(find.byKey(const Key('paused-continue')));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const Key('scoring-paused-panel')), findsOneWidget);
    expect(platform.hapticCalls, 0);
  });

  testWidgets('running and timer-disabled scoring do not show resume control', (
    tester,
  ) async {
    final runningDatabase = AppDatabase.inMemory();
    _closeAfterWidgetTest(tester, runningDatabase);
    await _startMatch(
      runningDatabase,
      'task6-resume-running',
      timerEnabled: true,
    );
    await _enterScoring(tester, runningDatabase);
    await _openMore(tester);
    expect(find.byKey(const Key('more-pause')), findsOneWidget);
    expect(find.byKey(const Key('more-resume')), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await runningDatabase.close();
    final noTimerDatabase = AppDatabase.inMemory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await noTimerDatabase.close();
    });
    await _startMatch(
      noTimerDatabase,
      'task6-resume-no-timer',
      timerEnabled: false,
    );
    await _enterScoring(tester, noTimerDatabase);
    await _openMore(tester);
    expect(find.byKey(const Key('more-pause')), findsNothing);
    expect(find.byKey(const Key('more-resume')), findsNothing);
  });
}

Future<void> _startMatch(
  AppDatabase database,
  String matchId, {
  required bool timerEnabled,
}) async {
  final now = DateTime.now().toUtc();
  await MatchCommandService(database).start(
    StartMatchCommand(
      commandId: '$matchId-start',
      matchId: matchId,
      redName: '红队',
      blueName: '蓝队',
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: '自由计分',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      timerEnabled: timerEnabled,
      regulationSeconds: timerEnabled ? 600 : null,
      createdAt: now,
      startedAt: now,
    ),
  );
}

Future<void> _enterScoring(WidgetTester tester, AppDatabase database) async {
  await tester.pumpWidget(
    HoopitoApp(database: database, showEntryAnimation: false),
  );
  await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
  await tester.tap(find.byKey(const Key('home-resume')));
  await _pumpUntilFound(tester, find.byType(ScoringPage));
}

void _closeAfterWidgetTest(WidgetTester tester, AppDatabase database) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await database.close();
  });
}

class _ResumeFeedbackPlatform implements ScoringFeedbackPlatform {
  _ResumeFeedbackPlatform(this.database);

  final AppDatabase database;
  int hapticCalls = 0;
  final eventCounts = <int>[];

  @override
  Future<void> lightImpact() async {
    hapticCalls++;
    eventCounts.add((await database.select(database.matchEvents).get()).length);
  }

  @override
  Future<void> click() async {}
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 300));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder');
}

Future<void> _openMore(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('scoring-more')));
  await tester.pumpAndSettle();
  expect(find.byKey(const Key('scoring-more-sheet')), findsOneWidget);
}

Future<void> _pumpUntilGone(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder to disappear');
}
