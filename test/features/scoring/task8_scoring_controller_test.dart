import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hoopito/core/data/commands/match_command_service.dart';
import 'package:hoopito/core/data/repositories/match_repository.dart';
import 'package:hoopito/core/domain/domain_enums.dart';
import 'package:hoopito/core/domain/entities/rule_template.dart';
import 'package:hoopito/core/domain/value_objects/court_point.dart';
import 'package:hoopito/core/domain/value_objects/team_side.dart';
import 'package:hoopito/features/scoring/scoring_controller.dart';
import 'package:hoopito/features/pregame/pregame_controller.dart';

import '../../test_helpers/test_database.dart';

void main() {
  test(
    'projection exposes mode coverage clock and latest possession',
    () async {
      await withTestDatabase((database) async {
        final openedAt = DateTime.now().toUtc();
        final service = MatchCommandService(database, now: () => openedAt);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-projection',
            recordingMode: RecordingMode.detailed,
            trackingCoverage: TrackingCoverage.locations,
            timerEnabled: false,
          ),
        );
        final withPossession = await service.record(
          RecordMatchEventCommand(
            matchId: started.match.id,
            type: EventKind.possession,
            side: TeamSide.blue,
            points: 0,
            occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
          ),
        );

        final controller = ScoringController.fromCommittedProjection(
          withPossession,
          service,
        );

        expect(controller.recordingMode, RecordingMode.detailed);
        expect(controller.trackingCoverage, TrackingCoverage.locations);
        expect(controller.clock, isNotNull);
        expect(controller.state.timerEnabled, isFalse);
        expect(controller.currentPossession, TeamSide.blue);
      });
    },
  );

  test('court-first draft is atomic and can move before commit', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(
        database,
        now: () => DateTime.utc(2026, 8, 23, 9),
      );
      final started = await service.start(
        _startCommand(matchId: 'task8-court-first'),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );

      expect(
        controller.beginOrMoveCourtFirstShot(
          CourtPoint(x: 0.2, y: 0.8),
          side: TeamSide.red,
        ),
        isTrue,
      );
      expect(
        controller.beginOrMoveCourtFirstShot(CourtPoint(x: 0.3, y: 0.7)),
        isTrue,
      );
      expect(controller.courtFirstShotDraft?.point.x, 0.3);
      expect(controller.cancelCourtFirstShot(), isTrue);
      expect(controller.courtFirstShotDraft, isNull);
      expect(await database.select(database.matchEvents).get(), isEmpty);
    });
  });

  test(
    'score-first supplement window survives controller rebuild and expires at deadline',
    () async {
      await withTestDatabase((database) async {
        final openedAt = DateTime.now().toUtc();
        final service = MatchCommandService(database, now: () => openedAt);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-supplement',
            trackingCoverage: TrackingCoverage.scoresOnly,
          ),
        );
        final scored = await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-supplement-score',
            matchId: started.match.id,
            eventId: 'task8-supplement-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: openedAt,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          scored,
          service,
        );
        expect(controller.locationSupplementWindow, isNotNull);
        expect(
          controller.expireSupplementWindow(
            atUtc: openedAt.add(const Duration(seconds: 10)),
          ),
          isTrue,
        );
        expect(controller.locationSupplementWindow, isNull);
        final rebuilt = ScoringController.fromCommittedProjection(
          scored,
          service,
        );
        expect(rebuilt.locationSupplementWindow, isNotNull);
      });
    },
  );

  test(
    'undoing the newest score restores the remaining supplement window',
    () async {
      await withTestDatabase((database) async {
        final openedAt = DateTime.now().toUtc();
        final secondAt = openedAt.add(const Duration(seconds: 1));
        var now = openedAt;
        final service = MatchCommandService(database, now: () => now);
        final started = await service.start(
          _startCommand(matchId: 'task8-undo-restores-window'),
        );
        final first = await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-undo-restores-first',
            matchId: started.match.id,
            eventId: 'task8-undo-restores-first-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: openedAt,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          first,
          service,
        );
        now = secondAt;
        final second = await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-undo-restores-second',
            matchId: started.match.id,
            eventId: 'task8-undo-restores-second-event',
            type: EventKind.fieldGoal,
            side: TeamSide.blue,
            points: 1,
            outcome: ShotOutcome.made,
            occurredAt: secondAt,
          ),
        );
        controller.replaceCommittedProjection(second);
        expect(
          controller.locationSupplementWindow?.eventId,
          'task8-undo-restores-second-event',
        );

        final undone = await service.undoLastScoringAction(
          UndoLastScoringActionCommand(
            commandId: 'task8-undo-restores-second-action',
            matchId: started.match.id,
          ),
        );
        controller.replaceCommittedProjection(undone);
        expect(
          controller.locationSupplementWindow?.eventId,
          'task8-undo-restores-first-event',
        );
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);
        expect(
          await controller.attachSupplementLocation(
            CourtPoint(x: 0.2, y: 0.3),
            requestedAtUtc: openedAt.add(const Duration(seconds: 2)),
          ),
          isTrue,
        );
        expect(undone.redScore, 2);
      });
    },
  );

  test(
    'projection rebuild drops pending location when a newer score owns the window',
    () async {
      await withTestDatabase((database) async {
        final openedAt = DateTime.now().toUtc();
        var now = openedAt;
        final service = MatchCommandService(database, now: () => now);
        final started = await service.start(
          _startCommand(matchId: 'task8-stale-pending'),
        );
        final first = await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-stale-first-score',
            matchId: started.match.id,
            eventId: 'task8-stale-first-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: openedAt,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          first,
          service,
          nowUtc: () => now,
        );
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);
        expect(
          controller.state.pendingLocation?.eventId,
          'task8-stale-first-event',
        );
        final staleEventId = controller.state.pendingLocation!.eventId;

        now = openedAt.add(const Duration(seconds: 1));
        final second = await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-stale-second-score',
            matchId: started.match.id,
            eventId: 'task8-stale-second-event',
            type: EventKind.fieldGoal,
            side: TeamSide.blue,
            points: 1,
            outcome: ShotOutcome.made,
            occurredAt: now,
          ),
        );
        controller.replaceCommittedProjection(second);

        expect(controller.state.pendingLocation, isNull);
        expect(
          controller.locationSupplementWindow?.eventId,
          'task8-stale-second-event',
        );
        await controller.confirmPendingLocation(
          CourtPoint(x: 0.2, y: 0.3),
          staleEventId,
        );
        expect(await database.select(database.shotLocations).get(), isEmpty);
      });
    },
  );

  test('unified scoring actions ignore legacy capability metadata', () async {
    await withTestDatabase((database) async {
      final openedAt = DateTime.now().toUtc();
      final service = MatchCommandService(database, now: () => openedAt);
      final started = await service.start(
        _startCommand(
          matchId: 'task8-unified-capabilities',
          recordingMode: RecordingMode.simple,
          trackingCoverage: TrackingCoverage.none,
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );
      expect(
        await controller.recordMissCommitted(
          side: TeamSide.red,
          occurredAt: openedAt,
        ),
        isTrue,
      );
      expect(controller.beginLocateLastUnlocatedShot(), isTrue);
      expect(
        await controller.attachSupplementLocation(
          CourtPoint(x: 0.2, y: 0.8),
          requestedAtUtc: openedAt.add(const Duration(seconds: 1)),
        ),
        isTrue,
      );
    });
  });

  test('unified undo excludes timer and finish actions', () async {
    final controller = ScoringController(matchId: 'task8-local-undo');
    expect(await controller.undoLastScoringActionCommitted(), isFalse);
  });

  test(
    'projection preserves timerEnabled independently from clock presence',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(matchId: 'task8-timer-flag', timerEnabled: true),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );

        expect(controller.state.timerEnabled, isTrue);
        expect(controller.clock, isNotNull);
      });
    },
  );

  test(
    'local score-first actions stay open while detailed drafts still guard',
    () async {
      final pendingController = ScoringController(
        matchId: 'task8-local-pending',
      );
      expect(
        pendingController.addScore(side: TeamSide.blue, points: 2),
        isTrue,
      );
      expect(
        await pendingController.recordScoreCommitted(
          side: TeamSide.red,
          points: 1,
        ),
        isTrue,
      );
      expect(await pendingController.recordFoulCommitted(TeamSide.red), isTrue);
      expect(
        await pendingController.recordFreeThrowCommitted(
          side: TeamSide.red,
          made: true,
        ),
        isTrue,
      );
      expect(
        await pendingController.recordPossessionCommitted(TeamSide.red),
        isTrue,
      );
      expect(await pendingController.recordNoteCommitted('note'), isTrue);
      expect(
        await pendingController.recordCustomCommitted(label: 'custom'),
        isTrue,
      );

      final draftController = ScoringController(
        setup: const MatchSetup(
          matchId: 'task8-local-draft',
          redName: '红方',
          blueName: '蓝方',
          ruleTemplateId: 'free',
          targetScore: null,
          timerEnabled: false,
          timeLimitMinutes: 10,
          winByTwo: false,
          recordingMode: RecordingMode.detailed,
          trackingCoverage: TrackingCoverage.locations,
        ),
      );
      expect(
        draftController.beginDetailedShot(CourtPoint(x: 0.4, y: 0.6)),
        isTrue,
      );
      expect(draftController.addScore(side: TeamSide.blue, points: 2), isFalse);
      expect(await draftController.recordFoulCommitted(TeamSide.blue), isFalse);
      expect(
        await draftController.recordFreeThrowCommitted(
          side: TeamSide.blue,
          made: true,
        ),
        isFalse,
      );
      expect(
        await draftController.recordPossessionCommitted(TeamSide.blue),
        isFalse,
      );
      expect(await draftController.recordNoteCommitted('note'), isFalse);
      expect(
        await draftController.recordCustomCommitted(label: 'custom'),
        isFalse,
      );
    },
  );

  test(
    'simple made score is committed without blocking the next score',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(matchId: 'task8-queue'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );

        final first = controller.recordScoreCommitted(
          side: TeamSide.red,
          points: 2,
        );
        final second = controller.recordScoreCommitted(
          side: TeamSide.blue,
          points: 3,
        );

        expect(await first, isTrue);
        expect(await second, isTrue);
        expect(controller.state.score.redScore, 2);
        expect(controller.state.score.blueScore, 3);
        expect(controller.state.pendingLocation, isNull);
        expect(
          await (database.select(
            database.matchEvents,
          )..where((row) => row.matchId.equals(started.match.id))).get(),
          hasLength(2),
        );
      });
    },
  );

  test(
    'ordinary rapid input is serialized in command creation order',
    () async {
      await withTestDatabase((database) async {
        final firstEntered = Completer<void>();
        final releaseFirst = Completer<void>();
        var recordCalls = 0;
        final service = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (point == MatchCommandFailurePoint.beforeCommit &&
                ++recordCalls == 2) {
              firstEntered.complete();
              await releaseFirst.future;
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'task8-order'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );

        final first = controller.recordScoreCommitted(
          side: TeamSide.red,
          points: 1,
        );
        await firstEntered.future;
        final second = controller.recordScoreCommitted(
          side: TeamSide.blue,
          points: 2,
        );
        releaseFirst.complete();

        expect(await first, isTrue);
        expect(await second, isTrue);
        final events = await (database.select(
          database.matchEvents,
        )..where((row) => row.matchId.equals(started.match.id))).get();
        expect(events.map((event) => event.points), [1, 2]);
      });
    },
  );

  test(
    'free throws, miss, foul, possession, note, and custom are command-backed',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-actions',
            trackingCoverage: TrackingCoverage.shotAttempts,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );

        expect(
          await controller.recordFreeThrowCommitted(
            side: TeamSide.red,
            made: true,
          ),
          isTrue,
        );
        expect(
          await controller.recordFreeThrowCommitted(
            side: TeamSide.red,
            made: false,
          ),
          isTrue,
        );
        expect(
          await controller.recordMissCommitted(side: TeamSide.blue),
          isTrue,
        );
        expect(await controller.recordFoulCommitted(TeamSide.blue), isTrue);
        expect(
          await controller.recordPossessionCommitted(TeamSide.red),
          isTrue,
        );
        expect(await controller.recordNoteCommitted('timeout'), isTrue);
        expect(
          await controller.recordCustomCommitted(
            label: '救球',
            side: TeamSide.red,
          ),
          isTrue,
        );

        final events = await (database.select(
          database.matchEvents,
        )..where((row) => row.matchId.equals(started.match.id))).get();
        expect(events.map((event) => event.type), [
          EventKind.freeThrow.name,
          EventKind.freeThrow.name,
          EventKind.fieldGoal.name,
          EventKind.foul.name,
          EventKind.possession.name,
          EventKind.note.name,
          EventKind.custom.name,
        ]);
        expect(events[1].outcome, ShotOutcome.missed.name);
        expect(events[2].outcome, ShotOutcome.missed.name);
        expect(controller.currentPossession, TeamSide.red);
      });
    },
  );

  test('miss tracking ignores legacy coverage metadata', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final started = await service.start(
        _startCommand(
          matchId: 'task8-coverage',
          trackingCoverage: TrackingCoverage.scoresOnly,
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );

      expect(await controller.recordMissCommitted(side: TeamSide.red), isTrue);
      expect(await database.select(database.matchEvents).get(), hasLength(1));
    });
  });

  test(
    'locate-last-shot is explicit and cancel leaves history unlocated',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-location',
            trackingCoverage: TrackingCoverage.locations,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);

        expect(controller.beginLocateLastUnlocatedShot(), isTrue);
        expect(controller.state.pendingLocation, isNotNull);
        expect(controller.cancelLocateLastUnlocatedShot(), isTrue);
        expect(controller.state.pendingLocation, isNull);
        expect(controller.state.score.redScore, 2);
        expect(await database.select(database.shotLocations).get(), isEmpty);
      });
    },
  );

  test(
    'detailed shot is a local court-first draft and commits one event plus location',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-detailed',
            recordingMode: RecordingMode.detailed,
            trackingCoverage: TrackingCoverage.locations,
          ),
        );
        final possession = await service.record(
          RecordMatchEventCommand(
            matchId: started.match.id,
            type: EventKind.possession,
            side: TeamSide.blue,
            points: 0,
            occurredAt: DateTime.utc(2026, 8, 23, 9, 1),
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          possession,
          service,
        );

        expect(
          controller.beginDetailedShot(CourtPoint(x: 0.2, y: 0.8)),
          isTrue,
        );
        expect(controller.detailedShotDraft?.side, TeamSide.blue);
        controller.updateDetailedShot(side: TeamSide.red, points: 3);
        expect(await controller.commitDetailedShot(), isTrue);
        expect(controller.detailedShotDraft, isNull);
        final events = await database.select(database.matchEvents).get();
        expect(
          events.where((event) => event.type == EventKind.fieldGoal.name),
          hasLength(1),
        );
        expect(events.last.type, EventKind.fieldGoal.name);
        expect(events.last.side, TeamSide.red.name);
        expect(events.last.points, 3);
        expect(
          await database.select(database.shotLocations).get(),
          hasLength(1),
        );
      });
    },
  );

  test(
    'an explicitly located missed field goal keeps the missed outcome',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-missed-location',
            trackingCoverage: TrackingCoverage.locations,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );
        await controller.recordMissCommitted(side: TeamSide.red);
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);
        await controller.confirmPendingLocation(CourtPoint(x: 0.1, y: 0.9));

        final event = await database.select(database.matchEvents).getSingle();
        expect(event.outcome, ShotOutcome.missed.name);
        expect(
          await database.select(database.shotLocations).get(),
          hasLength(1),
        );
      });
    },
  );

  test('detailed draft cancellation writes no event or location', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final started = await service.start(
        _startCommand(
          matchId: 'task8-cancel',
          recordingMode: RecordingMode.detailed,
          trackingCoverage: TrackingCoverage.locations,
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );
      expect(controller.beginDetailedShot(CourtPoint(x: 0.5, y: 0.5)), isTrue);
      expect(controller.cancelDetailedShot(), isTrue);
      expect(await database.select(database.matchEvents).get(), isEmpty);
      expect(await database.select(database.shotLocations).get(), isEmpty);
    });
  });

  test(
    'detailed controller never holds pending location and draft together',
    () {
      final controller = ScoringController(
        setup: const MatchSetup(
          matchId: 'task8-mutual-location-state',
          redName: '红方',
          blueName: '蓝方',
          ruleTemplateId: 'free',
          targetScore: null,
          timerEnabled: false,
          timeLimitMinutes: 10,
          winByTwo: false,
          recordingMode: RecordingMode.detailed,
          trackingCoverage: TrackingCoverage.locations,
        ),
      );

      expect(controller.addScore(side: TeamSide.blue, points: 2), isTrue);
      expect(controller.state.pendingLocation, isNull);
      expect(controller.beginDetailedShot(CourtPoint(x: 0.4, y: 0.6)), isTrue);
      expect(controller.detailedShotDraft, isNotNull);
    },
  );

  test('locating rejects while a detailed draft is being edited', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final started = await service.start(
        _startCommand(
          matchId: 'task8-reverse-location-state',
          recordingMode: RecordingMode.detailed,
          trackingCoverage: TrackingCoverage.locations,
        ),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );
      expect(
        await controller.recordFieldGoalCommitted(
          side: TeamSide.blue,
          outcome: ShotOutcome.made,
          points: 2,
        ),
        isTrue,
      );
      expect(controller.beginDetailedShot(CourtPoint(x: 0.4, y: 0.6)), isTrue);
      expect(controller.beginLocateLastUnlocatedShot(), isFalse);
      expect(controller.detailedShotDraft, isNotNull);
    });
  });

  test('pause and resume use semantic command events', () async {
    await withTestDatabase((database) async {
      final service = MatchCommandService(database);
      final started = await service.start(
        _startCommand(matchId: 'task8-clock', timerEnabled: false),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );

      expect(controller.isManuallyPaused, isFalse);
      expect(await controller.pauseCommitted(), isTrue);
      expect(controller.isManuallyPaused, isTrue);
      expect(await controller.resumeCommitted(), isTrue);
      expect(controller.isManuallyPaused, isFalse);
      final events = await database.select(database.matchEvents).get();
      expect(events.map((event) => event.customLabel), ['pause', 'resume']);
    });
  });

  test(
    'pause and resume preserve legacy pending location without a timer',
    () async {
      await withTestDatabase((database) async {
        final now = DateTime.now().toUtc();
        final service = MatchCommandService(database, now: () => now);
        final started = await service.start(
          _startCommand(matchId: 'task8-pause-pending', timerEnabled: false),
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
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);
        final pending = controller.state.pendingLocation!;

        expect(await controller.pauseCommitted(), isTrue);
        expect(controller.isManuallyPaused, isTrue);
        expect(controller.state.pendingLocation?.eventId, pending.eventId);
        expect(controller.state.pendingLocation?.point, pending.point);

        expect(await controller.resumeCommitted(), isTrue);
        expect(controller.isManuallyPaused, isFalse);
        expect(controller.state.pendingLocation?.eventId, pending.eventId);
        expect(controller.state.pendingLocation?.point, pending.point);
      });
    },
  );

  test('failed pause and resume commands do not change pause state', () async {
    await withTestDatabase((database) async {
      var failNext = false;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (failNext && point == MatchCommandFailurePoint.beforeCommit) {
            failNext = false;
            throw StateError('pause transition failed');
          }
        },
      );
      final started = await service.start(
        _startCommand(matchId: 'task8-pause-failure', timerEnabled: false),
      );
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );

      failNext = true;
      await expectLater(
        controller.pauseCommitted(),
        throwsA(isA<MatchCommandFailure>()),
      );
      expect(controller.isManuallyPaused, isFalse);

      expect(await controller.pauseCommitted(), isTrue);
      expect(controller.isManuallyPaused, isTrue);

      failNext = true;
      await expectLater(
        controller.resumeCommitted(),
        throwsA(isA<MatchCommandFailure>()),
      );
      expect(controller.isManuallyPaused, isTrue);
    });
  });

  test(
    'retry keeps the original command and updates projection after commit',
    () async {
      await withTestDatabase((database) async {
        var beforeCommitCalls = 0;
        var armed = false;
        final service = MatchCommandService(
          database,
          failureInjector: (point) {
            if (armed &&
                point == MatchCommandFailurePoint.beforeCommit &&
                beforeCommitCalls++ == 0) {
              throw StateError('retry once');
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'task8-retry'),
        );
        armed = true;
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );

        MatchCommandFailure? failure;
        try {
          await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
        } on MatchCommandFailure catch (error) {
          failure = error;
        }
        expect(failure, isNotNull);
        expect(failure!.command, isA<RecordMatchEventCommand>());
        await controller.retryCommand(failure);
        expect(controller.state.score.redScore, 2);
        expect(await database.select(database.matchEvents).get(), hasLength(1));
      });
    },
  );

  test(
    'disposed controller does not mutate or notify after queued command commits',
    () async {
      await withTestDatabase((database) async {
        final entered = Completer<void>();
        final release = Completer<void>();
        var armed = false;
        final service = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (armed && point == MatchCommandFailurePoint.beforeCommit) {
              entered.complete();
              await release.future;
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'task8-dispose'),
        );
        armed = true;
        final controller = ScoringController.fromCommittedProjection(
          started,
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
        expect(await command, isFalse);
        expect(notifications, notificationsBeforeDispose);
        expect(await database.select(database.matchEvents).get(), hasLength(1));
      });
    },
  );

  test('pause is serialized after an in-flight scoring command', () async {
    await withTestDatabase((database) async {
      final entered = Completer<void>();
      final release = Completer<void>();
      var armed = false;
      var beforeCommitCalls = 0;
      final service = MatchCommandService(
        database,
        failureInjector: (point) async {
          if (armed && point == MatchCommandFailurePoint.beforeCommit) {
            beforeCommitCalls++;
            if (!entered.isCompleted) {
              entered.complete();
              await release.future;
            }
          }
        },
      );
      final started = await service.start(
        _startCommand(matchId: 'task8-score-then-pause'),
      );
      armed = true;
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );

      final score = controller.recordScoreCommitted(
        side: TeamSide.blue,
        points: 2,
      );
      await entered.future;
      final pause = controller.pauseCommitted();
      release.complete();

      expect(await score, isTrue);
      expect(await pause, isTrue);
      expect(beforeCommitCalls, 2);
      expect(controller.state.score.blueScore, 2);
      expect(controller.isManuallyPaused, isTrue);
      final events = await database.select(database.matchEvents).get();
      expect(events.map((event) => event.type), [
        EventKind.fieldGoal.name,
        EventKind.pause.name,
      ]);
      expect(events.last.customLabel, 'pause');
    });
  });

  test('retry is a false no-op after controller disposal', () async {
    await withTestDatabase((database) async {
      var failureInjectorCalls = 0;
      var armed = false;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (armed && point == MatchCommandFailurePoint.beforeCommit) {
            failureInjectorCalls++;
            throw StateError('retry failure');
          }
        },
      );
      final started = await service.start(
        _startCommand(matchId: 'task8-retry-disposed'),
      );
      armed = true;
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );
      MatchCommandFailure? failure;
      try {
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
      } on MatchCommandFailure catch (error) {
        failure = error;
      }
      expect(failure, isNotNull);
      final callsBeforeDispose = failureInjectorCalls;
      controller.dispose();

      expect(await controller.retryCommand(failure!), isFalse);
      expect(failureInjectorCalls, callsBeforeDispose);
    });
  });

  test(
    'explicit location makes confirm exclusive and rejects ordinary actions',
    () async {
      await withTestDatabase((database) async {
        final entered = Completer<void>();
        final release = Completer<void>();
        var armed = false;
        final service = MatchCommandService(
          database,
          failureInjector: (point) async {
            if (armed && point == MatchCommandFailurePoint.beforeCommit) {
              entered.complete();
              await release.future;
            }
          },
        );
        final started = await service.start(
          _startCommand(
            matchId: 'task8-exclusive',
            trackingCoverage: TrackingCoverage.locations,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );
        await controller.recordScoreCommitted(side: TeamSide.red, points: 2);
        armed = true;
        expect(controller.beginLocateLastUnlocatedShot(), isTrue);

        final confirmation = controller.confirmPendingLocation();
        await entered.future;
        expect(
          await controller.recordScoreCommitted(side: TeamSide.blue, points: 1),
          isFalse,
        );
        expect(await controller.recordFoulCommitted(TeamSide.blue), isFalse);
        final beforePoint = controller.state.pendingLocation!.point;
        controller.updatePendingLocation(CourtPoint(x: 0.1, y: 0.9));
        expect(controller.state.pendingLocation!.point, beforePoint);
        expect(await controller.undoLastEventCommitted(), isFalse);
        expect(await controller.pauseCommitted(), isFalse);
        release.complete();
        await confirmation;
        expect(controller.state.pendingLocation, isNull);
        expect(await database.select(database.matchEvents).get(), hasLength(1));
      });
    },
  );

  test(
    'external projection refresh preserves an unfinished detailed draft',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-draft-refresh',
            recordingMode: RecordingMode.detailed,
            trackingCoverage: TrackingCoverage.locations,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );
        expect(
          controller.beginDetailedShot(CourtPoint(x: 0.4, y: 0.6)),
          isTrue,
        );
        controller.replaceCommittedProjection(started);
        expect(controller.detailedShotDraft, isNotNull);
        expect(controller.detailedShotDraft!.point.x, 0.4);
        expect(controller.detailedShotDraft!.point.y, 0.6);
      });
    },
  );

  test('detailed draft blocks undo but survives pause and resume', () async {
    await withTestDatabase((database) async {
      var commandCalls = 0;
      final service = MatchCommandService(
        database,
        failureInjector: (point) {
          if (point == MatchCommandFailurePoint.beforeCommit) {
            commandCalls++;
          }
        },
      );
      final started = await service.start(
        _startCommand(
          matchId: 'task8-draft-exclusive',
          recordingMode: RecordingMode.detailed,
          trackingCoverage: TrackingCoverage.locations,
        ),
      );
      commandCalls = 0;
      final controller = ScoringController.fromCommittedProjection(
        started,
        service,
      );
      expect(
        await controller.recordScoreCommitted(side: TeamSide.blue, points: 1),
        isTrue,
      );
      commandCalls = 0;
      expect(
        controller.beginDetailedShot(
          CourtPoint(x: 0.3, y: 0.7),
          side: TeamSide.red,
        ),
        isTrue,
      );

      expect(await controller.undoLastEventCommitted(), isFalse);
      expect(await controller.pauseCommitted(), isTrue);
      expect(controller.isManuallyPaused, isTrue);
      expect(controller.detailedShotDraft, isNotNull);
      expect(await controller.resumeCommitted(), isTrue);
      expect(controller.isManuallyPaused, isFalse);
      expect(commandCalls, 2);
      expect(controller.state.events, hasLength(3));
      expect(controller.state.score.blueScore, 1);
      expect(controller.detailedShotDraft, isNotNull);
      expect(controller.detailedShotDraft!.point.x, 0.3);
      expect(controller.detailedShotDraft!.point.y, 0.7);
      expect(controller.detailedShotDraft!.side, TeamSide.red);
      expect(await database.select(database.matchEvents).get(), hasLength(3));
    });
  });

  test(
    'generic command adapter enforces match identity and miss coverage',
    () async {
      await withTestDatabase((database) async {
        final service = MatchCommandService(database);
        final started = await service.start(
          _startCommand(
            matchId: 'task8-generic-guards',
            trackingCoverage: TrackingCoverage.scoresOnly,
          ),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );
        expect(
          await controller.recordEventCommitted(
            RecordMatchEventCommand(
              matchId: 'other-match',
              type: EventKind.fieldGoal,
              side: TeamSide.red,
              points: 0,
              outcome: ShotOutcome.missed,
              occurredAt: DateTime.utc(2026, 8, 23, 9),
            ),
          ),
          isFalse,
        );
        expect(
          await controller.recordFreeThrowCommitted(
            side: TeamSide.red,
            made: false,
          ),
          isTrue,
        );
        expect(await database.select(database.matchEvents).get(), hasLength(1));
      });
    },
  );

  test(
    'a failed queued command completes its future and the next command commits after it',
    () async {
      await withTestDatabase((database) async {
        var armed = false;
        var failed = false;
        final service = MatchCommandService(
          database,
          failureInjector: (point) {
            if (armed &&
                !failed &&
                point == MatchCommandFailurePoint.beforeCommit) {
              failed = true;
              throw StateError('first queued command failed');
            }
          },
        );
        final started = await service.start(
          _startCommand(matchId: 'task8-queue-failure'),
        );
        armed = true;
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
        );
        final first = controller.recordScoreCommitted(
          side: TeamSide.red,
          points: 1,
        );
        final second = controller.recordScoreCommitted(
          side: TeamSide.blue,
          points: 2,
        );
        await expectLater(first, throwsA(isA<MatchCommandFailure>()));
        expect(await second, isTrue);
        final events = await database.select(database.matchEvents).get();
        expect(events, hasLength(1));
        expect(events.single.side, TeamSide.blue.name);
        expect(events.single.points, 2);
      });
    },
  );

  test(
    'local court-first undo removes the event and location atomically',
    () async {
      final controller = ScoringController(
        matchId: 'task8-local-court-first-undo',
      );
      expect(
        controller.beginOrMoveCourtFirstShot(
          CourtPoint(x: 0.2, y: 0.8),
          side: TeamSide.red,
        ),
        isTrue,
      );
      controller.updateCourtFirstShot(outcome: ShotOutcome.made, points: 2);
      expect(await controller.commitCourtFirstShot(), isTrue);
      expect(controller.state.shotLocations, hasLength(1));
      expect(await controller.undoLastScoringActionCommitted(), isTrue);
      expect(
        controller.state.events.where((event) => !event.isDeleted),
        isEmpty,
      );
      expect(controller.state.shotLocations, isEmpty);
      expect(controller.state.score.redScore, 0);
    },
  );

  test('local score-first location undo remains a two-step action', () async {
    final controller = ScoringController(
      matchId: 'task8-local-score-first-undo',
    );
    expect(controller.addScore(side: TeamSide.red, points: 2), isTrue);
    await controller.attachSupplementLocation(CourtPoint(x: 0.4, y: 0.6));
    expect(controller.state.shotLocations, hasLength(1));
    expect(await controller.undoLastScoringActionCommitted(), isTrue);
    expect(
      controller.state.events.where((event) => !event.isDeleted),
      hasLength(1),
    );
    expect(controller.state.shotLocations, isEmpty);
    expect(await controller.undoLastScoringActionCommitted(), isTrue);
    expect(controller.state.events.where((event) => !event.isDeleted), isEmpty);
    expect(controller.state.score.redScore, 0);
  });

  test(
    'controller rebuild chooses the durable newest supplement owner for out-of-order timestamps',
    () async {
      await withTestDatabase((database) async {
        final openedAt = DateTime.now().toUtc();
        final service = MatchCommandService(database, now: () => openedAt);
        final started = await service.start(
          _startCommand(matchId: 'task8-durable-owner'),
        );
        final first = await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-durable-owner-first',
            matchId: started.match.id,
            eventId: 'task8-durable-owner-first-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: openedAt.subtract(const Duration(seconds: 5)),
          ),
        );
        final second = await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-durable-owner-second',
            matchId: started.match.id,
            eventId: 'task8-durable-owner-second-event',
            type: EventKind.fieldGoal,
            side: TeamSide.blue,
            points: 1,
            outcome: ShotOutcome.made,
            occurredAt: openedAt.subtract(const Duration(seconds: 6)),
          ),
        );
        expect(first.events, isNotEmpty);
        final controller = ScoringController.fromCommittedProjection(
          second,
          service,
        );
        expect(
          controller.locationSupplementWindow?.eventId,
          'task8-durable-owner-second-event',
        );
      });
    },
  );

  test(
    'controller uses current injected time after creation instead of the projection clock',
    () async {
      await withTestDatabase((database) async {
        final openedAt = DateTime.utc(2026, 8, 23, 9);
        var now = openedAt;
        final service = MatchCommandService(database, now: () => now);
        final started = await service.start(
          _startCommand(matchId: 'task8-live-clock'),
        );
        final controller = ScoringController.fromCommittedProjection(
          started,
          service,
          nowUtc: () => now,
        );

        now = openedAt.add(const Duration(seconds: 11));
        expect(
          await controller.recordScoreCommitted(side: TeamSide.red, points: 2),
          isTrue,
        );
        expect(controller.locationSupplementWindow?.openedAt, now);

        now = now.add(const Duration(seconds: 1));
        expect(
          await controller.attachSupplementLocation(
            CourtPoint(x: 0.2, y: 0.8),
            requestedAtUtc: now,
          ),
          isTrue,
        );
      });
    },
  );

  test(
    'repository reload and controller rebuild share durable newest ownership',
    () async {
      await withTestDatabase((database) async {
        final openedAt = DateTime.utc(2026, 8, 23, 9);
        final service = MatchCommandService(database, now: () => openedAt);
        final started = await service.start(
          _startCommand(matchId: 'task8-reload-owner'),
        );
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-reload-owner-a',
            matchId: started.match.id,
            eventId: 'task8-reload-owner-a-event',
            type: EventKind.fieldGoal,
            side: TeamSide.red,
            points: 2,
            outcome: ShotOutcome.made,
            occurredAt: openedAt.add(const Duration(seconds: 5)),
          ),
        );
        await service.record(
          RecordMatchEventCommand(
            commandId: 'task8-reload-owner-b',
            matchId: started.match.id,
            eventId: 'task8-reload-owner-b-event',
            type: EventKind.fieldGoal,
            side: TeamSide.blue,
            points: 1,
            outcome: ShotOutcome.made,
            occurredAt: openedAt.add(const Duration(seconds: 1)),
          ),
        );

        final reloaded = await MatchRepository(
          database,
        ).getMatchDetail(started.match.id);
        final rebuilt = ScoringController.fromCommittedProjection(
          reloaded!,
          service,
          nowUtc: () => openedAt.add(const Duration(seconds: 2)),
        );
        expect(
          rebuilt.locationSupplementWindow?.eventId,
          'task8-reload-owner-b-event',
        );
      });
    },
  );
}

StartMatchCommand _startCommand({
  required String matchId,
  RecordingMode recordingMode = RecordingMode.simple,
  TrackingCoverage trackingCoverage = TrackingCoverage.scoresOnly,
  bool timerEnabled = false,
}) {
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
    recordingMode: recordingMode,
    trackingCoverage: trackingCoverage,
    timerEnabled: timerEnabled,
    createdAt: DateTime.utc(2026, 8, 23, 9),
    startedAt: DateTime.utc(2026, 8, 23, 9),
  );
}
