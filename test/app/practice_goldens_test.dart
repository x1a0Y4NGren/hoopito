import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/practice/practice_session.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';
import '../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);
  for (final language in ['zh', 'en']) {
    for (final brightness in Brightness.values) {
      for (final stage in [
        'setup',
        'score',
        'court',
        'finish',
        'result',
        'large',
      ]) {
        final name = 'practice_${stage}_${language}_${brightness.name}';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = stage == 'setup' || stage == 'result'
              ? const Size(390, 844)
              : const Size(844, 390);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final session = PracticeSession();
          addTearDown(session.close);
          if (stage != 'setup') {
            await session.start(
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
            if (stage != 'score') {
              await session.controller!.recordScoreCommitted(
                side: TeamSide.blue,
                points: 2,
              );
              await session.controller!.undoLastScoringActionCommitted();
            }
            if (stage == 'finish' || stage == 'result') {
              session.controller!.beginDetailedShot(CourtPoint(x: .42, y: .48));
              session.controller!.updateDetailedShot(
                side: TeamSide.red,
                points: 2,
              );
              await session.controller!.commitDetailedShot();
              await session.controller!.recordMissCommitted(
                side: TeamSide.blue,
              );
            }
            if (stage == 'result') {
              await session.finish(2, 0, TrackingCoverage.scoresOnly);
            }
          }
          final practice = PracticePresentation(
            step: session.step,
            onExit: () {},
          );
          final Widget page;
          if (stage == 'setup') {
            page = PregamePage(practice: practice);
          } else if (stage == 'result') {
            final detail = session.result!;
            page = MatchSummaryPage(
              detail: detail,
              analytics: MatchAnalyticsCalculator().calculate(detail.events),
              practice: practice,
              onBack: () {},
              onRematch: () {},
              onPracticeStartReal: () {},
              onReplay: () {},
              onShare: () {},
              onCorrectCoverage: () {},
              onSavePlayer: (_) {},
            );
          } else {
            page = ScoringPage(
              controller: session.controller,
              practice: practice,
              onFinishWithCoverage: session.finish,
            );
          }
          await tester.pumpWidget(
            MaterialApp(
              theme: buildHoopitoTheme(brightness: brightness),
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(stage == 'large' ? 2 : 1),
                ),
                child: child!,
              ),
              home: RepaintBoundary(
                key: const Key('practice-golden'),
                child: page,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const Key('practice-exit')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await expectLater(
            find.byKey(const Key('practice-golden')),
            matchesGoldenFile(hoopitoGoldenFile(name)),
          );
          await tester.pumpWidget(const SizedBox());
        });
      }
    }
  }
}
