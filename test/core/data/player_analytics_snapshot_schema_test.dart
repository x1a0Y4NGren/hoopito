import 'package:drift/drift.dart' show Value;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';

import '../../test_helpers/test_database.dart';
import '../../generated_migrations/schema.dart';
import '../../generated_migrations/schema_v3.dart' as v3;

void main() {
  test(
    'schema v3 declares the derived player analytics snapshot table',
    () async {
      final database = createTestDatabase();

      expect(database.schemaVersion, 3);
      final tables = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      expect(
        tables.map((row) => row.read<String>('name')),
        contains('player_analytics_snapshots'),
      );
      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      expect(
        indexes.map((row) => row.read<String>('name')),
        containsAll([
          'player_analytics_snapshots_player_played_at',
          'player_analytics_snapshots_player_opponent_played_at',
        ]),
      );
    },
  );

  test('schema v3 declares every canonical invalidation trigger', () async {
    final database = createTestDatabase();
    final triggers = await database
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'trigger' "
          "AND name LIKE 'player_analytics_snapshots_invalidate_%'",
        )
        .get();

    expect(
      triggers.map((row) => row.read<String>('name')),
      containsAll(<String>[
        'player_analytics_snapshots_invalidate_matches_insert',
        'player_analytics_snapshots_invalidate_matches_update',
        'player_analytics_snapshots_invalidate_matches_delete',
        'player_analytics_snapshots_invalidate_match_participants_insert',
        'player_analytics_snapshots_invalidate_match_participants_update',
        'player_analytics_snapshots_invalidate_match_participants_delete',
        'player_analytics_snapshots_invalidate_match_events_insert',
        'player_analytics_snapshots_invalidate_match_events_update',
        'player_analytics_snapshots_invalidate_match_events_delete',
        'player_analytics_snapshots_invalidate_shot_locations_insert',
        'player_analytics_snapshots_invalidate_shot_locations_update',
        'player_analytics_snapshots_invalidate_shot_locations_delete',
      ]),
    );
    expect(triggers, hasLength(12));
  });

  final invalidationCases =
      <
        ({
          String name,
          bool participant,
          bool event,
          bool location,
          Future<void> Function(AppDatabase) mutate,
        })
      >[
        (
          name: 'match update',
          participant: false,
          event: false,
          location: false,
          mutate: (database) =>
              (database.update(database.matches)
                    ..where((row) => row.id.equals('match-1')))
                  .write(const MatchesCompanion(note: Value('corrected'))),
        ),
        (
          name: 'match delete',
          participant: false,
          event: false,
          location: false,
          mutate: (database) => (database.delete(
            database.matches,
          )..where((row) => row.id.equals('match-1'))).go(),
        ),
        (
          name: 'participant insert',
          participant: false,
          event: false,
          location: false,
          mutate: (database) => database
              .into(database.matchParticipants)
              .insert(_participant('participant-1', 'match-1')),
        ),
        (
          name: 'participant update',
          participant: true,
          event: false,
          location: false,
          mutate: (database) =>
              (database.update(
                database.matchParticipants,
              )..where((row) => row.id.equals('participant-1'))).write(
                const MatchParticipantsCompanion(
                  nameSnapshot: Value('Corrected'),
                ),
              ),
        ),
        (
          name: 'participant delete',
          participant: true,
          event: false,
          location: false,
          mutate: (database) => (database.delete(
            database.matchParticipants,
          )..where((row) => row.id.equals('participant-1'))).go(),
        ),
        (
          name: 'event insert',
          participant: false,
          event: false,
          location: false,
          mutate: (database) =>
              database.into(database.matchEvents).insert(_event()),
        ),
        (
          name: 'event update',
          participant: false,
          event: true,
          location: false,
          mutate: (database) =>
              (database.update(database.matchEvents)
                    ..where((row) => row.id.equals('event-1')))
                  .write(const MatchEventsCompanion(points: Value(3))),
        ),
        (
          name: 'event delete',
          participant: false,
          event: true,
          location: false,
          mutate: (database) => (database.delete(
            database.matchEvents,
          )..where((row) => row.id.equals('event-1'))).go(),
        ),
        (
          name: 'location insert',
          participant: false,
          event: true,
          location: false,
          mutate: (database) =>
              database.into(database.shotLocations).insert(_location()),
        ),
        (
          name: 'location update',
          participant: false,
          event: true,
          location: true,
          mutate: (database) =>
              (database.update(database.shotLocations)
                    ..where((row) => row.id.equals('location-1')))
                  .write(const ShotLocationsCompanion(x: Value(0.3))),
        ),
        (
          name: 'location delete',
          participant: false,
          event: true,
          location: true,
          mutate: (database) => (database.delete(
            database.shotLocations,
          )..where((row) => row.id.equals('location-1'))).go(),
        ),
      ];
  for (final scenario in invalidationCases) {
    test('${scenario.name} invalidates only its match snapshots', () async {
      final database = createTestDatabase();
      await _seedOperationFixture(
        database,
        participant: scenario.participant,
        event: scenario.event,
        location: scenario.location,
      );

      await scenario.mutate(database);

      final snapshots = await database
          .select(database.playerAnalyticsSnapshots)
          .get();
      expect(snapshots.map((row) => row.matchId), ['match-2']);
    });
  }

  test('participant match move invalidates old and new identities', () async {
    final database = createTestDatabase();
    await _seedOperationFixture(database, participant: true);

    await (database.update(database.matchParticipants)
          ..where((row) => row.id.equals('participant-1')))
        .write(const MatchParticipantsCompanion(matchId: Value('match-2')));

    expect(
      await database.select(database.playerAnalyticsSnapshots).get(),
      isEmpty,
    );
  });

  test(
    'v2 migration preserves canonical rows without eager snapshots',
    () async {
      final verifier = SchemaVerifier(GeneratedHelper());
      final schema = await verifier.schemaAt(2);
      addTearDown(schema.close);
      final playedAt = DateTime.utc(2026, 8, 28).millisecondsSinceEpoch;
      schema.rawDatabase.execute('''
        INSERT INTO matches(
          id, lifecycle, recording_mode, tracking_coverage, rule_template_json,
          created_at, started_at, ended_at, timer_enabled, note
        ) VALUES(
          'match-v2', 'finished', 'detailed', 'locations', '{}',
          $playedAt, $playedAt, $playedAt, 0, 'preserve-me'
        )
      ''');

      final migrating = AppDatabase(schema.newConnection());
      await verifier.migrateAndValidate(migrating, 3);
      await migrating.close();
      final migrated = v3.DatabaseAtV3(schema.newConnection());
      addTearDown(migrated.close);
      final match = await migrated
          .customSelect("SELECT id, note FROM matches WHERE id = 'match-v2'")
          .getSingle();
      expect(match.read<String>('id'), 'match-v2');
      expect(match.read<String>('note'), 'preserve-me');
      expect(
        await migrated
            .customSelect('SELECT * FROM player_analytics_snapshots')
            .get(),
        isEmpty,
      );
    },
  );

  test(
    'canonical updates invalidate snapshots for both match identities',
    () async {
      final database = createTestDatabase();
      await _seedInvalidationFixture(database);

      await database.customStatement(
        "UPDATE match_events SET match_id = 'match-2' WHERE id = 'event-1'",
      );

      expect(
        await database.select(database.playerAnalyticsSnapshots).get(),
        isEmpty,
      );
    },
  );

  test(
    'snapshot writes are excluded from automatic-backup dirty triggers',
    () async {
      final database = createTestDatabase();
      await _seedInvalidationFixture(database);
      await database.ensureBackupDirtyTriggers();
      await database
          .into(database.appSettings)
          .insert(
            AppSettingsCompanion.insert(
              key: 'backup.automatic.enabled',
              valueJson: 'true',
              updatedAt: DateTime.utc(2026),
            ),
          );
      await database.customStatement(
        "DELETE FROM app_settings WHERE key LIKE 'backup.automatic.dirty%'",
      );

      await database
          .into(database.playerAnalyticsSnapshots)
          .insertOnConflictUpdate(_snapshot('match-1', 'player-1'));

      expect(
        await (database.select(
          database.appSettings,
        )..where((row) => row.key.equals('backup.automatic.dirty'))).get(),
        isEmpty,
      );
    },
  );
}

