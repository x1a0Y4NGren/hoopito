import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

export 'package:hoopito/core/domain/domain_enums.dart' show PossessionSource;

class PossessionSegment {
  const PossessionSegment({
    required this.id,
    required this.matchId,
    required this.side,
    required this.startedAtEventId,
    this.endedAtEventId,
    this.reason,
    this.source = PossessionSource.manual,
  });

  final String id;
  final String matchId;
  final TeamSide side;
  final String startedAtEventId;
  final String? endedAtEventId;
  final String? reason;
  final PossessionSource source;
}
