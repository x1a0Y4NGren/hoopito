import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hoopito/app/app_providers.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/app/provider_router.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_series.dart'
    show SeriesStartContext;
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/history/history_page.dart';
import 'package:hoopito/features/series/series_detail_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

const _seriesId = 'close-series';
const _matchId = 'close-game';
const _summaryPath = '/matches/close-game/summary';
const _seriesPath = '/series/close-series';
const _summaryClose = Key('summary-series-close');
const _confirmClose = Key('series-close-confirm');

void main() {
  testWidgets('canceling summary close keeps the series open on its summary', (
    tester,
  ) async {
    final fixture = await _mount(tester);
    await _tap(tester, _summaryClose);
    expect(find.byType(AlertDialog), findsOneWidget);
    final l10n = AppLocalizations.of(tester.element(find.byType(AlertDialog)))!;
    await tester.tap(find.widgetWithText(TextButton, l10n.cancelAction));
    await tester.pumpAndSettle();

    expect(fixture.path, _summaryPath);
    expect(find.byType(MatchSummaryPage), findsOneWidget);
    expect(find.byType(SeriesDetailPage), findsNothing);
    expect(find.byType(AlertDialog), findsNothing);
    expect(_closeButton(tester).onPressed, isNotNull);
    final row = await fixture.database
        .select(fixture.database.matchSeries)
        .getSingle();
    expect(row.lifecycle, 'open');
    expect(row.revision, 1);
    expect(row.closedAt, isNull);
    expect(jsonDecode(row.lifecycleIntentsJson), isEmpty);
    await _expectUnchangedGame(fixture);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed summary close stays put and retry opens the closed group',
    (tester) async {
      final fixture = await _mount(tester);
      await fixture.database.customStatement('''
      CREATE TEMP TRIGGER reject_series_close
      BEFORE UPDATE OF lifecycle ON match_series
      WHEN NEW.lifecycle = 'closed'
      BEGIN
        SELECT RAISE(ABORT, 'Controlled close failure');
      END
    ''');
      await _tap(tester, _summaryClose);
      await _tap(tester, _confirmClose);
      await _until(tester, () => find.byType(SnackBar).evaluate().isNotEmpty);

      expect(fixture.path, _summaryPath);
      expect(find.byType(MatchSummaryPage), findsOneWidget);
      expect(find.byType(SeriesDetailPage), findsNothing);
      expect(_closeButton(tester).onPressed, isNotNull);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(MatchSummaryPage)),
      )!;
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(l10n.actionFailedRetry),
        ),
        findsOneWidget,
      );
      final failed = await fixture.database
          .select(fixture.database.matchSeries)
          .getSingle();
      expect(failed.lifecycle, 'open');
      expect(failed.revision, 1);
      expect(failed.closedAt, isNull);
      expect(jsonDecode(failed.lifecycleIntentsJson), isEmpty);
      await _expectUnchangedGame(fixture);

      await fixture.database.customStatement(
        'DROP TRIGGER reject_series_close',
      );
      await _tap(tester, _summaryClose);
      await _tap(tester, _confirmClose);
      await _until(
        tester,
        () => find.byType(SeriesDetailPage).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(fixture.path, _seriesPath);
      expect(find.byKey(const Key('series-reopen')), findsOneWidget);
      expect(find.byKey(const Key('series-close')), findsNothing);
      await _expectClosedOnce(fixture);

      // Returning must not reveal the summary that initiated the close.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await _until(
        tester,
        () => find.byType(HistoryPage).evaluate().isNotEmpty,
      );
      expect(fixture.path, '/history');
      expect(find.byType(MatchSummaryPage), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'summary close waits for persistence and ignores repeated presses',
    (tester) async {
      final fixture = await _mount(tester);
      final closeAgain = _closeButton(tester).onPressed!;
      final closeFinder = find.byKey(_summaryClose);
      await tester.ensureVisible(closeFinder);
      await tester.pumpAndSettle();
      // Two events before a rebuild must create just one confirmation.
      await tester.tap(closeFinder);
      closeAgain();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      final entered = Completer<void>();
      final release = Completer<void>();
      final heldTransaction = fixture.database.transaction(() async {
        await fixture.database.select(fixture.database.matchSeries).getSingle();
        entered.complete();
        await release.future;
      });
      await _until(tester, () => entered.isCompleted);
      try {
        await _tap(tester, _confirmClose);
        await tester.runAsync(() => Future<void>(() {}));
        await tester.pump(const Duration(milliseconds: 500));
        expect(fixture.path, _summaryPath);
        expect(find.byType(MatchSummaryPage), findsOneWidget);
        expect(find.byType(SeriesDetailPage), findsNothing);
        expect(_closeButton(tester).onPressed, isNull);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const Key('summary-series-next')),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester
              .widget<OutlinedButton>(
                find.byKey(const Key('summary-series-settings')),
              )
              .onPressed,
          isNull,
        );
        // A queued callback from the old frame must obey the same busy guard.
        closeAgain();
        await tester.pump();
        expect(find.byType(AlertDialog), findsNothing);
        expect(fixture.path, _summaryPath);
      } finally {
        release.complete();
        await heldTransaction;
      }

      await _until(
        tester,
        () => find.byType(SeriesDetailPage).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(fixture.path, _seriesPath);
      expect(find.byKey(const Key('series-reopen')), findsOneWidget);
      await _expectClosedOnce(fixture);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('system Back after summary close opens History', (tester) async {
    final fixture = await _mount(tester);
    await _tap(tester, _summaryClose);
    await _tap(tester, _confirmClose);
    await _until(
      tester,
      () => find.byType(SeriesDetailPage).evaluate().isNotEmpty,
    );
    expect(fixture.path, _seriesPath);
    expect(fixture.router.canPop(), isFalse);

    await _tap(tester, const ValueKey('series-game-1'));
    await _until(
      tester,
      () => find.byType(MatchSummaryPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back));
    await _until(
      tester,
      () => find.byType(SeriesDetailPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(fixture.router.canPop(), isFalse);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(fixture.path, '/history');
    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.byType(MatchSummaryPage), findsNothing);
    await _expectClosedOnce(fixture);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back from a pushed group returns to its prior page', (
    tester,
  ) async {
    final fixture = await _mount(tester, initialPath: _seriesPath);
    fixture.router.go('/history');
    await _until(tester, () => find.byType(HistoryPage).evaluate().isNotEmpty);
    unawaited(fixture.router.push<void>(_seriesPath));
    await _until(
      tester,
      () => find.byType(SeriesDetailPage).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
    expect(fixture.router.canPop(), isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(fixture.path, '/history');
    expect(find.byType(HistoryPage), findsOneWidget);
    expect(find.byType(SeriesDetailPage), findsNothing);
    final row = await fixture.database
        .select(fixture.database.matchSeries)
        .getSingle();
    expect(row.lifecycle, 'open');
    expect(row.revision, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing directly on group detail refreshes that same route', (
    tester,
  ) async {
    final fixture = await _mount(tester, initialPath: _seriesPath);
    await _tap(tester, const Key('series-close'));
    await _tap(tester, _confirmClose);
    await _until(
      tester,
      () => find.byKey(const Key('series-reopen')).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(fixture.path, _seriesPath);
    expect(find.byType(SeriesDetailPage), findsOneWidget);
    expect(find.byType(MatchSummaryPage), findsNothing);
    expect(find.byKey(const Key('series-close')), findsNothing);
    expect(find.byKey(const Key('series-next')), findsNothing);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SeriesDetailPage)),
    )!;
    expect(
      tester.widget<Text>(find.byKey(const Key('series-status'))).data,
      l10n.seriesClosed,
    );
    expect(find.byKey(const Key('series-game-1')), findsOneWidget);
    await _expectClosedOnce(fixture);
    expect(tester.takeException(), isNull);
  });
}

class _Fixture {
  _Fixture(this.database, this.router);
  final AppDatabase database;
  final GoRouter router;
  String get path => router.routeInformationProvider.value.uri.path;
}

Future<_Fixture> _mount(
  WidgetTester tester, {
  String initialPath = _summaryPath,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final database = AppDatabase.inMemory();
  final router = buildProviderAppRouter();
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    router.dispose();
    await tester.runAsync(database.close);
  });
  final service = MatchCommandService(database);
  await service.start(
    StartMatchCommand(
      matchId: _matchId,
      redName: 'Alex',
      blueName: 'Bo',
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      createdAt: DateTime.utc(2026, 11, 3, 7, 59),
      startedAt: DateTime.utc(2026, 11, 3, 7, 59),
      seriesContext: const SeriesStartContext(
        seriesId: _seriesId,
        expectedRevision: 0,
        gameNumber: 1,
        create: true,
      ),
    ),
  );
  await service.record(
    RecordMatchEventCommand(
      matchId: _matchId,
      side: TeamSide.red,
      points: 2,
      occurredAt: DateTime.utc(2026, 11, 3, 8),
    ),
  );
  await service.finish(
    FinishMatchCommand(
      matchId: _matchId,
      endedAt: DateTime.utc(2026, 11, 3, 8, 1),
      confirmFinalScore: true,
    ),
  );
  router.go(initialPath);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
      child: MaterialApp.router(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: router,
      ),
    ),
  );
  final closeKey = initialPath == _summaryPath
      ? _summaryClose
      : const Key('series-close');
  await _until(tester, () {
    final finder = find.byKey(closeKey);
    return finder.evaluate().isNotEmpty &&
        tester.widget<OutlinedButton>(finder).onPressed != null;
  });
  await tester.pumpAndSettle();
  return _Fixture(database, router);
}

