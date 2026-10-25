import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

void main() {
  group('JsonBackupCodec', () {
    test('atomic replace refuses to delete a local active session', () async {
      final exported = await withTestDatabase((source) async {
        return JsonBackupCodec(source, appVersion: '0.1.0+1').export();
      });
      final destination = createTestDatabase();
      await _seedActiveBackup(
        destination,
        runningSinceUtc: DateTime.utc(2026, 7, 18, 9, 1),
      );

      await expectLater(
        JsonBackupCodec(destination, appVersion: '0.1.0+1').restore(exported),
        throwsA(isA<BackupRestoreBlockedException>()),
      );

      expect(
        (await destination.select(destination.activeSessions).get()).single.id,
        'active',
      );
    });
    test('round-trips all twelve persisted table groups', () async {
      final exported = await withTestDatabase((source) async {
        await _seedCompleteBackup(source);
        return JsonBackupCodec(
          source,
          appVersion: '0.1.0+1',
          now: () => DateTime.utc(2026, 7, 18, 9, 30),
        ).export();
      });
      final restored = createTestDatabase();
      final exportedAt = DateTime.utc(2026, 7, 18, 9, 30);
      await JsonBackupCodec(restored, appVersion: '0.1.0+1').restore(exported);

      final document = jsonDecode(exported) as Map<String, dynamic>;
      final manifest = document['manifest'] as Map<String, dynamic>;
      expect(manifest['appName'], 'Hoopito');
      expect(manifest['appVersion'], '0.1.0+1');
      expect(manifest['schemaVersion'], restored.schemaVersion);
      expect(manifest['exportedAt'], exportedAt.toIso8601String());
      expect(manifest['recordCounts'], {
        'matches': 1,
        'matchParticipants': 2,
        'matchClocks': 0,
        'activeSessions': 0,
        'matchEvents': 1,
        'shotLocations': 1,
        'players': 1,
        'ruleTemplates': 1,
        'possessionSegments': 1,
        'auditLogs': 1,
        'appSettings': 1,
        'playerAnalyticsSnapshots': 1,
      });
      expect(manifest['checksum'], matches(RegExp(r'^[a-f0-9]{64}$')));

      expect(
        (await restored.select(restored.matches).get()).single.id,
        'match-1',
      );
      expect(
        (await restored.select(restored.matchEvents).get()).single.id,
        'event-1',
      );
      expect(
        (await restored.select(restored.shotLocations).get()).single.x,
        0.25,
      );
      expect(
        (await restored.select(restored.players).get()).single.nickname,
        'A, "Ace"',
      );
      expect(
        (await restored.select(restored.ruleTemplates).get()).single.name,
        'Race to 11',
      );
      expect(
        (await restored.select(restored.possessionSegments).get())
            .single
            .startedAtEventId,
        'event-1',
      );
      expect(
        (await restored.select(restored.auditLogs).get()).single.targetId,
        'event-1',
      );
      expect(
        (await restored.select(restored.appSettings).get()).single.key,
        'theme',
      );
    });

    test('uses deterministic payload ordering', () async {
      final database = createTestDatabase();
      await _seedCompleteBackup(database);
      final codec = JsonBackupCodec(
        database,
        appVersion: '0.1.0+1',
        now: () => DateTime.utc(2026, 7, 18),
      );

      expect(await codec.export(), await codec.export());
    });

    test(
      'keeps legacy event and audit insertion order when SQLite reverses unordered scans',
      () async {
        final database = createTestDatabase();
        await _seedCompleteBackup(database);
        final createdAt = DateTime.utc(2026, 7, 18, 8);
        await database
            .into(database.matchEvents)
            .insert(
              MatchEventRow(
                id: 'event-2',
                matchId: 'match-1',
                type: 'foul',
                side: 'blue',
                points: 0,
                occurredAt: createdAt.add(const Duration(seconds: 30)),
                note: null,
                outcome: null,
                matchClockPositionSeconds: null,
                customLabel: null,
                isDeleted: false,
              ),
            );
        await database
            .into(database.auditLogs)
            .insert(
              AuditLog(
                id: 'audit-2',
                matchId: 'match-1',
                targetId: 'event-2',
                action: 'create',
                beforeJson: '{}',
                afterJson: '{}',
                reason: null,
                createdAt: createdAt.add(const Duration(minutes: 2)),
              ),
            );
        await database.customStatement('PRAGMA reverse_unordered_selects = ON');

        final document =
            jsonDecode(
                  await JsonBackupCodec(
                    database,
                    appVersion: '1.0.0',
                    now: () => DateTime.utc(2026, 7, 18),
                  ).export(),
                )
                as Map<String, dynamic>;
        final data = document['data'] as Map<String, dynamic>;
        expect(
          (data['matchEvents'] as List<dynamic>).map(
            (row) => (row as Map<String, dynamic>)['id'],
          ),
          ['event-1', 'event-2'],
        );
        expect(
          (data['auditLogs'] as List<dynamic>).map(
            (row) => (row as Map<String, dynamic>)['id'],
          ),
          ['audit-1', 'audit-2'],
        );
      },
    );

    test('round-trips legacy event and audit insertion order', () async {
      final exported = await withTestDatabase((source) async {
        await _seedCompleteBackup(source);
        final createdAt = DateTime.utc(2026, 7, 18, 8);
        await source
            .into(source.matchEvents)
            .insert(
              MatchEventRow(
                id: 'event-2',
                matchId: 'match-1',
                type: 'foul',
                side: 'blue',
                points: 0,
                occurredAt: createdAt.add(const Duration(seconds: 30)),
                note: null,
                outcome: null,
                matchClockPositionSeconds: null,
                customLabel: null,
                isDeleted: false,
              ),
            );
        await source
            .into(source.auditLogs)
            .insert(
              AuditLog(
                id: 'audit-2',
                matchId: 'match-1',
                targetId: 'event-2',
                action: 'create',
                beforeJson: '{}',
                afterJson: '{}',
                reason: null,
                createdAt: createdAt.add(const Duration(minutes: 2)),
              ),
            );
        await source.customStatement('PRAGMA reverse_unordered_selects = ON');
        return JsonBackupCodec(
          source,
          appVersion: '1.0.0',
          now: () => DateTime.utc(2026, 7, 18),
        ).export();
      });

      final restored = createTestDatabase();
      await JsonBackupCodec(restored, appVersion: '1.0.0').restore(exported);
      final eventsQuery = restored.select(restored.matchEvents)
        ..orderBy([
          (_) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
        ]);
      final auditsQuery = restored.select(restored.auditLogs)
        ..orderBy([
          (_) => OrderingTerm(expression: const CustomExpression<int>('rowid')),
        ]);
      expect((await eventsQuery.get()).map((row) => row.id), [
        'event-1',
        'event-2',
      ]);
      expect((await auditsQuery.get()).map((row) => row.id), [
        'audit-1',
        'audit-2',
      ]);
    });

    test('restores a running backed-up clock in a paused state', () async {
      final exportedAt = DateTime.utc(2026, 7, 18, 9, 30);
      final exported = await withTestDatabase((source) async {
        await _seedActiveBackup(
          source,
          runningSinceUtc: exportedAt.subtract(const Duration(seconds: 30)),
        );
        return JsonBackupCodec(
          source,
          appVersion: '0.1.0+1',
          now: () => exportedAt,
        ).export();
      });
      final destination = createTestDatabase();

      await JsonBackupCodec(
        destination,
        appVersion: '0.1.0+1',
      ).restore(exported);

      final clock =
          (await destination.select(destination.matchClocks).get()).single;
      expect(clock.runningSinceUtc, isNull);
      expect(clock.accumulatedSeconds, 70);
      expect(
        (await destination.select(destination.activeSessions).get())
            .single
            .matchId,
        'active-match',
      );
    });

    test('rejects a future schema with a typed exception', () async {
      final database = createTestDatabase();
      final codec = JsonBackupCodec(
        database,
        appVersion: '0.1.0+1',
        now: () => DateTime.utc(2026, 7, 18),
      );
      final document = jsonDecode(await codec.export()) as Map<String, dynamic>;
      final manifest = document['manifest'] as Map<String, dynamic>;
      manifest['schemaVersion'] = database.schemaVersion + 1;

      expect(
        () => codec.restore(jsonEncode(document)),
        throwsA(
          isA<UnsupportedBackupSchemaException>().having(
            (error) => error.schemaVersion,
            'schemaVersion',
            database.schemaVersion + 1,
          ),
        ),
      );
    });

    test(
      'rejects a modified payload with a typed checksum exception',
      () async {
        final database = createTestDatabase();
        await _seedCompleteBackup(database);
        final codec = JsonBackupCodec(database, appVersion: '0.1.0+1');
        final document =
            jsonDecode(await codec.export()) as Map<String, dynamic>;
        final data = document['data'] as Map<String, dynamic>;
        final events = data['matchEvents'] as List<dynamic>;
        (events.single as Map<String, dynamic>)['points'] = 3;

        expect(
          () => codec.restore(jsonEncode(document)),
          throwsA(isA<BackupChecksumException>()),
        );
      },
    );

    test('fully validates before replacing existing local data', () async {
      final exported = await withTestDatabase((source) async {
        await _seedCompleteBackup(source);
        return JsonBackupCodec(source, appVersion: '0.1.0+1').export();
      });
      final destination = createTestDatabase();
      await destination
          .into(destination.matches)
          .insert(
            Matche(
              id: 'keep-me',
              lifecycle: 'active',
              recordingMode: 'simple',
              trackingCoverage: 'scoresOnly',
              ruleTemplateJson: '{}',
              createdAt: DateTime.utc(2026, 7, 17),
              startedAt: null,
              endedAt: null,
              timerEnabled: false,
              note: null,
            ),
          );
      final document = jsonDecode(exported) as Map<String, dynamic>;
      final data = document['data'] as Map<String, dynamic>;
      final events = data['matchEvents'] as List<dynamic>;
      (events.single as Map<String, dynamic>)['matchId'] = 'missing-match';
      _refreshChecksum(document);

      await expectLater(
        JsonBackupCodec(
          destination,
          appVersion: '0.1.0+1',
        ).restore(jsonEncode(document)),
        throwsA(isA<BackupValidationException>()),
      );
      final matches = await destination.select(destination.matches).get();
      expect(matches.map((match) => match.id), ['keep-me']);
      expect(await destination.select(destination.matchEvents).get(), isEmpty);
    });

    test(
      'rejects invalid domain values before replacing existing data',
      () async {
        final exported = await withTestDatabase((source) async {
          await _seedCompleteBackup(source);
          return JsonBackupCodec(source, appVersion: '0.1.0+1').export();
        });
        final destination = createTestDatabase();
        await destination
            .into(destination.players)
            .insert(
              PlayerRow(
                id: 'keep-player',
                nickname: '本机球员',
                createdAt: DateTime.utc(2026, 7, 17),
                preferredSide: null,
                note: null,
              ),
            );
        final document = jsonDecode(exported) as Map<String, dynamic>;
        final data = document['data'] as Map<String, dynamic>;
        final events = data['matchEvents'] as List<dynamic>;
        (events.single as Map<String, dynamic>)['side'] = 'green';
        final locations = data['shotLocations'] as List<dynamic>;
        (locations.single as Map<String, dynamic>)['x'] = 1.5;
        _refreshChecksum(document);

        await expectLater(
          JsonBackupCodec(
            destination,
            appVersion: '0.1.0+1',
          ).restore(jsonEncode(document)),
          throwsA(isA<BackupValidationException>()),
        );
        expect(
          (await destination.select(destination.players).get()).single.id,
          'keep-player',
        );
        expect(await destination.select(destination.matches).get(), isEmpty);
      },
    );

    test(
      'rejects a backup with a missing participant before replacement',
      () async {
        await _expectGraphRejected((document) {
          final data = document['data'] as Map<String, dynamic>;
          (data['matchParticipants'] as List<dynamic>).removeLast();
          _setRecordCount(document, 'matchParticipants', 1);
        });
      },
    );

    test(
      'rejects an active session for a non-active match before replacement',
      () async {
        await _expectGraphRejected((document) {
          final data = document['data'] as Map<String, dynamic>;
          (data['activeSessions'] as List<dynamic>).add({
            'id': 'active',
            'matchId': 'match-1',
            'claimedAtUtc': '2026-07-18T08:00:00.000Z',
          });
          _setRecordCount(document, 'activeSessions', 1);
        });
      },
    );

    test(
      'rejects a match that assigns one player profile to both sides',
      () async {
        await _expectGraphRejected((document) {
          final participants =
              (document['data'] as Map<String, dynamic>)['matchParticipants']
                  as List<dynamic>;
          final blue = participants.cast<Map<String, dynamic>>().singleWhere(
            (participant) => participant['side'] == 'blue',
          );
          blue['playerProfileId'] = 'player-1';
        });
      },
    );

    test(
      'requires active matches and sessions to correspond one-to-one',
      () async {
        final exported = await withTestDatabase((source) async {
          await _seedActiveBackup(
            source,
            runningSinceUtc: DateTime.utc(2026, 7, 18, 9, 1),
          );
          return JsonBackupCodec(source, appVersion: '0.1.0+1').export();
        });
        final database = createTestDatabase();
        final codec = JsonBackupCodec(database, appVersion: '0.1.0+1');

        final missingSession = jsonDecode(exported) as Map<String, dynamic>;
        final missingSessionData =
            missingSession['data'] as Map<String, dynamic>;
        (missingSessionData['activeSessions'] as List<dynamic>).clear();
        _setRecordCount(missingSession, 'activeSessions', 0);
        _refreshChecksum(missingSession);
        expect(
          () => codec.decodeAndValidate(jsonEncode(missingSession)),
          throwsA(isA<BackupValidationException>()),
        );

        final duplicateActive = jsonDecode(exported) as Map<String, dynamic>;
        final duplicateData = duplicateActive['data'] as Map<String, dynamic>;
        final duplicateMatch = Map<String, dynamic>.from(
          (duplicateData['matches'] as List<dynamic>).single
              as Map<String, dynamic>,
        )..['id'] = 'active-match-2';
        (duplicateData['matches'] as List<dynamic>).add(duplicateMatch);
        _setRecordCount(duplicateActive, 'matches', 2);
        _refreshChecksum(duplicateActive);
        expect(
          () => codec.decodeAndValidate(jsonEncode(duplicateActive)),
          throwsA(isA<BackupValidationException>()),
        );
      },
    );

    test('requires a clock for active or timer-enabled matches', () async {
      final exported = await withTestDatabase((source) async {
        await _seedActiveBackup(
          source,
          runningSinceUtc: DateTime.utc(2026, 7, 18, 9, 1),
        );
        return JsonBackupCodec(source, appVersion: '1.0.0').export();
      });
      final database = createTestDatabase();
      final codec = JsonBackupCodec(database, appVersion: '1.0.0');

      final activeWithoutClock = jsonDecode(exported) as Map<String, dynamic>;
      final activeData = activeWithoutClock['data'] as Map<String, dynamic>;
      (activeData['matchClocks'] as List<dynamic>).clear();
      _setRecordCount(activeWithoutClock, 'matchClocks', 0);
      _refreshChecksum(activeWithoutClock);
      expect(
        () => codec.decodeAndValidate(jsonEncode(activeWithoutClock)),
        throwsA(isA<BackupValidationException>()),
      );

      final historical = await withTestDatabase((source) async {
        await _seedCompleteBackup(source);
        return JsonBackupCodec(source, appVersion: '1.0.0').export();
      });
      final timerEnabledWithoutClock =
          jsonDecode(historical) as Map<String, dynamic>;
      final timerData =
          timerEnabledWithoutClock['data'] as Map<String, dynamic>;
      final match =
          (timerData['matches'] as List<dynamic>).single
              as Map<String, dynamic>;
      match['timerEnabled'] = true;
      _refreshChecksum(timerEnabledWithoutClock);
      expect(
        () => codec.decodeAndValidate(jsonEncode(timerEnabledWithoutClock)),
        throwsA(isA<BackupValidationException>()),
      );

      // A completed, timer-disabled record from older versions may have no
      // clock and remains valid.
      final completedWithoutClock =
          jsonDecode(historical) as Map<String, dynamic>;
      expect(
        () => codec.decodeAndValidate(jsonEncode(completedWithoutClock)),
        returnsNormally,
      );
    });

    test(
      'rejects running clocks on non-active matches and expired regulation',
      () async {
        final exported = await withTestDatabase((source) async {
          await _seedActiveBackup(
            source,
            runningSinceUtc: DateTime.utc(2026, 7, 18, 9, 1),
          );
          return JsonBackupCodec(source, appVersion: '1.0.0').export();
        });
        final database = createTestDatabase();
        final codec = JsonBackupCodec(database, appVersion: '1.0.0');

        final nonActive = jsonDecode(exported) as Map<String, dynamic>;
        final nonActiveData = nonActive['data'] as Map<String, dynamic>;
        ((nonActiveData['matches'] as List<dynamic>).single
                as Map<String, dynamic>)['lifecycle'] =
            'finished';
        (nonActiveData['activeSessions'] as List<dynamic>).clear();
        _setRecordCount(nonActive, 'activeSessions', 0);
        _refreshChecksum(nonActive);
        expect(
          () => codec.decodeAndValidate(jsonEncode(nonActive)),
          throwsA(isA<BackupValidationException>()),
        );

        final expired = jsonDecode(exported) as Map<String, dynamic>;
        final expiredData = expired['data'] as Map<String, dynamic>;
        ((expiredData['matchClocks'] as List<dynamic>).single
                as Map<String, dynamic>)['phase'] =
            'regulationExpired';
        _refreshChecksum(expired);
        expect(
          () => codec.decodeAndValidate(jsonEncode(expired)),
          throwsA(isA<BackupValidationException>()),
        );
      },
    );

    test('rejects an orphan clock before replacement', () async {
      await _expectGraphRejected((document) {
        final data = document['data'] as Map<String, dynamic>;
        (data['matchClocks'] as List<dynamic>).add({
          'id': 'clock-orphan',
          'matchId': 'missing-match',
          'mode': 'countUp',
          'phase': 'regulation',
          'accumulatedSeconds': 0,
          'runningSinceUtc': null,
          'regulationSeconds': null,
        });
        _setRecordCount(document, 'matchClocks', 1);
      });
    });

    test(
      'rejects a possession whose match disagrees with its events',
      () async {
        await _expectGraphRejected((document) {
          final data = document['data'] as Map<String, dynamic>;
          final possession =
              (data['possessionSegments'] as List<dynamic>).single
                  as Map<String, dynamic>;
          possession['matchId'] = 'missing-match';
        });
      },
    );

    test('prevalidates every persisted shot event invariant', () async {
      final invalidEvents = <Map<String, Object?>>[
        {'type': 'fieldGoal', 'side': 'red', 'points': 2, 'outcome': 'missed'},
        {'type': 'freeThrow', 'side': 'red', 'points': 0, 'outcome': 'made'},
        {'type': 'miss', 'side': null, 'points': 1, 'outcome': 'missed'},
      ];
      for (final invalid in invalidEvents) {
        await _expectGraphRejected((document) {
          final data = document['data'] as Map<String, dynamic>;
          final event =
              (data['matchEvents'] as List<dynamic>).single
                  as Map<String, dynamic>;
          event.addAll(invalid);
          (data['shotLocations'] as List<dynamic>).clear();
          _setRecordCount(document, 'shotLocations', 0);
        });
      }
    });

    test('rejects a score event with a non-made outcome', () async {
      await _expectGraphRejected((document) {
        final data = document['data'] as Map<String, dynamic>;
        final event =
            (data['matchEvents'] as List<dynamic>).single
                as Map<String, dynamic>;
        event['type'] = 'score';
        event['side'] = 'red';
        event['points'] = 2;
        event['outcome'] = 'missed';
        (data['shotLocations'] as List<dynamic>).clear();
        _setRecordCount(document, 'shotLocations', 0);
      });
    });

    test(
      'rejects duplicate shot locations for one event before writes',
      () async {
        await _expectGraphRejected((document) {
          final data = document['data'] as Map<String, dynamic>;
          final locations = data['shotLocations'] as List<dynamic>;
          final duplicate = Map<String, dynamic>.from(
            locations.single as Map<String, dynamic>,
          )..['id'] = 'shot-duplicate';
          locations.add(duplicate);
          _setRecordCount(document, 'shotLocations', 2);
        });
      },
    );

    test('rolls back replacement when a database write fails', () async {
      final exported = await withTestDatabase((source) async {
        await _seedCompleteBackup(source);
        return JsonBackupCodec(source, appVersion: '0.1.0+1').export();
      });
      final destination = createTestDatabase();
      await destination
          .into(destination.matches)
          .insert(
            Matche(
              id: 'keep-me',
              lifecycle: 'active',
              recordingMode: 'simple',
              trackingCoverage: 'scoresOnly',
              ruleTemplateJson: '{}',
              createdAt: DateTime.utc(2026, 7, 17),
              startedAt: null,
              endedAt: null,
              timerEnabled: false,
              note: null,
            ),
          );
      await destination.customStatement('''
        CREATE TRIGGER reject_restored_match
        BEFORE INSERT ON matches
        WHEN NEW.id = 'match-1'
        BEGIN
          SELECT RAISE(ABORT, 'forced restore failure');
        END;
      ''');
      await expectLater(
        JsonBackupCodec(destination, appVersion: '0.1.0+1').restore(exported),
        throwsA(isA<BackupRestoreException>()),
      );
      final matches = await destination.select(destination.matches).get();
      expect(matches.map((match) => match.id), ['keep-me']);
    });
  });
}

