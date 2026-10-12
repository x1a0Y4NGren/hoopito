import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/replay/replay_controller.dart';
import 'package:hoopito/features/replay/replay_page.dart';

void main() {
  test('replay timeline sorts by occurredAt with stable input tie-breaks', () {
    final late = DateTime.utc(2026, 8, 25, 12, 0, 5);
    final early = DateTime.utc(2026, 8, 25, 12, 0, 1);
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'timeline-order',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 4,
        blueScore: 0,
        duration: const Duration(seconds: 5),
        events: [
          ReplayEventData(
            id: 'late',
            kind: ReplayEventKind.score,
            side: TeamSide.red,
            points: 2,
            elapsed: const Duration(seconds: 5),
            occurredAt: late,
          ),
          ReplayEventData(
            id: 'tie-first',
            kind: ReplayEventKind.score,
            side: TeamSide.red,
            points: 1,
            elapsed: const Duration(seconds: 1),
            occurredAt: early,
          ),
          ReplayEventData(
            id: 'tie-second',
            kind: ReplayEventKind.score,
            side: TeamSide.red,
            points: 1,
            elapsed: const Duration(seconds: 1),
            occurredAt: early,
          ),
        ],
      ),
    );

    expect(controller.visibleEvents.map((event) => event.id).toList(), [
      'tie-first',
      'tie-second',
      'late',
    ]);
  });

  testWidgets('replay surfaces analytics summary, flow, and key possessions', (
    tester,
  ) async {
    final occurredAt = DateTime.utc(2026, 7, 18, 10);
    final analytics = MatchAnalytics(
      scoringFlow: [
        ScoringFlowEntry(
          eventId: 'r1',
          side: TeamSide.red,
          points: 2,
          redScore: 2,
          blueScore: 0,
          occurredAt: occurredAt,
        ),
        ScoringFlowEntry(
          eventId: 'b1',
          side: TeamSide.blue,
          points: 2,
          redScore: 2,
          blueScore: 2,
          occurredAt: occurredAt.add(const Duration(seconds: 10)),
        ),
      ],
      largestLeadSide: TeamSide.red,
      largestLeadPoints: 4,
      leadChanges: 2,
      madeShotCount: 2,
      missedShotCount: 1,
      shootingPercentage: 2 / 3,
      recordedShootingPercentage: 2 / 3,
      shootingPercentageIsTrustworthy: true,
      fieldGoalMadeCount: 2,
      fieldGoalAttemptCount: 3,
      keyPossessions: [
        KeyPossession(
          type: KeyPossessionType.overtake,
          eventId: 'r1',
          side: TeamSide.red,
          redScore: 2,
          blueScore: 0,
          occurredAt: occurredAt,
        ),
      ],
    );
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'match-analytics',
        redName: '赤焰',
        blueName: '海浪',
        redScore: 2,
        blueScore: 2,
        duration: const Duration(minutes: 5),
        analytics: analytics,
        events: const [],
      ),
    );
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );
    await tester.ensureVisible(find.text('比赛分析'));
    await tester.pumpAndSettle();

    expect(find.text('比赛分析'), findsOneWidget);
    expect(find.text('领先变化'), findsOneWidget);
    expect(find.text('2 次'), findsOneWidget);
    expect(find.text('赤焰 +4'), findsOneWidget);
    expect(find.text('67% · 2/3'), findsOneWidget);
    expect(find.text('比分流'), findsOneWidget);
    expect(find.text('2 : 2'), findsOneWidget);
    expect(find.text('关键回合'), findsOneWidget);
    expect(find.textContaining('反超'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('replay-analytics-summary')),
        matching: find.byType(Chip),
      ),
      findsNothing,
    );
  });

  testWidgets('shows a clear no-attempt state in compact landscape', (
    tester,
  ) async {
    final controller = ReplayController(
      data: ReplayMatchData(
        matchId: 'empty-analytics',
        redName: 'Red',
        blueName: 'Blue',
        redScore: 0,
        blueScore: 0,
        duration: Duration.zero,
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
        events: const [],
      ),
    );
    await tester.binding.setSurfaceSize(const Size(640, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: ReplayPage(controller: controller)),
    );
    await tester.ensureVisible(find.text('比赛分析'));
    await tester.pump();

    expect(find.text('暂无出手'), findsOneWidget);
    expect(find.text('0% · 0/0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
