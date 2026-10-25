import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations_zh.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/automatic_backup_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:go_router/go_router.dart';

import '../test_helpers/test_database.dart';

void main() {
  final l10n = AppLocalizationsZh();

  testWidgets(
    'production decision finish commits then opens result and replay',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(3000, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 200));
      });
      await _seedDecision(database, 'route-finish');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const HoopitoApp(showEntryAnimation: false),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
      await _tapVisible(tester, find.byKey(const Key('home-resume')));
      await _pumpUntilFound(tester, find.byType(ScoringPage));
      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);

      await tester.ensureVisible(
        find.byKey(const Key('scoring-decision-finish')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('scoring-decision-finish')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Red 1 : 0 Blue'), findsWidgets);
      await _tapVisible(
        tester,
        find.byKey(const Key('scoring-finish-confirm')),
      );
      await _pumpUntilFound(tester, find.byType(MatchSummaryPage));
      await tester.pumpAndSettle();
      expect(
        GoRouterState.of(
          tester.element(find.byType(MatchSummaryPage)),
        ).uri.path,
        '/matches/route-finish/summary',
      );
      await _tapVisible(tester, find.byKey(const Key('summary-replay')));
      await _pumpUntilFound(tester, find.byType(ReplayPage));
      await _pumpUntilFound(tester, find.text(l10n.replayFinished));
      expect(find.byKey(const Key('replay-finish-match')), findsNothing);

      final match = await database.select(database.matches).getSingle();
      expect(match.lifecycle, MatchLifecycle.finished.name);
      expect(await database.select(database.activeSessions).get(), isEmpty);
    },
  );

  testWidgets('production manual finish commits and opens canonical result', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1095, 616));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
      await database.close();
    });
    await _seedOpenMatch(MatchCommandService(database), 'route-manual-finish');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await _tapVisible(tester, find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    expect(find.byKey(const Key('scoring-decision-dock')), findsNothing);

    await _tapVisible(tester, find.byKey(const Key('scoring-finish')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('match-controls-finish')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Red 1 : 0 Blue'), findsOneWidget);
    await _tapVisible(tester, find.byKey(const Key('scoring-finish-confirm')));
    await _pumpUntilFound(tester, find.byType(MatchSummaryPage));
    await tester.pumpAndSettle();

    final match = await database.select(database.matches).getSingle();
    expect(match.lifecycle, MatchLifecycle.finished.name);
    expect(await database.select(database.activeSessions).get(), isEmpty);
    expect(
      GoRouterState.of(tester.element(find.byType(MatchSummaryPage))).uri.path,
      '/matches/route-manual-finish/summary',
    );
    await _tapVisible(tester, find.byKey(const Key('summary-replay')));
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    await _pumpUntilFound(tester, find.text(l10n.replayFinished));
  });

  testWidgets('production decision continue keeps the match active', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(3000, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    });
    await _seedDecision(database, 'route-continue');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await _tapVisible(tester, find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    await tester.ensureVisible(
      find.byKey(const Key('scoring-decision-continue')),
    );
    await _tapVisible(
      tester,
      find.byKey(const Key('scoring-decision-continue')),
    );
    await _pumpUntilMissing(
      tester,
      find.byKey(const Key('scoring-decision-dock')),
    );

    final match = await database.select(database.matches).getSingle();
    expect(match.lifecycle, MatchLifecycle.active.name);
    expect(await database.select(database.activeSessions).get(), hasLength(1));
    expect(find.byType(ScoringPage), findsOneWidget);
  });

  testWidgets('pending scoring finish stays Home after leaving the route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(3000, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    });
    await _seedDecision(database, 'route-finish-pending-home');
    final finishReleased = Completer<void>();
    var finishStarted = false;
    final service = MatchCommandService(
      database,
      failureInjector: (point) async {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          finishStarted = true;
          await finishReleased.future;
        }
      },
    );
    final backup = _RecordingAutomaticBackupService(database);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(service),
          automaticBackupServiceProvider.overrideWithValue(backup),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await _tapVisible(tester, find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    final router = _routerFrom(tester);
    await _tapVisible(tester, find.byKey(const Key('scoring-decision-finish')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('scoring-finish-confirm')));
    await _pumpUntil(tester, () => finishStarted);

    router.go('/');
    await tester.pump();
    finishReleased.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();
    await _pumpUntilFound(tester, find.byType(HomePage));

    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(find.byType(ReplayPage), findsNothing);
    expect(
      (await database.select(database.matches).getSingle()).lifecycle,
      MatchLifecycle.finished.name,
    );
    await _pumpUntil(tester, () => backup.calls == 1);
  });

  testWidgets('pending scoring finish stays on a switched scoring route', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(3000, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createTestDatabase();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 200));
    });
    const matchId = 'route-finish-pending-switch';
    await _seedDecision(database, matchId);
    final finishReleased = Completer<void>();
    var finishStarted = false;
    final service = MatchCommandService(
      database,
      failureInjector: (point) async {
        if (point == MatchCommandFailurePoint.beforeCommit) {
          finishStarted = true;
          await finishReleased.future;
        }
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          matchCommandServiceProvider.overrideWithValue(service),
        ],
        child: const HoopitoApp(showEntryAnimation: false),
      ),
    );
    await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
    await _tapVisible(tester, find.byKey(const Key('home-resume')));
    await _pumpUntilFound(tester, find.byType(ScoringPage));
    final router = _routerFrom(tester);
    await _tapVisible(tester, find.byKey(const Key('scoring-decision-finish')));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.byKey(const Key('scoring-finish-confirm')));
    await _pumpUntil(tester, () => finishStarted);

    const switchedMatchId = 'route-finish-pending-switch-target';
    router.go('/scoring/$switchedMatchId?source=pending-finish');
    await tester.pump();
    finishReleased.complete();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 30)),
    );
    await tester.pump();

    expect(
      router.routeInformationProvider.value.uri.path,
      '/scoring/$switchedMatchId',
    );
    expect(find.byType(ReplayPage), findsNothing);
    expect(
      (await database.select(database.matches).getSingle()).lifecycle,
      MatchLifecycle.finished.name,
    );
  });

  testWidgets(
    'production decision continue failure stays visible and retries',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(3000, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 200));
      });
      await _seedDecision(database, 'route-continue-retry');
      var failNext = true;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
            failNext = false;
            throw StateError('continue failed once');
          }
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            matchCommandServiceProvider.overrideWithValue(service),
          ],
          child: const HoopitoApp(showEntryAnimation: false),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
      await _tapVisible(tester, find.byKey(const Key('home-resume')));
      await _pumpUntilFound(tester, find.byType(ScoringPage));
      await tester.ensureVisible(
        find.byKey(const Key('scoring-decision-continue')),
      );
      await _tapVisible(
        tester,
        find.byKey(const Key('scoring-decision-continue')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('scoring-decision-dock')), findsOneWidget);
      expect(find.byType(SnackBarAction), findsOneWidget);
      tester.widget<SnackBarAction>(find.byType(SnackBarAction)).onPressed();
      await tester.pump();
      await _pumpUntilMissing(
        tester,
        find.byKey(const Key('scoring-decision-dock')),
      );

      final match = await database.select(database.matches).getSingle();
      expect(match.lifecycle, MatchLifecycle.active.name);
    },
  );

  testWidgets(
    'replay refreshes a stale confirmed score before retrying finish',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(3000, 1080));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final database = createTestDatabase();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 200));
      });
      final service = MatchCommandService(database);
      await _seedOpenMatch(service, 'route-stale-score');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const HoopitoApp(showEntryAnimation: false),
        ),
      );
      await _pumpUntilFound(tester, find.byKey(const Key('home-resume')));
      await _tapVisible(tester, find.byKey(const Key('home-resume')));
      await _pumpUntilFound(tester, find.byType(ScoringPage));
      await tester.pumpAndSettle();
      await _tapVisible(tester, find.byKey(const Key('scoring-more')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('more-replay')));
      final sheetScrollable = find.descendant(
        of: find.byKey(const Key('scoring-more-sheet')),
        matching: find.byType(Scrollable),
      );
      final viewport = tester.binding.renderViews.first.size;
      await tester.dragFrom(
        Offset(viewport.width / 2, viewport.height / 2),
        const Offset(0, -400),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('more-replay')),
        500,
        scrollable: sheetScrollable,
      );
      await _tapVisible(tester, find.byKey(const Key('more-replay')));
      await _pumpUntilFound(tester, find.byType(ReplayPage));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('replay-finish-match')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Red 1 : 0 Blue'), findsOneWidget);

      await service.record(
        RecordMatchEventCommand(
          commandId: 'route-stale-score-concurrent-command',
          matchId: 'route-stale-score',
          eventId: 'route-stale-score-concurrent-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 23, 9, 2),
        ),
      );
      await _tapVisible(tester, find.byKey(const Key('replay-finish-confirm')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.actionFailedRetry), findsOneWidget);
      expect(find.byKey(const Key('replay-finish-match')), findsOneWidget);

      await _tapVisible(tester, find.byKey(const Key('replay-finish-match')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Red 2 : 0 Blue'), findsOneWidget);
      await _tapVisible(tester, find.byKey(const Key('replay-finish-confirm')));
      await _pumpUntilFound(tester, find.text(l10n.replayFinished));

      final match = await database.select(database.matches).getSingle();
      expect(match.lifecycle, MatchLifecycle.finished.name);
    },
  );
}

