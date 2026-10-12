import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

/// The supported UTC windows for profile career analytics.
enum PlayerCareerWindow { sevenDays, thirtyDays, ninetyDays, allTime }

/// Compatibility aliases keep the query vocabulary readable at call sites.
typedef CareerWindow = PlayerCareerWindow;
typedef CareerTimeWindow = PlayerCareerWindow;

extension PlayerCareerWindowDays on PlayerCareerWindow {
  int? get days => switch (this) {
    PlayerCareerWindow.sevenDays => 7,
    PlayerCareerWindow.thirtyDays => 30,
    PlayerCareerWindow.ninetyDays => 90,
    PlayerCareerWindow.allTime => null,
  };
}

/// A stable, UTC-relative career query.
class PlayerCareerQuery {
  const PlayerCareerQuery({
    this.window = PlayerCareerWindow.allTime,
    this.opponentPlayerId,
    this.asOfUtc,
  });

  const PlayerCareerQuery.sevenDays({
    String? opponentPlayerId,
    DateTime? asOfUtc,
  }) : this(
         window: PlayerCareerWindow.sevenDays,
         opponentPlayerId: opponentPlayerId,
         asOfUtc: asOfUtc,
       );

  const PlayerCareerQuery.thirtyDays({
    String? opponentPlayerId,
    DateTime? asOfUtc,
  }) : this(
         window: PlayerCareerWindow.thirtyDays,
         opponentPlayerId: opponentPlayerId,
         asOfUtc: asOfUtc,
       );

  const PlayerCareerQuery.ninetyDays({
    String? opponentPlayerId,
    DateTime? asOfUtc,
  }) : this(
         window: PlayerCareerWindow.ninetyDays,
         opponentPlayerId: opponentPlayerId,
         asOfUtc: asOfUtc,
       );

  const PlayerCareerQuery.allTime({String? opponentPlayerId})
    : this(
        window: PlayerCareerWindow.allTime,
        opponentPlayerId: opponentPlayerId,
      );

  final PlayerCareerWindow window;
  final String? opponentPlayerId;
  final DateTime? asOfUtc;

  DateTime? get startUtc {
    final days = window.days;
    if (days == null) return null;
    return (asOfUtc ?? DateTime.now().toUtc()).toUtc().subtract(
      Duration(days: days),
    );
  }
}

class PlayerCareerShootingTrend {
  const PlayerCareerShootingTrend({
    required this.matchId,
    required this.playedAt,
    required this.fieldGoalMade,
    required this.fieldGoalAttempts,
    required this.freeThrowMade,
    required this.freeThrowAttempts,
    required this.recordedAttempts,
    required this.recordedMakes,
    required this.isTrustworthy,
  });

  final String matchId;
  final DateTime playedAt;
  final int fieldGoalMade;
  final int fieldGoalAttempts;
  final int freeThrowMade;
  final int freeThrowAttempts;
  final int recordedAttempts;
  final int recordedMakes;
  final bool isTrustworthy;

  double? get recordedShootingPercentage =>
      isTrustworthy && fieldGoalAttempts > 0
      ? fieldGoalMade / fieldGoalAttempts
      : null;
  double? get freeThrowPercentage => isTrustworthy && freeThrowAttempts > 0
      ? freeThrowMade / freeThrowAttempts
      : null;
  double? get shootingPercentage => recordedShootingPercentage;
  double? get percentage => recordedShootingPercentage;

  @override
  bool operator ==(Object other) =>
      other is PlayerCareerShootingTrend &&
      other.matchId == matchId &&
      other.playedAt == playedAt &&
      other.fieldGoalMade == fieldGoalMade &&
      other.fieldGoalAttempts == fieldGoalAttempts &&
      other.freeThrowMade == freeThrowMade &&
      other.freeThrowAttempts == freeThrowAttempts &&
      other.recordedAttempts == recordedAttempts &&
      other.recordedMakes == recordedMakes &&
      other.isTrustworthy == isTrustworthy;

  @override
  int get hashCode => Object.hash(
    matchId,
    playedAt,
    fieldGoalMade,
    fieldGoalAttempts,
    freeThrowMade,
    freeThrowAttempts,
    recordedAttempts,
    recordedMakes,
    isTrustworthy,
  );
}

class PlayerCareerRecentChange {
  const PlayerCareerRecentChange({
    required this.latestMatchId,
    required this.previousMatchId,
    required this.latestPoints,
    required this.previousPoints,
    required this.latestMargin,
    required this.previousMargin,
    required this.latestShootingPercentage,
    required this.previousShootingPercentage,
  });

  const PlayerCareerRecentChange.empty()
    : latestMatchId = null,
      previousMatchId = null,
      latestPoints = null,
      previousPoints = null,
      latestMargin = null,
      previousMargin = null,
      latestShootingPercentage = null,
      previousShootingPercentage = null;

  final String? latestMatchId;
  final String? previousMatchId;
  final int? latestPoints;
  final int? previousPoints;
  final int? latestMargin;
  final int? previousMargin;
  final double? latestShootingPercentage;
  final double? previousShootingPercentage;