OutlinedButton _closeButton(WidgetTester tester) =>
    tester.widget<OutlinedButton>(find.byKey(_summaryClose));

Future<void> _expectClosedOnce(_Fixture fixture) async {
  final row = await fixture.database
      .select(fixture.database.matchSeries)
      .getSingle();
  expect(row.lifecycle, 'closed');
  expect(row.revision, 2);
  expect(row.closedAt, isNotNull);
  expect(jsonDecode(row.lifecycleIntentsJson), hasLength(1));
  await _expectUnchangedGame(fixture);
}

Future<void> _expectUnchangedGame(_Fixture fixture) async {
  final database = fixture.database;
  final series = (await MatchSeriesRepository(database).getSeries(_seriesId))!;
  expect(series.games, hasLength(1));
  expect(series.games.single.matchId, _matchId);
  expect(series.games.single.gameNumber, 1);
  expect(series.games.single.slotAScore, 2);
  expect(series.games.single.slotBScore, 0);
  expect(series.slotAWins, 1);
  expect(series.slotBWins, 0);
  expect(series.nextGameNumber, 2);
  expect(await database.select(database.matches).get(), hasLength(1));
  expect(await database.select(database.activeSessions).get(), isEmpty);
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _until(tester, () => finder.evaluate().isNotEmpty);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _until(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    await tester.runAsync(() => Future<void>(() {}));
    await tester.pump(const Duration(milliseconds: 20));
    if (ready()) return;
  }
  fail('Timed out waiting for the series close route state.');
}
