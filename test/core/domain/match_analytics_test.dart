import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/match_analytics_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/possession_segment.dart';
import 'package:hoopito/core/domain/entities/shot_location.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

void main() {
  final calculator = MatchAnalyticsCalculator();

  test(
    'calculates a stable chronological scoring flow and ignores deleted events',
    () {
      final start = DateTime.utc(2026);
      final events = [
        _score(
          'blue-later',
          TeamSide.blue,
          2,
          start.add(const Duration(minutes: 2)),
        ),
        _score(
          'red-first',
          TeamSide.red,
          2,
          start.add(const Duration(minutes: 1)),
        ),
        _score(
          'red-same-time',
          TeamSide.red,
          1,
          start.add(const Duration(minutes: 1)),
        ),
        MatchEvent(
          id: 'deleted',
          matchId: 'm1',
          type: MatchEventType.score,
          side: TeamSide.blue,
          points: 100,
          occurredAt: start,
          isDeleted: true,
        ),
      ];

      final analytics = calculator.calculate(events);

      expect(analytics.scoringFlow, [
        ScoringFlowEntry(
          eventId: 'red-first',
          side: TeamSide.red,
          points: 2,
          redScore: 2,
          blueScore: 0,
          occurredAt: start.add(const Duration(minutes: 1)),
        ),
        ScoringFlowEntry(
          eventId: 'red-same-time',
          side: TeamSide.red,
          points: 1,
          redScore: 3,
          blueScore: 0,
          occurredAt: start.add(const Duration(minutes: 1)),
        ),
        ScoringFlowEntry(
          eventId: 'blue-later',
          side: TeamSide.blue,
          points: 2,
          redScore: 3,
          blueScore: 2,
          occurredAt: start.add(const Duration(minutes: 2)),
        ),
      ]);
      expect(analytics.largestLeadSide, TeamSide.red);
      expect(analytics.largestLeadPoints, 3);
      expect(analytics.scoringRuns.single.eventIds, [
        'red-first',
        'red-same-time',
      ]);
    },
  );

  test('counts when non-tied leader switches across ties', () {
    final start = DateTime.utc(2026);
    final analytics = calculator.calculate([
      _score('r1', TeamSide.red, 2, start),
      _score('b1', TeamSide.blue, 2, start.add(const Duration(seconds: 1))),
      _score('b2', TeamSide.blue, 1, start.add(const Duration(seconds: 2))),
      _score('r2', TeamSide.red, 1, start.add(const Duration(seconds: 3))),
      _score('r3', TeamSide.red, 1, start.add(const Duration(seconds: 4))),
      _score('b3', TeamSide.blue, 3, start.add(const Duration(seconds: 5))),
    ]);

    expect(analytics.leadChanges, 3);
    expect(analytics.largestLeadSide, TeamSide.red);
    expect(analytics.largestLeadPoints, 2);
  });

  test('calculates shooting percentage from made and missed shots', () {
    final start = DateTime.utc(2026);
    final analytics = calculator.calculate([
      _score('r1', TeamSide.red, 2, start),
      _score('r2', TeamSide.red, 3, start.add(const Duration(seconds: 1))),
      _miss('r3', TeamSide.red, start.add(const Duration(seconds: 2))),
      _miss('b1', TeamSide.blue, start.add(const Duration(seconds: 3))),
      MatchEvent(
        id: 'deleted-miss',
        matchId: 'm1',
        type: MatchEventType.miss,
        side: TeamSide.blue,
        points: 0,
        occurredAt: start.add(const Duration(seconds: 4)),
        isDeleted: true,
      ),
    ], trackingCoverage: TrackingCoverage.shotAttempts);

    expect(analytics.madeShotCount, 2);
    expect(analytics.missedShotCount, 2);
    expect(analytics.shootingPercentage, 0.5);
    final empty = calculator.calculate(const []);
    expect(empty.shootingPercentage, 0);
    expect(empty.scoringFlow, isEmpty);
    expect(empty.largestLeadSide, isNull);
    expect(empty.largestLeadPoints, 0);
    expect(empty.leadChanges, 0);
  });

  test(
    'records tie, overtake, match point, and one scoring run possession',
    () {
      final start = DateTime.utc(2026);
      final analytics = calculator.calculate([
        _score('r1', TeamSide.red, 2, start),
        _score('b1', TeamSide.blue, 2, start.add(const Duration(seconds: 1))),
        _score('b2', TeamSide.blue, 2, start.add(const Duration(seconds: 2))),
        _score('r2', TeamSide.red, 3, start.add(const Duration(seconds: 3))),
        _score('r3', TeamSide.red, 1, start.add(const Duration(seconds: 4))),
        _score('r4', TeamSide.red, 1, start.add(const Duration(seconds: 5))),
      ], targetScore: 7);

      expect(analytics.keyPossessions, [
        KeyPossession(
          type: KeyPossessionType.tie,
          eventId: 'b1',
          side: TeamSide.blue,
          redScore: 2,
          blueScore: 2,
          occurredAt: start.add(const Duration(seconds: 1)),
        ),
        KeyPossession(
          type: KeyPossessionType.overtake,
          eventId: 'b2',
          side: TeamSide.blue,
          redScore: 2,
          blueScore: 4,
          occurredAt: start.add(const Duration(seconds: 2)),
        ),
        KeyPossession(
          type: KeyPossessionType.overtake,
          eventId: 'r2',
          side: TeamSide.red,
          redScore: 5,
          blueScore: 4,
          occurredAt: start.add(const Duration(seconds: 3)),
        ),
        KeyPossession(
          type: KeyPossessionType.matchPoint,
          eventId: 'r3',
          side: TeamSide.red,
          redScore: 6,
          blueScore: 4,
          occurredAt: start.add(const Duration(seconds: 4)),
        ),
        KeyPossession(
          type: KeyPossessionType.scoringRun,
          eventId: 'r4',
          side: TeamSide.red,
          redScore: 7,
          blueScore: 4,
          occurredAt: start.add(const Duration(seconds: 5)),
        ),
      ]);
    },
  );

  test('records an overtake after scoring through a tie', () {
    final start = DateTime.utc(2026);
    final analytics = calculator.calculate([
      _score('r1', TeamSide.red, 2, start),
      _score('b1', TeamSide.blue, 2, start.add(const Duration(seconds: 1))),
      _score('b2', TeamSide.blue, 1, start.add(const Duration(seconds: 2))),
    ]);

    expect(analytics.keyPossessions.map((item) => item.type), [
      KeyPossessionType.tie,
      KeyPossessionType.overtake,
    ]);
    expect(analytics.keyPossessions.last.eventId, 'b2');
  });

  test('win-by-two match point excludes ties and follows one-point leads', () {
    final start = DateTime.utc(2026);
    final analytics = calculator.calculate(
      [
        _score('b10', TeamSide.blue, 10, start),
        _score('r10', TeamSide.red, 10, start.add(const Duration(seconds: 1))),
        _score('r11', TeamSide.red, 1, start.add(const Duration(seconds: 2))),
      ],
      targetScore: 11,
      winByTwo: true,
    );

    expect(
      analytics.keyPossessions
          .where((item) => item.type == KeyPossessionType.matchPoint)
          .map((item) => item.eventId),
      ['b10', 'r11'],
    );
  });

  test(
    'analytics and nested value objects compare by value and expose immutable lists',
    () {
      final start = DateTime.utc(2026);
      final events = [_score('r1', TeamSide.red, 2, start)];
      final first = calculator.calculate(events);
      final second = calculator.calculate(events);

      expect(first, second);
      expect(first.scoringFlow.single, second.scoringFlow.single);
      expect(
        () => first.scoringFlow.add(first.scoringFlow.single),
        throwsUnsupportedError,
      );
      expect(
        () => first.keyPossessions.add(
          KeyPossession(
            type: KeyPossessionType.tie,
            eventId: 'unused',
            side: TeamSide.red,
            redScore: 1,
            blueScore: 1,
            occurredAt: start,
          ),
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('counts legacy, field-goal, and free-throw attempts by outcome', () {
    final start = DateTime.utc(2026);
    final analytics = calculator.calculate([
      _score('legacy', TeamSide.red, 2, start),
      _fieldGoal(
        'fg-made',
        TeamSide.red,
        ShotOutcome.made,
        3,
        start.add(const Duration(seconds: 1)),
      ),
      _freeThrow(
        'ft-made',
        TeamSide.blue,
        ShotOutcome.made,
        1,
        start.add(const Duration(seconds: 2)),
      ),
      _miss(
        'legacy-miss',
        TeamSide.blue,
        start.add(const Duration(seconds: 3)),
      ),
      _fieldGoal(
        'fg-miss',
        TeamSide.red,
        ShotOutcome.missed,
        0,
        start.add(const Duration(seconds: 4)),
      ),
    ], trackingCoverage: TrackingCoverage.shotAttempts);

    expect(analytics.madeShotCount, 3);
    expect(analytics.missedShotCount, 2);
    expect(analytics.shotAttemptCount, 5);
    expect(analytics.shootingPercentage, closeTo(0.5, 0.0001));
    expect(analytics.recordedShootingPercentage, closeTo(0.5, 0.0001));
    expect(analytics.reliableFreeThrowPercentage, 1);
    expect(analytics.fieldGoalMadeCount, 2);
    expect(analytics.fieldGoalAttemptCount, 4);
    expect(analytics.freeThrowMadeCount, 1);
    expect(analytics.freeThrowAttemptCount, 1);
    expect(analytics.scoringFlow.map((entry) => entry.eventId), [
      'legacy',
      'fg-made',
      'ft-made',
    ]);
  });

  test('does not claim a perfect rate when only scores were recorded', () {
    final analytics = calculator.calculate([
      _score('score-only', TeamSide.red, 2, DateTime.utc(2026)),
    ], trackingCoverage: TrackingCoverage.scoresOnly);

    expect(analytics.recordedShootingPercentage, isNull);
    expect(analytics.shootingPercentageIsTrustworthy, isFalse);
    expect(analytics.shootingPercentage, isNot(1.0));
  });

  test('reports confirmed location coverage and zone distribution', () {
    final start = DateTime.utc(2026);
    final events = [
      _score('s1', TeamSide.red, 2, start),
      _score('s2', TeamSide.red, 2, start.add(const Duration(seconds: 1))),
      _score('s3', TeamSide.blue, 3, start.add(const Duration(seconds: 2))),
      _miss('m1', TeamSide.blue, start.add(const Duration(seconds: 3))),
      _miss('m2', TeamSide.red, start.add(const Duration(seconds: 4))),
      _freeThrow(
        'ft1',
        TeamSide.red,
        ShotOutcome.missed,
        0,
        start.add(const Duration(seconds: 5)),
      ),
    ];
    final analytics = calculator.calculate(
      events,
      trackingCoverage: TrackingCoverage.locations,
      shotLocations: [
        _location('l1', 's1', 0.5, 0.15, true),
        _location('l2', 's2', 0.2, 0.8, true),
        _location('l3', 's3', 0.8, 0.8, true),
      ],
    );

    expect(analytics.confirmedLocationCount, 3);
    expect(analytics.fieldGoalAttemptCount, 5);
    expect(analytics.freeThrowAttemptCount, 1);
    expect(analytics.locationCoverage, closeTo(0.6, 0.0001));
    expect(analytics.zoneDistribution.values.reduce((a, b) => a + b), 3);
    expect(analytics.zoneDistribution, isNotEmpty);
  });

  test('reports fouls, possession count, and completed scoring runs', () {
    final start = DateTime.utc(2026);
    final analytics = calculator.calculate(
      [
        _score('r1', TeamSide.red, 1, start),
        _score('r2', TeamSide.red, 2, start),
        MatchEvent(
          id: 'f1',
          matchId: 'm1',
          type: MatchEventType.foul,
          side: TeamSide.blue,
          points: 0,
          occurredAt: start,
        ),
        _score('b1', TeamSide.blue, 2, start.add(const Duration(seconds: 1))),
        MatchEvent(
          id: 'f2',
          matchId: 'm1',
          type: MatchEventType.foul,
          side: TeamSide.red,
          points: 0,
          occurredAt: start.add(const Duration(seconds: 2)),
        ),
      ],
      possessionSegments: [
        const PossessionSegment(
          id: 'p1',
          matchId: 'm1',
          side: TeamSide.red,
          startedAtEventId: 'r1',
        ),
        const PossessionSegment(
          id: 'p2',
          matchId: 'm1',
          side: TeamSide.blue,
          startedAtEventId: 'b1',
        ),
      ],
    );

    expect(analytics.redFoulCount, 1);
    expect(analytics.blueFoulCount, 1);
    expect(analytics.foulCount, 2);
    expect(analytics.possessionCount, 2);
    expect(analytics.scoringRuns.single.eventCount, 2);
    expect(analytics.scoringRuns.single.points, 3);
  });
}

MatchEvent _score(String id, TeamSide side, int points, DateTime occurredAt) {
  return MatchEvent.score(
    id: id,
    matchId: 'm1',
    side: side,
    points: points,
    occurredAt: occurredAt,
  );
}

MatchEvent _miss(String id, TeamSide side, DateTime occurredAt) {
  return MatchEvent(
    id: id,
    matchId: 'm1',
    type: MatchEventType.miss,
    side: side,
    points: 0,
    occurredAt: occurredAt,
  );
}

MatchEvent _fieldGoal(
  String id,
  TeamSide side,
  ShotOutcome outcome,
  int points,
  DateTime occurredAt,
) {
  return MatchEvent(
    id: id,
    matchId: 'm1',
    type: MatchEventType.fieldGoal,
    side: side,
    points: points,
    outcome: outcome,
    occurredAt: occurredAt,
  );
}

MatchEvent _freeThrow(
  String id,
  TeamSide side,
  ShotOutcome outcome,
  int points,
  DateTime occurredAt,
) {
  return MatchEvent(
    id: id,
    matchId: 'm1',
    type: MatchEventType.freeThrow,
    side: side,
    points: points,
    outcome: outcome,
    occurredAt: occurredAt,
  );
}

ShotLocation _location(
  String id,
  String eventId,
  double x,
  double y,
  bool isConfirmed,
) {
  return ShotLocation(
    id: id,
    matchId: 'm1',
    eventId: eventId,
    point: CourtPoint(x: x, y: y),
    isConfirmed: isConfirmed,
  );
}
