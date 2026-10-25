import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

/// A rebuildable, profile-keyed summary of one finished match.
class PlayerAnalyticsSnapshot {
  PlayerAnalyticsSnapshot({
    required this.matchId,
    required this.playerId,
    required this.opponentPlayerId,
    required DateTime playedAtUtc,
    required this.playerScore,
    required this.opponentScore,
    required this.fieldGoalMade,
    required this.fieldGoalAttempts,
    required this.freeThrowMade,
    required this.freeThrowAttempts,
    required this.trackingCoverage,
    required this.confirmedLocationCount,
    required this.locatableLocationCount,
    required this.zoneDistributionJson,
    required this.calculatorVersion,
    required this.sourceSha256,
  }) : playedAtUtc = playedAtUtc.toUtc();

  final String matchId;
  final String playerId;
  final String? opponentPlayerId;
  final DateTime playedAtUtc;
  final int playerScore;
  final int opponentScore;
  final int fieldGoalMade;
  final int fieldGoalAttempts;
  final int freeThrowMade;
  final int freeThrowAttempts;
  final TrackingCoverage trackingCoverage;
  final int confirmedLocationCount;
  final int locatableLocationCount;
  final String zoneDistributionJson;
  final int calculatorVersion;
  final String sourceSha256;
}

/// Canonical event data supplied to the pure snapshot calculator.
class PlayerAnalyticsSnapshotEventInput {
  const PlayerAnalyticsSnapshotEventInput({
    required this.id,
    required this.side,
    required this.type,
    required this.points,
    required this.occurredAtUtc,
    this.outcome,
    this.isDeleted = false,
    this.location,
  });

  final String id;
  final String? side;
  final EventKind type;
  final int points;
  final String occurredAtUtc;
  final ShotOutcome? outcome;
  final bool isDeleted;
  final PlayerAnalyticsSnapshotLocationInput? location;
}

/// A canonical, field-goal location joined to an event.
class PlayerAnalyticsSnapshotLocationInput {
  const PlayerAnalyticsSnapshotLocationInput({
    required this.id,
    required this.x,
    required this.y,
    required this.isConfirmed,
  });

  final String id;
  final double x;
  final double y;
  final bool isConfirmed;
}

/// Complete canonical inputs for a snapshot calculation.
class PlayerAnalyticsSnapshotCalculationRequest {
  const PlayerAnalyticsSnapshotCalculationRequest({
    required this.matchId,
    required this.playerId,
    required this.opponentPlayerId,
    required this.playerSide,
    required this.playedAtUtc,
    required this.trackingCoverage,
    required this.events,
  });

  final String matchId;
  final String playerId;
  final String? opponentPlayerId;
  final String playerSide;
  final DateTime playedAtUtc;
  final TrackingCoverage trackingCoverage;
  final List<PlayerAnalyticsSnapshotEventInput> events;
}

Map<String, int> zoneDistributionFromJson(Map<ShotZone, int> zones) => {
  for (final zone in ShotZone.values)
    if ((zones[zone] ?? 0) > 0) zone.name: zones[zone]!,
};
