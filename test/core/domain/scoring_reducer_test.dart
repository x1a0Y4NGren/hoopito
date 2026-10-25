import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/scoring/scoring_reducer.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

void main() {
  test('score is derived from non-deleted score events only', () {
    final events = [
      MatchEvent.score(
        id: 'r1',
        matchId: 'm1',
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026),
      ),
      MatchEvent.score(
        id: 'b1',
        matchId: 'm1',
        side: TeamSide.blue,
        points: 3,
        occurredAt: DateTime.utc(2026),
      ),
      MatchEvent(
        id: 'deleted-score',
        matchId: 'm1',
        type: MatchEventType.score,
        side: TeamSide.red,
        points: 100,
        occurredAt: DateTime.utc(2026),
        isDeleted: true,
      ),
      MatchEvent(
        id: 'foul',
        matchId: 'm1',
        type: MatchEventType.foul,
        side: TeamSide.blue,
        points: 100,
        occurredAt: DateTime.utc(2026),
      ),
    ];

    final score = ScoringReducer().reduce(events);

    expect(score.redScore, 2);
    expect(score.blueScore, 3);
  });
}