  double? get pointsDelta => latestPoints != null && previousPoints != null
      ? (latestPoints! - previousPoints!).toDouble()
      : null;
  double? get marginDelta => latestMargin != null && previousMargin != null
      ? (latestMargin! - previousMargin!).toDouble()
      : null;
  double? get shootingPercentageDelta =>
      latestShootingPercentage != null && previousShootingPercentage != null
      ? latestShootingPercentage! - previousShootingPercentage!
      : null;

  @override
  bool operator ==(Object other) =>
      other is PlayerCareerRecentChange &&
      other.latestMatchId == latestMatchId &&
      other.previousMatchId == previousMatchId &&
      other.latestPoints == latestPoints &&
      other.previousPoints == previousPoints &&
      other.latestMargin == latestMargin &&
      other.previousMargin == previousMargin &&
      other.latestShootingPercentage == latestShootingPercentage &&
      other.previousShootingPercentage == previousShootingPercentage;

  @override
  int get hashCode => Object.hash(
    latestMatchId,
    previousMatchId,
    latestPoints,
    previousPoints,
    latestMargin,
    previousMargin,
    latestShootingPercentage,
    previousShootingPercentage,
  );
}

/// A stable, profile-keyed summary of completed matches.
///
/// Only matches whose lifecycle is [MatchLifecycle.finished] or
/// [MatchLifecycle.archived] contribute to this value. The profile ID, not
/// the mutable display name, is the identity used by the repository.
class PlayerCareerAggregate {
  PlayerCareerAggregate({
    required this.playerId,
    required this.matches,
    required this.wins,
    required this.totalPoints,
    required this.averagePoints,
    required this.averageMargin,
    this.fieldGoalMade = 0,
    this.fieldGoalAttempts = 0,
    this.freeThrowMade = 0,
    this.freeThrowAttempts = 0,
    List<PlayerCareerShootingTrend> shootingTrend = const [],
    Map<ShotZone, int> zoneHeatmap = const {},
    this.recentChange = const PlayerCareerRecentChange.empty(),
  }) : shootingTrend = List.unmodifiable(shootingTrend),
       zoneHeatmap = Map.unmodifiable(zoneHeatmap);

  const PlayerCareerAggregate.empty(this.playerId)
    : matches = 0,
      wins = 0,
      totalPoints = 0,
      averagePoints = 0,
      averageMargin = 0,
      fieldGoalMade = 0,
      fieldGoalAttempts = 0,
      freeThrowMade = 0,
      freeThrowAttempts = 0,
      shootingTrend = const [],
      zoneHeatmap = const {},
      recentChange = const PlayerCareerRecentChange.empty();

  final String playerId;
  final int matches;
  final int wins;
  final int totalPoints;
  final double averagePoints;
  final double averageMargin;
  final int fieldGoalMade;
  final int fieldGoalAttempts;
  final int freeThrowMade;
  final int freeThrowAttempts;
  final List<PlayerCareerShootingTrend> shootingTrend;
  final Map<ShotZone, int> zoneHeatmap;
  final PlayerCareerRecentChange recentChange;

  List<PlayerCareerShootingTrend> get recordedShootingTrend => shootingTrend;
  Map<ShotZone, int> get zoneDistribution => zoneHeatmap;
  int get fieldGoalsMade => fieldGoalMade;
  int get fieldGoalAttemptsCount => fieldGoalAttempts;
  int get freeThrowsMade => freeThrowMade;
  int get freeThrowAttemptsCount => freeThrowAttempts;

  @override
  bool operator ==(Object other) {
    return other is PlayerCareerAggregate &&
        other.playerId == playerId &&
        other.matches == matches &&
        other.wins == wins &&
        other.totalPoints == totalPoints &&
        other.averagePoints == averagePoints &&
        other.averageMargin == averageMargin &&
        other.fieldGoalMade == fieldGoalMade &&
        other.fieldGoalAttempts == fieldGoalAttempts &&
        other.freeThrowMade == freeThrowMade &&
        other.freeThrowAttempts == freeThrowAttempts &&
        _listEquals(other.shootingTrend, shootingTrend) &&
        _mapEquals(other.zoneHeatmap, zoneHeatmap) &&
        other.recentChange == recentChange;
  }

  @override
  int get hashCode => Object.hash(
    playerId,
    matches,
    wins,
    totalPoints,
    averagePoints,
    averageMargin,
    fieldGoalMade,
    fieldGoalAttempts,
    freeThrowMade,
    freeThrowAttempts,
    Object.hashAll(shootingTrend),
    Object.hashAll(zoneHeatmap.entries),
    recentChange,
  );
}

bool _listEquals<T>(List<T> first, List<T> second) {
  if (first.length != second.length) return false;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) return false;
  }
  return true;
}

bool _mapEquals<K, V>(Map<K, V> first, Map<K, V> second) {
  if (first.length != second.length) return false;
  for (final entry in first.entries) {
    if (second[entry.key] != entry.value) return false;
  }
  return true;
}
