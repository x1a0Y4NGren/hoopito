import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/domain/analytics/player_analytics_snapshot.dart';
import 'package:hoopito/core/domain/analytics/player_analytics_snapshot_calculator.dart';
import 'package:hoopito/core/domain/domain_enums.dart';

void main() {
  test('calculates a deterministic profile-linked match snapshot', () {
    final calculator = PlayerAnalyticsSnapshotCalculator();

    final snapshot = calculator.calculate(
      PlayerAnalyticsSnapshotCalculationRequest(
        matchId: 'match-1',
        playerId: 'player-1',
        opponentPlayerId: 'player-2',
        playerSide: 'red',
        playedAtUtc: DateTime.utc(2026, 8, 28, 9),
        trackingCoverage: TrackingCoverage.locations,
        events: const [
          PlayerAnalyticsSnapshotEventInput(
            id: 'red-made',
            side: 'red',
            type: EventKind.fieldGoal,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAtUtc: '2026-08-28T09:00:01.000Z',
            location: PlayerAnalyticsSnapshotLocationInput(
              id: 'location-1',
              x: 0.5,
              y: 0.08,
              isConfirmed: true,
            ),
          ),
          PlayerAnalyticsSnapshotEventInput(
            id: 'red-miss',
            side: 'red',
            type: EventKind.miss,
            points: 0,
            occurredAtUtc: '2026-08-28T09:00:02.000Z',
          ),
          PlayerAnalyticsSnapshotEventInput(
            id: 'blue-free-throw',
            side: 'blue',
            type: EventKind.freeThrow,
            points: 1,
            outcome: ShotOutcome.made,
            occurredAtUtc: '2026-08-28T09:00:03.000Z',
          ),
        ],
      ),
    );

    expect(snapshot.playerScore, 2);
    expect(snapshot.opponentScore, 1);
    expect(snapshot.fieldGoalMade, 1);
    expect(snapshot.fieldGoalAttempts, 2);
    expect(snapshot.freeThrowMade, 0);
    expect(snapshot.freeThrowAttempts, 0);
    expect(snapshot.locatableLocationCount, 1);
    expect(snapshot.confirmedLocationCount, 1);
    expect(snapshot.zoneDistributionJson, '{"restrictedArea":1}');
    expect(snapshot.sourceSha256, matches(RegExp(r'^[a-f0-9]{64}$')));
  });
}
