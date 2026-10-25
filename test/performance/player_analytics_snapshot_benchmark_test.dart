import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_analytics_snapshot_repository.dart';

import '../test_helpers/test_database.dart';

const _matchCount = 1000;
const _eventCount = 10000;
const _snapshotBuildTarget = Duration(seconds: 2);

void main() {
  test(
    '1000-match and 10000-event cold snapshot rebuild stays below two seconds',
    () async {
      await withTestDatabase((database) async {
        await _seedSnapshotFixture(database);
        final repository = PlayerAnalyticsSnapshotRepository(database);

        final stopwatch = Stopwatch()..start();
        await repository.ensureSnapshots(playerId: 'profile-player');
        stopwatch.stop();

        final snapshots = await database
            .select(database.playerAnalyticsSnapshots)
            .get();
        debugPrint(
          'TASK2_SNAPSHOT_BENCHMARK '
          'cold_build_ms=${stopwatch.elapsedMicroseconds / 1000} '
          'matches=$_matchCount events=$_eventCount',
        );
        expect(snapshots, hasLength(_matchCount));
        expect(
          stopwatch.elapsed,
          lessThan(_snapshotBuildTarget),
          reason: 'snapshot cold build took ${stopwatch.elapsedMilliseconds}ms',
        );
      });
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _seedSnapshotFixture(AppDatabase database) async {
  final base = DateTime.utc(2026, 1, 1);
  final matches = <Matche>[];
  final participants = <MatchParticipant>[];
  final events = <MatchEventRow>[];
  for (var matchIndex = 0; matchIndex < _matchCount; matchIndex++) {
    final matchId = 'snapshot-match-${matchIndex.toString().padLeft(4, '0')}';
    final playedAt = base.add(Duration(minutes: matchIndex));
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
        nameSnapshot: 'Opponent $matchIndex',
        playerProfileId: null,
      ),
    ]);
    for (var eventIndex = 0; eventIndex < 10; eventIndex++) {
      events.add(
        MatchEventRow(
          id: '$matchId-event-$eventIndex',
          matchId: matchId,
          type: 'score',
          side: eventIndex.isEven ? 'red' : 'blue',
          points: 1,
          outcome: 'made',
          occurredAt: playedAt.add(Duration(milliseconds: eventIndex)),
          note: null,
          matchClockPositionSeconds: null,
          customLabel: null,
          isDeleted: false,
        ),
      );
    }
  }
  expect(events, hasLength(_eventCount));
  await database.batch((batch) {
    batch.insert(
      database.players,
      PlayerRow(id: 'profile-player', nickname: 'Profile', createdAt: base),
    );
    batch.insertAll(database.matches, matches);
    batch.insertAll(database.matchParticipants, participants);
    batch.insertAll(database.matchEvents, events);
  });
}
