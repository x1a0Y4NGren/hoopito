import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

void main() {
  test('court point rejects coordinates outside normalized court bounds', () {
    expect(() => CourtPoint(x: -0.1, y: 0.5), throwsArgumentError);
    expect(() => CourtPoint(x: 0.5, y: 1.1), throwsArgumentError);
    expect(CourtPoint(x: 0.25, y: 0.75).x, 0.25);
  });

  test('score event carries side and points', () {
    final event = MatchEvent.score(
      id: 'event-1',
      matchId: 'match-1',
      side: TeamSide.red,
      points: 2,
      occurredAt: DateTime.utc(2026, 5, 12, 12),
    );

    expect(event.side, TeamSide.red);
    expect(event.points, 2);
    expect(event.type, MatchEventType.score);
  });

  test(
    'score event requires side and positive points from base constructor',
    () {
      expect(
        () => MatchEvent(
          id: 'event-2',
          matchId: 'match-1',
          type: MatchEventType.score,
          side: null,
          points: 2,
          occurredAt: DateTime.utc(2026, 5, 12, 12),
        ),
        throwsArgumentError,
      );

      expect(
        () => MatchEvent(
          id: 'event-3',
          matchId: 'match-1',
          type: MatchEventType.score,
          side: TeamSide.red,
          points: 0,
          occurredAt: DateTime.utc(2026, 5, 12, 12),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'shot event combinations preserve missed free throws and field goals',
    () {
      final missedFreeThrow = MatchEvent(
        id: 'free-throw-missed',
        matchId: 'match-1',
        type: MatchEventType.freeThrow,
        side: TeamSide.red,
        points: 0,
        outcome: ShotOutcome.missed,
        occurredAt: DateTime.utc(2026, 5, 12, 12),
      );
      final missedFieldGoal = MatchEvent(
        id: 'field-goal-missed',
        matchId: 'match-1',
        type: MatchEventType.fieldGoal,
        side: TeamSide.blue,
        points: 0,
        outcome: ShotOutcome.missed,
        occurredAt: DateTime.utc(2026, 5, 12, 12),
      );

      expect(missedFreeThrow.points, 0);
      expect(missedFieldGoal.outcome, ShotOutcome.missed);
    },
  );

  test('shot event combinations reject ambiguous or impossible attempts', () {
    MatchEvent event({
      required MatchEventType type,
      TeamSide? side = TeamSide.red,
      required int points,
      ShotOutcome? outcome,
    }) => MatchEvent(
      id: '$type-$points-${outcome ?? 'none'}',
      matchId: 'match-1',
      type: type,
      side: side,
      points: points,
      outcome: outcome,
      occurredAt: DateTime.utc(2026, 5, 12, 12),
    );

    expect(
      () => event(
        type: MatchEventType.freeThrow,
        points: 0,
        outcome: ShotOutcome.made,
      ),
      throwsArgumentError,
    );
    expect(
      () => event(
        type: MatchEventType.freeThrow,
        side: null,
        points: 0,
        outcome: ShotOutcome.missed,
      ),
      throwsArgumentError,
    );
    expect(
      () => event(
        type: MatchEventType.fieldGoal,
        points: 0,
        outcome: ShotOutcome.made,
      ),
      throwsArgumentError,
    );
    expect(
      () => event(
        type: MatchEventType.fieldGoal,
        points: 2,
        outcome: ShotOutcome.missed,
      ),
      throwsArgumentError,
    );
    expect(
      () => event(type: MatchEventType.fieldGoal, points: 2, outcome: null),
      throwsArgumentError,
    );
    expect(
      () => event(
        type: MatchEventType.miss,
        side: null,
        points: 0,
        outcome: ShotOutcome.missed,
      ),
      throwsArgumentError,
    );
    expect(
      () => event(
        type: MatchEventType.miss,
        points: 2,
        outcome: ShotOutcome.missed,
      ),
      throwsArgumentError,
    );
    expect(
      () => event(
        type: MatchEventType.fieldGoal,
        points: 0,
        outcome: ShotOutcome.notApplicable,
      ),
      throwsArgumentError,
    );
    expect(
      MatchEvent(
        id: 'custom-timeout',
        matchId: 'match-1',
        type: MatchEventType.custom,
        side: null,
        points: 0,
        outcome: ShotOutcome.notApplicable,
        occurredAt: DateTime.utc(2026, 5, 12, 12),
      ).outcome,
      ShotOutcome.notApplicable,
    );
  });
}
