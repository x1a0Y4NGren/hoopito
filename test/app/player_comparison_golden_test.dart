import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/players/player_comparison_controller.dart';
import 'package:hoopito/features/players/player_comparison_page.dart';

import '../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  testWidgets(
    'golden player comparison zh light compact',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final controller = PlayerComparisonController(
        playerId: 'golden-player',
        asOfUtc: DateTime.utc(2026, 8, 29),
        listMatches: (_) async => [
          PlayerComparisonMatch(
            matchId: 'golden-current',
            playedAtUtc: DateTime.utc(2026, 8, 28),
            opponentPlayerId: 'golden-opponent-b',
            opponentNameSnapshot: '北辰',
            playerScore: 11,
            opponentScore: 8,
          ),
          PlayerComparisonMatch(
            matchId: 'golden-baseline',
            playedAtUtc: DateTime.utc(2026, 8, 20),
            opponentPlayerId: 'golden-opponent-a',
            opponentNameSnapshot: '阿岚',
            playerScore: 8,
            opponentScore: 11,
          ),
        ],
        compare: (_) async => _report(),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          theme: buildHoopitoTheme(brightness: Brightness.light),
          home: RepaintBoundary(
            key: const Key('player-comparison-golden-root'),
            child: PlayerComparisonPage(
              controller: controller,
              player: Player(
                id: 'golden-player',
                nickname: '飞鱼',
                createdAt: DateTime.utc(2026, 1, 1),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('player-comparison-golden-root')),
        matchesGoldenFile(
          hoopitoGoldenFile('player_comparison_zh_light_compact'),
        ),
      );
      expect(tester.takeException(), isNull);
    },
    skip: !Platform.isWindows && !Platform.isLinux,
  );
}

PlayerComparisonReport _report() {
  return PlayerComparisonReportBuilder().build(
    mode: PlayerComparisonMode.matchPair,
    baseline: _sample(
      'golden-baseline',
      pointsFor: 8,
      pointsAgainst: 11,
      made: 3,
      attempts: 8,
      paint: 1,
      wing: 3,
    ),
    current: _sample(
      'golden-current',
      pointsFor: 11,
      pointsAgainst: 8,
      made: 5,
      attempts: 10,
      paint: 3,
      wing: 2,
    ),
  );
}

PlayerComparisonSample _sample(
  String id, {
  required int pointsFor,
  required int pointsAgainst,
  required int made,
  required int attempts,
  required int paint,
  required int wing,
}) => PlayerComparisonSample(
  startUtc: DateTime.utc(2026, 8, id.endsWith('baseline') ? 20 : 28),
  endUtc: DateTime.utc(2026, 8, id.endsWith('baseline') ? 20 : 28),
  matchIds: [id],
  wins: pointsFor > pointsAgainst ? 1 : 0,
  pointsFor: pointsFor,
  pointsAgainst: pointsAgainst,
  fieldGoalMade: made,
  fieldGoalAttempts: attempts,
  freeThrowMade: 2,
  freeThrowAttempts: 2,
  trustworthyAttemptMatchCount: 1,
  confirmedLocationCount: 4,
  locatableAttemptCount: 6,
  zoneDistribution: {ShotZone.paint: paint, ShotZone.wingThree: wing},
);
