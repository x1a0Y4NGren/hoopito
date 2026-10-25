import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/app_database_provider.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';
import 'package:hoopito/core/domain/entities/match.dart' as dom;
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('match rejects contradictory legacy names and participants', () {
    expect(
      () => dom.Match(
        id: 'match-1',
        createdAt: DateTime.utc(2026),
        redName: 'Legacy Red',
        blueName: 'Blue',
        participants: const [
          dom.MatchParticipant(
            id: 'red',
            matchId: 'match-1',
            side: TeamSide.red,
            nameSnapshot: 'Canonical Red',
          ),
          dom.MatchParticipant(
            id: 'blue',
            matchId: 'match-1',
            side: TeamSide.blue,
            nameSnapshot: 'Blue',
          ),
        ],
        ruleTemplateSnapshot: const RuleTemplate(
          id: 'free',
          name: 'Free',
          scoreButtons: [1, 2, 3],
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'participant profile foreign key rejects orphans and sets null on delete',
    () async {
      final database = createTestDatabase();
      await database
          .into(database.matches)
          .insert(
            MatchesCompanion.insert(
              id: 'match-1',
              ruleTemplateJson:
                  '{"id":"free","name":"Free","scoreButtons":[1,2,3],'
                  '"targetScore":null,"timeLimitSeconds":null,"winByTwo":false,'
                  '"foulLimit":null,"possessionHintEnabled":false,'
                  '"customEventTypes":[]}',
              createdAt: DateTime.utc(2026),
            ),
          );
      expect(
        database
            .into(database.matchParticipants)
            .insert(
              MatchParticipantsCompanion.insert(
                id: 'participant-1',
                matchId: 'match-1',
                side: 'red',
                nameSnapshot: 'Red',
                playerProfileId: const Value('missing-player'),
              ),
            ),
        throwsException,
      );
      await database
          .into(database.players)
          .insert(
            PlayersCompanion.insert(
              id: 'player-1',
              nickname: 'Red',
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
              nameSnapshot: 'Red',
              playerProfileId: const Value('player-1'),
            ),
          );
      await (database.delete(
        database.players,
      )..where((player) => player.id.equals('player-1'))).go();
      expect(
        (await database.select(database.matchParticipants).get())
            .single
            .playerProfileId,
        predicate<String?>((value) => value == null),
      );
    },
  );

  test(
    'shot location remains field-goal-only after event updates and across matches',
    () async {
      final database = createTestDatabase();
      await database.batch((batch) {
        batch.insert(
          database.matches,
          MatchesCompanion.insert(
            id: 'match-1',
            ruleTemplateJson:
                '{"id":"free","name":"Free","scoreButtons":[1,2,3],'
                '"targetScore":null,"timeLimitSeconds":null,"winByTwo":false,'
                '"foulLimit":null,"possessionHintEnabled":false,'
                '"customEventTypes":[]}',
            createdAt: DateTime.utc(2026),
          ),
        );
        batch.insert(
          database.matches,
          MatchesCompanion.insert(
            id: 'match-2',
            ruleTemplateJson: '{}',
            createdAt: DateTime.utc(2026),
          ),
        );
        batch.insert(
          database.matchEvents,
          MatchEventsCompanion.insert(
            id: 'event-1',
            matchId: 'match-1',
            type: EventKind.fieldGoal.name,
            side: const Value('red'),
            points: const Value(2),
            outcome: const Value('made'),
            occurredAt: DateTime.utc(2026),
          ),
        );
      });
      await database
          .into(database.shotLocations)
          .insert(
            ShotLocationsCompanion.insert(
              id: 'location-1',
              matchId: 'match-1',
              eventId: 'event-1',
              x: 0.5,
              y: 0.5,
            ),
          );
      expect(
        (database.update(database.matchEvents)
              ..where((event) => event.id.equals('event-1')))
            .write(const MatchEventsCompanion(type: Value('freeThrow'))),
        throwsException,
      );
      expect(
        database
            .into(database.shotLocations)
            .insert(
              ShotLocationsCompanion.insert(
                id: 'location-cross-match',
                matchId: 'match-2',
                eventId: 'event-1',
                x: 0.2,
                y: 0.3,
              ),
            ),
        throwsException,
      );
    },
  );

  test(
    'event persistence rejects unknown vocabulary and illegal free throws',
    () async {
      final database = createTestDatabase();
      await database
          .into(database.matches)
          .insert(
            MatchesCompanion.insert(
              id: 'match-1',
              ruleTemplateJson: '{}',
              createdAt: DateTime.utc(2026),
            ),
          );

      MatchEventsCompanion event({
        required String type,
        String? side,
        int points = 0,
        String? outcome,
      }) => MatchEventsCompanion.insert(
        id: '$type-${side ?? 'none'}-$points',
        matchId: 'match-1',
        type: type,
        side: Value(side),
        points: Value(points),
        outcome: Value(outcome),
        occurredAt: DateTime.utc(2026),
      );

      expect(
        database.into(database.matchEvents).insert(event(type: 'green')),
        throwsException,
      );
      expect(
        database
            .into(database.matchEvents)
            .insert(
              event(type: EventKind.score.name, side: 'green', points: 2),
            ),
        throwsException,
      );
      expect(
        database
            .into(database.matchEvents)
            .insert(
              event(
                type: EventKind.freeThrow.name,
                side: 'red',
                outcome: 'missed',
              ),
            ),
        completes,
      );
      expect(
        database
            .into(database.matchEvents)
            .insert(
              event(
                type: EventKind.freeThrow.name,
                side: 'red',
                outcome: 'made',
              ),
            ),
        throwsException,
      );
      expect(
        database
            .into(database.matchEvents)
            .insert(
              event(
                type: EventKind.fieldGoal.name,
                side: 'red',
                points: 0,
                outcome: 'made',
              ),
            ),
        throwsException,
      );
      expect(
        database
            .into(database.matchEvents)
            .insert(
              event(
                type: EventKind.fieldGoal.name,
                side: 'red',
                points: 2,
                outcome: 'missed',
              ),
            ),
        throwsException,
      );
      expect(
        database
            .into(database.matchEvents)
            .insert(
              event(type: EventKind.fieldGoal.name, side: 'red', points: 2),
            ),
        throwsException,
      );
      expect(
        database
            .into(database.matchEvents)
            .insert(event(type: EventKind.custom.name, outcome: 'unknown')),
        throwsException,
      );
    },
  );

  test(
    'repository round-trips canonical custom label and audits event extensions',
    () async {
      final database = createTestDatabase();
      final repository = MatchRepository(database);
      await repository.createMinimalMatch(
        id: 'match-1',
        redName: 'Red',
        blueName: 'Blue',
        createdAt: DateTime.utc(2026),
      );
      await repository.saveEvent(
        MatchEvent(
          id: 'event-1',
          matchId: 'match-1',
          type: EventKind.custom,
          side: null,
          points: 0,
          outcome: ShotOutcome.notApplicable,
          matchClockPositionSeconds: 21,
          customLabel: '  timeout  ',
          occurredAt: DateTime.utc(2026),
        ),
      );
      final detail = await repository.getMatchDetail('match-1');
      expect(detail!.events.single.customLabel, 'timeout');
      await repository.softDeleteEvent(eventId: 'event-1', reason: 'review');
      final audit = await repository.listAuditLogs('match-1');
      final before = audit.single.diff.before;
      expect(before['outcome'], 'notApplicable');
      expect(before['matchClockPositionSeconds'], 21);
      expect(before['customLabel'], 'timeout');
    },
  );

  test('finish writes lifecycle and history filters use lifecycle', () async {
    final database = createTestDatabase();
    final repository = MatchRepository(database);
    await repository.createMinimalMatch(
      id: 'match-1',
      redName: 'Red',
      blueName: 'Blue',
      createdAt: DateTime.utc(2026),
    );
    await repository.finishMatch('match-1', endedAt: DateTime.utc(2026, 1, 2));
    final row = (await database.select(database.matches).get()).single;
    expect(row.lifecycle, MatchLifecycle.finished.name);
    expect(await repository.listHistory(), hasLength(1));
  });

  test(
    'native bootstrap rejects v1 before Drift opens or changes the file',
    () async {
      final directory = await Directory.systemTemp.createTemp('hoopito-v1-');
      addTearDown(() => directory.delete(recursive: true));
      final file = File(
        '${directory.path}${Platform.pathSeparator}hooptrace.sqlite',
      );
      final raw = sqlite3.open(file.path);
      raw.execute('PRAGMA user_version = 1');
      raw.execute('CREATE TABLE sentinel(value TEXT NOT NULL)');
      raw.execute('INSERT INTO sentinel(value) VALUES (\'untouched\')');
      raw.close();

      expect(
        openNativeAppDatabaseAt(file),
        throwsA(isA<LegacySchemaDetectedException>()),
      );
      final verify = sqlite3.open(file.path);
      expect(verify.select('PRAGMA user_version').single.values.first, 1);
      expect(
        verify.select('SELECT value FROM sentinel').single.values.first,
        'untouched',
      );
      verify.close();
    },
  );

  test(
    'v2 backup round-trips participant, clock, and active-session groups',
    () async {
      final source = createTestDatabase();
      await source
          .into(source.matches)
          .insert(
            MatchesCompanion.insert(
              id: 'match-1',
              lifecycle: const Value('active'),
              ruleTemplateJson:
                  '{"id":"free","name":"Free","scoreButtons":[1,2,3],'
                  '"targetScore":null,"timeLimitSeconds":null,"winByTwo":false,'
                  '"foulLimit":null,"possessionHintEnabled":false,'
                  '"customEventTypes":[]}',
              createdAt: DateTime.utc(2026),
            ),
          );
      await source
          .into(source.matchParticipants)
          .insert(
            MatchParticipantsCompanion.insert(
              id: 'participant-1',
              matchId: 'match-1',
              side: 'red',
              nameSnapshot: 'Red',
            ),
          );
      await source
          .into(source.matchParticipants)
          .insert(
            MatchParticipantsCompanion.insert(
              id: 'participant-2',
              matchId: 'match-1',
              side: 'blue',
              nameSnapshot: 'Blue',
            ),
          );
      await source
          .into(source.matchClocks)
          .insert(
            MatchClocksCompanion.insert(
              id: 'clock-1',
              matchId: 'match-1',
              mode: const Value('countUp'),
              phase: const Value('regulation'),
            ),
          );
      await source
          .into(source.activeSessions)
          .insert(ActiveSessionsCompanion.insert(matchId: 'match-1'));
      final exported = await JsonBackupCodec(
        source,
        appVersion: '1.0.0',
      ).export();
      await source.close();
      final document = jsonDecode(exported) as Map<String, dynamic>;
      final data = document['data'] as Map<String, dynamic>;
      expect(
        data.keys,
        containsAll(['matchParticipants', 'matchClocks', 'activeSessions']),
      );

      final destination = createTestDatabase();
      await JsonBackupCodec(destination, appVersion: '1.0.0').restore(exported);
      expect(
        await destination.select(destination.matchParticipants).get(),
        hasLength(2),
      );
      expect(
        await destination.select(destination.matchClocks).get(),
        hasLength(1),
      );
      expect(
        await destination.select(destination.activeSessions).get(),
        hasLength(1),
      );
    },
  );

  test('committed Drift schema export is v2', () {
    final schema =
        jsonDecode(
              File('drift_schemas/drift_schema_v2.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(schema['_meta'], isA<Map<String, dynamic>>());
    final entities = schema['entities'] as List<dynamic>;
    final tables = entities
        .whereType<Map<String, dynamic>>()
        .where((entity) => entity['type'] == 'table')
        .map((entity) => (entity['data'] as Map<String, dynamic>)['name'])
        .toSet();
    expect(
      tables,
      containsAll(['matches', 'match_participants', 'active_sessions']),
    );
    expect(createTestDatabase().schemaVersion, 3);
  });
}
