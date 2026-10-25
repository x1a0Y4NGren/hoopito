import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/players/player_career_page.dart';
import 'package:hoopito/features/players/player_comparison_page.dart';
import 'package:hoopito/features/players/player_list_page.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'compares two finished matches for a linked player by match and window',
    (tester) async {
      const subjectId = 'integration-comparison-subject';
      const opponentId = 'integration-comparison-opponent';
      const subjectName = '集成主角';
      const opponentName = '集成对手';
      final database = AppDatabase.inMemory();
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await tester.runAsync(database.close);
      });

      final playerRepository = PlayerRepository(database);
      final createdAt = DateTime.now().toUtc();
      await playerRepository.save(
        Player(id: subjectId, nickname: subjectName, createdAt: createdAt),
      );
      await playerRepository.save(
        Player(id: opponentId, nickname: opponentName, createdAt: createdAt),
      );

      await tester.pumpWidget(HoopitoApp(database: database));
      await _pumpUntilFound(tester, find.byKey(homeStartScoringKey));

      await _playAndFinishLinkedMatch(
        tester,
        subjectName: subjectName,
        opponentName: opponentName,
        subjectScores: 1,
      );

      final firstMatch = (await database.select(database.matches).get()).single;
      final baselineStartedAt = DateTime.now().toUtc().subtract(
        const Duration(days: 8),
      );
      await (database.update(
        database.matches,
      )..where((row) => row.id.equals(firstMatch.id))).write(
        MatchesCompanion(
          createdAt: Value(baselineStartedAt),
          startedAt: Value(baselineStartedAt),
          endedAt: Value(baselineStartedAt.add(const Duration(minutes: 1))),
        ),
      );

      await _playAndFinishLinkedMatch(
        tester,
        subjectName: subjectName,
        opponentName: opponentName,
        subjectScores: 2,
      );

      await _tapWhenHitTestable(
        tester,
        find.byType(NavigationDestination).at(2),
        description: 'the Players primary navigation destination',
      );
      await _pumpUntilFound(tester, find.byType(PlayerListPage));
      await _tapWhenHitTestable(
        tester,
        find.byKey(const ValueKey('player-row-$subjectId')),
        description: 'the linked player career row',
      );
      await _pumpUntilFound(tester, find.byType(PlayerCareerPage));
      await _tapWhenHitTestable(
        tester,
        find.byKey(const ValueKey('player-comparison-$subjectId')),
        description: 'the career comparison action',
      );
      await _pumpUntilFound(tester, find.byType(PlayerComparisonPage));

      await _pumpUntilFound(
        tester,
        find.byKey(const Key('comparison-metric-result')),
        description: 'the match-pair comparison report',
      );
      expect(
        find.byKey(const Key('comparison-baseline-selector')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('comparison-current-selector')),
        findsOneWidget,
      );

      await _tapWhenHitTestable(
        tester,
        find.byKey(const Key('comparison-mode-adjacentWindow')),
        description: 'the adjacent-window comparison mode',
      );
      await _tapWhenHitTestable(
        tester,
        find.byKey(const ValueKey('comparison-window-sevenDays')),
        description: 'the seven-day window option',
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const Key('comparison-metric-matchCount')),
        description: 'the adjacent-window comparison report',
      );
      expect(
        find.byKey(const Key('comparison-single-side-empty')),
        findsNothing,
      );

      final snapshots = await (database.select(
        database.playerAnalyticsSnapshots,
      )..where((row) => row.playerId.equals(subjectId))).get();
      expect(snapshots, hasLength(2));
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _playAndFinishLinkedMatch(
  WidgetTester tester, {
  required String subjectName,
  required String opponentName,
  required int subjectScores,
}) async {
  await _tapWhenHitTestable(
    tester,
    find.byKey(homeStartScoringKey),
    description: 'the Home start-scoring action',
  );
  await _pumpUntilFound(tester, find.byType(PregamePage));

  await _selectProfile(
    tester,
    dropdownKey: const Key('pregame-red-profile'),
    playerName: subjectName,
  );
  await _selectProfile(
    tester,
    dropdownKey: const Key('pregame-blue-profile'),
    playerName: opponentName,
  );
  await tester.ensureVisible(find.byKey(const Key('pregame-start-match')));
  await _tapWhenHitTestable(
    tester,
    find.byKey(const Key('pregame-start-match')),
    description: 'the Pregame start-match action',
  );
  await _pumpUntilFound(tester, find.byType(ScoringPage));
  final skipGuide = find.byKey(const Key('scoring-guide-skip'));
  if (skipGuide.evaluate().isNotEmpty) {
    await _tapWhenHitTestable(
      tester,
      skipGuide,
      description: 'the inline scoring guide skip action',
    );
  }

  for (var score = 0; score < subjectScores; score++) {
    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('red-score-2')),
      description: 'the red two-point action',
    );
  }

  await _tapWhenHitTestable(
    tester,
    find.byKey(const Key('scoring-finish')),
    description: 'the scoring finish menu',
  );
  await _pumpUntilFound(tester, find.byKey(const Key('match-controls-finish')));
  await _tapWhenHitTestable(
    tester,
    find.byKey(const Key('match-controls-finish')),
    description: 'the match-controls finish action',
  );
  await _pumpUntilFound(
    tester,
    find.byKey(const Key('scoring-finish-confirm')),
  );
  await _tapWhenHitTestable(
    tester,
    find.byKey(const Key('scoring-finish-confirm')),
    description: 'the scoring finish confirmation',
  );
  await _pumpUntilFound(tester, find.byType(MatchSummaryPage));

  await _tapWhenHitTestable(
    tester,
    find.descendant(
      of: find.byType(MatchSummaryPage),
      matching: find.byIcon(Icons.arrow_back),
    ),
    description: 'the result return action',
  );
  await _pumpUntilFound(tester, find.byType(NavigationBar));
  await _tapWhenHitTestable(
    tester,
    find.byType(NavigationDestination).first,
    description: 'the Matches primary navigation destination',
  );
  await _pumpUntilFound(tester, find.byType(HomePage));
}

Future<void> _selectProfile(
  WidgetTester tester, {
  required Key dropdownKey,
  required String playerName,
}) async {
  await tester.ensureVisible(find.byKey(dropdownKey));
  await _tapWhenHitTestable(
    tester,
    find.byKey(dropdownKey),
    description: 'the player-profile dropdown',
  );
  await _pumpUntilFound(tester, find.text(playerName).last);
  await _tapWhenHitTestable(
    tester,
    find.text(playerName).last,
    description: 'the $playerName profile option',
  );
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  String? description,
  int attempts = 180,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for ${description ?? finder} ($finder).');
}

Future<void> _tapWhenHitTestable(
  WidgetTester tester,
  Finder finder, {
  required String description,
  int attempts = 180,
}) async {
  final hitTestableFinder = finder.hitTestable();
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (hitTestableFinder.evaluate().isNotEmpty) {
      await tester.tap(hitTestableFinder);
      await tester.pump();
      return;
    }
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await tester.pump();
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for $description to become hit-testable ($finder).');
}
