import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart' hide ShotLocation;
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'start atomically claims the active row and is idempotent across services',
    () async {
      final database = createTestDatabase();
      final command = _startCommand(commandId: 'start-1', matchId: 'match-1');

      final first = await MatchCommandService(database).start(command);
      final second = await MatchCommandService(database).start(command);

      expect(first.match.id, 'match-1');
      expect(second.match.id, 'match-1');
      expect(second.match.redName, 'Red');
      expect(await database.select(database.matches).get(), hasLength(1));
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );
      expect(
        await database
            .select(database.activeSessions)
            .getSingle()
            .then((row) => row.matchId),
        'match-1',
      );
      expect(
        await database.select(database.matchParticipants).get(),
        hasLength(2),
      );
      expect(await database.select(database.matchClocks).get(), hasLength(1));
      expect(
        await (database.select(
          database.auditLogs,
        )..where((row) => row.action.equals('command'))).get(),
        hasLength(1),
      );
    },
  );

  test(
    'record writes its event and optional location atomically and duplicate command scores once',
    () async {
      final database = createTestDatabase();
      final start = _startCommand(commandId: 'start-2', matchId: 'match-2');
      await MatchCommandService(database).start(start);
      final command = RecordMatchEventCommand(
        commandId: 'record-1',
        matchId: 'match-2',
        eventId: 'event-1',
        type: EventKind.fieldGoal,
        side: TeamSide.red,
        points: 2,
        outcome: ShotOutcome.made,
        occurredAt: DateTime.utc(2026, 8, 22, 10),
        shotLocation: const MatchShotLocationInput(x: 0.25, y: 0.75),
      );

      final first = await MatchCommandService(database).record(command);
      final second = await MatchCommandService(database).record(command);

      expect(first.redScore, 2);
      expect(second.redScore, 2);
      expect(await database.select(database.matchEvents).get(), hasLength(1));
      expect(await database.select(database.shotLocations).get(), hasLength(1));
      expect(await database.select(database.auditLogs).get(), hasLength(3));
    },
  );

  test(
    'same command id with a different payload is a typed conflict with the committed projection',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
      ).start(_startCommand(commandId: 'start-3', matchId: 'match-3'));
      final original = RecordMatchEventCommand(
        commandId: 'record-conflict',
        matchId: 'match-3',
        eventId: 'event-conflict',
        side: TeamSide.blue,
        points: 1,
        occurredAt: DateTime.utc(2026, 8, 22, 10),
      );
      await MatchCommandService(database).record(original);

      final conflicting = RecordMatchEventCommand(
        commandId: original.commandId,
        matchId: original.matchId,
        eventId: original.eventId,
        side: original.side,
        points: 3,
        occurredAt: original.occurredAt,
      );

      await expectLater(
        MatchCommandService(database).record(conflicting),
        throwsA(
          isA<CommandConflictFailure>()
              .having(
                (failure) => failure.lastCommittedProjection?.blueScore,
                'blue score',
                1,
              )
              .having((failure) => failure.canRetry, 'retryable', isFalse),
        ),
      );
      expect(await database.select(database.matchEvents).get(), hasLength(1));
    },
  );

  test(
    'record projection counts made field goals and free throws but not misses',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      await service.start(
        _startCommand(commandId: 'start-shots', matchId: 'match-shots'),
      );

      final fieldGoal = await service.record(
        RecordMatchEventCommand(
          commandId: 'field-goal',
          matchId: 'match-shots',
          eventId: 'field-goal-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      );
      final missedFreeThrow = await service.record(
        RecordMatchEventCommand(
          commandId: 'missed-free-throw',
          matchId: 'match-shots',
          eventId: 'missed-free-throw-event',
          type: EventKind.freeThrow,
          side: TeamSide.blue,
          points: 0,
          outcome: ShotOutcome.missed,
          occurredAt: DateTime.utc(2026, 8, 22, 10, 1),
        ),
      );
      final freeThrow = await service.record(
        RecordMatchEventCommand(
          commandId: 'free-throw',
          matchId: 'match-shots',
          eventId: 'free-throw-event',
          type: EventKind.freeThrow,
          side: TeamSide.blue,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 22, 10, 2),
        ),
      );

      expect(fieldGoal.redScore, 2);
      expect(missedFreeThrow.blueScore, 0);
      expect(freeThrow.blueScore, 1);
    },
  );

  test(
    'record rejects shot locations for non-shot events before writing rows',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      await service.start(
        _startCommand(
          commandId: 'start-location-validation',
          matchId: 'match-location-validation',
        ),
      );
      final failure = await _captureFailure(
        () => service.record(
          RecordMatchEventCommand(
            commandId: 'invalid-location',
            matchId: 'match-location-validation',
            eventId: 'invalid-location-event',
            type: EventKind.foul,
            side: TeamSide.red,
            points: 0,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
            shotLocation: const MatchShotLocationInput(x: 0.5, y: 0.5),
          ),
        ),
      );

      expect(failure, isA<CommandValidationFailure>());
      expect(await database.select(database.matchEvents).get(), isEmpty);
      expect(await database.select(database.shotLocations).get(), isEmpty);
    },
  );

  test(
    'correct preserves event identity and writes human-readable before/after audit atomically',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
      ).start(_startCommand(commandId: 'start-4', matchId: 'match-4'));
      await MatchCommandService(database).record(
        RecordMatchEventCommand(
          commandId: 'record-4',
          matchId: 'match-4',
          eventId: 'event-4',
          side: TeamSide.red,
          points: 2,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      );

      final projection = await MatchCommandService(database).correct(
        CorrectMatchEventCommand(
          commandId: 'correct-4',
          matchId: 'match-4',
          eventId: 'event-4',
          side: TeamSide.blue,
          points: 3,
          reason: 'Wrong side and value',
        ),
      );

      expect(projection.redScore, 0);
      expect(projection.blueScore, 3);
      expect(projection.events.single.id, 'event-4');
      final audits = await MatchRepositoryForTest(database).auditRows();
      final edit = audits.singleWhere((row) => row.action == 'edit');
      expect(edit.beforeJson, contains('"side":"red"'));
      expect(edit.afterJson, contains('"side":"blue"'));
      expect(edit.afterJson, contains('"points":3'));
      expect(edit.reason, 'Wrong side and value');
    },
  );

  test(
    'undo soft-deletes an event and writes an undo audit without changing event id',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
      ).start(_startCommand(commandId: 'start-5', matchId: 'match-5'));
      await MatchCommandService(database).record(
        RecordMatchEventCommand(
          commandId: 'record-5',
          matchId: 'match-5',
          eventId: 'event-5',
          side: TeamSide.red,
          points: 2,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      );

      final projection = await MatchCommandService(database).undo(
        UndoMatchEventCommand(
          commandId: 'undo-5',
          matchId: 'match-5',
          eventId: 'event-5',
          reason: 'Accidental tap',
        ),
      );

      expect(projection.redScore, 0);
      final row = await database.select(database.matchEvents).getSingle();
      expect(row.id, 'event-5');
      expect(row.isDeleted, isTrue);
      final audits = await MatchRepositoryForTest(database).auditRows();
      final undo = audits.singleWhere((row) => row.action == 'undo');
      expect(undo.beforeJson, contains('"isDeleted":false'));
      expect(undo.afterJson, contains('"isDeleted":true'));
      expect(undo.reason, 'Accidental tap');
    },
  );

  test(
    'pause and resume record semantic events and finish clears the active row',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      await service.start(
        _startCommand(commandId: 'start-6', matchId: 'match-6'),
      );

      await service.pause(
        PauseMatchCommand(
          commandId: 'pause-6',
          matchId: 'match-6',
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      );
      await service.resume(
        ResumeMatchCommand(
          commandId: 'resume-6',
          matchId: 'match-6',
          occurredAt: DateTime.utc(2026, 8, 22, 10, 1),
        ),
      );
      final finished = await service.finish(
        FinishMatchCommand(
          commandId: 'finish-6',
          matchId: 'match-6',
          endedAt: DateTime.utc(2026, 8, 22, 11),
          confirmFinalScore: true,
        ),
      );
      final duplicate = await MatchCommandService(database).finish(
        FinishMatchCommand(
          commandId: 'finish-6',
          matchId: 'match-6',
          endedAt: DateTime.utc(2026, 8, 22, 11),
          confirmFinalScore: true,
        ),
      );

      expect(finished.match.lifecycle, MatchLifecycle.finished);
      expect(duplicate.match.lifecycle, MatchLifecycle.finished);
      expect(await database.select(database.activeSessions).get(), isEmpty);
      final events = await database.select(database.matchEvents).get();
      expect(
        events.map((row) => row.customLabel),
        containsAll(<String?>['pause', 'resume']),
      );
    },
  );

  test('abandon clears the active row and is idempotent', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    await service.start(
      _startCommand(commandId: 'start-7', matchId: 'match-7'),
    );

    final abandoned = await service.abandon(
      AbandonMatchCommand(
        commandId: 'abandon-7',
        matchId: 'match-7',
        endedAt: DateTime.utc(2026, 8, 22, 11),
      ),
    );
    final duplicate = await MatchCommandService(database).abandon(
      AbandonMatchCommand(
        commandId: 'abandon-7',
        matchId: 'match-7',
        endedAt: DateTime.utc(2026, 8, 22, 11),
      ),
    );

    expect(abandoned.match.lifecycle, MatchLifecycle.abandoned);
    expect(duplicate.match.lifecycle, MatchLifecycle.abandoned);
    expect(await database.select(database.activeSessions).get(), isEmpty);
  });

  test(
    'injected failure rolls back the event and exposes the last committed projection for retry',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
      ).start(_startCommand(commandId: 'start-8', matchId: 'match-8'));
      var fail = true;
      final command = RecordMatchEventCommand(
        commandId: 'record-8',
        matchId: 'match-8',
        eventId: 'event-8',
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026, 8, 22, 10),
      );
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (fail && point == MatchCommandFailurePoint.afterEventWritten) {
            throw StateError('injected rollback');
          }
        },
      );

      final failure = await _captureFailure(() => service.record(command));
      expect(failure, isA<CommandTransactionFailure>());
      expect(failure.lastCommittedProjection?.redScore, 0);
      expect(failure.canRetry, isTrue);
      expect(await database.select(database.matchEvents).get(), isEmpty);

      fail = false;
      final retried = await failure.retry();
      expect(retried.redScore, 2);
      expect(await database.select(database.matchEvents).get(), hasLength(1));
    },
  );

  test(
    'simultaneous starts leave one committed match and reject the other with a typed failure',
    () async {
      final database = createTestDatabase();
      final first = _startCommand(
        commandId: 'simultaneous-1',
        matchId: 'match-a',
      );
      final second = _startCommand(
        commandId: 'simultaneous-2',
        matchId: 'match-b',
      );

      final results = await Future.wait<Object>([
        _observe(MatchCommandService(database).start(first)),
        _observe(MatchCommandService(database).start(second)),
      ]);

      expect(results.whereType<Exception>(), hasLength(1));
      expect(results.whereType<MatchDetail>(), hasLength(1));
      expect(results.whereType<MatchCommandFailure>(), hasLength(1));
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );
      expect(await database.select(database.matches).get(), hasLength(1));
    },
  );
}

Future<Object> _observe(Future<MatchDetail> operation) async {
  try {
    return await operation;
  } on Object catch (error) {
    return error;
  }
}

StartMatchCommand _startCommand({
  required String commandId,
  required String matchId,
}) {
  return StartMatchCommand(
    commandId: commandId,
    matchId: matchId,
    redName: 'Red',
    blueName: 'Blue',
    ruleTemplate: const RuleTemplate(
      id: 'free',
      name: 'Free',
      scoreButtons: [1, 2, 3],
    ),
    recordingMode: RecordingMode.simple,
    startedAt: DateTime.utc(2026, 8, 22, 9),
  );
}

Future<MatchCommandFailure> _captureFailure(
  Future<Object> Function() operation,
) async {
  try {
    await operation();
    fail('Expected a typed command failure.');
  } on MatchCommandFailure catch (failure) {
    return failure;
  }
}

/// Small test-only adapter keeps row assertions independent from repository
/// mapping while the command service remains a Drift-facing kernel.
class MatchRepositoryForTest {
  MatchRepositoryForTest(this.database);

  final AppDatabase database;

  Future<List<AuditLog>> auditRows() =>
      database.select(database.auditLogs).get();
}
