import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' show Value;
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/l10n/app_localizations_en.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/features/history/history_page.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../test_helpers/test_database.dart';

void main() {
  final l10n = AppLocalizationsEn();

  test(
    'active and live watches have one initial snapshot and later updates',
    () async {
      final database = createTestDatabase();
      const matchId = 'task6-single-initial';
      final now = DateTime.utc(2026, 8, 23, 12);
      final service = MatchCommandService(database);
      await service.start(
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
          trackingCoverage: TrackingCoverage.locations,
          createdAt: now,
          startedAt: now,
        ),
      );
      final repository = MatchRepository(database);
      final activeValues = <dynamic>[];
      final liveValues = <dynamic>[];
      final activeSubscription = repository.watchActiveMatch().listen(
        activeValues.add,
      );
      final liveSubscription = repository
          .watchLiveMatch(matchId)
          .listen(liveValues.add);
      addTearDown(() async {
        await activeSubscription.cancel();
        await liveSubscription.cancel();
        await database.close();
      });

      await _eventually(
        () => activeValues.length == 1 && liveValues.length == 1,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(activeValues, hasLength(1));
      expect(liveValues, hasLength(1));

      await service.record(
        RecordMatchEventCommand(
          commandId: '$matchId-score',
          matchId: matchId,
          eventId: '$matchId-score-event',
          side: TeamSide.red,
          points: 2,
          occurredAt: now,
        ),
      );
      await _eventually(
        () =>
            activeValues.any((value) => value?.redScore == 2) &&
            liveValues.any((value) => value?.redScore == 2),
      );

      await database
          .into(database.possessionSegments)
          .insert(
            PossessionSegmentsCompanion.insert(
              id: '$matchId-segment',
              matchId: matchId,
              side: TeamSide.red.name,
              startedAtEventId: '$matchId-score-event',
              source: Value(PossessionSource.manual.name),
            ),
          );
      await _eventually(
        () =>
            activeValues.any(
              (value) => value?.possessionSegments.length == 1,
            ) &&
            liveValues.any((value) => value?.possessionSegments.length == 1),
      );
    },
  );

  test(
    'scoring controller keeps identity and pending location across projection refresh',
    () async {
      final database = createTestDatabase();
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(() async {
        container.dispose();
        await database.close();
      });

      const matchId = 'task6-controller-stability';
      final now = DateTime.utc(2026, 8, 23, 12);
      final service = container.read(matchCommandServiceProvider);
      await service.start(
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
          trackingCoverage: TrackingCoverage.locations,
          createdAt: now,
          startedAt: now,
        ),
      );
      final live = container.listen<AsyncValue<dynamic>>(
        liveMatchProvider(matchId),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(live.close);
      await _eventually(
        () => container.read(liveMatchProvider(matchId)).hasValue,
      );

      final scoring = container.listen(
        scoringControllerProvider(matchId),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(scoring.close);
      final first = container.read(scoringControllerProvider(matchId));
      expect(first, isNotNull);
      await first!.recordScoreCommitted(side: TeamSide.red, points: 2);
      expect(first.beginLocateLastUnlocatedShot(), isTrue);
      expect(first.state.pendingLocation, isNotNull);

      await _eventually(
        () =>
            container.read(liveMatchProvider(matchId)).valueOrNull?.redScore ==
            2,
      );
      final afterRefresh = container.read(scoringControllerProvider(matchId));
      expect(identical(afterRefresh, first), isTrue);
      expect(afterRefresh!.state.pendingLocation, isNotNull);

      await afterRefresh.confirmPendingLocation();
      await _eventually(
        () =>
            container
                .read(scoringControllerProvider(matchId))!
                .state
                .pendingLocation ==
            null,
      );
    },
  );

  test(
    'new provider container creates a fresh controller from the same database projection',
    () async {
      final database = createTestDatabase();
      const matchId = 'task6-controller-rebuild';
      final now = DateTime.utc(2026, 8, 23, 12);
      final service = MatchCommandService(database);
      await service.start(
        StartMatchCommand(
          commandId: '$matchId-start',
          matchId: matchId,
          redName: '重建红队',
          blueName: '重建蓝队',
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
      await service.record(
        RecordMatchEventCommand(
          commandId: '$matchId-score',
          matchId: matchId,
          side: TeamSide.blue,
          points: 3,
          occurredAt: now,
        ),
      );

      final firstContainer = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      final firstLive = firstContainer.listen<AsyncValue<dynamic>>(
        liveMatchProvider(matchId),
        (_, _) {},
        fireImmediately: true,
      );
      await _eventually(
        () => firstContainer.read(liveMatchProvider(matchId)).hasValue,
      );
      final firstScoring = firstContainer.listen(
        scoringControllerProvider(matchId),
        (_, _) {},
        fireImmediately: true,
      );
      final first = firstContainer.read(scoringControllerProvider(matchId));
      expect(first!.state.score.blueScore, 3);
      firstLive.close();
      firstScoring.close();
      firstContainer.dispose();

      final secondContainer = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
      );
      addTearDown(secondContainer.dispose);
      final secondLive = secondContainer.listen<AsyncValue<dynamic>>(
        liveMatchProvider(matchId),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(secondLive.close);
      await _eventually(
        () => secondContainer.read(liveMatchProvider(matchId)).hasValue,
      );
      final secondScoring = secondContainer.listen(
        scoringControllerProvider(matchId),
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(secondScoring.close);
      final second = secondContainer.read(scoringControllerProvider(matchId));
      expect(second, isNotNull);
      expect(identical(second, first), isFalse);
      expect(second!.state.score.blueScore, 3);
    },
  );

  testWidgets('scoring route shows a terminal message for an unknown match', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp.router(
          theme: buildHoopitoTheme(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    router.go('/scoring/not-a-match');
    await _pumpUntilFound(tester, find.text(l10n.routeMatchNotActive));
    await tester.pumpAndSettle();
    expect(find.text(l10n.routeMatchNotActiveBody), findsOneWidget);
    expect(find.byKey(const Key('route-message-home')), findsOneWidget);
    expect(find.byKey(const Key('route-message-replay')), findsNothing);
    await tester.tap(find.byKey(const Key('route-message-home')));
    await _pumpUntilFound(tester, find.byType(HomePage));
  });

  testWidgets('finished scoring deep link offers replay and home exits', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-finished-scoring-deep-link';
    await _seedFinishedMatch(database, matchId);
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerHost(database, router));
    router.go('/scoring/$matchId');
    await _pumpUntilFound(tester, find.text(l10n.routeMatchNotActive));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('route-message-home')), findsOneWidget);
    expect(find.byKey(const Key('route-message-replay')), findsOneWidget);
    await tester.tap(find.byKey(const Key('route-message-replay')));
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await tester.pumpAndSettle();
    expect(find.text(l10n.replayFinished), findsOneWidget);

    await tester.binding.handlePopRoute();
    await _pumpUntilFound(tester, find.byType(HomePage));
  });

  testWidgets('active replay has an explicit exit back to scoring', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-active-replay-exit';
    final now = DateTime.utc(2026, 8, 23, 12);
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
        trackingCoverage: TrackingCoverage.scoresOnly,
        createdAt: now,
        startedAt: now,
      ),
    );
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerHost(database, router));
    router.go('/scoring/$matchId');
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    router.push('/matches/$matchId/replay');
    await _pumpUntilFound(tester, find.byType(ReplayPage));

    expect(
      tester.widget<IconButton>(find.byKey(const Key('replay-exit'))).tooltip,
      l10n.replayExitToScoringTooltip,
    );

    await tester.tap(find.byKey(const Key('replay-exit')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));

    router.push('/matches/$matchId/replay');
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await tester.binding.handlePopRoute();
    await _pumpUntilFound(tester, find.byType(ScoringPage));
  });

  testWidgets(
    'cold-start active replay deep link stays finishable and exits to scoring',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });
      const matchId = 'task6-cold-start-active-replay';
      final now = DateTime.utc(2026, 8, 23, 12);
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
          trackingCoverage: TrackingCoverage.scoresOnly,
          createdAt: now,
          startedAt: now,
        ),
      );
      final router = buildProviderAppRouter();
      addTearDown(router.dispose);
      router.go('/matches/$matchId/replay');

      await tester.pumpWidget(_routerHost(database, router));
      await _pumpUntilFound(tester, find.byType(ReplayPage));

      expect(find.text(l10n.replayInProgress), findsOneWidget);
      expect(find.byKey(const Key('replay-finish-match')), findsOneWidget);

      await tester.binding.handlePopRoute();
      await _pumpUntilFound(tester, find.byType(ScoringPage));

      router.go('/matches/$matchId/replay');
      await _pumpUntilFound(tester, find.byType(ReplayPage));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.byKey(const Key('replay-exit')));
      await _pumpUntilFound(tester, find.byType(ScoringPage));
    },
  );

  testWidgets('pending replay finish stays Home after leaving the route', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-pending-finish-home';
    await _seedActiveMatch(database, matchId);
    final finishReleased = Completer<void>();
    var finishStarted = false;
    final commandService = MatchCommandService(
      database,
      failureInjector: (point) async {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          finishStarted = true;
          await finishReleased.future;
        }
      },
    );
    final backup = _RecordingAutomaticBackupService(database);
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    router.go('/matches/$matchId/replay');
    await tester.pumpWidget(
      _routerHost(
        database,
        router,
        commandService: commandService,
        automaticBackup: backup,
      ),
    );
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await tester.tap(find.byKey(const Key('replay-finish-match')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('replay-finish-confirm')));
    await _pumpUntil(tester, () => finishStarted);

    router.go('/');
    await tester.pump();
    finishReleased.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.byType(HomePage));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(ReplayPage), findsNothing);
    expect(
      (await MatchRepository(
        database,
      ).getMatchDetail(matchId))!.match.lifecycle,
      MatchLifecycle.finished,
    );
    await _pumpUntil(tester, () => backup.calls == 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending replay finish does not switch back after same-state match switch',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });
      const activeMatchId = 'task6-pending-finish-switch-active';
      const finishedMatchId = 'task6-pending-finish-switch-finished';
      await _seedFinishedMatch(database, finishedMatchId, redName: 'Bravo');
      await _seedActiveMatch(database, activeMatchId, redName: 'Active');
      final finishReleased = Completer<void>();
      var finishStarted = false;
      final commandService = MatchCommandService(
        database,
        failureInjector: (point) async {
          if (point == MatchCommandFailurePoint.beforeCommit) {
            finishStarted = true;
            await finishReleased.future;
          }
        },
      );
      final backup = _RecordingAutomaticBackupService(database);
      final router = buildProviderAppRouter();
      addTearDown(router.dispose);
      router.go('/matches/$activeMatchId/replay');
      await tester.pumpWidget(
        _routerHost(
          database,
          router,
          commandService: commandService,
          automaticBackup: backup,
        ),
      );
      await _pumpUntilFound(tester, find.byType(ReplayPage));
      await tester.tap(find.byKey(const Key('replay-finish-match')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const Key('replay-finish-confirm')));
      await _pumpUntil(tester, () => finishStarted);

      router.go('/matches/$finishedMatchId/replay');
      await tester.pump();
      finishReleased.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump();
      await _pumpUntilFound(tester, find.text('Bravo'));

      expect(find.text('Bravo'), findsOneWidget);
      expect(find.text('Active'), findsNothing);
      expect(
        (await MatchRepository(
          database,
        ).getMatchDetail(activeMatchId))!.match.lifecycle,
        MatchLifecycle.finished,
      );
      await _pumpUntil(tester, () => backup.calls == 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('stale replay finish failure does not refresh after disposal', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-pending-finish-refresh-dispose';
    await _seedActiveMatch(database, matchId);
    final detail = await MatchRepository(database).getMatchDetail(matchId);
    final repository = _CountingReplayRepository(database);
    var finishStarted = false;
    final finishReleased = Completer<void>();
    final commandService = MatchCommandService(
      database,
      failureInjector: (point) async {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          finishStarted = true;
          await finishReleased.future;
          throw StateError('finish failed once');
        }
      },
    );
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    router.go('/matches/$matchId/replay');
    await tester.pumpWidget(
      _routerHost(
        database,
        router,
        repository: repository,
        commandService: commandService,
      ),
    );
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await tester.tap(find.byKey(const Key('replay-finish-match')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('replay-finish-confirm')));
    await _pumpUntil(tester, () => finishStarted);
    await tester.pumpWidget(const SizedBox.shrink());
    finishReleased.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    expect(repository.requests, 1);
    expect(tester.takeException(), isNull);
    expect(detail, isNotNull);
  });

  testWidgets('pending replay load is ignored after leaving the route', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-pending-replay-load';
    await _seedFinishedMatch(database, matchId);
    final detail = await MatchRepository(database).getMatchDetail(matchId);
    final pending = Completer<MatchDetail?>();
    final repository = _PendingReplayRepository(database)
      ..enqueue(matchId, pending.future);
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(
      _routerHost(database, router, repository: repository),
    );
    router.go('/matches/$matchId/replay');
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    pending.complete(detail);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    expect(find.byType(ReplayPage), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending replay refresh is ignored after route disposal', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-pending-replay-refresh';
    final start = MatchCommandService(database);
    await start.start(
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
        trackingCoverage: TrackingCoverage.scoresOnly,
        createdAt: DateTime.utc(2026, 8, 23, 12),
        startedAt: DateTime.utc(2026, 8, 23, 12),
      ),
    );
    final detail = await MatchRepository(database).getMatchDetail(matchId);
    expect(detail, isNotNull);
    final pending = Completer<MatchDetail?>();
    final repository = _PendingReplayRepository(database)
      ..enqueue(matchId, Future<MatchDetail?>.value(detail))
      ..enqueue(matchId, pending.future);
    var failNext = true;
    final commandService = MatchCommandService(
      database,
      failureInjector: (point) {
        if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
          failNext = false;
          throw StateError('finish failed once');
        }
      },
    );
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    router.go('/matches/$matchId/replay');
    await tester.pumpWidget(
      _routerHost(
        database,
        router,
        repository: repository,
        commandService: commandService,
      ),
    );
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await tester.tap(find.byKey(const Key('replay-finish-match')));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.byKey(const Key('replay-finish-confirm')));
    for (var attempt = 0; attempt < 100; attempt++) {
      await tester.pump(const Duration(milliseconds: 20));
      if (repository.pendingRequests == 2) break;
    }
    expect(repository.pendingRequests, 2);

    await tester.pumpWidget(const SizedBox.shrink());
    pending.complete(detail);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid replay route switch only shows the latest loaded match', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    await _seedFinishedMatch(
      database,
      'task6-switch-a',
      redName: 'Alpha',
      blueName: 'Blue A',
    );
    await _seedFinishedMatch(
      database,
      'task6-switch-b',
      redName: 'Bravo',
      blueName: 'Blue B',
    );
    final base = MatchRepository(database);
    final detailA = await base.getMatchDetail('task6-switch-a');
    final detailB = await base.getMatchDetail('task6-switch-b');
    final pendingA = Completer<MatchDetail?>();
    final pendingB = Completer<MatchDetail?>();
    final repository = _PendingReplayRepository(database)
      ..enqueue('task6-switch-a', pendingA.future)
      ..enqueue('task6-switch-b', pendingB.future);
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    router.go('/matches/task6-switch-a/replay');
    await tester.pumpWidget(
      _routerHost(database, router, repository: repository),
    );
    await tester.pump();
    router.go('/matches/task6-switch-b/replay');
    await tester.pump();

    pendingB.complete(detailB);
    await _pumpUntilFound(tester, find.text('Bravo'));
    pendingA.complete(detailA);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    expect(find.text('Bravo'), findsOneWidget);
    expect(find.text('Alpha'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replay not-found home action returns to Home', (tester) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerHost(database, router));
    router.go('/matches/task6-not-found-home/replay');
    await _pumpUntilFound(tester, find.text(l10n.routeReplayNotFound));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('route-message-home')));
    await _pumpUntilFound(tester, find.byType(HomePage));
  });

  testWidgets('replay load-error home action returns to Home', (tester) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-load-error-home';
    await _seedFinishedMatch(database, matchId);
    final detail = await MatchRepository(database).getMatchDetail(matchId);
    final repository = _FlakyReplayRepository(database, [
      StateError('offline'),
      detail,
    ]);
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    router.go('/matches/$matchId/replay');
    await tester.pumpWidget(
      _routerHost(database, router, repository: repository),
    );
    await _pumpUntilFound(tester, find.text(l10n.routeReplayOpenError));
    await tester.tap(find.byKey(const Key('route-message-home')));
    await _pumpUntilFound(tester, find.byType(HomePage));
  });

  testWidgets(
    'replay not-found fallback has home and retry and reloads successfully',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });
      const matchId = 'task6-replay-retry-not-found';
      final router = buildProviderAppRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(_routerHost(database, router));
      router.go('/matches/$matchId/replay');
      await _pumpUntilFound(tester, find.text(l10n.routeReplayNotFound));

      expect(find.byKey(const Key('route-message-home')), findsOneWidget);
      expect(find.byKey(const Key('route-message-retry')), findsOneWidget);

      await _seedFinishedMatch(database, matchId);
      await tester.tap(find.byKey(const Key('route-message-retry')));
      await _pumpUntilFound(tester, find.byType(ReplayPage));
      expect(find.text(l10n.replayFinished), findsOneWidget);
    },
  );

  testWidgets(
    'replay load error fallback can retry after repository recovers',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });
      const matchId = 'task6-replay-retry-error';
      await _seedFinishedMatch(database, matchId);
      final repository = MatchRepository(database);
      final detail = await repository.getMatchDetail(matchId);
      final flaky = _FlakyReplayRepository(database, [
        StateError('offline'),
        detail,
      ]);
      final router = buildProviderAppRouter();
      addTearDown(router.dispose);
      router.go('/matches/$matchId/replay');
      await tester.pumpWidget(_routerHost(database, router, repository: flaky));
      await _pumpUntilFound(tester, find.text(l10n.routeReplayOpenError));

      expect(find.byKey(const Key('route-message-home')), findsOneWidget);
      expect(find.byKey(const Key('route-message-retry')), findsOneWidget);
      await tester.tap(find.byKey(const Key('route-message-retry')));
      await _pumpUntilFound(tester, find.byType(ReplayPage));
      expect(find.text(l10n.replayFinished), findsOneWidget);
    },
  );

  testWidgets('canonical finished replay exits to home', (tester) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-canonical-replay-exit';
    await _seedFinishedMatch(database, matchId);
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerHost(database, router));
    router.go('/matches/$matchId/replay');
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await tester.pumpAndSettle();

    expect(
      tester.widget<IconButton>(find.byKey(const Key('replay-exit'))).tooltip,
      l10n.historyHomeTooltip,
    );

    await tester.tap(find.byKey(const Key('replay-exit')));
    await _pumpUntilFound(tester, find.byType(HomePage));
  });

  testWidgets('canonical finished replay system back exits to home', (
    tester,
  ) async {
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await database.close();
    });
    const matchId = 'task6-canonical-replay-system-back';
    await _seedFinishedMatch(database, matchId);
    final router = buildProviderAppRouter();
    addTearDown(router.dispose);
    await tester.pumpWidget(_routerHost(database, router));
    router.go('/matches/$matchId/replay');
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await _pumpUntilFound(tester, find.byType(HomePage));
  });

  testWidgets(
    'history result opens replay and returns through result to history',
    (tester) async {
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await database.close();
      });
      const matchId = 'task6-history-replay-exit';
      await _seedFinishedMatch(database, matchId);
      final router = buildProviderAppRouter();
      addTearDown(router.dispose);
      await tester.pumpWidget(_routerHost(database, router));
      router.go('/history');
      await _pumpUntilFound(tester, find.byKey(Key('history-match-$matchId')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('history-match-$matchId')));
      await _pumpUntilFound(tester, find.byType(MatchSummaryPage));
      await tester.pumpAndSettle();
      final replayButton = find.byKey(const Key('summary-replay'));
      await tester.ensureVisible(replayButton);
      await tester.pumpAndSettle();
      await tester.tap(replayButton);
      await _pumpUntilFound(tester, find.byType(ReplayPage));
      await tester.pumpAndSettle();

      expect(
        tester.widget<IconButton>(find.byKey(const Key('replay-exit'))).tooltip,
        l10n.replayExitToHistoryTooltip,
      );

      await tester.tap(find.byKey(const Key('replay-exit')));
      await _pumpUntilFound(tester, find.byType(MatchSummaryPage));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(MatchSummaryPage),
          matching: find.byTooltip(l10n.historyHomeTooltip),
        ),
      );
      await _pumpUntilFound(tester, find.byType(HistoryPage));
      await tester.pumpAndSettle();
      expect(router.routeInformationProvider.value.uri.path, '/history');
    },
  );
}

