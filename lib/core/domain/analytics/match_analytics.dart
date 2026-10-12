import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

enum KeyPossessionType { tie, overtake, matchPoint, scoringRun }

/// Coarse court buckets used by single-match shot summaries.
///
/// Coordinates are deliberately kept out of the persisted domain model. The
/// calculator maps normalized court points into these stable buckets so the
/// UI can choose its own presentation and localization.
enum ShotZone {
  restrictedArea,
  paint,
  midRange,
  cornerThree,
  wingThree,
  topThree,
  unknown,
}

class ScoringRun {
  ScoringRun({
    required this.side,
    required List<String> eventIds,
    required this.points,
    required this.startedAt,
    required this.endedAt,
  }) : eventIds = List.unmodifiable(eventIds);

  final TeamSide side;
  final List<String> eventIds;
  final int points;
  final DateTime startedAt;
  final DateTime endedAt;

  int get eventCount => eventIds.length;

  /// Compatibility-friendly alias for callers that call a run's event count
  /// its length.
  int get length => eventCount;

  @override
  bool operator ==(Object other) {
    return other is ScoringRun &&
        other.side == side &&
        _listEquals(other.eventIds, eventIds) &&
        other.points == points &&
        other.startedAt == startedAt &&
        other.endedAt == endedAt;
  }

  @override
  int get hashCode =>
      Object.hash(side, Object.hashAll(eventIds), points, startedAt, endedAt);
}

class ScoringFlowEntry {
  const ScoringFlowEntry({
    required this.eventId,
    required this.side,
    required this.points,
    required this.redScore,
    required this.blueScore,
    required this.occurredAt,
  });

  final String eventId;
  final TeamSide side;
  final int points;
  final int redScore;
  final int blueScore;
  final DateTime occurredAt;

  @override
  bool operator ==(Object other) {
    return other is ScoringFlowEntry &&
        other.eventId == eventId &&
        other.side == side &&
        other.points == points &&
        other.redScore == redScore &&
        other.blueScore == blueScore &&
        other.occurredAt == occurredAt;
  }

  @override
  int get hashCode =>
      Object.hash(eventId, side, points, redScore, blueScore, occurredAt);
}

class KeyPossession {
  const KeyPossession({
    required this.type,
    required this.eventId,
    required this.side,
    required this.redScore,
    required this.blueScore,
    required this.occurredAt,
  });

  final KeyPossessionType type;
  final String eventId;
  final TeamSide side;
  final int redScore;
  final int blueScore;
  final DateTime occurredAt;

  @override
  bool operator ==(Object other) {
    return other is KeyPossession &&
        other.type == type &&
        other.eventId == eventId &&
        other.side == side &&
        other.redScore == redScore &&
        other.blueScore == blueScore &&
        other.occurredAt == occurredAt;
  }

  @override
  int get hashCode =>
      Object.hash(type, eventId, side, redScore, blueScore, occurredAt);
}

class MatchAnalytics {
  MatchAnalytics({
    required List<ScoringFlowEntry> scoringFlow,
    required this.largestLeadSide,
    required this.largestLeadPoints,
    required this.leadChanges,
    required this.madeShotCount,
    required this.missedShotCount,
    required this.shootingPercentage,
    required List<KeyPossession> keyPossessions,
    this.recordedShootingPercentage,
    this.shootingPercentageIsTrustworthy = false,
    this.trackingCoverage = TrackingCoverage.scoresOnly,
    this.fieldGoalMadeCount = 0,
    this.fieldGoalAttemptCount = 0,
    this.freeThrowMadeCount = 0,
    this.freeThrowAttemptCount = 0,
    this.redFoulCount = 0,
    this.blueFoulCount = 0,
    this.possessionCount,
    this.shotAttemptCount,
    this.confirmedLocationCount = 0,
    this.locationCoverage = 0,
    Map<ShotZone, int> zoneDistribution = const {},
    List<ScoringRun> scoringRuns = const [],
  }) : scoringFlow = List.unmodifiable(scoringFlow),
       keyPossessions = List.unmodifiable(keyPossessions),
       zoneDistribution = Map.unmodifiable(zoneDistribution),
       scoringRuns = List.unmodifiable(scoringRuns);

