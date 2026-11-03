import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/app_database.dart' show AppDatabase;
import 'package:hoopito/core/data/repositories/match_series_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_series.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/settings/scoring_guide_preferences.dart';
import 'package:hoopito/features/history/history_page.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';
import 'package:hoopito/features/series/series_detail_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

/// Exercises the actual routed UI against an injected real database. Both
/// Flutter's regression suite and isolated Android use this same journey.
Future<void> runContinuousSeriesJourney(
  WidgetTester tester,
  AppDatabase database,
) async {
  await ScoringGuidePreferences(database).markSeen();
  final repository = MatchSeriesRepository(database);
  await tester.pumpWidget(
    HoopitoApp(database: database, showEntryAnimation: false),
  );
  await _wait(tester, find.byKey(homeStartScoringKey));
  await _tap(tester, homeStartScoringKey);
  await _wait(tester, find.byType(PregamePage));
  await _tap(tester, const Key('pregame-mode-series'));
  await tester.enterText(find.byKey(const Key('pregame-red-name')), '系列甲');
  await tester.enterText(find.byKey(const Key('pregame-blue-name')), '系列乙');
  await _tap(tester, const Key('pregame-start-match'));
  await _wait(tester, find.byType(ScoringPage));
  await _pickLocation(tester, CourtPoint(x: .5, y: .5));
  await _tap(tester, const Key('red-score-2'));
  await _finish(tester);
  var series = (await repository.getOpenSeries())!;
  expect(series.games, hasLength(1));
  expect(series.slotAWins, 1);
  expect(series.slotBWins, 0);
  expect(
    series.games.single.detail.match.trackingCoverage,
    TrackingCoverage.scoresOnly,
  );

  await _tap(tester, const Key('summary-series-next'));
  await _wait(tester, find.byType(ScoringPage));
  series = (await repository.getOpenSeries())!;
  expect(series.games, hasLength(2));
  expect(series.games.last.slotAScore, 0);
  expect(series.games.last.slotBScore, 0);
  await _pickLocation(tester, CourtPoint(x: .25, y: .6));
  await _tap(tester, const Key('blue-score-3'));
  await _finish(tester);
  series = (await repository.getOpenSeries())!;
  expect(series.slotAWins, 1);
  expect(series.slotBWins, 1);

  await _tap(tester, const Key('summary-series-settings'));
  await _wait(tester, find.byType(PregamePage));
  expect(find.byKey(const Key('pregame-red-name')), findsNothing);
  expect(find.byKey(const Key('pregame-blue-name')), findsNothing);
  expect(
    tester.widget<PregamePage>(find.byType(PregamePage)).lockedPair,
    isTrue,
  );
  for (final name in ['系列甲', '系列乙']) {
    expect(
      find.descendant(
        of: find.byType(PregamePage),
        matching: find.textContaining(name),
      ),
      findsOneWidget,
    );
  }
  await _tap(tester, const Key('pregame-swap-sides'));
  await _tap(tester, const Key('pregame-start-match'));
  await _wait(tester, find.byType(ScoringPage));
  series = (await repository.getOpenSeries())!;
  expect(series.games.last.detail.match.redName, '系列乙');
  expect(series.games.last.detail.match.blueName, '系列甲');
  await _finish(tester);
  series = (await repository.getOpenSeries())!;
  expect(series.draws, 1);
  expect(series.completedGames, 3);
  expect(series.nextGameNumber, 4);

  await _tap(tester, const Key('summary-series-close'));
  await _wait(tester, find.byKey(const Key('series-close-confirm')));
  await _tap(tester, const Key('series-close-confirm'));
  await _waitCondition(
    tester,
    () async => await repository.getOpenSeries() == null,
  );
  final closed = (await repository.getSeries(series.id))!;
  expect(closed.isOpen, isFalse);
  expect(closed.slotAWins, 1);
  expect(closed.slotBWins, 1);

  // Closing the group must show every game without an extra navigation tap.
  await _wait(tester, find.byType(SeriesDetailPage));
  expect(find.byType(MatchSummaryPage), findsNothing);
  for (var number = 1; number <= 3; number++) {
    expect(find.byKey(ValueKey('series-game-$number')), findsOneWidget);
  }
  await _reviewEachGame(tester, closed);

  // Close clears the old scoring/summary stack. Back opens History, where the
  // same closed group and all of its individual replays remain reachable.
  await _backFrom(tester, SeriesDetailPage);
  await _wait(tester, find.byType(HistoryPage));
  await _tap(tester, const Key('history-mode-series'));
  await _tap(tester, ValueKey('series-${series.id}'));
  await _wait(tester, find.byType(SeriesDetailPage));
  await _reviewEachGame(tester, closed);
  await _tap(tester, const Key('series-reopen'));
  await _waitCondition(
    tester,
    () async => (await repository.getSeries(series.id))!.isOpen,
  );
  expect(await database.select(database.activeSessions).get(), isEmpty);
  expect((await repository.getSeries(series.id))!.games, hasLength(3));
  expect(find.byKey(const Key('series-next')), findsOneWidget);
  expect(find.byKey(const Key('series-reopen')), findsNothing);
  expect(tester.takeException(), isNull);
}