Widget _routerHost(
  AppDatabase database,
  GoRouter router, {
  MatchRepository? repository,
  MatchCommandService? commandService,
  AutomaticBackupService? automaticBackup,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(database),
      if (repository != null)
        matchRepositoryProvider.overrideWithValue(repository),
      if (commandService != null)
        matchCommandServiceProvider.overrideWithValue(commandService),
      if (automaticBackup != null)
        automaticBackupServiceProvider.overrideWithValue(automaticBackup),
    ],
    child: MaterialApp.router(
      theme: buildHoopitoTheme(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    ),
  );
}

class _FlakyReplayRepository extends MatchRepository {
  _FlakyReplayRepository(this.database, this.responses) : super(database);

  final AppDatabase database;
  final List<Object?> responses;
  var _index = 0;

  @override
  Future<MatchDetail?> getMatchDetail(String matchId) async {
    final response = responses[_index++];
    if (response is Object && response is! MatchDetail) {
      throw response;
    }
    return response as MatchDetail?;
  }
}

class _PendingReplayRepository extends MatchRepository {
  _PendingReplayRepository(super.database);

  final _responses = <String, List<Future<MatchDetail?>>>{};
  var pendingRequests = 0;

  void enqueue(String matchId, Future<MatchDetail?> response) {
    (_responses[matchId] ??= []).add(response);
  }

