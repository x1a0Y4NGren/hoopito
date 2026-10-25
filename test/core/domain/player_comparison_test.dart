import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/match_analytics.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';

void main() {
  test('match evidence reports exact changes without interpretation', () {
    final report = PlayerComparisonReportBuilder().build(
      baseline: _sample(
        id: 'older',
        wins: 0,
        pointsFor: 8,
        pointsAgainst: 11,
        fieldGoalMade: 3,
        fieldGoalAttempts: 8,
        freeThrowMade: 2,
        freeThrowAttempts: 2,
        confirmedLocations: 4,
        locatableAttempts: 6,
        zones: const {ShotZone.paint: 1, ShotZone.wingThree: 3},
      ),
      current: _sample(
        id: 'newer',
        wins: 1,
        pointsFor: 11,
        pointsAgainst: 7,
        fieldGoalMade: 5,
        fieldGoalAttempts: 10,
        freeThrowMade: 1,
        freeThrowAttempts: 2,
        confirmedLocations: 5,
        locatableAttempts: 8,
        zones: const {ShotZone.paint: 3, ShotZone.wingThree: 2},
      ),
      mode: PlayerComparisonMode.matchPair,
    );

    expect(
      report.evidenceFor(PlayerComparisonMetric.points),
      isA<PlayerComparisonEvidence>()
          .having((value) => value.trend, 'trend', ComparisonTrend.increase)
          .having((value) => value.delta, 'delta', 3),
    );
    expect(report.evidenceFor(PlayerComparisonMetric.margin)?.delta, 7);
    expect(
      report.evidenceFor(PlayerComparisonMetric.fieldGoalPercentage),
      isA<PlayerComparisonEvidence>()
          .having((value) => value.delta, 'percentage-point delta', 12.5)
          .having((value) => value.isPercentagePoints, 'unit', isTrue),
    );
    expect(
      report.evidenceFor(
        PlayerComparisonMetric.confirmedZoneShare,
        zone: ShotZone.paint,
      ),
      isA<PlayerComparisonEvidence>()
          .having((value) => value.delta, 'percentage-point delta', 35)
          .having((value) => value.confirmedLocationSample, 'sample', isTrue),
    );
  });

  test('insufficient tracking makes percentage evidence unavailable', () {
    final report = PlayerComparisonReportBuilder().build(
      baseline: _sample(id: 'baseline', trustworthyAttempts: false),
      current: _sample(id: 'current'),
      mode: PlayerComparisonMode.matchPair,
    );

    expect(
      report.evidenceFor(PlayerComparisonMetric.fieldGoalPercentage)?.trend,
      ComparisonTrend.unavailable,
    );
    expect(
      report.evidenceFor(PlayerComparisonMetric.freeThrowPercentage)?.trend,
      ComparisonTrend.unavailable,
    );
    expect(
      report.evidenceFor(PlayerComparisonMetric.locationCoverage)?.trend,
      ComparisonTrend.equal,
    );
  });

  test('empty window keeps match count but marks rates unavailable', () {
    final report = PlayerComparisonReportBuilder().build(
      baseline: PlayerComparisonSample.empty(
        startUtc: DateTime.utc(2026, 8, 14),
        endUtc: DateTime.utc(2026, 8, 21),
      ),
      current: _sample(id: 'current'),
      mode: PlayerComparisonMode.adjacentWindow,
    );

    expect(
      report.evidenceFor(PlayerComparisonMetric.matchCount)?.baselineValue,
      0,
    );
    expect(
      report.evidenceFor(PlayerComparisonMetric.winRate)?.trend,
      ComparisonTrend.unavailable,
    );
  });

  test('window point and margin evidence uses per-match averages', () {
    final baseline = PlayerComparisonSample(
      startUtc: DateTime.utc(2026, 8, 1),
      endUtc: DateTime.utc(2026, 8, 8),
      matchIds: const ['a', 'b'],
      wins: 1,
      pointsFor: 20,
      pointsAgainst: 16,
      fieldGoalMade: 8,
      fieldGoalAttempts: 16,
      freeThrowMade: 4,
      freeThrowAttempts: 4,
      trustworthyAttemptMatchCount: 2,
      confirmedLocationCount: 0,
      locatableAttemptCount: 0,
      zoneDistribution: const {},
    );
    final report = PlayerComparisonReportBuilder().build(
      baseline: baseline,
      current: _sample(id: 'current', pointsFor: 12, pointsAgainst: 8),
      mode: PlayerComparisonMode.adjacentWindow,
    );

    expect(report.evidenceFor(PlayerComparisonMetric.points)?.delta, 2);
    expect(report.evidenceFor(PlayerComparisonMetric.margin)?.delta, 2);
  });
}

PlayerComparisonSample _sample({
  required String id,
  int wins = 1,
  int pointsFor = 10,
  int pointsAgainst = 8,
  int fieldGoalMade = 4,
  int fieldGoalAttempts = 8,
  int freeThrowMade = 2,
  int freeThrowAttempts = 2,
  int confirmedLocations = 4,
  int locatableAttempts = 6,
  bool trustworthyAttempts = true,
  Map<ShotZone, int> zones = const {ShotZone.paint: 2, ShotZone.wingThree: 2},
}) {
  return PlayerComparisonSample(
    startUtc: DateTime.utc(2026, 8, 28),
    endUtc: DateTime.utc(2026, 8, 29),
    matchIds: [id],
    wins: wins,
    pointsFor: pointsFor,
    pointsAgainst: pointsAgainst,
    fieldGoalMade: fieldGoalMade,
    fieldGoalAttempts: fieldGoalAttempts,
    freeThrowMade: freeThrowMade,
    freeThrowAttempts: freeThrowAttempts,
    trustworthyAttemptMatchCount: trustworthyAttempts ? 1 : 0,
    confirmedLocationCount: confirmedLocations,
    locatableAttemptCount: locatableAttempts,
    zoneDistribution: zones,
  );
}