Future<void> _expectGraphRejected(
  void Function(Map<String, dynamic> document) mutate,
) async {
  final exported = await withTestDatabase((source) async {
    await _seedCompleteBackup(source);
    return JsonBackupCodec(source, appVersion: '0.1.0+1').export();
  });
  final document = jsonDecode(exported) as Map<String, dynamic>;
  mutate(document);
  _refreshChecksum(document);

  final destination = createTestDatabase();
  try {
    await destination
        .into(destination.matches)
        .insert(
          Matche(
            id: 'keep-me',
            lifecycle: 'active',
            recordingMode: 'simple',
            trackingCoverage: 'scoresOnly',
            ruleTemplateJson: '{}',
            createdAt: DateTime.utc(2026, 7, 17),
            startedAt: null,
            endedAt: null,
            timerEnabled: false,
            note: null,
          ),
        );

    await expectLater(
      JsonBackupCodec(
        destination,
        appVersion: '0.1.0+1',
      ).restore(jsonEncode(document)),
      throwsA(isA<BackupValidationException>()),
    );
    expect(
      (await destination.select(destination.matches).get()).single.id,
      'keep-me',
    );
    expect(await destination.select(destination.matchEvents).get(), isEmpty);
  } finally {
    await destination.close();
  }
}

void _setRecordCount(Map<String, dynamic> document, String table, int count) {
  final manifest = document['manifest'] as Map<String, dynamic>;
  final counts = manifest['recordCounts'] as Map<String, dynamic>;
  counts[table] = count;
}