  @override
  Future<MatchDetail?> getMatchDetail(String matchId) {
    final responses = _responses[matchId];
    if (responses == null || responses.isEmpty) {
      return super.getMatchDetail(matchId);
    }
    pendingRequests++;
    return responses.removeAt(0);
  }
}

class _CountingReplayRepository extends MatchRepository {
  _CountingReplayRepository(super.database);

  var requests = 0;

  @override
  Future<MatchDetail?> getMatchDetail(String matchId) {
    requests++;
    return super.getMatchDetail(matchId);
  }
}

class _RecordingAutomaticBackupService extends AutomaticBackupService {
  _RecordingAutomaticBackupService(AppDatabase database)
    : super(database, JsonBackupCodec(database, appVersion: 'test'));

  var calls = 0;

  @override
  Future<String?> runAfterMatchFinish() async {
    calls++;
    return null;
  }
}

Future<void> _seedActiveMatch(
  AppDatabase database,
  String matchId, {
  String redName = '红队',
  String blueName = '蓝队',
}) async {
  final now = DateTime.utc(2026, 8, 23, 12);
  await MatchCommandService(database).start(
    StartMatchCommand(
      commandId: '$matchId-start',
      matchId: matchId,
      redName: redName,
      blueName: blueName,
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: '自由计分',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      trackingCoverage: TrackingCoverage.scoresOnly,
      createdAt: now,
      startedAt: now,
    ),
  );
}

Future<void> _seedFinishedMatch(
  AppDatabase database,
  String matchId, {
  String redName = '红队',
  String blueName = '蓝队',
}) async {
  final service = MatchCommandService(database);
  final now = DateTime.utc(2026, 8, 23, 12);
  await service.start(
    StartMatchCommand(
      commandId: '$matchId-start',
      matchId: matchId,
      redName: redName,
      blueName: blueName,
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: '自由计分',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      trackingCoverage: TrackingCoverage.scoresOnly,
      createdAt: now,
      startedAt: now,
    ),
  );
  await service.finish(
    FinishMatchCommand(
      matchId: matchId,
      endedAt: now.add(const Duration(minutes: 5)),
      confirmFinalScore: true,
      expectedRedScore: 0,
      expectedBlueScore: 0,
    ),
  );
}

Future<void> _eventually(bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (predicate()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  fail('Timed out waiting for provider update.');
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (predicate()) return;
  }
  fail('Timed out waiting for test state.');
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder');
}
