import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/practice/practice_presentation.dart';
import 'package:hoopito/features/pregame/pregame_page.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../../support/golden_fonts.dart';

void main() {
  setUpAll(loadHoopitoGoldenFonts);
  for (final language in ['en', 'zh']) {
    for (final brightness in Brightness.values) {
      for (final size in [const Size(360, 800), const Size(640, 360)]) {
        for (final stage in ['setup', 'scoring', 'result']) {
          testWidgets(
            'practice $stage $language ${brightness.name} $size at 200%',
            (tester) async {
              tester.view.physicalSize = size;
              tester.view.devicePixelRatio = 1;
              addTearDown(tester.view.resetPhysicalSize);
              addTearDown(tester.view.resetDevicePixelRatio);
              final semantics = tester.ensureSemantics();
              try {
                final controller = ScoringController(matchId: 'layout-matrix');
                final step = ValueNotifier(
                  stage == 'setup'
                      ? PracticeStep.pregame
                      : stage == 'result'
                      ? PracticeStep.result
                      : PracticeStep.scoreBlueTwo,
                );
                var exits = 0;
                var starts = 0;
                var realGames = 0;
                await tester.pumpWidget(
                  MaterialApp(
                    theme: buildHoopitoTheme(brightness: brightness),
                    locale: Locale(language),
                    localizationsDelegates:
                        AppLocalizations.localizationsDelegates,
                    supportedLocales: AppLocalizations.supportedLocales,
                    builder: (context, child) => MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(textScaler: const TextScaler.linear(2)),
                      child: child!,
                    ),
                    home: ValueListenableBuilder<PracticeStep>(
                      valueListenable: step,
                      builder: (_, current, _) {
                        final practice = PracticePresentation(
                          step: current,
                          onExit: () {
                            exits++;
                          },
                        );
                        if (stage == 'setup') {
                          return PregamePage(
                            practice: practice,
                            onStartMatch: (_) {
                              starts++;
                            },
                          );
                        }
                        if (stage == 'scoring') {
                          return ScoringPage(
                            controller: controller,
                            practice: practice,
                            onFinishWithCoverage: (_, _, _) async {},
                          );
                        }
                        final detail = _practiceResult();
                        return MatchSummaryPage(
                          detail: detail,
                          analytics: MatchAnalyticsCalculator().calculate(
                            detail.events,
                          ),
                          practice: practice,
                          onBack: () {},
                          onRematch: () {},
                          onReplay: () {},
                          onShare: () {},
                          onCorrectCoverage: () {},
                          onSavePlayer: (_) {},
                          onPracticeStartReal: () {
                            realGames++;
                          },
                        );
                      },
                    ),
                  ),
                );
                await tester.pumpAndSettle();
                _expectExitAndNoOverflow(tester);
                if (stage == 'setup') {
                  final start = find.byKey(const Key('pregame-start-match'));
                  expect(start.hitTestable(), findsOneWidget);
                  expect(
                    tester
                        .getSemantics(start)
                        .getSemanticsData()
                        .hasAction(ui.SemanticsAction.tap),
                    isTrue,
                  );
                  await tester.tap(start);
                  await tester.pumpAndSettle();
                  expect(starts, 1);
                } else if (stage == 'scoring') {
                  // Missing from image snapshots: all current targets, including
                  // scrolled Miss, must remain reachable after step transitions.
                  for (final entry in {
                    PracticeStep.scoreBlueTwo: 'blue-score-2',
                    PracticeStep.undo: 'scoring-undo',
                    PracticeStep.courtPoint: 'scoring-court',
                    PracticeStep.scoreRedTwo: 'red-score-2',
                    PracticeStep.missBlue: 'blue-miss',
                    PracticeStep.finish: 'scoring-finish',
                  }.entries) {
                    step.value = entry.key;
                    await tester.pumpAndSettle();
                    expect(
                      find.byKey(Key(entry.value)).hitTestable(),
                      findsOneWidget,
                      reason: '${entry.key} is the current target',
                    );
                    _expectExitAndNoOverflow(tester);
                    final context = tester.element(find.byType(ScoringPage));
                    expect(
                      find.text(AppLocalizations.of(context)!.v2Saved),
                      findsNothing,
                    );
                    if (entry.key == PracticeStep.courtPoint) {
                      final courtNode = _tapOwner(
                        tester.getSemantics(
                          find.byKey(const Key('scoring-court')),
                        ),
                      );
                      expect(courtNode, isNotNull);
                      tester
                          .renderObject(find.byKey(const Key('scoring-court')))
                          .owner!
                          .semanticsOwner!
                          .performAction(courtNode!.id, ui.SemanticsAction.tap);
                      await tester.pumpAndSettle();
                      expect(controller.courtFirstShotDraft, isNotNull);
                      expect(controller.state.events, isEmpty);
                      controller.cancelCourtFirstShot();
                    }
                  }
                } else {
                  final cta = find.byKey(const Key('practice-real-game'));
                  await tester.ensureVisible(cta);
                  await tester.pumpAndSettle();
                  expect(cta.hitTestable(), findsOneWidget);
                  _expectExitAndNoOverflow(tester);
                  await tester.tap(cta);
                  expect(realGames, 1);
                  expect(find.byKey(const Key('summary-share')), findsNothing);
                  expect(find.byKey(const Key('summary-replay')), findsNothing);
                  expect(
                    find.byKey(const Key('summary-correct-coverage')),
                    findsNothing,
                  );
                  expect(
                    find.byKey(const Key('summary-save-layout-red')),
                    findsNothing,
                  );
                }
                await tester.tap(find.byKey(const Key('practice-exit')));
                expect(exits, 1);
                expect(tester.takeException(), isNull);
                await tester.pumpWidget(const SizedBox());
                step.dispose();
                controller.dispose();
              } finally {
                semantics.dispose();
              }
            },
          );
        }
      }
    }
  }
}

void _expectExitAndNoOverflow(WidgetTester tester) {
  expect(find.byKey(const Key('practice-exit')).hitTestable(), findsOneWidget);
  expect(tester.takeException(), isNull);
}

SemanticsNode? _tapOwner(SemanticsNode root) {
  if (root.getSemanticsData().hasAction(ui.SemanticsAction.tap)) return root;
  SemanticsNode? result;
  root.visitChildren((child) {
    result ??= _tapOwner(child);
    return result == null;
  });
  return result;
}

MatchDetail _practiceResult() {
  final events = [
    MatchEvent.score(
      id: 'layout-score',
      matchId: 'layout',
      side: TeamSide.red,
      points: 2,
      occurredAt: DateTime.utc(2026),
    ),
  ];
  return MatchDetail(
    match: Match(
      id: 'layout',
      createdAt: DateTime.utc(2026),
      lifecycle: MatchLifecycle.finished,
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplateSnapshot: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
    ),
    events: events,
    shotLocations: const [],
    redScore: 2,
    blueScore: 0,
    redFouls: 0,
    blueFouls: 0,
    shotAttemptCount: 1,
    locatedShotCount: 0,
  );
}