Future<void> _seedOperationFixture(
  AppDatabase database, {
  bool participant = false,
  bool event = false,
  bool location = false,
}) async {
  await database.batch((batch) {
    batch.insertAll(database.players, [
      PlayerRow(id: 'player-1', nickname: 'P1', createdAt: DateTime.utc(2026)),
      PlayerRow(id: 'player-2', nickname: 'P2', createdAt: DateTime.utc(2026)),
    ]);
    batch.insertAll(database.matches, [_match('match-1'), _match('match-2')]);
    if (participant) {
      batch.insert(
        database.matchParticipants,
        _participant('participant-1', 'match-1'),
      );
    }
    if (event || location) batch.insert(database.matchEvents, _event());
    if (location) batch.insert(database.shotLocations, _location());
    batch.insertAll(database.playerAnalyticsSnapshots, [
      _snapshot('match-1', 'player-1'),
      _snapshot('match-2', 'player-2'),
    ]);
  });
}

MatchParticipant _participant(String id, String matchId) => MatchParticipant(
  id: id,
  matchId: matchId,
  side: 'red',
  nameSnapshot: 'P1',
  playerProfileId: 'player-1',
);

MatchEventRow _event() => MatchEventRow(
  id: 'event-1',
  matchId: 'match-1',
  type: 'fieldGoal',
  side: 'red',
  points: 2,
  outcome: 'made',
  occurredAt: DateTime.utc(2026),
  note: null,
  matchClockPositionSeconds: null,
  customLabel: null,
  isDeleted: false,
);

