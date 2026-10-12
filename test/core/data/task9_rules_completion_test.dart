import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/data/repositories/rule_template_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test('rule template persistence retains the possession policy', () async {
    final database = createTestDatabase();
    final repository = RuleTemplateRepository(database);
    const template = RuleTemplate(
      id: 'policy-round-trip',
      name: 'Policy',
      scoreButtons: [1, 2, 3],
      possessionHintEnabled: true,
      possessionPolicy: PossessionPolicy.switchAfterMade,
    );
    await repository.save(template);
    final restored = await repository.getById(template.id);
    expect(restored?.possessionPolicy, PossessionPolicy.switchAfterMade);
    expect(restored?.possessionHintEnabled, isTrue);
  });

  test('rule hints expose stable keys and localized text', () {
    final hints = RuleEngine(locale: 'en').evaluate(
      template: const RuleTemplate(
        id: 'localized',
        name: 'Localized',
        scoreButtons: [1, 2, 3],
        targetScore: 1,
      ),
      score: const ScoreState(redScore: 0, blueScore: 0),
      scoringSide: TeamSide.red,
      scoringPoints: 1,
    );
    expect(hints.single.messageKey, 'targetReached');
    expect(hints.single.localizedMessage('zh'), contains('目标分数'));
    expect(hints.single.localizedMessage('en'), contains('Target score'));
  });

  test('possession hints reflect policy and omit manual suggestions', () {
    final manual = RuleEngine(locale: 'en').evaluate(
      template: const RuleTemplate(
        id: 'manual-hint',
        name: 'Manual',
        scoreButtons: [1, 2, 3],
        possessionHintEnabled: true,
        possessionPolicy: PossessionPolicy.manual,
      ),
      score: const ScoreState(redScore: 0, blueScore: 0),
      scoringSide: TeamSide.red,
      scoringPoints: 2,
    );
    expect(
      manual.where((hint) => hint.type == RuleHintType.possessionChange),
      isEmpty,
    );

    final keep = RuleEngine(locale: 'en').evaluate(
      template: const RuleTemplate(
        id: 'keep-hint',
        name: 'Keep',
        scoreButtons: [1, 2, 3],
        possessionHintEnabled: true,
        possessionPolicy: PossessionPolicy.keepAfterMade,
      ),
      score: const ScoreState(redScore: 0, blueScore: 0),
      scoringSide: TeamSide.red,
      scoringPoints: 2,
    );
    final keepHint = keep.singleWhere(
      (hint) => hint.type == RuleHintType.possessionChange,
    );
    expect(keepHint.suggestedSide, TeamSide.red);
    expect(keepHint.message, contains('Red'));
  });

  test(
    'switch-after-made suggests the other side and never infers a miss',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      final start = _start('switch', PossessionPolicy.switchAfterMade);
      await service.start(start);

      final made = await service.record(
        _fieldGoal(
          'switch-made',
          start.matchId,
          'switch-made-event',
          TeamSide.red,
        ),
      );
      expect(made.currentPossession, TeamSide.blue);
      expect(made.possessionSegments, hasLength(1));
      expect(made.possessionSegments.single.source, PossessionSource.suggested);

      final missed = await service.record(
        RecordMatchEventCommand(
          commandId: 'switch-miss',
          matchId: start.matchId,
          eventId: 'switch-miss-event',
          type: EventKind.fieldGoal,
          side: TeamSide.blue,
          points: 0,
          outcome: ShotOutcome.missed,
          occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
        ),
      );
      expect(missed.currentPossession, TeamSide.blue);
      expect(missed.possessionSegments, hasLength(1));
      expect(missed.possessionSegments.single.endedAtEventId, isNull);
    },
  );

  test(
    'command-backed scoring recovery uses durable possession segments',
    () async {
      final database = createTestDatabase();
      try {
        final service = MatchCommandService(database);
        final start = _start(
          'controller-recovery',
          PossessionPolicy.switchAfterMade,
        );
        await service.start(start);
        final projection = await service.record(
          _fieldGoal(
            'controller-recovery-made',
            start.matchId,
            'controller-recovery-event',
            TeamSide.red,
          ),
        );

        final controller = ScoringController.fromCommittedProjection(
          projection,
          service,
        );
        expect(controller.currentPossession, TeamSide.blue);
        controller.dispose();
      } finally {
        await database.close();
      }
    },
  );

  test(
    'keep-after-made retains the scorer and manual policy does not suggest',
    () async {
      final keepDatabase = createTestDatabase();
      final keepService = MatchCommandService(keepDatabase);
      final keep = _start('keep', PossessionPolicy.keepAfterMade);
      await keepService.start(keep);
      final keepProjection = await keepService.record(
        _fieldGoal('keep-made', keep.matchId, 'keep-made-event', TeamSide.red),
      );
      final repeated = await keepService.record(
        _fieldGoal(
          'keep-made-again',
          keep.matchId,
          'keep-made-again-event',
          TeamSide.red,
        ),
      );
      expect(keepProjection.currentPossession, TeamSide.red);
      expect(
        keepProjection.possessionSegments.single.source,
        PossessionSource.suggested,
      );
      expect(repeated.possessionSegments, hasLength(1));

      final manualDatabase = createTestDatabase();
      final manualService = MatchCommandService(manualDatabase);
      final manual = _start('manual', PossessionPolicy.manual);
      await manualService.start(manual);
      final manualProjection = await manualService.record(
        _fieldGoal(
          'manual-made',
          manual.matchId,
          'manual-made-event',
          TeamSide.red,
        ),
      );
      expect(manualProjection.possessionSegments, isEmpty);
      final manualPossession = await manualService.record(
        RecordMatchEventCommand(
          commandId: 'manual-possession-command',
          matchId: manual.matchId,
          eventId: 'manual-possession-event',
          type: EventKind.possession,
          side: TeamSide.blue,
          points: 0,
          note: '裁判指定',
          occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
        ),
      );
      expect(manualPossession.currentPossession, TeamSide.blue);
      expect(
        manualPossession.possessionSegments.single.source,
        PossessionSource.manual,
      );

      final repeatedManualPossession = await manualService.record(
        RecordMatchEventCommand(
          commandId: 'manual-possession-repeat-command',
          matchId: manual.matchId,
          eventId: 'manual-possession-repeat-event',
          type: EventKind.possession,
          side: TeamSide.blue,
          points: 0,
          note: '再次确认',
          occurredAt: DateTime.utc(2026, 8, 23, 10, 2),
        ),
      );
      expect(repeatedManualPossession.currentPossession, TeamSide.blue);
      expect(repeatedManualPossession.possessionSegments, hasLength(1));
      expect(
        repeatedManualPossession.possessionSegments.single.endedAtEventId,
        isNull,
      );
    },
  );

  test('a made free throw does not infer a new possession segment', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = _start(
        'free-throw-possession',
        PossessionPolicy.switchAfterMade,
      );
      await service.start(start);

      final projection = await service.record(
        RecordMatchEventCommand(
          commandId: 'free-throw-possession-event-command',
          matchId: start.matchId,
          eventId: 'free-throw-possession-event',
          type: EventKind.freeThrow,
          side: TeamSide.red,
          points: 1,
          outcome: ShotOutcome.made,
          occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
        ),
      );

      expect(projection.possessionSegments, isEmpty);
      expect(projection.currentPossession, isNull);
    });
  });

  test(
    'manual possession correction closes the suggestion and audits its reason',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      final start = _start('correction', PossessionPolicy.switchAfterMade);
      await service.start(start);
      await service.record(
        _fieldGoal(
          'correction-made',
          start.matchId,
          'correction-made-event',
          TeamSide.red,
        ),
      );

      final corrected = await service.setPossession(
        SetPossessionCommand(
          commandId: 'correction-set',
          matchId: start.matchId,
          side: TeamSide.red,
          reason: '裁判纠正',
          occurredAt: DateTime.utc(2026, 8, 23, 10, 2),
        ),
      );
      expect(corrected.currentPossession, TeamSide.red);
      expect(corrected.possessionSegments, hasLength(2));
      expect(
        corrected.possessionSegments.first.source,
        PossessionSource.suggested,
      );
      expect(
        corrected.possessionSegments.first.endedAtEventId,
        'correction-set:event',
      );
      expect(corrected.possessionSegments.last.source, PossessionSource.manual);
      expect(corrected.possessionSegments.last.reason, '裁判纠正');

      final audit = await (database.select(
        database.auditLogs,
      )..where((row) => row.action.equals('possession'))).getSingle();
      expect(audit.reason, '裁判纠正');
      expect(audit.beforeJson, contains('suggested'));
      expect(audit.afterJson, contains('manual'));
    },
  );

  test(
    'same-side manual correction is idempotent without splitting possession',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start('same-side', PossessionPolicy.manual);
        await service.start(start);
        final first = await service.setPossession(
          SetPossessionCommand(
            commandId: 'same-side-first',
            matchId: start.matchId,
            side: TeamSide.red,
            reason: '裁判指定',
            occurredAt: DateTime.utc(2026, 8, 23, 10),
          ),
        );
        final command = SetPossessionCommand(
          commandId: 'same-side-repeat',
          matchId: start.matchId,
          side: TeamSide.red,
          reason: '再次确认',
          occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
        );

        final repeated = await service.setPossession(command);
        final duplicate = await service.setPossession(command);

        expect(first.possessionSegments, hasLength(1));
        expect(repeated.possessionSegments, hasLength(1));
        expect(duplicate.possessionSegments, hasLength(1));
        expect(
          repeated.possessionSegments.single.id,
          first.possessionSegments.single.id,
        );
        expect(repeated.possessionSegments.single.endedAtEventId, isNull);
        expect(await database.select(database.matchEvents).get(), hasLength(2));
        expect(
          await (database.select(database.auditLogs)..where(
                (row) => row.id.isIn([
                  start.commandId,
                  'same-side-first',
                  'same-side-repeat',
                ]),
              ))
              .get(),
          hasLength(3),
        );
      });
    },
  );

  test(
    'correcting and undoing a manual possession rebuilds its segment',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start('manual-mutation', PossessionPolicy.manual);
        await service.start(start);
        const possessionEventId = 'manual-mutation-set:event';
        await service.setPossession(
          SetPossessionCommand(
            commandId: 'manual-mutation-set',
            matchId: start.matchId,
            side: TeamSide.red,
            reason: '裁判指定',
            occurredAt: DateTime.utc(2026, 8, 23, 10),
          ),
        );

        final corrected = await service.correct(
          CorrectMatchEventCommand(
            commandId: 'manual-mutation-edit',
            matchId: start.matchId,
            eventId: possessionEventId,
            side: TeamSide.blue,
            reason: '方向记反',
          ),
        );
        expect(corrected.currentPossession, TeamSide.blue);
        expect(corrected.possessionSegments.single.side, TeamSide.blue);

        final undone = await service.undo(
          UndoMatchEventCommand(
            commandId: 'manual-mutation-undo',
            matchId: start.matchId,
            eventId: possessionEventId,
            reason: '取消判定',
          ),
        );
        expect(undone.currentPossession, isNull);
        expect(undone.possessionSegments, isEmpty);
        expect(
          await (database.select(database.auditLogs)..where(
                (row) => row.action.isIn(['possession', 'edit', 'undo']),
              ))
              .get(),
          hasLength(3),
        );
      });
    },
  );

  test(
    'manual possession rejects a boundary earlier than the latest event',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start('possession-chronology', PossessionPolicy.manual);
        await service.start(start);
        await service.record(
          _fieldGoal(
            'possession-chronology-score',
            start.matchId,
            'possession-chronology-score-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 5),
          ),
        );

        await expectLater(
          service.setPossession(
            SetPossessionCommand(
              commandId: 'possession-chronology-set',
              matchId: start.matchId,
              side: TeamSide.blue,
              reason: '迟到的人工记录',
              occurredAt: DateTime.utc(2026, 8, 23, 10, 4),
            ),
          ),
          throwsA(isA<CommandValidationFailure>()),
        );
        expect(
          await database.select(database.possessionSegments).get(),
          isEmpty,
        );
        expect(await database.select(database.matchEvents).get(), hasLength(1));
      });
    },
  );

  test(
    'equal timestamps preserve event and possession insertion order',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start(
          'possession-stable-order',
          PossessionPolicy.switchAfterMade,
        );
        await service.start(start);
        final occurredAt = DateTime.utc(2026, 8, 23, 10, 5);
        await service.record(
          _fieldGoal(
            'possession-stable-order-red',
            start.matchId,
            'possession-stable-order-red-event',
            TeamSide.red,
            occurredAt: occurredAt,
          ),
        );
        final projection = await service.record(
          _fieldGoal(
            'possession-stable-order-blue',
            start.matchId,
            'possession-stable-order-blue-event',
            TeamSide.blue,
            occurredAt: occurredAt,
          ),
        );

        expect(projection.events.map((event) => event.id), <String>[
          'possession-stable-order-red-event',
          'possession-stable-order-blue-event',
        ]);
        expect(
          projection.possessionSegments.map(
            (segment) => segment.startedAtEventId,
          ),
          <String>[
            'possession-stable-order-red-event',
            'possession-stable-order-blue-event',
          ],
        );
        expect(projection.currentPossession, TeamSide.red);

        final undone = await service.undo(
          UndoMatchEventCommand(
            commandId: 'possession-stable-order-undo',
            matchId: start.matchId,
            eventId: 'possession-stable-order-red-event',
            reason: 'tie-order replay',
          ),
        );
        expect(undone.currentPossession, TeamSide.red);
        expect(
          undone.possessionSegments.map((segment) => segment.startedAtEventId),
          <String>['possession-stable-order-blue-event'],
        );
      });
    },
  );

  test(
    'possession replay follows durable order after out-of-order correction and undo',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start(
          'possession-durable-order',
          PossessionPolicy.switchAfterMade,
        );
        await service.start(start);

        await service.record(
          _fieldGoal(
            'possession-durable-order-a',
            start.matchId,
            'possession-durable-order-a-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
          ),
        );
        await service.record(
          _fieldGoal(
            'possession-durable-order-b',
            start.matchId,
            'possession-durable-order-b-event',
            TeamSide.blue,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 3),
          ),
        );
        await service.record(
          _fieldGoal(
            'possession-durable-order-c',
            start.matchId,
            'possession-durable-order-c-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 2),
          ),
        );

        final corrected = await service.correct(
          CorrectMatchEventCommand(
            commandId: 'possession-durable-order-correct',
            matchId: start.matchId,
            eventId: 'possession-durable-order-a-event',
            points: 0,
            outcome: ShotOutcome.missed,
            reason: 'correct earliest durable event',
          ),
        );
        expect(corrected.currentPossession, TeamSide.blue);
        expect(
          corrected.possessionSegments.map(
            (segment) => segment.startedAtEventId,
          ),
          <String>[
            'possession-durable-order-b-event',
            'possession-durable-order-c-event',
          ],
        );

        final undone = await service.undo(
          UndoMatchEventCommand(
            commandId: 'possession-durable-order-undo',
            matchId: start.matchId,
            eventId: 'possession-durable-order-a-event',
            reason: 'remove earliest durable event',
          ),
        );

        expect(
          (await (database.select(database.matchEvents)..where(
                    (event) =>
                        event.id.equals('possession-durable-order-a-event'),
                  ))
                  .getSingle())
              .isDeleted,
          isTrue,
        );
        expect(undone.currentPossession, TeamSide.blue);
        expect(
          undone.possessionSegments.map((segment) => segment.startedAtEventId),
          <String>[
            'possession-durable-order-b-event',
            'possession-durable-order-c-event',
          ],
        );
        expect(
          undone.possessionSegments.map((segment) => segment.endedAtEventId),
          <String?>['possession-durable-order-c-event', null],
        );
      });
    },
  );

  test(
    'legacy imported possession replay falls back to event row chronology',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start(
          'possession-legacy-order',
          PossessionPolicy.switchAfterMade,
        );
        await service.start(start);
        final repository = MatchRepository(database);
        for (final event in [
          MatchEvent(
            id: 'possession-legacy-order-a-event',
            matchId: start.matchId,
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
          ),
          MatchEvent(
            id: 'possession-legacy-order-b-event',
            matchId: start.matchId,
            type: EventKind.fieldGoal,
            side: TeamSide.blue,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 3),
          ),
          MatchEvent(
            id: 'possession-legacy-order-c-event',
            matchId: start.matchId,
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 2),
          ),
        ]) {
          await repository.saveEvent(event);
        }

        final undone = await service.undo(
          UndoMatchEventCommand(
            commandId: 'possession-legacy-order-undo',
            matchId: start.matchId,
            eventId: 'possession-legacy-order-a-event',
            reason: 'remove imported event',
          ),
        );

        expect(undone.currentPossession, TeamSide.blue);
        expect(
          undone.possessionSegments.map((segment) => segment.startedAtEventId),
          <String>[
            'possession-legacy-order-b-event',
            'possession-legacy-order-c-event',
          ],
        );
      });
    },
  );

  test('possession correction failure rolls back every write', () async {
    await withTestDatabase((database) async {
      final bootstrap = MatchCommandService(database);
      final start = _start('possession-rollback', PossessionPolicy.manual);
      await bootstrap.start(start);
      final before = await bootstrap.setPossession(
        SetPossessionCommand(
          commandId: 'possession-rollback-first',
          matchId: start.matchId,
          side: TeamSide.red,
          reason: '初始球权',
          occurredAt: DateTime.utc(2026, 8, 23, 10),
        ),
      );
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (point == MatchCommandFailurePoint.afterEventWritten) {
            throw StateError('possession failed');
          }
        },
      );

      await expectLater(
        service.setPossession(
          SetPossessionCommand(
            commandId: 'possession-rollback-failed',
            matchId: start.matchId,
            side: TeamSide.blue,
            reason: '裁判纠正',
            occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
          ),
        ),
        throwsA(isA<CommandTransactionFailure>()),
      );

      final segments = await database.select(database.possessionSegments).get();
      expect(segments, hasLength(1));
      expect(segments.single.id, before.possessionSegments.single.id);
      expect(segments.single.endedAtEventId, isNull);
      expect(await database.select(database.matchEvents).get(), hasLength(1));
      expect(
        await (database.select(
          database.auditLogs,
        )..where((row) => row.id.equals('possession-rollback-failed'))).get(),
        isEmpty,
      );
    });
  });

  test('finish closes open possession and clock transactionally', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    final start = _start(
      'finish',
      PossessionPolicy.keepAfterMade,
      timerEnabled: true,
    );
    await service.start(start);
    await service.record(
      _fieldGoal(
        'finish-made',
        start.matchId,
        'finish-made-event',
        TeamSide.red,
      ),
    );

    final finished = await service.finish(
      FinishMatchCommand(
        commandId: 'finish-set',
        matchId: start.matchId,
        endedAt: DateTime.utc(2026, 8, 23, 10, 3),
        confirmFinalScore: true,
      ),
    );
    expect(finished.match.lifecycle, MatchLifecycle.finished);
    expect(
      finished.possessionSegments.single.endedAtEventId,
      'finish-set:event',
    );
    expect(finished.clock?.isRunning, isFalse);
    expect(await database.select(database.activeSessions).get(), isEmpty);
  });

  test(
    'undoing a made shot recomputes valid suggestions and keeps later segments',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start(
          'undo-recalculate',
          PossessionPolicy.switchAfterMade,
        );
        await service.start(start);
        await service.record(
          _fieldGoal(
            'undo-recalculate-red',
            start.matchId,
            'undo-recalculate-red-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10),
          ),
        );
        await service.record(
          _fieldGoal(
            'undo-recalculate-blue-invalid',
            start.matchId,
            'undo-recalculate-blue-invalid-event',
            TeamSide.blue,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
          ),
        );
        await service.record(
          _fieldGoal(
            'undo-recalculate-blue-valid',
            start.matchId,
            'undo-recalculate-blue-valid-event',
            TeamSide.blue,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 2),
          ),
        );
        final before = await service.record(
          _fieldGoal(
            'undo-recalculate-red-later',
            start.matchId,
            'undo-recalculate-red-later-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 3),
          ),
        );
        expect(
          before.possessionSegments.map((segment) => segment.startedAtEventId),
          containsAll(<String>[
            'undo-recalculate-blue-invalid-event',
            'undo-recalculate-red-later-event',
          ]),
        );

        final command = UndoMatchEventCommand(
          commandId: 'undo-recalculate-undo-command',
          matchId: start.matchId,
          eventId: 'undo-recalculate-blue-invalid-event',
          reason: '误记命中',
        );
        final undone = await service.undo(command);
        final duplicate = await service.undo(command);

        expect(
          undone.events
              .singleWhere((event) => event.id == command.eventId)
              .isDeleted,
          isTrue,
        );
        expect(
          undone.possessionSegments.map((segment) => segment.startedAtEventId),
          isNot(contains(command.eventId)),
        );
        expect(
          undone.possessionSegments.map((segment) => segment.startedAtEventId),
          containsAll(<String>[
            'undo-recalculate-blue-valid-event',
            'undo-recalculate-red-later-event',
          ]),
        );
        expect(
          duplicate.possessionSegments.map(
            (segment) => segment.startedAtEventId,
          ),
          orderedEquals(
            undone.possessionSegments.map(
              (segment) => segment.startedAtEventId,
            ),
          ),
        );
        expect(
          await (database.select(database.possessionSegments)..where(
                (segment) => segment.startedAtEventId.equals(command.eventId),
              ))
              .get(),
          isEmpty,
        );
      });
    },
  );

  test(
    'correcting a made shot to miss removes its suggestion but preserves manual and later segments',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start(
          'correct-miss-recalculate',
          PossessionPolicy.switchAfterMade,
        );
        await service.start(start);
        await service.record(
          _fieldGoal(
            'correct-miss-first',
            start.matchId,
            'correct-miss-first-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10),
          ),
        );
        await service.record(
          _fieldGoal(
            'correct-miss-invalid',
            start.matchId,
            'correct-miss-invalid-event',
            TeamSide.blue,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
          ),
        );
        await service.setPossession(
          SetPossessionCommand(
            commandId: 'correct-miss-manual',
            matchId: start.matchId,
            side: TeamSide.red,
            reason: '裁判纠正',
            occurredAt: DateTime.utc(2026, 8, 23, 10, 2),
          ),
        );
        final before = await service.record(
          _fieldGoal(
            'correct-miss-later',
            start.matchId,
            'correct-miss-later-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 3),
          ),
        );
        expect(
          before.possessionSegments.map((segment) => segment.startedAtEventId),
          contains('correct-miss-invalid-event'),
        );

        final command = CorrectMatchEventCommand(
          commandId: 'correct-miss-command',
          matchId: start.matchId,
          eventId: 'correct-miss-invalid-event',
          points: 0,
          outcome: ShotOutcome.missed,
          reason: '实际未命中',
        );
        final corrected = await service.correct(command);
        final duplicate = await service.correct(command);

        expect(
          corrected.events
              .singleWhere((event) => event.id == command.eventId)
              .outcome,
          ShotOutcome.missed,
        );
        expect(
          corrected.possessionSegments.map(
            (segment) => segment.startedAtEventId,
          ),
          isNot(contains(command.eventId)),
        );
        expect(
          corrected.possessionSegments.map(
            (segment) => segment.startedAtEventId,
          ),
          contains('correct-miss-later-event'),
        );
        final manual = corrected.possessionSegments.singleWhere(
          (segment) => segment.source == PossessionSource.manual,
        );
        expect(manual.reason, '裁判纠正');
        expect(manual.endedAtEventId, 'correct-miss-later-event');
        final manualAudit = await (database.select(
          database.auditLogs,
        )..where((row) => row.action.equals('possession'))).getSingle();
        expect(manualAudit.reason, '裁判纠正');
        expect(
          duplicate.possessionSegments.map(
            (segment) => segment.startedAtEventId,
          ),
          orderedEquals(
            corrected.possessionSegments.map(
              (segment) => segment.startedAtEventId,
            ),
          ),
        );
      });
    },
  );

  test(
    'possession suggestion recalculation rolls back with event correction',
    () async {
      await withTestDatabase((database) async {
        final bootstrap = MatchCommandService(database);
        final start = _start(
          'correct-miss-rollback',
          PossessionPolicy.switchAfterMade,
        );
        await bootstrap.start(start);
        await bootstrap.record(
          _fieldGoal(
            'correct-miss-rollback-first',
            start.matchId,
            'correct-miss-rollback-first-event',
            TeamSide.red,
            occurredAt: DateTime.utc(2026, 8, 23, 10),
          ),
        );
        await bootstrap.record(
          _fieldGoal(
            'correct-miss-rollback-target',
            start.matchId,
            'correct-miss-rollback-target-event',
            TeamSide.blue,
            occurredAt: DateTime.utc(2026, 8, 23, 10, 1),
          ),
        );
        final service = MatchCommandService(
          database,
          failureInjector: (point) {
            if (point == MatchCommandFailurePoint.afterAuditWritten) {
              throw StateError('correction rollback');
            }
          },
        );

        await expectLater(
          service.correct(
            CorrectMatchEventCommand(
              commandId: 'correct-miss-rollback-edit-command',
              matchId: start.matchId,
              eventId: 'correct-miss-rollback-target-event',
              points: 0,
              outcome: ShotOutcome.missed,
              reason: '回滚测试',
            ),
          ),
          throwsA(isA<CommandTransactionFailure>()),
        );
        final restored = await MatchRepository(
          database,
        ).getMatchDetail(start.matchId);
        expect(restored, isNotNull);
        expect(
          restored!.events
              .singleWhere(
                (event) => event.id == 'correct-miss-rollback-target-event',
              )
              .outcome,
          ShotOutcome.made,
        );
        expect(
          restored.possessionSegments.map(
            (segment) => segment.startedAtEventId,
          ),
          contains('correct-miss-rollback-target-event'),
        );
        expect(
          await (database.select(database.auditLogs)..where(
                (row) => row.id.equals('correct-miss-rollback-edit-command'),
              ))
              .get(),
          isEmpty,
        );
      });
    },
  );

  test('finish compares the expected score inside its transaction', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = _start('finish-score-cas', PossessionPolicy.manual);
      await service.start(start);
      await service.record(
        _fieldGoal(
          'finish-score-cas-score',
          start.matchId,
          'finish-score-cas-score-event',
          TeamSide.red,
        ),
      );

      final stale = await _captureFailure(
        () => service.finish(
          FinishMatchCommand(
            commandId: 'finish-score-cas-stale',
            matchId: start.matchId,
            endedAt: DateTime.utc(2026, 8, 23, 10, 3),
            confirmFinalScore: true,
            expectedRedScore: 0,
            expectedBlueScore: 0,
          ),
        ),
      );
      expect(stale, isA<FinalScoreConflictFailure>());
      expect(stale.message, contains('expected 0 : 0'));
      expect(stale.message, contains('current 2 : 0'));
      expect(
        (await database.select(database.matches).getSingle()).lifecycle,
        MatchLifecycle.active.name,
      );
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );

      final finished = await service.finish(
        FinishMatchCommand(
          commandId: 'finish-score-cas-ok',
          matchId: start.matchId,
          endedAt: DateTime.utc(2026, 8, 23, 10, 4),
          confirmFinalScore: true,
          expectedRedScore: 2,
          expectedBlueScore: 0,
        ),
      );
      final duplicate = await service.finish(
        FinishMatchCommand(
          commandId: 'finish-score-cas-ok',
          matchId: start.matchId,
          endedAt: DateTime.utc(2026, 8, 23, 10, 4),
          confirmFinalScore: true,
          expectedRedScore: 2,
          expectedBlueScore: 0,
        ),
      );
      expect(finished.match.lifecycle, MatchLifecycle.finished);
      expect(duplicate.match.lifecycle, MatchLifecycle.finished);
      expect(await database.select(database.activeSessions).get(), isEmpty);
    });
  });

  test('finish requires explicit final-score confirmation', () async {
    final database = createTestDatabase();
    final service = MatchCommandService(database);
    final start = _start('finish-confirm', PossessionPolicy.manual);
    await service.start(start);
    await expectLater(
      service.finish(
        FinishMatchCommand(
          commandId: 'finish-confirm-finish',
          matchId: start.matchId,
          endedAt: DateTime.utc(2026, 8, 23, 10, 3),
        ),
      ),
      throwsA(isA<CommandValidationFailure>()),
    );
    expect(
      (await database.select(database.matches).getSingle()).lifecycle,
      MatchLifecycle.active.name,
    );
  });

  test(
    'target end condition pauses and continue remains an explicit decision',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(database);
      final start = _start(
        'decision',
        PossessionPolicy.manual,
        targetScore: 1,
        timerEnabled: true,
      );
      await service.start(start);

      final decisionProjection = await service.record(
        _fieldGoal(
          'decision-made',
          start.matchId,
          'decision-made-event',
          TeamSide.red,
        ),
      );
      expect(decisionProjection.decision, isNotNull);
      // The committed score and the durable decision marker are both replay
      // events; the marker keeps continue/finalize idempotent.
      expect(await database.select(database.matchEvents).get(), hasLength(2));
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );

      final continued = await service.continueMatch(
        ContinueMatchCommand(
          commandId: 'decision-continue',
          matchId: start.matchId,
          occurredAt: DateTime.utc(2026, 8, 23, 10, 4),
        ),
      );
      expect(continued.match.lifecycle, MatchLifecycle.active);
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );
    },
  );

  test(
    'repository recovery preserves a pending decision and foul warning',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start(
          'repository-recovery',
          PossessionPolicy.manual,
          targetScore: 2,
        );
        await service.start(start);
        await service.record(
          _fieldGoal(
            'repository-recovery-made',
            start.matchId,
            'repository-recovery-event',
            TeamSide.red,
          ),
        );

        final recovered = await MatchRepository(
          database,
        ).getMatchDetail(start.matchId);
        expect(recovered?.decision, isNotNull);
        expect(recovered?.decision?.redScore, 2);
      });
    },
  );

  test(
    'command-backed scoring state keeps the end-condition decision',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = _start(
          'controller-decision',
          PossessionPolicy.manual,
          targetScore: 2,
        );
        await service.start(start);
        final projection = await service.record(
          _fieldGoal(
            'controller-decision-made',
            start.matchId,
            'controller-decision-event',
            TeamSide.red,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          projection,
          service,
        );
        expect(controller.state.decision, isNotNull);
        expect(controller.state.decision?.redScore, 2);
      });
    },
  );

  test(
    'finish rollback preserves active session, open possession, and clock',
    () async {
      final database = createTestDatabase();
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (point == MatchCommandFailurePoint.afterLifecycleWritten) {
            throw StateError('finish failed');
          }
        },
      );
      final start = _start(
        'finish-rollback',
        PossessionPolicy.keepAfterMade,
        timerEnabled: true,
      );
      await service.start(start);
      await service.record(
        _fieldGoal(
          'finish-rollback-made',
          start.matchId,
          'finish-rollback-event',
          TeamSide.red,
        ),
      );

      await expectLater(
        service.finish(
          FinishMatchCommand(
            commandId: 'finish-rollback-finish',
            matchId: start.matchId,
            endedAt: DateTime.utc(2026, 8, 23, 10, 5),
            confirmFinalScore: true,
          ),
        ),
        throwsA(isA<CommandTransactionFailure>()),
      );
      final match = await database.select(database.matches).getSingle();
      final segment = await database
          .select(database.possessionSegments)
          .getSingle();
      expect(match.lifecycle, MatchLifecycle.active.name);
      expect(segment.endedAtEventId, isNull);
      expect(
        await database.select(database.activeSessions).get(),
        hasLength(1),
      );
      expect(await database.select(database.matchEvents).get(), hasLength(1));
    },
  );
}

StartMatchCommand _start(
  String key,
  PossessionPolicy policy, {
  bool timerEnabled = false,
  int? targetScore,
}) {
  return StartMatchCommand(
    commandId: '$key-command',
    matchId: '$key-match',
    redName: 'Red',
    blueName: 'Blue',
    ruleTemplate: RuleTemplate(
      id: key,
      name: key,
      scoreButtons: const [1, 2, 3],
      targetScore: targetScore,
      possessionHintEnabled: policy != PossessionPolicy.manual,
      possessionPolicy: policy,
    ),
    recordingMode: RecordingMode.simple,
    timerEnabled: timerEnabled,
    createdAt: DateTime.utc(2026, 8, 23),
    startedAt: DateTime.utc(2026, 8, 23),
  );
}

RecordMatchEventCommand _fieldGoal(
  String key,
  String matchId,
  String eventId,
  TeamSide side, {
  DateTime? occurredAt,
}) {
  return RecordMatchEventCommand(
    commandId: key,
    matchId: matchId,
    eventId: eventId,
    type: EventKind.fieldGoal,
    side: side,
    points: 2,
    outcome: ShotOutcome.made,
    occurredAt: occurredAt ?? DateTime.utc(2026, 8, 23, 10),
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
