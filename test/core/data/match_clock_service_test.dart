import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/app_database.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/clock_state.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/core/export/backup_merge_service.dart';
import 'package:hoopito/core/export/json_backup_codec.dart';

import '../../test_helpers/test_database.dart';

final _anchor = DateTime.utc(2026, 8, 23, 10);

void main() {
  test('confirm location commands require a non-null request timestamp', () {
    final command = ConfirmShotLocationCommand(
      matchId: 'match-clock',
      eventId: 'timestamp-contract-event',
      point: CourtPoint(x: 0.4, y: 0.6),
      requestedAtUtc: _anchor,
    );
    final DateTime requestedAtUtc = command.requestedAtUtc;
    expect(requestedAtUtc, _anchor);
    expect(command.payload['requestedAtUtc'], _anchor.toIso8601String());
  });

  test('scoring undo cannot reopen a finished match', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database, now: () => _anchor);
    await service.start(_start());
    await service.record(
      _score(commandId: 'finished-score', eventId: 'finished-event'),
    );
    await service.finish(
      FinishMatchCommand(
        commandId: 'finish-for-undo',
        matchId: 'match-clock',
        endedAt: _anchor,
        confirmFinalScore: true,
        expectedRedScore: 1,
        expectedBlueScore: 0,
      ),
    );
    final failure = await _captureFailure(
      () => service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-finished-score',
          matchId: 'match-clock',
        ),
      ),
    );
    expect(failure, isA<CommandValidationFailure>());
    final projection = failure.lastCommittedProjection;
    expect(projection?.match.lifecycle, MatchLifecycle.finished);
    expect(projection?.redScore, 1);
  });

  test(
    'reconstructed command services derive the same persisted running clock',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));

      final later = _anchor.add(const Duration(seconds: 15));
      final first = await MatchCommandService(
        database,
        now: () => later,
      ).readClock('match-clock');
      final rebuilt = await MatchCommandService(
        database,
        now: () => later,
      ).readClock('match-clock');

      expect(first?.displaySeconds, 15);
      expect(rebuilt?.displaySeconds, 15);
      expect(
        (await database.select(database.matchClocks).getSingle())
            .accumulatedSeconds,
        0,
      );
    },
  );

  test(
    'running clock command receipt round-trips persisted and normalized states',
    () async {
      final database = createTestDatabase();
      final startedAt = _anchor;
      final projectedAt = _anchor.add(const Duration(seconds: 5));
      await MatchCommandService(
        database,
        now: () => startedAt,
      ).start(_start(timerEnabled: true));
      final command = RecordMatchEventCommand(
        commandId: 'clock-receipt-round-trip',
        matchId: 'match-clock',
        eventId: 'clock-receipt-event',
        side: TeamSide.red,
        points: 1,
        occurredAt: projectedAt,
      );
      final first = await MatchCommandService(
        database,
        now: () => projectedAt,
      ).record(command);
      final receipt = await (database.select(
        database.auditLogs,
      )..where((row) => row.id.equals(command.commandId))).getSingle();
      final receiptAfter =
          jsonDecode(receipt.afterJson) as Map<String, Object?>;
      final receiptClock =
          (receiptAfter['projection'] as Map<String, Object?>)['clock']
              as Map<String, Object?>;
      expect(receiptClock['state'], isA<Map>());
      expect(receiptClock['normalizedState'], isA<Map>());
      expect(
        (receiptClock['state'] as Map<String, Object?>)['accumulatedSeconds'],
        0,
      );
      expect(
        (receiptClock['normalizedState']
            as Map<String, Object?>)['accumulatedSeconds'],
        5,
      );

      final duplicate = await MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 30)),
      ).record(command);
      _expectClockProjectionEqual(first.clock!, duplicate.clock!);
    },
  );

  test(
    'restored running-clock receipt returns the original first projection',
    () async {
      late final RecordMatchEventCommand command;
      final exported = await withTestDatabase((source) async {
        final startedAt = _anchor;
        final projectedAt = _anchor.add(const Duration(seconds: 5));
        final service = MatchCommandService(source, now: () => startedAt);
        await service.start(_start(timerEnabled: true));
        command = RecordMatchEventCommand(
          commandId: 'clock-backup-receipt',
          matchId: 'match-clock',
          eventId: 'clock-backup-event',
          side: TeamSide.red,
          points: 1,
          occurredAt: projectedAt,
        );
        await MatchCommandService(
          source,
          now: () => projectedAt,
        ).record(command);
        return JsonBackupCodec(
          source,
          appVersion: '0.1.0+1',
          now: () => projectedAt,
        ).export();
      });

      final restored = createTestDatabase();
      await JsonBackupCodec(restored, appVersion: '0.1.0+1').restore(exported);
      final duplicate = await MatchCommandService(
        restored,
        now: () => _anchor.add(const Duration(seconds: 30)),
      ).record(command);
      expect(duplicate.clock, isNotNull);
      expect(duplicate.clock?.displaySeconds, 5);
      expect(duplicate.clock?.state.accumulatedSeconds, 0);
      expect(duplicate.clock?.normalizedState.accumulatedSeconds, 5);
    },
  );

  test('legacy clock receipt shape remains readable', () async {
    final database = createTestDatabase();
    final projectedAt = _anchor.add(const Duration(seconds: 5));
    await MatchCommandService(
      database,
      now: () => _anchor,
    ).start(_start(timerEnabled: true));
    final command = RecordMatchEventCommand(
      commandId: 'legacy-clock-receipt',
      matchId: 'match-clock',
      eventId: 'legacy-clock-event',
      side: TeamSide.red,
      points: 1,
      occurredAt: projectedAt,
    );
    await MatchCommandService(database, now: () => projectedAt).record(command);
    final receipt = await (database.select(
      database.auditLogs,
    )..where((row) => row.id.equals(command.commandId))).getSingle();
    final after = jsonDecode(receipt.afterJson) as Map<String, Object?>;
    final projection = after['projection'] as Map<String, Object?>;
    final clock = projection['clock'] as Map<String, Object?>;
    clock.remove('state');
    clock.remove('normalizedState');
    await database.customUpdate(
      'UPDATE audit_logs SET after_json = ? WHERE id = ?',
      variables: [
        Variable.withString(jsonEncode(after)),
        Variable.withString(command.commandId),
      ],
      updates: {database.auditLogs},
    );

    final duplicate = await MatchCommandService(
      database,
      now: () => _anchor.add(const Duration(seconds: 30)),
    ).record(command);
    expect(duplicate.clock?.displaySeconds, 5);
    expect(duplicate.clock?.phase, ClockPhase.regulation);
  });

  test(
    'nested clock receipt shape does not require duplicated top-level state fields',
    () async {
      final database = createTestDatabase();
      final projectedAt = _anchor.add(const Duration(seconds: 5));
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final command = RecordMatchEventCommand(
        commandId: 'nested-clock-receipt',
        matchId: 'match-clock',
        eventId: 'nested-clock-event',
        side: TeamSide.red,
        points: 1,
        occurredAt: projectedAt,
      );
      await MatchCommandService(
        database,
        now: () => projectedAt,
      ).record(command);
      final receipt = await (database.select(
        database.auditLogs,
      )..where((row) => row.id.equals(command.commandId))).getSingle();
      final after = jsonDecode(receipt.afterJson) as Map<String, Object?>;
      final projection = after['projection'] as Map<String, Object?>;
      final clock = projection['clock'] as Map<String, Object?>;
      for (final key in [
        'id',
        'matchId',
        'mode',
        'phase',
        'accumulatedSeconds',
        'runningSinceUtc',
        'regulationSeconds',
      ]) {
        clock.remove(key);
      }
      await database.customUpdate(
        'UPDATE audit_logs SET after_json = ? WHERE id = ?',
        variables: [
          Variable.withString(jsonEncode(after)),
          Variable.withString(command.commandId),
        ],
        updates: {database.auditLogs},
      );

      final duplicate = await MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 30)),
      ).record(command);
      expect(duplicate.clock?.state.accumulatedSeconds, 0);
      expect(duplicate.clock?.normalizedState.accumulatedSeconds, 5);
      expect(duplicate.clock?.displaySeconds, 5);
    },
  );

  test(
    'pause and resume atomically persist anchors and semantic audit rows',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final pausedAt = _anchor.add(const Duration(seconds: 9));
      final service = MatchCommandService(database, now: () => pausedAt);

      final paused = await service.pause(
        PauseMatchCommand(
          commandId: 'clock-pause',
          matchId: 'match-clock',
          occurredAt: pausedAt,
        ),
      );
      var row = await database.select(database.matchClocks).getSingle();
      expect(row.accumulatedSeconds, 9);
      expect(row.runningSinceUtc, isNull);
      expect(paused.clock?.displaySeconds, 9);

      final resumedAt = pausedAt.add(const Duration(seconds: 20));
      final resumed = await MatchCommandService(database, now: () => resumedAt)
          .resume(
            ResumeMatchCommand(
              commandId: 'clock-resume',
              matchId: 'match-clock',
              occurredAt: resumedAt,
            ),
          );
      row = await database.select(database.matchClocks).getSingle();
      expect(row.accumulatedSeconds, 9);
      expect(row.runningSinceUtc?.toUtc(), resumedAt);
      expect(resumed.clock?.displaySeconds, 9);

      final audits = await database.select(database.auditLogs).get();
      expect(audits.where((row) => row.action == 'command'), hasLength(3));
      expect(audits.where((row) => row.action == 'edit'), hasLength(2));
    },
  );

  test(
    'backward wall-clock read pauses once and returns a recovery reason',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));

      final rollback = await MatchCommandService(
        database,
        now: () => _anchor.subtract(const Duration(seconds: 2)),
      ).readClock('match-clock');
      final secondRead = await MatchCommandService(
        database,
        now: () => _anchor.subtract(const Duration(seconds: 2)),
      ).readClock('match-clock');

      expect(
        rollback?.recoveryReason,
        ClockRecoveryReason.wallClockMovedBackward,
      );
      expect(rollback?.displaySeconds, 0);
      expect(secondRead?.recoveryReason, isNull);
      expect(
        (await database.select(database.matchClocks).getSingle())
            .runningSinceUtc,
        isNull,
      );
    },
  );

  test(
    'countdown expiry pauses input and continue starts overtime without auto-finishing',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          timerEnabled: true,
          clockMode: ClockMode.countdown,
          regulationSeconds: 60,
        ),
      );

      final expired = await MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 60)),
      ).readClock('match-clock');
      expect(expired?.phase, ClockPhase.regulationExpired);
      expect(expired?.displaySeconds, 0);

      final continued =
          await MatchCommandService(
            database,
            now: () => _anchor.add(const Duration(seconds: 12)),
          ).continueMatch(
            ContinueMatchCommand(
              commandId: 'continue-ot',
              matchId: 'match-clock',
              occurredAt: _anchor.add(const Duration(seconds: 12)),
            ),
          );

      expect(continued.clock?.phase, ClockPhase.overtime);
      expect(continued.clock?.displaySeconds, 0);
      expect(continued.match.lifecycle, MatchLifecycle.active);
      expect(
        (await database.select(database.matchClocks).getSingle()).phase,
        'overtime',
      );
    },
  );

  test(
    'wall-clock rollback writes one recoverable system pause and rebuilt resume continues',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final rollbackAt = _anchor.subtract(const Duration(seconds: 2));
      final first = await MatchCommandService(
        database,
        now: () => rollbackAt,
      ).readClock('match-clock');
      final second = await MatchCommandService(
        database,
        now: () => rollbackAt,
      ).readClock('match-clock');

      expect(first?.recoveryReason, ClockRecoveryReason.wallClockMovedBackward);
      expect(second?.recoveryReason, isNull);
      final events = await database.select(database.matchEvents).get();
      expect(events, hasLength(1));
      expect(events.single.type, EventKind.pause.name);
      expect(events.single.customLabel, 'pause');
      final recoveryAudits = (await database.select(database.auditLogs).get())
          .where(
            (row) => row.action == 'edit' && row.reason == 'clock-recovery',
          )
          .toList();
      expect(recoveryAudits, hasLength(1));

      final resumedAt = _anchor.add(const Duration(seconds: 5));
      final resumed = await MatchCommandService(database, now: () => resumedAt)
          .resume(
            ResumeMatchCommand(
              commandId: 'recovery-resume',
              matchId: 'match-clock',
              occurredAt: resumedAt,
            ),
          );
      expect(resumed.clock?.runningSinceUtc, resumedAt);
      final continued = await MatchCommandService(
        database,
        now: () => resumedAt.add(const Duration(seconds: 3)),
      ).readClock('match-clock');
      expect(continued?.displaySeconds, 3);
    },
  );

  test(
    'concurrent rollback reads create one deterministic recovery event and audit',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final rollbackAt = _anchor.subtract(const Duration(seconds: 2));
      await Future.wait([
        MatchCommandService(
          database,
          now: () => rollbackAt,
        ).readClock('match-clock'),
        MatchCommandService(
          database,
          now: () => rollbackAt,
        ).readClock('match-clock'),
      ]);
      expect(
        (await database.select(database.matchEvents).get()).where(
          (event) => event.customLabel == 'pause',
        ),
        hasLength(1),
      );
      expect(
        (await database.select(database.auditLogs).get()).where(
          (row) => row.reason == 'clock-recovery',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'record at the exact countdown boundary commits expiry before rejecting input',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(database, now: () => _anchor).start(
        _start(
          timerEnabled: true,
          clockMode: ClockMode.countdown,
          regulationSeconds: 60,
        ),
      );

      final failure = await _captureFailure(
        () => MatchCommandService(
          database,
          now: () => _anchor.add(const Duration(seconds: 60)),
        ).record(_score()),
      );

      expect(failure, isA<EndConditionFailure>());
      final row = await database.select(database.matchClocks).getSingle();
      expect(row.phase, ClockPhase.regulationExpired.name);
      expect(row.runningSinceUtc, isNull);
      expect(await database.select(database.matchEvents).get(), isEmpty);
    },
  );

  test(
    'target acknowledgement is not repeated until the next score change',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'target-11',
            name: 'Target',
            scoreButtons: [1, 2, 3],
            targetScore: 11,
            winByTwo: true,
          ),
        ),
      );

      await service.record(
        RecordMatchEventCommand(
          commandId: 'blue-lead',
          matchId: 'match-clock',
          eventId: 'blue-lead-event',
          side: TeamSide.blue,
          points: 10,
          occurredAt: _anchor,
        ),
      );

      final targetCommand = _score(points: 11);
      final target = await service.record(targetCommand);
      expect(target.decision?.kind, MatchDecisionKind.finishOrContinue);
      expect(target.decision?.reason, MatchDecisionReason.winByTwoRequired);
      final targetAudits = await database.select(database.auditLogs).get();
      expect(
        targetAudits.any(
          (row) => row.action == 'edit' && row.reason == 'decision-clock',
        ),
        isTrue,
      );

      final duplicateTarget = await service.record(targetCommand);
      expect(
        duplicateTarget.decision?.reason,
        MatchDecisionReason.winByTwoRequired,
      );

      await expectLater(
        service.record(
          _score(
            commandId: 'blocked-score',
            eventId: 'blocked-event',
            points: 1,
          ),
        ),
        throwsA(isA<EndConditionFailure>()),
      );

      final continued = await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'continue-target',
          matchId: 'match-clock',
          occurredAt: _anchor,
        ),
      );
      expect(continued.decision, isNull);

      final nextScore = await service.record(
        _score(commandId: 'next-score', eventId: 'next-event', points: 1),
      );
      expect(nextScore.decision, isNotNull);
    },
  );

  test('win-by-two finishes at an exact two-point lead', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database, now: () => _anchor);
    await service.start(
      _start(
        ruleTemplate: const RuleTemplate(
          id: 'target-11-exact',
          name: 'Target',
          scoreButtons: [1, 2, 3],
          targetScore: 11,
          winByTwo: true,
        ),
      ),
    );
    await service.record(
      RecordMatchEventCommand(
        commandId: 'blue-nine',
        matchId: 'match-clock',
        eventId: 'blue-nine-event',
        side: TeamSide.blue,
        points: 9,
        occurredAt: _anchor,
      ),
    );
    final result = await service.record(_score(points: 11));

    expect(result.decision?.reason, MatchDecisionReason.targetReached);
    expect(result.decision?.canFinish, isTrue);
    expect(result.decision?.canContinue, isTrue);
  });

  test(
    'foul limit is exposed as a warning and never finishes the match',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'fouls',
            name: 'Fouls',
            scoreButtons: [1],
            foulLimit: 1,
          ),
        ),
      );

      final result = await service.record(
        RecordMatchEventCommand(
          commandId: 'foul-command',
          matchId: 'match-clock',
          eventId: 'foul-event',
          type: EventKind.foul,
          side: TeamSide.red,
          points: 0,
          occurredAt: _anchor,
        ),
      );

      expect(result.warnings, isNotEmpty);
      expect(result.match.lifecycle, MatchLifecycle.active);
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );
    },
  );

  test(
    'pause and resume transaction failures leave clock and semantic events unchanged',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final pauseFailureService = MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 5)),
        failureInjector: (point) {
          if (point == MatchCommandFailurePoint.afterEventWritten) {
            throw StateError('pause failure');
          }
        },
      );
      final pauseFailure = await _captureFailure(
        () => pauseFailureService.pause(
          PauseMatchCommand(
            commandId: 'rollback-pause',
            matchId: 'match-clock',
            occurredAt: _anchor.add(const Duration(seconds: 5)),
          ),
        ),
      );
      expect(pauseFailure, isA<CommandTransactionFailure>());
      var row = await database.select(database.matchClocks).getSingle();
      expect(row.accumulatedSeconds, 0);
      expect(row.runningSinceUtc?.toUtc(), _anchor);
      expect(await database.select(database.matchEvents).get(), isEmpty);

      await MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 5)),
      ).pause(
        PauseMatchCommand(
          commandId: 'rollback-pause-success',
          matchId: 'match-clock',
          occurredAt: _anchor.add(const Duration(seconds: 5)),
        ),
      );
      final resumeFailureService = MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 8)),
        failureInjector: (point) {
          if (point == MatchCommandFailurePoint.afterAuditWritten) {
            throw StateError('resume failure');
          }
        },
      );
      final resumeFailure = await _captureFailure(
        () => resumeFailureService.resume(
          ResumeMatchCommand(
            commandId: 'rollback-resume',
            matchId: 'match-clock',
            occurredAt: _anchor.add(const Duration(seconds: 8)),
          ),
        ),
      );
      expect(resumeFailure, isA<CommandTransactionFailure>());
      row = await database.select(database.matchClocks).getSingle();
      expect(row.accumulatedSeconds, 5);
      expect(row.runningSinceUtc, isNull);
      expect(
        (await database.select(database.matchEvents).get()).where(
          (event) => event.customLabel == 'resume',
        ),
        isEmpty,
      );

      final resumed =
          await MatchCommandService(
            database,
            now: () => _anchor.add(const Duration(seconds: 8)),
          ).resume(
            ResumeMatchCommand(
              commandId: 'rollback-resume-success',
              matchId: 'match-clock',
              occurredAt: _anchor.add(const Duration(seconds: 8)),
            ),
          );
      expect(
        resumed.clock?.runningSinceUtc,
        _anchor.add(const Duration(seconds: 8)),
      );
    },
  );

  test(
    'abandon freezes the clock and later projections cannot advance it',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      await MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 7)),
      ).abandon(
        AbandonMatchCommand(
          commandId: 'abandon-clock',
          matchId: 'match-clock',
          endedAt: _anchor.add(const Duration(seconds: 7)),
        ),
      );
      final row = await database.select(database.matchClocks).getSingle();
      expect(row.accumulatedSeconds, 7);
      expect(row.runningSinceUtc, isNull);
      expect(
        (await database.select(database.matches).getSingle()).lifecycle,
        MatchLifecycle.abandoned.name,
      );
      final later = await MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 100)),
      ).readClock('match-clock');
      expect(later?.displaySeconds, 7);
      expect(later?.isRunning, isFalse);
    },
  );

  test(
    'clock projection at its anchor is exact and does not persist a tick',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final projection = await MatchCommandService(
        database,
        now: () => _anchor,
      ).readClock('match-clock');
      expect(projection?.displaySeconds, 0);
      expect(projection?.elapsedSeconds, 0);
      final row = await database.select(database.matchClocks).getSingle();
      expect(row.accumulatedSeconds, 0);
      expect(row.runningSinceUtc?.toUtc(), _anchor);
    },
  );

  test(
    'countdown with no anchor normalizes an accumulated regulation boundary',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(database, now: () => _anchor).start(
        _start(
          timerEnabled: true,
          clockMode: ClockMode.countdown,
          regulationSeconds: 60,
        ),
      );
      await database.customUpdate(
        'UPDATE match_clocks SET accumulated_seconds = ? WHERE match_id = ?',
        variables: [Variable.withInt(60), Variable.withString('match-clock')],
        updates: {database.matchClocks},
      );
      final projection = await MatchCommandService(
        database,
        now: () => _anchor,
      ).readClock('match-clock');
      expect(projection?.phase, ClockPhase.regulationExpired);
      expect(projection?.displaySeconds, 0);
      final row = await database.select(database.matchClocks).getSingle();
      expect(row.phase, ClockPhase.regulationExpired.name);
      expect(row.accumulatedSeconds, 60);
    },
  );

  test('concurrent read and pause preserve elapsed seconds', () async {
    final database = createTestDatabase();
    await MatchCommandService(
      database,
      now: () => _anchor,
    ).start(_start(timerEnabled: true));
    final at = _anchor.add(const Duration(seconds: 6));
    await Future.wait([
      MatchCommandService(database, now: () => at).readClock('match-clock'),
      MatchCommandService(database, now: () => at).pause(
        PauseMatchCommand(
          commandId: 'concurrent-pause',
          matchId: 'match-clock',
          occurredAt: at,
        ),
      ),
    ]);
    final row = await database.select(database.matchClocks).getSingle();
    expect(row.accumulatedSeconds, 6);
    expect(row.runningSinceUtc, isNull);
    expect(
      (await database.select(database.matchEvents).get()).where(
        (event) => event.customLabel == 'pause',
      ),
      hasLength(1),
    );
  });

  test(
    'concurrent read and record preserve the score and running projection',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final at = _anchor.add(const Duration(seconds: 6));
      await Future.wait([
        MatchCommandService(database, now: () => at).readClock('match-clock'),
        MatchCommandService(database, now: () => at).record(
          _score(
            commandId: 'concurrent-score',
            eventId: 'concurrent-score-event',
          ),
        ),
      ]);
      final projection = await MatchCommandService(
        database,
        now: () => at,
      ).readClock('match-clock');
      expect(projection?.displaySeconds, 6);
      expect(
        (await database.select(database.matchEvents).get()).where(
          (event) => event.id == 'concurrent-score-event',
        ),
        hasLength(1),
      );
    },
  );

  test('manual pause and resume reject illegal repeated sequences', () async {
    final database = createTestDatabase();
    await MatchCommandService(
      database,
      now: () => _anchor,
    ).start(_start(timerEnabled: true));
    final service = MatchCommandService(database, now: () => _anchor);
    await service.pause(
      PauseMatchCommand(
        commandId: 'pause-once',
        matchId: 'match-clock',
        occurredAt: _anchor,
      ),
    );
    await expectLater(
      service.pause(
        PauseMatchCommand(
          commandId: 'pause-twice',
          matchId: 'match-clock',
          occurredAt: _anchor,
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
    await service.resume(
      ResumeMatchCommand(
        commandId: 'resume-once',
        matchId: 'match-clock',
        occurredAt: _anchor,
      ),
    );
    await expectLater(
      service.resume(
        ResumeMatchCommand(
          commandId: 'resume-twice',
          matchId: 'match-clock',
          occurredAt: _anchor,
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
  });

  test(
    'pause at a countdown boundary keeps the persisted expiry decision',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(database, now: () => _anchor).start(
        _start(
          timerEnabled: true,
          clockMode: ClockMode.countdown,
          regulationSeconds: 60,
        ),
      );
      final failure = await _captureFailure(
        () =>
            MatchCommandService(
              database,
              now: () => _anchor.add(const Duration(seconds: 60)),
            ).pause(
              PauseMatchCommand(
                commandId: 'pause-at-expiry',
                matchId: 'match-clock',
                occurredAt: _anchor.add(const Duration(seconds: 60)),
              ),
            ),
      );

      expect(failure, isA<EndConditionFailure>());
      final row = await database.select(database.matchClocks).getSingle();
      expect(row.phase, ClockPhase.regulationExpired.name);
      expect(row.runningSinceUtc, isNull);
    },
  );

  test(
    'finishing a timed match freezes its persisted clock atomically',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      await MatchCommandService(
        database,
        now: () => _anchor.add(const Duration(seconds: 5)),
      ).finish(
        FinishMatchCommand(
          commandId: 'finish-clock',
          matchId: 'match-clock',
          endedAt: _anchor.add(const Duration(seconds: 5)),
          confirmFinalScore: true,
        ),
      );

      final row = await database.select(database.matchClocks).getSingle();
      expect(row.accumulatedSeconds, 5);
      expect(row.runningSinceUtc, isNull);
      expect(row.phase, ClockPhase.regulation.name);
    },
  );

  test(
    'reconstructed pause commands remain idempotent with the same command id',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).start(_start(timerEnabled: true));
      final firstCommand = PauseMatchCommand(
        commandId: 'pause-retry',
        matchId: 'match-clock',
        occurredAt: _anchor,
      );
      await MatchCommandService(
        database,
        now: () => _anchor,
      ).pause(firstCommand);
      final duplicate = await MatchCommandService(database, now: () => _anchor)
          .pause(
            PauseMatchCommand(
              commandId: 'pause-retry',
              matchId: 'match-clock',
              occurredAt: _anchor,
            ),
          );

      expect(duplicate.clock?.displaySeconds, 0);
      expect(
        (await database.select(database.matchEvents).get()).where(
          (row) => row.customLabel == 'pause',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'win-by-two pending decision rejects finish, while an exact 12-10 lead can finish',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'target-finish-gate',
            name: 'Target',
            scoreButtons: [1, 2, 3],
            targetScore: 11,
            winByTwo: true,
          ),
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'finish-gate-blue',
          matchId: 'match-clock',
          eventId: 'finish-gate-blue-event',
          side: TeamSide.blue,
          points: 10,
          occurredAt: _anchor,
        ),
      );
      final pending = await service.record(
        _score(
          commandId: 'finish-gate-red',
          eventId: 'finish-gate-red-event',
          points: 11,
        ),
      );
      expect(pending.decision?.reason, MatchDecisionReason.winByTwoRequired);
      expect(pending.decision?.canFinish, isFalse);

      final failure = await _captureFailure(
        () => service.finish(
          FinishMatchCommand(
            commandId: 'finish-gate-too-early',
            matchId: 'match-clock',
            endedAt: _anchor,
            confirmFinalScore: true,
          ),
        ),
      );
      expect(failure, isA<EndConditionFailure>());
      expect((failure as EndConditionFailure).decision.canFinish, isFalse);
      expect(
        (await database.select(database.matches).getSingle()).lifecycle,
        MatchLifecycle.active.name,
      );

      await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'finish-gate-continue',
          matchId: 'match-clock',
          occurredAt: _anchor,
        ),
      );
      final exact = await service.record(
        _score(
          commandId: 'finish-gate-exact',
          eventId: 'finish-gate-exact-event',
        ),
      );
      expect(exact.redScore, 12);
      expect(exact.blueScore, 10);
      expect(exact.decision?.reason, MatchDecisionReason.targetReached);
      expect(exact.decision?.canFinish, isTrue);
      final finished = await service.finish(
        FinishMatchCommand(
          commandId: 'finish-gate-finish',
          matchId: 'match-clock',
          endedAt: _anchor,
          confirmFinalScore: true,
        ),
      );
      expect(finished.match.lifecycle, MatchLifecycle.finished);
    },
  );

  test(
    'pending decision remains a mutation barrier after service reconstruction',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'target-rebuild-gate',
            name: 'Target',
            scoreButtons: [1, 2, 3],
            targetScore: 11,
            winByTwo: true,
          ),
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'rebuild-blue',
          matchId: 'match-clock',
          eventId: 'rebuild-blue-event',
          side: TeamSide.blue,
          points: 10,
          occurredAt: _anchor,
        ),
      );
      await service.record(
        _score(
          commandId: 'rebuild-red',
          eventId: 'rebuild-red-event',
          points: 11,
        ),
      );

      final rebuilt = MatchCommandService(database, now: () => _anchor);
      final failure = await _captureFailure(
        () => rebuilt.record(
          _score(
            commandId: 'rebuild-blocked',
            eventId: 'rebuild-blocked-event',
          ),
        ),
      );
      expect(failure, isA<EndConditionFailure>());
      expect(
        (failure as EndConditionFailure).decision.reason,
        MatchDecisionReason.winByTwoRequired,
      );
    },
  );

  test(
    'pending decisions block correct and undo but allow committed field-goal location confirmation',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'target-mutation-gate',
            name: 'Target',
            scoreButtons: [1, 2, 3],
            targetScore: 11,
            winByTwo: true,
          ),
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'mutation-blue',
          matchId: 'match-clock',
          eventId: 'mutation-blue-event',
          side: TeamSide.blue,
          points: 10,
          occurredAt: _anchor,
        ),
      );
      await service.record(
        _score(
          commandId: 'mutation-red',
          eventId: 'mutation-red-event',
          points: 11,
        ),
      );

      final correctFailure = await _captureFailure(
        () => service.correct(
          CorrectMatchEventCommand(
            commandId: 'mutation-correct',
            matchId: 'match-clock',
            eventId: 'mutation-red-event',
            points: 10,
          ),
        ),
      );
      expect(correctFailure, isA<EndConditionFailure>());
      final undoFailure = await _captureFailure(
        () => service.undo(
          UndoMatchEventCommand(
            commandId: 'mutation-undo',
            matchId: 'match-clock',
            eventId: 'mutation-red-event',
          ),
        ),
      );
      expect(undoFailure, isA<EndConditionFailure>());
    },
  );

  test(
    'pending decision still allows committed field-goal location confirmation',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'target-location-gate',
            name: 'Target',
            scoreButtons: [1],
            targetScore: 1,
          ),
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'location-score',
          matchId: 'match-clock',
          eventId: 'location-score-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      final located = await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'location-confirm',
          matchId: 'match-clock',
          eventId: 'location-score-event',
          point: CourtPoint(x: 0.1, y: 0.2),
          requestedAtUtc: _anchor.add(const Duration(seconds: 1)),
        ),
      );
      expect(located.decision?.reason, MatchDecisionReason.targetReached);
      expect(await database.select(database.shotLocations).get(), hasLength(1));
    },
  );

  test(
    'location confirmation accepts 9.999 seconds but rejects 10 seconds',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'window-score',
          matchId: 'match-clock',
          eventId: 'window-score-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'window-confirm-in-time',
          matchId: 'match-clock',
          eventId: 'window-score-event',
          point: CourtPoint(x: 0.4, y: 0.6),
          requestedAtUtc: _anchor.add(const Duration(milliseconds: 9999)),
        ),
      );

      await service.record(
        RecordMatchEventCommand(
          commandId: 'window-score-2',
          matchId: 'match-clock',
          eventId: 'window-score-event-2',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      await expectLater(
        service.confirmShotLocation(
          ConfirmShotLocationCommand(
            commandId: 'window-confirm-at-deadline',
            matchId: 'match-clock',
            eventId: 'window-score-event-2',
            point: CourtPoint(x: 0.4, y: 0.6),
            requestedAtUtc: _anchor.add(const Duration(seconds: 10)),
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );
    },
  );

  test(
    'location confirmation rejects an older field goal after a newer score',
    () async {
      final database = createTestDatabase();
      final openedAt = _anchor;
      final newerAt = openedAt.add(const Duration(seconds: 1));
      final service = MatchCommandService(database, now: () => newerAt);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'ownership-old-score',
          matchId: 'match-clock',
          eventId: 'ownership-old-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: openedAt,
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'ownership-new-score',
          matchId: 'match-clock',
          eventId: 'ownership-new-event',
          type: EventKind.fieldGoal,
          side: TeamSide.blue,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: newerAt,
        ),
      );

      await expectLater(
        service.confirmShotLocation(
          ConfirmShotLocationCommand(
            commandId: 'ownership-old-location',
            matchId: 'match-clock',
            eventId: 'ownership-old-event',
            point: CourtPoint(x: 0.2, y: 0.3),
            requestedAtUtc: newerAt,
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );
    },
  );

  test('a free throw closes the previous supplement window', () async {
    final database = createTestDatabase();
    final openedAt = _anchor;
    final newerAt = openedAt.add(const Duration(seconds: 1));
    final service = MatchCommandService(database, now: () => newerAt);
    await service.start(_start());
    await service.record(
      RecordMatchEventCommand(
        commandId: 'ownership-free-throw-old-score',
        matchId: 'match-clock',
        eventId: 'ownership-free-throw-old-event',
        type: EventKind.fieldGoal,
        side: TeamSide.red,
        points: 2,
        outcome: ShotOutcome.made,
        occurredAt: openedAt,
      ),
    );
    await service.record(
      RecordMatchEventCommand(
        commandId: 'ownership-free-throw',
        matchId: 'match-clock',
        eventId: 'ownership-free-throw-event',
        type: EventKind.freeThrow,
        side: TeamSide.blue,
        points: 1,
        outcome: ShotOutcome.made,
        occurredAt: newerAt,
      ),
    );

    await expectLater(
      service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'ownership-free-throw-old-location',
          matchId: 'match-clock',
          eventId: 'ownership-free-throw-old-event',
          point: CourtPoint(x: 0.2, y: 0.3),
          requestedAtUtc: newerAt,
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
  });

  test(
    'undoing a target score restores decision and a running clock',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          timerEnabled: true,
          ruleTemplate: const RuleTemplate(
            id: 'undo-target',
            name: 'Target',
            scoreButtons: [1],
            targetScore: 1,
          ),
        ),
      );
      final reached = await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-target-score',
          matchId: 'match-clock',
          eventId: 'undo-target-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      expect(reached.decision, isNotNull);
      expect(reached.clock?.state.runningSinceUtc, isNull);

      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-target-action',
          matchId: 'match-clock',
        ),
      );
      expect(undone.redScore, 0);
      expect(undone.decision, isNull);
      expect(undone.clock?.state.runningSinceUtc, isNotNull);

      final continued = await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-target-retry-score',
          matchId: 'match-clock',
          eventId: 'undo-target-retry-event',
          type: EventKind.fieldGoal,
          side: TeamSide.blue,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      expect(continued.blueScore, 1);
    },
  );

  test(
    'undoing a legacy decision-clock audit without scoringEventId restores its terminal score',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          timerEnabled: true,
          ruleTemplate: const RuleTemplate(
            id: 'legacy-undo-target',
            name: 'Target',
            scoreButtons: [1],
            targetScore: 1,
          ),
        ),
      );
      final reached = await service.record(
        RecordMatchEventCommand(
          commandId: 'legacy-undo-score',
          matchId: 'match-clock',
          eventId: 'legacy-undo-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      expect(reached.decision, isNotNull);

      final decisionClock = (await database.select(database.auditLogs).get())
          .singleWhere((row) => row.reason == 'decision-clock');
      final legacyAfter =
          jsonDecode(decisionClock.afterJson) as Map<String, Object?>;
      legacyAfter.remove('scoringEventId');
      await database.customUpdate(
        'UPDATE audit_logs SET after_json = ? WHERE id = ?',
        variables: [
          Variable.withString(jsonEncode(legacyAfter)),
          Variable.withString(decisionClock.id),
        ],
        updates: {database.auditLogs},
      );

      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'legacy-undo-action',
          matchId: 'match-clock',
        ),
      );
      expect(undone.redScore, 0);
      expect(undone.decision, isNull);
      expect(undone.clock?.state.runningSinceUtc, isNotNull);
    },
  );

  test('free throws participate in scoring undo chronology', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database, now: () => _anchor);
    await service.start(_start());
    await service.record(
      RecordMatchEventCommand(
        commandId: 'undo-free-throw-score',
        matchId: 'match-clock',
        eventId: 'undo-free-throw-score-event',
        type: EventKind.fieldGoal,
        side: TeamSide.red,
        points: 2,
        outcome: ShotOutcome.made,
        occurredAt: _anchor,
      ),
    );
    final withFreeThrow = await service.record(
      RecordMatchEventCommand(
        commandId: 'undo-free-throw',
        matchId: 'match-clock',
        eventId: 'undo-free-throw-event',
        type: EventKind.freeThrow,
        side: TeamSide.red,
        points: 1,
        outcome: ShotOutcome.made,
        occurredAt: _anchor,
      ),
    );
    expect(withFreeThrow.redScore, 3);

    final undone = await service.undoLastScoringAction(
      UndoLastScoringActionCommand(
        commandId: 'undo-free-throw-action',
        matchId: 'match-clock',
      ),
    );
    expect(undone.redScore, 2);
    expect(
      undone.events
          .singleWhere((event) => event.id == 'undo-free-throw-event')
          .isDeleted,
      isTrue,
    );
  });

  test(
    'live undo follows audit chronology across every user-recorded event',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        _score(commandId: 'undo-all-score', eventId: 'undo-all-score-event'),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-all-foul',
          matchId: 'match-clock',
          eventId: 'undo-all-foul-event',
          type: EventKind.foul,
          side: TeamSide.blue,
          points: 0,
          occurredAt: _anchor,
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-all-possession',
          matchId: 'match-clock',
          eventId: 'undo-all-possession-event',
          type: EventKind.possession,
          side: TeamSide.blue,
          points: 0,
          occurredAt: _anchor,
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-all-note',
          matchId: 'match-clock',
          eventId: 'undo-all-note-event',
          type: EventKind.note,
          side: null,
          points: 0,
          note: 'Timeout adjustment',
          occurredAt: _anchor,
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-all-custom',
          matchId: 'match-clock',
          eventId: 'undo-all-custom-event',
          type: EventKind.custom,
          side: null,
          points: 0,
          customLabel: 'Lineup change',
          occurredAt: _anchor,
        ),
      );

      var projection = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-all-custom-action',
          matchId: 'match-clock',
        ),
      );
      expect(
        projection.events
            .singleWhere((event) => event.id == 'undo-all-custom-event')
            .isDeleted,
        isTrue,
      );
      expect(projection.redScore, 1);
      expect(projection.blueFouls, 1);

      projection = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-all-note-action',
          matchId: 'match-clock',
        ),
      );
      expect(
        projection.events
            .singleWhere((event) => event.id == 'undo-all-note-event')
            .isDeleted,
        isTrue,
      );

      projection = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-all-possession-action',
          matchId: 'match-clock',
        ),
      );
      expect(
        projection.events
            .singleWhere((event) => event.id == 'undo-all-possession-event')
            .isDeleted,
        isTrue,
      );
      expect(projection.currentPossession, isNull);

      projection = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-all-foul-action',
          matchId: 'match-clock',
        ),
      );
      expect(projection.blueFouls, 0);
      expect(projection.redScore, 1);

      projection = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-all-score-action',
          matchId: 'match-clock',
        ),
      );
      expect(projection.redScore, 0);
    },
  );

  test('a newer foul is undone before a supplemented shot location', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database, now: () => _anchor);
    await service.start(_start());
    await service.record(
      _score(commandId: 'undo-order-score', eventId: 'undo-order-event'),
    );
    await service.confirmShotLocation(
      ConfirmShotLocationCommand(
        commandId: 'undo-order-location',
        matchId: 'match-clock',
        eventId: 'undo-order-event',
        point: CourtPoint(x: 0.4, y: 0.6),
        requestedAtUtc: _anchor.add(const Duration(seconds: 1)),
      ),
    );
    await service.record(
      RecordMatchEventCommand(
        commandId: 'undo-order-foul',
        matchId: 'match-clock',
        eventId: 'undo-order-foul-event',
        type: EventKind.foul,
        side: TeamSide.red,
        points: 0,
        occurredAt: _anchor.add(const Duration(seconds: 2)),
      ),
    );

    final foulUndo = await service.undoLastScoringAction(
      UndoLastScoringActionCommand(
        commandId: 'undo-order-foul-action',
        matchId: 'match-clock',
      ),
    );
    expect(foulUndo.redFouls, 0);
    expect(foulUndo.redScore, 1);
    expect(foulUndo.locatedShotCount, 1);

    final locationUndo = await service.undoLastScoringAction(
      UndoLastScoringActionCommand(
        commandId: 'undo-order-location-action',
        matchId: 'match-clock',
      ),
    );
    expect(locationUndo.redScore, 1);
    expect(locationUndo.locatedShotCount, 0);
  });

  test(
    'a location supplemented after a foul is undone before that foul',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        _score(
          commandId: 'undo-reverse-order-score',
          eventId: 'undo-reverse-order-event',
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-reverse-order-foul',
          matchId: 'match-clock',
          eventId: 'undo-reverse-order-foul-event',
          type: EventKind.foul,
          side: TeamSide.blue,
          points: 0,
          occurredAt: _anchor.add(const Duration(seconds: 1)),
        ),
      );
      await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'undo-reverse-order-location',
          matchId: 'match-clock',
          eventId: 'undo-reverse-order-event',
          point: CourtPoint(x: 0.25, y: 0.75),
          requestedAtUtc: _anchor.add(const Duration(seconds: 2)),
        ),
      );

      final locationUndo = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-reverse-order-location-action',
          matchId: 'match-clock',
        ),
      );
      expect(locationUndo.locatedShotCount, 0);
      expect(locationUndo.blueFouls, 1);
      expect(locationUndo.redScore, 1);

      final foulUndo = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-reverse-order-foul-action',
          matchId: 'match-clock',
        ),
      );
      expect(foulUndo.blueFouls, 0);
      expect(foulUndo.redScore, 1);
    },
  );

  test(
    'pause semantics stay recorded while undo skips to the latest user action',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start(timerEnabled: true));
      await service.record(
        _score(commandId: 'undo-pause-score', eventId: 'undo-pause-event'),
      );
      await service.pause(
        PauseMatchCommand(
          commandId: 'undo-pause-semantic',
          matchId: 'match-clock',
          occurredAt: _anchor.add(const Duration(seconds: 2)),
        ),
      );

      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-pause-action',
          matchId: 'match-clock',
        ),
      );

      expect(undone.redScore, 0);
      expect(
        undone.events
            .singleWhere((event) => event.id == 'undo-pause-semantic:event')
            .isDeleted,
        isFalse,
      );
    },
  );

  test(
    'failed foul undo rolls back completely and the same command retries',
    () async {
      final database = createTestDatabase();
      var failUndo = false;
      var failureInjected = false;
      final service = MatchCommandService(
        database,
        now: () => _anchor,
        failureInjector: (point) {
          if (failUndo &&
              !failureInjected &&
              point == MatchCommandFailurePoint.afterEventWritten) {
            failureInjected = true;
            throw StateError('undo failed once');
          }
        },
      );
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-rollback-foul',
          matchId: 'match-clock',
          eventId: 'undo-rollback-foul-event',
          type: EventKind.foul,
          side: TeamSide.red,
          points: 0,
          occurredAt: _anchor,
        ),
      );
      failUndo = true;
      final command = UndoLastScoringActionCommand(
        commandId: 'undo-rollback-action',
        matchId: 'match-clock',
      );

      await expectLater(
        service.undoLastScoringAction(command),
        throwsA(isA<CommandTransactionFailure>()),
      );
      var foul = (await database.select(database.matchEvents).get())
          .singleWhere((event) => event.id == 'undo-rollback-foul-event');
      expect(foul.isDeleted, isFalse);
      expect(
        (await database.select(database.auditLogs).get()).where(
          (audit) =>
              audit.targetId == 'undo-rollback-foul-event' &&
              audit.action == 'undo',
        ),
        isEmpty,
      );

      final retried = await service.undoLastScoringAction(command);
      expect(retried.redFouls, 0);
      foul = (await database.select(database.matchEvents).get()).singleWhere(
        (event) => event.id == 'undo-rollback-foul-event',
      );
      expect(foul.isDeleted, isTrue);
      expect(
        (await database.select(database.auditLogs).get()).where(
          (audit) =>
              audit.targetId == 'undo-rollback-foul-event' &&
              audit.action == 'undo',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'mixed legacy event rows keep the newest row as supplement owner and undo target',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'mixed-legacy-old',
          matchId: 'match-clock',
          eventId: 'mixed-legacy-old-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'mixed-legacy-new',
          matchId: 'match-clock',
          eventId: 'mixed-legacy-new-event',
          type: EventKind.fieldGoal,
          side: TeamSide.blue,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      await (database.delete(database.auditLogs)..where(
            (row) =>
                row.targetId.equals('mixed-legacy-new-event') &
                row.action.equals('create'),
          ))
          .go();

      await expectLater(
        service.confirmShotLocation(
          ConfirmShotLocationCommand(
            commandId: 'mixed-legacy-stale-location',
            matchId: 'match-clock',
            eventId: 'mixed-legacy-old-event',
            point: CourtPoint(x: 0.2, y: 0.3),
            requestedAtUtc: _anchor.add(const Duration(seconds: 1)),
          ),
        ),
        throwsA(isA<CommandValidationFailure>()),
      );

      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'mixed-legacy-new-undo',
          matchId: 'match-clock',
        ),
      );
      expect(undone.redScore, 2);
      expect(undone.blueScore, 0);
      expect(
        undone.events
            .singleWhere((event) => event.id == 'mixed-legacy-new-event')
            .isDeleted,
        isTrue,
      );
      expect(
        undone.events
            .singleWhere((event) => event.id == 'mixed-legacy-old-event')
            .isDeleted,
        isFalse,
      );
    },
  );

  test(
    'mixed score and free-throw audit chronology undoes the free throw first',
    () async {
      final database = createTestDatabase();
      final openedAt = _anchor;
      final locationAt = openedAt.add(const Duration(seconds: 1));
      final freeThrowAt = openedAt.add(const Duration(seconds: 2));
      final service = MatchCommandService(database, now: () => openedAt);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'mixed-score',
          matchId: 'match-clock',
          eventId: 'mixed-score-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: openedAt,
        ),
      );
      await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'mixed-location',
          matchId: 'match-clock',
          eventId: 'mixed-score-event',
          point: CourtPoint(x: 0.4, y: 0.6),
          requestedAtUtc: locationAt,
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'mixed-free-throw',
          matchId: 'match-clock',
          eventId: 'mixed-free-throw-event',
          type: EventKind.freeThrow,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: freeThrowAt,
        ),
      );

      final freeThrowUndone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'mixed-free-throw-undo',
          matchId: 'match-clock',
        ),
      );
      expect(freeThrowUndone.redScore, 2);
      expect(freeThrowUndone.locatedShotCount, 1);

      final locationUndone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'mixed-location-undo',
          matchId: 'match-clock',
        ),
      );
      expect(locationUndone.redScore, 2);
      expect(locationUndone.locatedShotCount, 0);
      expect(
        (await database.select(database.shotLocations).getSingle()).isConfirmed,
        isFalse,
      );
    },
  );

  test(
    'latest scoring action undo unconfirms location before deleting score',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'undo-score',
          matchId: 'match-clock',
          eventId: 'undo-score-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'undo-location',
          matchId: 'match-clock',
          eventId: 'undo-score-event',
          point: CourtPoint(x: 0.4, y: 0.6),
          requestedAtUtc: _anchor.add(const Duration(seconds: 1)),
        ),
      );

      final locationUndo = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-location-action',
          matchId: 'match-clock',
        ),
      );
      expect(locationUndo.redScore, 2);
      expect(locationUndo.locatedShotCount, 0);
      expect(
        (await database.select(database.shotLocations).getSingle()).isConfirmed,
        isFalse,
      );

      final scoreUndo = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'undo-score-action',
          matchId: 'match-clock',
        ),
      );
      expect(scoreUndo.redScore, 0);
      expect(scoreUndo.events.single.isDeleted, isTrue);
      expect(scoreUndo.shotLocations, isEmpty);
    },
  );

  test(
    'reconfirmation updates the durable location row instead of inserting another',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'reconfirm-score',
          matchId: 'match-clock',
          eventId: 'reconfirm-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      final first = await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'reconfirm-first',
          matchId: 'match-clock',
          eventId: 'reconfirm-event',
          point: CourtPoint(x: 0.2, y: 0.3),
          requestedAtUtc: _anchor.add(const Duration(seconds: 1)),
        ),
      );
      await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'reconfirm-undo-location',
          matchId: 'match-clock',
        ),
      );
      final second = await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'reconfirm-second',
          matchId: 'match-clock',
          eventId: 'reconfirm-event',
          point: CourtPoint(x: 0.8, y: 0.7),
          requestedAtUtc: _anchor.add(const Duration(seconds: 2)),
        ),
      );
      final rows = await database.select(database.shotLocations).get();
      expect(rows, hasLength(1));
      expect(rows.single.id, first.shotLocations.single.id);
      expect(rows.single.isConfirmed, isTrue);
      expect(second.shotLocations.single.point.x, 0.8);
    },
  );

  test(
    'court-first event and location undo together as one scoring action',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      final committed = await service.record(
        RecordMatchEventCommand(
          commandId: 'atomic-score',
          matchId: 'match-clock',
          eventId: 'atomic-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 3,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
          shotLocation: MatchShotLocationInput(x: 0.3, y: 0.7),
        ),
      );
      expect(committed.shotLocations, hasLength(1));
      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'atomic-undo',
          matchId: 'match-clock',
        ),
      );
      expect(undone.redScore, 0);
      expect(undone.shotLocations, isEmpty);
      expect(
        (await database.select(database.shotLocations).getSingle()).isConfirmed,
        isFalse,
      );
    },
  );

  test(
    'score-changing corrections and undo after target continuation re-evaluate the decision',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'target-correction-recheck',
            name: 'Target',
            scoreButtons: [1, 2, 3],
            targetScore: 11,
            winByTwo: true,
          ),
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'recheck-blue',
          matchId: 'match-clock',
          eventId: 'recheck-blue-event',
          side: TeamSide.blue,
          points: 10,
          occurredAt: _anchor,
        ),
      );
      await service.record(
        _score(
          commandId: 'recheck-red',
          eventId: 'recheck-red-event',
          points: 11,
        ),
      );
      await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'recheck-continue',
          matchId: 'match-clock',
          occurredAt: _anchor,
        ),
      );

      final lowered = await service.correct(
        CorrectMatchEventCommand(
          commandId: 'recheck-lower',
          matchId: 'match-clock',
          eventId: 'recheck-red-event',
          points: 1,
        ),
      );
      expect(lowered.decision, isNull);

      final retargeted = await service.correct(
        CorrectMatchEventCommand(
          commandId: 'recheck-retarget',
          matchId: 'match-clock',
          eventId: 'recheck-red-event',
          points: 11,
        ),
      );
      expect(retargeted.decision?.reason, MatchDecisionReason.winByTwoRequired);

      await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'recheck-continue-again',
          matchId: 'match-clock',
          occurredAt: _anchor,
        ),
      );
      final undone = await service.undo(
        UndoMatchEventCommand(
          commandId: 'recheck-undo',
          matchId: 'match-clock',
          eventId: 'recheck-red-event',
        ),
      );
      expect(undone.decision, isNull);
    },
  );

  test(
    'scoring undo removes a future-timestamp terminal decision and resumes the clock',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          timerEnabled: true,
          ruleTemplate: const RuleTemplate(
            id: 'future-target',
            name: 'Target',
            scoreButtons: [1, 2, 3],
            targetScore: 1,
          ),
        ),
      );
      final future = _anchor.add(const Duration(seconds: 30));
      final scored = await service.record(
        RecordMatchEventCommand(
          commandId: 'future-terminal-score',
          matchId: 'match-clock',
          eventId: 'future-terminal-event',
          side: TeamSide.red,
          points: 1,
          occurredAt: future,
        ),
      );
      expect(scored.decision, isNotNull);

      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'future-terminal-undo',
          matchId: 'match-clock',
        ),
      );
      expect(undone.decision, isNull);
      expect(undone.clock?.state.runningSinceUtc, isNotNull);
      final continued = await service.record(
        _score(
          commandId: 'future-terminal-next',
          eventId: 'future-terminal-next-event',
        ),
      );
      expect(continued.redScore, 1);
    },
  );

  test(
    'undoing a later terminal score retains the earlier decision audit row',
    () async {
      final database = createTestDatabase();
      var now = _anchor;
      final service = MatchCommandService(database, now: () => now);
      await service.start(
        _start(
          ruleTemplate: const RuleTemplate(
            id: 'decision-history',
            name: 'Target',
            scoreButtons: [1, 2, 3],
            targetScore: 1,
          ),
        ),
      );
      await service.record(
        _score(commandId: 'decision-first', eventId: 'decision-first-event'),
      );
      final firstDecision = (await database.select(database.matchEvents).get())
          .lastWhere(
            (event) => event.customLabel?.startsWith('decision:') == true,
          );
      await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'decision-continue',
          matchId: 'match-clock',
          occurredAt: _anchor,
        ),
      );
      now = _anchor.add(const Duration(seconds: 1));
      final second = await service.record(
        RecordMatchEventCommand(
          commandId: 'decision-second',
          matchId: 'match-clock',
          eventId: 'decision-second-event',
          side: TeamSide.red,
          points: 1,
          occurredAt: _anchor.add(const Duration(seconds: 30)),
        ),
      );
      final secondDecision = second.events.lastWhere(
        (event) => event.customLabel?.startsWith('decision:') == true,
      );
      final secondDecisionClock =
          (await database.select(database.auditLogs).get()).reversed.firstWhere(
            (row) {
              if (row.reason != 'decision-clock') return false;
              final after = jsonDecode(row.afterJson) as Map<String, Object?>;
              return after['scoringEventId'] == 'decision-second-event';
            },
          );
      final legacyAfter =
          jsonDecode(secondDecisionClock.afterJson) as Map<String, Object?>;
      legacyAfter.remove('scoringEventId');
      await database.customUpdate(
        'UPDATE audit_logs SET after_json = ? WHERE id = ?',
        variables: [
          Variable.withString(jsonEncode(legacyAfter)),
          Variable.withString(secondDecisionClock.id),
        ],
        updates: {database.auditLogs},
      );
      await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'decision-second-undo',
          matchId: 'match-clock',
        ),
      );
      final rows = await database.select(database.matchEvents).get();
      expect(
        rows.singleWhere((event) => event.id == firstDecision.id).isDeleted,
        isFalse,
      );
      expect(
        rows.singleWhere((event) => event.id == secondDecision.id).isDeleted,
        isTrue,
      );
    },
  );

  test(
    'newest supplement ownership follows commit order for out-of-order timestamps',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'ownership-first',
          matchId: 'match-clock',
          eventId: 'ownership-first-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: _anchor.subtract(const Duration(seconds: 5)),
        ),
      );
      await service.record(
        RecordMatchEventCommand(
          commandId: 'ownership-second',
          matchId: 'match-clock',
          eventId: 'ownership-second-event',
          type: EventKind.fieldGoal,
          side: TeamSide.blue,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: _anchor.subtract(const Duration(seconds: 6)),
        ),
      );
      final failure = await _captureFailure(
        () => service.confirmShotLocation(
          ConfirmShotLocationCommand(
            commandId: 'ownership-stale-confirm',
            matchId: 'match-clock',
            eventId: 'ownership-first-event',
            point: CourtPoint(x: 0.2, y: 0.3),
            requestedAtUtc: _anchor.subtract(const Duration(seconds: 4)),
          ),
        ),
      );
      expect(failure, isA<CommandValidationFailure>());
    },
  );

  test(
    'confirm location rejects a future event even inside its requested window',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      final future = _anchor.add(const Duration(seconds: 5));
      await service.record(
        RecordMatchEventCommand(
          commandId: 'future-location-score',
          matchId: 'match-clock',
          eventId: 'future-location-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: future,
        ),
      );
      final failure = await _captureFailure(
        () => service.confirmShotLocation(
          ConfirmShotLocationCommand(
            commandId: 'future-location-confirm',
            matchId: 'match-clock',
            eventId: 'future-location-event',
            point: CourtPoint(x: 0.2, y: 0.3),
            requestedAtUtc: future.add(const Duration(seconds: 1)),
          ),
        ),
      );
      expect(failure, isA<CommandValidationFailure>());
    },
  );

  test(
    'location confirmation supports legacy miss and score event kinds',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'legacy-miss-record',
          matchId: 'match-clock',
          eventId: 'legacy-miss-event',
          type: EventKind.miss,
          side: TeamSide.red,
          points: 0,
          occurredAt: _anchor.subtract(const Duration(seconds: 1)),
        ),
      );
      final miss = await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'legacy-miss-locate',
          matchId: 'match-clock',
          eventId: 'legacy-miss-event',
          point: CourtPoint(x: 0.2, y: 0.3),
          requestedAtUtc: _anchor,
        ),
      );
      expect(miss.locatedShotCount, 1);

      await service.record(
        RecordMatchEventCommand(
          commandId: 'legacy-score-record',
          matchId: 'match-clock',
          eventId: 'legacy-score-event',
          type: EventKind.score,
          side: TeamSide.blue,
          points: 1,
          occurredAt: _anchor,
        ),
      );
      final score = await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'legacy-score-locate',
          matchId: 'match-clock',
          eventId: 'legacy-score-event',
          point: CourtPoint(x: 0.8, y: 0.7),
          requestedAtUtc: _anchor.add(const Duration(seconds: 1)),
        ),
      );
      expect(score.locatedShotCount, 2);
    },
  );

  test(
    'legacy locate audit without create audit undoes location then newest event',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'legacy-locate-only-score',
          matchId: 'match-clock',
          eventId: 'legacy-locate-only-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      await service.confirmShotLocation(
        ConfirmShotLocationCommand(
          commandId: 'legacy-locate-only-location',
          matchId: 'match-clock',
          eventId: 'legacy-locate-only-event',
          point: CourtPoint(x: 0.3, y: 0.7),
          requestedAtUtc: _anchor.add(const Duration(seconds: 1)),
        ),
      );
      await (database.delete(database.auditLogs)..where(
            (row) =>
                row.targetId.equals('legacy-locate-only-event') &
                row.action.equals('create'),
          ))
          .go();

      final locationUndo = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'legacy-locate-only-location-undo',
          matchId: 'match-clock',
        ),
      );
      expect(locationUndo.redScore, 2);
      expect(locationUndo.events.single.isDeleted, isFalse);
      expect(locationUndo.locatedShotCount, 0);

      final scoreUndo = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'legacy-locate-only-score-undo',
          matchId: 'match-clock',
        ),
      );
      expect(scoreUndo.redScore, 0);
      expect(scoreUndo.events.single.isDeleted, isTrue);
      expect(
        (await database.select(database.shotLocations).getSingle()).isConfirmed,
        isFalse,
      );
    },
  );

  test(
    'undoing an imported confirmed location clears it even with only non-scoring audit',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(_start());
      await service.record(
        RecordMatchEventCommand(
          commandId: 'imported-location-score',
          matchId: 'match-clock',
          eventId: 'imported-location-event',
          type: EventKind.fieldGoal,
          side: TeamSide.red,
          points: 2,
          outcome: ShotOutcome.made,
          occurredAt: _anchor,
        ),
      );
      await database
          .into(database.shotLocations)
          .insert(
            ShotLocationsCompanion.insert(
              id: 'imported-location-row',
              matchId: 'match-clock',
              eventId: 'imported-location-event',
              x: 0.2,
              y: 0.8,
              isConfirmed: const Value(true),
            ),
          );
      await database
          .into(database.auditLogs)
          .insert(
            AuditLogsCompanion.insert(
              id: 'imported-location-edit-audit',
              matchId: 'match-clock',
              targetId: 'imported-location-event',
              action: 'edit',
              beforeJson: '{}',
              afterJson: '{}',
              reason: const Value('imported'),
              createdAt: _anchor,
            ),
          );

      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(
          commandId: 'imported-location-score-undo',
          matchId: 'match-clock',
        ),
      );
      expect(undone.redScore, 0);
      final location = await database
          .select(database.shotLocations)
          .getSingle();
      expect(location.isConfirmed, isFalse);
      expect(undone.shotLocations, isEmpty);
    },
  );

  test(
    'ambiguous legacy decision adjacency rejects undo without partial mutation',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database, now: () => _anchor);
      await service.start(
        _start(
          timerEnabled: true,
          ruleTemplate: const RuleTemplate(
            id: 'ambiguous-legacy-target',
            name: 'Target',
            scoreButtons: [1],
            targetScore: 1,
          ),
        ),
      );
      final reached = await service.record(
        _score(
          commandId: 'ambiguous-legacy-score',
          eventId: 'ambiguous-legacy-event',
        ),
      );
      expect(reached.decision, isNotNull);
      final decisionClock = (await database.select(database.auditLogs).get())
          .singleWhere((row) => row.reason == 'decision-clock');
      final legacyAfter =
          jsonDecode(decisionClock.afterJson) as Map<String, Object?>;
      legacyAfter.remove('scoringEventId');
      await database.customUpdate(
        'UPDATE audit_logs SET after_json = ? WHERE id = ?',
        variables: [
          Variable.withString(jsonEncode(legacyAfter)),
          Variable.withString(decisionClock.id),
        ],
        updates: {database.auditLogs},
      );
      await (database.delete(database.auditLogs)..where(
            (row) =>
                row.targetId.equals('ambiguous-legacy-event') &
                row.action.equals('create'),
          ))
          .go();

      final failure = await _captureFailure(
        () => service.undoLastScoringAction(
          UndoLastScoringActionCommand(
            commandId: 'ambiguous-legacy-undo',
            matchId: 'match-clock',
          ),
        ),
      );
      expect(failure, isA<CommandValidationFailure>());
      final event = (await database.select(database.matchEvents).get())
          .singleWhere((row) => row.id == 'ambiguous-legacy-event');
      expect(event.isDeleted, isFalse);
      final decision = (await database.select(database.matchEvents).get())
          .singleWhere(
            (row) => row.customLabel?.startsWith('decision:') == true,
          );
      expect(decision.isDeleted, isFalse);
      final clock = await database.select(database.matchClocks).getSingle();
      expect(clock.runningSinceUtc, isNull);
    },
  );

  test(
    'backup roundtrip preserves durable order for legacy unaudited scoring rows',
    () async {
      final source = createTestDatabase();
      final sourceService = MatchCommandService(source, now: () => _anchor);
      await sourceService.start(_start());
      await sourceService.record(
        _score(commandId: 'legacy-backup-a', eventId: 'legacy-backup-a-event'),
      );
      await sourceService.record(
        _score(commandId: 'legacy-backup-b', eventId: 'legacy-backup-b-event'),
      );
      await (source.delete(source.auditLogs)..where(
            (row) =>
                row.action.equals('create') &
                row.targetId.isIn([
                  'legacy-backup-a-event',
                  'legacy-backup-b-event',
                ]),
          ))
          .go();
      final backup = await JsonBackupCodec(
        source,
        appVersion: '0.1.0+1',
        now: () => _anchor,
      ).export();

      final restored = createTestDatabase();
      await JsonBackupCodec(restored, appVersion: '0.1.0+1').restore(backup);
      final restoredEvents = await restored.select(restored.matchEvents).get();
      final scoringIds = restoredEvents
          .where(
            (row) =>
                row.type == EventKind.fieldGoal.name ||
                row.type == EventKind.score.name,
          )
          .map((row) => row.id)
          .toList();
      expect(scoringIds, ['legacy-backup-a-event', 'legacy-backup-b-event']);
      final undone = await MatchCommandService(restored, now: () => _anchor)
          .undoLastScoringAction(
            UndoLastScoringActionCommand(
              commandId: 'legacy-backup-undo',
              matchId: 'match-clock',
            ),
          );
      expect(undone.redScore, 1);
      expect(
        undone.events
            .singleWhere((event) => event.id == 'legacy-backup-b-event')
            .isDeleted,
        isTrue,
      );

      final merged = createTestDatabase();
      await BackupMergeService(merged).merge(backup);
      final mergedEvents = await merged.select(merged.matchEvents).get();
      expect(
        mergedEvents
            .where(
              (row) =>
                  row.type == EventKind.fieldGoal.name ||
                  row.type == EventKind.score.name,
            )
            .map((row) => row.id),
        ['legacy-backup-a-event', 'legacy-backup-b-event'],
      );
    },
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

void _expectClockProjectionEqual(
  ClockProjection expected,
  ClockProjection actual,
) {
  _expectClockStateEqual(expected.state, actual.state);
  _expectClockStateEqual(expected.normalizedState, actual.normalizedState);
  expect(actual.nowUtc, expected.nowUtc);
  expect(actual.elapsedSeconds, expected.elapsedSeconds);
  expect(actual.displaySeconds, expected.displaySeconds);
  expect(actual.phase, expected.phase);
  expect(actual.remainingSeconds, expected.remainingSeconds);
  expect(actual.recoveryReason, expected.recoveryReason);
  expect(actual.recoveryMessage, expected.recoveryMessage);
  expect(actual.requiresPersistence, expected.requiresPersistence);
}

void _expectClockStateEqual(ClockState expected, ClockState actual) {
  expect(actual.id, expected.id);
  expect(actual.matchId, expected.matchId);
  expect(actual.mode, expected.mode);
  expect(actual.phase, expected.phase);
  expect(actual.accumulatedSeconds, expected.accumulatedSeconds);
  expect(actual.runningSinceUtc, expected.runningSinceUtc);
  expect(actual.regulationSeconds, expected.regulationSeconds);
}

StartMatchCommand _start({
  bool timerEnabled = false,
  ClockMode clockMode = ClockMode.countUp,
  int? regulationSeconds,
  RuleTemplate ruleTemplate = const RuleTemplate(
    id: 'free',
    name: 'Free',
    scoreButtons: [1, 2, 3],
  ),
}) => StartMatchCommand(
  commandId: 'start-clock',
  matchId: 'match-clock',
  redName: 'Red',
  blueName: 'Blue',
  ruleTemplate: ruleTemplate,
  recordingMode: RecordingMode.simple,
  clockMode: clockMode,
  regulationSeconds: regulationSeconds,
  timerEnabled: timerEnabled,
  createdAt: _anchor,
  startedAt: _anchor,
);

RecordMatchEventCommand _score({
  String commandId = 'score-command',
  String eventId = 'score-event',
  int points = 1,
}) => RecordMatchEventCommand(
  commandId: commandId,
  matchId: 'match-clock',
  eventId: eventId,
  side: TeamSide.red,
  points: points,
  occurredAt: _anchor,
);