ShotLocation _location() => const ShotLocation(
  id: 'location-1',
  matchId: 'match-1',
  eventId: 'event-1',
  x: 0.2,
  y: 0.4,
  isConfirmed: true,
);

Future<void> _seedInvalidationFixture(AppDatabase database) async {
  await database.batch((batch) {
    batch.insertAll(database.players, [
      PlayerRow(id: 'player-1', nickname: 'P1', createdAt: DateTime.utc(2026)),
      PlayerRow(id: 'player-2', nickname: 'P2', createdAt: DateTime.utc(2026)),
    ]);
    batch.insertAll(database.matches, [_match('match-1'), _match('match-2')]);
    batch.insert(
      database.matchEvents,
      MatchEventRow(
        id: 'event-1',
        matchId: 'match-1',
        type: 'score',
        side: 'red',
        points: 1,
        outcome: 'made',
        occurredAt: DateTime.utc(2026),
        note: null,
        matchClockPositionSeconds: null,
        customLabel: null,
        isDeleted: false,
      ),
    );
    batch.insertAll(database.playerAnalyticsSnapshots, [
      _snapshot('match-1', 'player-1'),
      _snapshot('match-2', 'player-2'),
    ]);
  });
}

Matche _match(String id) => Matche(
  id: id,
  lifecycle: 'finished',
  recordingMode: 'simple',
  trackingCoverage: 'none',
  ruleTemplateJson: '{}',
  createdAt: DateTime.utc(2026),
  startedAt: null,
  endedAt: null,
  timerEnabled: false,
  note: null,
);

PlayerAnalyticsSnapshotRow _snapshot(String matchId, String playerId) =>
    PlayerAnalyticsSnapshotRow(
      matchId: matchId,
      playerId: playerId,
      opponentPlayerId: null,
      playedAtUtc: DateTime.utc(2026),
      playerScore: 0,
      opponentScore: 0,
      fieldGoalMade: 0,
      fieldGoalAttempts: 0,
      freeThrowMade: 0,
      freeThrowAttempts: 0,
      trackingCoverage: 'none',
      confirmedLocationCount: 0,
      locatableLocationCount: 0,
      zoneDistributionJson: '{}',
      calculatorVersion: 1,
      sourceSha256: '0' * 64,
    );
