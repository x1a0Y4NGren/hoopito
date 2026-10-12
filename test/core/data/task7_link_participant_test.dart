import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:hoopito/core/data/app_database.dart' hide ShotLocation;
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'finished match links a temporary participant with an audit receipt',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-red', 'New profile name');
        final service = MatchCommandService(database);
        final start = await _start(service, 'task7-link-finished');
        await service.finish(
          FinishMatchCommand(
            commandId: 'task7-finish-finished',
            matchId: start.match.id,
            endedAt: DateTime.utc(2026, 8, 23, 11),
            confirmFinalScore: true,
          ),
        );
        final participant = await _participant(
          database,
          matchId: start.match.id,
          side: 'red',
        );

        final linked = await service.linkParticipant(
          LinkMatchParticipantCommand(
            commandId: 'task7-link-finished-command',
            auditId: 'task7-link-finished-audit',
            matchId: start.match.id,
            participantId: participant.id,
            playerProfileId: 'player-red',
            reason: 'Identified after the game',
          ),
        );

        expect(linked.match.lifecycle, MatchLifecycle.finished);
        final linkedParticipant = linked.match.participants.singleWhere(
          (value) => value.id == participant.id,
        );
        expect(linkedParticipant.playerProfileId, 'player-red');
        expect(linkedParticipant.nameSnapshot, 'Red temporary');
        final audit =
            await (database.select(database.auditLogs)
                  ..where((row) => row.id.equals('task7-link-finished-audit')))
                .getSingle();
        expect(audit.action, 'edit');
        expect(audit.beforeJson, contains('"playerProfileId":null'));
        expect(audit.afterJson, contains('"playerProfileId":"player-red"'));
        expect(audit.afterJson, contains('"nameSnapshot":"Red temporary"'));
        final receipt =
            await (database.select(
                  database.auditLogs,
                )..where((row) => row.id.equals('task7-link-finished-command')))
                .getSingle();
        expect(receipt.action, 'command');
      });
    },
  );

  test(
    'archived match can link and profile rename never changes the snapshot',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-archive', 'Before rename');
        final service = MatchCommandService(database);
        final start = await _start(service, 'task7-link-archived');
        await service.finish(
          FinishMatchCommand(
            matchId: start.match.id,
            endedAt: DateTime.utc(2026, 8, 23, 11),
            confirmFinalScore: true,
          ),
        );
        await (database.update(
          database.matches,
        )..where((row) => row.id.equals(start.match.id))).write(
          MatchesCompanion(lifecycle: Value(MatchLifecycle.archived.name)),
        );
        final participant = await _participant(
          database,
          matchId: start.match.id,
          side: 'red',
        );

        await service.linkParticipant(
          LinkMatchParticipantCommand(
            matchId: start.match.id,
            participantId: participant.id,
            playerProfileId: 'player-archive',
          ),
        );
        await database
            .into(database.players)
            .insertOnConflictUpdate(
              PlayersCompanion.insert(
                id: 'player-archive',
                nickname: 'After rename',
                createdAt: DateTime.utc(2026, 8, 23),
              ),
            );

        final detail = await MatchRepository(
          database,
        ).getMatchDetail(start.match.id);
        expect(detail, isNotNull);
        expect(
          detail!.match.participants
              .singleWhere((value) => value.id == participant.id)
              .nameSnapshot,
          'Red temporary',
        );
      });
    },
  );

  test(
    'duplicate link command returns its first projection without new audit',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-duplicate', 'Profile');
        final service = MatchCommandService(database);
        final start = await _start(service, 'task7-link-idempotent');
        await service.finish(
          FinishMatchCommand(
            matchId: start.match.id,
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        final participant = await _participant(
          database,
          matchId: start.match.id,
          side: 'red',
        );
        final command = LinkMatchParticipantCommand(
          commandId: 'task7-link-idempotent-command',
          auditId: 'task7-link-idempotent-audit',
          matchId: start.match.id,
          participantId: participant.id,
          playerProfileId: 'player-duplicate',
        );

        final first = await service.linkParticipant(command);
        final second = await service.linkParticipant(command);

        expect(
          second.match.participants
              .singleWhere((value) => value.id == participant.id)
              .playerProfileId,
          isNotNull,
        );
        final firstLinked = first.match.participants.singleWhere(
          (value) => value.id == participant.id,
        );
        final secondLinked = second.match.participants.singleWhere(
          (value) => value.id == participant.id,
        );
        expect(secondLinked.playerProfileId, firstLinked.playerProfileId);
        expect(secondLinked.nameSnapshot, firstLinked.nameSnapshot);
        expect(
          await (database.select(
            database.auditLogs,
          )..where((row) => row.matchId.equals(start.match.id))).get(),
          hasLength(5), // start + finish clock/audit + link audit/receipt
        );
      });
    },
  );

  test('same command id with a different link payload conflicts', () async {
    await withTestDatabase((database) async {
      await _insertPlayer(database, 'player-one', 'One');
      await _insertPlayer(database, 'player-two', 'Two');
      final service = MatchCommandService(database);
      final start = await _start(service, 'task7-link-conflict');
      await service.finish(
        FinishMatchCommand(
          matchId: start.match.id,
          endedAt: DateTime.now(),
          confirmFinalScore: true,
        ),
      );
      final participant = await _participant(
        database,
        matchId: start.match.id,
        side: 'red',
      );
      final first = LinkMatchParticipantCommand(
        commandId: 'task7-link-conflict-command',
        matchId: start.match.id,
        participantId: participant.id,
        playerProfileId: 'player-one',
      );
      await service.linkParticipant(first);

      await expectLater(
        service.linkParticipant(
          LinkMatchParticipantCommand(
            commandId: first.commandId,
            matchId: first.matchId,
            participantId: first.participantId,
            playerProfileId: 'player-two',
          ),
        ),
        throwsA(isA<CommandConflictFailure>()),
      );
    });
  });

  test(
    'link rejects active matches, unknown profile, and already linked rows',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-linked', 'Linked');
        final service = MatchCommandService(database);
        final active = await _start(service, 'task7-link-active');
        final activeParticipant = await _participant(
          database,
          matchId: active.match.id,
          side: 'red',
        );

        await expectLater(
          service.linkParticipant(
            LinkMatchParticipantCommand(
              matchId: active.match.id,
              participantId: activeParticipant.id,
              playerProfileId: 'player-linked',
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
        await expectLater(
          service.linkParticipant(
            LinkMatchParticipantCommand(
              matchId: active.match.id,
              participantId: activeParticipant.id,
              playerProfileId: 'missing',
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );

        await service.finish(
          FinishMatchCommand(
            matchId: active.match.id,
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        await (database.update(
          database.matchParticipants,
        )..where((row) => row.id.equals(activeParticipant.id))).write(
          const MatchParticipantsCompanion(
            playerProfileId: Value('player-linked'),
          ),
        );
        await expectLater(
          service.linkParticipant(
            LinkMatchParticipantCommand(
              matchId: active.match.id,
              participantId: activeParticipant.id,
              playerProfileId: 'player-linked',
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
      });
    },
  );

  test('link rejects abandoned matches', () async {
    await withTestDatabase((database) async {
      await _insertPlayer(database, 'player-abandoned', 'Abandoned profile');
      final service = MatchCommandService(database);
      final start = await _start(service, 'task7-link-abandoned');
      await service.abandon(
        AbandonMatchCommand(
          commandId: 'task7-abandon-link',
          matchId: start.match.id,
          endedAt: DateTime.utc(2026, 8, 23, 11),
        ),
      );
      final participant = await _participant(
        database,
        matchId: start.match.id,
        side: 'red',
      );

      await expectLater(
        service.linkParticipant(
          LinkMatchParticipantCommand(
            matchId: start.match.id,
            participantId: participant.id,
            playerProfileId: 'player-abandoned',
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );
    });
  });

  test(
    'link rejects a profile already used by the other participant',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-other', 'Other');
        final service = MatchCommandService(database);
        final start = await _start(
          service,
          'task7-link-other-side',
          bluePlayerProfileId: 'player-other',
        );
        await service.finish(
          FinishMatchCommand(
            matchId: start.match.id,
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        final red = await _participant(
          database,
          matchId: start.match.id,
          side: 'red',
        );

        await expectLater(
          service.linkParticipant(
            LinkMatchParticipantCommand(
              matchId: start.match.id,
              participantId: red.id,
              playerProfileId: 'player-other',
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
      });
    },
  );

  test(
    'failed link rolls back participant, audit, and receipt and retries',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-retry', 'Retry');
        final setupService = MatchCommandService(database);
        final start = await _start(setupService, 'task7-link-retry');
        await setupService.finish(
          FinishMatchCommand(
            matchId: start.match.id,
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        final participant = await _participant(
          database,
          matchId: start.match.id,
          side: 'red',
        );
        var shouldFail = true;
        final service = MatchCommandService(
          database,
          failureInjector: (point) {
            if (shouldFail &&
                point == MatchCommandFailurePoint.afterEventWritten) {
              shouldFail = false;
              throw StateError('injected link rollback');
            }
          },
        );
        final command = LinkMatchParticipantCommand(
          commandId: 'task7-link-retry-command',
          auditId: 'task7-link-retry-audit',
          matchId: start.match.id,
          participantId: participant.id,
          playerProfileId: 'player-retry',
        );

        MatchCommandFailure? failure;
        try {
          await service.linkParticipant(command);
        } on MatchCommandFailure catch (error) {
          failure = error;
        }
        expect(failure, isA<CommandTransactionFailure>());
        expect(
          (await _participant(
            database,
            matchId: start.match.id,
            side: 'red',
          )).playerProfileId,
          isNull,
        );
        expect(
          await (database.select(database.auditLogs)..where(
                (row) => row.id.isIn([command.commandId, command.auditId]),
              ))
              .get(),
          isEmpty,
        );

        final retried = await failure!.retry();
        expect(
          retried.match.participants
              .singleWhere((value) => value.id == participant.id)
              .playerProfileId,
          'player-retry',
        );
      });
    },
  );

  test(
    'link rejects a missing match and a participant from another match',
    () async {
      await withTestDatabase((database) async {
        await _insertPlayer(database, 'player-cross-match', 'Cross match');
        final service = MatchCommandService(database);
        final first = await _start(service, 'task7-link-first-match');
        await service.finish(
          FinishMatchCommand(
            matchId: first.match.id,
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        final second = await _start(service, 'task7-link-second-match');
        await service.finish(
          FinishMatchCommand(
            matchId: second.match.id,
            endedAt: DateTime.now(),
            confirmFinalScore: true,
          ),
        );
        final secondParticipant = await _participant(
          database,
          matchId: second.match.id,
          side: 'red',
        );

        await expectLater(
          service.linkParticipant(
            LinkMatchParticipantCommand(
              matchId: first.match.id,
              participantId: secondParticipant.id,
              playerProfileId: 'player-cross-match',
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
        await expectLater(
          service.linkParticipant(
            LinkMatchParticipantCommand(
              matchId: 'missing-match',
              participantId: secondParticipant.id,
              playerProfileId: 'player-cross-match',
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
      });
    },
  );
}

Future<MatchDetail> _start(
  MatchCommandService service,
  String matchId, {
  String? bluePlayerProfileId,
}) {
  return service.start(
    StartMatchCommand(
      commandId: '$matchId-start',
      matchId: matchId,
      redName: 'Red temporary',
      blueName: 'Blue temporary',
      bluePlayerProfileId: bluePlayerProfileId,
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      createdAt: DateTime.utc(2026, 8, 23, 10),
      startedAt: DateTime.utc(2026, 8, 23, 10),
    ),
  );
}

Future<MatchParticipant> _participant(
  AppDatabase database, {
  required String matchId,
  required String side,
}) {
  return (database.select(database.matchParticipants)
        ..where((row) => row.matchId.equals(matchId) & row.side.equals(side)))
      .getSingle();
}

Future<void> _insertPlayer(AppDatabase database, String id, String nickname) {
  return database
      .into(database.players)
      .insert(
        PlayersCompanion.insert(
          id: id,
          nickname: nickname,
          createdAt: DateTime.utc(2026, 8, 23),
        ),
      );
}