Future<void> _pickLocation(WidgetTester tester, CourtPoint point) async {
  final court = find.byKey(const Key('scoring-court'));
  final local = HalfCourtGeometry.pointToOffset(point, tester.getSize(court));
  await tester.tapAt(tester.getTopLeft(court) + local);
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _reviewEachGame(WidgetTester tester, MatchSeries series) async {
  for (final game in series.games) {
    final expected = switch (game.gameNumber) {
      1 => (red: 2, blue: 0, points: 2, x: .5, y: .5),
      2 => (red: 0, blue: 3, points: 3, x: .25, y: .6),
      3 => (red: 0, blue: 0, points: 0, x: .0, y: .0),
      _ => throw StateError('Unexpected game number in three-game fixture'),
    };
    await _tap(tester, ValueKey('series-game-${game.gameNumber}'));
    await _wait(tester, find.byType(MatchSummaryPage));
    final summary = tester.widget<MatchSummaryPage>(
      find.byType(MatchSummaryPage),
    );
    expect(summary.detail.match.id, game.matchId);
    expect(summary.detail.redScore, expected.red);
    expect(summary.detail.blueScore, expected.blue);
    await _tap(tester, const Key('summary-replay'));
    await _wait(tester, find.byType(ReplayPage));
    final replay = tester.widget<ReplayPage>(find.byType(ReplayPage));
    final data = replay.controller.data;
    expect(data.matchId, game.matchId);
    expect(data.redScore, expected.red);
    expect(data.blueScore, expected.blue);
    expect(data.redName, game.gameNumber == 3 ? '系列乙' : '系列甲');
    expect(data.blueName, game.gameNumber == 3 ? '系列甲' : '系列乙');
    final scores = data.events.where((e) => e.kind == ReplayEventKind.score);
    if (game.gameNumber == 3) {
      expect(scores, isEmpty);
      expect(data.events.where((e) => e.shotPoint != null), isEmpty);
    } else {
      expect(scores, hasLength(1));
      final score = scores.single;
      expect(score.points, expected.points);
      expect(score.side, game.gameNumber == 1 ? TeamSide.red : TeamSide.blue);
      expect(score.locationId, isNotNull);
      expect(score.shotPoint?.x, closeTo(expected.x, .001));
      expect(score.shotPoint?.y, closeTo(expected.y, .001));
    }
    await _tap(tester, const Key('replay-exit'));
    await _wait(tester, find.byType(MatchSummaryPage));
    expect(
      tester
          .widget<MatchSummaryPage>(find.byType(MatchSummaryPage))
          .detail
          .match
          .id,
      game.matchId,
    );
    await _backFrom(tester, MatchSummaryPage);
    await _wait(tester, find.byType(SeriesDetailPage));
  }
}

Future<void> _backFrom(WidgetTester tester, Type page) async {
  final back = find.descendant(
    of: find.byType(page),
    matching: find.widgetWithIcon(IconButton, Icons.arrow_back),
  );
  await tester.ensureVisible(back);
  await tester.tap(back);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _finish(WidgetTester tester) async {
  await _tap(tester, const Key('scoring-finish'));
  await _wait(tester, find.byKey(const Key('match-controls-finish')));
  await _tap(tester, const Key('match-controls-finish'));
  await _wait(tester, find.byKey(const Key('scoring-finish-confirm')));
  expect(
    tester
        .widget<SwitchListTile>(
          find.byKey(const Key('confirm-complete-recording')),
        )
        .value,
    isFalse,
  );
  await _tap(tester, const Key('scoring-finish-confirm'));
  await _wait(tester, find.byKey(const Key('summary-series-next')));
}

Future<void> _tap(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  await _wait(tester, finder);
  await tester.ensureVisible(finder);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(finder);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> _wait(WidgetTester tester, Finder finder) async {
  await _waitCondition(tester, () async => finder.evaluate().isNotEmpty);
}

Future<void> _waitCondition(
  WidgetTester tester,
  Future<bool> Function() ready,
) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 40));
    if (await ready()) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Continuous series journey did not reach the expected state.');
}
