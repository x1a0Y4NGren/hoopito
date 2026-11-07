import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/hoopito_app.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/settings/practice_preferences.dart';
import 'package:hoopito/features/practice/practice_flow_page.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

Future<void> waitFor(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 160; i++) {
    await tester.pump(const Duration(milliseconds: 30));
    if (ready()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 2)),
    );
  }
  fail('Expected practice state was not reached');
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  runPracticeJourney();
}

void runPracticeJourney({bool device = false}) {
  testWidgets(
    'first invitation teaches the complete real UI without writing game records',
    (tester) async {
      if (!device) {
        tester.view.physicalSize = const Size(900, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
      }
      final temp = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('hoopito-practice-isolation-'),
      ))!;
      final database = AppDatabase(
        NativeDatabase(File('${temp.path}/real.sqlite')),
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
        await tester.runAsync(() async {
          await database.close();
          await temp.delete(recursive: true);
        });
        await tester.pump(const Duration(seconds: 1));
      });
      await tester.pumpWidget(
        HoopitoApp(database: database, showEntryAnimation: false),
      );
      await waitFor(
        tester,
        () => find
            .byKey(const Key('practice-invite-start'))
            .evaluate()
            .isNotEmpty,
      );
      await tapKey(tester, 'practice-invite-start');
      await waitFor(
        tester,
        () =>
            find.byType(PracticeFlowPage).evaluate().isNotEmpty &&
            find.byKey(const Key('pregame-start-match')).evaluate().isNotEmpty,
      );
      expect(find.byKey(const Key('pregame-mode-series')), findsNothing);
      await tapKey(tester, 'pregame-start-match');
      await waitFor(
        tester,
        () => find.byType(ScoringPage).evaluate().isNotEmpty,
      );
      PracticeStep step() =>
          tester.widget<ScoringPage>(find.byType(ScoringPage)).practice!.step;
      final controller = tester
          .widget<ScoringPage>(find.byType(ScoringPage))
          .controller!;
      expect(step(), PracticeStep.scoreBlueTwo);
      await tapKey(tester, 'red-score-2');
      expect(controller.state.score.redScore, 0);
      await tapKey(tester, 'blue-score-2');
      await waitFor(tester, () => step() == PracticeStep.undo);
      expect(controller.state.score.blueScore, 2);
      await tapKey(tester, 'scoring-undo');
      await waitFor(tester, () => step() == PracticeStep.courtPoint);
      expect(controller.state.score.blueScore, 0);
      await tapKey(tester, 'scoring-court');
      await waitFor(tester, () => step() == PracticeStep.scoreRedTwo);
      await tapKey(tester, 'red-score-2');
      await waitFor(tester, () => step() == PracticeStep.missBlue);
      expect(controller.state.shotLocations, hasLength(1));
      await tapKey(tester, 'blue-miss');
      await waitFor(tester, () => step() == PracticeStep.finish);
      await tapKey(tester, 'scoring-finish');
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('scoring-match-controls')), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const Key('match-controls-pause')),
            )
            .onPressed,
        isNull,
      );
      await tapKey(tester, 'match-controls-finish');
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<SwitchListTile>(
              find.byKey(const Key('confirm-complete-recording')),
            )
            .value,
        isFalse,
      );
      await tapKey(tester, 'scoring-finish-confirm');
      await waitFor(
        tester,
        () => find.byType(MatchSummaryPage).evaluate().isNotEmpty,
      );
      expect(find.text('练习结束'), findsOneWidget);
      expect(find.byKey(const Key('summary-share')), findsNothing);
      await tester.runAsync(() async {
        expect(await database.select(database.matches).get(), isEmpty);
        expect(await database.select(database.matchEvents).get(), isEmpty);
        expect(await database.select(database.players).get(), isEmpty);
        expect(await database.select(database.auditLogs).get(), isEmpty);
        expect(await database.select(database.matchSeries).get(), isEmpty);
        expect(await database.select(database.seriesMatches).get(), isEmpty);
      });
      await waitFor(
        tester,
        () => find.byKey(const Key('practice-real-game')).evaluate().isNotEmpty,
      );
      await tester.runAsync(() async {
        expect(
          (await PracticePreferences(database).load()).practiceCompleted,
          isTrue,
        );
      });
      await tapKey(tester, 'practice-real-game');
      await waitFor(
        tester,
        () =>
            find
                .byKey(const Key('pregame-start-match'))
                .evaluate()
                .isNotEmpty &&
            find.byType(PracticeFlowPage).evaluate().isEmpty,
      );
      expect(find.byKey(const Key('practice-coach')), findsNothing);
      expect(find.byKey(const Key('pregame-mode-series')), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        expect(await database.select(database.matches).get(), isEmpty);
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    },
  );
}
