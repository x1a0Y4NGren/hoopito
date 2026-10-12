import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart' hide ShotLocation;
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  group('replay event correction', () {
    test(
      'corrects events in a finished replay and recalculates the score',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final start = _startCommand('task11-finished-correction');
        await service.start(start);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-finished-record',
            matchId: start.matchId,
            eventId: 'task11-finished-event',
            side: TeamSide.red,
            points: 2,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        );
        await service.finish(
          FinishMatchCommand(
            commandId: 'task11-finished-finish',
            matchId: start.matchId,
            endedAt: DateTime.utc(2026, 8, 22, 11),
            confirmFinalScore: true,
          ),
        );

        final corrected = await service.correct(
          CorrectMatchEventCommand(
            commandId: 'task11-finished-correct',
            matchId: start.matchId,
            eventId: 'task11-finished-event',
            side: TeamSide.blue,
            points: 3,
            auditId: 'task11-finished-correct-audit',
            reason: 'Replay review',
          ),
        );

        expect(corrected.match.lifecycle, MatchLifecycle.finished);
        expect(corrected.redScore, 0);
        expect(corrected.blueScore, 3);
        final audit = await _auditById(
          database,
          'task11-finished-correct-audit',
        );
        expect(audit.action, 'edit');
        expect(audit.targetId, 'task11-finished-event');
        expect(audit.reason, 'Replay review');
      },
    );

    test(
      'corrects events in an archived replay without enabling new active-match behavior',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final start = _startCommand('task11-archived-correction');
        await service.start(start);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-archived-record',
            matchId: start.matchId,
            eventId: 'task11-archived-event',
            side: TeamSide.red,
            points: 1,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        );
        await service.finish(
          FinishMatchCommand(
            commandId: 'task11-archived-finish',
            matchId: start.matchId,
            endedAt: DateTime.utc(2026, 8, 22, 11),
            confirmFinalScore: true,
          ),
        );
        await (database.update(
          database.matches,
        )..where((row) => row.id.equals(start.matchId))).write(
          MatchesCompanion(lifecycle: Value(MatchLifecycle.archived.name)),
        );

        final corrected = await service.correct(
          CorrectMatchEventCommand(
            commandId: 'task11-archived-correct',
            matchId: start.matchId,
            eventId: 'task11-archived-event',
            points: 2,
          ),
        );

        expect(corrected.match.lifecycle, MatchLifecycle.archived);
        expect(corrected.redScore, 2);
      },
    );

    test(
      'removes and audits a location when correction changes shot kind',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final start = _startCommand('task11-correction-location-invariant');
        await service.start(start);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-location-kind-record',
            matchId: start.matchId,
            eventId: 'task11-location-kind-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        );
        await database
            .into(database.shotLocations)
            .insert(
              ShotLocationsCompanion.insert(
                id: 'task11-location-kind-location',
                matchId: start.matchId,
                eventId: 'task11-location-kind-event',
                x: 0.2,
                y: 0.3,
                isConfirmed: const Value(true),
              ),
            );
        await service.finish(
          FinishMatchCommand(
            commandId: 'task11-location-kind-finish',
            matchId: start.matchId,
            endedAt: DateTime.utc(2026, 8, 22, 11),
            confirmFinalScore: true,
          ),
        );

        final corrected = await service.correct(
          CorrectMatchEventCommand(
            commandId: 'task11-location-kind-correct',
            matchId: start.matchId,
            eventId: 'task11-location-kind-event',
            type: EventKind.freeThrow,
            points: 1,
            outcome: ShotOutcome.made,
            auditId: 'task11-location-kind-audit',
            reason: 'Wrong shot kind',
          ),
        );

        expect(corrected.shotLocations, isEmpty);
        expect(await database.select(database.shotLocations).get(), isEmpty);
        final locationAudit = await _auditById(
          database,
          'task11-location-kind-audit:location',
        );
        expect(locationAudit.action, 'locate');
        expect(locationAudit.beforeJson, contains('"x":0.2'));
        expect(locationAudit.afterJson, '{}');
        expect(locationAudit.reason, 'Wrong shot kind');
      },
    );

    test(
      'rejects correction of a deleted replay event until it is restored',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final start = _startCommand('task11-deleted-correction');
        await service.start(start);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-deleted-record',
            matchId: start.matchId,
            eventId: 'task11-deleted-event',
            side: TeamSide.red,
            points: 2,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        );
        await service.undo(
          UndoMatchEventCommand(
            commandId: 'task11-deleted-undo',
            matchId: start.matchId,
            eventId: 'task11-deleted-event',
          ),
        );

        await expectLater(
          service.correct(
            CorrectMatchEventCommand(
              commandId: 'task11-deleted-correct',
              matchId: start.matchId,
              eventId: 'task11-deleted-event',
              points: 3,
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
      },
    );
  });

  group('restore replay event command', () {
    test(
      'restores a deleted event, recalculates score and possession, and writes audit',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final start = _startCommand(
          'task11-restore',
          template: const RuleTemplate(
            id: 'possession',
            name: 'Possession',
            scoreButtons: [1, 2, 3],
            possessionHintEnabled: true,
            possessionPolicy: PossessionPolicy.switchAfterMade,
          ),
        );
        await service.start(start);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-restore-record',
            matchId: start.matchId,
            eventId: 'task11-restore-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        );
        expect(
          (await _read(database, start.matchId)).possessionSegments,
          isNotEmpty,
        );
        await service.undo(
          UndoMatchEventCommand(
            commandId: 'task11-restore-undo',
            matchId: start.matchId,
            eventId: 'task11-restore-event',
          ),
        );
        expect((await _read(database, start.matchId)).redScore, 0);
        expect(
          (await _read(database, start.matchId)).possessionSegments,
          isEmpty,
        );

        final restored = await service.restore(
          RestoreMatchEventCommand(
            commandId: 'task11-restore-command',
            matchId: start.matchId,
            eventId: 'task11-restore-event',
            auditId: 'task11-restore-command-audit',
            reason: 'Replay review',
          ),
        );

        expect(restored.redScore, 2);
        expect(restored.possessionSegments, isNotEmpty);
        final restoredRow = await (database.select(
          database.matchEvents,
        )..where((row) => row.id.equals('task11-restore-event'))).getSingle();
        expect(restoredRow.isDeleted, isFalse);
        final audit = await _auditById(
          database,
          'task11-restore-command-audit',
        );
        expect(audit.action, 'restore');
        expect(audit.beforeJson, contains('"isDeleted":true'));
        expect(audit.afterJson, contains('"isDeleted":false'));
      },
    );

    test(
      'returns the first restore projection from an idempotent receipt',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final start = _startCommand('task11-restore-receipt');
        await service.start(start);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-restore-receipt-record',
            matchId: start.matchId,
            eventId: 'task11-restore-receipt-event',
            side: TeamSide.red,
            points: 2,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        );
        await service.undo(
          UndoMatchEventCommand(
            commandId: 'task11-restore-receipt-undo',
            matchId: start.matchId,
            eventId: 'task11-restore-receipt-event',
          ),
        );
        final command = RestoreMatchEventCommand(
          commandId: 'task11-restore-receipt-command',
          matchId: start.matchId,
          eventId: 'task11-restore-receipt-event',
        );

        final first = await service.restore(command);
        final duplicate = await service.restore(command);

        expect(duplicate.redScore, first.redScore);
        expect(duplicate.blueScore, first.blueScore);
        final audits = await (database.select(
          database.auditLogs,
        )..where((row) => row.action.equals('restore'))).get();
        expect(audits, hasLength(1));
      },
    );

    test('rolls back restore audit and event state before retry', () async {
      final database = createTestDatabase();
      var fail = true;
      final base = MatchCommandService(database);
      final start = _startCommand('task11-restore-rollback');
      await base.start(start);
      await base.record(
        RecordMatchEventCommand(
          commandId: 'task11-restore-rollback-record',
          matchId: start.matchId,
          eventId: 'task11-restore-rollback-event',
          side: TeamSide.blue,
          points: 3,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      );
      await base.undo(
        UndoMatchEventCommand(
          commandId: 'task11-restore-rollback-undo',
          matchId: start.matchId,
          eventId: 'task11-restore-rollback-event',
        ),
      );
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (fail && point == MatchCommandFailurePoint.afterAuditWritten) {
            throw StateError('restore rollback');
          }
        },
      );
      final command = RestoreMatchEventCommand(
        commandId: 'task11-restore-rollback-command',
        matchId: start.matchId,
        eventId: 'task11-restore-rollback-event',
      );

      final failure = await _captureFailure(() => service.restore(command));

      expect(failure, isA<CommandTransactionFailure>());
      expect(
        (await database.select(database.matchEvents).getSingle()).isDeleted,
        isTrue,
      );
      expect(
        await (database.select(
          database.auditLogs,
        )..where((row) => row.action.equals('restore'))).get(),
        isEmpty,
      );
      fail = false;
      final retried = await failure.retry();
      expect(retried.blueScore, 3);
    });
  });

  group('confirmed field-goal location correction', () {
    test(
      'moves a confirmed location in a finished replay and preserves location counts',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final start = _startCommand('task11-location');
        await service.start(start);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-location-record',
            matchId: start.matchId,
            eventId: 'task11-location-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
            shotLocation: const MatchShotLocationInput(x: 0.2, y: 0.3),
          ),
        );
        await service.finish(
          FinishMatchCommand(
            commandId: 'task11-location-finish',
            matchId: start.matchId,
            endedAt: DateTime.utc(2026, 8, 22, 11),
            confirmFinalScore: true,
          ),
        );

        final corrected = await service.correctShotLocation(
          CorrectShotLocationCommand(
            commandId: 'task11-location-correct',
            matchId: start.matchId,
            eventId: 'task11-location-event',
            point: CourtPoint(x: 0.8, y: 0.7),
            auditId: 'task11-location-correct-audit',
            reason: 'Replay chart correction',
          ),
        );

        expect(corrected.redScore, 2);
        expect(corrected.locatedShotCount, 1);
        expect(corrected.shotLocations.single.point.x, 0.8);
        expect(corrected.shotLocations.single.point.y, 0.7);
        final audit = await _auditById(
          database,
          'task11-location-correct-audit',
        );
        expect(audit.action, 'edit');
        expect(audit.beforeJson, contains('0.2'));
        expect(audit.afterJson, contains('0.8'));
        expect(audit.reason, 'Replay chart correction');
      },
    );

    test(
      'rejects location correction for another match, deleted event, or unconfirmed location',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database);
        final first = _startCommand('task11-location-owner-a');
        await service.start(first);
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task11-location-owner-record',
            matchId: first.matchId,
            eventId: 'task11-location-owner-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
            shotLocation: const MatchShotLocationInput(x: 0.2, y: 0.3),
          ),
        );
        final other = _startCommand('task11-location-owner-b');
        await expectLater(
          service.correctShotLocation(
            CorrectShotLocationCommand(
              commandId: 'task11-location-owner-mismatch',
              matchId: other.matchId,
              eventId: 'task11-location-owner-event',
              point: CourtPoint(x: 0.4, y: 0.4),
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );

        await service.undo(
          UndoMatchEventCommand(
            commandId: 'task11-location-owner-undo',
            matchId: first.matchId,
            eventId: 'task11-location-owner-event',
          ),
        );
        await expectLater(
          service.correctShotLocation(
            CorrectShotLocationCommand(
              commandId: 'task11-location-owner-deleted',
              matchId: first.matchId,
              eventId: 'task11-location-owner-event',
              point: CourtPoint(x: 0.4, y: 0.4),
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );

        await service.restore(
          RestoreMatchEventCommand(
            commandId: 'task11-location-owner-restore',
            matchId: first.matchId,
            eventId: 'task11-location-owner-event',
          ),
        );

        final second = _startCommand('task11-location-unconfirmed');
        await expectLater(
          service.start(second),
          throwsA(isA<ActiveMatchConflictFailure>()),
        );
        await (database.update(database.shotLocations)..where(
              (row) => row.eventId.equals('task11-location-owner-event'),
            ))
            .write(const ShotLocationsCompanion(isConfirmed: Value(false)));
        await expectLater(
          service.correctShotLocation(
            CorrectShotLocationCommand(
              commandId: 'task11-location-owner-unconfirmed',
              matchId: first.matchId,
              eventId: 'task11-location-owner-event',
              point: CourtPoint(x: 0.4, y: 0.4),
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
      },
    );

    test(
      'returns first location correction from receipt and rolls back on failure',
      () async {
        final database = createTestDatabase();
        final base = MatchCommandService(database);
        final start = _startCommand('task11-location-receipt');
        await base.start(start);
        await base.record(
          RecordMatchEventCommand(
            commandId: 'task11-location-receipt-record',
            matchId: start.matchId,
            eventId: 'task11-location-receipt-event',
            type: EventKind.fieldGoal,
            side: TeamSide.blue,
            points: 3,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
            shotLocation: const MatchShotLocationInput(x: 0.1, y: 0.1),
          ),
        );
        final command = CorrectShotLocationCommand(
          commandId: 'task11-location-receipt-command',
          matchId: start.matchId,
          eventId: 'task11-location-receipt-event',
          point: CourtPoint(x: 0.9, y: 0.9),
        );
        final first = await base.correctShotLocation(command);
        final duplicate = await base.correctShotLocation(command);
        expect(
          duplicate.shotLocations.single.point.x,
          first.shotLocations.single.point.x,
        );
        expect(
          await (database.select(database.auditLogs)..where(
                (row) =>
                    row.targetId.equals('task11-location-receipt-event') &
                    row.action.equals('edit'),
              ))
              .get(),
          hasLength(1),
        );

        final secondCommand = CorrectShotLocationCommand(
          commandId: 'task11-location-rollback-command',
          matchId: start.matchId,
          eventId: 'task11-location-receipt-event',
          point: CourtPoint(x: 0.7, y: 0.7),
        );
        final failing = MatchCommandService(
          database,
          failureInjector: (point) {
            if (point == MatchCommandFailurePoint.afterAuditWritten) {
              throw StateError('location rollback');
            }
          },
        );
        await expectLater(
          failing.correctShotLocation(secondCommand),
          throwsA(isA<CommandTransactionFailure>()),
        );
        expect(
          (await _read(database, start.matchId)).shotLocations.single.point.x,
          0.9,
        );
      },
    );
  });
}

StartMatchCommand _startCommand(String key, {RuleTemplate? template}) {
  return StartMatchCommand(
    commandId: '$key-start',
    matchId: '$key-match',
    redName: 'Red',
    blueName: 'Blue',
    ruleTemplate:
        template ??
        const RuleTemplate(id: 'free', name: 'Free', scoreButtons: [1, 2, 3]),
    recordingMode: RecordingMode.simple,
    createdAt: DateTime.utc(2026, 8, 22, 8),
    startedAt: DateTime.utc(2026, 8, 22, 9),
  );
}

Future<AuditLog> _auditById(AppDatabase database, String id) {
  return (database.select(
    database.auditLogs,
  )..where((row) => row.id.equals(id))).getSingle();
}

Future<MatchDetail> _read(AppDatabase database, String matchId) async {
  final detail = await MatchRepository(database).getMatchDetail(matchId);
  if (detail == null) fail('Missing match projection for $matchId.');
  return detail;
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