void _refreshChecksum(Map<String, dynamic> document) {
  final manifest = document['manifest'] as Map<String, dynamic>;
  final checksumSource = Map<String, dynamic>.from(manifest)
    ..remove('checksum');
  final encoded = jsonEncode({
    'manifest': checksumSource,
    'data': document['data'],
  });
  manifest['checksum'] = sha256.convert(utf8.encode(encoded)).toString();
}

Future<void> _seedCompleteBackup(AppDatabase database) async {
  final createdAt = DateTime.utc(2026, 7, 18, 8);
  await database
      .into(database.matches)
      .insert(
        Matche(
          id: 'match-1',
          lifecycle: 'finished',
          recordingMode: 'simple',
          trackingCoverage: 'scoresOnly',
          ruleTemplateJson: jsonEncode({
            'id': 'rule-1',
            'name': 'Race to 11',
            'scoreButtons': [1, 2, 3],
            'targetScore': 11,
            'timeLimitSeconds': null,
            'winByTwo': true,
            'foulLimit': null,
            'possessionHintEnabled': false,
            'customEventTypes': <String>[],
          }),
          createdAt: createdAt,
          startedAt: createdAt,
          endedAt: createdAt.add(const Duration(minutes: 8)),
          timerEnabled: false,
          note: 'final',
        ),
      );
  await database
      .into(database.matchEvents)
      .insert(
        MatchEventRow(
          id: 'event-1',
          matchId: 'match-1',
          type: 'score',
          side: 'red',
          points: 2,
          occurredAt: createdAt.add(const Duration(seconds: 15)),
          note: 'corner',
          outcome: 'made',
          matchClockPositionSeconds: null,
          customLabel: null,
          isDeleted: false,
        ),
      );
  await database
      .into(database.shotLocations)
      .insert(
        const ShotLocation(
          id: 'shot-1',
          matchId: 'match-1',
          eventId: 'event-1',
          x: 0.25,
          y: 0.75,
          isConfirmed: true,
        ),
      );
  await database
      .into(database.players)
      .insert(
        PlayerRow(
          id: 'player-1',
          nickname: 'A, "Ace"',
          createdAt: createdAt,
          preferredSide: 'red',
          note: null,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.matchParticipants, [
      const MatchParticipant(
        id: 'participant-red',
        matchId: 'match-1',
        side: 'red',
        nameSnapshot: 'Red',
        playerProfileId: 'player-1',
      ),
      const MatchParticipant(
        id: 'participant-blue',
        matchId: 'match-1',
        side: 'blue',
        nameSnapshot: 'Blue',
      ),
    ]);
  });
  await database
      .into(database.ruleTemplates)
      .insert(
        const RuleTemplateRow(
          id: 'rule-1',
          name: 'Race to 11',
          scoreButtonsJson: '[1,2,3]',
          targetScore: 11,
          timeLimitSeconds: null,
          winByTwo: true,
          foulLimit: null,
          customEventTypesJson:
              '{"eventTypes":[],"possessionHintEnabled":false}',
          isBuiltIn: false,
        ),
      );
  await database
      .into(database.possessionSegments)
      .insert(
        const PossessionSegment(
          id: 'possession-1',
          matchId: 'match-1',
          side: 'red',
          startedAtEventId: 'event-1',
          endedAtEventId: 'event-1',
          reason: 'score',
          source: 'manual',
        ),
      );
  await database
      .into(database.auditLogs)
      .insert(
        AuditLog(
          id: 'audit-1',
          matchId: 'match-1',
          targetId: 'event-1',
          action: 'edit',
          beforeJson: '{}',
          afterJson: '{"note":"corner"}',
          reason: 'correction',
          createdAt: createdAt.add(const Duration(minutes: 1)),
        ),
      );
  await database
      .into(database.appSettings)
      .insert(
        AppSetting(key: 'theme', valueJson: '"light"', updatedAt: createdAt),
      );
}

