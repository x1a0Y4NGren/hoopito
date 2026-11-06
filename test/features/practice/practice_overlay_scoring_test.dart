import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/practice/practice_coach.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/scoring/widgets/court_painter.dart';

void main() {
  for (final step in [PracticeStep.missBlue, PracticeStep.finish]) {
    testWidgets('coach protects the committed red shot during ${step.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScoringController(matchId: 'committed-marker');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScoringPage(
            controller: controller,
            practice: PracticePresentation(step: step, onExit: () {}),
            onFinishWithCoverage: (_, _, _) async {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final court = tester.getRect(find.byKey(const Key('scoring-court')));
      final playableCourt = HalfCourtGeometry.courtRectForSize(
        court.size,
      ).shift(court.topLeft);
      // Choose a real court point in the coach's current footprint: the
      // committed location must force it to find another legal placement.
      final overlap = tester
          .getRect(find.byKey(const Key('practice-coach')))
          .intersect(playableCourt.deflate(24));
      expect(overlap.isEmpty, isFalse);
      final point = HalfCourtGeometry.pointFromLocal(
        overlap.center - court.topLeft,
        court.size,
      );
      expect(
        controller.beginOrMoveCourtFirstShot(
          point,
          side: TeamSide.red,
          points: 2,
        ),
        isTrue,
      );
      expect(await controller.commitCourtFirstShot(), isTrue);
      await tester.pumpAndSettle();
      expect(controller.state.courtFirstShotDraft, isNull);
      expect(controller.state.shotLocations, hasLength(1));
      final recorded = controller.state.shotLocations.single.point;
      expect(recorded.x, point.x);
      expect(recorded.y, point.y);
      final marker = Rect.fromCenter(
        center:
            court.topLeft +
            HalfCourtGeometry.pointToOffset(recorded, court.size),
        width: 40,
        height: 40,
      );
      expect(
        tester
            .getRect(find.byKey(const Key('practice-coach')))
            .overlaps(marker),
        isFalse,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  for (final confirmation in [false, true]) {
    testWidgets(
      'popup exit skips a disposed scoring scope confirmation=$confirmation',
      (tester) async {
        final controller = ScoringController(matchId: 'disposed-popup');
        final showScoring = ValueNotifier(true);
        var exits = 0;
        var finishes = 0;
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: ValueListenableBuilder<bool>(
              valueListenable: showScoring,
              builder: (_, visible, _) => visible
                  ? ScoringPage(
                      controller: controller,
                      practice: PracticePresentation(
                        step: PracticeStep.finish,
                        onExit: () => exits++,
                      ),
                      onFinishWithCoverage: (_, _, _) async {
                        finishes++;
                      },
                    )
                  : const Scaffold(body: Text('unrelated page')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('scoring-finish')));
        await tester.pumpAndSettle();
        if (confirmation) {
          await tester.tap(find.byKey(const Key('match-controls-finish')));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.byKey(const Key('practice-exit')));
        expect(exits, 0);
        showScoring.value = false;
        await tester.pump();
        await tester.pumpAndSettle();
        expect(exits, 0);
        expect(finishes, 0);
        expect(find.text('unrelated page'), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        showScoring.dispose();
        controller.dispose();
      },
    );

    testWidgets('popup coach owns exit confirmation=$confirmation', (
      tester,
    ) async {
      final controller = ScoringController(matchId: 'overlay-popup');
      var exits = 0;
      var finishes = 0;
      final navigator = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigator,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Text('root sentinel')),
        ),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => ScoringPage(
            controller: controller,
            practice: PracticePresentation(
              step: PracticeStep.finish,
              onExit: () => exits++,
            ),
            onFinishWithCoverage: (_, _, _) async {
              finishes++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('scoring-finish')));
      await tester.pumpAndSettle();
      if (confirmation) {
        await tester.tap(find.byKey(const Key('match-controls-finish')));
        await tester.pumpAndSettle();
      }
      final dialog = find.byType(AlertDialog);
      final localHost = find.ancestor(
        of: dialog,
        matching: find.byType(PracticeCoachHost),
      );
      expect(localHost, findsOneWidget);
      expect(
        find.descendant(
          of: localHost,
          matching: find.byKey(const Key('practice-coach')),
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('practice-coach')), findsOneWidget);
      final confirmKey = confirmation
          ? 'scoring-finish-confirm'
          : 'match-controls-finish';
      expect(find.byKey(Key(confirmKey)).hitTestable(), findsOneWidget);
      await tester.tap(find.byKey(const Key('practice-exit')));
      expect(
        exits,
        0,
        reason: 'Exit waits for the owned dialog transition to complete',
      );
      await tester.pumpAndSettle();
      expect(exits, 1);
      expect(finishes, 0);
      expect(find.byType(AlertDialog), findsNothing);
      expect(navigator.currentState!.canPop(), isTrue);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }

  testWidgets(
    'controls cancel returns the page coach and repeated activation opens one route',
    (tester) async {
      final controller = ScoringController(matchId: 'overlay-controls');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ScoringPage(
            controller: controller,
            practice: PracticePresentation(
              step: PracticeStep.finish,
              onExit: () {},
            ),
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
      expect(find.byKey(const Key('practice-coach')), findsOneWidget);
      await tester.tap(find.byKey(const Key('match-controls-return')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog, skipOffstage: false), findsNothing);
      expect(find.byKey(const Key('practice-coach')), findsOneWidget);
      expect(
        find.byKey(const Key('scoring-finish')).hitTestable(),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );

  testWidgets('cancel restores page coach and coverage keeps manual choice', (
    tester,
  ) async {
    final controller = ScoringController(matchId: 'overlay-coverage');
    TrackingCoverage? finished;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ScoringPage(
          controller: controller,
          practice: PracticePresentation(
            step: PracticeStep.finish,
            onExit: () {},
          ),
          onFinishWithCoverage: (_, _, coverage) async {
            finished = coverage;
          },
        ),
      ),
    );
    Future<void> open() async {
      await tester.tap(find.byKey(const Key('scoring-finish')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('match-controls-finish')));
      await tester.pumpAndSettle();
    }

    await open();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('confirm-complete-recording')),
          )
          .value,
      isFalse,
    );
    expect(find.byKey(const Key('practice-coach')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scoring-finish-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byKey(const Key('practice-coach')), findsOneWidget);
    await open();
    await tester.tap(find.byKey(const Key('confirm-complete-recording')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<SwitchListTile>(
            find.byKey(const Key('confirm-complete-recording')),
          )
          .value,
      isTrue,
    );
    await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
    await tester.pumpAndSettle();
    expect(finished, TrackingCoverage.shotAttempts);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
}
