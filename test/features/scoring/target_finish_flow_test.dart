import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/app/app_theme.dart';
import 'package:hoopito/app/design_system/design_system.dart';
import 'package:hoopito/app/l10n/app_localizations.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/scoring/scoring_page.dart';
import 'package:hoopito/features/summary/match_summary_page.dart';

import '../../test_helpers/test_database.dart';

final _anchor = DateTime.utc(2026, 10, 28, 9);

void main() {
  testWidgets(
    'target finish commits before navigation and failed save can retry',
    (tester) async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      final detail = await _seed(service, red: 12, blue: 3, target: 11);
      final controller = ScoringController.fromCommittedProjection(
        detail,
        service,
        nowUtc: () => _anchor.add(const Duration(seconds: 11)),
      );
      addTearDown(controller.dispose);
      final repository = MatchRepository(database);
      final navigator = GlobalKey<NavigatorState>();
      var failNextSave = true;
      final finishing = MatchCommandService(
        database,
        now: () => _anchor,
        failureInjector: (point) {
          if (failNextSave && point == MatchCommandFailurePoint.beforeCommit) {
            failNextSave = false;
            throw StateError('Synthetic finish save failure');
          }
        },
      );
      var attemptSettled = Completer<void>();
      await tester.pumpWidget(
        _app(
          navigatorKey: navigator,
          child: ScoringPage(
            controller: controller,
            clockNowUtc: () => _anchor,
            onFinishWithCoverage: (red, blue, coverage) async {
              try {
                final finished = await finishing.finish(
                  FinishMatchCommand(
                    matchId: 'finish-flow',
                    endedAt: _anchor,
                    confirmFinalScore: true,
                    expectedRedScore: red,
                    expectedBlueScore: blue,
                    trackingCoverage: coverage,
                  ),
                );
                unawaited(
                  navigator.currentState!.pushReplacement<void, void>(
                    MaterialPageRoute(builder: (_) => _summary(finished)),
                  ),
                );
              } finally {
                attemptSettled.complete();
              }
            },
          ),
        ),
      );

      expect(find.text('已达到目标分'), findsOneWidget);
      expect(find.text('比赛结束'), findsNothing);
      expect(find.text('Falcons获胜'), findsNothing);
      for (var attempt = 1; attempt <= 2; attempt++) {
        attemptSettled = Completer<void>();
        await tester.tap(find.byKey(const Key('scoring-decision-finish')));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.textContaining('Falcons 12 : 3 Waves'), findsWidgets);
        // This is an explicit completeness declaration, not inferred from goals.
        await tester.tap(find.byKey(const Key('confirm-complete-recording')));
        await tester.tap(find.byKey(const Key('scoring-finish-confirm')));
        await tester.pump();
        await tester.runAsync(() => attemptSettled.future);
        await tester.pumpAndSettle();
        final stored = (await repository.getMatchDetail('finish-flow'))!;
        if (attempt == 1) {
          expect(stored.match.lifecycle, MatchLifecycle.active);
          expect(stored.match.trackingCoverage, TrackingCoverage.scoresOnly);
          expect(stored.decision?.reason, MatchDecisionReason.targetReached);
          expect(stored.clock?.state.isRunning, isFalse);
          expect((await repository.getActiveMatch())?.match.id, 'finish-flow');
          expect(find.byType(MatchSummaryPage), findsNothing);
          expect(find.text('比赛结束'), findsNothing);
          expect(find.text('Falcons获胜'), findsNothing);
          expect(find.text('操作失败，请重试。'), findsOneWidget);
          expect(
            tester
                .widget<FilledButton>(
                  find.byKey(const Key('scoring-decision-finish')),
                )
                .onPressed,
            isNotNull,
          );
        } else {
          expect(stored.match.lifecycle, MatchLifecycle.finished);
          expect(stored.match.trackingCoverage, TrackingCoverage.shotAttempts);
          expect(await repository.getActiveMatch(), isNull);
          expect(find.byType(ScoringPage), findsNothing);
          expect(find.byType(MatchSummaryPage), findsOneWidget);
          expect(find.text('比赛结束'), findsOneWidget);
          expect(find.text('Falcons获胜'), findsOneWidget);
          final score = tester.widget<MatchScoreRow>(
            find.byType(MatchScoreRow),
          );
          expect((score.redScore, score.blueScore), (12, 3));
          expect((score.redTeamName, score.blueTeamName), ('Falcons', 'Waves'));
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final locale in ['zh', 'en']) {
    for (final result in [(12, 3, 'Falcons'), (4, 9, 'Waves'), (7, 7, '')]) {
      testWidgets('committed result $result uses actual winner in $locale', (
        tester,
      ) async {
        final service = MatchCommandService(
          createTestDatabase(),
          now: () => _anchor,
        );
        await _seed(service, red: result.$1, blue: result.$2);
        final finished = await service.finish(
          FinishMatchCommand(
            matchId: 'finish-flow',
            endedAt: _anchor,
            confirmFinalScore: true,
            expectedRedScore: result.$1,
            expectedBlueScore: result.$2,
            trackingCoverage: TrackingCoverage.scoresOnly,
          ),
        );
        await tester.pumpWidget(
          _app(child: _summary(finished), locale: locale),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(locale == 'zh' ? '比赛结束' : 'Game finished'),
          findsOneWidget,
        );
        final expected = result.$3.isEmpty
            ? (locale == 'zh' ? '平局' : 'Draw')
            : (locale == 'zh' ? '${result.$3}获胜' : '${result.$3} wins');
        expect(find.text(expected), findsOneWidget);
        final score = tester.widget<MatchScoreRow>(find.byType(MatchScoreRow));
        expect((score.redScore, score.blueScore), (result.$1, result.$2));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
}

Future<MatchDetail> _seed(
  MatchCommandService service, {
  required int red,
  required int blue,
  int? target,
}) async {
  var detail = await service.start(
    StartMatchCommand(
      matchId: 'finish-flow',
      redName: 'Falcons',
      blueName: 'Waves',
      ruleTemplate: RuleTemplate(
        id: 'flow-rule',
        name: 'Flow rule',
        scoreButtons: const [1, 2, 3],
        targetScore: target,
      ),
      recordingMode: RecordingMode.simple,
      timerEnabled: true,
      clockMode: ClockMode.countUp,
      createdAt: _anchor,
      startedAt: _anchor,
    ),
  );
  for (final sideAndScore in [(TeamSide.blue, blue), (TeamSide.red, red)]) {
    for (var remaining = sideAndScore.$2; remaining > 0;) {
      final points = remaining >= 2 ? 2 : 1;
      detail = await service.record(
        RecordMatchEventCommand(
          matchId: 'finish-flow',
          side: sideAndScore.$1,
          points: points,
          occurredAt: _anchor,
        ),
      );
      remaining -= points;
    }
  }
  return detail;
}

Widget _summary(MatchDetail detail) => MatchSummaryPage(
  detail: detail,
  analytics: MatchAnalyticsCalculator().calculate(
    detail.events,
    trackingCoverage: detail.match.trackingCoverage,
    targetScore: detail.match.ruleTemplateSnapshot.targetScore,
    shotLocations: detail.shotLocations,
  ),
  onBack: () {},
  onRematch: () {},
  onReplay: () {},
  onShare: () {},
  onCorrectCoverage: () {},
  onSavePlayer: (_) {},
);

Widget _app({
  required Widget child,
  String locale = 'zh',
  GlobalKey<NavigatorState>? navigatorKey,
}) => MaterialApp(
  navigatorKey: navigatorKey,
  theme: buildHoopitoTheme(brightness: Brightness.light),
  locale: Locale(locale),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  home: child,
);