Future<void> _seedActiveBackup(
  AppDatabase database, {
  required DateTime runningSinceUtc,
}) async {
  final createdAt = DateTime.utc(2026, 7, 18, 9);
  await database
      .into(database.matches)
      .insert(
        Matche(
          id: 'active-match',
          lifecycle: 'active',
          recordingMode: 'simple',
          trackingCoverage: 'scoresOnly',
          ruleTemplateJson: jsonEncode({
            'id': 'rule-1',
            'name': 'Race to 11',
            'scoreButtons': [1, 2, 3],
            'targetScore': 11,
            'timeLimitSeconds': null,
            'winByTwo': true,
            'foulLimit': null,
            'possessionHintEnabled': false,
            'customEventTypes': <String>[],
          }),
          createdAt: createdAt,
          startedAt: createdAt,
          endedAt: null,
          timerEnabled: true,
          note: null,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.matchParticipants, const [
      MatchParticipant(
        id: 'active-red',
        matchId: 'active-match',
        side: 'red',
        nameSnapshot: 'Red',
      ),
      MatchParticipant(
        id: 'active-blue',
        matchId: 'active-match',
        side: 'blue',
        nameSnapshot: 'Blue',
      ),
    ]);
    batch.insert(
      database.matchClocks,
      MatchClock(
        id: 'active-clock',
        matchId: 'active-match',
        mode: 'countUp',
        phase: 'regulation',
        accumulatedSeconds: 40,
        runningSinceUtc: runningSinceUtc,
        regulationSeconds: null,
      ),
    );
    batch.insert(
      database.activeSessions,
      ActiveSession(
        id: 'active',
        matchId: 'active-match',
        claimedAtUtc: createdAt,
      ),
    );
  });
}
