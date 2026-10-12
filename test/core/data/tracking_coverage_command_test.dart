import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_lifecycle_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('archived match permits explicit coverage correction', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    await service.start(_start('archived-coverage'));
    await service.finish(
      FinishMatchCommand(
        matchId: 'archived-coverage',
        endedAt: DateTime.utc(2026, 9, 24, 11),
        confirmFinalScore: true,
      ),
    );
    await MatchLifecycleRepository(database).archive('archived-coverage');
    final result = await service.setTrackingCoverage(
      SetTrackingCoverageCommand(
        matchId: 'archived-coverage',
        trackingCoverage: TrackingCoverage.shotAttempts,
        reason: 'Every attempt was recorded.',
      ),
    );
    expect(result.match.lifecycle, MatchLifecycle.archived);
    expect(result.match.trackingCoverage, TrackingCoverage.shotAttempts);
  });

  test(
    'failed atomic finish keeps lifecycle, scope, audits and receipt unchanged',
    () async {
      final database = createTestDatabase();
      await MatchCommandService(database).start(_start('finish-rollback'));
      var fail = true;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (fail && point == MatchCommandFailurePoint.beforeCommit) {
            throw StateError('disk failure');
          }
        },
      );
      final command = FinishMatchCommand(
        commandId: 'finish-rollback-command',
        matchId: 'finish-rollback',
        endedAt: DateTime.utc(2026, 9, 24, 11),
        confirmFinalScore: true,
        trackingCoverage: TrackingCoverage.shotAttempts,
      );
      await expectLater(
        service.finish(command),
        throwsA(isA<CommandTransactionFailure>()),
      );
      final row = await database.select(database.matches).getSingle();
      expect(row.lifecycle, MatchLifecycle.active.name);
      expect(row.trackingCoverage, TrackingCoverage.scoresOnly.name);
      expect(
        (await database.select(database.auditLogs).get()).where(
          (a) => a.id.startsWith(command.commandId),
        ),
        isEmpty,
      );
      fail = false;
      expect(
        (await service.finish(command)).match.trackingCoverage,
        TrackingCoverage.shotAttempts,
      );
      expect(
        (await service.finish(command)).match.lifecycle,
        MatchLifecycle.finished,
      );
    },
  );

  test(
    'coverage correction does not consume the live scoring undo action',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final service = MatchCommandService(database);
      await service.start(_start('undo-coverage'));
      await service.record(
        RecordMatchEventCommand(
          matchId: 'undo-coverage',
          side: TeamSide.red,
          points: 2,
          occurredAt: DateTime.utc(2026, 9, 24, 10),
        ),
      );
      await service.setTrackingCoverage(
        SetTrackingCoverageCommand(
          matchId: 'undo-coverage',
          trackingCoverage: TrackingCoverage.shotAttempts,
          reason: 'all attempts recorded',
        ),
      );
      final undone = await service.undoLastScoringAction(
        UndoLastScoringActionCommand(matchId: 'undo-coverage'),
      );
      expect(undone.redScore, 0);
      expect(undone.match.trackingCoverage, TrackingCoverage.shotAttempts);
    },
  );

  for (final existing in [TrackingCoverage.locations, TrackingCoverage.full]) {
    test(
      'complete finish preserves historical ${existing.name} declaration',
      () async {
        final database = createTestDatabase();
        addTearDown(database.close);
        final service = MatchCommandService(database);
        await service.start(_start('strong-coverage'));
        await service.setTrackingCoverage(
          SetTrackingCoverageCommand(
            matchId: 'strong-coverage',
            trackingCoverage: existing,
            reason: 'historical declaration',
          ),
        );
        final finish = FinishMatchCommand(
          matchId: 'strong-coverage',
          endedAt: DateTime.utc(2026, 9, 24, 11),
          confirmFinalScore: true,
          trackingCoverage: TrackingCoverage.shotAttempts,
        );
        expect((await service.finish(finish)).match.trackingCoverage, existing);
        expect((await service.finish(finish)).match.trackingCoverage, existing);
      },
    );
  }
  test('legacy finish payload omits absent tracking coverage', () {
    final legacy = FinishMatchCommand(
      commandId: 'finish-legacy',
      matchId: 'match-legacy',
      endedAt: DateTime.utc(2026, 9, 24, 10),
      confirmFinalScore: true,
    );
    final complete = FinishMatchCommand(
      commandId: 'finish-complete',
      matchId: 'match-complete',
      endedAt: DateTime.utc(2026, 9, 24, 10),
      confirmFinalScore: true,
      trackingCoverage: TrackingCoverage.shotAttempts,
    );

    expect(legacy.payload, isNot(contains('trackingCoverage')));
    expect(complete.payload['trackingCoverage'], 'shotAttempts');
  });

  test(
    'finish commits coverage, lifecycle, audit and receipt together',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final service = MatchCommandService(database);
      await service.start(_start('finish-coverage'));

      final result = await service.finish(
        FinishMatchCommand(
          commandId: 'finish-coverage-command',
          matchId: 'finish-coverage',
          endedAt: DateTime.utc(2026, 9, 24, 11),
          confirmFinalScore: true,
          trackingCoverage: TrackingCoverage.shotAttempts,
        ),
      );

      expect(result.match.lifecycle, MatchLifecycle.finished);
      expect(result.match.trackingCoverage, TrackingCoverage.shotAttempts);
      final row = await database.select(database.matches).getSingle();
      expect(row.trackingCoverage, TrackingCoverage.shotAttempts.name);
      final audits = await database.select(database.auditLogs).get();
      final edit = audits.singleWhere(
        (entry) => entry.id == 'finish-coverage-command:coverage-audit',
      );
      expect(edit.action, 'edit');
      expect(edit.targetId, 'finish-coverage');
      expect(jsonDecode(edit.beforeJson), <String, Object?>{
        'matchId': 'finish-coverage',
        'trackingCoverage': 'scoresOnly',
      });
      expect(jsonDecode(edit.afterJson), <String, Object?>{
        'matchId': 'finish-coverage',
        'trackingCoverage': 'shotAttempts',
      });
      expect(
        audits.where((entry) => entry.id == 'finish-coverage-command'),
        hasLength(1),
      );
    },
  );

  test(
    'coverage correction is audited, idempotent and not an undo event',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      final service = MatchCommandService(database);
      await service.start(_start('correct-coverage'));
      await service.finish(
        FinishMatchCommand(
          commandId: 'finish-before-correction',
          matchId: 'correct-coverage',
          endedAt: DateTime.utc(2026, 9, 24, 11),
          confirmFinalScore: true,
          trackingCoverage: TrackingCoverage.shotAttempts,
        ),
      );
      final command = SetTrackingCoverageCommand(
        commandId: 'correct-coverage-command',
        matchId: 'correct-coverage',
        trackingCoverage: TrackingCoverage.scoresOnly,
        reason: 'A missed attempt was not recorded.',
      );

      final corrected = await service.setTrackingCoverage(command);
      final duplicate = await MatchCommandService(
        database,
      ).setTrackingCoverage(command);

      expect(corrected.match.trackingCoverage, TrackingCoverage.scoresOnly);
      expect(duplicate.match.trackingCoverage, TrackingCoverage.scoresOnly);
      expect(await database.select(database.matchEvents).get(), isEmpty);
      final audits = await database.select(database.auditLogs).get();
      final edit = audits.singleWhere(
        (entry) => entry.id == 'correct-coverage-command:audit',
      );
      expect(edit.action, 'edit');
      expect(edit.reason, 'A missed attempt was not recorded.');
      expect(
        audits.where((entry) => entry.id == 'correct-coverage-command'),
        hasLength(1),
      );
    },
  );

  test(
    'coverage correction rollback preserves the committed declaration',
    () async {
      final database = createTestDatabase();
      addTearDown(database.close);
      await MatchCommandService(database).start(_start('rollback-coverage'));
      var injectFailure = true;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (injectFailure &&
              point == MatchCommandFailurePoint.afterLifecycleWritten) {
            throw StateError('injected coverage rollback');
          }
        },
      );
      final command = SetTrackingCoverageCommand(
        commandId: 'rollback-coverage-command',
        matchId: 'rollback-coverage',
        trackingCoverage: TrackingCoverage.shotAttempts,
        reason: 'Every attempt was recorded.',
      );

      await expectLater(
        service.setTrackingCoverage(command),
        throwsA(isA<CommandTransactionFailure>()),
      );

      final row = await database.select(database.matches).getSingle();
      expect(row.trackingCoverage, TrackingCoverage.scoresOnly.name);
      final audits = await database.select(database.auditLogs).get();
      expect(
        audits.where(
          (entry) => entry.id.startsWith('rollback-coverage-command'),
        ),
        isEmpty,
      );

      injectFailure = false;
      final retried = await service.setTrackingCoverage(command);
      expect(retried.match.trackingCoverage, TrackingCoverage.shotAttempts);
    },
  );
}

StartMatchCommand _start(String matchId) {
  return StartMatchCommand(
    commandId: 'start-$matchId',
    matchId: matchId,
    redName: 'Red',
    blueName: 'Blue',
    ruleTemplate: const RuleTemplate(
      id: 'free',
      name: 'Free',
      scoreButtons: [1, 2, 3],
    ),
    recordingMode: RecordingMode.simple,
    trackingCoverage: TrackingCoverage.scoresOnly,
    startedAt: DateTime.utc(2026, 9, 24, 9),
  );
}
