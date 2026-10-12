import 'package:hoopito/core/domain/analytics/match_analytics.dart';

sealed class PlayerComparisonRequest {
  const PlayerComparisonRequest({required this.playerId});

  final String playerId;
}

class MatchPairComparisonRequest extends PlayerComparisonRequest {
  const MatchPairComparisonRequest({
    required super.playerId,
    required this.baselineMatchId,
    required this.currentMatchId,
  });

  final String baselineMatchId;
  final String currentMatchId;
}

class AdjacentWindowComparisonRequest extends PlayerComparisonRequest {
  AdjacentWindowComparisonRequest({
    required super.playerId,
    required this.window,
    required DateTime asOfUtc,
    this.opponentPlayerId,
  }) : asOfUtc = asOfUtc.toUtc();

  final PlayerComparisonWindow window;
  final DateTime asOfUtc;
  final String? opponentPlayerId;
}

enum PlayerComparisonWindow {
  sevenDays(Duration(days: 7)),
  thirtyDays(Duration(days: 30)),
  ninetyDays(Duration(days: 90));

  const PlayerComparisonWindow(this.duration);

  final Duration duration;
}

enum PlayerComparisonMode { matchPair, adjacentWindow }

enum PlayerComparisonMetric {
  result,
  matchCount,
  winRate,
  points,
  margin,
  fieldGoalsMade,
  fieldGoalAttempts,
  fieldGoalPercentage,
  freeThrowsMade,
  freeThrowAttempts,
  freeThrowPercentage,
  locationCoverage,
  confirmedZoneShare,
}

enum PlayerComparisonAvailability { available, unavailable }

enum ComparisonTrend { increase, decrease, equal, unavailable }

class PlayerComparisonSample {
  PlayerComparisonSample({
    required DateTime startUtc,
    required DateTime endUtc,
    required List<String> matchIds,
    required this.wins,
    required this.pointsFor,
    required this.pointsAgainst,
    required this.fieldGoalMade,
    required this.fieldGoalAttempts,
    required this.freeThrowMade,
    required this.freeThrowAttempts,
    required this.trustworthyAttemptMatchCount,
    required this.confirmedLocationCount,
    required this.locatableAttemptCount,
    required Map<ShotZone, int> zoneDistribution,
  }) : startUtc = startUtc.toUtc(),
       endUtc = endUtc.toUtc(),
       matchIds = List.unmodifiable(matchIds),
       zoneDistribution = Map.unmodifiable(zoneDistribution);

  factory PlayerComparisonSample.empty({
    required DateTime startUtc,
    required DateTime endUtc,
  }) => PlayerComparisonSample(
    startUtc: startUtc,
    endUtc: endUtc,
    matchIds: const [],
    wins: 0,
    pointsFor: 0,
    pointsAgainst: 0,
    fieldGoalMade: 0,
    fieldGoalAttempts: 0,
    freeThrowMade: 0,
    freeThrowAttempts: 0,
    trustworthyAttemptMatchCount: 0,
    confirmedLocationCount: 0,
    locatableAttemptCount: 0,
    zoneDistribution: const {},
  );

  final DateTime startUtc;
  final DateTime endUtc;
  final List<String> matchIds;
  final int wins;
  final int pointsFor;
  final int pointsAgainst;
  final int fieldGoalMade;
  final int fieldGoalAttempts;
  final int freeThrowMade;
  final int freeThrowAttempts;
  final int trustworthyAttemptMatchCount;
  final int confirmedLocationCount;
  final int locatableAttemptCount;
  final Map<ShotZone, int> zoneDistribution;

