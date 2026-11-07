import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_flow_page.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

void main() {
  testWidgets(
    'durable completion survives preference failure and returns to the old match',
    (tester) async {
      var completions = 0;
      var returns = 0;
      late Completer<void> returned;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: PracticeFlowPage(
            onExit: () {},
            onStartReal: () => fail('must return to existing match'),
            onReturnMatch: () {
              returns++;
              returned.complete();
            },
            onCompleted: () async {
              completions++;
              throw StateError('preferences unavailable');
            },
          ),
        ),
      );
      final pregame = tester.widget<PregamePage>(find.byType(PregamePage));
      await tester.runAsync(() async {
        await pregame.onStartMatch!(
          const MatchSetup(
            matchId: 'unused',
            redName: 'Red',
            blueName: 'Blue',
            ruleTemplateId: 'free',
            targetScore: null,
            timerEnabled: false,
            timeLimitMinutes: 10,
            winByTwo: false,
          ),
        );
      });
      await tester.pumpAndSettle();
      var scoring = tester.widget<ScoringPage>(find.byType(ScoringPage));
      final controller = scoring.controller!;
      await tester.runAsync(() async {
        await controller.recordScoreCommitted(side: TeamSide.blue, points: 2);
        await controller.undoLastScoringActionCommitted();
        controller.beginDetailedShot(CourtPoint(x: .5, y: .5));
        controller.updateDetailedShot(side: TeamSide.red, points: 2);
        await controller.commitDetailedShot();
        await controller.recordMissCommitted(side: TeamSide.blue);
      });
      await tester.pumpAndSettle();
      scoring = tester.widget<ScoringPage>(find.byType(ScoringPage));
      expect(completions, 0);
      await tester.runAsync(
        () =>
            scoring.onFinishWithCoverage!(2, 0, TrackingCoverage.shotAttempts),
      );
      await tester.pumpAndSettle();
      expect(completions, 1);
      expect(find.byType(MatchSummaryPage), findsOneWidget);
      expect(find.byKey(const Key('practice-real-game')), findsNothing);
      final summary = tester.widget<MatchSummaryPage>(
        find.byType(MatchSummaryPage),
      );
      await tester.runAsync(() async {
        returned = Completer<void>();
        summary.onPracticeReturnMatch!();
        await returned.future.timeout(const Duration(seconds: 10));
      });
      await tester.pumpAndSettle();
      expect(returns, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('exit from pregame does not complete practice', (tester) async {
    var exits = 0;
    var completions = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PracticeFlowPage(
          onExit: () => exits++,
          onStartReal: () {},
          onCompleted: () async {
            completions++;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(PregamePage), findsOneWidget);
    await tester.tap(find.byKey(const Key('practice-exit')));
    await tester.pumpAndSettle();
    expect(exits, 1);
    expect(completions, 0);
  });
}
