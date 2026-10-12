import 'package:hoopito/core/domain/value_objects/court_point.dart';

class ShotLocation {
  const ShotLocation({
    required this.id,
    required this.matchId,
    required this.eventId,
    required this.point,
    required this.isConfirmed,
  });

  final String id;
  final String matchId;
  final String eventId;
  final CourtPoint point;
  final bool isConfirmed;
}
