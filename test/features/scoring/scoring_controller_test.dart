import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';
import 'package:hoopito/core/audit/audit_log_entry.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/domain/entities/match_detail.dart';
import 'package:hoopito/core/domain/entities/match_event.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/rules/rule_engine.dart';
import 'package:hoopito/core/domain/scoring/score_state.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'manual pause state only follows active pause and resume semantic events',
    () {
      MatchEvent event({
        required String id,
        required EventKind type,
        String? label,
        bool isDeleted = false,
      }) {
        return MatchEvent(
          id: id,
          matchId: 'pause-state',
          type: type,
          side: null,
          points: 0,
          occurredAt: DateTime.utc(2026, 8, 27, 12),
          customLabel: label,
          isDeleted: isDeleted,
        );
      }

      MatchScoringState state(List<MatchEvent> events) {
        return MatchScoringState(
          matchId: 'pause-state',
          redName: 'Red',
          blueName: 'Blue',
          events: events,
          score: const ScoreState.zero(),
          shotLocations: const [],
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: 'Free',
            scoreButtons: [1, 2, 3],
          ),
        );
      }

      final pause = event(id: 'pause', type: EventKind.pause, label: 'pause');
      final resume = event(
        id: 'resume',
        type: EventKind.pause,
        label: 'resume',
      );

      expect(state([pause]).isManuallyPaused, isTrue);
      expect(
        state([
          pause,
          event(id: 'foul', type: EventKind.foul, label: 'resume'),
          event(
            id: 'decision',
            type: EventKind.pause,
            label: 'decision:targetReached',
          ),
        ]).isManuallyPaused,
        isTrue,
      );
      expect(state([pause, resume]).isManuallyPaused, isFalse);
      expect(
        state([
          pause,
          event(
            id: 'deleted-resume',
            type: EventKind.pause,
            label: 'resume',
            isDeleted: true,
          ),
        ]).isManuallyPaused,
        isTrue,
      );
      expect(
        state([
          event(
            id: 'deleted-pause',
            type: EventKind.pause,
            label: 'pause',
            isDeleted: true,
          ),
          event(id: 'custom-pause', type: EventKind.custom, label: 'pause'),
        ]).isManuallyPaused,
        isFalse,
      );
    },
  );

  test('local untimed pause and resume preserve a court-first draft', () async {
    final controller = ScoringController(matchId: 'local-pause-state');
    final point = CourtPoint(x: 0.35, y: 0.65);
    expect(controller.beginOrMoveCourtFirstShot(point), isTrue);

    expect(await controller.pauseCommitted(), isTrue);
    expect(controller.isManuallyPaused, isTrue);
    expect(controller.courtFirstShotDraft?.point, point);

    expect(await controller.resumeCommitted(), isTrue);
    expect(controller.isManuallyPaused, isFalse);
    expect(controller.courtFirstShotDraft?.point, point);
    expect(controller.state.events.map((event) => event.customLabel), [
      'pause',
      'resume',
    ]);
  });

  test('retryCommand rejects a failure from another match', () async {
    final controller = ScoringController(matchId: 'current-match');
    final command = RecordMatchEventCommand(
      matchId: 'other-match',
      side: TeamSide.red,
      points: 1,
      occurredAt: DateTime.utc(2026, 8, 25, 12),
    );
    final failure = MatchCommandFailure(
      command: command,
      message: 'stale match failure',
      canRetry: true,
    );

    expect(await controller.retryCommand(failure), isFalse);
    expect(controller.state.events, isEmpty);
  });

  test('local score opens a supplement window without blocking actions', () {
    final now = DateTime.utc(2026, 8, 25, 12);
    final controller = ScoringController(matchId: 'match-1', nowUtc: () => now);

    controller.addScore(side: TeamSide.red, points: 2);

    expect(controller.state.score.redScore, 2);
    expect(controller.state.blueFouls, 0);
    expect(controller.state.pendingLocation, isNull);
    expect(
      controller.state.locationSupplementWindow?.eventId,
      'match-1-event-1',
    );
    expect(controller.state.locationSupplementWindow?.openedAtUtc, now);
  });

  test(
    'local court-first receipt reports the committed event and location',
    () async {
      final controller = ScoringController(
        matchId: 'receipt-local-court',
        nowUtc: () => DateTime.utc(2026, 8, 25, 12),
      );
      final point = CourtPoint(x: 0.2, y: 0.8);
      expect(
        controller.beginOrMoveCourtFirstShot(point, side: TeamSide.red),
        isTrue,
      );
      controller.updateCourtFirstShot(points: 2);

      final receipt = await controller.commitCourtFirstShotWithReceipt();

      expect(receipt, isNotNull);
      expect(receipt!.source, ShotLocationCommitSource.courtFirst);
      expect(receipt.eventId, controller.state.events.single.id);
      expect(
        receipt.actualShotLocationId,
        controller.state.shotLocations.single.id,
      );
      expect(receipt.side, TeamSide.red);
      expect(receipt.points, 2);
      expect(receipt.point.x, point.x);
      expect(receipt.point.y, point.y);
    },
  );

  test(
    'command-backed supplement receipt uses the confirmed projection location id',
    () async {
      await withTestDatabase((database) async {
        final now = DateTime.utc(2026, 8, 25, 12);
        final service = MatchCommandService(database, now: () => now);
        final started = await service.start(
          _startCommand(matchId: 'receipt-supplement'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
          nowUtc: () => now,
        );
        expect(
          await controller.recordScoreCommitted(side: TeamSide.blue, points: 3),
          isTrue,
        );
        final eventId = controller.state.events.single.id;
        final command = ConfirmShotLocationCommand(
          commandId: 'receipt-existing-location',
          matchId: started.match.id,
          eventId: eventId,
          point: CourtPoint(x: 0.1, y: 0.1),
          requestedAtUtc: now,
          shotLocationId: 'receipt-existing-location-shot',
        );
        // Seed an unconfirmed row through the real command kernel's undo path.
        final firstProjection = await service.confirmShotLocation(command);
        expect(firstProjection.shotLocations.single.isConfirmed, isTrue);
        final undone = await service.undoLastScoringAction(
          UndoLastScoringActionCommand(
            commandId: 'receipt-existing-location-undo',
            matchId: started.match.id,
          ),
        );
        final durableLocation = await (database.select(
          database.shotLocations,
        )..where((row) => row.eventId.equals(eventId))).getSingle();
        expect(durableLocation.id, 'receipt-existing-location-shot');
        expect(durableLocation.isConfirmed, isFalse);
        controller.replaceCommittedProjection(undone);
        final receipt = await controller.attachSupplementLocationWithReceipt(
          CourtPoint(x: 0.9, y: 0.7),
          requestedAtUtc: now,
        );

        expect(receipt, isNotNull);
        expect(receipt!.source, ShotLocationCommitSource.supplement);
        expect(receipt.eventId, eventId);
        expect(receipt.actualShotLocationId, 'receipt-existing-location-shot');
        expect(receipt.side, TeamSide.blue);
        expect(receipt.points, 3);
        expect(receipt.point.x, 0.9);
        expect(receipt.point.y, 0.7);
      });
    },
  );

  test(
    'command-backed court-first receipt matches durable event and location rows',
    () async {
      await withTestDatabase((database) async {
        final now = DateTime.utc(2026, 8, 25, 12);
        final service = MatchCommandService(database, now: () => now);
        final started = await service.start(
          _startCommand(matchId: 'receipt-durable-court'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
          nowUtc: () => now,
        );
        final point = CourtPoint(x: 0.35, y: 0.65);
        expect(
          controller.beginOrMoveCourtFirstShot(point, side: TeamSide.blue),
          isTrue,
        );
        controller.updateCourtFirstShot(points: 3);

        final receipt = await controller.commitCourtFirstShotWithReceipt();

        expect(receipt, isNotNull);
        expect(receipt!.source, ShotLocationCommitSource.courtFirst);
        expect(receipt.side, TeamSide.blue);
        expect(receipt.points, 3);
        expect(receipt.point.x, point.x);
        expect(receipt.point.y, point.y);
        final event = await (database.select(
          database.matchEvents,
        )..where((row) => row.id.equals(receipt.eventId))).getSingle();
        final location = await (database.select(
          database.shotLocations,
        )..where((row) => row.id.equals(receipt.shotLocationId))).getSingle();
        expect(event.side, TeamSide.blue.name);
        expect(event.points, 3);
        expect(location.eventId, receipt.eventId);
        expect(location.isConfirmed, isTrue);
        expect(location.x, point.x);
        expect(location.y, point.y);
        final commandRows = await (database.select(
          database.auditLogs,
        )..where((row) => row.action.equals(AuditAction.command.name))).get();
        final recordCommand = commandRows.last;
        final before = jsonDecode(recordCommand.beforeJson) as Map;
        expect(before['commandType'], 'record');
        expect(before['commandId'], recordCommand.id);
      });
    },
  );

  test(
    'receipt methods return null for invalid paths without changing state',
    () async {
      final controller = ScoringController(matchId: 'receipt-invalid');

      expect(await controller.commitCourtFirstShotWithReceipt(), isNull);
      expect(
        await controller.attachSupplementLocationWithReceipt(
          CourtPoint(x: 0.2, y: 0.8),
        ),
        isNull,
      );
      expect(controller.state.events, isEmpty);
      expect(controller.state.shotLocations, isEmpty);
    },
  );

  test(
    'receipt transaction failures throw and preserve court-first draft',
    () async {
      await withTestDatabase((database) async {
        var armed = false;
        var beforeCommitCalls = 0;
        final service = MatchCommandService(
          database,
          failureInjector: (point) {
            if (armed && point == MatchCommandFailurePoint.beforeCommit) {
              beforeCommitCalls++;
              throw StateError('receipt court-first failure');
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'receipt-failure-court'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );
        expect(
          controller.beginOrMoveCourtFirstShot(
            CourtPoint(x: 0.25, y: 0.75),
            side: TeamSide.red,
          ),
          isTrue,
        );
        armed = true;

        await expectLater(
          controller.commitCourtFirstShotWithReceipt(),
          throwsA(isA<MatchCommandFailure>()),
        );
        expect(beforeCommitCalls, 1);
        expect(controller.state.courtFirstShotDraft, isNotNull);
        expect(controller.state.events, isEmpty);
        expect(controller.state.shotLocations, isEmpty);
        expect(await database.select(database.matchEvents).get(), isEmpty);
        expect(await database.select(database.shotLocations).get(), isEmpty);
      });
    },
  );

  test(
    'receipt transaction failures throw and preserve supplement window',
    () async {
      await withTestDatabase((database) async {
        final now = DateTime.utc(2026, 8, 25, 12);
        var armed = false;
        var beforeCommitCalls = 0;
        final service = MatchCommandService(
          database,
          now: () => now,
          failureInjector: (point) {
            if (armed && point == MatchCommandFailurePoint.beforeCommit) {
              beforeCommitCalls++;
              throw StateError('receipt supplement failure');
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'receipt-failure-supplement'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
          nowUtc: () => now,
        );
        expect(
          await controller.recordScoreCommitted(side: TeamSide.red, points: 2),
          isTrue,
        );
        final windowEventId =
            controller.state.locationSupplementWindow!.eventId;
        armed = true;

        await expectLater(
          controller.attachSupplementLocationWithReceipt(
            CourtPoint(x: 0.75, y: 0.25),
            requestedAtUtc: now,
          ),
          throwsA(isA<MatchCommandFailure>()),
        );
        expect(beforeCommitCalls, 1);
        expect(
          controller.state.locationSupplementWindow!.eventId,
          windowEventId,
        );
        expect(controller.state.shotLocations, isEmpty);
        expect(await database.select(database.shotLocations).get(), isEmpty);
      });
    },
  );

  test('receipt methods return null after disposal while in flight', () async {
    await withTestDatabase((database) async {
      final now = DateTime.utc(2026, 8, 25, 12);
      final entered = Completer<void>();
      final release = Completer<void>();
      var armed = false;
      final service = MatchCommandService(
        database,
        now: () => now,
        failureInjector: (point) async {
          if (armed && point == MatchCommandFailurePoint.beforeCommit) {
            entered.complete();
            await release.future;
          }
        },
      );
      final started = await service.start(
        _startCommand(matchId: 'receipt-dispose'),
      );
      armed = true;
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );
      expect(
        controller.beginOrMoveCourtFirstShot(
          CourtPoint(x: 0.4, y: 0.6),
          side: TeamSide.blue,
        ),
        isTrue,
      );
      final operation = controller.commitCourtFirstShotWithReceipt();
      await entered.future;
      controller.dispose();
      release.complete();

      expect(await operation, isNull);
      expect(
        await (database.select(
          database.matchEvents,
        )..where((row) => row.matchId.equals(started.match.id))).get(),
        hasLength(1),
      );
    });
  });

  test(
    'supplement receipt returns null after disposal while in flight',
    () async {
      await withTestDatabase((database) async {
        final now = DateTime.utc(2026, 8, 25, 12);
        final entered = Completer<void>();
        final release = Completer<void>();
        var armed = false;
        final service = MatchCommandService(
          database,
          now: () => now,
          failureInjector: (point) async {
            if (armed && point == MatchCommandFailurePoint.beforeCommit) {
              entered.complete();
              await release.future;
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'receipt-dispose-supplement'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
          nowUtc: () => now,
        );
        expect(
          await controller.recordScoreCommitted(side: TeamSide.red, points: 2),
          isTrue,
        );
        armed = true;
        final operation = controller.attachSupplementLocationWithReceipt(
          CourtPoint(x: 0.6, y: 0.4),
          requestedAtUtc: now,
        );
        await entered.future;
        controller.dispose();
        release.complete();

        expect(await operation, isNull);
        expect(
          await database.select(database.shotLocations).get(),
          hasLength(1),
        );
      });
    },
  );

  test(
    'bool court-first failure propagates once without a duplicate command',
    () async {
      await withTestDatabase((database) async {
        final now = DateTime.utc(2026, 8, 25, 12);
        var armed = false;
        var beforeCommitCalls = 0;
        final service = MatchCommandService(
          database,
          now: () => now,
          failureInjector: (point) {
            if (armed && point == MatchCommandFailurePoint.beforeCommit) {
              beforeCommitCalls++;
              throw StateError('wrapper failure');
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'receipt-wrapper-failure'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
          nowUtc: () => now,
        );
        expect(
          controller.beginOrMoveCourtFirstShot(
            CourtPoint(x: 0.2, y: 0.8),
            side: TeamSide.red,
          ),
          isTrue,
        );
        armed = true;

        await expectLater(
          controller.commitCourtFirstShot(),
          throwsA(isA<MatchCommandFailure>()),
        );
        expect(beforeCommitCalls, 1);
        expect(controller.state.courtFirstShotDraft, isNotNull);
        expect(await database.select(database.matchEvents).get(), isEmpty);
      });
    },
  );

  test('bool receipt wrappers commit each action exactly once', () async {
    await withTestDatabase((database) async {
      final now = DateTime.utc(2026, 8, 25, 12);
      final service = MatchCommandService(database, now: () => now);
      final started = await service.start(
        _startCommand(matchId: 'receipt-wrapper-count'),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
        nowUtc: () => now,
      );
      Future<int> countCommands() async {
        return (await (database.select(database.auditLogs)
                  ..where((row) => row.action.equals(AuditAction.command.name)))
                .get())
            .length;
      }

      final beforeCourt = await countCommands();
      expect(
        controller.beginOrMoveCourtFirstShot(
          CourtPoint(x: 0.3, y: 0.7),
          side: TeamSide.red,
        ),
        isTrue,
      );
      expect(await controller.commitCourtFirstShot(), isTrue);
      expect(await countCommands(), beforeCourt + 1);

      expect(
        await controller.recordScoreCommitted(side: TeamSide.blue, points: 1),
        isTrue,
      );
      final beforeSupplement = await countCommands();
      expect(
        await controller.attachSupplementLocation(CourtPoint(x: 0.8, y: 0.2)),
        isTrue,
      );
      expect(await countCommands(), beforeSupplement + 1);
    });
  });

  test('local score-first accepts foul and next score replaces the window', () {
    final now = DateTime.utc(2026, 8, 25, 12);
    final controller = ScoringController(matchId: 'match-1', nowUtc: () => now);

    final firstAccepted = controller.addScore(side: TeamSide.red, points: 2);
    controller.addFoul(TeamSide.blue);
    final secondAccepted = controller.addScore(side: TeamSide.blue, points: 3);

    expect(firstAccepted, isTrue);
    expect(secondAccepted, isTrue);
    expect(controller.state.score.redScore, 2);
    expect(controller.state.score.blueScore, 3);
    expect(controller.state.blueFouls, 1);
    expect(controller.state.pendingLocation, isNull);
    expect(
      controller.state.locationSupplementWindow?.eventId,
      'match-1-event-3',
    );
    expect(controller.state.locationSupplementWindow?.side, TeamSide.blue);
  });

  test('skipping a location keeps the score without recording a marker', () {
    final controller = ScoringController(matchId: 'match-1');

    controller.addScore(side: TeamSide.red, points: 1);
    controller.skipPendingLocation();

    expect(controller.state.score.redScore, 1);
    expect(controller.state.pendingLocation, isNull);
    expect(controller.state.shotLocations, isEmpty);
  });

  test(
    'local score-first attach then undo restores the window before the score',
    () async {
      final now = DateTime.utc(2026, 8, 25, 12);
      final controller = ScoringController(
        matchId: 'match-1',
        nowUtc: () => now,
      );

      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      final point = CourtPoint(x: 0.25, y: 0.75);
      expect(await controller.attachSupplementLocation(point), isTrue);
      expect(controller.state.locationSupplementWindow, isNull);
      expect(controller.state.shotLocations, hasLength(1));

      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.score.redScore, 2);
      expect(controller.state.shotLocations, isEmpty);
      expect(
        controller.state.locationSupplementWindow?.eventId,
        'match-1-event-1',
      );
      expect(controller.state.pendingLocation, isNull);

      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.score.redScore, 0);
      expect(controller.state.events.single.isDeleted, isTrue);
    },
  );

  test('local free throw closes an earlier score supplement window', () async {
    var now = DateTime.utc(2026, 8, 25, 12);
    final controller = ScoringController(
      matchId: 'match-free-throw-window',
      nowUtc: () => now,
    );

    await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
    expect(controller.locationSupplementWindow, isNotNull);
    now = now.add(const Duration(seconds: 1));
    expect(
      await controller.recordFreeThrowCommitted(side: TeamSide.red, made: true),
      isTrue,
    );
    expect(controller.locationSupplementWindow, isNull);
    expect(
      await controller.attachSupplementLocation(
        CourtPoint(x: 0.3, y: 0.7),
        eventId: 'match-free-throw-window-event-1',
      ),
      isFalse,
    );
  });

  test(
    'local undo of an unlocated newer score restores an active older window',
    () async {
      var now = DateTime.utc(2026, 8, 25, 12);
      final controller = ScoringController(
        matchId: 'match-local-window-restore',
        nowUtc: () => now,
      );

      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      now = now.add(const Duration(seconds: 1));
      await controller.recordScoreCommitted(side: TeamSide.blue, points: 1);
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(
        controller.locationSupplementWindow?.eventId,
        'match-local-window-restore-event-1',
      );
      expect(controller.state.score.redScore, 2);
    },
  );

  test(
    'local undo withdraws newer location then score and restores older window',
    () async {
      var now = DateTime.utc(2026, 8, 25, 12);
      final controller = ScoringController(
        matchId: 'match-local-window-location',
        nowUtc: () => now,
      );

      await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      now = now.add(const Duration(seconds: 1));
      await controller.recordScoreCommitted(side: TeamSide.blue, points: 1);
      expect(
        await controller.attachSupplementLocation(CourtPoint(x: 0.3, y: 0.7)),
        isTrue,
      );
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.score.blueScore, 1);
      expect(controller.state.shotLocations, isEmpty);
      expect(
        controller.locationSupplementWindow?.eventId,
        'match-local-window-location-event-2',
      );

      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(
        controller.locationSupplementWindow?.eventId,
        'match-local-window-location-event-1',
      );
      expect(controller.state.score.redScore, 2);
    },
  );

  test(
    'local undo does not restore an expired or located older window',
    () async {
      var now = DateTime.utc(2026, 8, 25, 12);
      final expired = ScoringController(
        matchId: 'match-local-window-expired',
        nowUtc: () => now,
      );
      await expired.recordScoreCommitted(side: TeamSide.red, points: 2);
      now = now.add(const Duration(seconds: 1));
      await expired.recordScoreCommitted(side: TeamSide.blue, points: 1);
      now = now.add(const Duration(seconds: 10));
      expect(await expired.undoLastScoringActionCommitted(), isTrue);
      expect(expired.locationSupplementWindow, isNull);

      now = DateTime.utc(2026, 8, 25, 12);
      final located = ScoringController(
        matchId: 'match-local-window-located',
        nowUtc: () => now,
      );
      await located.recordScoreCommitted(side: TeamSide.red, points: 2);
      expect(
        await located.attachSupplementLocation(CourtPoint(x: 0.2, y: 0.8)),
        isTrue,
      );
      now = now.add(const Duration(seconds: 1));
      await located.recordScoreCommitted(side: TeamSide.blue, points: 1);
      expect(await located.undoLastScoringActionCommitted(), isTrue);
      expect(located.locationSupplementWindow, isNull);

      now = DateTime.utc(2026, 8, 25, 12);
      final deleted = ScoringController(
        matchId: 'match-local-window-deleted',
        nowUtc: () => now,
      );
      await deleted.recordScoreCommitted(side: TeamSide.red, points: 2);
      deleted.undoLastEvent();
      now = now.add(const Duration(seconds: 1));
      await deleted.recordScoreCommitted(side: TeamSide.blue, points: 1);
      expect(await deleted.undoLastScoringActionCommitted(), isTrue);
      expect(deleted.locationSupplementWindow, isNull);
    },
  );

  test(
    'local court-first draft blocks ordinary actions and undoes atomically',
    () async {
      final controller = ScoringController(
        matchId: 'match-1',
        nowUtc: () => DateTime.utc(2026, 8, 25, 12),
      );
      final point = CourtPoint(x: 0.4, y: 0.6);

      expect(
        controller.beginOrMoveCourtFirstShot(point, side: TeamSide.red),
        isTrue,
      );
      expect(controller.state.courtFirstShotDraft, isNotNull);
      expect(await controller.recordFoulCommitted(TeamSide.blue), isFalse);
      expect(
        await controller.recordScoreCommitted(side: TeamSide.blue, points: 1),
        isFalse,
      );

      expect(await controller.commitCourtFirstShot(), isTrue);
      expect(controller.state.courtFirstShotDraft, isNull);
      expect(controller.state.score.redScore, 1);
      expect(controller.state.shotLocations, hasLength(1));
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.score.redScore, 0);
      expect(controller.state.shotLocations, isEmpty);
      expect(controller.state.events.single.isDeleted, isTrue);
    },
  );

  test('score-first confirmation locks and records the court point', () async {
    final controller = ScoringController(matchId: 'match-1');
    final point = CourtPoint(x: 0.25, y: 0.75);

    controller.addScore(side: TeamSide.blue, points: 2);
    await controller.confirmPendingLocation(point);

    expect(controller.state.pendingLocation, isNull);
    expect(controller.state.shotLocations, hasLength(1));
    expect(controller.state.shotLocations.single.side, TeamSide.blue);
    expect(controller.state.shotLocations.single.point.x, 0.25);
    expect(controller.state.shotLocations.single.isLocked, isTrue);
  });

  test('fouls are accumulated per side', () {
    final controller = ScoringController(matchId: 'match-1');

    controller.addFoul(TeamSide.red);
    controller.addFoul(TeamSide.red);
    controller.addFoul(TeamSide.blue);

    expect(controller.state.redFouls, 2);
    expect(controller.state.blueFouls, 1);
    expect(
      controller.state.events.where(
        (event) => event.type == MatchEventType.foul,
      ),
      hasLength(3),
    );
  });

  test('undo rolls back the latest foul event', () {
    final controller = ScoringController(matchId: 'match-1');

    controller.addFoul(TeamSide.red);
    controller.addFoul(TeamSide.blue);
    controller.undoLastEvent();

    expect(controller.state.redFouls, 1);
    expect(controller.state.blueFouls, 0);
  });

  test(
    'live undo covers foul, possession, note, and custom events locally',
    () async {
      final controller = ScoringController(matchId: 'local-all-undo');

      expect(await controller.recordFoulCommitted(TeamSide.red), isTrue);
      expect(await controller.recordPossessionCommitted(TeamSide.blue), isTrue);
      expect(
        await controller.recordNoteCommitted('Timeout adjustment'),
        isTrue,
      );
      expect(
        await controller.recordCustomCommitted(label: 'Lineup change'),
        isTrue,
      );

      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(
        controller.state.events
            .singleWhere((event) => event.type == EventKind.custom)
            .isDeleted,
        isTrue,
      );
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(
        controller.state.events
            .singleWhere((event) => event.type == EventKind.note)
            .isDeleted,
        isTrue,
      );
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.currentPossession, isNull);
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.redFouls, 0);
      expect(await controller.undoLastScoringActionCommitted(), isFalse);
    },
  );

  test(
    'local undo preserves action order around location supplements',
    () async {
      final controller = ScoringController(
        matchId: 'local-location-action-order',
        nowUtc: () => DateTime.utc(2026, 8, 25, 12),
      );
      expect(
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2),
        isTrue,
      );
      expect(
        await controller.attachSupplementLocation(CourtPoint(x: 0.4, y: 0.6)),
        isTrue,
      );
      expect(await controller.recordFoulCommitted(TeamSide.blue), isTrue);

      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.blueFouls, 0);
      expect(controller.state.shotLocations, hasLength(1));
      expect(controller.state.score.redScore, 2);

      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(controller.state.shotLocations, isEmpty);
      expect(controller.state.score.redScore, 2);
    },
  );

  test('target score setup produces rule hints while scoring', () {
    final controller = ScoringController(
      setup: const MatchSetup(
        matchId: 'match-1',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplateId: 'eleven',
        targetScore: 2,
        timerEnabled: false,
        timeLimitMinutes: 10,
        winByTwo: false,
      ),
    );

    controller.addScore(side: TeamSide.red, points: 2);

    expect(controller.state.ruleHints.single.type, RuleHintType.targetReached);
  });

  test('preserves the selected rule name in the scoring snapshot', () {
    final controller = ScoringController(
      setup: const MatchSetup(
        matchId: 'match-custom',
        redName: 'Red',
        blueName: 'Blue',
        ruleTemplateId: 'custom-15',
        ruleTemplateName: 'Custom 15',
        targetScore: 15,
        timerEnabled: false,
        timeLimitMinutes: 10,
        winByTwo: false,
      ),
    );

    expect(controller.state.ruleTemplate.name, 'Custom 15');
  });

  test(
    'command-backed made score commits as fieldGoal and creates pending location',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = StartMatchCommand(
          commandId: 'ui-score-start-command',
          matchId: 'ui-score-match',
          redName: 'Red',
          blueName: 'Blue',
          ruleTemplate: const RuleTemplate(
            id: 'free',
            name: 'Free',
            scoreButtons: [1, 2, 3],
          ),
          recordingMode: RecordingMode.simple,
          createdAt: DateTime.utc(2026, 8, 23, 9),
          startedAt: DateTime.utc(2026, 8, 23, 9),
        );
        final projection = await service.start(start);
        final controller = ScoringController.fromCommittedProjection(
          projection,
          service,
        );

        expect(
          await controller.recordScoreCommitted(side: TeamSide.red, points: 2),
          isTrue,
        );

        final event = await (database.select(
          database.matchEvents,
        )..where((row) => row.matchId.equals(start.matchId))).getSingle();
        expect(event.type, EventKind.fieldGoal.name);
        expect(event.outcome, ShotOutcome.made.name);
        expect(controller.state.pendingLocation, isNull);
      });
    },
  );

  test(
    'command-backed projection exposes possession and match-point hints',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = await service.start(
          StartMatchCommand(
            commandId: 'command-hints-start',
            matchId: 'command-hints',
            redName: 'Red',
            blueName: 'Blue',
            ruleTemplate: const RuleTemplate(
              id: 'command-hints-rule',
              name: 'Command hints',
              scoreButtons: [1, 2, 3],
              targetScore: 3,
              possessionHintEnabled: true,
              possessionPolicy: PossessionPolicy.switchAfterMade,
            ),
            recordingMode: RecordingMode.simple,
            createdAt: DateTime.utc(2026, 8, 23, 9),
            startedAt: DateTime.utc(2026, 8, 23, 9),
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );

        expect(
          await controller.recordScoreCommitted(side: TeamSide.red, points: 2),
          isTrue,
        );

        final possessionHint = controller.state.ruleHints.singleWhere(
          (hint) => hint.type == RuleHintType.possessionChange,
        );
        expect(possessionHint.suggestedSide, TeamSide.blue);
        expect(
          controller.state.ruleHints.any(
            (hint) => hint.type == RuleHintType.matchPoint,
          ),
          isTrue,
        );
        expect(controller.currentPossession, TeamSide.blue);
      });
    },
  );

  test(
    'command-backed target decision keeps a visible target hint for the scorer',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = await service.start(
          StartMatchCommand(
            commandId: 'command-target-start',
            matchId: 'command-target',
            redName: 'Red',
            blueName: 'Blue',
            ruleTemplate: const RuleTemplate(
              id: 'command-target-rule',
              name: 'Command target',
              scoreButtons: [1, 2, 3],
              targetScore: 2,
              possessionHintEnabled: true,
              possessionPolicy: PossessionPolicy.switchAfterMade,
            ),
            recordingMode: RecordingMode.simple,
            createdAt: DateTime.utc(2026, 8, 23, 9),
            startedAt: DateTime.utc(2026, 8, 23, 9),
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );

        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);

        expect(
          controller.state.ruleHints.any(
            (hint) => hint.type == RuleHintType.targetReached,
          ),
          isTrue,
        );
        expect(
          controller.state.ruleHints
              .where((hint) => hint.type == RuleHintType.possessionChange)
              .single
              .suggestedSide,
          TeamSide.blue,
        );
      });
    },
  );

  test(
    'command-backed confirmation persists fieldGoal location after commit',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = await _startCommandBackedMatch(service);
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);

        await controller.confirmPendingLocation(CourtPoint(x: 0.25, y: 0.75));

        expect(controller.state.pendingLocation, isNull);
        expect(controller.state.shotLocations, hasLength(1));
        expect(controller.state.shotLocations.single.point.x, 0.25);
        expect(
          await database.select(database.shotLocations).get(),
          hasLength(1),
        );
      });
    },
  );

  test('command-backed skip leaves a committed unlocated fieldGoal', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final start = await _startCommandBackedMatch(service);
      final controller = ScoringController.fromCommittedProjection(
        start,
        service,
      );
      await controller.recordScoreCommitted(side: TeamSide.blue, points: 3);
      expect(controller.beginLocateLastUnlocatedShot(), isTrue);

      controller.skipPendingLocation();

      expect(controller.state.pendingLocation, isNull);
      expect(controller.state.score.blueScore, 3);
      expect(controller.state.shotLocations, isEmpty);
      expect(await database.select(database.shotLocations).get(), isEmpty);
      expect(await database.select(database.matchEvents).get(), hasLength(1));
    });
  });

  test(
    'failed command-backed confirmation keeps pending state and retries the same command',
    () async {
      await withTestDatabase((database) async {
        var beforeCommitCalls = 0;
        final service = MatchCommandService(
          database,
          failureInjector: (point) {
            if (point == MatchCommandFailurePoint.beforeCommit &&
                beforeCommitCalls++ == 2) {
              throw StateError('confirm failed once');
            }
          },
        );
        final start = await _startCommandBackedMatch(service);
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);
        final pendingEventId = controller.state.pendingLocation!.eventId;

        MatchCommandFailure? failure;
        try {
          await controller.confirmPendingLocation(CourtPoint(x: 0.25, y: 0.75));
        } on MatchCommandFailure catch (error) {
          failure = error;
        }

        expect(failure, isA<CommandTransactionFailure>());
        expect(failure!.command.commandId, isNotEmpty);
        expect(controller.state.pendingLocation!.eventId, pendingEventId);
        expect(await database.select(database.shotLocations).get(), isEmpty);

        await controller.retryCommand(failure);

        expect(controller.state.pendingLocation, isNull);
        expect(controller.state.shotLocations, hasLength(1));
        final receipts = await (database.select(
          database.auditLogs,
        )..where((row) => row.id.equals(failure!.command.commandId))).get();
        expect(receipts, hasLength(1));
        expect(receipts.single.action, AuditAction.command.name);
      });
    },
  );

  test(
    'pending location cannot be skipped while confirmation command is in flight',
    () async {
      await withTestDatabase((database) async {
        final entered = Completer<void>();
        final release = Completer<void>();
        var beforeCommitCalls = 0;
        final service = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (point == MatchCommandFailurePoint.beforeCommit &&
                beforeCommitCalls++ == 2) {
              entered.complete();
              await release.future;
            }
          },
        );
        final start = await _startCommandBackedMatch(service);
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);

        final confirmation = controller.confirmPendingLocation();
        await entered.future;

        expect(controller.skipPendingLocation(), isFalse);
        expect(controller.state.pendingLocation, isNotNull);

        release.complete();
        await confirmation;
        expect(controller.state.pendingLocation, isNull);
      });
    },
  );

  test(
    'explicit location rejects foul until cancelled, then undo soft-deletes the shot',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final start = await _startCommandBackedMatch(service);
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        await controller.recordScoreCommitted(side: TeamSide.blue, points: 3);
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);

        expect(await controller.recordFoulCommitted(TeamSide.red), isFalse);
        expect(await database.select(database.matchEvents).get(), hasLength(1));

        expect(controller.cancelLocateLastUnlocatedShot(), isTrue);
        await controller.undoLastEventCommitted();
        final event = await database.select(database.matchEvents).getSingle();
        expect(event.isDeleted, isTrue);
      });
    },
  );

  test(
    'committed score completing after dispose commits but does not touch controller',
    () async {
      await withTestDatabase((database) async {
        final startService = MatchCommandService(database);
        final start = await _startCommandBackedMatch(startService);
        final entered = Completer<void>();
        final release = Completer<void>();
        final service = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (point == MatchCommandFailurePoint.beforeCommit) {
              entered.complete();
              await release.future;
            }
          },
        );
        final controller = ScoringController.fromCommittedProjection(
          start,
          service,
        );
        var notifications = 0;
        controller.addListener(() => notifications++);

        final command = controller.recordScoreCommitted(
          side: TeamSide.red,
          points: 2,
        );
        await entered.future;
        final notificationsBeforeDispose = notifications;
        controller.dispose();
        release.complete();

        await command;
        expect(
          await (database.select(
            database.matchEvents,
          )..where((row) => row.matchId.equals(start.match.id))).get(),
          hasLength(1),
        );
        expect(notifications, notificationsBeforeDispose);
      });
    },
  );

  test(
    'foul, undo, and confirmation completing after dispose do not notify',
    () async {
      await withTestDatabase((database) async {
        final startService = MatchCommandService(database);
        final start = await _startCommandBackedMatch(startService);

        final foulEntered = Completer<void>();
        final foulRelease = Completer<void>();
        final foulService = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (point == MatchCommandFailurePoint.beforeCommit) {
              foulEntered.complete();
              await foulRelease.future;
            }
          },
        );
        final foulController = ScoringController.fromCommittedProjection(
          start,
          foulService,
        );
        final foulCommand = foulController.recordFoulCommitted(TeamSide.red);
        await foulEntered.future;
        foulController.dispose();
        foulRelease.complete();
        await foulCommand;

        final scoreProjection = await startService.record(
          RecordMatchEventCommand(
            matchId: start.match.id,
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: DateTime.now().toUtc(),
          ),
        );

        final undoEntered = Completer<void>();
        final undoRelease = Completer<void>();
        final undoService = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (point == MatchCommandFailurePoint.beforeCommit) {
              undoEntered.complete();
              await undoRelease.future;
            }
          },
        );
        final undoController = ScoringController.fromCommittedProjection(
          scoreProjection,
          undoService,
        );
        final undoCommand = undoController.undoLastEventCommitted();
        await undoEntered.future;
        undoController.dispose();
        undoRelease.complete();
        await undoCommand;

        final confirmEntered = Completer<void>();
        final confirmRelease = Completer<void>();
        var beforeCommitCalls = 0;
        final confirmService = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (point == MatchCommandFailurePoint.beforeCommit &&
                ++beforeCommitCalls == 2) {
              confirmEntered.complete();
              await confirmRelease.future;
            }
          },
        );
        final confirmController = ScoringController.fromCommittedProjection(
          scoreProjection,
          confirmService,
        );
        await confirmController.recordScoreCommitted(
          side: TeamSide.blue,
          points: 3,
        );
        expect(confirmController.beginLocateLastUnlocatedShot(), isTrue);
        final confirmCommand = confirmController.confirmPendingLocation();
        await confirmEntered.future;
        confirmController.dispose();
        confirmRelease.complete();
        await confirmCommand;

        expect(
          await (database.select(
            database.matchEvents,
          )..where((row) => row.matchId.equals(start.match.id))).get(),
          hasLength(3),
        );
        expect(
          await database.select(database.shotLocations).get(),
          hasLength(1),
        );
      });
    },
  );
}

StartMatchCommand _startCommand({required String matchId}) {
  return StartMatchCommand(
    commandId: '$matchId-start',
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
    timerEnabled: false,
    createdAt: DateTime.utc(2026, 8, 25, 12),
    startedAt: DateTime.utc(2026, 8, 25, 12),
  );
}

Future<MatchDetail> _startCommandBackedMatch(MatchCommandService service) {
  return service.start(
    StartMatchCommand(
      commandId: 'ui-command-${DateTime.now().microsecondsSinceEpoch}',
      matchId: 'ui-command-match-${DateTime.now().microsecondsSinceEpoch}',
      redName: 'Red',
      blueName: 'Blue',
      ruleTemplate: const RuleTemplate(
        id: 'free',
        name: 'Free',
        scoreButtons: [1, 2, 3],
      ),
      recordingMode: RecordingMode.simple,
      trackingCoverage: TrackingCoverage.locations,
      createdAt: DateTime.utc(2026, 8, 23, 9),
      startedAt: DateTime.utc(2026, 8, 23, 9),
    ),
  );
}
