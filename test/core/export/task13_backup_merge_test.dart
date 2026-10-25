import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

void main() {
  group('BackupMergeService', () {
    test(
      'identical rows are skipped and local settings are preserved',
      () async {
        final source = await _exportLibrary();
        final destination = createTestDatabase();
        await _seedLibrary(destination);
        await (destination.update(
          destination.appSettings,
        )..where((row) => row.key.equals('theme'))).write(
          AppSettingsCompanion(
            valueJson: Value(jsonEncode('dark')),
            updatedAt: Value(DateTime.utc(2026, 8, 24, 12)),
          ),
        );

        final result = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);

        expect(result.changed, isFalse);
        expect(result.insertedRowCount, 0);
        expect(result.skippedIds['matches'], contains('match-1'));
        expect(
          () => result.idMap['matches']!['other'] = 'mutated',
          throwsUnsupportedError,
        );
        expect(
          () => result.skippedIds['matches']!.add('mutated'),
          throwsUnsupportedError,
        );
        expect(
          (await destination.select(destination.appSettings).get())
              .single
              .valueJson,
          jsonEncode('dark'),
        );
        expect(
          await destination.select(destination.matches).get(),
          hasLength(1),
        );
      },
    );

    test(
      'conflicting graph IDs are deterministically remapped through every FK',
      () async {
        final source = await _exportLibrary(playerNote: 'source-player');
        final destination = createTestDatabase();
        await _seedLibrary(destination, playerNote: 'local-player');
        await destination
            .update(destination.matches)
            .write(const MatchesCompanion(note: Value('local-match')));
        await destination
            .update(destination.ruleTemplates)
            .write(const RuleTemplatesCompanion(name: Value('Local rule')));

        final result = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);

        final matchId = result.idMap['matches']!['match-1']!;
        final eventId = result.idMap['matchEvents']!['event-1']!;
        final participantId =
            result.idMap['matchParticipants']!['participant-red']!;
        final playerId = result.idMap['players']!['player-1']!;
        final locationId = result.idMap['shotLocations']!['location-1']!;
        final possessionId =
            result.idMap['possessionSegments']!['possession-1']!;
        final auditId = result.idMap['auditLogs']!['audit-1']!;

        expect(matchId, isNot('match-1'));
        expect(eventId, isNot('event-1'));
        expect(participantId, isNot('participant-red'));
        expect(playerId, isNot('player-1'));
        expect(locationId, isNot('location-1'));
        expect(possessionId, isNot('possession-1'));
        expect(auditId, isNot('audit-1'));

        final importedParticipant =
            (await destination.select(destination.matchParticipants).get())
                .singleWhere((row) => row.id == participantId);
        final importedClock =
            (await destination.select(destination.matchClocks).get())
                .singleWhere((row) => row.matchId == matchId);
        final importedEvent =
            (await destination.select(destination.matchEvents).get())
                .singleWhere((row) => row.id == eventId);
        final importedLocation =
            (await destination.select(destination.shotLocations).get())
                .singleWhere((row) => row.id == locationId);
        final importedPossession =
            (await destination.select(destination.possessionSegments).get())
                .singleWhere((row) => row.id == possessionId);
        final importedAudit =
            (await destination.select(destination.auditLogs).get()).singleWhere(
              (row) => row.id == auditId,
            );

        expect(importedParticipant.matchId, matchId);
        expect(importedParticipant.playerProfileId, playerId);
        expect(importedClock.matchId, matchId);
        expect(importedEvent.matchId, matchId);
        expect(importedLocation.matchId, matchId);
        expect(importedLocation.eventId, eventId);
        expect(importedPossession.matchId, matchId);
        expect(importedPossession.startedAtEventId, eventId);
        expect(importedPossession.endedAtEventId, eventId);
        expect(importedAudit.matchId, matchId);
        expect(importedAudit.targetId, eventId);
      },
    );

    test(
      'remaps a match when a conflicting clock would violate one clock per match',
      () async {
        final source = await _exportLibrary(clockAccumulatedSeconds: 30);
        final destination = createTestDatabase();
        await _seedLibrary(destination);

        final service = BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        );
        final first = await service.merge(source);
        final importedMatchId = first.idMap['matches']!['match-1']!;

        expect(importedMatchId, isNot('match-1'));
        final clocks = await destination.select(destination.matchClocks).get();
        expect(clocks, hasLength(2));
        expect(
          clocks.singleWhere((clock) => clock.matchId == importedMatchId),
          isA<MatchClock>().having(
            (clock) => clock.accumulatedSeconds,
            'accumulated seconds',
            30,
          ),
        );

        final countsAfterFirst = await _counts(destination);
        final second = await service.merge(source);
        expect(second.changed, isFalse);
        expect(second.idMap, first.idMap);
        expect(await _counts(destination), countsAfterFirst);
      },
    );

    test(
      'remaps a conflicting event when a location would violate one location per event',
      () async {
        final source = await _exportLibrary(locationX: 0.9);
        final destination = createTestDatabase();
        await _seedLibrary(destination, locationX: 0.25);

        final result = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);
        final importedEventId = result.idMap['matchEvents']!['event-1']!;
        final importedLocationId =
            result.idMap['shotLocations']!['location-1']!;

        expect(importedEventId, isNot('event-1'));
        expect(importedLocationId, isNot('location-1'));
        final importedLocation =
            (await destination.select(destination.shotLocations).get())
                .singleWhere((location) => location.id == importedLocationId);
        expect(importedLocation.eventId, importedEventId);
        expect(importedLocation.x, 0.9);
        expect(
          (await destination.select(destination.shotLocations).get()).where(
            (location) => location.eventId == 'event-1',
          ),
          hasLength(1),
        );
      },
    );

    test(
      'recursively remaps structured audit references without changing ordinary text',
      () async {
        final source = await _exportLibrary(
          playerNote: 'source-player',
          auditBeforeJson: jsonEncode({
            'matchId': 'match-1',
            'eventId': 'event-1',
            'scoringEventId': 'event-1',
            'locationId': 'location-1',
            'participantId': 'participant-red',
            'clockId': 'clock-1',
            'possessionId': 'possession-1',
            'playerProfileId': 'player-1',
            'ordinaryText': 'event-1 is mentioned as prose',
            'nested': [
              {'eventId': 'event-1'},
              {'description': 'participant-red'},
            ],
            'eventRecord': {
              'id': 'event-1',
              'matchId': 'match-1',
              'type': 'score',
              'occurredAt': '2026-08-24T09:00:15.000Z',
            },
            'locationRecord': {
              'id': 'location-1',
              'eventId': 'event-1',
              'x': 0.25,
              'y': 0.75,
            },
          }),
          auditAfterJson: jsonEncode({
            'matchId': 'match-1',
            'eventId': 'event-1',
            'scoringEventId': 'event-1',
            'locationId': 'location-1',
            'participantId': 'participant-red',
            'clockId': 'clock-1',
            'possessionId': 'possession-1',
            'playerProfileId': 'player-1',
          }),
        );
        final destination = createTestDatabase();
        await _seedLibrary(destination, playerNote: 'local-player');
        await destination
            .update(destination.matches)
            .write(const MatchesCompanion(note: Value('local-match')));
        await destination
            .update(destination.ruleTemplates)
            .write(const RuleTemplatesCompanion(name: Value('Local rule')));

        final result = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);
        final auditId = result.idMap['auditLogs']!['audit-1']!;
        final audit = (await destination.select(destination.auditLogs).get())
            .singleWhere((row) => row.id == auditId);
        final before = jsonDecode(audit.beforeJson) as Map<String, dynamic>;
        final after = jsonDecode(audit.afterJson) as Map<String, dynamic>;

        expect(before['matchId'], result.idMap['matches']!['match-1']);
        expect(before['eventId'], result.idMap['matchEvents']!['event-1']);
        expect(
          before['locationId'],
          result.idMap['shotLocations']!['location-1'],
        );
        expect(
          before['participantId'],
          result.idMap['matchParticipants']!['participant-red'],
        );
        expect(before['clockId'], result.idMap['matchClocks']!['clock-1']);
        expect(
          before['possessionId'],
          result.idMap['possessionSegments']!['possession-1'],
        );
        expect(before['playerProfileId'], result.idMap['players']!['player-1']);
        expect(before['ordinaryText'], 'event-1 is mentioned as prose');
        expect(
          (before['nested'] as List<dynamic>).first['eventId'],
          result.idMap['matchEvents']!['event-1'],
        );
        expect(
          (before['nested'] as List<dynamic>)[1]['description'],
          'participant-red',
        );
        expect(
          (before['eventRecord'] as Map<String, dynamic>)['id'],
          result.idMap['matchEvents']!['event-1'],
        );
        expect(
          (before['locationRecord'] as Map<String, dynamic>)['id'],
          result.idMap['shotLocations']!['location-1'],
        );
        expect(after['matchId'], result.idMap['matches']!['match-1']);
        expect(
          after['scoringEventId'],
          result.idMap['matchEvents']!['event-1'],
        );

        final countsAfterFirst = await _counts(destination);
        final second = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);
        expect(second.changed, isFalse);
        expect(second.idMap, result.idMap);
        expect(await _counts(destination), countsAfterFirst);
      },
    );

    test(
      'remapped scoringEventId remains usable by scoring undo after resuming an import',
      () async {
        final source = await _exportLibrary(
          matchId: 'merge-undo',
          lifecycle: 'active',
          activeSession: true,
          auditAfterJson: jsonEncode({'scoringEventId': 'event-1'}),
        );
        final destination = createTestDatabase();
        await _seedLibrary(destination);

        final result = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);
        final importedEventId = result.idMap['matchEvents']!['event-1']!;
        expect(importedEventId, isNot('event-1'));
        final importedMatchId = result.idMap['matches']!['merge-undo']!;
        final auditId = result.idMap['auditLogs']!['audit-1']!;
        final importedAudit =
            (await destination.select(destination.auditLogs).get()).singleWhere(
              (row) => row.id == auditId,
            );
        expect(
          (jsonDecode(importedAudit.afterJson)
              as Map<String, dynamic>)['scoringEventId'],
          importedEventId,
        );

        await MatchCommandService(destination).resumeImportedIncomplete(
          ResumeImportedIncompleteMatchCommand(
            commandId: 'merge-undo-resume',
            matchId: importedMatchId,
            claimedAtUtc: DateTime.utc(2026, 8, 24, 12),
          ),
        );
        final undone = await MatchCommandService(destination)
            .undoLastScoringAction(
              UndoLastScoringActionCommand(
                commandId: 'merge-undo-score',
                matchId: importedMatchId,
              ),
            );
        expect(
          undone.events
              .singleWhere((event) => event.id == importedEventId)
              .isDeleted,
          isTrue,
        );
      },
    );

    test(
      'legacy event and audit insertion order survives merge for scoring undo',
      () async {
        final source = await withTestDatabase((sourceDatabase) async {
          await _seedLibrary(
            sourceDatabase,
            matchId: 'merge-legacy-order',
            lifecycle: 'active',
            activeSession: true,
          );
          await (sourceDatabase.update(sourceDatabase.auditLogs)
                ..where((row) => row.id.equals('audit-1')))
              .write(const AuditLogsCompanion(action: Value('create')));
          await sourceDatabase
              .into(sourceDatabase.matchEvents)
              .insert(
                MatchEventRow(
                  id: 'event-2',
                  matchId: 'merge-legacy-order',
                  type: 'score',
                  side: 'red',
                  points: 3,
                  outcome: 'made',
                  matchClockPositionSeconds: null,
                  occurredAt: DateTime.utc(2026, 8, 24, 9, 1),
                  note: null,
                  customLabel: null,
                  isDeleted: false,
                ),
              );
          await sourceDatabase
              .into(sourceDatabase.auditLogs)
              .insert(
                AuditLog(
                  id: 'audit-2',
                  matchId: 'merge-legacy-order',
                  targetId: 'event-2',
                  action: 'create',
                  beforeJson: '{}',
                  afterJson: '{}',
                  reason: null,
                  createdAt: DateTime.utc(2026, 8, 24, 9, 2),
                ),
              );
          await sourceDatabase.customStatement(
            'PRAGMA reverse_unordered_selects = ON',
          );
          return JsonBackupCodec(
            sourceDatabase,
            appVersion: '1.0.0',
            now: () => DateTime.utc(2026, 8, 24, 10),
          ).export();
        });

        final destination = createTestDatabase();
        await _seedLibrary(destination);
        final result = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);
        final importedMatchId = result.idMap['matches']!['merge-legacy-order']!;
        final importedEvent1 = result.idMap['matchEvents']!['event-1']!;
        final importedEvent2 = result.idMap['matchEvents']!['event-2']!;

        await MatchCommandService(destination).resumeImportedIncomplete(
          ResumeImportedIncompleteMatchCommand(
            commandId: 'merge-legacy-order-resume',
            matchId: importedMatchId,
            claimedAtUtc: DateTime.utc(2026, 8, 24, 12),
          ),
        );
        final undone = await MatchCommandService(destination)
            .undoLastScoringAction(
              UndoLastScoringActionCommand(
                commandId: 'merge-legacy-order-undo',
                matchId: importedMatchId,
              ),
            );

        expect(
          undone.events
              .singleWhere((event) => event.id == importedEvent2)
              .isDeleted,
          isTrue,
        );
        expect(
          undone.events
              .singleWhere((event) => event.id == importedEvent1)
              .isDeleted,
          isFalse,
        );
      },
    );

    test(
      'imported-incomplete records are queryable and resume atomically with one active slot',
      () async {
        final source = await _exportLibrary(
          matchId: 'import-active',
          lifecycle: 'active',
          activeSession: true,
        );
        final destination = createTestDatabase();
        await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);

        final page = await MatchRepository(
          destination,
        ).queryImportedIncomplete();
        expect(page.entries, hasLength(1));
        expect(page.entries.single.lifecycle, MatchLifecycle.abandoned);

        final command = ResumeImportedIncompleteMatchCommand(
          commandId: 'resume-imported',
          matchId: 'import-active',
          claimedAtUtc: DateTime.utc(2026, 8, 24, 12),
        );
        final service = MatchCommandService(destination);
        final resumed = await service.resumeImportedIncomplete(command);
        final duplicate = await MatchCommandService(
          destination,
        ).resumeImportedIncomplete(command);

        expect(resumed.match.lifecycle, MatchLifecycle.active);
        expect(duplicate.match.lifecycle, MatchLifecycle.active);
        expect(
          await destination.select(destination.activeSessions).get(),
          hasLength(1),
        );
        expect(
          (await destination.select(destination.activeSessions).getSingle())
              .matchId,
          'import-active',
        );
        expect(
          await destination.select(destination.matches).getSingle(),
          isA<Matche>()
              .having(
                (row) => row.lifecycle,
                'lifecycle',
                MatchLifecycle.active.name,
              )
              .having(
                (row) => row.note,
                'reserved marker removed',
                isA<Null>(),
              ),
        );
      },
    );

    test(
      'resuming imported-incomplete keeps the local active session and record intact on conflict',
      () async {
        final source = await _exportLibrary(
          matchId: 'import-active-conflict',
          lifecycle: 'active',
          activeSession: true,
        );
        final destination = createTestDatabase();
        await _seedLibrary(
          destination,
          matchId: 'local-active',
          lifecycle: 'active',
          activeSession: true,
        );
        await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);

        await expectLater(
          MatchCommandService(destination).resumeImportedIncomplete(
            ResumeImportedIncompleteMatchCommand(
              commandId: 'resume-imported-conflict',
              matchId: 'import-active-conflict',
              claimedAtUtc: DateTime.utc(2026, 8, 24, 12),
            ),
          ),
          throwsA(isA<ActiveMatchConflictFailure>()),
        );

        expect(
          (await destination.select(destination.activeSessions).getSingle())
              .matchId,
          'local-active',
        );
        expect(
          (await (destination.select(destination.matches)..where(
                    (match) => match.id.equals('import-active-conflict'),
                  ))
                  .getSingle())
              .lifecycle,
          MatchLifecycle.abandoned.name,
        );
      },
    );

    test(
      'imported-incomplete resume rolls back lifecycle and claim together',
      () async {
        final source = await _exportLibrary(
          matchId: 'import-active-rollback',
          lifecycle: 'active',
          activeSession: true,
        );
        final destination = createTestDatabase();
        await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);
        final service = MatchCommandService(
          destination,
          failureInjector: (point) {
            if (point == MatchCommandFailurePoint.afterLifecycleWritten) {
              throw StateError('injected imported resume failure');
            }
          },
        );

        await expectLater(
          service.resumeImportedIncomplete(
            ResumeImportedIncompleteMatchCommand(
              commandId: 'resume-imported-rollback',
              matchId: 'import-active-rollback',
              claimedAtUtc: DateTime.utc(2026, 8, 24, 12),
            ),
          ),
          throwsA(isA<CommandTransactionFailure>()),
        );
        expect(
          await destination.select(destination.activeSessions).get(),
          isEmpty,
        );
        expect(
          (await (destination.select(destination.matches)..where(
                    (match) => match.id.equals('import-active-rollback'),
                  ))
                  .getSingle())
              .lifecycle,
          MatchLifecycle.abandoned.name,
        );
      },
    );

    test('same nickname with different IDs remains two players', () async {
      final source = await _exportLibrary(playerId: 'source-player');
      final destination = createTestDatabase();
      await _seedLibrary(destination, playerId: 'local-player');
      await destination
          .update(destination.players)
          .write(const PlayersCompanion(nickname: Value('Ace')));

      await BackupMergeService(
        destination,
        JsonBackupCodec(destination, appVersion: '1.0.0'),
      ).merge(source);

      final players = await destination.select(destination.players).get();
      expect(players, hasLength(2));
      expect(players.map((row) => row.nickname), everyElement('Ace'));
      expect(
        players.map((row) => row.id),
        containsAll(['local-player', 'source-player']),
      );
    });

    test(
      'imported active session becomes abandoned without touching local active',
      () async {
        final source = await _exportLibrary(
          matchId: 'import-active',
          lifecycle: 'active',
          activeSession: true,
        );
        final destination = createTestDatabase();
        await _seedLibrary(
          destination,
          matchId: 'local-active',
          lifecycle: 'active',
          activeSession: true,
        );

        final result = await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);

        expect(result.importedActiveSession, isTrue);
        final imported = (await destination.select(destination.matches).get())
            .singleWhere((row) => row.id == 'import-active');
        expect(imported.lifecycle, 'abandoned');
        expect(imported.note, contains('imported-incomplete'));
        final activeSessions = await destination
            .select(destination.activeSessions)
            .get();
        expect(activeSessions, hasLength(1));
        expect(activeSessions.single.matchId, 'local-active');
      },
    );

    test(
      'imported draft is retained as an abandoned incomplete record',
      () async {
        final source = await _exportLibrary(
          matchId: 'import-draft',
          lifecycle: 'draft',
        );
        final destination = createTestDatabase();

        await BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source);

        final imported =
            (await destination.select(destination.matches).get()).single;
        expect(imported.id, 'import-draft');
        expect(imported.lifecycle, 'abandoned');
        expect(imported.note, contains('imported-incomplete'));
        expect(
          (await MatchRepository(
            destination,
          ).queryImportedIncomplete()).entries.map((entry) => entry.id),
          contains('import-draft'),
        );
      },
    );

    test('repeating the same backup is idempotent', () async {
      final source = await _exportLibrary(playerNote: 'source-player');
      final destination = createTestDatabase();
      await _seedLibrary(destination, playerNote: 'local-player');
      await destination
          .update(destination.matches)
          .write(const MatchesCompanion(note: Value('local-match')));

      final service = BackupMergeService(
        destination,
        JsonBackupCodec(destination, appVersion: '1.0.0'),
      );
      final first = await service.merge(source);
      final countsAfterFirst = await _counts(destination);
      final second = await service.merge(source);
      final countsAfterSecond = await _counts(destination);

      expect(first.changed, isTrue);
      expect(second.changed, isFalse);
      expect(second.idMap, first.idMap);
      expect(countsAfterSecond, countsAfterFirst);
    });

    test('database failure rolls back all merge tables', () async {
      final source = await _exportLibrary();
      final destination = createTestDatabase();
      await destination.customStatement('''
        CREATE TRIGGER reject_merge_match
        BEFORE INSERT ON matches
        WHEN NEW.id = 'match-1'
        BEGIN
          SELECT RAISE(ABORT, 'forced merge failure');
        END;
      ''');

      await expectLater(
        BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge(source),
        throwsA(isA<BackupMergeException>()),
      );
      expect(await destination.select(destination.players).get(), isEmpty);
      expect(
        await destination.select(destination.ruleTemplates).get(),
        isEmpty,
      );
      expect(await destination.select(destination.matches).get(), isEmpty);
      expect(await destination.select(destination.matchEvents).get(), isEmpty);
    });

    test('invalid input is rejected before local mutation', () async {
      final destination = createTestDatabase();
      await destination
          .into(destination.players)
          .insert(
            PlayerRow(
              id: 'keep',
              nickname: 'Keep',
              createdAt: DateTime.utc(2026, 8, 24),
              preferredSide: null,
              note: null,
            ),
          );

      await expectLater(
        BackupMergeService(
          destination,
          JsonBackupCodec(destination, appVersion: '1.0.0'),
        ).merge('{"manifest": {}}'),
        throwsA(isA<BackupException>()),
      );
      expect(
        (await destination.select(destination.players).get()).single.id,
        'keep',
      );
    });
  });
}

