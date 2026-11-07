import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';

void main() {
  for (final practice in [false, true]) {
    testWidgets(
      'repeated Finish activation opens one controls dialog practice=$practice',
      (tester) async {
        final controller = ScoringController(matchId: 'single-controls');
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ScoringPage(
              controller: controller,
              practice: practice
                  ? PracticePresentation(
                      step: PracticeStep.finish,
                      onExit: () {},
                    )
                  : null,
              onFinishWithCoverage: (_, _, _) async {},
            ),
          ),
        );
        final finish = tester
            .widget<FilledButton>(find.byKey(const Key('scoring-finish')))
            .onPressed!;
        finish();
        finish();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('match-controls-return')));
        await tester.pumpAndSettle();
        // Offstage stacked dialogs also count: one return must close them all.
        expect(
          find.byKey(const Key('scoring-match-controls'), skipOffstage: false),
          findsNothing,
        );
        finish();
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('scoring-match-controls')), findsOneWidget);
        await tester.tap(find.byKey(const Key('match-controls-return')));
        await tester.pumpAndSettle();
        await tester.pumpWidget(const SizedBox());
        controller.dispose();
      },
    );
  }

  for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.space]) {
    testWidgets('practice court step progresses using focused ${key.keyLabel}', (
      tester,
    ) async {
      final controller = ScoringController(matchId: 'keyboard-court');
      final step = ValueNotifier(PracticeStep.undo);
      controller.addListener(() {
        if (controller.courtFirstShotDraft != null) {
          step.value = PracticeStep.scoreRedTwo;
        }
      });
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ValueListenableBuilder<PracticeStep>(
            valueListenable: step,
            builder: (_, current, _) => ScoringPage(
              controller: controller,
              practice: PracticePresentation(step: current, onExit: () {}),
            ),
          ),
        ),
      );
      // Match the real flow: the existing scoring page transitions to court.
      step.value = PracticeStep.courtPoint;
      await tester.pumpAndSettle();
      expect(FocusManager.instance.primaryFocus?.debugLabel, 'practice-court');
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(controller.courtFirstShotDraft, isNotNull);
      expect(controller.courtFirstShotDraft!.point.x, .5);
      expect(controller.courtFirstShotDraft!.point.y, .5);
      expect(step.value, PracticeStep.scoreRedTwo);
      final before = controller.state.events.length;
      // A repeated key after progression must not place another draft or score.
      await tester.sendKeyEvent(key);
      await tester.pumpAndSettle();
      expect(controller.state.events.length, before);
      await tester.pumpWidget(const SizedBox());
      step.dispose();
      controller.dispose();
    });
  }
}
