import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

final _anchor = DateTime.utc(2026, 10, 28, 10);

void main() {
  test('target undo keeps old payload stable unless explicitly requested', () {
    expect(
      UndoLastScoringActionCommand(
        matchId: 'target',
      ).payload.containsKey('undoTargetScore'),
      isFalse,
    );
    expect(
      UndoLastScoringActionCommand(
        matchId: 'target',
        undoTargetScore: true,
      ).payload['undoTargetScore'],
      isTrue,
    );
  });

  for (final injectFailure in [false, true]) {
    test(
      'target undo includes location and clock atomically failure=$injectFailure',
      () async {
        final database = createTestDatabase();
        final service = MatchCommandService(database, now: () => _anchor);
        await service.start(_start());
        await service.record(_score('winner', 3));
        await service.confirmShotLocation(
          ConfirmShotLocationCommand(
            commandId: 'location',
            matchId: 'target',
            eventId: 'winner-event',
            point: CourtPoint(x: 0.4, y: 0.6),
            requestedAtUtc: _anchor,
          ),
        );
        final command = UndoLastScoringActionCommand(
          commandId: 'target-undo',
          matchId: 'target',
          undoTargetScore: true,
        );
        if (injectFailure) {
          final failing = MatchCommandService(
            database,
            now: () => _anchor,
            failureInjector: (point) {
              if (point == MatchCommandFailurePoint.beforeCommit) {
                throw StateError('test rollback');
              }
            },
          );
          await expectLater(
            failing.undoLastScoringAction(command),
            throwsA(isA<MatchCommandFailure>()),
          );
          final unchanged = await database.select(database.matchEvents).get();
          expect(
            unchanged.singleWhere((e) => e.id == 'winner-event').isDeleted,
            isFalse,
          );
          expect(
            unchanged
                .singleWhere((e) => e.customLabel == 'decision:targetReached')
                .isDeleted,
            isFalse,
          );
          expect(
            (await database.select(database.shotLocations).getSingle())
                .isConfirmed,
            isTrue,
          );
          expect((await service.readClock('target'))?.state.isRunning, isFalse);
        }
        final result = await service.undoLastScoringAction(command);
        expect(result.redScore, 0);
        expect(result.decision, isNull);
        expect(result.shotLocations, isEmpty);
        expect(result.clock?.state.isRunning, isTrue);
        expect(
          (await database.select(database.shotLocations).getSingle())
              .isConfirmed,
          isFalse,
        );
        final duplicate = await service.undoLastScoringAction(command);
        expect(duplicate.redScore, 0);
        expect(duplicate.decision, isNull);
        expect(
          (await service.record(
            _score('new-winning-score', 3),
          )).decision?.reason,
          MatchDecisionReason.targetReached,
        );
      },
    );
  }

  test('target undo rejects when there is no active target decision', () async {
    final service = MatchCommandService(
      createTestDatabase(),
      now: () => _anchor,
    );
    await service.start(_start());
    await service.record(_score('first', 3));
    await service.continueMatch(_continue());
    await expectLater(
      service.undoLastScoringAction(
        UndoLastScoringActionCommand(matchId: 'target', undoTargetScore: true),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
  });

  test('target undo cannot skip a later imported note', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database, now: () => _anchor);
    await service.start(_start());
    await service.record(_score('first', 3));
    await database
        .into(database.matchEvents)
        .insert(
          MatchEventsCompanion.insert(
            id: 'later-note',
            matchId: 'target',
            type: EventKind.note.name,
            occurredAt: _anchor,
          ),
        );
    await expectLater(
      service.undoLastScoringAction(
        UndoLastScoringActionCommand(matchId: 'target', undoTargetScore: true),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
    expect(
      (await database.select(database.matchEvents).get())
          .singleWhere((e) => e.id == 'first-event')
          .isDeleted,
      isFalse,
    );
  });

  test(
    'target undo must match the active decision, not an older decision audit',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start(winByTwo: true));
      await service.record(_score('first', 3));
      await service.continueMatch(_continue());
      await service.record(_score('second', 1));
      await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'continue-second',
          matchId: 'target',
          occurredAt: _anchor,
        ),
      );
      // Editing the earlier score now owns the active derived pause. The latest
      // live recording still has a historical decision audit, but cannot claim it.
      final corrected = await service.correct(
        CorrectMatchEventCommand(
          commandId: 'correct-first',
          matchId: 'target',
          eventId: 'first-event',
          points: 4,
        ),
      );
      expect(corrected.redScore, 5);
      expect(corrected.decision?.reason, MatchDecisionReason.targetReached);
      await expectLater(
        service.undoLastScoringAction(
          UndoLastScoringActionCommand(
            commandId: 'wrong-target-undo',
            matchId: 'target',
            undoTargetScore: true,
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );
      final events = await database.select(database.matchEvents).get();
      expect(
        events.singleWhere((e) => e.id == 'second-event').isDeleted,
        isFalse,
      );
      expect((await service.readClock('target'))?.state.isRunning, isFalse);
    },
  );

  test(
    'backup restore retains target acknowledgement despite later semantics',
    () async {
      final backup = await withTestDatabase((database) async {
        final service = MatchCommandService(database, now: () => _anchor);
        await service.start(_start());
        await service.record(_score('first', 3));
        await service.continueMatch(_continue());
        await service.pause(
          PauseMatchCommand(
            commandId: 'pause',
            matchId: 'target',
            occurredAt: _anchor,
          ),
        );
        await service.resume(
          ResumeMatchCommand(
            commandId: 'resume',
            matchId: 'target',
            occurredAt: _anchor,
          ),
        );
        return JsonBackupCodec(
          database,
          appVersion: '2.0.0',
          now: () => _anchor,
        ).export();
      });
      final restored = createTestDatabase();
      await JsonBackupCodec(restored, appVersion: '2.0.0').restore(backup);
      final result = await MatchCommandService(
        restored,
        now: () => _anchor,
      ).record(_score('after-restore', 2));
      expect(result.redScore, 5);
      expect(result.decision, isNull);
    },
  );

  for (final points in [3, 4]) {
    test('first target decision preserves actual score $points', () async {
      final service = MatchCommandService(
        createTestDatabase(),
        now: () => _anchor,
      );
      await service.start(_start());
      final result = await service.record(_score('first', points));
      expect(result.redScore, points);
      expect(result.decision?.reason, MatchDecisionReason.targetReached);
      expect(result.clock?.state.isRunning, isFalse);
    });
  }

  test('free throw also triggers first target decision', () async {
    final service = MatchCommandService(
      createTestDatabase(),
      now: () => _anchor,
    );
    await service.start(_start());
    await service.record(_score('field', 2));
    final result = await service.record(
      RecordMatchEventCommand(
        commandId: 'free',
        matchId: 'target',
        eventId: 'free-event',
        type: EventKind.freeThrow,
        side: TeamSide.red,
        points: 1,
        outcome: ShotOutcome.made,
        occurredAt: _anchor,
      ),
    );
    expect(result.redScore, 3);
    expect(result.decision?.reason, MatchDecisionReason.targetReached);
  });

  test('continue acknowledges target for every later score and undo', () async {
    final service = MatchCommandService(
      createTestDatabase(),
      now: () => _anchor,
    );
    await service.start(_start());
    await service.record(_score('first', 3));
    await service.continueMatch(_continue());
    final second = await service.record(_score('second', 2));
    expect(second.redScore, 5);
    expect(second.decision, isNull);
    final undone = await service.undoLastScoringAction(
      UndoLastScoringActionCommand(commandId: 'undo', matchId: 'target'),
    );
    expect(undone.redScore, 3);
    expect(undone.decision, isNull);
    expect(
      undone.events
          .singleWhere((e) => e.customLabel == 'continueTarget')
          .isDeleted,
      isFalse,
    );
    expect((await service.record(_score('third', 1))).decision, isNull);
  });

  test(
    'continue survives later pause/resume and actual file database reopen',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'target-continue-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/match.sqlite');
      final database = AppDatabase(NativeDatabase(file));
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(_score('first', 3));
      await service.continueMatch(_continue());
      await service.pause(
        PauseMatchCommand(
          commandId: 'pause',
          matchId: 'target',
          occurredAt: _anchor,
        ),
      );
      await service.resume(
        ResumeMatchCommand(
          commandId: 'resume',
          matchId: 'target',
          occurredAt: _anchor,
        ),
      );
      await database.close();
      final reopened = AppDatabase(NativeDatabase(file));
      addTearDown(reopened.close);
      final result = await MatchCommandService(
        reopened,
        now: () => _anchor,
      ).record(_score('later', 1));
      expect(result.redScore, 4);
      expect(result.decision, isNull);
    },
  );

  test(
    'continued target still blocks scoring when regulation expires',
    () async {
      var now = _anchor;
      final service = MatchCommandService(createTestDatabase(), now: () => now);
      await service.start(_start(countDown: true));
      await service.record(_score('first', 3));
      await service.continueMatch(_continue());
      now = now.add(const Duration(seconds: 61));
      await expectLater(
        service.record(_score('late', 1)),
        throwsA(
          isA<EndConditionFailure>().having(
            (e) => e.decision.reason,
            'reason',
            MatchDecisionReason.regulationExpired,
          ),
        ),
      );
      await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'overtime',
          matchId: 'target',
          occurredAt: now,
        ),
      );
      expect(
        (await service.record(_score('overtime-score', 1))).decision,
        isNull,
      );
    },
  );

  test('legacy win by two still prompts after a continued target', () async {
    final service = MatchCommandService(
      createTestDatabase(),
      now: () => _anchor,
    );
    await service.start(_start(winByTwo: true));
    await service.record(_score('blue', 2, side: TeamSide.blue));
    final narrow = await service.record(_score('red', 3));
    expect(narrow.decision?.reason, MatchDecisionReason.winByTwoRequired);
    await service.continueMatch(_continue());
    final winner = await service.record(_score('winner', 1));
    expect(winner.decision?.reason, MatchDecisionReason.targetReached);
  });
}

StartMatchCommand _start({bool countDown = false, bool winByTwo = false}) =>
    StartMatchCommand(
      commandId: 'start',
      matchId: 'target',
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplate: RuleTemplate(
        id: 'target-rule',
        name: 'Target',
        scoreButtons: const [1, 2, 3],
        targetScore: 3,
        winByTwo: winByTwo,
      ),
      recordingMode: RecordingMode.simple,
      timerEnabled: true,
      clockMode: countDown ? ClockMode.countdown : ClockMode.countUp,
      regulationSeconds: countDown ? 60 : null,
      createdAt: _anchor,
      startedAt: _anchor,
    );

RecordMatchEventCommand _score(
  String id,
  int points, {
  TeamSide side = TeamSide.red,
}) => RecordMatchEventCommand(
  commandId: id,
  matchId: 'target',
  eventId: '$id-event',
  side: side,
  points: points,
  occurredAt: _anchor,
);

ContinueMatchCommand _continue() => ContinueMatchCommand(
  commandId: 'continue',
  matchId: 'target',
  occurredAt: _anchor,
);