  final List<ScoringFlowEntry> scoringFlow;
  final TeamSide? largestLeadSide;
  final int largestLeadPoints;
  final int leadChanges;
  final int madeShotCount;
  final int missedShotCount;
  final double shootingPercentage;
  final List<KeyPossession> keyPossessions;
  final double? recordedShootingPercentage;
  final bool shootingPercentageIsTrustworthy;
  final TrackingCoverage trackingCoverage;
  final int fieldGoalMadeCount;
  final int fieldGoalAttemptCount;
  final int freeThrowMadeCount;
  final int freeThrowAttemptCount;
  final int redFoulCount;
  final int blueFoulCount;
  final int? possessionCount;
  final int? shotAttemptCount;
  final int confirmedLocationCount;
  final double locationCoverage;
  final Map<ShotZone, int> zoneDistribution;
  final List<ScoringRun> scoringRuns;

  int get foulCount => redFoulCount + blueFoulCount;

  /// A nullable form for new consumers. [shootingPercentage] remains a
  /// non-null compatibility field and is zero when the recording is not
  /// sufficient to make a truthful claim.
  double? get reliableShootingPercentage => recordedShootingPercentage;

  double? get reliableFreeThrowPercentage =>
      trackingCoverage.index >= TrackingCoverage.shotAttempts.index &&
          freeThrowAttemptCount > 0
      ? freeThrowMadeCount / freeThrowAttemptCount
      : null;

  bool get hasReliableShootingPercentage =>
      shootingPercentageIsTrustworthy && recordedShootingPercentage != null;

  double get confirmedLocationCoverage => locationCoverage;

  int get locatedShotCount => confirmedLocationCount;

  int get attempts => shotAttemptCount ?? (madeShotCount + missedShotCount);

  @override
  bool operator ==(Object other) {
    return other is MatchAnalytics &&
        _listEquals(other.scoringFlow, scoringFlow) &&
        other.largestLeadSide == largestLeadSide &&
        other.largestLeadPoints == largestLeadPoints &&
        other.leadChanges == leadChanges &&
        other.madeShotCount == madeShotCount &&
        other.missedShotCount == missedShotCount &&
        other.shootingPercentage == shootingPercentage &&
        _listEquals(other.keyPossessions, keyPossessions) &&
        other.recordedShootingPercentage == recordedShootingPercentage &&
        other.shootingPercentageIsTrustworthy ==
            shootingPercentageIsTrustworthy &&
        other.trackingCoverage == trackingCoverage &&
        other.fieldGoalMadeCount == fieldGoalMadeCount &&
        other.fieldGoalAttemptCount == fieldGoalAttemptCount &&
        other.freeThrowMadeCount == freeThrowMadeCount &&
        other.freeThrowAttemptCount == freeThrowAttemptCount &&
        other.redFoulCount == redFoulCount &&
        other.blueFoulCount == blueFoulCount &&
        other.possessionCount == possessionCount &&
        other.shotAttemptCount == shotAttemptCount &&
        other.confirmedLocationCount == confirmedLocationCount &&
        other.locationCoverage == locationCoverage &&
        _mapEquals(other.zoneDistribution, zoneDistribution) &&
        _listEquals(other.scoringRuns, scoringRuns);
  }

  @override
  int get hashCode => Object.hashAll([
    Object.hashAll(scoringFlow),
    largestLeadSide,
    largestLeadPoints,
    leadChanges,
    madeShotCount,
    missedShotCount,
    shootingPercentage,
    Object.hashAll(keyPossessions),
    recordedShootingPercentage,
    shootingPercentageIsTrustworthy,
    trackingCoverage,
    fieldGoalMadeCount,
    fieldGoalAttemptCount,
    freeThrowMadeCount,
    freeThrowAttemptCount,
    redFoulCount,
    blueFoulCount,
    possessionCount,
    shotAttemptCount,
    confirmedLocationCount,
    locationCoverage,
    Object.hashAll(zoneDistribution.entries),
    Object.hashAll(scoringRuns),
  ]);
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (var index = 0; index < first.length; index++) {
    if (first[index] != second[index]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> first, Map<K, V> second) {
  if (identical(first, second)) return true;
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) return false;
  }
  return true;
}
