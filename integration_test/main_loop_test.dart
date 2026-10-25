import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/data/repositories/player_career_repository.dart';
import 'package:hoopito/core/data/repositories/player_repository.dart';
import 'package:hoopito/core/domain/entities/player.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/replay_image_exporter.dart';
import 'package:hoopito/features/home/home_page.dart';
import 'package:hoopito/features/players/player_career_page.dart';
import 'package:hoopito/features/players/player_list_page.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/replay/replay_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('completes the v2 scoring, summary and player loop', (
    tester,
  ) async {
    final runId = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final redName = '集成红-$runId';
    final blueName = '集成蓝-$runId';
    final playerId = 'integration-profile-$runId';
    final playerName = '集成档案-$runId';
    final database = AppDatabase.inMemory();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.runAsync(database.close);
    });

    await PlayerRepository(database).save(
      Player(
        id: playerId,
        nickname: playerName,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await tester.pumpWidget(HoopitoApp(database: database));
    await _pumpUntilFound(
      tester,
      find.byKey(homeStartScoringKey),
      description: 'the Home start-scoring action',
    );
    await tester.ensureVisible(find.byKey(homeStartScoringKey));
    await tester.pump();

    await _tapWhenHitTestable(
      tester,
      find.byKey(homeStartScoringKey),
      description: 'the Home start-scoring action',
    );
    await _pumpUntilFound(
      tester,
      find.byType(PregamePage),
      description: 'PregamePage after starting a match',
    );

    await tester.enterText(find.byKey(const Key('pregame-red-name')), redName);
    await tester.enterText(
      find.byKey(const Key('pregame-blue-name')),
      blueName,
    );
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.ensureVisible(find.byKey(const Key('pregame-clock-settings')));
    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('pregame-clock-settings')),
      description: 'the collapsed Pregame clock settings',
    );
    await _pumpUntilFound(tester, find.byKey(const Key('pregame-timer')));
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const Key('pregame-timer')))
          .value,
      isFalse,
    );
    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('pregame-coverage-shots')),
      description: 'complete shot-attempt recording',
    );
    await tester.ensureVisible(find.byKey(const Key('pregame-start-match')));
    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('pregame-start-match')),
      description: 'the Pregame start-match action',
    );
    await _pumpUntilFound(
      tester,
      find.byType(ScoringPage),
      description: 'ScoringPage after confirming pregame',
    );
    await _pumpUntilLandscape(tester);
    await _pumpUntilFound(tester, find.byKey(const Key('scoring-guide')));
    expect(find.byType(Dialog), findsNothing);
    expect(find.byKey(const Key('red-score-2')).hitTestable(), findsOneWidget);
    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('scoring-guide-skip')),
      description: 'the inline first-use guide skip action',
    );

    await tester.tap(find.byKey(const Key('red-score-2')));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2 $redName'), findsOneWidget);
    expect(find.text('$blueName 0'), findsOneWidget);

    await tester.tapAt(
      tester.getCenter(find.byKey(const Key('scoring-court'))),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('scoring-finish')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('match-controls-pause')),
      description: 'the scoring match controls',
    );
    await tester.tap(find.byKey(const Key('match-controls-pause')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
      description: 'the blocking paused-match panel',
    );
    expect(find.byKey(const Key('paused-return-home')), findsOneWidget);
    expect(find.byKey(const Key('paused-continue')), findsOneWidget);
    expect(find.byKey(const Key('paused-finish')), findsOneWidget);
    await tester.tap(find.byKey(const Key('paused-continue')));
    await _pumpUntilGone(
      tester,
      find.byKey(const Key('scoring-paused-panel')),
      description: 'the paused-match panel after continuing',
    );

    await tester.tap(find.byKey(const Key('scoring-finish')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('match-controls-finish')),
      description: 'the scoring finish action',
    );
    await tester.tap(find.byKey(const Key('match-controls-finish')));
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('scoring-finish-confirm')),
      description: 'the scoring finish confirmation',
    );
    final completeRecording = find.byKey(
      const Key('confirm-complete-recording'),
    );
    if (!tester.widget<SwitchListTile>(completeRecording).value) {
      await _tapWhenHitTestable(
        tester,
        completeRecording,
        description: 'the final complete-recording declaration',
      );
    }
    await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
    await _pumpUntilFound(
      tester,
      find.byType(MatchSummaryPage),
      description: 'MatchSummaryPage after finishing from ScoringPage',
    );
    final summaryL10n = AppLocalizations.of(
      tester.element(find.byType(MatchSummaryPage)),
    )!;
    expect(find.text(redName), findsAtLeastNWidgets(1));
    expect(find.text(blueName), findsAtLeastNWidgets(1));
    final match = (await database.select(database.matches).get()).single;
    final matchId = match.id;
    expect(match.lifecycle, 'finished');
    expect(match.trackingCoverage, 'shotAttempts');
    expect(await database.select(database.activeSessions).get(), isEmpty);

    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('summary-rematch')),
      description: 'the result rematch action',
    );
    await _pumpUntilFound(tester, find.byType(PregamePage));
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pregame-red-name')))
          .controller!
          .text,
      redName,
    );
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('pregame-blue-name')))
          .controller!
          .text,
      blueName,
    );
    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('pregame-cancel')),
      description: 'the rematch cancel action',
    );
    await _pumpUntilFound(tester, find.byType(MatchSummaryPage));
    expect(await database.select(database.matches).get(), hasLength(1));
    expect(await database.select(database.activeSessions).get(), isEmpty);

    final beforeLink = (await MatchRepository(
      database,
    ).getMatchDetail(matchId))!;
    final participant = beforeLink.match.participants.firstWhere(
      (participant) => participant.side == TeamSide.red,
    );
    await _tapWhenHitTestable(
      tester,
      find.byKey(ValueKey('summary-save-${participant.id}')),
      description: 'the result save-player action',
    );
    await _pumpUntilFound(tester, find.byType(AlertDialog));
    await _tapWhenHitTestable(
      tester,
      find.widgetWithText(ListTile, playerName),
      description: 'the explicitly selected player profile',
    );
    await _pumpUntilGone(tester, find.byType(AlertDialog));
    await _pumpUntilGone(
      tester,
      find.byKey(ValueKey('summary-save-${participant.id}')),
      description: 'the saved participant action',
    );
    final afterLink = (await MatchRepository(
      database,
    ).getMatchDetail(matchId))!;
    expect(afterLink.match.redName, redName);
    expect(
      afterLink.match.participants
          .singleWhere((entry) => entry.id == participant.id)
          .playerProfileId,
      playerId,
    );

    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('summary-share')),
      description: 'the result share preview action',
    );
    await _pumpUntilFound(
      tester,
      find.byKey(const Key('replay-export-summary')),
    );
    final preview = find.byKey(const Key('replay-export-summary'));
    expect(
      find.descendant(of: preview, matching: find.text(redName)),
      findsAtLeastNWidgets(1),
    );
    expect(
      find.descendant(of: preview, matching: find.text(blueName)),
      findsAtLeastNWidgets(1),
    );
    final boundaryFinder = find
        .ancestor(of: preview, matching: find.byType(RepaintBoundary))
        .first;
    final boundary = tester.widget<RepaintBoundary>(boundaryFinder);
    final png = (await tester.runAsync(
      () => ReplayImageExporter.capture(
        boundary.key! as GlobalKey,
        pixelRatio: 1,
      ),
    ))!;
    expect(png.length, greaterThan(1000));
    expect(png.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    await _tapWhenHitTestable(
      tester,
      find.widgetWithText(TextButton, summaryL10n.cancelAction),
      description: 'the share preview cancel action',
    );
    await _pumpUntilGone(tester, preview);
    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('summary-replay')),
      description: 'the result full replay action',
    );
    await _pumpUntilFound(tester, find.byType(ReplayPage));
    final finishedReplayL10n = AppLocalizations.of(
      tester.element(find.byType(ReplayPage)),
    )!;
    expect(find.text(redName), findsAtLeastNWidgets(1));
    expect(find.text(blueName), findsAtLeastNWidgets(1));
    expect(find.text(finishedReplayL10n.replayFinished), findsOneWidget);
    expect(find.byKey(const Key('replay-finish-match')), findsNothing);

    await _tapWhenHitTestable(
      tester,
      find.byKey(const Key('replay-exit')),
      description: 'the full replay return action',
    );
    await _pumpUntilFound(tester, find.byType(MatchSummaryPage));
    await _tapWhenHitTestable(
      tester,
      find.byTooltip(summaryL10n.historyHomeTooltip),
      description: 'the result return action',
    );
    await _pumpUntilFound(
      tester,
      find.byType(NavigationBar),
      description: 'the primary navigation after leaving the result',
    );
    await _tapWhenHitTestable(
      tester,
      find.byType(NavigationDestination).at(2),
      description: 'the Players primary navigation destination',
    );
    await _pumpUntilFound(tester, find.byType(PlayerListPage));
    await _tapWhenHitTestable(
      tester,
      find.byKey(ValueKey('player-row-$playerId')),
      description: 'the saved player career row',
    );
    await _pumpUntilFound(tester, find.byType(PlayerCareerPage));
    final careerPage = tester.widget<PlayerCareerPage>(
      find.byType(PlayerCareerPage),
    );
    await _pumpUntilCondition(
      tester,
      () => careerPage.controller.aggregate?.matches == 1,
      description: 'the saved player career aggregate',
    );
    final career = await PlayerCareerRepository(
      database,
    ).getByPlayerId(playerId);
    expect(career.matches, 1);
    expect(career.totalPoints, 2);
    expect(find.text(playerName), findsAtLeastNWidgets(1));
    expect(find.byType(ReplayPage), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpUntilLandscape(
  WidgetTester tester, {
  int attempts = 150,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    final physicalSize = tester.view.physicalSize;
    if (physicalSize.width > physicalSize.height) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for the scoring view to enter landscape.');
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  String? description,
  int attempts = 150,
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

Future<void> _pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  String? description,
  int attempts = 150,
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 250));
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail(
    'Timed out waiting for ${description ?? finder} to disappear ($finder).',
  );
}

Future<void> _tapWhenHitTestable(
  WidgetTester tester,
  Finder finder, {
  required String description,
  int attempts = 150,
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
  final viewSize = tester.view.physicalSize / tester.view.devicePixelRatio;
  final rects = finder
      .evaluate()
      .map(
        (element) => tester.getRect(
          find.byElementPredicate((candidate) => candidate == element),
        ),
      )
      .toList(growable: false);
  final hitPaths = rects
      .map(
        (rect) => tester
            .hitTestOnBinding(rect.center)
            .path
            .map((entry) => entry.target.runtimeType)
            .toList(growable: false),
      )
      .toList(growable: false);
  fail(
    'Timed out waiting for $description to become hit-testable ($finder). '
    'view=$viewSize rects=$rects hitPaths=$hitPaths.',
  );
}

Future<void> _pumpUntilCondition(
  WidgetTester tester,
  bool Function() condition, {
  required String description,
}) async {
  for (var attempt = 0; attempt < 150; attempt++) {
    await tester.pump(const Duration(milliseconds: 50));
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
  }
  fail('Timed out waiting for $description.');
}
