import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/features/scoring/widgets/score_side_panel.dart';

void main() {
  testWidgets('outside court-first point enables only +3 for both sides', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'page-standard');
    addTearDown(controller.dispose);
    await _pump(tester, controller);
    controller.beginOrMoveCourtFirstShot(CourtPoint(x: .5, y: .9));
    await tester.pump();
    for (final side in TeamSide.values) {
      final panel = tester.widget<ScoreSidePanel>(
        find.byKey(Key('${side.name}-side-panel')),
      );
      expect(panel.enabledScorePoints, {3});
    }
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'one-point baskets omit +2 and +3 while allowing an outside make',
    (tester) async {
      final controller = ScoringController(
        setup: const MatchSetup(
          matchId: 'page-baskets',
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplateId: 'baskets',
          targetScore: null,
          timerEnabled: false,
          timeLimitMinutes: 10,
          winByTwo: false,
          scoringConvention: ScoringConvention.onePerBasket,
          scoreButtons: [1],
        ),
      );
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      expect(find.text('+2'), findsNothing);
      expect(find.text('+3'), findsNothing);
      controller.beginOrMoveCourtFirstShot(CourtPoint(x: .5, y: .9));
      await tester.pump();
      await tester.tap(find.byKey(const Key('blue-score-1')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(controller.state.events.single.type, EventKind.fieldGoal);
      expect(controller.state.score.blueScore, 1);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'standard +1 is explicit and creates a free throw without a location window',
    (tester) async {
      final controller = ScoringController(matchId: 'page-ft');
      addTearDown(controller.dispose);
      await _pump(tester, controller);
      expect(find.text('罚球 +1'), findsNWidgets(2));
      await tester.tap(find.byKey(const Key('red-score-1')));
      await tester.pump();
      expect(controller.state.events.single.type, EventKind.freeThrow);
      expect(controller.locationSupplementWindow, isNull);
      expect(controller.state.shotLocations, isEmpty);
      final court = tester.widget<CourtView>(find.byType(CourtView));
      expect(court.freeThrowMarkers, hasLength(1));
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _pump(WidgetTester tester, ScoringController controller) async {
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
      home: ScoringPage(controller: controller, motionPreference: null),
    ),
  );
  await tester.pump();
}
