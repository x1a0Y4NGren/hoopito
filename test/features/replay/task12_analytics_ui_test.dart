import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/widgets/replay_analytics_summary.dart';

void main() {
  testWidgets('replay analytics presents flow, attempts, coverage, and zones', (
    tester,
  ) async {
    final analytics = MatchAnalytics(
      scoringFlow: const [],
      largestLeadSide: TeamSide.red,
      largestLeadPoints: 5,
      leadChanges: 2,
      madeShotCount: 3,
      missedShotCount: 2,
      shootingPercentage: .5,
      recordedShootingPercentage: .5,
      shootingPercentageIsTrustworthy: true,
      trackingCoverage: TrackingCoverage.full,
      fieldGoalMadeCount: 2,
      fieldGoalAttemptCount: 4,
      freeThrowMadeCount: 1,
      freeThrowAttemptCount: 2,
      redFoulCount: 3,
      blueFoulCount: 1,
      possessionCount: 8,
      shotAttemptCount: 6,
      confirmedLocationCount: 3,
      locationCoverage: 3 / 4,
      zoneDistribution: const {ShotZone.paint: 2, ShotZone.cornerThree: 1},
      scoringRuns: [
        ScoringRun(
          side: TeamSide.red,
          eventIds: const ['a', 'b'],
          points: 4,
          startedAt: DateTime.utc(2026, 8, 1),
          endedAt: DateTime.utc(2026, 8, 1, 0, 1),
        ),
      ],
      keyPossessions: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: ReplayAnalyticsSummary(
            analytics: analytics,
            redName: 'Red',
            blueName: 'Blue',
          ),
        ),
      ),
    );

    expect(find.text('连续得分'), findsOneWidget);
    expect(find.text('投篮记录'), findsOneWidget);
    expect(find.text('罚球'), findsOneWidget);
    expect(find.text('犯规'), findsOneWidget);
    expect(find.text('球权'), findsOneWidget);
    expect(find.text('记录范围'), findsOneWidget);
    expect(find.text('已确认运动战落点 / 已记录运动战出手'), findsOneWidget);
    expect(find.text('出手区域'), findsOneWidget);
    expect(find.textContaining('油漆区'), findsOneWidget);
    expect(find.text('50% · 2/4'), findsOneWidget);
    expect(find.text('50% · 1/2'), findsOneWidget);
    expect(find.text('3/4'), findsOneWidget);
    expect(find.text('3/6'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('replay never displays a percentage for scores-only tracking', (
    tester,
  ) async {
    final analytics = MatchAnalytics(
      scoringFlow: const [],
      largestLeadSide: null,
      largestLeadPoints: 0,
      leadChanges: 0,
      madeShotCount: 4,
      missedShotCount: 0,
      shootingPercentage: 0,
      recordedShootingPercentage: null,
      shootingPercentageIsTrustworthy: false,
      trackingCoverage: TrackingCoverage.scoresOnly,
      fieldGoalMadeCount: 4,
      fieldGoalAttemptCount: 4,
      keyPossessions: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SingleChildScrollView(
          child: ReplayAnalyticsSummary(
            analytics: analytics,
            redName: 'Red',
            blueName: 'Blue',
          ),
        ),
      ),
    );

    expect(find.textContaining('%'), findsNothing);
    expect(find.textContaining('运动战出手'), findsWidgets);
    expect(find.textContaining('4'), findsWidgets);
  });

  testWidgets('replay analytics stays usable at 200 percent text scale', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: MaterialApp(
          home: SingleChildScrollView(
            child: ReplayAnalyticsSummary(
              analytics: MatchAnalytics(
                scoringFlow: const [],
                largestLeadSide: null,
                largestLeadPoints: 0,
                leadChanges: 0,
                madeShotCount: 0,
                missedShotCount: 0,
                shootingPercentage: 0,
                keyPossessions: const [],
              ),
              redName: 'Red',
              blueName: 'Blue',
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
