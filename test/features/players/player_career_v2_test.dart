import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/player_career_aggregate.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/players/player_career_controller.dart';
import 'package:hoopito/features/players/player_career_page.dart';

void main() {
  testWidgets('career draws shooting growth and keeps the numeric samples', (
    tester,
  ) async {
    await _pumpCareer(tester, [_sample(0), _sample(1), _sample(2)]);

    expect(find.byKey(const Key('career-growth-chart')), findsOneWidget);
    expect(find.textContaining('FG% in match order'), findsOneWidget);
    expect(find.text('50%'), findsWidgets);
    expect(find.text('100%'), findsWidgets);
  });

  testWidgets('all-time growth displays only the latest thirty samples', (
    tester,
  ) async {
    await _pumpCareer(tester, List.generate(35, _sample));

    expect(find.text('Showing the latest 30 of 35 games'), findsOneWidget);
    expect(find.byKey(const ValueKey('career-trend-match-0')), findsNothing);
    expect(find.byKey(const ValueKey('career-trend-match-4')), findsNothing);
    expect(find.byKey(const ValueKey('career-trend-match-5')), findsOneWidget);
    expect(find.byKey(const ValueKey('career-trend-match-34')), findsOneWidget);
  });

  testWidgets(
    'incomplete shooting leaves a visible gap and keeps recorded counts',
    (tester) async {
      var middle = _sample(1);
      middle = PlayerCareerShootingTrend(
        matchId: middle.matchId,
        playedAt: middle.playedAt,
        fieldGoalMade: 3,
        fieldGoalAttempts: 3,
        freeThrowMade: 1,
        freeThrowAttempts: 1,
        recordedAttempts: 4,
        recordedMakes: 4,
        isTrustworthy: false,
      );
      final pixelsWithGap = await _middleColumn(tester, [
        _sample(0),
        middle,
        _sample(2),
      ]);
      expect(pixelsWithGap, 0);
      final row = find.byKey(const ValueKey('career-trend-match-1'));
      expect(
        find.descendant(of: row, matching: find.text('—')),
        findsNWidgets(2),
      );
      expect(
        find.descendant(of: row, matching: find.text('100%')),
        findsNothing,
      );
      expect(
        find.descendant(of: row, matching: find.text('Recorded shots')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('4')),
        findsOneWidget,
      );

      final connectedPixels = await _middleColumn(tester, [
        _sample(0),
        _sample(1),
        _sample(2),
      ]);
      expect(connectedPixels, greaterThan(0));
    },
  );

  testWidgets(
    'trend rows open their source match and masthead exposes edit and fallback back',
    (tester) async {
      final matches = <String>[];
      var backs = 0;
      var edits = 0;
      await _pumpCareer(
        tester,
        [_sample(0), _sample(1)],
        onMatchTap: matches.add,
        onBack: () => backs++,
        onEdit: () => edits++,
      );
      expect(
        Navigator.of(tester.element(find.byType(PlayerCareerPage))).canPop(),
        isFalse,
      );
      final row = find.byKey(const ValueKey('career-trend-match-1'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      expect(matches, ['match-1']);
      await tester.tap(find.byKey(const Key('career-edit')));
      await tester.tap(find.byKey(const Key('career-back')));
      expect(edits, 1);
      expect(backs, 1);
      expect(
        tester.getSize(find.byKey(const Key('career-edit'))).height,
        greaterThanOrEqualTo(48),
      );
    },
  );

  testWidgets('chart states selected scope and localized dates', (
    tester,
  ) async {
    await _pumpCareer(
      tester,
      [_sample(0), _sample(1)],
      query: const PlayerCareerQuery.sevenDays(opponentPlayerId: 'opponent'),
      opponents: [
        Player(id: 'opponent', nickname: 'Alex', createdAt: DateTime.utc(2026)),
      ],
    );
    expect(find.text('Last 7 days · Alex'), findsOneWidget);
    expect(find.text('Aug 1, 2026 – Aug 2, 2026'), findsOneWidget);
    expect(find.text('Showing the latest 2 of 2 games'), findsOneWidget);
  });

  testWidgets(
    'chart and numeric details remain usable at actual 200 percent text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(360, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpCareer(tester, [_sample(0), _sample(1)], textScale: 2);
      await tester.ensureVisible(find.byKey(const Key('career-growth-chart')));
      await tester.ensureVisible(
        find.byKey(const ValueKey('career-trend-match-1')),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpCareer(
  WidgetTester tester,
  List<PlayerCareerShootingTrend> samples, {
  ValueChanged<String>? onMatchTap,
  VoidCallback? onBack,
  VoidCallback? onEdit,
  PlayerCareerQuery query = const PlayerCareerQuery(),
  List<Player> opponents = const [],
  double textScale = 1,
}) async {
  final controller = PlayerCareerController(
    playerId: 'player',
    initialQuery: query,
    loader: (_) => Stream.value(
      PlayerCareerAggregate(
        playerId: 'player',
        matches: samples.length,
        wins: 1,
        totalPoints: 10,
        averagePoints: 5,
        averageMargin: 1,
        shootingTrend: samples,
        recentChange: const PlayerCareerRecentChange(
          latestMatchId: 'match-1',
          previousMatchId: 'match-0',
          latestPoints: 8,
          previousPoints: 6,
          latestMargin: 2,
          previousMargin: 1,
          latestShootingPercentage: .5,
          previousShootingPercentage: .5,
        ),
      ),
    ),
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: PlayerCareerPage(
        controller: controller,
        player: Player(
          id: 'player',
          nickname: 'Player',
          createdAt: DateTime.utc(2026),
        ),
        opponents: opponents,
        onMatchTap: onMatchTap,
        onBack: onBack,
        onEdit: onEdit,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<int> _middleColumn(
  WidgetTester tester,
  List<PlayerCareerShootingTrend> samples,
) async {
  await _pumpCareer(tester, samples);
  final boundaryFinder = find.byKey(const Key('career-growth-chart-image'));
  await tester.ensureVisible(boundaryFinder);
  await tester.pumpAndSettle();
  final boundary = tester.renderObject<RenderRepaintBoundary>(boundaryFinder);
  final snapshot = await tester.runAsync(() => boundary.toImage(pixelRatio: 1));
  final rgba = await tester.runAsync(
    () => snapshot!.toByteData(format: ui.ImageByteFormat.rawRgba),
  );
  final accent = editorialThemeOf(
    tester.element(boundaryFinder),
  ).arenaAccent.toARGB32();
  final x = snapshot!.width ~/ 2;
  var count = 0;
  for (var y = 0; y < snapshot.height; y++) {
    final offset = (y * snapshot.width + x) * 4;
    if (rgba!.getUint8(offset) == ((accent >> 16) & 255) &&
        rgba.getUint8(offset + 1) == ((accent >> 8) & 255) &&
        rgba.getUint8(offset + 2) == (accent & 255) &&
        rgba.getUint8(offset + 3) > 0) {
      count++;
    }
  }
  snapshot.dispose();
  return count;
}

PlayerCareerShootingTrend _sample(int index) => PlayerCareerShootingTrend(
  matchId: 'match-$index',
  playedAt: DateTime.utc(2026, 8, 1).add(Duration(days: index)),
  fieldGoalMade: 3,
  fieldGoalAttempts: 6,
  freeThrowMade: 1,
  freeThrowAttempts: 1,
  recordedAttempts: 7,
  recordedMakes: 4,
  isTrustworthy: true,
);
