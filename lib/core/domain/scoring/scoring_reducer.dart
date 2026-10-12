import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

class ScoringReducer {
  ScoreState reduce(Iterable<MatchEvent> events) {
    var red = 0;
    var blue = 0;

    for (final event in events) {
      if (event.isDeleted ||
          (event.type != MatchEventType.score &&
              event.type != MatchEventType.fieldGoal &&
              event.type != MatchEventType.freeThrow)) {
        continue;
      }
      if ((event.type == MatchEventType.fieldGoal ||
              event.type == MatchEventType.freeThrow) &&
          event.outcome != ShotOutcome.made) {
        continue;
      }
      switch (event.side) {
        case TeamSide.red:
          red += event.points;
        case TeamSide.blue:
          blue += event.points;
        case null:
          break;
      }
    }

    return ScoreState(redScore: red, blueScore: blue);
  }
}