Future<String> _exportLibrary({
  String playerId = 'player-1',
  String matchId = 'match-1',
  String lifecycle = 'finished',
  String? playerNote,
  bool activeSession = false,
  int clockAccumulatedSeconds = 0,
  double locationX = 0.25,
  String auditBeforeJson = '{}',
  String auditAfterJson = '{}',
}) async {
  final source = AppDatabase.inMemory();
  try {
    await _seedLibrary(
      source,
      playerId: playerId,
      matchId: matchId,
      lifecycle: lifecycle,
      playerNote: playerNote,
      activeSession: activeSession,
      clockAccumulatedSeconds: clockAccumulatedSeconds,
      locationX: locationX,
      auditBeforeJson: auditBeforeJson,
      auditAfterJson: auditAfterJson,
    );
    return await JsonBackupCodec(
      source,
      appVersion: '1.0.0',
      now: () => DateTime.utc(2026, 8, 24, 10),
    ).export();
  } finally {
    await source.close();
  }
}

Future<void> _seedLibrary(
  AppDatabase database, {
  String playerId = 'player-1',
  String matchId = 'match-1',
  String lifecycle = 'finished',
  String? playerNote,
  bool activeSession = false,
  int clockAccumulatedSeconds = 0,
  double locationX = 0.25,
  String auditBeforeJson = '{}',
  String auditAfterJson = '{}',
}) async {
  final createdAt = DateTime.utc(2026, 8, 24, 9);
  await database
      .into(database.players)
      .insert(
        PlayerRow(
          id: playerId,
          nickname: 'Ace',
          createdAt: createdAt,
          preferredSide: 'red',
          note: playerNote,
        ),
      );
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
      .into(database.matches)
      .insert(
        Matche(
          id: matchId,
          lifecycle: lifecycle,
          recordingMode: 'simple',
          trackingCoverage: 'locations',
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
          endedAt: lifecycle == 'finished'
              ? createdAt.add(const Duration(minutes: 8))
              : null,
          timerEnabled: false,
          note: null,
        ),
      );
  await database.batch((batch) {
    batch.insertAll(database.matchParticipants, [
      MatchParticipant(
        id: 'participant-red',
        matchId: matchId,
        side: 'red',
        nameSnapshot: 'Ace',
        playerProfileId: playerId,
      ),
      MatchParticipant(
        id: 'participant-blue',
        matchId: matchId,
        side: 'blue',
        nameSnapshot: 'Blue',
        playerProfileId: null,
      ),
    ]);
  });
  await database
      .into(database.matchClocks)
      .insert(
        MatchClock(
          id: 'clock-1',
          matchId: matchId,
          mode: 'countUp',
          phase: 'regulation',
          accumulatedSeconds: clockAccumulatedSeconds,
          runningSinceUtc: null,
          regulationSeconds: null,
        ),
      );
  await database
      .into(database.matchEvents)
      .insert(
        MatchEventRow(
          id: 'event-1',
          matchId: matchId,
          type: 'score',
          side: 'red',
          points: 2,
          outcome: null,
          matchClockPositionSeconds: null,
          occurredAt: createdAt.add(const Duration(seconds: 15)),
          note: null,
          customLabel: null,
          isDeleted: false,
        ),
      );
  await database
      .into(database.shotLocations)
      .insert(
        ShotLocation(
          id: 'location-1',
          matchId: matchId,
          eventId: 'event-1',
          x: locationX,
          y: 0.75,
          isConfirmed: true,
        ),
      );
  await database
      .into(database.possessionSegments)
      .insert(
        PossessionSegment(
          id: 'possession-1',
          matchId: matchId,
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
          matchId: matchId,
          targetId: 'event-1',
          action: 'edit',
          beforeJson: auditBeforeJson,
          afterJson: auditAfterJson,
          reason: null,
          createdAt: createdAt.add(const Duration(minutes: 1)),
        ),
      );
  await database
      .into(database.appSettings)
      .insert(
        AppSetting(
          key: 'theme',
          valueJson: jsonEncode('light'),
          updatedAt: createdAt,
        ),
      );
  if (activeSession) {
    await database
        .into(database.activeSessions)
        .insert(
          ActiveSession(
            id: 'active',
            matchId: matchId,
            claimedAtUtc: createdAt,
          ),
        );
  }
}

Future<List<int>> _counts(AppDatabase database) async {
  return [
    (await database.select(database.matches).get()).length,
    (await database.select(database.matchParticipants).get()).length,
    (await database.select(database.matchClocks).get()).length,
    (await database.select(database.matchEvents).get()).length,
    (await database.select(database.shotLocations).get()).length,
    (await database.select(database.players).get()).length,
    (await database.select(database.ruleTemplates).get()).length,
    (await database.select(database.possessionSegments).get()).length,
    (await database.select(database.auditLogs).get()).length,
    (await database.select(database.appSettings).get()).length,
  ];
}
