import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

void main() {
  final events = [
    shot('fg-made', EventKind.fieldGoal, true),
    shot('fg-missed', EventKind.fieldGoal, false),
    shot('ft-made', EventKind.freeThrow, true),
    shot('ft-missed-1', EventKind.freeThrow, false),
    shot('ft-missed-2', EventKind.freeThrow, false),
  ];
  test('misses do not prove complete recording', () {
    final value = MatchAnalyticsCalculator().calculate(events);
    expect(value.trackingCoverage, TrackingCoverage.scoresOnly);
    expect(value.reliableShootingPercentage, isNull);
  });
  test('declared complete FG and FT use separate denominators', () {
    final value = MatchAnalyticsCalculator().calculate(
      events,
      trackingCoverage: TrackingCoverage.shotAttempts,
    );
    expect(value.reliableShootingPercentage, 0.5);
    expect(value.reliableFreeThrowPercentage, closeTo(1 / 3, 0.0001));
  });
  test('complete recording without attempts has no percentage', () {
    final value = MatchAnalyticsCalculator().calculate(
      [],
      trackingCoverage: TrackingCoverage.full,
    );
    expect(value.reliableShootingPercentage, isNull);
    expect(value.reliableFreeThrowPercentage, isNull);
  });
}

MatchEvent shot(String id, EventKind kind, bool made) => MatchEvent(
  id: id,
  matchId: 'm',
  type: kind,
  side: TeamSide.red,
  points: made ? (kind == EventKind.freeThrow ? 1 : 2) : 0,
  outcome: made ? ShotOutcome.made : ShotOutcome.missed,
  occurredAt: DateTime.utc(2026),
);