  int get matchCount => matchIds.length;
  int get margin => pointsFor - pointsAgainst;
  bool get isEmpty => matchIds.isEmpty;
  double? get averagePoints => isEmpty ? null : pointsFor / matchCount;
  double? get averageMargin => isEmpty ? null : margin / matchCount;
  bool get hasTrustworthyAttempts =>
      matchCount > 0 && trustworthyAttemptMatchCount == matchCount;
  double? get winRate => isEmpty ? null : wins * 100 / matchCount;
  double? get fieldGoalPercentage =>
      hasTrustworthyAttempts && fieldGoalAttempts > 0
      ? fieldGoalMade * 100 / fieldGoalAttempts
      : null;
  double? get freeThrowPercentage =>
      hasTrustworthyAttempts && freeThrowAttempts > 0
      ? freeThrowMade * 100 / freeThrowAttempts
      : null;
  double? get locationCoverage => fieldGoalAttempts > 0
      ? confirmedLocationCount * 100 / fieldGoalAttempts
      : null;
  int get result => pointsFor.compareTo(pointsAgainst);

  double? confirmedZoneShare(ShotZone zone) => confirmedLocationCount == 0
      ? null
      : (zoneDistribution[zone] ?? 0) * 100 / confirmedLocationCount;
}

class PlayerComparisonEvidence {
  const PlayerComparisonEvidence({
    required this.metric,
    required this.availability,
    required this.trend,
    required this.baselineValue,
    required this.currentValue,
    required this.delta,
    this.zone,
    this.isPercentagePoints = false,
    this.confirmedLocationSample = false,
  });

  final PlayerComparisonMetric metric;
  final PlayerComparisonAvailability availability;
  final ComparisonTrend trend;
  final double? baselineValue;
  final double? currentValue;
  final double? delta;
  final ShotZone? zone;
  final bool isPercentagePoints;
  final bool confirmedLocationSample;
}

class PlayerComparisonReport {
  PlayerComparisonReport({
    required this.mode,
    required this.baseline,
    required this.current,
    required List<PlayerComparisonEvidence> evidence,
  }) : evidence = List.unmodifiable(evidence);

  final PlayerComparisonMode mode;
  final PlayerComparisonSample baseline;
  final PlayerComparisonSample current;
  final List<PlayerComparisonEvidence> evidence;

  PlayerComparisonEvidence? evidenceFor(
    PlayerComparisonMetric metric, {
    ShotZone? zone,
  }) {
    for (final item in evidence) {
      if (item.metric == metric && item.zone == zone) return item;
    }
    return null;
  }
}

class PlayerComparisonReportBuilder {
  PlayerComparisonReport build({
    required PlayerComparisonSample baseline,
    required PlayerComparisonSample current,
    required PlayerComparisonMode mode,
  }) {
    final evidence = <PlayerComparisonEvidence>[
      if (mode == PlayerComparisonMode.matchPair)
        _available(
          PlayerComparisonMetric.result,
          baseline.result.toDouble(),
          current.result.toDouble(),
        )
      else ...[
        _available(
          PlayerComparisonMetric.matchCount,
          baseline.matchCount.toDouble(),
          current.matchCount.toDouble(),
        ),
        _optional(
          PlayerComparisonMetric.winRate,
          baseline.winRate,
          current.winRate,
          percentagePoints: true,
        ),
      ],
      _optional(
        PlayerComparisonMetric.points,
        mode == PlayerComparisonMode.matchPair
            ? (baseline.isEmpty ? null : baseline.pointsFor.toDouble())
            : baseline.averagePoints,
        mode == PlayerComparisonMode.matchPair
            ? (current.isEmpty ? null : current.pointsFor.toDouble())
            : current.averagePoints,
      ),
      _optional(
        PlayerComparisonMetric.margin,
        mode == PlayerComparisonMode.matchPair
            ? (baseline.isEmpty ? null : baseline.margin.toDouble())
            : baseline.averageMargin,
        mode == PlayerComparisonMode.matchPair
            ? (current.isEmpty ? null : current.margin.toDouble())
            : current.averageMargin,
      ),
      _optional(
        PlayerComparisonMetric.fieldGoalsMade,
        baseline.isEmpty ? null : baseline.fieldGoalMade.toDouble(),
        current.isEmpty ? null : current.fieldGoalMade.toDouble(),
      ),
      _optional(
        PlayerComparisonMetric.fieldGoalAttempts,
        baseline.isEmpty ? null : baseline.fieldGoalAttempts.toDouble(),
        current.isEmpty ? null : current.fieldGoalAttempts.toDouble(),
      ),
      _optional(
        PlayerComparisonMetric.fieldGoalPercentage,
        baseline.fieldGoalPercentage,
        current.fieldGoalPercentage,
        percentagePoints: true,
      ),
      _optional(
        PlayerComparisonMetric.freeThrowsMade,
        baseline.isEmpty ? null : baseline.freeThrowMade.toDouble(),
        current.isEmpty ? null : current.freeThrowMade.toDouble(),
      ),
      _optional(
        PlayerComparisonMetric.freeThrowAttempts,
        baseline.isEmpty ? null : baseline.freeThrowAttempts.toDouble(),
        current.isEmpty ? null : current.freeThrowAttempts.toDouble(),
      ),
      _optional(
        PlayerComparisonMetric.freeThrowPercentage,
        baseline.freeThrowPercentage,
        current.freeThrowPercentage,
        percentagePoints: true,
      ),
      _optional(
        PlayerComparisonMetric.locationCoverage,
        baseline.locationCoverage,
        current.locationCoverage,
        percentagePoints: true,
      ),
      for (final zone in ShotZone.values)
        _optional(
          PlayerComparisonMetric.confirmedZoneShare,
          baseline.confirmedZoneShare(zone),
          current.confirmedZoneShare(zone),
          zone: zone,
          percentagePoints: true,
          confirmedLocationSample: true,
        ),
    ];
    return PlayerComparisonReport(
      mode: mode,
      baseline: baseline,
      current: current,
      evidence: evidence,
    );
  }

