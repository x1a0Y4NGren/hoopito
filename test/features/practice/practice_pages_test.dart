import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/widgets/court_view.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

class _GatedScoreController extends ScoringController {
  _GatedScoreController() : super(matchId: 'practice-gated');
  final gate = Completer<bool>();
  int calls = 0;
  @override
  Future<bool> recordScoreCommitted({
    required TeamSide side,
    required int points,
    DateTime? occurredAt,
  }) {
    calls++;
    return gate.future;
  }
}

void main() {
  testWidgets(
    'practice setup starts free with timer disabled and temporary names',
    (tester) async {
      MatchSetup? started;
      await tester.pumpWidget(
        MaterialApp(
          home: PregamePage(
            practice: PracticePresentation(
              step: PracticeStep.pregame,
              onExit: () {},
            ),
            onStartMatch: (setup) {
              started = setup;
            },
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('pregame-start-match')));
      await tester.pump();
      expect(started, isNotNull);
      expect(started!.targetScore, isNull);
      expect(started!.timerEnabled, isFalse);
      expect(started!.redPlayerProfileId, isNull);
      expect(started!.bluePlayerProfileId, isNull);
    },
  );

  testWidgets('practice repeated activation is blocked while commit waits', (
    tester,
  ) async {
    final controller = _GatedScoreController();
    var exited = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ScoringPage(
          controller: controller,
          practice: PracticePresentation(
            step: PracticeStep.scoreBlueTwo,
            onExit: () {
              exited = true;
            },
          ),
        ),
      ),
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('blue-score-2')),
    );
    button.onPressed!();
    button.onPressed!();
    expect(controller.calls, 1);
    await tester.tap(find.byKey(const Key('practice-exit')));
    expect(exited, isTrue);
    controller.gate.complete(false);
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets(
    'practice coach and court remain accessible on large text landscape',
    (tester) async {
      tester.view.physicalSize = const Size(640, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScoringController(matchId: 'practice-large-text');
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(2)),
            child: child!,
          ),
          home: ScoringPage(
            controller: controller,
            practice: PracticePresentation(
              step: PracticeStep.courtPoint,
              onExit: () {},
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(const Key('practice-exit')).hitTestable(),
        findsOneWidget,
      );
      final court = tester.widget<CourtView>(
        find.byKey(const Key('scoring-court')),
      );
      court.onCourtPointTap!(CourtPoint(x: 0.4, y: 0.5));
      await tester.pump();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('practice setup hides live profile and rule controls', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: PregamePage(
          practice: PracticePresentation(
            step: PracticeStep.pregame,
            onExit: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('practice-exit')), findsOneWidget);
    expect(find.byKey(const Key('pregame-red-profile')), findsNothing);
    expect(find.byKey(const Key('pregame-rule-template')), findsNothing);
    expect(find.byKey(const Key('pregame-start-match')), findsOneWidget);
  });

  testWidgets('practice wrong score does not produce an event', (tester) async {
    final controller = ScoringController(matchId: 'practice-ui-test');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoringPage(
          controller: controller,
          practice: PracticePresentation(
            step: PracticeStep.scoreBlueTwo,
            onExit: () {},
          ),
        ),
      ),
    );
    final before = controller.state.events.length;
    await tester.tap(find.byKey(const Key('red-score-2')));
    await tester.pump();
    expect(controller.state.events.length, before);
    expect(find.byKey(const Key('practice-coach')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
