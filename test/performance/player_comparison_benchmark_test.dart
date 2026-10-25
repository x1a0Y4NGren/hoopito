import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_comparison_repository.dart';
import 'package:hoopito/core/domain/analytics/player_comparison.dart';

import '../test_helpers/test_database.dart';

const _matchCount = 1000;
const _warmComparisonTarget = Duration(milliseconds: 100);

void main() {
  test(
    'warm 1000-match comparison p95 stays below 100 milliseconds',
    () async {
      await withTestDatabase((database) async {
        await _seedWarmFixture(database);
        final repository = PlayerComparisonRepository(database);
        final request = AdjacentWindowComparisonRequest(
          playerId: 'profile-player',
          window: PlayerComparisonWindow.ninetyDays,
          asOfUtc: DateTime.utc(2026, 3, 1),
        );
        await repository.compare(request);

        final samples = <Duration>[];
        for (var index = 0; index < 25; index++) {
          final stopwatch = Stopwatch()..start();
          await repository.compare(request);
          stopwatch.stop();
          samples.add(stopwatch.elapsed);
        }
        samples.sort();
        final p95 = samples[23];
        debugPrint(
          'TASK4_COMPARISON_BENCHMARK '
          'p95_ms=${p95.inMicroseconds / 1000} matches=$_matchCount',
        );
        expect(p95, lessThan(_warmComparisonTarget));
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _seedWarmFixture(AppDatabase database) async {
  final base = DateTime.utc(2026, 1, 1);
  final matches = <Matche>[];
  final participants = <MatchParticipant>[];
  final snapshots = <PlayerAnalyticsSnapshotRow>[];
  for (var index = 0; index < _matchCount; index++) {
    final matchId = 'comparison-match-${index.toString().padLeft(4, '0')}';
    final playedAt = base.add(Duration(hours: index));
    matches.add(
      Matche(
        id: matchId,
        lifecycle: 'finished',
        recordingMode: 'detailed',
        trackingCoverage: 'shotAttempts',
        ruleTemplateJson: '{}',
        createdAt: playedAt,
        startedAt: playedAt,
        endedAt: playedAt.add(const Duration(minutes: 10)),
        timerEnabled: false,
        note: null,
      ),
    );
    participants.addAll([
      MatchParticipant(
        id: '$matchId-red',
        matchId: matchId,
        side: 'red',
        nameSnapshot: 'Profile',
        playerProfileId: 'profile-player',
      ),
      MatchParticipant(
        id: '$matchId-blue',
        matchId: matchId,
        side: 'blue',
        nameSnapshot: 'Opponent',
        playerProfileId: 'opponent-player',
      ),
    ]);
    snapshots.add(
      PlayerAnalyticsSnapshotRow(
        matchId: matchId,
        playerId: 'profile-player',
        opponentPlayerId: 'opponent-player',
        playedAtUtc: playedAt,
        playerScore: index.isEven ? 11 : 8,
        opponentScore: index.isEven ? 8 : 11,
        fieldGoalMade: 5,
        fieldGoalAttempts: 10,
        freeThrowMade: 1,
        freeThrowAttempts: 2,
        trackingCoverage: 'shotAttempts',
        confirmedLocationCount: 0,
        locatableLocationCount: 0,
        zoneDistributionJson: '{}',
        calculatorVersion: 1,
        sourceSha256: '0' * 64,
      ),
    );
  }
  await database.batch((batch) {
    batch.insertAll(database.players, [
      PlayerRow(id: 'profile-player', nickname: 'Profile', createdAt: base),
      PlayerRow(id: 'opponent-player', nickname: 'Opponent', createdAt: base),
    ]);
    batch.insertAll(database.matches, matches);
    batch.insertAll(database.matchParticipants, participants);
    batch.insertAll(database.playerAnalyticsSnapshots, snapshots);
  });
}