  PlayerComparisonEvidence _optional(
    PlayerComparisonMetric metric,
    double? baseline,
    double? current, {
    ShotZone? zone,
    bool percentagePoints = false,
    bool confirmedLocationSample = false,
  }) {
    if (baseline == null || current == null) {
      return PlayerComparisonEvidence(
        metric: metric,
        availability: PlayerComparisonAvailability.unavailable,
        trend: ComparisonTrend.unavailable,
        baselineValue: baseline,
        currentValue: current,
        delta: null,
        zone: zone,
        isPercentagePoints: percentagePoints,
        confirmedLocationSample: confirmedLocationSample,
      );
    }
    return _available(
      metric,
      baseline,
      current,
      zone: zone,
      percentagePoints: percentagePoints,
      confirmedLocationSample: confirmedLocationSample,
    );
  }

  PlayerComparisonEvidence _available(
    PlayerComparisonMetric metric,
    double baseline,
    double current, {
    ShotZone? zone,
    bool percentagePoints = false,
    bool confirmedLocationSample = false,
  }) {
    final delta = current - baseline;
    final trend = delta > 0
        ? ComparisonTrend.increase
        : delta < 0
        ? ComparisonTrend.decrease
        : ComparisonTrend.equal;
    return PlayerComparisonEvidence(
      metric: metric,
      availability: PlayerComparisonAvailability.available,
      trend: trend,
      baselineValue: baseline,
      currentValue: current,
      delta: delta,
      zone: zone,
      isPercentagePoints: percentagePoints,
      confirmedLocationSample: confirmedLocationSample,
    );
  }
}

class PlayerComparisonMatch {
  PlayerComparisonMatch({
    required this.matchId,
    required DateTime playedAtUtc,
    required this.opponentPlayerId,
    required this.opponentNameSnapshot,
    required this.playerScore,
    required this.opponentScore,
  }) : playedAtUtc = playedAtUtc.toUtc();

  final String matchId;
  final DateTime playedAtUtc;
  final String? opponentPlayerId;
  final String opponentNameSnapshot;
  final int playerScore;
  final int opponentScore;
}

class PlayerComparisonException implements Exception {
  const PlayerComparisonException(this.message);

  final String message;

  @override
  String toString() => 'PlayerComparisonException: $message';
}