GoRouter _routerFrom(WidgetTester tester) {
  final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
  return app.routerConfig! as GoRouter;
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

Future<void> _seedDecision(AppDatabase database, String matchId) async {
  final service = MatchCommandService(database);
  await service.start(
    StartMatchCommand(
      commandId: '$matchId-start',
      matchId: matchId,
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplate: const RuleTemplate(
        id: 'target-one',
        name: 'Target one',
        scoreButtons: [1, 2, 3],
        targetScore: 1,
      ),
      recordingMode: RecordingMode.simple,
      trackingCoverage: TrackingCoverage.scoresOnly,
      createdAt: DateTime.utc(2026, 8, 23, 9),
      startedAt: DateTime.utc(2026, 8, 23, 9),
    ),
  );
  await service.record(
    RecordMatchEventCommand(
      commandId: '$matchId-score',
      matchId: matchId,
      eventId: '$matchId-score-event',
      type: EventKind.fieldGoal,
      side: TeamSide.red,
      points: 1,
      outcome: ShotOutcome.made,
      occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
    ),
  );
}

Future<void> _seedOpenMatch(MatchCommandService service, String matchId) async {
  await service.start(
    StartMatchCommand(
      commandId: '$matchId-start',
      matchId: matchId,
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplate: const RuleTemplate(
        id: 'open-score',
        name: 'Open score',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      trackingCoverage: TrackingCoverage.scoresOnly,
      createdAt: DateTime.utc(2026, 8, 23, 9),
      startedAt: DateTime.utc(2026, 8, 23, 9),
    ),
  );
  await service.record(
    RecordMatchEventCommand(
      commandId: '$matchId-score-command',
      matchId: matchId,
      eventId: '$matchId-score-event',
      type: EventKind.fieldGoal,
      side: TeamSide.red,
      points: 1,
      outcome: ShotOutcome.made,
      occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
    ),
  );
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder');
}

Future<void> _pumpUntilMissing(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (finder.evaluate().isEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for $finder to disappear');
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() predicate) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 20));
    if (predicate()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
  }
  fail('Timed out waiting for test state.');
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}
