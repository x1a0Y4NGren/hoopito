import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/repositories/player_analytics_snapshot_repository.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'builds every eligible linked-player snapshot in one explicit rebuild',
    () async {
      final database = createTestDatabase();
      await _seedEligibleMatch(database);
      final repository = PlayerAnalyticsSnapshotRepository(database);

      await repository.ensureSnapshots();

      final snapshots = await database
          .select(database.playerAnalyticsSnapshots)
          .get();
      expect(snapshots, hasLength(2));
      final red = snapshots.singleWhere((row) => row.playerId == 'red-player');
      expect(red.opponentPlayerId, 'blue-player');
      expect(red.playerScore, 2);
      expect(red.opponentScore, 1);
      expect(red.fieldGoalMade, 1);
      expect(red.fieldGoalAttempts, 1);
      expect(red.freeThrowAttempts, 0);
    },
  );

  test('canonical event writes invalidate an existing snapshot', () async {
    final database = createTestDatabase();
    await _seedEligibleMatch(database);
    final repository = PlayerAnalyticsSnapshotRepository(database);
    await repository.ensureSnapshots(playerId: 'red-player');

    await database
        .into(database.matchEvents)
        .insert(
          MatchEventsCompanion.insert(
            id: 'late-score',
            matchId: 'match-1',
            type: 'score',
            side: const Value('red'),
            points: const Value(1),
            outcome: const Value('made'),
            occurredAt: DateTime.utc(2026, 8, 28, 9, 2),
          ),
        );

    expect(
      await database.select(database.playerAnalyticsSnapshots).get(),
      isEmpty,
    );
  });

  test(
    'a correction queued during rebuild cannot leave a stale snapshot',
    () async {
      final database = createTestDatabase();
      await _seedEligibleMatch(database);
      final repository = PlayerAnalyticsSnapshotRepository(database);

      final rebuild = repository.ensureSnapshots(playerId: 'red-player');
      final correction =
          (database.update(database.matchEvents)
                ..where((row) => row.id.equals('red-made')))
              .write(const MatchEventsCompanion(points: Value(3)));
      await Future.wait([rebuild, correction]);

      await repository.ensureSnapshots(playerId: 'red-player');
      final snapshot = await (database.select(
        database.playerAnalyticsSnapshots,
      )..where((row) => row.playerId.equals('red-player'))).getSingle();
      expect(snapshot.playerScore, 3);
    },
  );
}

Future<void> _seedEligibleMatch(AppDatabase database) async {
  await database.batch((batch) {
    batch.insertAll(database.players, [
      PlayerRow(
        id: 'red-player',
        nickname: 'Red',
        createdAt: DateTime.utc(2026),
      ),
      PlayerRow(
        id: 'blue-player',
        nickname: 'Blue',
        createdAt: DateTime.utc(2026),
      ),
    ]);
    batch.insert(
      database.matches,
      Matche(
        id: 'match-1',
        lifecycle: 'finished',
        recordingMode: 'detailed',
        trackingCoverage: 'locations',
        ruleTemplateJson: '{}',
        createdAt: DateTime.utc(2026, 8, 28, 9),
        startedAt: DateTime.utc(2026, 8, 28, 9),
        endedAt: DateTime.utc(2026, 8, 28, 9, 10),
        timerEnabled: false,
        note: null,
      ),
    );
    batch.insertAll(database.matchParticipants, [
      MatchParticipant(
        id: 'red-participant',
        matchId: 'match-1',
        side: 'red',
        nameSnapshot: 'Red',
        playerProfileId: 'red-player',
      ),
      MatchParticipant(
        id: 'blue-participant',
        matchId: 'match-1',
        side: 'blue',
        nameSnapshot: 'Blue',
        playerProfileId: 'blue-player',
      ),
    ]);
    batch.insertAll(database.matchEvents, [
      MatchEventRow(
        id: 'red-made',
        matchId: 'match-1',
        type: 'fieldGoal',
        side: 'red',
        points: 2,
        outcome: 'made',
        occurredAt: DateTime.utc(2026, 8, 28, 9, 1),
        note: null,
        matchClockPositionSeconds: null,
        customLabel: null,
        isDeleted: false,
      ),
      MatchEventRow(
        id: 'blue-made',
        matchId: 'match-1',
        type: 'freeThrow',
        side: 'blue',
        points: 1,
        outcome: 'made',
        occurredAt: DateTime.utc(2026, 8, 28, 9, 1, 1),
        note: null,
        matchClockPositionSeconds: null,
        customLabel: null,
        isDeleted: false,
      ),
    ]);
  });
}
