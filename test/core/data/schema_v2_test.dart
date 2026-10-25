import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match.dart' as entities;
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/entities/active_session.dart'
    as entity_active;
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';
import '../../generated_migrations/schema.dart';

void main() {
  test('domain contract exposes the 1.0 enum vocabulary', () {
    expect(
      RecordingMode.values,
      containsAll([RecordingMode.simple, RecordingMode.detailed]),
    );
    expect(
      MatchLifecycle.values,
      containsAll([
        MatchLifecycle.active,
        MatchLifecycle.finished,
        MatchLifecycle.archived,
      ]),
    );
    expect(
      ClockMode.values,
      containsAll([ClockMode.countUp, ClockMode.countdown]),
    );
    expect(
      ClockPhase.values,
      containsAll([
        ClockPhase.regulation,
        ClockPhase.regulationExpired,
        ClockPhase.overtime,
      ]),
    );
    expect(
      EventKind.values,
      containsAll([EventKind.fieldGoal, EventKind.freeThrow, EventKind.custom]),
    );
    expect(
      ShotOutcome.values,
      containsAll([ShotOutcome.made, ShotOutcome.missed]),
    );
    expect(
      PossessionPolicy.values,
      containsAll([
        PossessionPolicy.manual,
        PossessionPolicy.switchAfterMade,
        PossessionPolicy.keepAfterMade,
      ]),
    );
    expect(
      RestoreMode.values,
      containsAll([RestoreMode.replace, RestoreMode.merge]),
    );
    expect(
      ThemePreference.values,
      containsAll([
        ThemePreference.system,
        ThemePreference.light,
        ThemePreference.dark,
      ]),
    );
    expect(
      TrackingCoverage.values,
      containsAll([TrackingCoverage.scoresOnly, TrackingCoverage.shotAttempts]),
    );
  });

  test(
    'domain snapshots participant ownership and normalizes custom labels',
    () {
      const participant = entities.MatchParticipant(
        id: 'participant-1',
        matchId: 'match-1',
        side: TeamSide.red,
        nameSnapshot: '  Alice  ',
        playerProfileId: 'player-1',
      );
      expect(participant.side, TeamSide.red);
      expect(participant.nameSnapshot, '  Alice  ');
      expect(participant.playerProfileId, 'player-1');

      final event = MatchEvent(
        id: 'custom-1',
        matchId: 'match-1',
        type: EventKind.custom,
        side: null,
        points: 0,
        occurredAt: DateTime.utc(2026),
        customLabel: '  timeout  ',
      );
      expect(event.customLabel, 'timeout');
    },
  );

  test('clock state and active session are explicit domain records', () {
    final clock = ClockState(
      id: 'clock-1',
      matchId: 'match-1',
      mode: ClockMode.countdown,
      phase: ClockPhase.regulation,
      accumulatedSeconds: 30,
      regulationSeconds: 600,
    );
    expect(clock.remainingSeconds, 570);
    expect(clock.isRunning, isFalse);

    const session = entity_active.ActiveSession(
      id: 'active',
      matchId: 'match-1',
    );
    expect(session.matchId, 'match-1');
  });

  test(
    'fresh schema has v2 tables, foreign keys, indexes and integrity',
    () async {
      final database = createTestDatabase();

      expect(database.schemaVersion, 3);
      final foreignKeys = await database
          .customSelect('PRAGMA foreign_keys')
          .getSingle();
      expect(foreignKeys.read<int>('foreign_keys'), 1);
      expect(
        await database.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );

      final tableNames = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
          .get();
      final names = tableNames.map((row) => row.read<String>('name')).toSet();
      expect(
        names,
        containsAll(<String>[
          'matches',
          'match_participants',
          'match_clocks',
          'active_sessions',
          'match_events',
          'shot_locations',
          'possession_segments',
        ]),
      );

      final indexes = await database
          .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
          .get();
      final indexNames = indexes.map((row) => row.read<String>('name')).toSet();
      expect(indexNames, contains('match_participants_match_side'));
      expect(indexNames, contains('shot_locations_event'));
      expect(indexNames, contains('match_events_match_clock'));
    },
  );

  test(
    'participant and event graph enforces one field-goal location and cascades',
    () async {
      final database = createTestDatabase();
      await database
          .into(database.players)
          .insert(
            PlayersCompanion.insert(
              id: 'player-1',
              nickname: 'A',
              createdAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.matches)
          .insert(
            MatchesCompanion.insert(
              id: 'match-1',
              lifecycle: const Value('active'),
              ruleTemplateJson: '{}',
              createdAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.matchParticipants)
          .insert(
            MatchParticipantsCompanion.insert(
              id: 'participant-1',
              matchId: 'match-1',
              side: 'red',
              nameSnapshot: 'A',
              playerProfileId: const Value('player-1'),
            ),
          );
      await database
          .into(database.matchEvents)
          .insert(
            MatchEventsCompanion.insert(
              id: 'field-goal',
              matchId: 'match-1',
              type: EventKind.fieldGoal.name,
              side: const Value('red'),
              points: const Value(2),
              outcome: const Value('made'),
              matchClockPositionSeconds: const Value(12),
              occurredAt: DateTime.utc(2026),
            ),
          );
      await database
          .into(database.matchEvents)
          .insert(
            MatchEventsCompanion.insert(
              id: 'free-throw',
              matchId: 'match-1',
              type: EventKind.freeThrow.name,
              side: const Value('red'),
              points: const Value(1),
              outcome: const Value('made'),
              occurredAt: DateTime.utc(2026),
            ),
          );
      expect(
        database
            .into(database.shotLocations)
            .insert(
              ShotLocationsCompanion.insert(
                id: 'free-throw-location',
                matchId: 'match-1',
                eventId: 'free-throw',
                x: 0.2,
                y: 0.3,
              ),
            ),
        throwsException,
      );
      await database
          .into(database.shotLocations)
          .insert(
            ShotLocationsCompanion.insert(
              id: 'location-1',
              matchId: 'match-1',
              eventId: 'field-goal',
              x: 0.4,
              y: 0.6,
            ),
          );
      expect(
        database
            .into(database.shotLocations)
            .insert(
              ShotLocationsCompanion.insert(
                id: 'location-2',
                matchId: 'match-1',
                eventId: 'field-goal',
                x: 0.2,
                y: 0.3,
              ),
            ),
        throwsException,
      );

      await database
          .into(database.matchClocks)
          .insert(
            MatchClocksCompanion.insert(
              id: 'clock-1',
              matchId: 'match-1',
              mode: Value(ClockMode.countUp.name),
              phase: Value(ClockPhase.regulation.name),
              accumulatedSeconds: const Value(12),
            ),
          );
      await database
          .into(database.activeSessions)
          .insert(ActiveSessionsCompanion.insert(matchId: 'match-1'));
      expect(
        database
            .into(database.activeSessions)
            .insert(ActiveSessionsCompanion.insert(matchId: 'match-1')),
        throwsException,
      );
      await database
          .into(database.possessionSegments)
          .insert(
            PossessionSegmentsCompanion.insert(
              id: 'possession-1',
              matchId: 'match-1',
              side: 'red',
              startedAtEventId: 'field-goal',
              source: const Value('manual'),
            ),
          );

      await (database.delete(
        database.matches,
      )..where((row) => row.id.equals('match-1'))).go();
      expect(await database.select(database.matchParticipants).get(), isEmpty);
      expect(await database.select(database.matchClocks).get(), isEmpty);
      expect(await database.select(database.activeSessions).get(), isEmpty);
      expect(await database.select(database.matchEvents).get(), isEmpty);
      expect(await database.select(database.shotLocations).get(), isEmpty);
      expect(await database.select(database.possessionSegments).get(), isEmpty);
      expect(await database.select(database.players).get(), hasLength(1));
    },
  );

  test(
    'schema v1 is rejected before a migration can modify the database',
    () async {
      final database = AppDatabase.inMemory();
      addTearDown(database.close);
      await database.customStatement('PRAGMA user_version = 1');

      await expectLater(
        database.assertCompatible(),
        throwsA(isA<LegacySchemaDetectedException>()),
      );
    },
  );

  test('official generated schema verifies the runtime v3 database', () async {
    final verifier = SchemaVerifier(GeneratedHelper());
    final schema = await verifier.startAt(3);
    final database = AppDatabase(schema.executor);
    addTearDown(database.close);

    await verifier.migrateAndValidate(
      database,
      3,
      options: const ValidationOptions(validateDropped: true),
    );
  });
}
