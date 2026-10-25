import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart' hide ShotLocation;
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'duplicate start returns the first committed projection after later commands',
    () async {
      final database = createTestDatabase();
      final start = _startCommand('receipt-result');
      final service = MatchCommandService(database);
      final first = await service.start(start);
      await service.record(
        RecordMatchEventCommand(
          commandId: 'receipt-result-record',
          matchId: start.matchId,
          eventId: 'receipt-result-event',
          side: TeamSide.red,
          points: 2,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      );

      final duplicate = await MatchCommandService(database).start(start);

      expect(first.redScore, 0);
      expect(duplicate.redScore, 0);
      expect(duplicate.blueScore, 0);
    },
  );

  test(
    'duplicate command returns its first projection after backup restore',
    () async {
      final source = createTestDatabase();
      final start = _startCommand('receipt-restore');
      final service = MatchCommandService(source);
      final first = await service.start(start);
      await service.record(
        RecordMatchEventCommand(
          commandId: 'receipt-restore-record',
          matchId: start.matchId,
          eventId: 'receipt-restore-event',
          side: TeamSide.blue,
          points: 3,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      );
      final backup = await JsonBackupCodec(
        source,
        appVersion: '1.0.0',
      ).export();
      await source.close();
      final restored = createTestDatabase();
      await JsonBackupCodec(restored, appVersion: '1.0.0').restore(backup);

      final duplicate = await MatchCommandService(restored).start(start);

      expect(first.redScore, 0);
      expect(duplicate.redScore, 0);
      expect(duplicate.blueScore, 0);
    },
  );

  test('finish and abandon only allow active to become terminal', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    final draft = Match(
      id: 'draft-match',
      createdAt: DateTime.utc(2026, 8, 22),
      lifecycle: MatchLifecycle.draft,
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplateSnapshot: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
    );
    // The repository writes canonical participant rows for the draft fixture.
    await database.transaction(() async {
      await database
          .into(database.matches)
          .insert(
            MatchesCompanion.insert(
              id: draft.id,
              lifecycle: Value(MatchLifecycle.draft.name),
              recordingMode: Value(RecordingMode.simple.name),
              trackingCoverage: Value(TrackingCoverage.scoresOnly.name),
              ruleTemplateJson:
                  '{"id":"free","name":"Free","scoreButtons":[1,2,3]}',
              createdAt: draft.createdAt,
            ),
          );
      await database
          .into(database.matchParticipants)
          .insert(
            MatchParticipantsCompanion.insert(
              id: 'draft-red',
              matchId: draft.id,
              side: TeamSide.red.name,
              nameSnapshot: 'Red',
            ),
          );
      await database
          .into(database.matchParticipants)
          .insert(
            MatchParticipantsCompanion.insert(
              id: 'draft-blue',
              matchId: draft.id,
              side: TeamSide.blue.name,
              nameSnapshot: 'Blue',
            ),
          );
    });

    await expectLater(
      service.finish(
        FinishMatchCommand(
          commandId: 'finish-draft',
          matchId: draft.id,
          endedAt: DateTime.utc(2026, 8, 22, 11),
          confirmFinalScore: true,
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );

    final active = _startCommand('terminal-active');
    await service.start(active);
    await service.finish(
      FinishMatchCommand(
        commandId: 'finish-active',
        matchId: active.matchId,
        endedAt: DateTime.utc(2026, 8, 22, 11),
        confirmFinalScore: true,
      ),
    );
    await expectLater(
      service.finish(
        FinishMatchCommand(
          commandId: 'finish-finished-again',
          matchId: active.matchId,
          endedAt: DateTime.utc(2026, 8, 22, 12),
          confirmFinalScore: true,
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
  });

  test('pause and resume enforce alternating semantic state', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    final start = _startCommand('pause-state');
    await service.start(start);

    await expectLater(
      service.resume(
        ResumeMatchCommand(
          commandId: 'resume-before-pause',
          matchId: start.matchId,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
    await service.pause(
      PauseMatchCommand(
        commandId: 'pause-once',
        matchId: start.matchId,
        occurredAt: DateTime.utc(2026, 8, 22, 10),
      ),
    );
    await expectLater(
      service.pause(
        PauseMatchCommand(
          commandId: 'pause-twice',
          matchId: start.matchId,
          occurredAt: DateTime.utc(2026, 8, 22, 10, 1),
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
    await service.resume(
      ResumeMatchCommand(
        commandId: 'resume-once',
        matchId: start.matchId,
        occurredAt: DateTime.utc(2026, 8, 22, 10, 2),
      ),
    );
    await expectLater(
      service.resume(
        ResumeMatchCommand(
          commandId: 'resume-twice',
          matchId: start.matchId,
          occurredAt: DateTime.utc(2026, 8, 22, 10, 3),
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
  });

  test(
    'new command locations require fieldGoal and score outcomes are made only',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      final start = _startCommand('event-validation');
      await service.start(start);

      await expectLater(
        service.record(
          RecordMatchEventCommand(
            commandId: 'score-with-location',
            matchId: start.matchId,
            eventId: 'score-with-location-event',
            side: TeamSide.red,
            points: 2,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
            shotLocation: const MatchShotLocationInput(x: 0.5, y: 0.5),
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );
      await expectLater(
        service.record(
          RecordMatchEventCommand(
            commandId: 'score-with-missed-outcome',
            matchId: start.matchId,
            eventId: 'score-with-missed-outcome-event',
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.missed,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );
    },
  );

  test('correction rejects a non-made score outcome', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    final start = _startCommand('correct-outcome');
    await service.start(start);
    await service.record(
      RecordMatchEventCommand(
        commandId: 'correct-outcome-record',
        matchId: start.matchId,
        eventId: 'correct-outcome-event',
        side: TeamSide.red,
        points: 2,
        occurredAt: DateTime.utc(2026, 8, 22, 10),
      ),
    );

    await expectLater(
      service.correct(
        CorrectMatchEventCommand(
          commandId: 'correct-outcome-correction',
          matchId: start.matchId,
          eventId: 'correct-outcome-event',
          type: EventKind.score,
          outcome: ShotOutcome.missed,
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
  });

  test(
    'start command snapshots and freezes nested rule lists for stable fingerprinting',
    () {
      final scoreButtons = <int>[1, 2];
      final customEvents = <String>['foul'];
      final template = RuleTemplate(
        id: 'mutable',
        name: 'Mutable',
        scoreButtons: scoreButtons,
        customEventTypes: customEvents,
      );
      final command = StartMatchCommand(
        commandId: 'immutable-start',
        matchId: 'immutable-match',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplate: template,
        recordingMode: RecordingMode.simple,
        createdAt: DateTime.utc(2026, 8, 22, 9),
      );
      final fingerprint = command.fingerprint;
      scoreButtons.add(3);
      customEvents.add('note');

      expect(command.ruleTemplate.scoreButtons, [1, 2]);
      expect(command.ruleTemplate.customEventTypes, ['foul']);
      expect(command.fingerprint, fingerprint);
      expect(
        () => command.ruleTemplate.scoreButtons.add(4),
        throwsUnsupportedError,
      );
      expect(
        () => command.ruleTemplate.customEventTypes.add('x'),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'fieldGoal locations count as attempts and located shots in committed projection',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      final start = _startCommand('location-counter');
      await service.start(start);
      final projection = await service.record(
        RecordMatchEventCommand(
          commandId: 'location-counter-record',
          matchId: start.matchId,
          eventId: 'location-counter-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 22, 10),
          shotLocation: const MatchShotLocationInput(x: 0.5, y: 0.5),
        ),
      );

      expect(projection.shotAttemptCount, 1);
      expect(projection.locatedShotCount, 1);
    },
  );

  test(
    'failed command emits no event, receipt, or watcher projection',
    () async {
      final database = createTestDatabase();
      final start = _startCommand('watcher-rollback');
      await MatchCommandService(database).start(start);
      final events = <List<dynamic>>[];
      final subscription = MatchRepository(
        database,
      ).watchEvents(start.matchId).listen(events.add);
      addTearDown(subscription.cancel);
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (point == MatchCommandFailurePoint.afterEventWritten) {
            throw StateError('rollback watcher');
          }
        },
      );

      await expectLater(
        service.record(
          RecordMatchEventCommand(
            commandId: 'watcher-rollback-record',
            matchId: start.matchId,
            eventId: 'watcher-rollback-event',
            side: TeamSide.blue,
            points: 3,
            occurredAt: DateTime.utc(2026, 8, 22, 10),
          ),
        ),
        throwsA(isA<CommandTransactionFailure>()),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(await database.select(database.matchEvents).get(), isEmpty);
      expect(
        await (database.select(
          database.auditLogs,
        )..where((row) => row.id.equals('watcher-rollback-record'))).get(),
        isEmpty,
      );
      expect(events.where((batch) => batch.isNotEmpty), isEmpty);
    },
  );
}

StartMatchCommand _startCommand(String key) {
  return StartMatchCommand(
    commandId: '$key-command',
    matchId: '$key-match',
    redName: 'Red',
    blueName: 'Blue',
    ruleTemplate: const RuleTemplate(
      id: 'free',
      name: 'Free',
      scoreButtons: [1, 2, 3],
    ),
    recordingMode: RecordingMode.simple,
    createdAt: DateTime.utc(2026, 8, 22, 8),
    startedAt: DateTime.utc(2026, 8, 22, 9),
  );
}
