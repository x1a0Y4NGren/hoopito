import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/practice/practice_session.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../../support/golden_fonts.dart';

const _setup = MatchSetup(
  matchId: 'unused',
  redName: 'Red',
  blueName: 'Blue',
  ruleTemplateId: 'free',
  targetScore: null,
  timerEnabled: false,
  timeLimitMinutes: 10,
  winByTwo: false,
);

void main() {
  setUpAll(loadHoopitoGoldenFonts);

  for (final size in [const Size(390, 844), const Size(844, 390)]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('pregame overlay preserves geometry $size at $scale', (
        tester,
      ) async {
        _viewport(tester, size);
        var started = 0;
        var exited = 0;
        Widget page(bool visible) => PregamePage(
          practice: PracticePresentation(
            step: PracticeStep.pregame,
            onExit: () => exited++,
            showCoach: visible,
          ),
          onStartMatch: (_) => started++,
        );
        final landmarks = [
          find.byType(EditorialMasthead),
          find.byKey(const Key('pregame-start-match')),
          find.byKey(const Key('pregame-blue-name')),
          find.byKey(const Key('pregame-red-name')),
          find.byKey(const Key('pregame-blue-card')),
          find.byKey(const Key('pregame-red-card')),
          find.byKey(const Key('pregame-rules-summary')),
        ];
        await _pump(tester, page(false), scale);
        expect(find.byKey(const Key('practice-coach')), findsNothing);
        final original = [
          for (final finder in landmarks) tester.getRect(finder),
        ];
        await _pump(tester, page(true), scale);
        for (var i = 0; i < landmarks.length; i++) {
          expect(tester.getRect(landmarks[i]), original[i]);
        }
        expect(
          find.byKey(const Key('practice-exit')).hitTestable(),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const Key('practice-exit')));
        expect(exited, 1);
        await tester.tap(find.byKey(const Key('pregame-start-match')));
        await tester.pumpAndSettle();
        expect(started, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('summary overlay preserves geometry $size at $scale', (
        tester,
      ) async {
        _viewport(tester, size);
        final session = PracticeSession();
        addTearDown(session.close);
        await session.start(_setup);
        await session.controller!.recordScoreCommitted(
          side: TeamSide.blue,
          points: 2,
        );
        await session.controller!.undoLastScoringActionCommitted();
        session.controller!.beginDetailedShot(CourtPoint(x: .42, y: .48));
        session.controller!.updateDetailedShot(side: TeamSide.red, points: 2);
        await session.controller!.commitDetailedShot();
        await session.controller!.recordMissCommitted(side: TeamSide.blue);
        await session.finish(2, 0, TrackingCoverage.scoresOnly);
        final detail = session.result!;
        var replayed = 0;
        var startedReal = 0;
        Widget page(bool visible) => MatchSummaryPage(
          detail: detail,
          analytics: MatchAnalyticsCalculator().calculate(detail.events),
          practice: PracticePresentation(
            step: PracticeStep.result,
            onExit: () {},
            showCoach: visible,
          ),
          onBack: () {},
          onRematch: () => replayed++,
          onPracticeStartReal: () => startedReal++,
          onReplay: () {},
          onShare: () => fail('Practice must not expose sharing'),
          onCorrectCoverage: () => fail('Practice must not expose corrections'),
          onSavePlayer: (_) => fail('Practice must not save real players'),
        );
        final landmarks = [
          find.byType(EditorialMasthead),
          find.byType(MatchScoreRow),
          find.byKey(const Key('summary-outcome')),
          find.byKey(const Key('summary-rematch')),
          find.byKey(const Key('practice-real-game')),
        ];
        await _pump(tester, page(false), scale);
        // Compare the same scroll position: short viewports may need to reveal
        // the result score before guidance can point to it.
        await Scrollable.ensureVisible(
          tester.element(find.byType(MatchScoreRow)),
          alignment: .5,
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('practice-coach')), findsNothing);
        final original = [
          for (final finder in landmarks) tester.getRect(finder),
        ];
        await _pump(tester, page(true), scale);
        for (var i = 0; i < landmarks.length; i++) {
          expect(tester.getRect(landmarks[i]), original[i]);
        }
        expect(
          find.byKey(const Key('practice-exit')).hitTestable(),
          findsOneWidget,
        );
        expect(find.byKey(const Key('summary-share')), findsNothing);
        expect(find.byKey(const Key('summary-correct-coverage')), findsNothing);
        await tester.ensureVisible(find.byKey(const Key('summary-rematch')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('summary-rematch')));
        expect(replayed, 1);
        await tester.ensureVisible(find.byKey(const Key('practice-real-game')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('practice-real-game')));
        expect(startedReal, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'summary coach leaves visible winner and masthead clear in Chinese',
    (tester) async {
      _viewport(tester, const Size(390, 844));
      final session = PracticeSession();
      addTearDown(session.close);
      await session.start(_setup);
      await session.controller!.recordScoreCommitted(
        side: TeamSide.blue,
        points: 2,
      );
      await session.controller!.undoLastScoringActionCommitted();
      session.controller!.beginDetailedShot(CourtPoint(x: .42, y: .48));
      session.controller!.updateDetailedShot(side: TeamSide.red, points: 2);
      await session.controller!.commitDetailedShot();
      await session.controller!.recordMissCommitted(side: TeamSide.blue);
      await session.finish(2, 0, TrackingCoverage.scoresOnly);
      final detail = session.result!;
      await _pump(
        tester,
        MatchSummaryPage(
          detail: detail,
          analytics: MatchAnalyticsCalculator().calculate(detail.events),
          practice: PracticePresentation(
            step: PracticeStep.result,
            onExit: () {},
          ),
          onBack: () {},
          onRematch: () {},
          onPracticeStartReal: () {},
          onReplay: () {},
          onShare: () {},
          onCorrectCoverage: () {},
          onSavePlayer: (_) {},
        ),
        1,
        locale: const Locale('zh'),
      );
      final bubble = tester.getRect(find.byKey(const Key('practice-coach')));
      expect(
        bubble.overlaps(
          tester.getRect(find.byKey(const Key('summary-outcome'))),
        ),
        isFalse,
        reason: 'The result winner must remain readable beside the guidance',
      );
      expect(
        bubble.overlaps(tester.getRect(find.byType(EditorialMasthead))),
        isFalse,
        reason: 'The restored result masthead must remain readable',
      );
      expect(find.byKey(const Key('practice-coach-arrow')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('formal pregame retains defaults without guidance', (
    tester,
  ) async {
    await _pump(tester, const PregamePage(), 1);
    expect(find.byKey(const Key('practice-coach')), findsNothing);
    expect(find.byType(EditorialMasthead), findsOneWidget);
    expect(find.byKey(const Key('pregame-rule-template')), findsOneWidget);
    expect(find.byKey(const Key('pregame-red-profile')), findsOneWidget);
    expect(find.byKey(const Key('pregame-blue-profile')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _viewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _pump(
  WidgetTester tester,
  Widget page,
  double scale, {
  Locale locale = const Locale('en'),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: buildHoopitoTheme(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}
